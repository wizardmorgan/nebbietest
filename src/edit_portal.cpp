/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "edit_portal.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cctype>
#include <cstring>
#include <deque>
#include <future>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "../contrib/slacking/json.hpp"
#include "autoenums.hpp"
#include "constants.hpp"
#include "db.hpp"
#include "edit_pool.hpp"
#include "edit_system_config.hpp"
#include "handler.hpp"
#include "legacy_import.hpp"
#include "logging.hpp"
#include "multiclass.hpp"
#include "obj_edit_catalog.hpp"
#include "obj_value.hpp"
#include "object_instance.hpp"
#include "reception.hpp"
#include "Sql.hpp"
#include "structs.hpp"
#include "utils.hpp"

#if USE_MYSQL
#include <mysql/mysql.h>
#include <odb/mysql/connection.hxx>
#include "odb/account-odb.hxx"
#endif

namespace Alarmud {
namespace {

using Json = nlohmann::json;

struct EditPortalJob {
	std::string path;
	std::string body;
	std::promise<std::string> response;
};

std::mutex g_queue_mutex;
std::condition_variable g_queue_cv;
std::deque<EditPortalJob> g_jobs;
std::atomic<bool> g_http_running {false};

[[nodiscard]] std::string trim_http_value(std::string value) {
	while(!value.empty() && (value.front() == ' ' || value.front() == '\t')) {
		value.erase(value.begin());
	}
	while(!value.empty() && (value.back() == ' ' || value.back() == '\t')) {
		value.pop_back();
	}
	return value;
}

[[nodiscard]] std::string api_secret() {
	const char* s = std::getenv("EDIT_API_SECRET");
	if(!s || !*s) {
		return "nebbie-edit-dev-secret";
	}
	return trim_http_value(std::string(s));
}

[[nodiscard]] int api_port() {
	const char* p = std::getenv("EDIT_API_PORT");
	if(!p || !*p) {
		return 8090;
	}
	return std::atoi(p);
}

[[nodiscard]] bool header_has_secret(const std::string& headers) {
	const std::string secret = api_secret();
	std::istringstream stream(headers);
	std::string line;
	while(std::getline(stream, line)) {
		if(!line.empty() && line.back() == '\r') {
			line.pop_back();
		}
		const auto colon = line.find(':');
		if(colon == std::string::npos) {
			continue;
		}
		std::string name = line.substr(0, colon);
		for(char& c : name) {
			c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
		}
		if(name != "x-edit-api-secret") {
			continue;
		}
		return trim_http_value(line.substr(colon + 1)) == secret;
	}
	return false;
}

[[nodiscard]] size_t header_content_length(const std::string& headers) {
	std::istringstream stream(headers);
	std::string line;
	while(std::getline(stream, line)) {
		if(!line.empty() && line.back() == '\r') {
			line.pop_back();
		}
		const auto colon = line.find(':');
		if(colon == std::string::npos) {
			continue;
		}
		std::string name = line.substr(0, colon);
		for(char& c : name) {
			c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
		}
		if(name != "content-length") {
			continue;
		}
		return static_cast<size_t>(
			std::strtoul(trim_http_value(line.substr(colon + 1)).c_str(), nullptr, 10));
	}
	return 0;
}

[[nodiscard]] std::string read_http_request(int client) {
	std::string raw;
	char buf[4096];
	size_t need = 0;
	while(raw.size() < 65536) {
		if(need > 0 && raw.size() >= need) {
			break;
		}
		const ssize_t n = read(client, buf, sizeof(buf));
		if(n <= 0) {
			break;
		}
		raw.append(buf, static_cast<size_t>(n));
		const auto hdr_end = raw.find("\r\n\r\n");
		if(hdr_end == std::string::npos) {
			continue;
		}
		const size_t cl = header_content_length(raw.substr(0, hdr_end));
		need = hdr_end + 4 + cl;
	}
	return raw;
}

[[nodiscard]] std::string normalize_api_path(std::string path) {
	if(!path.empty() && path.front() != '/') {
		path.insert(path.begin(), '/');
	}
	const auto q = path.find('?');
	if(q != std::string::npos) {
		path = path.substr(0, q);
	}
	while(path.size() > 1 && path.back() == '/') {
		path.pop_back();
	}
	return path;
}

[[nodiscard]] std::string json_error(const char* msg, int code = 400) {
	Json j;
	j["ok"] = false;
	j["error"] = msg ? msg : "errore";
	j["code"] = code;
	j[kEditPortalApiVersionTag] = kEditPortalApiVersion;
	return j.dump();
}

[[nodiscard]] std::string json_ok(const Json& data) {
	Json j;
	j["ok"] = true;
	j["data"] = data;
	j[kEditPortalApiVersionTag] = kEditPortalApiVersion;
	return j.dump();
}

[[nodiscard]] unsigned long long parse_json_ull(const Json& req, const char* key) {
	if(!key || !*key || req.find(key) == req.end() || req[key].is_null()) {
		return 0ULL;
	}
	const Json& v = req[key];
	if(v.is_number_unsigned()) {
		return v.get<unsigned long long>();
	}
	if(v.is_number_integer()) {
		return static_cast<unsigned long long>(v.get<long long>());
	}
	if(v.is_string()) {
		try {
			const std::string id_text = v.get<std::string>();
			if(id_text.empty()) {
				return 0ULL;
			}
			std::size_t parsed = 0;
			const unsigned long long id = std::stoull(id_text, &parsed);
			if(parsed != id_text.size()) {
				return 0ULL;
			}
			return id;
		}
		catch(...) {
			return 0ULL;
		}
	}
	return 0ULL;
}

[[nodiscard]] int parse_json_int(const Json& v, int default_val = 0) {
	if(v.is_number_integer()) {
		return static_cast<int>(v.get<long long>());
	}
	if(v.is_number_unsigned()) {
		return static_cast<int>(v.get<unsigned long long>());
	}
	if(v.is_string()) {
		try {
			const std::string t = v.get<std::string>();
			if(t.empty()) {
				return default_val;
			}
			std::size_t parsed = 0;
			const int n = std::stoi(t, &parsed);
			if(parsed != t.size()) {
				return default_val;
			}
			return n;
		}
		catch(...) {
			return default_val;
		}
	}
	return default_val;
}

[[nodiscard]] int parse_json_int(const Json& req, const char* key, int default_val = 0) {
	if(!key || !*key || req.find(key) == req.end()) {
		return default_val;
	}
	return parse_json_int(req[key], default_val);
}

[[nodiscard]] unsigned long long parse_json_toon_id(const Json& req) {
	return parse_json_ull(req, "toon_id");
}

[[nodiscard]] bool is_toon_online_by_name(const std::string& name) {
	if(name.empty()) {
		return false;
	}
	for(struct char_data* c = character_list; c; c = c->next) {
		if(IS_NPC(c) || !GET_NAME(c)) {
			continue;
		}
		if(!strcasecmp(GET_NAME(c), name.c_str())) {
			return true;
		}
	}
	return false;
}

#if USE_MYSQL
/** Escape for SQL string literals (portal raw mysql path). */
[[nodiscard]] std::string portal_sql_escape(const char* s) {
	if(!s) {
		return {};
	}
	std::string out;
	out.reserve(std::strlen(s) * 2 + 4);
	for(const char* p = s; *p; ++p) {
		if(*p == '\'' || *p == '\\') {
			out.push_back('\\');
		}
		out.push_back(*p);
	}
	return out;
}

[[nodiscard]] std::string portal_sql_literal(const char* s) {
	return "'" + portal_sql_escape(s ? s : "") + "'";
}

/**
 * Execute SQL via libmysql (no odb::transaction required).
 * Prefer this over db->execute / ODB persist on the mud main thread: ODB object
 * ops and database::execute need a live transaction TLS slot that has proven
 * unreliable for portal jobs (not_in_transaction even after begin()).
 */
[[nodiscard]] bool portal_mysql_exec(DB* db, const std::string& sql, std::string& err,
									 const char* where = "portal_mysql_exec") {
	if(!db) {
		err = std::string("[") + where + "] database non disponibile";
		return false;
	}
	/* TLS ODB sporco (has_current ma finalized) → connection() sulla tx esplode
	 * con "operation can only be performed in transaction". Reset e usa il pool. */
	if(odb::transaction::has_current() && odb::transaction::current().finalized()) {
		odb::transaction::reset_current();
	}
	try {
		/* database::connection(): se c'e' tx attiva riusa quella, altrimenti pool. */
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		if(mysql_query(h, sql.c_str()) != 0) {
			err = std::string("[") + where + "] mysql: " +
				  (mysql_error(h) ? mysql_error(h) : "mysql_query failed");
			return false;
		}
		return true;
	}
	catch(const std::exception& e) {
		const bool had_tx = odb::transaction::has_current();
		err = std::string("[") + where + "] odb/conn has_current=" +
			  (had_tx ? "1" : "0") + ": " + e.what();
		mudlog(LOG_SYSERR, "edit_portal: %s", err.c_str());
		return false;
	}
}

/** INSERT via libmysql; returns AUTO_INCREMENT id on the same connection. */
[[nodiscard]] bool portal_mysql_insert(DB* db, const std::string& sql,
									   unsigned long long& out_id, std::string& err,
									   const char* where = "portal_mysql_insert") {
	out_id = 0;
	if(!db) {
		err = std::string("[") + where + "] database non disponibile";
		return false;
	}
	if(odb::transaction::has_current() && odb::transaction::current().finalized()) {
		odb::transaction::reset_current();
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		if(mysql_query(h, sql.c_str()) != 0) {
			err = std::string("[") + where + "] mysql: " +
				  (mysql_error(h) ? mysql_error(h) : "mysql_query failed");
			return false;
		}
		out_id = static_cast<unsigned long long>(mysql_insert_id(h));
		if(out_id == 0) {
			err = std::string("[") + where + "] mysql_insert_id=0 dopo INSERT";
			return false;
		}
		return true;
	}
	catch(const std::exception& e) {
		const bool had_tx = odb::transaction::has_current();
		err = std::string("[") + where + "] odb/conn has_current=" +
			  (had_tx ? "1" : "0") + ": " + e.what();
		mudlog(LOG_SYSERR, "edit_portal: %s", err.c_str());
		return false;
	}
}

[[nodiscard]] int max_level_for_toon(unsigned long long toon_id) {
	DB* db = Sql::getMysql();
	if(!db || toon_id == 0) {
		return 0;
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		const std::string sql =
			"SELECT MAX(level) FROM character_classes WHERE toon_id = " +
			std::to_string(toon_id);
		if(mysql_query(h, sql.c_str()) != 0) {
			return 0;
		}
		MYSQL_RES* res = mysql_store_result(h);
		if(!res) {
			return 0;
		}
		MYSQL_ROW row = mysql_fetch_row(res);
		const int lvl = row && row[0] ? std::atoi(row[0]) : 0;
		mysql_free_result(res);
		return lvl;
	}
	catch(...) {
		return 0;
	}
}

[[nodiscard]] std::string toon_name_by_id(unsigned long long toon_id) {
	if(toon_id == 0) {
		return {};
	}
	const toonPtr pg = Sql::getOne<toon>(toonQuery::id == toon_id);
	if(pg && pg->name[0] != '\0') {
		return pg->name;
	}
#if USE_MYSQL
	DB* db = Sql::getMysql();
	if(!db) {
		return {};
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		const std::string sql =
			"SELECT name FROM toon WHERE id = " + std::to_string(toon_id) + " LIMIT 1";
		if(mysql_query(h, sql.c_str()) != 0) {
			return {};
		}
		MYSQL_RES* res = mysql_store_result(h);
		if(!res) {
			return {};
		}
		MYSQL_ROW row = mysql_fetch_row(res);
		const std::string name = row && row[0] ? row[0] : std::string();
		mysql_free_result(res);
		return name;
	}
	catch(...) {
		return {};
	}
#else
	(void)toon_id;
#endif
	return {};
}

[[nodiscard]] bool load_stats_for_toon(unsigned long long toon_id, int& exp,
									   int& rune) {
	DB* db = Sql::getMysql();
	if(!db || toon_id == 0) {
		return false;
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		const std::string sql =
			"SELECT exp, p_rune_dei FROM character_stats WHERE toon_id = " +
			std::to_string(toon_id) + " LIMIT 1";
		if(mysql_query(h, sql.c_str()) != 0) {
			return false;
		}
		MYSQL_RES* res = mysql_store_result(h);
		if(!res) {
			return false;
		}
		MYSQL_ROW row = mysql_fetch_row(res);
		if(!row) {
			mysql_free_result(res);
			return false;
		}
		exp = row[0] ? std::atoi(row[0]) : 0;
		rune = row[1] ? std::atoi(row[1]) : 0;
		mysql_free_result(res);
		return true;
	}
	catch(...) {
		return false;
	}
}

[[nodiscard]] bool deduct_payment(unsigned long long toon_id, int xp_cost,
								  int rune_cost, int max_level, std::string& err) {
	int exp = 0;
	int rune = 0;
	if(!load_stats_for_toon(toon_id, exp, rune)) {
		err = "[portal:deduct] character_stats non trovato";
		return false;
	}
	const long long prince_reserve =
		(max_level >= PRINCIPE) ? static_cast<long long>(PRINCEEXP) : 0LL;
	const long long available_xp = static_cast<long long>(exp) - prince_reserve;
	if(xp_cost > 0 && available_xp < static_cast<long long>(xp_cost)) {
		err = "[portal:deduct] XP insufficienti (riserva principi 400M inclusa)";
		return false;
	}
	if(rune_cost > 0 && rune < rune_cost) {
		err = "[portal:deduct] Rune degli Eroi insufficienti";
		return false;
	}
	DB* db = Sql::getMysql();
	if(!db) {
		err = "[portal:deduct] database non disponibile";
		return false;
	}
	std::ostringstream sql;
	sql << "UPDATE character_stats SET exp = exp - " << xp_cost
		<< ", p_rune_dei = p_rune_dei - " << rune_cost << " WHERE toon_id = "
		<< toon_id;
	/* mysql_query: evita odb::execute che richiede transaction sul thread mud. */
	return portal_mysql_exec(db, sql.str(), err, "portal:deduct");
}

/**
 * Listino: la parte MXP (quote_xp) si paga in XP e/o Rune (1 MXP = 1 Rune =
 * kObjEditRunePerMegaXp XP raw). quote_pq sono rune “rent” aggiuntive obbligatorie.
 * Non forzare mai max(pay_xp, quote_xp): spezzerebbe il pagamento solo-rune.
 */
[[nodiscard]] bool resolve_object_edit_payment(int pay_xp, int pay_rune, long quote_xp,
											  int quote_pq, int& xp_cost, int& rune_cost,
											  std::string& err) {
	if(pay_xp < 0 || pay_rune < 0) {
		err = "[portal:pay] pagamento non valido";
		return false;
	}
	const int quote_xp_i = static_cast<int>(std::max(0L, quote_xp));
	const int pq = std::max(0, quote_pq);
	if(pay_rune < pq) {
		err = "[portal:pay] rune componente listino insufficienti";
		return false;
	}
	const long long rune_cover_xp =
		static_cast<long long>(pay_rune - pq) * kObjEditRunePerMegaXp;
	const long long covered =
		static_cast<long long>(pay_xp) + rune_cover_xp;
	if(covered < static_cast<long long>(quote_xp_i)) {
		err = "[portal:pay] copertura XP/Rune insufficiente rispetto al listino";
		return false;
	}
	xp_cost = pay_xp;
	rune_cost = pay_rune;
	return true;
}

[[nodiscard]] bool inventory_row_has_affect_overlay(const inventory_mysql_row& row) {
	for(int j = 0; j < MAX_OBJ_AFFECT; ++j) {
		if(row.elem.affected[j].location != 0 || row.elem.affected[j].modifier != 0) {
			return true;
		}
	}
	return false;
}

[[nodiscard]] struct obj_data* materialize_inventory_row(
	const inventory_mysql_row& row) {
	if(row.elem.item_number <= 0) {
		return nullptr;
	}
	struct obj_data* obj =
		object_instance_load_stored(row.elem.item_number, row.instance_id);
	if(!obj) {
		return nullptr;
	}
	if(obj->db_instance_id != 0) {
		return obj;
	}
	obj->obj_flags.value[0] = row.elem.value[0];
	obj->obj_flags.value[1] = row.elem.value[1];
	obj->obj_flags.value[2] = row.elem.value[2];
	obj->obj_flags.value[3] = row.elem.value[3];
	obj->obj_flags.extra_flags = row.elem.extra_flags;
	obj->obj_flags.extra_flags2 = row.elem.extra_flags2;
	obj->obj_flags.weight = row.elem.weight;
	obj->obj_flags.timer = row.elem.timer;
	obj->obj_flags.bitvector = row.elem.bitvector;
	if(obj->name) {
		free(obj->name);
	}
	if(obj->short_description) {
		free(obj->short_description);
	}
	if(obj->description) {
		free(obj->description);
	}
	obj->name = strdup(row.elem.name);
	obj->short_description = strdup(row.elem.sd);
	obj->description = strdup(row.elem.desc);
	/* Empty character_inventory_affect must not zero proto affects. */
	if(inventory_row_has_affect_overlay(row)) {
		for(int j = 0; j < MAX_OBJ_AFFECT; ++j) {
			obj->affected[j] = row.elem.affected[j];
		}
	}
	obj->db_inventory_id = row.id;
	return obj;
}

[[nodiscard]] inventory_mysql_row* find_inventory_row(
	std::vector<inventory_mysql_row>& rows, unsigned long long inventory_id) {
	for(auto& r : rows) {
		if(r.id == inventory_id) {
			return &r;
		}
	}
	return nullptr;
}

/**
 * Tetto dam/sp listino (personaggio):
 * pezzi in possesso (inv o indossati) con ITEM2_EDIT e owner del toon
 * → max(0, dam_attuale − dam_prototipo). Simboli di clan esclusi.
 */
[[nodiscard]] int sum_owned_edited_damroll_excluding(
	std::vector<inventory_mysql_row>& rows, unsigned long long exclude_inventory_id,
	const char* toon_name) {
	int total = 0;
	for(auto& r : rows) {
		if(r.id == exclude_inventory_id) {
			continue;
		}
		struct obj_data* o = materialize_inventory_row(r);
		if(!o) {
			continue;
		}
		if(object_edit_counts_toward_combat_budget(o, toon_name)) {
			total += object_edit_damroll_edited_delta(o);
		}
		extract_obj(o);
	}
	return total;
}

[[nodiscard]] int sum_owned_edited_spellpower_excluding(
	std::vector<inventory_mysql_row>& rows, unsigned long long exclude_inventory_id,
	const char* toon_name) {
	int total = 0;
	for(auto& r : rows) {
		if(r.id == exclude_inventory_id) {
			continue;
		}
		struct obj_data* o = materialize_inventory_row(r);
		if(!o) {
			continue;
		}
		if(object_edit_counts_toward_combat_budget(o, toon_name)) {
			total += object_edit_spellpower_edited_delta(o);
		}
		extract_obj(o);
	}
	return total;
}

/** Elenco pezzi EDIT+owner che contribuiscono al tetto dam (UI). */
[[nodiscard]] Json owned_dam_budget_contributors_json(
	std::vector<inventory_mysql_row>& rows, const char* toon_name) {
	Json list = Json::array();
	for(auto& r : rows) {
		struct obj_data* o = materialize_inventory_row(r);
		if(!o) {
			continue;
		}
		if(object_edit_counts_toward_combat_budget(o, toon_name)) {
			const int cur = object_edit_damroll_total(o);
			const int proto = object_edit_damroll_prototype_total(o);
			const int delta = object_edit_damroll_edited_delta(o);
			if(delta > 0) {
				Json c;
				c["inventory_id"] = r.id;
				c["short_desc"] = r.elem.sd;
				c["current"] = cur;
				c["proto"] = proto;
				c["delta"] = delta;
				c["worn"] = inventory_row_is_worn(r.elem.wearpos);
				c["proto_vnum"] = object_edit_prototype_vnum(o);
				list.push_back(c);
			}
		}
		extract_obj(o);
	}
	return list;
}

[[nodiscard]] bool persist_inventory_affects(unsigned long long inventory_id,
											 const struct obj_data* obj,
											 std::string& err) {
	DB* db = Sql::getMysql();
	if(!db || !obj) {
		err = "[portal:persist_inv] database/obj non disponibile";
		return false;
	}
	const int base_vnum = object_instance_resolve_base_vnum(obj);
	const std::string name_lit =
		portal_sql_literal(obj->name ? obj->name : "");
	const std::string sd_lit =
		portal_sql_literal(obj->short_description ? obj->short_description : "");
	const std::string desc_lit =
		portal_sql_literal(obj->description ? obj->description : "");
	std::ostringstream upd;
	upd << "UPDATE character_inventory SET extra_flags="
		<< static_cast<int>(obj->obj_flags.extra_flags) << ", extra_flags2="
		<< static_cast<int>(obj->obj_flags.extra_flags2) << ", obj_name=" << name_lit
		<< ", short_desc=" << sd_lit << ", description=" << desc_lit;
	if(obj->db_instance_id != 0) {
		upd << ", instance_id=" << obj->db_instance_id;
		if(base_vnum > 0) {
			upd << ", item_number=" << base_vnum;
		}
	}
	upd << " WHERE id = " << inventory_id;
	if(!portal_mysql_exec(db, upd.str(), err, "portal:persist_inv_upd")) {
		return false;
	}
	if(!portal_mysql_exec(db,
						  "DELETE FROM character_inventory_affect WHERE inventory_id = " +
							  std::to_string(inventory_id),
						  err, "portal:persist_inv_del_aff")) {
		return false;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		if(loc == APPLY_NONE || loc == APPLY_SKIP || mod == 0) {
			continue;
		}
		std::ostringstream ins;
		ins << "INSERT INTO character_inventory_affect (inventory_id, affect_slot, "
			   "location, modifier) VALUES ("
			<< inventory_id << ',' << i << ',' << loc << ',' << mod << ')';
		if(!portal_mysql_exec(db, ins.str(), err, "portal:persist_inv_ins_aff")) {
			return false;
		}
	}
	return true;
}

/**
 * Persist edited object_instance (+ affects + event) via raw mysql_query.
 * Creates a new row when obj->db_instance_id == 0 (first portal edit), otherwise
 * UPDATEs. Avoids ODB persist/update which require transaction TLS on mud thread.
 */
[[nodiscard]] bool portal_persist_object_instance_mysql(struct obj_data* obj,
														int base_vnum,
														const char* owner_name,
														std::string& err) {
	DB* db = Sql::getMysql();
	if(!db || !obj || base_vnum <= 0) {
		err = "[portal:persist_inst] parametri non validi";
		return false;
	}

	int shell_weight = obj->obj_flags.weight;
	if(GET_ITEM_TYPE(obj) == ITEM_CONTAINER) {
		shell_weight -= contained_weight(obj);
		if(shell_weight < 0) {
			shell_weight = 0;
		}
	}
	const std::string stripped_name = object_instance_strip_ed_tokens(obj->name);
	const char* name_src =
		!stripped_name.empty() ? stripped_name.c_str()
							   : (obj->name ? obj->name : "");
	const std::string name_lit = portal_sql_literal(name_src);
	const std::string sd_lit =
		portal_sql_literal(obj->short_description ? obj->short_description : "");
	const std::string desc_lit =
		portal_sql_literal(obj->description ? obj->description : "");

	int char_vnum = obj->char_vnum;
	if(char_vnum <= 0 ||
	   (char_vnum >= LOW_EDITED_ITEMS && char_vnum <= HIGH_EDITED_ITEMS)) {
		char_vnum = base_vnum;
	}
	obj->char_vnum = char_vnum;

	std::string owner;
	if(owner_name && *owner_name) {
		owner = owner_name;
	}
	else if(obj->personal_owner[0] != '\0') {
		owner = obj->personal_owner;
	}
	const std::string owner_sql =
		owner.empty() ? "NULL" : portal_sql_literal(owner.c_str());

	const bool is_create = (obj->db_instance_id == 0);
	unsigned long long id = obj->db_instance_id;

	if(is_create) {
		std::ostringstream ins;
		ins << "INSERT INTO object_instance ("
			   "base_vnum, char_vnum, type_flag, wear_flags, extra_flags, "
			   "extra_flags2, weight, cost, cost_per_day, timer, bitvector, "
			   "value0, value1, value2, value3, obj_name, short_desc, description, "
			   "owner_name, created_by_name, updated_by_name, deleted, "
			   "created_at, updated_at) VALUES ("
			<< base_vnum << ',' << char_vnum << ','
			<< static_cast<int>(obj->obj_flags.type_flag) << ','
			<< static_cast<int>(obj->obj_flags.wear_flags) << ','
			<< static_cast<int>(obj->obj_flags.extra_flags) << ','
			<< static_cast<int>(obj->obj_flags.extra_flags2) << ','
			<< shell_weight << ',' << obj->obj_flags.cost << ','
			<< obj->obj_flags.cost_per_day << ',' << obj->obj_flags.timer << ','
			<< obj->obj_flags.bitvector << ',' << obj->obj_flags.value[0] << ','
			<< obj->obj_flags.value[1] << ',' << obj->obj_flags.value[2] << ','
			<< obj->obj_flags.value[3] << ',' << name_lit << ',' << sd_lit << ','
			<< desc_lit << ',' << owner_sql
			<< ", 'edit_portal', 'edit_portal', 0, NOW(), NOW())";
		if(!portal_mysql_insert(db, ins.str(), id, err, "portal:persist_inst_ins")) {
			return false;
		}
		obj->db_instance_id = id;
		if(!owner.empty()) {
			strncpy(obj->personal_owner, owner.c_str(),
					sizeof(obj->personal_owner) - 1);
			obj->personal_owner[sizeof(obj->personal_owner) - 1] = '\0';
		}
	}
	else {
		std::ostringstream upd;
		upd << "UPDATE object_instance SET base_vnum=" << base_vnum
			<< ", char_vnum=" << char_vnum
			<< ", type_flag=" << static_cast<int>(obj->obj_flags.type_flag)
			<< ", wear_flags=" << static_cast<int>(obj->obj_flags.wear_flags)
			<< ", extra_flags=" << static_cast<int>(obj->obj_flags.extra_flags)
			<< ", extra_flags2=" << static_cast<int>(obj->obj_flags.extra_flags2)
			<< ", weight=" << shell_weight << ", cost=" << obj->obj_flags.cost
			<< ", cost_per_day=" << obj->obj_flags.cost_per_day
			<< ", timer=" << obj->obj_flags.timer
			<< ", bitvector=" << obj->obj_flags.bitvector
			<< ", value0=" << obj->obj_flags.value[0]
			<< ", value1=" << obj->obj_flags.value[1]
			<< ", value2=" << obj->obj_flags.value[2]
			<< ", value3=" << obj->obj_flags.value[3]
			<< ", obj_name=" << name_lit << ", short_desc=" << sd_lit
			<< ", description=" << desc_lit;
		if(!owner.empty()) {
			upd << ", owner_name=" << owner_sql;
		}
		upd << ", updated_by_name='edit_portal', updated_at=NOW()"
			<< " WHERE id=" << id << " AND deleted=0";
		if(!portal_mysql_exec(db, upd.str(), err, "portal:persist_inst_upd")) {
			return false;
		}
	}

	if(!portal_mysql_exec(db,
						  "DELETE FROM object_instance_affect WHERE key_instance_id=" +
							  std::to_string(id),
						  err, "portal:persist_inst_del_aff")) {
		return false;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		if(loc == 0 && mod == 0) {
			continue;
		}
		std::ostringstream aff;
		aff << "INSERT INTO object_instance_affect (key_instance_id, key_affect_slot, "
			   "location, modifier) VALUES ("
			<< id << ',' << i << ',' << loc << ',' << mod << ')';
		if(!portal_mysql_exec(db, aff.str(), err, "portal:persist_inst_ins_aff")) {
			return false;
		}
	}
	{
		std::ostringstream ev;
		ev << "INSERT INTO object_instance_event (instance_id, at, actor_name, kind, "
			  "note) VALUES ("
		   << id << ", NOW(), 'edit_portal', '" << (is_create ? "create" : "update")
		   << "', "
		   << portal_sql_literal(("base=" + std::to_string(base_vnum)).c_str()) << ')';
		if(!portal_mysql_exec(db, ev.str(), err, "portal:persist_inst_event")) {
			return false;
		}
	}
	return true;
}

/**
 * Come do_personalize / SetPersonOnSave: owner sul toon target + flag PERSONAL.
 * Le keyword restano senza ED* (owner in personal_owner / object_instance.owner_name).
 */
void portal_apply_personalize(struct obj_data* obj, const char* owner_name) {
	if(!obj || !owner_name || !*owner_name) {
		return;
	}
	SET_BIT(obj->obj_flags.extra_flags2, ITEM2_PERSONAL);
	strncpy(obj->personal_owner, owner_name, sizeof(obj->personal_owner) - 1);
	obj->personal_owner[sizeof(obj->personal_owner) - 1] = '\0';
	if(obj->name) {
		const std::string stripped = object_instance_strip_ed_tokens(obj->name);
		if(!stripped.empty() && stripped != obj->name) {
			free(obj->name);
			obj->name = strdup(stripped.c_str());
		}
	}
}

/**
 * Save apply-affect result: create/update object_instance via raw mysql, then
 * refresh character_inventory (+ affects + instance_id link). Never uses ODB.
 */
[[nodiscard]] bool portal_save_edited_inventory_item(unsigned long long inventory_id,
													 struct obj_data* after,
													 std::string& err,
													 const char* owner_name) {
	if(!after) {
		err = "[portal:save] obj null";
		return false;
	}
	const int base = object_instance_resolve_base_vnum(after);
	if(base <= 0) {
		err = "[portal:save] base_vnum non risolvibile (item_number/char_vnum)";
		return false;
	}
	if(after->char_vnum == 0 ||
	   (after->char_vnum >= LOW_EDITED_ITEMS &&
		after->char_vnum <= HIGH_EDITED_ITEMS)) {
		after->char_vnum = base;
	}
	if(!IS_OBJ_STAT2(after, ITEM2_EDIT)) {
		SET_BIT(after->obj_flags.extra_flags2, ITEM2_EDIT);
	}
	/* Stesso effetto di «personalize <obj> <toon>»: PERSONAL + owner del target. */
	if(owner_name && *owner_name) {
		portal_apply_personalize(after, owner_name);
	}
	if(!portal_persist_object_instance_mysql(after, base, owner_name, err)) {
		return false;
	}
	if(!persist_inventory_affects(inventory_id, after, err)) {
		return false;
	}
	return true;
}

[[nodiscard]] Json analyze_to_json(const struct obj_data* obj) {
	const ObjEditAnalysis a =
		AnalyzeObjEdit(const_cast<struct obj_data*>(obj));
	Json j;
	j["has_edit"] = a.has_edit;
	j["owner_name"] = a.owner_name;
	j["owner_classes"] = a.owner_classes;
	j["class_mult"] = a.class_mult;
	j["diff_xp_mega"] = static_cast<long long>(a.diff.valore / 1000000L);
	j["diff_xp_frac"] = static_cast<long long>(
		(a.diff.valore - static_cast<long long>(j["diff_xp_mega"].get<long long>()) *
							 1000000L) /
		10000L);
	j["diff_xp_raw"] = a.diff.valore;
	j["diff_rune"] = a.diff.rune;
	j["diff_derent_mega"] = static_cast<long long>(a.diff.derent / 1000000L);
	j["changes"] = a.changes;
	j["artifact"] = IS_OBJ_STAT(obj, ITEM_IMMUNE) ? 1 : 0;
	return j;
}

[[nodiscard]] bool portal_text_field_ok(const std::string& s, int max_len,
										const char* label, std::string& err) {
	if(static_cast<int>(s.size()) > max_len) {
		err = std::string(label) + " troppo lungo (" + std::to_string(s.size()) +
			  "/" + std::to_string(max_len) + ")";
		return false;
	}
	return true;
}

void portal_set_obj_string(char*& field, const std::string& value) {
	if(field) {
		free(field);
		field = nullptr;
	}
	field = strdup(value.c_str());
}

/**
 * Opzionale: name/short/long dal body JSON.
 * Restituisce true se almeno un campo e' presente nella richiesta.
 * Se present e testo diverso dall'attuale, require_paid deve essere true
 * (affect con costo listino > 0), altrimenti err.
 */
[[nodiscard]] bool portal_apply_optional_text_fields(
	struct obj_data* obj, const Json& req, bool affect_is_paid, std::string& err,
	bool& text_changed_out) {
	text_changed_out = false;
	if(!obj) {
		err = "oggetto null";
		return false;
	}
	const bool has_name = req.find("obj_name") != req.end() || req.find("name") != req.end();
	const bool has_short =
		req.find("short_desc") != req.end() || req.find("short") != req.end();
	const bool has_long =
		req.find("description") != req.end() || req.find("long_desc") != req.end();
	if(!has_name && !has_short && !has_long) {
		return true;
	}
	const std::string new_name =
		has_name ? std::string(req.value("obj_name", req.value("name", "")))
				 : std::string(obj->name ? obj->name : "");
	const std::string new_short =
		has_short
			? std::string(req.value("short_desc", req.value("short", "")))
			: std::string(obj->short_description ? obj->short_description : "");
	const std::string new_long =
		has_long
			? std::string(req.value("description", req.value("long_desc", "")))
			: std::string(obj->description ? obj->description : "");

	if(!portal_text_field_ok(new_name, kObjEditTextNameMax, "name", err) ||
	   !portal_text_field_ok(new_short, kObjEditTextShortMax, "short", err) ||
	   !portal_text_field_ok(new_long, kObjEditTextLongMax, "long", err)) {
		return false;
	}

	const std::string cur_name = obj->name ? obj->name : "";
	const std::string cur_short =
		obj->short_description ? obj->short_description : "";
	const std::string cur_long = obj->description ? obj->description : "";
	const bool changed =
		(new_name != cur_name) || (new_short != cur_short) || (new_long != cur_long);
	if(!changed) {
		return true;
	}
	if(!affect_is_paid) {
		err = "name/short/long solo insieme al pagamento di un nuovo affect "
			  "(non con Artifact gratis ne' da soli)";
		return false;
	}
	portal_set_obj_string(obj->name, new_name);
	portal_set_obj_string(obj->short_description, new_short);
	portal_set_obj_string(obj->description, new_long);
	text_changed_out = true;
	return true;
}

inline constexpr long kEditPortalPqPerMegaXp = kEditPoolPqPerMegaXp;

[[nodiscard]] Json quote_from_pool(const edit_pool_quote& quote) {
	Json q;
	q["mxp"] = quote.mxp;
	q["mxp_frac"] = quote.mxp_frac;
	q["xp_raw"] = quote.xp_raw;
	q["pq"] = quote.pq;
	return q;
}

[[nodiscard]] Json quote_xp_json(long xp_raw, int pq) {
	edit_pool_quote q;
	q.xp_raw = xp_raw;
	q.pq = pq;
	q.mxp = xp_raw / 1000000L;
	q.mxp_frac = (xp_raw % 1000000L) / 10000L;
	return quote_from_pool(q);
}

[[nodiscard]] sh_int pool_field_current(const char_edit_pool_data& pool,
										EditPoolField field) noexcept {
	switch(field) {
	case EditPoolField::Hp:
		return pool.edit_hp;
	case EditPoolField::Mana:
		return pool.edit_mana;
	case EditPoolField::Move:
		return pool.edit_move;
	case EditPoolField::HpRegen:
		return pool.edit_hp_regen;
	case EditPoolField::ManaRegen:
		return pool.edit_mana_regen;
	case EditPoolField::MoveRegen:
		return pool.edit_move_regen;
	}
	return 0;
}

[[nodiscard]] long resistance_bit_xp_raw(unsigned damage_type) noexcept {
	/* MXP listino × 100 raw (× storage → mega): https://www.nebbiearcane.it/listino-edits/ */
	switch(damage_type) {
	case IMM_FIRE:
		return 10000L; /* 100 MXP */
	case IMM_COLD:
	case IMM_ACID:
	case IMM_HOLD:
		return 7500L; /* 75 MXP */
	case IMM_ELEC:
	case IMM_ENERGY:
	case IMM_SLASH:
	case IMM_PIERCE:
		return 15000L; /* 150 MXP */
	case IMM_BLUNT:
		return 30000L; /* 300 MXP */
	case IMM_DRAIN:
	case IMM_POISON:
		return 3000L; /* 30 MXP */
	default:
		return 5000L;
	}
}

[[nodiscard]] Json quote_xp_json(long xp_raw) {
	return quote_xp_json(xp_raw, 0);
}

[[nodiscard]] bool load_edit_pool_for_toon(unsigned long long toon_id,
										   char_edit_pool_data& pool) {
	DB* db = Sql::getMysql();
	if(!db || toon_id == 0) {
		return false;
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		MYSQL* h = mc.handle();
		const std::string sql =
			"SELECT edit_hp, edit_mana, edit_move, edit_hp_regen, edit_mana_regen, "
			"edit_move_regen, overedit_hp, overedit_mana, overedit_move, "
			"overedit_hp_regen, overedit_mana_regen, overedit_move_regen "
			"FROM character_stats WHERE toon_id = " +
			std::to_string(toon_id) + " LIMIT 1";
		if(mysql_query(h, sql.c_str()) != 0) {
			return false;
		}
		MYSQL_RES* res = mysql_store_result(h);
		if(!res) {
			return false;
		}
		MYSQL_ROW row = mysql_fetch_row(res);
		if(!row) {
			mysql_free_result(res);
			return false;
		}
		pool.edit_hp = static_cast<sh_int>(row[0] ? std::atoi(row[0]) : 0);
		pool.edit_mana = static_cast<sh_int>(row[1] ? std::atoi(row[1]) : 0);
		pool.edit_move = static_cast<sh_int>(row[2] ? std::atoi(row[2]) : 0);
		pool.edit_hp_regen = static_cast<sh_int>(row[3] ? std::atoi(row[3]) : 0);
		pool.edit_mana_regen = static_cast<sh_int>(row[4] ? std::atoi(row[4]) : 0);
		pool.edit_move_regen = static_cast<sh_int>(row[5] ? std::atoi(row[5]) : 0);
		pool.overedit_hp = static_cast<sh_int>(row[6] ? std::atoi(row[6]) : 0);
		pool.overedit_mana = static_cast<sh_int>(row[7] ? std::atoi(row[7]) : 0);
		pool.overedit_move = static_cast<sh_int>(row[8] ? std::atoi(row[8]) : 0);
		pool.overedit_hp_regen = static_cast<sh_int>(row[9] ? std::atoi(row[9]) : 0);
		pool.overedit_mana_regen =
			static_cast<sh_int>(row[10] ? std::atoi(row[10]) : 0);
		pool.overedit_move_regen =
			static_cast<sh_int>(row[11] ? std::atoi(row[11]) : 0);
		mysql_free_result(res);
		return true;
	}
	catch(...) {
		return false;
	}
}

[[nodiscard]] Json pool_to_json(const char_edit_pool_data& pool) {
	Json j;
	j["hit"] = pool.edit_hp;
	j["mana"] = pool.edit_mana;
	j["move"] = pool.edit_move;
	j["hit_regen"] = pool.edit_hp_regen;
	j["mana_regen"] = pool.edit_mana_regen;
	j["move_regen"] = pool.edit_move_regen;
	j["over_hit"] = pool.overedit_hp;
	j["over_mana"] = pool.overedit_mana;
	j["over_move"] = pool.overedit_move;
	j["over_hit_regen"] = pool.overedit_hp_regen;
	j["over_mana_regen"] = pool.overedit_mana_regen;
	j["over_move_regen"] = pool.overedit_move_regen;
	Json caps = Json::object();
	caps["hit"] = kEditPoolMaxHit;
	caps["mana"] = kEditPoolMaxMana;
	caps["move"] = kEditPoolMaxMove;
	caps["hit_regen"] = kEditPoolMaxHitRegen;
	caps["mana_regen"] = kEditPoolMaxManaRegen;
	caps["move_regen"] = kEditPoolMaxMoveRegen;
	j["caps"] = caps;
	return j;
}

[[nodiscard]] std::string handle_internal(const std::string& path,
										  const std::string& body) {
	try {
		const Json req = body.empty() ? Json::object() : Json::parse(body);

		if(path == "/internal/ping") {
			Json d;
			d["service"] = "myst-edit-api";
			d[kEditPortalApiVersionTag] = kEditPortalApiVersion;
			return json_ok(d);
		}

		if(path == "/internal/is-online") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const std::string name = toon_name_by_id(toon_id);
			Json d;
			d["toon_id"] = toon_id;
			d["online"] = is_toon_online_by_name(name);
			return json_ok(d);
		}

		if(path == "/internal/max-level") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			Json d;
			d["toon_id"] = toon_id;
			d["max_level"] = max_level_for_toon(toon_id);
			return json_ok(d);
		}

