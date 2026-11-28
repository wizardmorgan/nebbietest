/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "listino_db.hpp"

#include "config.hpp"
#include "flags.hpp"
#include "logging.hpp"
#include "Sql.hpp"
#include "autoenums.hpp"

#include "listino_seed.inc"

#if USE_MYSQL
#include <odb/database.hxx>
#include <odb/exception.hxx>
#include <odb/mysql/connection.hxx>
#include <odb/transaction.hxx>
#include <mysql/mysql.h>
#endif

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace Alarmud {
namespace {

struct AffectRowLive {
	std::string id;
	std::string label;
	int location = 0;
	int step = 1;
	int min_total = 0;
	int max_total = 0;
	long pos_unit_raw = 0;
	long neg_unit_raw = 0;
	int rune_num = 0;
	int rune_den = 1;
	std::string cap_group;
};

std::mutex g_mu;
std::vector<AffectRowLive> g_affect;
std::unordered_map<int, std::size_t> g_by_loc;
std::vector<AffectRowLive> g_bit;
std::unordered_map<unsigned long long, std::size_t> g_by_bit;
std::unordered_map<std::string, ListinoPoolRow> g_pool;
std::unordered_map<std::string, ListinoCapGroupRow> g_cap_groups;
std::unordered_map<std::string, double> g_params;
std::string g_seed_tag;
bool g_ready = false;
std::vector<ListinoRowStatus> g_status;
std::unordered_map<std::string, std::string> g_cap_group_labels;
void clear_cache_unlocked() {
	g_affect.clear();
	g_by_loc.clear();
	g_bit.clear();
	g_by_bit.clear();
	g_pool.clear();
	g_cap_groups.clear();
	g_params.clear();
	g_seed_tag.clear();
	g_ready = false;
	g_status.clear();
	g_cap_group_labels.clear();
}

void fill_spec(const AffectRowLive& row, ObjEditListinoSpec& out) noexcept {
	out.location = row.location;
	out.id = row.id.c_str();
	out.label = row.label.c_str();
	out.step = row.step;
	out.min_total = row.min_total;
	out.max_total = row.max_total;
	out.positive_unit_raw = row.pos_unit_raw;
	out.negative_unit_raw = row.neg_unit_raw;
}

[[nodiscard]] unsigned long long bit_key(int loc, unsigned long bit) noexcept {
	return (static_cast<unsigned long long>(static_cast<unsigned int>(loc)) << 32) |
		   static_cast<unsigned long long>(bit);
}

[[nodiscard]] bool is_resist_bit_loc(int loc) noexcept {
	return loc == APPLY_IMMUNE || loc == APPLY_M_IMMUNE || loc == APPLY_SUSC;
}

#if USE_MYSQL

bool mysql_exec(MYSQL* h, const char* sql) {
	if(mysql_query(h, sql) != 0) {
		mudlog(LOG_SYSERR, "listino_db: %s [%s]", mysql_error(h), sql);
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		mysql_free_result(res);
	}
	return true;
}

/* ------------------------------------------------------------------------
 * Store: listino unico `edit_listino` + `edit_listino_rules` (condiviso con
 * il MUD Server, heal_v15_edit_listino). Le vecchie tabelle listino_affect /
 * listino_pool / listino_param / listino_cap_group / listino_meta non sono
 * piu' create ne' lette: solo listino_param.broker_fee_percent viene copiato
 * (una volta, INSERT IGNORE) se la tabella legacy esiste ancora.
 *
 * DDL identico al Server: se il MUD ha gia' creato le tabelle, CREATE IF NOT
 * EXISTS e' un no-op; il seed e' INSERT IGNORE e non tocca valori presenti.
 * ------------------------------------------------------------------------ */

std::string sql_quote(MYSQL* h, const char* s) {
	const std::string in = s ? s : "";
	std::string buf(in.size() * 2 + 1, '\0');
	const unsigned long n =
		mysql_real_escape_string(h, buf.data(), in.c_str(), static_cast<unsigned long>(in.size()));
	buf.resize(n);
	return "'" + buf + "'";
}

bool table_exists(MYSQL* h, const char* table) {
	std::string sql =
		"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() "
		"AND TABLE_NAME = " +
		sql_quote(h, table);
	if(mysql_query(h, sql.c_str()) != 0) {
		return false;
	}
	bool found = false;
	if(MYSQL_RES* res = mysql_store_result(h)) {
		if(MYSQL_ROW row = mysql_fetch_row(res)) {
			found = row[0] && std::strtoull(row[0], nullptr, 10) > 0ULL;
		}
		mysql_free_result(res);
	}
	return found;
}

bool ensure_schema(MYSQL* h) {
	const char* ddl[] = {
		"CREATE TABLE IF NOT EXISTS `edit_listino` ("
		"  `code` varchar(64) NOT NULL PRIMARY KEY,"
		"  `label` varchar(128) NOT NULL,"
		"  `category` varchar(32) NOT NULL,"
		"  `xp` BIGINT NOT NULL DEFAULT 0,"
		"  `rune_num` INT NOT NULL DEFAULT 0,"
		"  `rune_den` INT NOT NULL DEFAULT 1,"
		"  `sign` SMALLINT NOT NULL DEFAULT 1,"
		"  `cap_obj` INT NOT NULL DEFAULT 0,"
		"  `step` INT NOT NULL DEFAULT 1,"
		"  `on_obj` TINYINT UNSIGNED NOT NULL DEFAULT 0,"
		"  `on_pc` TINYINT UNSIGNED NOT NULL DEFAULT 0,"
		"  `cap_pc` INT NOT NULL DEFAULT 0,"
		"  `cap_group` varchar(32) NOT NULL DEFAULT '',"
		"  `over_cap` INT NOT NULL DEFAULT 0,"
		"  `over_step` INT NOT NULL DEFAULT 0,"
		"  `over_rune` INT NOT NULL DEFAULT 0,"
		"  `over_xp` BIGINT NOT NULL DEFAULT 0,"
		"  `over_gold` BIGINT NOT NULL DEFAULT 0,"
		"  `over_inc_pct` INT NOT NULL DEFAULT 0,"
		"  `apply_loc` INT NOT NULL DEFAULT 0,"
		"  `apply_bit` BIGINT UNSIGNED NOT NULL DEFAULT 0,"
		"  `resist_equiv` SMALLINT NOT NULL DEFAULT 0,"
		"  `resist_code` varchar(64) NOT NULL DEFAULT '',"
		"  `buy_step` SMALLINT NOT NULL DEFAULT 1,"
		"  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 0,"
		"  `mud_supported` TINYINT UNSIGNED NOT NULL DEFAULT 0,"
		"  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP "
		"ON UPDATE CURRENT_TIMESTAMP"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
		"CREATE TABLE IF NOT EXISTS `edit_listino_rules` ("
		"  `conf_key` varchar(64) NOT NULL PRIMARY KEY,"
		"  `num` INT NOT NULL DEFAULT 0,"
		"  `den` INT NOT NULL DEFAULT 1,"
		"  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP "
		"ON UPDATE CURRENT_TIMESTAMP"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
	};
	for(const char* sql : ddl) {
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	/* Etichette gruppi cap (stesso DDL proposto per il Server). */
	if(!mysql_exec(h,
				   "CREATE TABLE IF NOT EXISTS `edit_listino_cap_group` ("
				   "  `code` varchar(32) NOT NULL PRIMARY KEY,"
				   "  `label` varchar(128) NOT NULL,"
				   "  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP "
				   "ON UPDATE CURRENT_TIMESTAMP"
				   ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4")) {
		return false;
	}
	/* Colonne aggiunte dopo la prima versione (stesso ordine del Server).
	 * Ritorna 1 se la colonna e' stata appena aggiunta, 0 se c'era, -1 errore. */
	auto ensure_col = [&](const char* table, const char* col, const char* ddl_tail) -> int {
		std::string probe = std::string("SELECT `") + col + "` FROM `" + table + "` LIMIT 0";
		if(mysql_query(h, probe.c_str()) == 0) {
			if(MYSQL_RES* res = mysql_store_result(h)) {
				mysql_free_result(res);
			}
			return 0;
		}
		std::string alter =
			std::string("ALTER TABLE `") + table + "` ADD COLUMN `" + col + "` " + ddl_tail;
		return mysql_exec(h, alter.c_str()) ? 1 : -1;
	};
	(void)ensure_col("edit_listino", "step", "INT NOT NULL DEFAULT 1");
	(void)ensure_col("edit_listino", "resist_equiv", "SMALLINT NOT NULL DEFAULT 0");
	(void)ensure_col("edit_listino", "resist_code", "varchar(64) NOT NULL DEFAULT ''");
	/* Stesse colonne e stessi backfill del Server (heal_v15_edit_listino). */
	(void)ensure_col("edit_listino", "buy_step", "SMALLINT NOT NULL DEFAULT 1");
	(void)ensure_col("edit_listino", "enabled", "TINYINT UNSIGNED NOT NULL DEFAULT 0");
	/* mud_supported: lo scrive il MUD Server (codici del suo seed); myst non la
	 * tocca, la crea solo se manca. */
	(void)ensure_col("edit_listino", "mud_supported", "TINYINT UNSIGNED NOT NULL DEFAULT 0");
	/* buy_step ufficiale del pool solo se ancora al default 1. */
	(void)mysql_exec(h, "UPDATE `edit_listino` SET `buy_step`=10 "
						"WHERE `buy_step`=1 AND `code` IN ('hit','mana','move')");
	(void)mysql_exec(h, "UPDATE `edit_listino` SET `buy_step`=5 WHERE `buy_step`=1 AND "
						"`code` IN ('hit_regen','mana_regen','move_regen')");
	/* enabled=1 sulle righe gia' vendibili solo se la colonna e' ancora tutta a 0
	 * (colonna appena aggiunta su DB gia' seminato). */
	(void)mysql_exec(h, "SET @ld_en_sum = (SELECT IFNULL(SUM(`enabled`),0) FROM `edit_listino`)");
	(void)mysql_exec(h, "UPDATE `edit_listino` SET `enabled`=1 "
						"WHERE (`on_obj`=1 OR `on_pc`=1) AND `enabled`=0 AND @ld_en_sum=0");
	return true;
}

/** broker_fee_percent dal vecchio listino_param (se c'e'), prima del seed. */
bool migrate_legacy_params(MYSQL* h) {
	if(!table_exists(h, "listino_param")) {
		return true;
	}
	return mysql_exec(
		h, "INSERT IGNORE INTO `edit_listino_rules` (`conf_key`,`num`,`den`) "
		   "SELECT 'broker_fee_percent', ROUND(`param_value` * 100), 100 "
		   "FROM `listino_param` WHERE `param_key` = 'broker_fee_percent'");
}

/** INSERT IGNORE del seed (righe + regole). Non sovrascrive mai. */
bool seed_missing(MYSQL* h) {
	for(const auto& e : listino_seed::kListinoRows) {
		char nums[512];
		std::snprintf(nums, sizeof(nums),
					  "%ld,%d,%d,%d,%d,%d,%d,%d,%d", e.xp, e.rune_num,
					  e.rune_den > 0 ? e.rune_den : 1, e.sign, e.cap_obj,
					  e.step > 0 ? e.step : 1, e.on_obj ? 1 : 0, e.on_pc ? 1 : 0, e.cap_pc);
		char over[512];
		/* mud_supported=1: queste righe sono codici del seed del MUD Server; se myst
		 * semina per primo, il Server (INSERT IGNORE) non le correggerebbe. */
		std::snprintf(over, sizeof(over), "%d,%d,%d,%ld,%ld,%d,%d,%lu,%d,", e.over_cap,
					  e.over_step, e.over_rune, e.over_xp, e.over_gold, e.over_inc_pct,
					  e.apply_loc, e.apply_bit, e.resist_equiv);
		char tail[32];
		std::snprintf(tail, sizeof(tail), ",%d,%d,1", e.buy_step > 0 ? e.buy_step : 1,
					  e.enabled ? 1 : 0);
		const std::string sql =
			std::string("INSERT IGNORE INTO `edit_listino` (`code`,`label`,`category`,`xp`,"
						"`rune_num`,`rune_den`,`sign`,`cap_obj`,`step`,`on_obj`,`on_pc`,"
						"`cap_pc`,`cap_group`,`over_cap`,`over_step`,`over_rune`,`over_xp`,"
						"`over_gold`,`over_inc_pct`,`apply_loc`,`apply_bit`,`resist_equiv`,"
						"`resist_code`,`buy_step`,`enabled`,`mud_supported`) VALUES (") +
			sql_quote(h, e.code) + "," + sql_quote(h, e.label) + "," +
			sql_quote(h, e.category) + "," + nums + "," + sql_quote(h, e.cap_group) + "," +
			over + sql_quote(h, e.resist_code ? e.resist_code : "") + tail + ")";
		if(!mysql_exec(h, sql.c_str())) {
			return false;
		}
	}
	for(const auto& g : listino_seed::kCapGroupRows) {
		const std::string sql =
			std::string("INSERT IGNORE INTO `edit_listino_cap_group` (`code`,`label`) VALUES (") +
			sql_quote(h, g.code) + "," + sql_quote(h, g.label) + ")";
		if(!mysql_exec(h, sql.c_str())) {
			return false;
		}
	}
	for(const auto& r : listino_seed::kRuleRows) {
		char tail[64];
		std::snprintf(tail, sizeof(tail), ",%d,%d)", r.num, r.den > 0 ? r.den : 1);
		const std::string sql =
			std::string("INSERT IGNORE INTO `edit_listino_rules` (`conf_key`,`num`,`den`) "
						"VALUES (") +
			sql_quote(h, r.conf_key) + tail;
		if(!mysql_exec(h, sql.c_str())) {
			return false;
		}
	}
	return true;
}

long gcd_long(long a, long b) {
	a = a < 0 ? -a : a;
	b = b < 0 ? -b : b;
	while(b != 0) {
		const long t = a % b;
		a = b;
		b = t;
	}
	return a == 0 ? 1 : a;
}

/** Campo editpool (chiave listino_pool storica) per un APPLY pool. */
const char* pool_key_for_apply(int apply_loc) {
	switch(apply_loc) {
	case APPLY_HIT:
		return "hit";
	case APPLY_MANA:
		return "mana";
	case APPLY_MOVE:
		return "move";
	case APPLY_HIT_REGEN:
		return "hit_regen";
	case APPLY_MANA_REGEN:
		return "mana_regen";
	case APPLY_MOVE_REGEN:
		return "move_regen";
	default:
		return nullptr;
	}
}

/** Id storico del portale per i codici edit_listino che hanno cambiato nome
 *  (app.js usa 'armor' per la logica "piu' basso = meglio"). */
std::string portal_id_for_code(const std::string& code) {
	if(code == "ac") {
		return "armor";
	}
	if(code == "intel") {
		return "int";
	}
	return code;
}

const char* cap_group_label(const std::string& key) {
	if(key == "dam_sp") {
		return "Damroll + Spellpower";
	}
	return nullptr;
}

/** Firma delle tre tabelle: cambia a ogni INSERT/UPDATE/DELETE (MUD o portale). */
std::string read_signature(MYSQL* h) {
	const char* sql =
		"SELECT CONCAT("
		"(SELECT CONCAT(IFNULL(UNIX_TIMESTAMP(MAX(updated_at)),0),'.',COUNT(*)) FROM edit_listino),"
		"'/',"
		"(SELECT CONCAT(IFNULL(UNIX_TIMESTAMP(MAX(updated_at)),0),'.',COUNT(*)) FROM edit_listino_rules),"
		"'/',"
		"(SELECT CONCAT(IFNULL(UNIX_TIMESTAMP(MAX(updated_at)),0),'.',COUNT(*)) FROM edit_listino_cap_group))";
	if(mysql_query(h, sql) != 0) {
		return {};
	}
	std::string sig;
	if(MYSQL_RES* res = mysql_store_result(h)) {
		if(MYSQL_ROW row = mysql_fetch_row(res)) {
			sig = row[0] ? row[0] : "";
		}
		mysql_free_result(res);
	}
	return sig;
}

/**
 * Il MUD (questo myst) sa usare la voce? Solo per queste il portale permette
 * enabled=1. Una voce aggiunta dal web per una funzione non ancora scritta
 * resta "non supportata" finche' il codice non la conosce.
 */
bool row_supported(int apply_loc, unsigned long long apply_bit, bool is_pool_apply,
				   std::string& kind, std::string& reason) {
	if(apply_loc == 0 && apply_bit == static_cast<unsigned long long>(ITEM_IMMUNE)) {
		kind = "flag";
		return true;
	}
	if(is_pool_apply && apply_bit == 0ULL) {
		kind = "pool";
		return true;
	}
	if(apply_loc > 0 && apply_bit == 0ULL) {
		kind = "affect";
		if(obj_edit_listino_builtin_known(apply_loc)) {
			return true;
		}
		reason = "APPLY non editabile dal portale in questo MUD";
		return false;
	}
	if(is_resist_bit_loc(apply_loc) && apply_bit != 0ULL) {
		kind = "bit";
		return true;
	}
	kind = apply_loc > 0 ? "bit" : "other";
	reason = apply_loc > 0 ? "voce a bit: spell/weapon, non resistenze oggetto"
						   : "nessun APPLY/flag: funzione non implementata nel MUD";
	return false;
}

bool load_cache(MYSQL* h) {
	clear_cache_unlocked();
	const double scale = static_cast<double>(listino_seed::kStorageScale);

	/* 1) Regole: conf_key -> num/den (anche alias storici del portale). */
	long malus_num = 2;
	long malus_den = 1;
	if(mysql_query(h, "SELECT conf_key, num, den FROM edit_listino_rules") != 0) {
		mudlog(LOG_SYSERR, "listino_db load edit_listino_rules: %s", mysql_error(h));
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		while(MYSQL_ROW row = mysql_fetch_row(res)) {
			if(!row[0]) {
				continue;
			}
			const std::string key = row[0];
			const long num = row[1] ? std::strtol(row[1], nullptr, 10) : 0;
			long den = row[2] ? std::strtol(row[2], nullptr, 10) : 1;
			if(den <= 0) {
				den = 1;
			}
			const double v = static_cast<double>(num) / static_cast<double>(den);
			g_params[key] = v;
			if(key == "class_mult_2") {
				g_params["class_mult_bi"] = v;
			}
			else if(key == "class_mult_3") {
				g_params["class_mult_tri"] = v;
			}
			else if(key == "malus_mult" && num > 0) {
				malus_num = num;
				malus_den = den;
			}
		}
		mysql_free_result(res);
	}
	if(g_params.find("storage_scale") == g_params.end()) {
		g_params["storage_scale"] = scale;
	}
	/* Artifact: la regola artifact_cost_xp (base, x class_mult) vince sulla riga
	 * `artifact`; artifact_cost_raw resta per i consumer storici. */
	const auto art_rule = g_params.find("artifact_cost_xp");
	const bool has_art_rule = art_rule != g_params.end() && art_rule->second > 0.0;
	if(has_art_rule) {
		g_params["artifact_cost_raw"] = art_rule->second / scale;
	}

	/* 1b) Etichette gruppi cap. */
	if(mysql_query(h, "SELECT code, label FROM edit_listino_cap_group") == 0) {
		if(MYSQL_RES* res = mysql_store_result(h)) {
			while(MYSQL_ROW row = mysql_fetch_row(res)) {
				if(row[0]) {
					g_cap_group_labels[row[0]] = row[1] ? row[1] : "";
				}
			}
			mysql_free_result(res);
		}
	}

	/* 2) Righe listino. */
	if(mysql_query(h,
				   "SELECT code, label, category, xp, rune_num, rune_den, sign, cap_obj, "
				   "step, on_obj, on_pc, cap_pc, cap_group, apply_loc, apply_bit, "
				   "UNIX_TIMESTAMP(updated_at), buy_step, enabled "
				   "FROM edit_listino ORDER BY code") != 0) {
		mudlog(LOG_SYSERR, "listino_db load edit_listino: %s", mysql_error(h));
		return false;
	}
	unsigned long long max_updated = 0;
	std::size_t n_rows = 0;
	if(MYSQL_RES* res = mysql_store_result(h)) {
		while(MYSQL_ROW row = mysql_fetch_row(res)) {
			++n_rows;
			const std::string code = row[0] ? row[0] : "";
			const std::string label = row[1] ? row[1] : "";
			const long xp = row[3] ? std::strtol(row[3], nullptr, 10) : 0;
			const long r_num = row[4] ? std::strtol(row[4], nullptr, 10) : 0;
			long r_den = row[5] ? std::strtol(row[5], nullptr, 10) : 1;
			if(r_den <= 0) {
				r_den = 1;
			}
			const int sign = row[6] && std::atoi(row[6]) < 0 ? -1 : 1;
			const int cap_obj = row[7] ? std::abs(std::atoi(row[7])) : 0;
			int step = row[8] ? std::atoi(row[8]) : 1;
			if(step <= 0) {
				step = 1;
			}
			const bool on_obj = row[9] && std::atoi(row[9]) != 0;
			const bool on_pc = row[10] && std::atoi(row[10]) != 0;
			const int cap_pc = row[11] ? std::atoi(row[11]) : 0;
			const std::string cap_group = row[12] ? row[12] : "";
			const int apply_loc = row[13] ? std::atoi(row[13]) : 0;
			const unsigned long long apply_bit =
				row[14] ? std::strtoull(row[14], nullptr, 10) : 0ULL;
			if(row[15]) {
				max_updated = std::max(max_updated, std::strtoull(row[15], nullptr, 10));
			}
			int buy_step = row[16] ? std::atoi(row[16]) : 1;
			if(buy_step <= 0) {
				buy_step = 1;
			}
			const bool enabled = row[17] && std::atoi(row[17]) != 0;
			if(code.empty()) {
				continue;
			}
			ListinoRowStatus st;
			st.code = code;
			st.enabled = enabled;
			st.supported = row_supported(apply_loc, apply_bit,
										 pool_key_for_apply(apply_loc) != nullptr, st.kind,
										 st.reason);
			const bool usable = enabled && st.supported;
			if(!enabled && st.reason.empty()) {
				st.reason = "spenta (enabled=0)";
			}
			const std::size_t st_index = g_status.size();
			g_status.push_back(st);
			if(!usable) {
				continue;
			}

			/* Prezzo per unita' (xp e rune sono per `step` unita'). */
			const long xp_unit = static_cast<long>(std::llround(
				static_cast<double>(xp) / static_cast<double>(step)));
			long ru_num = r_num;
			long ru_den = r_den * step;
			{
				const long g = gcd_long(ru_num, ru_den);
				ru_num /= g;
				ru_den /= g;
			}

			/* Artifact (flag ITEM_IMMUNE, nessun APPLY): costo raw flag. */
			if(apply_loc == 0 && apply_bit == static_cast<unsigned long long>(ITEM_IMMUNE)) {
				g_status[st_index].active = on_obj;
				if(on_obj && !has_art_rule) {
					g_params["artifact_cost_raw"] = static_cast<double>(xp) / scale;
					g_params["artifact_cost_xp"] = static_cast<double>(xp);
				}
				continue;
			}

			/* Campi editpool: on_pc + APPLY pool. */
			if(const char* pkey = pool_key_for_apply(apply_loc)) {
				if(on_pc && apply_bit == 0ULL) {
					g_status[st_index].active = true;
					ListinoPoolRow p;
					p.field_key = pkey;
					p.label = label;
					p.cap = cap_pc;
					/* step=1 nel listino = prezzo a punto: lo step di acquisto resta
					 * quello del portale (10 / 5). step>1 = slot esplicito. */
					p.step = buy_step > 1 ? buy_step : (step > 1 ? step : 0);
					p.xp_per_unit = xp_unit;
					p.unit_valore = static_cast<long>(
						std::llround(static_cast<double>(xp_unit) / scale));
					p.rune_num = static_cast<int>(ru_num);
					p.rune_den = static_cast<int>(ru_den);
					g_pool[p.field_key] = std::move(p);
				}
				continue;
			}

			/* Voce a bit (resistenze / immunita' / susc) vendibile su oggetto. */
			if(on_obj && is_resist_bit_loc(apply_loc) && apply_bit != 0ULL) {
				const unsigned long long key =
					bit_key(apply_loc, static_cast<unsigned long>(apply_bit));
				if(g_by_bit.find(key) != g_by_bit.end()) {
					g_status[st_index].reason = "bit gia' coperto da un'altra voce";
					continue;
				}
				g_status[st_index].active = true;
				AffectRowLive a;
				a.id = portal_id_for_code(code);
				a.label = label;
				a.location = apply_loc;
				a.step = 1;
				a.min_total = 0;
				a.max_total = cap_obj > 0 ? cap_obj : 1;
				a.pos_unit_raw = static_cast<long>(
					std::llround(static_cast<double>(xp_unit) / scale));
				a.neg_unit_raw = static_cast<long>(std::llround(
					static_cast<double>(a.pos_unit_raw) * static_cast<double>(malus_num) /
					static_cast<double>(malus_den)));
				a.rune_num = static_cast<int>(ru_num);
				a.rune_den = static_cast<int>(ru_den);
				a.cap_group = cap_group;
				g_by_bit[key] = g_bit.size();
				g_bit.push_back(std::move(a));
				continue;
			}

			/* Affect oggetto: APPLY numerico (niente bit), vendibile su oggetto. */
			if(!on_obj || apply_loc <= 0 || apply_bit != 0ULL) {
				g_status[st_index].reason =
					on_pc ? "campo PG (on_pc): non e' un affect oggetto del portale"
						  : "on_obj=0: non vendibile su oggetto";
				continue;
			}
			if(g_by_loc.find(apply_loc) != g_by_loc.end()) {
				g_status[st_index].reason = "APPLY gia' coperto da un'altra voce";
				continue; /* uq_listino_affect_location storico: vince il primo */
			}
			g_status[st_index].active = true;
			AffectRowLive a;
			a.id = portal_id_for_code(code);
			a.label = label;
			a.location = apply_loc;
			a.step = sign < 0 ? -step : step;
			a.min_total = sign < 0 ? -cap_obj : 0;
			a.max_total = sign < 0 ? 0 : cap_obj;
			a.pos_unit_raw =
				static_cast<long>(std::llround(static_cast<double>(xp_unit) / scale));
			a.neg_unit_raw = static_cast<long>(std::llround(
				static_cast<double>(a.pos_unit_raw) * static_cast<double>(malus_num) /
				static_cast<double>(malus_den)));
			a.rune_num = static_cast<int>(ru_num);
			a.rune_den = static_cast<int>(ru_den);
			a.cap_group = cap_group;
			if(!cap_group.empty()) {
				ListinoCapGroupRow& g = g_cap_groups[cap_group];
				if(g.group_key.empty()) {
					g.group_key = cap_group;
					const auto lit = g_cap_group_labels.find(cap_group);
					const char* lbl = cap_group_label(cap_group);
					g.label = lit != g_cap_group_labels.end() && !lit->second.empty()
								  ? lit->second
								  : (lbl ? lbl : cap_group);
					g.enabled = true;
				}
				g.max_piece = std::max(g.max_piece, cap_obj);
				g.max_character = std::max(g.max_character, cap_pc);
			}
			g_by_loc[a.location] = g_affect.size();
			g_affect.push_back(std::move(a));
		}
		mysql_free_result(res);
	}

	/* Revisione listino = ultima modifica (portale la usa per invalidare quote). */
	const std::string signature = read_signature(h);
	g_seed_tag = std::string(listino_seed::kSeedTag) + "@" + std::to_string(max_updated) +
				 "#" + signature;

	g_ready = !g_affect.empty();
	mudlog(LOG_CHECK,
		   "listino_db: edit_listino rows=%zu affect=%zu bit=%zu pool=%zu rules/params=%zu rev=%s",
		   n_rows, g_affect.size(), g_bit.size(), g_pool.size(), g_params.size(),
		   g_seed_tag.c_str());
	/* DEBUG portale: EDIT_PORTAL_LOG_LEVEL=debug → dettaglio voci in syslog mud */
	const char* lvl = std::getenv("EDIT_PORTAL_LOG_LEVEL");
	if(lvl != nullptr && (std::strcmp(lvl, "debug") == 0 || std::strcmp(lvl, "DEBUG") == 0)) {
		for(const auto& a : g_affect) {
			mudlog(LOG_CHECK,
				   "listino_db DEBUG affect id=%s loc=%d step=%d min=%d max=%d pos=%ld neg=%ld "
				   "rune=%d/%d group=%s",
				   a.id.c_str(), a.location, a.step, a.min_total, a.max_total,
				   a.pos_unit_raw, a.neg_unit_raw, a.rune_num, a.rune_den,
				   a.cap_group.c_str());
		}
		for(const auto& kv : g_pool) {
			mudlog(LOG_CHECK, "listino_db DEBUG pool %s cap=%d step=%d xp/u=%ld rune=%d/%d",
				   kv.first.c_str(), kv.second.cap, kv.second.step, kv.second.xp_per_unit,
				   kv.second.rune_num, kv.second.rune_den);
		}
		for(const auto& kv : g_params) {
			mudlog(LOG_CHECK, "listino_db DEBUG param %s=%g", kv.first.c_str(), kv.second);
		}
	}
	return g_ready;
}

bool with_mysql(bool (*fn)(MYSQL*)) {
	DB* db = Sql::getMysql();
	if(!db) {
		return false;
	}
	try {
		const bool in_tx = odb::transaction::has_current();
		odb::connection_ptr owned;
		odb::connection& conn =
			in_tx ? odb::transaction::current().connection() : *(owned = db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(conn);
		MYSQL* h = mc.handle();
		if(!in_tx) {
			odb::transaction t(db->begin());
			t.tracer(logTracer);
			const bool ok = fn(h);
			t.commit();
			return ok;
		}
		return fn(h);
	}
	catch(const odb::exception& e) {
		mudlog(LOG_SYSERR, "listino_db odb: %s", e.what());
		return false;
	}
}

#endif /* USE_MYSQL */

} /* namespace */

void listino_db_init() {
#if USE_MYSQL
	std::lock_guard<std::mutex> lock(g_mu);
	with_mysql([](MYSQL* h) {
		if(!ensure_schema(h)) {
			return false;
		}
		if(!migrate_legacy_params(h)) {
			return false;
		}
		if(!seed_missing(h)) {
			return false;
		}
		return load_cache(h);
	});
#else
	(void)0;
#endif
}

bool listino_db_reload() {
#if USE_MYSQL
	std::lock_guard<std::mutex> lock(g_mu);
	return with_mysql([](MYSQL* h) { return load_cache(h); });
#else
	return false;
#endif
}

std::vector<ListinoRowStatus> listino_db_row_status() {
	std::lock_guard<std::mutex> lock(g_mu);
	return g_status;
}

bool listino_db_ready() noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	return g_ready;
}

int listino_db_affect_count() noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	return static_cast<int>(g_affect.size());
}

bool listino_db_affect_at(int index, ObjEditListinoSpec& out) noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	if(index < 0 || index >= static_cast<int>(g_affect.size())) {
		return false;
	}
	fill_spec(g_affect[static_cast<std::size_t>(index)], out);
	return true;
}

bool listino_db_affect_by_location(int location, ObjEditListinoSpec& out) noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_by_loc.find(location);
	if(it == g_by_loc.end()) {
		return false;
	}
	fill_spec(g_affect[it->second], out);
	return true;
}

