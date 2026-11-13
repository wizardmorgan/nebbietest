/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_LISTINO_DB_HPP_
#define SRC_LISTINO_DB_HPP_

#include "obj_value.hpp"

#include <string>

namespace odb {
class database;
}

namespace Alarmud {

struct ListinoPoolRow {
	std::string field_key;
	std::string label;
	int cap = 0;
	int step = 0;
	long unit_valore = 0;
	long xp_per_unit = 0;
	int rune_num = 0;
	int rune_den = 1;
};

/**
 * Crea tabelle listino_* se mancano; se listino_affect e' vuota esegue seed
 * da listino_seed.inc; carica tutto in RAM.
 */
void listino_db_init();

/** Ricarica RAM da MySQL (dopo edit staff). */
bool listino_db_reload();

/** true se la cache RAM e' popolata. */
[[nodiscard]] bool listino_db_ready() noexcept;

[[nodiscard]] int listino_db_affect_count() noexcept;

/** Spec come obj_edit_listino_*; false se indice fuori range. */
[[nodiscard]] bool listino_db_affect_at(int index, ObjEditListinoSpec& out) noexcept;

[[nodiscard]] bool listino_db_affect_by_location(int location,
												 ObjEditListinoSpec& out) noexcept;

[[nodiscard]] bool listino_db_pool(const char* field_key, ListinoPoolRow& out) noexcept;

[[nodiscard]] double listino_db_param(const char* key, double fallback) noexcept;

/** Seed tag / versione letta da meta (stringa vuota se assente). */
[[nodiscard]] std::string listino_db_seed_tag();

} /* namespace Alarmud */

#endif /* SRC_LISTINO_DB_HPP_ */
