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
};

std::mutex g_mu;
std::vector<AffectRowLive> g_affect;
std::unordered_map<int, std::size_t> g_by_loc;
std::unordered_map<std::string, ListinoPoolRow> g_pool;
std::unordered_map<std::string, double> g_params;
std::string g_seed_tag;
bool g_ready = false;

void clear_cache_unlocked() {
	g_affect.clear();
	g_by_loc.clear();
	g_pool.clear();
	g_params.clear();
	g_seed_tag.clear();
	g_ready = false;
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

bool ensure_schema(MYSQL* h) {
	const char* ddl[] = {
		"CREATE TABLE IF NOT EXISTS listino_meta ("
		"  meta_key VARCHAR(64) NOT NULL,"
		"  meta_value VARCHAR(255) NOT NULL,"
		"  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP "
		"    ON UPDATE CURRENT_TIMESTAMP,"
		"  PRIMARY KEY (meta_key)"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
		"CREATE TABLE IF NOT EXISTS listino_affect ("
		"  id VARCHAR(32) NOT NULL,"
		"  label VARCHAR(64) NOT NULL,"
		"  location INT NOT NULL,"
		"  step INT NOT NULL DEFAULT 1,"
		"  min_total INT NOT NULL DEFAULT 0,"
		"  max_total INT NOT NULL DEFAULT 0,"
		"  pos_unit_raw BIGINT NOT NULL DEFAULT 0,"
		"  neg_unit_raw BIGINT NOT NULL DEFAULT 0,"
		"  enabled TINYINT NOT NULL DEFAULT 1,"
		"  PRIMARY KEY (id),"
		"  UNIQUE KEY uq_listino_affect_location (location)"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
		"CREATE TABLE IF NOT EXISTS listino_pool ("
		"  field_key VARCHAR(32) NOT NULL,"
		"  label VARCHAR(64) NOT NULL,"
		"  cap INT NOT NULL DEFAULT 0,"
		"  step INT NOT NULL DEFAULT 1,"
		"  unit_valore BIGINT NOT NULL DEFAULT 0,"
		"  xp_per_unit BIGINT NOT NULL DEFAULT 0,"
		"  rune_num INT NOT NULL DEFAULT 0,"
		"  rune_den INT NOT NULL DEFAULT 1,"
		"  enabled TINYINT NOT NULL DEFAULT 1,"
		"  PRIMARY KEY (field_key)"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
		"CREATE TABLE IF NOT EXISTS listino_param ("
		"  param_key VARCHAR(64) NOT NULL,"
		"  param_value DOUBLE NOT NULL,"
		"  PRIMARY KEY (param_key)"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
	};
	for(const char* sql : ddl) {
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	return true;
}

unsigned long long count_affect(MYSQL* h) {
	if(mysql_query(h, "SELECT COUNT(*) FROM listino_affect") != 0) {
		return 0;
	}
	MYSQL_RES* res = mysql_store_result(h);
	unsigned long long n = 0;
	if(res) {
		if(MYSQL_ROW row = mysql_fetch_row(res)) {
			if(row[0]) {
				n = std::strtoull(row[0], nullptr, 10);
			}
		}
		mysql_free_result(res);
	}
	return n;
}

bool seed_if_empty(MYSQL* h) {
	if(count_affect(h) > 0ULL) {
		return true;
	}
	mudlog(LOG_CHECK, "listino_db: seeding from %s", listino_seed::kSeedTag);
	for(const auto& a : listino_seed::kAffectRows) {
		char sql[1024];
		std::snprintf(
			sql, sizeof(sql),
			"INSERT INTO listino_affect "
			"(id, label, location, step, min_total, max_total, pos_unit_raw, "
			"neg_unit_raw, enabled) VALUES ('%s','%s',%d,%d,%d,%d,%ld,%ld,1)",
			a.id, a.label, a.location, a.step, a.min_total, a.max_total, a.pos_unit_raw,
			a.neg_unit_raw);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	for(const auto& p : listino_seed::kPoolRows) {
		char sql[1024];
		std::snprintf(
			sql, sizeof(sql),
			"INSERT INTO listino_pool "
			"(field_key, label, cap, step, unit_valore, xp_per_unit, rune_num, "
			"rune_den, enabled) VALUES ('%s','%s',%d,%d,%ld,%ld,%d,%d,1)",
			p.field_key, p.label, p.cap, p.step, p.unit_valore, p.xp_per_unit, p.rune_num,
			p.rune_den);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	for(const auto& p : listino_seed::kParams) {
		char sql[512];
		std::snprintf(sql, sizeof(sql),
					  "INSERT INTO listino_param (param_key, param_value) VALUES "
					  "('%s',%.17g) ON DUPLICATE KEY UPDATE param_value=VALUES(param_value)",
					  p.key, p.value);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	{
		char sql[512];
		std::snprintf(sql, sizeof(sql),
					  "INSERT INTO listino_meta (meta_key, meta_value) VALUES "
					  "('seed_tag','%s') ON DUPLICATE KEY UPDATE meta_value=VALUES(meta_value)",
					  listino_seed::kSeedTag);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	return true;
}

/** Inserisce param del seed mancanti (non sovrascrive valori staff). */
bool ensure_seed_params(MYSQL* h) {
	for(const auto& p : listino_seed::kParams) {
		char sql[512];
		std::snprintf(sql, sizeof(sql),
					  "INSERT IGNORE INTO listino_param (param_key, param_value) VALUES "
					  "('%s',%.17g)",
					  p.key, p.value);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	{
		char sql[512];
		std::snprintf(sql, sizeof(sql),
					  "INSERT INTO listino_meta (meta_key, meta_value) VALUES "
					  "('seed_tag','%s') ON DUPLICATE KEY UPDATE meta_value=VALUES(meta_value)",
					  listino_seed::kSeedTag);
		if(!mysql_exec(h, sql)) {
			return false;
		}
	}
	return true;
}

bool load_cache(MYSQL* h) {
	clear_cache_unlocked();

	if(mysql_query(h,
				   "SELECT id, label, location, step, min_total, max_total, "
				   "pos_unit_raw, neg_unit_raw FROM listino_affect WHERE enabled = 1 "
				   "ORDER BY id") != 0) {
		mudlog(LOG_SYSERR, "listino_db load affect: %s", mysql_error(h));
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		while(MYSQL_ROW row = mysql_fetch_row(res)) {
			AffectRowLive a;
			a.id = row[0] ? row[0] : "";
			a.label = row[1] ? row[1] : "";
			a.location = row[2] ? std::atoi(row[2]) : 0;
			a.step = row[3] ? std::atoi(row[3]) : 1;
			a.min_total = row[4] ? std::atoi(row[4]) : 0;
			a.max_total = row[5] ? std::atoi(row[5]) : 0;
			a.pos_unit_raw = row[6] ? std::strtol(row[6], nullptr, 10) : 0;
			a.neg_unit_raw = row[7] ? std::strtol(row[7], nullptr, 10) : 0;
			g_by_loc[a.location] = g_affect.size();
			g_affect.push_back(std::move(a));
		}
		mysql_free_result(res);
	}

	if(mysql_query(h,
				   "SELECT field_key, label, cap, step, unit_valore, xp_per_unit, "
				   "rune_num, rune_den FROM listino_pool WHERE enabled = 1") != 0) {
		mudlog(LOG_SYSERR, "listino_db load pool: %s", mysql_error(h));
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		while(MYSQL_ROW row = mysql_fetch_row(res)) {
			ListinoPoolRow p;
			p.field_key = row[0] ? row[0] : "";
			p.label = row[1] ? row[1] : "";
			p.cap = row[2] ? std::atoi(row[2]) : 0;
			p.step = row[3] ? std::atoi(row[3]) : 1;
			p.unit_valore = row[4] ? std::strtol(row[4], nullptr, 10) : 0;
			p.xp_per_unit = row[5] ? std::strtol(row[5], nullptr, 10) : 0;
			p.rune_num = row[6] ? std::atoi(row[6]) : 0;
			p.rune_den = row[7] ? std::atoi(row[7]) : 1;
			if(p.rune_den <= 0) {
				p.rune_den = 1;
			}
			g_pool[p.field_key] = std::move(p);
		}
		mysql_free_result(res);
	}

	if(mysql_query(h, "SELECT param_key, param_value FROM listino_param") != 0) {
		mudlog(LOG_SYSERR, "listino_db load param: %s", mysql_error(h));
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		while(MYSQL_ROW row = mysql_fetch_row(res)) {
			if(row[0] && row[1]) {
				g_params[row[0]] = std::strtod(row[1], nullptr);
			}
		}
		mysql_free_result(res);
	}

	if(mysql_query(h,
				   "SELECT meta_value FROM listino_meta WHERE meta_key = 'seed_tag' "
				   "LIMIT 1") == 0) {
		if(MYSQL_RES* res = mysql_store_result(h)) {
			if(MYSQL_ROW row = mysql_fetch_row(res)) {
				if(row[0]) {
					g_seed_tag = row[0];
				}
			}
			mysql_free_result(res);
		}
	}

	g_ready = !g_affect.empty();
	mudlog(LOG_CHECK, "listino_db: loaded affect=%zu pool=%zu params=%zu tag=%s",
		   g_affect.size(), g_pool.size(), g_params.size(),
		   g_seed_tag.empty() ? "-" : g_seed_tag.c_str());
	/* DEBUG portale: EDIT_PORTAL_LOG_LEVEL=debug → dettaglio voci in syslog mud */
	const char* lvl = std::getenv("EDIT_PORTAL_LOG_LEVEL");
	if(lvl != nullptr && (std::strcmp(lvl, "debug") == 0 || std::strcmp(lvl, "DEBUG") == 0)) {
		for(const auto& a : g_affect) {
			mudlog(LOG_CHECK,
				   "listino_db DEBUG affect id=%s loc=%d step=%d pos=%ld neg=%ld",
				   a.id.c_str(), a.location, a.step, a.pos_unit_raw, a.neg_unit_raw);
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
		if(!seed_if_empty(h)) {
			return false;
		}
		if(!ensure_seed_params(h)) {
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