bool listino_db_affect_rune(int location, int& rune_num, int& rune_den) noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_by_loc.find(location);
	if(it == g_by_loc.end()) {
		return false;
	}
	const AffectRowLive& a = g_affect[it->second];
	rune_num = a.rune_num;
	rune_den = a.rune_den > 0 ? a.rune_den : 1;
	return true;
}

bool listino_db_affect_by_bit(int location, unsigned long apply_bit,
							  ObjEditListinoSpec& out) noexcept {
	if(apply_bit == 0UL) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_by_bit.find(bit_key(location, apply_bit));
	if(it == g_by_bit.end()) {
		return false;
	}
	fill_spec(g_bit[it->second], out);
	return true;
}

bool listino_db_affect_rune_bit(int location, unsigned long apply_bit, int& rune_num,
								int& rune_den) noexcept {
	if(apply_bit == 0UL) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_by_bit.find(bit_key(location, apply_bit));
	if(it == g_by_bit.end()) {
		return false;
	}
	const AffectRowLive& a = g_bit[it->second];
	rune_num = a.rune_num;
	rune_den = a.rune_den > 0 ? a.rune_den : 1;
	return true;
}

long listino_db_take_bit_raw(int location, unsigned& bits) noexcept {
	std::lock_guard<std::mutex> lock(g_mu);
	unsigned leftover = 0U;
	long sum = 0;
	for(unsigned b = 1U; b != 0U; b <<= 1) {
		if((bits & b) == 0U) {
			continue;
		}
		const auto it = g_by_bit.find(bit_key(location, static_cast<unsigned long>(b)));
		if(it == g_by_bit.end()) {
			leftover |= b;
			continue;
		}
		sum += g_bit[it->second].pos_unit_raw;
	}
	bits = leftover;
	return sum;
}

std::string listino_db_affect_cap_group(int location) {
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_by_loc.find(location);
	if(it == g_by_loc.end()) {
		return {};
	}
	return g_affect[it->second].cap_group;
}

bool listino_db_cap_group(const char* group_key, ListinoCapGroupRow& out) noexcept {
	if(!group_key || !*group_key) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_cap_groups.find(group_key);
	if(it == g_cap_groups.end() || !it->second.enabled) {
		return false;
	}
	out = it->second;
	return true;
}

bool listino_db_pool(const char* field_key, ListinoPoolRow& out) noexcept {
	if(!field_key) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_pool.find(field_key);
	if(it == g_pool.end()) {
		return false;
	}
	out = it->second;
	return true;
}

double listino_db_param(const char* key, double fallback) noexcept {
	if(!key) {
		return fallback;
	}
	std::lock_guard<std::mutex> lock(g_mu);
	const auto it = g_params.find(key);
	if(it == g_params.end()) {
		return fallback;
	}
	return it->second;
}

std::string listino_db_seed_tag() {
	std::lock_guard<std::mutex> lock(g_mu);
	return g_seed_tag;
}

} /* namespace Alarmud */