		if(path == "/internal/get-edit-catalog") {
			Json cfg;
			try {
				cfg = Json::parse(edit_system_config_to_json());
			}
			catch(...) {
				cfg = Json::object();
			}
			Json entries = Json::array();
			if(cfg.find("entries") != cfg.end() && cfg["entries"].is_array()) {
				for(const auto& e : cfg["entries"]) {
					if(!e.value("enabled", true)) {
						continue;
					}
					Json out = e;
					const std::string kind = e.value("kind", "");
					if(kind == "pool") {
						const std::string field = e.value("pool_field", "");
						EditPoolField pf {};
						if(edit_pool_parse_field_key(field.c_str(), pf)) {
							out["step"] = edit_pool_field_step(pf);
							out["cap"] = edit_pool_field_cap(pf);
							const edit_pool_quote step_quote =
								edit_pool_quote_delta(pf, edit_pool_field_step(pf));
							out["mxp_per_step"] = step_quote.mxp;
							out["mxp_frac_per_step"] = step_quote.mxp_frac;
							out["pq_per_step"] = step_quote.pq;
						}
					}
					if(kind == "resistance") {
						out["min"] = -100;
						out["max"] = 100;
						out["step"] = 25;
					}
					entries.push_back(out);
				}
			}
			Json d;
			d["entries"] = entries;
			d["pq_per_mega_xp"] = kEditPoolPqPerMegaXp;
			return json_ok(d);
		}

