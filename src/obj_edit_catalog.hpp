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

/** Slug e_item_type senza ITEM_ (es. armor, weapon). nullptr se ITEM_NONE o non mappato. */
[[nodiscard]] const char* object_portal_item_type_slug(int item_type) noexcept;

/** Motivo se non editabile (stringa vuota se editabile). */
[[nodiscard]] std::string object_portal_skip_reason(const struct obj_data* obj,
												  const char* toon_name);

/** wearpos MySQL: >0 = indossato. */
bool inventory_row_is_worn(int wearpos) noexcept;

/**
 * true se l'oggetto può essere editato anche indossato.
 * Path portale = MySQL offline: primo edit e ri-edit entrambi OK su wear_pos>0.
 */
[[nodiscard]] bool object_portal_allows_worn_edit(const struct obj_data* obj) noexcept;

/** Oggetto editabile nel portale (esclusioni listino + categorie staff). */
[[nodiscard]] bool object_portal_editable(const struct obj_data* obj,
										  const char* toon_name) noexcept;

/** false = non mostrare in inventario portale.
 * TAN/HAS-GEMS/simbolo: mai. RARO: nascosto salvo ri-edit (ITEM2_EDIT + EDNomeToon).
 * Categorie staff: pezzi EDIT/instance/owner bypassano solo le categorie. */
[[nodiscard]] bool object_portal_show_in_inventory_list(const struct obj_data* obj,
														const char* toon_name) noexcept;

/** Slot affect occupati / liberi (MAX_OBJ_AFFECT). */
[[nodiscard]] Json object_affect_slots_json(const struct obj_data* obj);

/** Catalogo edit oggetto (listino obj_value CheckValueObj; pool PG esclusi sull'eq). */
[[nodiscard]] Json object_edit_catalog_json(const struct obj_data* obj);

/**
 * Simula un affect target sull'oggetto e restituisce delta costo vs stato attuale
 * (AnalyzeObjEdit prima/dopo). Per APPLY_IMMUNE modifier = bit IMM da aggiungere.
 */
/**
 * Simula affect target.
 * Se other_worn_edited_dam >= 0 e l'edit tocca il dam → tetto 30
 * (somma delta vs proto su pezzi ITEM2_EDIT *indossati*, escluso questo).
 */
[[nodiscard]] bool object_quote_affect_target(struct obj_data* obj, int location,
											  int target_modifier, long& xp_raw,
											  int& pq, std::string& err,
											  int other_worn_edited_dam = -1,
											  int other_worn_edited_sp = -1);

/** Imposta affect target (stessa logica di quote). Restituisce false se invalido. */
[[nodiscard]] bool object_apply_affect_target(struct obj_data* obj, int location,
											  int target_modifier, std::string& err,
											  int other_worn_edited_dam = -1,
											  int other_worn_edited_sp = -1);

[[nodiscard]] int object_affect_current_modifier(const struct obj_data* obj,
												 int location) noexcept;

/** Totale effettivo sul pezzo (include HIT-N-DAM / HIT-N-SP). */
[[nodiscard]] int object_edit_display_current(const struct obj_data* obj,
											  int location) noexcept;

/** Dam effettivo sul pezzo (DAMROLL + HITNDAM). */
[[nodiscard]] int object_edit_damroll_total(const struct obj_data* obj) noexcept;

/** Spellpower effettivo sul pezzo (SPELLPOWER + HITNSP). */
[[nodiscard]] int object_edit_spellpower_total(const struct obj_data* obj) noexcept;

/**
 * Dam/SP *editato* = max(0, totale_pezzo − totale_prototipo).
 * Conta solo il bonus aggiunto rispetto all'originale.
 */
[[nodiscard]] int object_edit_damroll_edited_delta(const struct obj_data* obj) noexcept;
[[nodiscard]] int object_edit_spellpower_edited_delta(const struct obj_data* obj) noexcept;
[[nodiscard]] int object_edit_hitroll_edited_delta(const struct obj_data* obj) noexcept;

/** Hitroll effettivo sul pezzo (HITROLL + HITNDAM + HITNSP). */
[[nodiscard]] int object_edit_hitroll_total(const struct obj_data* obj) noexcept;

/** Dam sul prototipo risolto (0 se proto assente). */
[[nodiscard]] int object_edit_damroll_prototype_total(const struct obj_data* obj) noexcept;

/** Vnum prototipo usato per il delta edit (0 se sconosciuto). */
[[nodiscard]] int object_edit_prototype_vnum(const struct obj_data* obj) noexcept;

/**
 * true se il pezzo entra nel tetto dam/sp del toon:
 * ITEM2_EDIT + owner (personal_owner o ED*) del toon; esclusi simboli di clan.
 * Conta sia indossati che in inventario.
 */
[[nodiscard]] bool object_edit_counts_toward_combat_budget(const struct obj_data* obj,
														  const char* toon_name) noexcept;

/** true se location può cambiare il dam effettivo del pezzo. */
[[nodiscard]] bool object_edit_location_affects_dam(int location) noexcept;

/** true se location può cambiare lo spellpower effettivo del pezzo. */
[[nodiscard]] bool object_edit_location_affects_spellpower(int location) noexcept;

[[nodiscard]] int object_immune_current_bits(const struct obj_data* obj) noexcept;

/** Bit APPLY_M_IMMUNE (immunità concesse listino: drain/charm/poison). */
[[nodiscard]] int object_m_immune_current_bits(const struct obj_data* obj) noexcept;

[[nodiscard]] int object_spell_current_bits(const struct obj_data* obj) noexcept;

[[nodiscard]] int object_aff2_current_bits(const struct obj_data* obj) noexcept;

/** Ottimizza slot combat (hit-n-dam, hit-n-sp). */
void object_compact_edit_affects(struct obj_data* obj) noexcept;

} // namespace Alarmud

#endif /* SRC_OBJ_EDIT_CATALOG_HPP_ */
