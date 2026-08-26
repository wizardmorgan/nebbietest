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
#include <chrono>
#include <condition_variable>
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

[[nodiscard]] std::string api_secret() {
	const char* s = std::getenv("EDIT_API_SECRET");
	return s ? std::string(s) : "nebbie-edit-dev-secret";
}

[[nodiscard]] int api_port() {
	const char* p = std::getenv("EDIT_API_PORT");
	if(!p || !*p) {
		return 8090;
	}
	return std::atoi(p);
}

[[nodiscard]] bool header_has_secret(const std::string& headers) {
	const std::string key = "x-edit-api-secret:";
	const auto pos = headers.find(key);
	if(pos == std::string::npos) {
		return false;
	}
	const auto end = headers.find("\r\n", pos);
	std::string value = headers.substr(pos + key.size(), end - pos - key.size());
	while(!value.empty() && (value.front() == ' ' || value.front() == '\t')) {
		value.erase(value.begin());
	}
	return value == api_secret();
}

[[nodiscard]] std::string json_error(const char* msg, int code = 400) {
	Json j;
	j["ok"] = false;
	j["error"] = msg;
	j["code"] = code;
	return j.dump();
}

[[nodiscard]] std::string json_ok(const Json& data) {
	Json j;
	j["ok"] = true;
	j["data"] = data;
	return j.dump();
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
	const toonPtr pg = Sql::getOne<toon>(toonQuery::id == toon_id);
	return pg ? pg->name : std::string();
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
		err = "character_stats non trovato";
		return false;
	}
	const long long prince_reserve =
		(max_level >= PRINCIPE) ? static_cast<long long>(PRINCEEXP) : 0LL;
	const long long available_xp = static_cast<long long>(exp) - prince_reserve;
	if(xp_cost > 0 && available_xp < static_cast<long long>(xp_cost)) {
		err = "XP insufficienti (riserva principi 400M inclusa)";
		return false;
	}
	if(rune_cost > 0 && rune < rune_cost) {
		err = "Rune degli Eroi insufficienti";
		return false;
	}
	DB* db = Sql::getMysql();
	if(!db) {
		err = "database non disponibile";
		return false;
	}
	try {
		std::ostringstream sql;
		sql << "UPDATE character_stats SET exp = exp - " << xp_cost
			<< ", p_rune_dei = p_rune_dei - " << rune_cost << " WHERE toon_id = "
			<< toon_id;
		db->execute(sql.str().c_str());
		return true;
	}
	catch(const std::exception& e) {
		err = e.what();
		return false;
	}
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
	for(int j = 0; j < MAX_OBJ_AFFECT; ++j) {
		obj->affected[j] = row.elem.affected[j];
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

[[nodiscard]] bool persist_inventory_affects(unsigned long long inventory_id,
											 const struct obj_data* obj) {
	DB* db = Sql::getMysql();
	if(!db || !obj) {
		return false;
	}
	try {
		db->execute(("DELETE FROM character_inventory_affect WHERE inventory_id = " +
					 std::to_string(inventory_id))
						.c_str());
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
			db->execute(ins.str().c_str());
		}
		return true;
	}
	catch(...) {
		return false;
	}
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
	return j;
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
	switch(damage_type) {
	case IMM_FIRE:
		return 10000L;
	case IMM_COLD:
	case IMM_ACID:
	case IMM_HOLD:
		return 7500L;
	case IMM_ELEC:
	case IMM_ENERGY:
		return 15000L;
	case IMM_DRAIN:
	case IMM_POISON:
		return 3000L;
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
			return json_ok(d);
		}

		if(path == "/internal/is-online") {
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
			const std::string name = toon_name_by_id(toon_id);
			Json d;
			d["toon_id"] = toon_id;
			d["online"] = is_toon_online_by_name(name);
			return json_ok(d);
		}

		if(path == "/internal/max-level") {
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
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
			d["session_pq_fee"] = kEditPoolSessionPqFee;
			return json_ok(d);
		}

		if(path == "/internal/get-character-state") {
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
			if(toon_id == 0) {
				return json_error("toon_id richiesto", 400);
			}
			int exp = 0;
			int rune = 0;
			if(!load_stats_for_toon(toon_id, exp, rune)) {
				return json_error("character_stats non trovato", 404);
			}
			const int max_level = max_level_for_toon(toon_id);
			const long long prince_reserve =
				(max_level >= PRINCIPE) ? static_cast<long long>(PRINCEEXP) : 0LL;
			const long long available_xp =
				static_cast<long long>(exp) - prince_reserve;

			char_edit_pool_data pool {};
			if(!load_edit_pool_for_toon(toon_id, pool)) {
				return json_error("edit pool non trovato", 404);
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
			d["prince_reserve"] = prince_reserve;
			d["pool"] = pool_to_json(pool);
			d["resistances"] = resistances;
			return json_ok(d);
		}

		if(path == "/internal/quote-pool") {
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
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
								   ? req.value("new_value", current)
								   : current + req.value("delta", 0);
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
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
			const unsigned damage_type =
				static_cast<unsigned>(req.value("damage_type", 0));
			const int target_value = req.value("value", 0);
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
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
			std::vector<inventory_mysql_row> rows;
			load_character_inventory_mysql(toon_id, rows);
			Json items = Json::array();
			for(const auto& r : rows) {
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
				items.push_back(it);
			}
			Json d;
			d["items"] = items;
			return json_ok(d);
		}

		if(path == "/internal/quote-item") {
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
			const unsigned long long inventory_id = req.value("inventory_id", 0ULL);
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
			const unsigned long long target_toon_id = req.value("target_toon_id", 0ULL);
			const unsigned long long inventory_id = req.value("inventory_id", 0ULL);
			const int location = req.value("location", 0);
			const int modifier = req.value("modifier", 0);
			const int pay_xp = req.value("pay_xp", 0);
			const int pay_rune = req.value("pay_rune", 0);

			const std::string target_name = toon_name_by_id(target_toon_id);
			if(target_name.empty()) {
				return json_error("toon target non trovato", 404);
			}
			if(is_toon_online_by_name(target_name)) {
				return json_error("il toon target e collegato al mud", 409);
			}

			if(edit_system_blocked_on_object(location, modifier)) {
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

			struct obj_data* before = materialize_inventory_row(*row);
			if(!before) {
				return json_error("impossibile materializzare oggetto", 500);
			}

			struct obj_data* after = materialize_inventory_row(*row);
			if(!after) {
				extract_obj(before);
				return json_error("impossibile clonare oggetto", 500);
			}

			int slot = -1;
			for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
				if(after->affected[i].location == APPLY_NONE ||
				   after->affected[i].location == APPLY_SKIP) {
					slot = i;
					break;
				}
			}
			if(slot < 0) {
				extract_obj(before);
				extract_obj(after);
				return json_error("nessuno slot affect libero", 400);
			}

			after->affected[slot].location = static_cast<sh_int>(location);
			after->affected[slot].modifier = static_cast<sh_int>(modifier);

			const ExpValue diff_before = CheckDiffValue(before);
			extract_obj(before);
			const ExpValue diff_after = CheckDiffValue(after);

			const long long delta_xp = diff_after.valore - diff_before.valore;
			const int delta_rune = diff_after.rune - diff_before.rune;
			const int xp_cost =
				pay_xp > 0 ? pay_xp : static_cast<int>(std::max(0LL, delta_xp));
			const int rune_cost =
				pay_rune > 0 ? pay_rune : std::max(0, delta_rune);

			const int max_level = max_level_for_toon(target_toon_id);
			std::string pay_err;
			if(!deduct_payment(target_toon_id, xp_cost, rune_cost, max_level, pay_err)) {
				extract_obj(after);
				return json_error(pay_err.c_str(), 402);
			}

			bool saved = false;
			if(after->db_instance_id != 0) {
				const int base = object_instance_resolve_base_vnum(after);
				if(base > 0 &&
				   object_instance_persist(after, base, 0, nullptr, true,
										   "edit_portal") != 0) {
					saved = true;
				}
			}
			else {
				saved = persist_inventory_affects(inventory_id, after);
			}

			Json d = analyze_to_json(after);
			d["paid_xp"] = xp_cost;
			d["paid_rune"] = rune_cost;
			d["saved"] = saved;
			extract_obj(after);

			if(!saved) {
				return json_error("pagamento eseguito ma salvataggio fallito", 500);
			}
			return json_ok(d);
		}

		if(path == "/internal/apply-pool") {
			const unsigned long long target_toon_id = req.value("target_toon_id", 0ULL);
			const std::string field = req.value("field", "");
			int pay_xp = req.value("pay_xp", 0);
			int pay_rune = req.value("pay_rune", 0);

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
								   ? req.value("new_value", current)
								   : current + req.value("delta", 0);
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
				db->execute(upd.str().c_str());
			}
			catch(const std::exception& e) {
				return json_error(e.what(), 500);
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
			const unsigned long long target_toon_id = req.value("target_toon_id", 0ULL);
			const unsigned damage_type = static_cast<unsigned>(req.value("damage_type", 0));
			const int value = req.value("value", 0);
			const int pay_xp = req.value("pay_xp", 0);
			const int pay_rune = req.value("pay_rune", 0);

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
			const unsigned long long toon_id = req.value("toon_id", 0ULL);
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
		return json_error(e.what(), 500);
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

		char buf[16384];
		const ssize_t n = read(client, buf, sizeof(buf) - 1);
		if(n <= 0) {
			close(client);
			continue;
		}
		buf[n] = '\0';
		std::string raw(buf, static_cast<size_t>(n));

		std::string method;
		std::string path;
		{
			std::istringstream ls(raw);
			ls >> method >> path;
		}

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
	std::thread(http_thread_main).detach();
#else
	mudlog(LOG_CHECK, "edit_portal: disabled (USE_MYSQL=0)");
#endif
}

} // namespace Alarmud
