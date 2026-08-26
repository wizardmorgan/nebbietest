/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_OBJ_EDIT_CATALOG_HPP_
#define SRC_OBJ_EDIT_CATALOG_HPP_

#include <string>

#include "../contrib/slacking/json.hpp"

namespace Alarmud {

using Json = nlohmann::json;

/** Vnum prototipo tan (TAN_* da skill tan). */
[[nodiscard]] bool object_vnum_is_tan_proto(int vnum) noexcept;

[[nodiscard]] bool object_is_tanned(const struct obj_data* obj) noexcept;

/** Motivo se non editabile (stringa vuota se editabile). */
[[nodiscard]] std::string object_portal_skip_reason(const struct obj_data* obj,
												  const char* toon_name);

/** wearpos MySQL: >0 = indossato (non editabile in portale). */
bool inventory_row_is_worn(int wearpos) noexcept;

/** Oggetto editabile nel portale (esclusioni listino + categorie staff). */
[[nodiscard]] bool object_portal_editable(const struct obj_data* obj,
										  const char* toon_name) noexcept;

/** false = non mostrare in inventario portale (food/potion sempre, categorie staff). */
[[nodiscard]] bool object_portal_show_in_inventory_list(const struct obj_data* obj,
														const char* toon_name) noexcept;

/** Catalogo edit oggetto (listino obj_value; pool PG esclusi sull'eq). */
[[nodiscard]] Json object_edit_catalog_json(bool is_armor, bool is_weapon);

/**
 * Simula un affect target sull'oggetto e restituisce delta costo vs stato attuale
 * (AnalyzeObjEdit prima/dopo). Per APPLY_IMMUNE modifier = bit IMM da aggiungere.
 */
[[nodiscard]] bool object_quote_affect_target(struct obj_data* obj, int location,
											  int target_modifier, long& xp_raw,
											  int& pq, std::string& err);

/** Imposta affect target (stessa logica di quote). Restituisce false se invalido. */
[[nodiscard]] bool object_apply_affect_target(struct obj_data* obj, int location,
											  int target_modifier, std::string& err);

[[nodiscard]] int object_affect_current_modifier(const struct obj_data* obj,
												 int location) noexcept;

[[nodiscard]] int object_immune_current_bits(const struct obj_data* obj) noexcept;

} // namespace Alarmud

#endif /* SRC_OBJ_EDIT_CATALOG_HPP_ */