		if(path == "/internal/get-character-state") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			if(toon_id == 0) {
				return json_error("toon_id richiesto", 400);
			}
			int exp = 0;
			int rune = 0;
			const bool has_stats = load_stats_for_toon(toon_id, exp, rune);
			const int max_level = max_level_for_toon(toon_id);
			const long long prince_reserve =
				(max_level >= PRINCIPE) ? static_cast<long long>(PRINCEEXP) : 0LL;
			const long long available_xp =
				has_stats ? (static_cast<long long>(exp) - prince_reserve) : 0LL;

			char_edit_pool_data pool {};
			if(has_stats) {
				(void)load_edit_pool_for_toon(toon_id, pool);
			}

			Json resistances = Json::array();
			DB* db = Sql::getMysql();
			if(db) {
				try {
					odb::connection_ptr cp(db->connection());
					auto& mc = static_cast<odb::mysql::connection&>(*cp);
					MYSQL* h = mc.handle();
					const std::string sql =
						"SELECT damage_type, value FROM character_resistance WHERE toon_id = " +
						std::to_string(toon_id) + " ORDER BY damage_type";
					if(mysql_query(h, sql.c_str()) == 0) {
						MYSQL_RES* res = mysql_store_result(h);
						if(res) {
							MYSQL_ROW row;
							while((row = mysql_fetch_row(res))) {
								Json r;
								r["damage_type"] = row[0] ? std::atoi(row[0]) : 0;
								r["value"] = row[1] ? std::atoi(row[1]) : 0;
								resistances.push_back(r);
							}
							mysql_free_result(res);
						}
					}
				}
				catch(...) {
					/* resistenze opzionali */
				}
			}

