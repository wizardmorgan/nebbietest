/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "character_edit_affect.hpp"

#include "config.hpp"
#include "handler.hpp"
#include "listino_db.hpp"
#include "logging.hpp"
#include "obj_value.hpp"
#include "Sql.hpp"
#include "structs.hpp"
#include "utils.hpp"

#if USE_MYSQL
#include <odb/database.hxx>
#include <odb/mysql/connection.hxx>
#include <mysql/mysql.h>
#include "odb/account-odb.hxx"
#endif

#include <cmath>
#include <sstream>

namespace Alarmud {
namespace {

#if USE_MYSQL
[[nodiscard]] MYSQL* mysql_handle() {
	DB* db = Sql::getMysql();
	if(!db) {
		return nullptr;
	}
	try {
		odb::connection_ptr cp(db->connection());
		auto& mc = static_cast<odb::mysql::connection&>(*cp);
		return mc.handle();
	}
	catch(...) {
		return nullptr;
	}
}

[[nodiscard]] bool mysql_exec_simple(MYSQL* h, const char* sql, const char* where) {
	if(mysql_query(h, sql) != 0) {
		mudlog(LOG_SYSERR, "character_edit_affect %s: %s [%s]", where, mysql_error(h),
			   sql);
		return false;
	}
	if(MYSQL_RES* res = mysql_store_result(h)) {
		mysql_free_result(res);
	}
	return true;
}
#endif

[[nodiscard]] long affect_slot_raw(int location, int mod, long pos, long neg) {
	if(location == APPLY_AC || location == APPLY_SPELLFAIL) {
		return -static_cast<long>(mod) * pos;
	}
	if(mod < 0) {
		return static_cast<long>(mod) * neg;
	}
	return static_cast<long>(mod) * pos;
}

} // namespace

void character_edit_affect_ensure_schema() {
#if USE_MYSQL
	MYSQL* h = mysql_handle();
	if(!h) {
		return;
	}
	(void)mysql_exec_simple(
		h,
		"CREATE TABLE IF NOT EXISTS character_edit_affect ("
		"  toon_id BIGINT UNSIGNED NOT NULL,"
		"  location INT NOT NULL,"
		"  value INT NOT NULL DEFAULT 0,"
		"  PRIMARY KEY (toon_id, location),"
		"  KEY idx_char_edit_affect_loc (location)"
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
		"ddl");
#endif
}

bool character_edit_affect_load(unsigned long long toon_id,
								std::vector<CharEditAffectRow>& out) {
	out.clear();
#if USE_MYSQL
	MYSQL* h = mysql_handle();
	if(!h || toon_id == 0) {
		return false;
	}
	std::ostringstream sql;
	sql << "SELECT location, value FROM character_edit_affect WHERE toon_id = "
		<< toon_id << " ORDER BY location";
	if(mysql_query(h, sql.str().c_str()) != 0) {
		mudlog(LOG_SYSERR, "character_edit_affect load: %s", mysql_error(h));
		return false;
	}
	MYSQL_RES* res = mysql_store_result(h);
	if(!res) {
		return true;
	}
	while(MYSQL_ROW row = mysql_fetch_row(res)) {
		CharEditAffectRow r;
		r.location = row[0] ? std::atoi(row[0]) : 0;
		r.value = row[1] ? std::atoi(row[1]) : 0;
		if(r.location != 0) {
			out.push_back(r);
		}
	}
	mysql_free_result(res);
	return true;
#else
	(void)toon_id;
	return false;
#endif
}

int character_edit_affect_get(unsigned long long toon_id, int location) {
	std::vector<CharEditAffectRow> rows;
	if(!character_edit_affect_load(toon_id, rows)) {
		return 0;
	}
	for(const auto& r : rows) {
		if(r.location == location) {
			return r.value;
		}
	}
	return 0;
}

bool character_edit_affect_set(unsigned long long toon_id, int location, int value,
							   std::string& err) {
	err.clear();
#if USE_MYSQL
	MYSQL* h = mysql_handle();
	if(!h || toon_id == 0 || location == 0) {
		err = "parametri non validi";
		return false;
	}
	std::ostringstream sql;
	if(value == 0) {
		sql << "DELETE FROM character_edit_affect WHERE toon_id = " << toon_id
			<< " AND location = " << location;
	}
	else {
		sql << "INSERT INTO character_edit_affect (toon_id, location, value) VALUES ("
			<< toon_id << "," << location << "," << value
			<< ") ON DUPLICATE KEY UPDATE value = VALUES(value)";
	}
	if(mysql_query(h, sql.str().c_str()) != 0) {
		err = mysql_error(h) ? mysql_error(h) : "mysql_query failed";
		return false;
	}
	return true;
#else
	(void)toon_id;
	(void)location;
	(void)value;
	err = "MySQL disabilitato";
	return false;
#endif
}

void character_edit_affect_apply_to_char(struct char_data* ch) {
	if(!ch || IS_NPC(ch)) {
		return;
	}
	affect_from_char(ch, kCharacterEditAffectType);

	unsigned long long toon_id = 0;
#if USE_MYSQL
	if(ch->player.name) {
		try {
			const toonPtr pg = Sql::getOne<toon>(toonQuery::name == std::string(GET_NAME(ch)));
			if(pg) {
				toon_id = pg->id;
			}
		}
		catch(...) {
			toon_id = 0;
		}
	}
#endif
	if(toon_id == 0) {
		return;
	}

	std::vector<CharEditAffectRow> rows;
	if(!character_edit_affect_load(toon_id, rows)) {
		return;
	}
	for(const auto& r : rows) {
		if(r.value == 0 || r.location == APPLY_NONE || r.location == APPLY_SKIP) {
			continue;
		}
		affected_type af {};
		af.type = kCharacterEditAffectType;
		af.duration = -1;
		af.modifier = r.value;
		af.location = r.location;
		af.bitvector = 0;
		affect_to_char(ch, &af);
	}
}

std::pair<long, int> character_edit_affect_quote_paid(int location, int delta_units,
													  int n_classes) {
	if(delta_units == 0) {
		return {0, 0};
	}
	ObjEditListinoSpec spec {};
	if(!obj_edit_listino_spec(location, spec)) {
		return {0, 0};
	}
	const long raw =
		affect_slot_raw(location, delta_units, spec.positive_unit_raw, spec.negative_unit_raw);
	if(raw <= 0) {
		return {0, 0};
	}
	const double scale =
		listino_db_ready() ? listino_db_param("storage_scale", kObjValueStorageScale)
						   : static_cast<double>(kObjValueStorageScale);
	double scaled = static_cast<double>(raw) * scale;
	const int classes = n_classes < 1 ? 1 : n_classes;
	double mult = 1.0;
	if(listino_db_ready()) {
		if(classes >= 3) {
			mult = listino_db_param("class_mult_tri", kObjValueClassMultTri);
		}
		else if(classes == 2) {
			mult = listino_db_param("class_mult_bi", kObjValueClassMultBi);
		}
	}
	else if(classes >= 3) {
		mult = kObjValueClassMultTri;
	}
	else if(classes == 2) {
		mult = kObjValueClassMultBi;
	}
	if(mult != 1.0) {
		scaled = static_cast<double>(std::llround(scaled * mult));
	}
	const double art =
		listino_db_ready() ? listino_db_param("artifact_mult", 1.5) : 1.5;
	scaled = static_cast<double>(std::llround(scaled * art));

	int rune_num = 0;
	int rune_den = 1;
	(void)listino_db_affect_rune(location, rune_num, rune_den);
	double listino_rune = 0.0;
	if(rune_num != 0 && rune_den > 0) {
		listino_rune = static_cast<double>(std::abs(delta_units)) *
					   static_cast<double>(rune_num) / static_cast<double>(rune_den);
		listino_rune = listino_rune * art * mult;
	}
	const long xp = scaled > 0 ? static_cast<long>(scaled) : 0L;
	const int pq = listino_rune > 0 ? static_cast<int>(std::ceil(listino_rune)) : 0;
	return {xp, pq};
}

} /* namespace Alarmud */
