/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_CHARACTER_EDIT_AFFECT_HPP_
#define SRC_CHARACTER_EDIT_AFFECT_HPP_

#include <string>
#include <utility>
#include <vector>

#include "typedefs.hpp"

namespace Alarmud {

/** Tipo affect permanente portale (fuori da MAX_SKILLS). */
inline constexpr short kCharacterEditAffectType = 32001;

struct CharEditAffectRow {
	int location = 0;
	int value = 0;
};

/** Crea tabella character_edit_affect se manca. */
void character_edit_affect_ensure_schema();

[[nodiscard]] bool character_edit_affect_load(unsigned long long toon_id,
											  std::vector<CharEditAffectRow>& out);

[[nodiscard]] int character_edit_affect_get(unsigned long long toon_id, int location);

/**
 * Upsert valore assoluto (0 = DELETE riga).
 * Restituisce false su errore SQL.
 */
[[nodiscard]] bool character_edit_affect_set(unsigned long long toon_id, int location,
											int value, std::string& err);

/**
 * Rimuove affect portale precedenti e riapplica da MySQL sul PG online.
 * Chiamare dopo load inventario / migrate pool.
 */
void character_edit_affect_apply_to_char(struct char_data* ch);

/**
 * Costo XP raw per delta (listino affect x scale x class_mult x artifact sempre).
 * Rune parallele da rune_num/den sulla riga listino (0 se assenti).
 */
[[nodiscard]] std::pair<long, int> character_edit_affect_quote_paid(int location,
																   int delta_units,
																   int n_classes);

} /* namespace Alarmud */

#endif /* SRC_CHARACTER_EDIT_AFFECT_HPP_ */