			Json d;
			d["toon_id"] = toon_id;
			d["name"] = toon_name_by_id(toon_id);
			d["max_level"] = max_level;
			d["exp"] = exp;
			d["rune"] = rune;
			d["available_xp"] = available_xp;
			d["available_mxp"] = available_xp / 1000000L;
			d["available_mxp_frac"] = (available_xp % 1000000L) / 10000L;
			d["prince_reserve_mxp"] = prince_reserve / 1000000L;
			d["pool"] = pool_to_json(pool);
			d["resistances"] = resistances;
			d["stats_missing"] = !has_stats;
			if(!has_stats) {
				d["warning"] =
					"Nessuna riga in character_stats per questo toon (PG non migrato "
					"o mai creato via login/import). Inventario consultabile; "
					"pagamenti edit bloccati finche' non esiste character_stats.";
			}
			return json_ok(d);
		}

		if(path == "/internal/quote-pool") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const std::string field = req.value("field", "");
			EditPoolField pool_field {};
			if(toon_id == 0 || !edit_pool_parse_field_key(field.c_str(), pool_field)) {
				return json_error("toon_id e campo pool valido richiesti", 400);
			}
			if(!edit_system_pool_enabled(field.c_str())) {
				return json_error("campo pool disabilitato in edit_system.json", 400);
			}
			if(edit_system_pool_target(field.c_str()) != EditSystemTarget::Character) {
				return json_error("campo pool non configurato sul personaggio", 400);
			}

			char_edit_pool_data pool {};
			if(!load_edit_pool_for_toon(toon_id, pool)) {
				return json_error("character_stats non trovato", 404);
			}

			const int current = pool_field_current(pool, pool_field);
			const int target = req.find("new_value") != req.end()
								   ? parse_json_int(req, "new_value", current)
								   : current + parse_json_int(req, "delta", 0);
			const int delta = target - current;
			if(delta == 0) {
				Json d = quote_from_pool(edit_pool_quote {});
				d["field"] = field;
				d["current"] = current;
				d["target"] = target;
				d["delta"] = 0;
				return json_ok(d);
			}

			const edit_pool_quote quote = edit_pool_quote_delta(pool_field, delta);
			Json d = quote_from_pool(quote);
			d["field"] = field;
			d["current"] = current;
			d["target"] = target;
			d["delta"] = delta;
			return json_ok(d);
		}

		if(path == "/internal/quote-resistance") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const unsigned damage_type =
				static_cast<unsigned>(parse_json_int(req, "damage_type", 0));
			const int target_value = parse_json_int(req, "value", 0);
			if(toon_id == 0 || damage_type == 0) {
				return json_error("toon_id e damage_type richiesti", 400);
			}
			if(!edit_system_resistance_enabled(damage_type)) {
				return json_error("resistenza disabilitata in edit_system.json", 400);
			}
			if(edit_system_resistance_target(damage_type) != EditSystemTarget::Character) {
				return json_error("resistenza non configurata sul personaggio", 400);
			}

			int current = 0;
			DB* db = Sql::getMysql();
			if(db) {
				try {
					odb::connection_ptr cp(db->connection());
					auto& mc = static_cast<odb::mysql::connection&>(*cp);
					MYSQL* h = mc.handle();
					const std::string sql =
						"SELECT value FROM character_resistance WHERE toon_id = " +
						std::to_string(toon_id) + " AND damage_type = " +
						std::to_string(damage_type) + " LIMIT 1";
					if(mysql_query(h, sql.c_str()) == 0) {
						MYSQL_RES* res = mysql_store_result(h);
						if(res) {
							MYSQL_ROW row = mysql_fetch_row(res);
							if(row && row[0]) {
								current = std::atoi(row[0]);
							}
							mysql_free_result(res);
						}
					}
				}
				catch(...) {
					/* default current 0 */
				}
			}

			const int delta = target_value - current;
			const long xp_raw =
				static_cast<long>(std::abs(delta)) * resistance_bit_xp_raw(damage_type) /
				100L * kObjValueStorageScale;
			Json d = quote_xp_json(xp_raw);
			d["damage_type"] = damage_type;
			d["current"] = current;
			d["target"] = target_value;
			d["delta"] = delta;
			return json_ok(d);
		}

		if(path == "/internal/list-inventory") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			if(toon_id == 0) {
				return json_error("toon_id richiesto", 400);
			}
			const std::string toon_name = toon_name_by_id(toon_id);
			std::vector<inventory_mysql_row> rows;
			if(!load_character_inventory_mysql(toon_id, rows)) {
				return json_error("impossibile leggere character_inventory da MySQL", 500);
			}
			Json items = Json::array();
			int editable_count = 0;
			const bool toon_name_ok = !toon_name.empty();
			for(const auto& r : rows) {
				struct obj_data* obj = materialize_inventory_row(r);
				if(obj && !object_portal_show_in_inventory_list(obj, toon_name.c_str())) {
					extract_obj(obj);
					continue;
				}

				Json it;
				it["inventory_id"] = r.id;
				it["list_index"] = r.list_index;
				it["parent_inventory_id"] = r.parent_inventory_id;
				it["instance_id"] = r.instance_id;
				it["item_number"] = r.elem.item_number;
				it["short_desc"] = r.elem.sd;
				it["name"] = r.elem.name;
				it["wear_pos"] = r.elem.wearpos;
				it["depth"] = r.elem.depth;
				it["worn"] = inventory_row_is_worn(r.elem.wearpos);

				if(obj) {
					const char* type_slug = object_portal_item_type_slug(ITEM_TYPE(obj));
					if(type_slug) {
						it["item_type"] = type_slug;
					}
					else if(IS_OBJ_STAT2(obj, ITEM2_EDIT)) {
						it["item_type"] = "edited";
					}
				}

				std::string skip_reason;
				bool editable = false;
				if(!toon_name_ok) {
					skip_reason = "PG non risolto in myst (toon_id)";
				}
				else if(!obj) {
					skip_reason = "non materializzabile";
				}
				else if(inventory_row_is_worn(r.elem.wearpos) &&
						!object_portal_allows_worn_edit(obj)) {
					skip_reason = "indossato (primo edit: togli e metti in inventario)";
				}
				else if(object_is_tanned(obj)) {
					skip_reason = "conciato (skill tan)";
				}
				else if(object_portal_editable(obj, toon_name.c_str())) {
					editable = true;
					const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
					if(slug) {
						it["item_type"] = slug;
						it["portal_category"] = slug;
					}
					else {
						it["item_type"] = "other";
						it["portal_category"] = "edited";
					}
				}
				else {
					skip_reason = object_portal_skip_reason(obj, toon_name.c_str());
				}

				if(obj) {
					extract_obj(obj);
				}

				it["editable"] = editable;
				if(!skip_reason.empty()) {
					it["skip_reason"] = skip_reason;
				}
				if(editable) {
					++editable_count;
				}
				items.push_back(it);
			}
			Json d;
			d["items"] = items;
			d["total"] = items.size();
			d["editable_count"] = editable_count;
			d["loaded_rows"] = rows.size();
			d["toon_id"] = toon_id;
			d["toon_name"] = toon_name;
			d["toon_name_ok"] = toon_name_ok;
			return json_ok(d);
		}

		if(path == "/internal/get-object-edit-options") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const unsigned long long inventory_id = parse_json_ull(req, "inventory_id");
			const std::string toon_name = toon_name_by_id(toon_id);
			if(toon_name.empty()) {
				return json_error("toon non trovato", 404);
			}

			std::vector<inventory_mysql_row> rows;
			load_character_inventory_mysql(toon_id, rows);
			inventory_mysql_row* row = find_inventory_row(rows, inventory_id);
			if(!row) {
				return json_error("oggetto non trovato nell'inventario del toon", 404);
			}

			struct obj_data* obj = materialize_inventory_row(*row);
			if(!obj) {
				return json_error("impossibile materializzare oggetto", 500);
			}
			if(inventory_row_is_worn(row->elem.wearpos) &&
			   !object_portal_allows_worn_edit(obj)) {
				extract_obj(obj);
				return json_error(
					"l'oggetto e indossato: per il primo edit rimuovilo e mettilo in inventario "
					"(i pezzi gia editati si possono ri-editare anche indossati)",
					400);
			}
			if(!object_portal_editable(obj, toon_name.c_str())) {
				extract_obj(obj);
				return json_error("oggetto non editabile (RARO, tan, tipo o owner)", 400);
			}

			const int item_type = ITEM_TYPE(obj);
			const bool is_armor =
				item_type == ITEM_ARMOR || item_type == ITEM_WORN;
			const bool is_weapon =
				item_type == ITEM_WEAPON || item_type == ITEM_FIREWEAPON ||
				item_type == ITEM_MISSILE;
			Json entries = object_edit_catalog_json(obj);
			for(auto& e : entries) {
				const std::string kind = e.value("kind", "");
				if(kind == "scalar") {
					const int loc = e.value("location", 0);
					e["current"] = object_edit_display_current(obj, loc);
				}
				else if(kind == "immune" || kind == "m_immune") {
					const unsigned bit =
						static_cast<unsigned>(e.value("immune_bit", 0U));
					const int loc = e.value("location", APPLY_IMMUNE);
					const int bits = (loc == APPLY_M_IMMUNE)
										 ? object_m_immune_current_bits(obj)
										 : object_immune_current_bits(obj);
					e["current"] = (bits & static_cast<int>(bit)) ? 1 : 0;
				}
				else if(kind == "spell") {
					const int loc = e.value("location", APPLY_SPELL);
					const unsigned long bit = e.value("spell_bit", 0UL);
					const int bits =
						(loc == APPLY_AFF2) ? object_aff2_current_bits(obj)
											: object_spell_current_bits(obj);
					e["current"] = (bits & static_cast<int>(bit)) ? 1 : 0;
				}
				else if(kind == "flag" && e.value("flag", "") == "artifact") {
					e["current"] = IS_OBJ_STAT(obj, ITEM_IMMUNE) ? 1 : 0;
				}
			}

			Json d = analyze_to_json(obj);
			d["entries"] = entries;
			d["affect_slots"] = object_affect_slots_json(obj);
			d["inventory_id"] = inventory_id;
			d["short_desc"] = row->elem.sd;
			{
				const int piece_delta = object_edit_damroll_edited_delta(obj);
				const bool piece_worn = inventory_row_is_worn(row->elem.wearpos);
				const bool piece_edit = object_edit_counts_toward_combat_budget(
					obj, toon_name.c_str());
				const int other_dam = sum_owned_edited_damroll_excluding(
					rows, inventory_id, toon_name.c_str());
				const int piece_for_total = piece_edit ? piece_delta : 0;

				Json dam_budget;
				dam_budget["piece"] = piece_delta;
				dam_budget["piece_current"] = object_edit_damroll_total(obj);
				dam_budget["piece_proto"] = object_edit_damroll_prototype_total(obj);
				dam_budget["piece_proto_vnum"] = object_edit_prototype_vnum(obj);
				dam_budget["piece_worn"] = piece_worn;
				dam_budget["piece_edit"] = piece_edit;
				dam_budget["piece_max"] = kObjEditMaxDamrollPerPiece;
				dam_budget["other"] = other_dam;
				dam_budget["char_total"] = other_dam + piece_for_total;
				dam_budget["char_max"] = kObjEditMaxDamrollEditableTotal;
				dam_budget["source"] = "owned_edit_delta_vs_proto";
				dam_budget["contributors"] =
					owned_dam_budget_contributors_json(rows, toon_name.c_str());
				d["dam_budget"] = dam_budget;

				const int piece_sp_delta = object_edit_spellpower_edited_delta(obj);
				const int other_sp = sum_owned_edited_spellpower_excluding(
					rows, inventory_id, toon_name.c_str());
				const int piece_sp_for_total = piece_edit ? piece_sp_delta : 0;
				Json sp_budget;
				sp_budget["piece"] = piece_sp_delta;
				sp_budget["piece_current"] = object_edit_spellpower_total(obj);
				sp_budget["piece_max"] = kObjEditMaxSpellpowerPerPiece;
				sp_budget["other"] = other_sp;
				sp_budget["char_total"] = other_sp + piece_sp_for_total;
				sp_budget["char_max"] = kObjEditMaxSpellpowerEditableTotal;
				sp_budget["source"] = "owned_edit_delta_vs_proto";
				d["sp_budget"] = sp_budget;
			}
			{
				/* Sempre editabile in UI: si salva solo insieme a un affect pagato
				 * (stesso apply), mai come passo successivo gratuito. */
				Json text;
				text["can_edit"] = true;
				text["requires_paid_affect"] = true;
				text["name"] = obj->name ? obj->name : "";
				text["short_desc"] =
					obj->short_description ? obj->short_description : "";
				text["description"] = obj->description ? obj->description : "";
				text["name_max"] = kObjEditTextNameMax;
				text["short_max"] = kObjEditTextShortMax;
				text["long_max"] = kObjEditTextLongMax;
				text["hint"] =
					"Name / short / long: gratuiti ma solo insieme al pagamento "
					"di un nuovo affect (stesso salvataggio). Non si salvano da soli.";
				d["text_edit"] = text;
			}
			if(is_armor && is_weapon) {
				d["item_type"] = "armor+weapon";
			}
			else if(is_armor) {
				d["item_type"] = "armor";
			}
			else if(is_weapon) {
				d["item_type"] = "weapon";
			}
			else {
				d["item_type"] = "other";
			}
			extract_obj(obj);
			return json_ok(d);
		}

		if(path == "/internal/quote-object-edit") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const unsigned long long inventory_id = parse_json_ull(req, "inventory_id");
			const int location = parse_json_int(req, "location", 0);
			const int target_modifier =
				req.find("target_modifier") != req.end()
					? parse_json_int(req, "target_modifier", 0)
					: parse_json_int(req, "modifier", 0);
			const std::string flag = req.value("flag", "");

			const std::string toon_name = toon_name_by_id(toon_id);
			if(toon_name.empty()) {
				return json_error("toon non trovato", 404);
			}

			std::vector<inventory_mysql_row> rows;
			load_character_inventory_mysql(toon_id, rows);
			inventory_mysql_row* row = find_inventory_row(rows, inventory_id);
			if(!row) {
				return json_error("oggetto non trovato nell'inventario del toon", 404);
			}

			struct obj_data* obj = materialize_inventory_row(*row);
			if(!obj) {
				return json_error("impossibile materializzare oggetto", 500);
			}
			if(inventory_row_is_worn(row->elem.wearpos) &&
			   !object_portal_allows_worn_edit(obj)) {
				extract_obj(obj);
				return json_error(
					"l'oggetto e indossato: per il primo edit rimuovilo e mettilo in inventario "
					"(i pezzi gia editati si possono ri-editare anche indossati)",
					400);
			}
			if(!object_portal_editable(obj, toon_name.c_str())) {
				extract_obj(obj);
				return json_error("oggetto non editabile (RARO, tan, tipo o owner)", 400);
			}

			if(flag == "artifact") {
				const int current = IS_OBJ_STAT(obj, ITEM_IMMUNE) ? 1 : 0;
				const int target = target_modifier ? 1 : 0;
				if(current && !target) {
					extract_obj(obj);
					return json_error(
						"Artifact non rimovibile una volta impostato", 400);
				}
				Json d = quote_xp_json(0, 0);
				d["location"] = 0;
				d["flag"] = "artifact";
				d["target_modifier"] = target;
				d["current"] = current;
				d["target"] = target;
				d["inventory_id"] = inventory_id;
				d["note"] =
					target
						? "Artifact: flag gratis; +50% sul costo finale di questo edit "
						  "(gia' presente o aggiunto nello stesso pacchetto)"
						: "Artifact invariato";
				extract_obj(obj);
				return json_ok(d);
			}

			/* Listino: +50% se pezzo gia' Artifact OPPURE Artifact e' in coda
			 * nello stesso edit (pending_artifact dal carrello portal). */
			const bool pending_artifact =
				parse_json_int(req, "pending_artifact", 0) != 0;
			if(pending_artifact || IS_OBJ_STAT(obj, ITEM_IMMUNE)) {
				SET_BIT(obj->obj_flags.extra_flags, ITEM_IMMUNE);
			}

			long xp_raw = 0;
			int pq = 0;
			std::string quote_err;
			const int other_dam =
				object_edit_location_affects_dam(location)
					? sum_owned_edited_damroll_excluding(rows, inventory_id,
														toon_name.c_str())
					: -1;
			const int other_sp =
				object_edit_location_affects_spellpower(location)
					? sum_owned_edited_spellpower_excluding(rows, inventory_id,
														   toon_name.c_str())
					: -1;
			if(!object_quote_affect_target(obj, location, target_modifier, xp_raw, pq,
										   quote_err, other_dam, other_sp)) {
				extract_obj(obj);
				return json_error(quote_err.c_str(), 400);
			}

			int current = 0;
			int target = target_modifier;
			if(location == APPLY_IMMUNE || location == APPLY_M_IMMUNE) {
				const int bits = (location == APPLY_M_IMMUNE)
									 ? object_m_immune_current_bits(obj)
									 : object_immune_current_bits(obj);
				current = (bits & target_modifier) ? 1 : 0;
				target = current ? 1 : (target_modifier != 0 ? 1 : 0);
			}
			else if(location == APPLY_SPELL || location == APPLY_AFF2) {
				const int bits = (location == APPLY_AFF2)
									 ? object_aff2_current_bits(obj)
									 : object_spell_current_bits(obj);
				current = (bits & target_modifier) ? 1 : 0;
				target = current ? 1 : (target_modifier != 0 ? 1 : 0);
			}
			else {
				current = object_edit_display_current(obj, location);
			}

			Json d = quote_xp_json(xp_raw, pq);
			d["location"] = location;
			d["target_modifier"] = target_modifier;
			d["current"] = current;
			d["target"] = target;
			d["inventory_id"] = inventory_id;
			d["artifact"] = IS_OBJ_STAT(obj, ITEM_IMMUNE) ? 1 : 0;
			d["pending_artifact"] = pending_artifact ? 1 : 0;
			if(IS_OBJ_STAT(obj, ITEM_IMMUNE) && xp_raw > 0) {
				d["note"] = "Include maggiorazione Artifact +50% (listino)";
			}
			extract_obj(obj);
			return json_ok(d);
		}

		if(path == "/internal/quote-item") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			const unsigned long long inventory_id = parse_json_ull(req, "inventory_id");
			std::vector<inventory_mysql_row> rows;
			load_character_inventory_mysql(toon_id, rows);
			inventory_mysql_row* row = find_inventory_row(rows, inventory_id);
			if(!row) {
				return json_error("oggetto non trovato nell'inventario del toon", 404);
			}
			struct obj_data* obj = materialize_inventory_row(*row);
			if(!obj) {
				return json_error("impossibile materializzare oggetto", 500);
			}
			Json d = analyze_to_json(obj);
			extract_obj(obj);
			return json_ok(d);
		}

		if(path == "/internal/apply-affect") {
			const unsigned long long target_toon_id = parse_json_ull(req, "target_toon_id");
			const unsigned long long inventory_id = parse_json_ull(req, "inventory_id");
			const int location = parse_json_int(req, "location", 0);
			const int target_modifier =
				req.find("target_modifier") != req.end()
					? parse_json_int(req, "target_modifier", 0)
					: parse_json_int(req, "modifier", 0);
			const int pay_xp = parse_json_int(req, "pay_xp", 0);
			const int pay_rune = parse_json_int(req, "pay_rune", 0);
			const std::string flag = req.value("flag", "");

			const std::string target_name = toon_name_by_id(target_toon_id);
			if(target_name.empty()) {
				return json_error("toon target non trovato", 404);
			}
			if(is_toon_online_by_name(target_name)) {
				return json_error("il toon target e collegato al mud", 409);
			}

			if(flag.empty() &&
			   edit_system_blocked_on_object(location, target_modifier)) {
				if(location == APPLY_IMMUNE || location == APPLY_M_IMMUNE ||
				   location == APPLY_SUSC) {
					return json_error(
						"questa resistenza e configurata sul personaggio — usa apply-resistance",
						400);
				}
				if(edit_pool_is_pool_apply(location)) {
					return json_error(
						"hit/mana/move/regen vanno sul personaggio (edit pool), non sull'oggetto",
						400);
				}
				return json_error("campo configurato sul personaggio, non sull'oggetto", 400);
			}

			std::vector<inventory_mysql_row> rows;
			load_character_inventory_mysql(target_toon_id, rows);
			inventory_mysql_row* row = find_inventory_row(rows, inventory_id);
			if(!row) {
				return json_error("oggetto non trovato nell'inventario", 404);
			}

			struct obj_data* obj = materialize_inventory_row(*row);
			if(!obj) {
				return json_error("impossibile materializzare oggetto", 500);
			}
			if(inventory_row_is_worn(row->elem.wearpos) &&
			   !object_portal_allows_worn_edit(obj)) {
				extract_obj(obj);
				return json_error(
					"l'oggetto e indossato: per il primo edit rimuovilo e mettilo in inventario "
					"(i pezzi gia editati si possono ri-editare anche indossati)",
					400);
			}
			if(!object_portal_editable(obj, target_name.c_str())) {
				extract_obj(obj);
				return json_error("oggetto non editabile (RARO, tan, tipo o owner)", 400);
			}

			if(flag == "artifact") {
				const bool already = IS_OBJ_STAT(obj, ITEM_IMMUNE);
				if(already && !target_modifier) {
					extract_obj(obj);
					return json_error(
						"Artifact non rimovibile una volta impostato", 400);
				}
				if(already && target_modifier) {
					/* Gia' artifact: no-op (flag permanente). */
					Json d = analyze_to_json(obj);
					d["paid_xp"] = 0;
					d["paid_rune"] = 0;
					d["saved"] = true;
					d["flag"] = "artifact";
					d["artifact"] = 1;
					d["instance_id"] = obj->db_instance_id;
					d["base_vnum"] = object_instance_resolve_base_vnum(obj);
					extract_obj(obj);
					(void)pay_xp;
					(void)pay_rune;
					return json_ok(d);
				}
				if(!target_modifier) {
					extract_obj(obj);
					return json_error("Artifact: specificare target_modifier=1 per attivare",
									  400);
				}
				struct obj_data* after = materialize_inventory_row(*row);
				if(!after) {
					extract_obj(obj);
					return json_error("impossibile clonare oggetto", 500);
				}
				extract_obj(obj);
				SET_BIT(after->obj_flags.extra_flags, ITEM_IMMUNE);
				if(!IS_OBJ_STAT2(after, ITEM2_EDIT)) {
					SET_BIT(after->obj_flags.extra_flags2, ITEM2_EDIT);
				}
				/* Artifact gratis: eventuale testo in body e' rifiutato
				 * (serve un affect pagato nello stesso apply). */
				bool text_changed = false;
				std::string text_err;
				if(!portal_apply_optional_text_fields(after, req, /*affect_is_paid=*/false,
													  text_err, text_changed)) {
					extract_obj(after);
					return json_error(text_err.c_str(), 400);
				}
				/* Flag gratis; il +50% e' sul costo degli edit pagati (stesso
				 * pacchetto o successivi) via AnalyzeObjEdit. */
				std::string save_err;
				const bool saved = portal_save_edited_inventory_item(
					inventory_id, after, save_err, target_name.c_str());
				Json d = analyze_to_json(after);
				d["paid_xp"] = 0;
				d["paid_rune"] = 0;
				d["saved"] = saved;
				d["flag"] = "artifact";
				d["artifact"] = IS_OBJ_STAT(after, ITEM_IMMUNE) ? 1 : 0;
				d["instance_id"] = after->db_instance_id;
				d["base_vnum"] = object_instance_resolve_base_vnum(after);
				extract_obj(after);
				if(!saved) {
					return json_error(save_err.empty()
										  ? "[portal:save] salvataggio flag artifact fallito"
										  : save_err.c_str(),
									  500);
				}
				(void)pay_xp;
				(void)pay_rune;
				return json_ok(d);
			}

			long quote_xp = 0;
			int quote_pq = 0;
			std::string quote_err;
			const int other_dam =
				object_edit_location_affects_dam(location)
					? sum_owned_edited_damroll_excluding(rows, inventory_id,
														target_name.c_str())
					: -1;
			const int other_sp =
				object_edit_location_affects_spellpower(location)
					? sum_owned_edited_spellpower_excluding(rows, inventory_id,
														   target_name.c_str())
					: -1;
			if(!object_quote_affect_target(obj, location, target_modifier, quote_xp,
										   quote_pq, quote_err, other_dam, other_sp)) {
				extract_obj(obj);
				return json_error(quote_err.c_str(), 400);
			}

			struct obj_data* after = materialize_inventory_row(*row);
			if(!after) {
				extract_obj(obj);
				return json_error("impossibile clonare oggetto", 500);
			}
			extract_obj(obj);

			std::string apply_err;
			if(!object_apply_affect_target(after, location, target_modifier, apply_err,
										   other_dam, other_sp)) {
				extract_obj(after);
				return json_error(apply_err.c_str(), 400);
			}
			if(!IS_OBJ_STAT2(after, ITEM2_EDIT)) {
				SET_BIT(after->obj_flags.extra_flags2, ITEM2_EDIT);
			}

			/* Pagamento: XP e/o Rune coprono il listino (1 MXP = 1 Rune). */
			int xp_cost = 0;
			int rune_cost = 0;
			std::string pay_resolve_err;
			if(!resolve_object_edit_payment(pay_xp, pay_rune, quote_xp, quote_pq, xp_cost,
										   rune_cost, pay_resolve_err)) {
				extract_obj(after);
				return json_error(pay_resolve_err.c_str(), 402);
			}
			const int quote_xp_i = static_cast<int>(std::max(0L, quote_xp));
			const bool affect_is_paid = (quote_xp_i > 0) || (quote_pq > 0) ||
										(xp_cost > 0) || (rune_cost > 0);

			bool text_changed = false;
			std::string text_err;
			if(!portal_apply_optional_text_fields(after, req, affect_is_paid, text_err,
												  text_changed)) {
				extract_obj(after);
				return json_error(text_err.c_str(), 400);
			}

			const int max_level = max_level_for_toon(target_toon_id);
			std::string pay_err;
			if(!deduct_payment(target_toon_id, xp_cost, rune_cost, max_level, pay_err)) {
				extract_obj(after);
				return json_error(pay_err.c_str(), 402);
			}

			std::string save_err;
			const bool saved = portal_save_edited_inventory_item(
				inventory_id, after, save_err, target_name.c_str());

			Json d = analyze_to_json(after);
			d["paid_xp"] = xp_cost;
			d["paid_rune"] = rune_cost;
			d["saved"] = saved;
			d["text_changed"] = text_changed;
			d["instance_id"] = after->db_instance_id;
			d["base_vnum"] = object_instance_resolve_base_vnum(after);
			if(!save_err.empty()) {
				d["save_err"] = save_err;
			}
			extract_obj(after);

			if(!saved) {
				return json_error(save_err.empty()
									  ? "[portal:save] pagamento eseguito ma salvataggio fallito"
									  : save_err.c_str(),
								  500);
			}
			return json_ok(d);
		}

		if(path == "/internal/quote-object-text" ||
		   path == "/internal/apply-object-text") {
			return json_error(
				"name/short/long non si salvano da soli: includili nel pagamento "
				"di un nuovo affect (apply-affect)",
				400);
		}

		if(path == "/internal/apply-pool") {
			const unsigned long long target_toon_id = parse_json_ull(req, "target_toon_id");
			const std::string field = req.value("field", "");
			int pay_xp = parse_json_int(req, "pay_xp", 0);
			const int pay_rune = parse_json_int(req, "pay_rune", 0);

			const std::string target_name = toon_name_by_id(target_toon_id);
			if(target_name.empty()) {
				return json_error("toon target non trovato", 404);
			}
			if(is_toon_online_by_name(target_name)) {
				return json_error("il toon target e collegato al mud", 409);
			}

			EditPoolField pool_field {};
			if(!edit_pool_parse_field_key(field.c_str(), pool_field)) {
				return json_error("campo pool non valido", 400);
			}

			if(!edit_system_pool_enabled(field.c_str())) {
				return json_error("campo pool disabilitato in edit_system.json", 400);
			}
			if(edit_system_pool_target(field.c_str()) != EditSystemTarget::Character) {
				return json_error(
					"campo pool configurato sull'oggetto — usa apply-affect (APPLY)", 400);
			}

			DB* db = Sql::getMysql();
			if(!db) {
				return json_error("database non disponibile", 500);
			}

			char_edit_pool_data pool {};
			if(!load_edit_pool_for_toon(target_toon_id, pool)) {
				return json_error("character_stats non trovato", 404);
			}

			const int current = pool_field_current(pool, pool_field);
			const int target = req.find("new_value") != req.end()
								   ? parse_json_int(req, "new_value", current)
								   : current + parse_json_int(req, "delta", 0);
			const int delta = target - current;
			if(delta == 0) {
				return json_error("nessuna modifica al pool", 400);
			}

			if(pay_xp == 0 && pay_rune == 0) {
				const edit_pool_quote quote = edit_pool_quote_delta(pool_field, delta);
				pay_xp = static_cast<int>(quote.xp_raw);
			}

			if(!edit_pool_add_delta(&pool, pool_field, delta)) {
				return json_error("delta pool rifiutato (cap listino)", 400);
			}

			const int max_level = max_level_for_toon(target_toon_id);
			std::string pay_err;
			if(!deduct_payment(target_toon_id, pay_xp, pay_rune, max_level, pay_err)) {
				return json_error(pay_err.c_str(), 402);
			}

			try {
				std::ostringstream upd;
				upd << "UPDATE character_stats SET edit_hp=" << pool.edit_hp
					<< ", edit_mana=" << pool.edit_mana << ", edit_move=" << pool.edit_move
					<< ", edit_hp_regen=" << pool.edit_hp_regen
					<< ", edit_mana_regen=" << pool.edit_mana_regen
					<< ", edit_move_regen=" << pool.edit_move_regen
					<< ", overedit_hp=" << pool.overedit_hp
					<< ", overedit_mana=" << pool.overedit_mana
					<< ", overedit_move=" << pool.overedit_move
					<< ", overedit_hp_regen=" << pool.overedit_hp_regen
					<< ", overedit_mana_regen=" << pool.overedit_mana_regen
					<< ", overedit_move_regen=" << pool.overedit_move_regen
					<< ", edit_pool_migrated=1 WHERE toon_id = " << target_toon_id;
				std::string sql_err;
				if(!portal_mysql_exec(db, upd.str(), sql_err, "portal:apply_pool")) {
					return json_error(sql_err.c_str(), 500);
				}
			}
			catch(const std::exception& e) {
				return json_error(
					(std::string("[portal:apply_pool] ") + e.what()).c_str(), 500);
			}

			Json d;
			d["edit_hp"] = pool.edit_hp;
			d["edit_mana"] = pool.edit_mana;
			d["edit_move"] = pool.edit_move;
			d["edit_hp_regen"] = pool.edit_hp_regen;
			d["edit_mana_regen"] = pool.edit_mana_regen;
			d["edit_move_regen"] = pool.edit_move_regen;
			d["paid_xp"] = pay_xp;
			d["paid_rune"] = pay_rune;
			return json_ok(d);
		}

		if(path == "/internal/apply-resistance") {
			const unsigned long long target_toon_id = parse_json_ull(req, "target_toon_id");
			const unsigned damage_type =
				static_cast<unsigned>(parse_json_int(req, "damage_type", 0));
			const int value = parse_json_int(req, "value", 0);
			const int pay_xp = parse_json_int(req, "pay_xp", 0);
			const int pay_rune = parse_json_int(req, "pay_rune", 0);

			const std::string target_name = toon_name_by_id(target_toon_id);
			if(target_name.empty()) {
				return json_error("toon target non trovato", 404);
			}
			if(is_toon_online_by_name(target_name)) {
				return json_error("il toon target e collegato al mud", 409);
			}
			if(damage_type == 0) {
				return json_error("damage_type (bit IMM_*) richiesto", 400);
			}
			if(!edit_system_resistance_enabled(damage_type)) {
				return json_error("resistenza disabilitata in edit_system.json", 400);
			}
			if(edit_system_resistance_target(damage_type) != EditSystemTarget::Character) {
				return json_error(
					"resistenza configurata sull'oggetto — usa apply-affect (APPLY_IMMUNE)", 400);
			}

			DB* db = Sql::getMysql();
			if(!db) {
				return json_error("database non disponibile", 500);
			}

			const int max_level = max_level_for_toon(target_toon_id);
			std::string pay_err;
			if(!deduct_payment(target_toon_id, pay_xp, pay_rune, max_level, pay_err)) {
				return json_error(pay_err.c_str(), 402);
			}

			std::string persist_err;
			if(!legacy_upsert_character_resistance(db, target_toon_id,
												   damage_type, value, persist_err)) {
				return json_error(persist_err.c_str(), 500);
			}

			Json d;
			d["damage_type"] = damage_type;
			d["value"] = value;
			d["paid_xp"] = pay_xp;
			d["paid_rune"] = pay_rune;
			return json_ok(d);
		}

		if(path == "/internal/list-resistances") {
			const unsigned long long toon_id = parse_json_toon_id(req);
			DB* db = Sql::getMysql();
			if(!db || toon_id == 0) {
				return json_error("toon_id richiesto", 400);
			}
			Json rows = Json::array();
			try {
				odb::connection_ptr cp(db->connection());
				auto& mc = static_cast<odb::mysql::connection&>(*cp);
				MYSQL* h = mc.handle();
				const std::string sql =
					"SELECT damage_type, value FROM character_resistance WHERE toon_id = " +
					std::to_string(toon_id) + " ORDER BY damage_type";
				if(mysql_query(h, sql.c_str()) == 0) {
					MYSQL_RES* res = mysql_store_result(h);
					if(res) {
						MYSQL_ROW row;
						while((row = mysql_fetch_row(res))) {
							Json r;
							r["damage_type"] = row[0] ? std::atoi(row[0]) : 0;
							r["value"] = row[1] ? std::atoi(row[1]) : 0;
							rows.push_back(r);
						}
						mysql_free_result(res);
					}
				}
			}
			catch(...) {
				return json_error("lettura character_resistance fallita", 500);
			}
			Json d;
			d["rows"] = rows;
			return json_ok(d);
		}

		if(path == "/internal/get-system-config") {
			Json d;
			d["path"] = edit_system_config_path();
			try {
				d["config"] = Json::parse(edit_system_config_to_json());
			}
			catch(...) {
				d["config"] = Json::object();
			}
			return json_ok(d);
		}

		if(path == "/internal/set-system-config") {
			if(req.find("config") == req.end()) {
				return json_error("config JSON richiesto", 400);
			}
			std::string err;
			const std::string text = req["config"].dump(2);
			if(!edit_system_config_save_json(text, err)) {
				return json_error(err.c_str(), 400);
			}
			Json d;
			d["path"] = edit_system_config_path();
			d["config"] = req["config"];
			return json_ok(d);
		}

		return json_error("endpoint non trovato", 404);
	}
	catch(const std::exception& e) {
		mudlog(LOG_SYSERR, "edit_portal: handle_internal exception: %s", e.what());
		return json_error((std::string("[portal:handle] ") + e.what()).c_str(), 500);
	}
}
#else
[[nodiscard]] std::string handle_internal(const std::string&, const std::string&) {
	return json_error("MySQL non attivo in questa build", 503);
}
#endif

[[nodiscard]] std::string submit_job(const std::string& path, const std::string& body) {
	EditPortalJob job;
	job.path = path;
	job.body = body;
	auto fut = job.response.get_future();
	{
		std::lock_guard<std::mutex> lock(g_queue_mutex);
		g_jobs.push_back(std::move(job));
	}
	g_queue_cv.notify_one();
	if(fut.wait_for(std::chrono::seconds(30)) != std::future_status::ready) {
		return json_error("timeout elaborazione mud", 504);
	}
	return fut.get();
}

void http_thread_main() {
	const int port = api_port();
	const int server_fd = socket(AF_INET, SOCK_STREAM, 0);
	if(server_fd < 0) {
		mudlog(LOG_SYSERR, "edit_portal: socket() failed");
		return;
	}

	sockaddr_in addr {};
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(static_cast<uint16_t>(port));

	if(bind(server_fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
		mudlog(LOG_SYSERR, "edit_portal: bind(%d) failed", port);
		close(server_fd);
		return;
	}
	if(listen(server_fd, 16) < 0) {
		mudlog(LOG_SYSERR, "edit_portal: listen failed");
		close(server_fd);
		return;
	}

	mudlog(LOG_CHECK, "edit_portal: API listening on port %d", port);
	g_http_running = true;

	while(g_http_running) {
		const int client = accept(server_fd, nullptr, nullptr);
		if(client < 0) {
			continue;
		}

		const std::string raw = read_http_request(client);
		if(raw.empty()) {
			close(client);
			continue;
		}

		std::string method;
		std::string path;
		{
			std::istringstream ls(raw);
			ls >> method >> path;
		}
		path = normalize_api_path(path);

		const auto hdr_end = raw.find("\r\n\r\n");
		const std::string headers = hdr_end != std::string::npos
										? raw.substr(0, hdr_end)
										: raw;
		std::string body =
			hdr_end != std::string::npos ? raw.substr(hdr_end + 4) : std::string();

		std::string response_body;
		int status = 200;
		if(!header_has_secret(headers)) {
			response_body = json_error("unauthorized", 401);
			status = 401;
		}
		else if(method != "POST") {
			response_body = json_error("solo POST", 405);
			status = 405;
		}
		else {
			response_body = submit_job(path, body);
			if(response_body.find("\"ok\":false") != std::string::npos) {
				const auto cp = response_body.find("\"code\":");
				if(cp != std::string::npos) {
					status = std::atoi(response_body.c_str() + cp + 7);
				}
			}
		}

		std::ostringstream out;
		out << "HTTP/1.1 " << status << " OK\r\n"
			<< "Content-Type: application/json\r\n"
			<< "Connection: close\r\n"
			<< "Content-Length: " << response_body.size() << "\r\n\r\n"
			<< response_body;
		const std::string packet = out.str();
		write(client, packet.data(), packet.size());
		close(client);
	}

	close(server_fd);
}

} // namespace

void edit_portal_process_pending() {
	std::deque<EditPortalJob> local;
	{
		std::lock_guard<std::mutex> lock(g_queue_mutex);
		local.swap(g_jobs);
	}
	for(auto& job : local) {
		try {
			job.response.set_value(handle_internal(job.path, job.body));
		}
		catch(...) {
			job.response.set_value(json_error("errore interno", 500));
		}
	}
}

void edit_portal_init() {
#if USE_MYSQL
	edit_system_config_init();
	mudlog(LOG_CHECK, "edit_portal: API listening on port %d (%s=%d)",
		   api_port(), kEditPortalApiVersionTag, kEditPortalApiVersion);
	std::thread(http_thread_main).detach();
#else
	mudlog(LOG_CHECK, "edit_portal: disabled (USE_MYSQL=0)");
#endif
}

} // namespace Alarmud
