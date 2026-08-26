/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_EDIT_POOL_HPP_
#define SRC_EDIT_POOL_HPP_

#include "structs.hpp"

namespace Alarmud {

/** Massimali listino edits (per personaggio), unità raw come APPLY sull'eq. */
inline constexpr int kEditPoolMaxHit = 100;
inline constexpr int kEditPoolMaxMana = 150;
inline constexpr int kEditPoolMaxMove = 100;
inline constexpr int kEditPoolMaxHitRegen = 50;
inline constexpr int kEditPoolMaxManaRegen = 50;
inline constexpr int kEditPoolMaxMoveRegen = 50;

[[nodiscard]] bool edit_pool_is_pool_apply(int location) noexcept;

/** true se location e' uno dei 6 APPLY migrati sul PG. */
[[nodiscard]] bool edit_pool_location_blocked_on_eq(int location) noexcept;

/**
 * Delta vs prototipo (solo APPLY pool). Proto nullptr → tutto conta come edit.
 */
void edit_pool_accumulate_obj_delta(const struct obj_data* obj,
									const struct obj_data* proto,
									struct char_edit_pool_data* add);

/**
 * Porta gli APPLY pool dell'oggetto ai valori del prototipo: toglie l'extra
 * editato (gia' accreditato a parte) e lascia HIT/MANA/MOVE/regen di base.
 * Proto nullptr → azzera solo i pool apply (legacy).
 */
bool edit_pool_strip_obj(struct obj_data* obj, const struct obj_data* proto);

/**
 * Heal una tantum: istanze gia' strippate a APPLY_NONE ripristinano i pool
 * apply del base_vnum. Idempotente (event edit_pool_proto_restore).
 */
void edit_pool_heal_proto_pool_affects();

/**
 * Applica somma grezza ai campi edit/overedit rispettando i cap listino.
 * Non tocca `migrated`.
 */
void edit_pool_credit_raw(struct char_edit_pool_data* pool, int hit, int mana,
						  int move, int hit_regen, int mana_regen, int move_regen);

/** Campi del listino edit sul PG (comando editpool). */
enum class EditPoolField {
	Hp,
	Mana,
	Move,
	HpRegen,
	ManaRegen,
	MoveRegen
};

[[nodiscard]] int edit_pool_field_cap(EditPoolField field) noexcept;

/** Step UI/listino per incrementi sul PG (non coincide con add oggetto EditMaster). */
[[nodiscard]] int edit_pool_field_step(EditPoolField field) noexcept;

/** Chiave config / API: hit, mana, move, hit_regen, ... */
[[nodiscard]] const char* edit_pool_field_key(EditPoolField field) noexcept;

[[nodiscard]] bool edit_pool_parse_field_key(const char* key, EditPoolField& out) noexcept;

struct edit_pool_quote {
	long xp_raw = 0;
	int pq = 0;
	long mxp = 0;
	long mxp_frac = 0;
};

/**
 * Costo listino EditMaster (pedit comandi) per delta positivo sul pool PG.
 * Delta <= 0 → costo zero (riduzione non pagata).
 */
[[nodiscard]] edit_pool_quote edit_pool_quote_delta(EditPoolField field,
													int delta) noexcept;

/** 1 PQ equivale a questo ammontare di XP raw (PRICE_EXP in pedit). */
inline constexpr long kEditPoolPqPerMegaXp = 2000000L;

/** PQ di servizio come EditMaster (pagamento in MXP). */
inline constexpr int kEditPoolSessionPqFee = 1;

/**
 * Imposta il valore attivo (0..cap). Non tocca overedit_*.
 * Restituisce false se pool null.
 */
bool edit_pool_set_absolute(struct char_edit_pool_data* pool, EditPoolField field,
							int value);

/**
 * Somma delta: positivo usa credit (overflow → overedit); negativo toglie
 * prima da edit_* poi da overedit_*.
 */
bool edit_pool_add_delta(struct char_edit_pool_data* pool, EditPoolField field,
						 int delta);

/** Persiste edit_pool su character_stats (MySQL). Online o offline via toon. */
bool edit_pool_persist_char(struct char_data* ch);

/**
 * Dopo modifica pool: affect_total + clamp hit/mana/move correnti ai nuovi max.
 */
void edit_pool_apply_to_char(struct char_data* ch);

/**
 * Migrazione automatica EQ→PG per un personaggio online (dopo load inventorio).
 * Solo oggetti in range edit (34k) o con db_instance_id, proprietario (pers_on),
 * esclusi simboli del clan (ITEM_CLAN_SYMBOL / vnum in lista). Idempotente se edit_pool.migrated != 0.
 */
void edit_pool_migrate_char(struct char_data* ch);

/**
 * Boot: per ogni object_instance attiva, somma delta pool all'owner, strip affect,
 * aggiorna character_stats (solo se edit_pool_migrated=0). Poi marca migrated.
 */
void edit_pool_boot_migrate();

} // namespace Alarmud

#endif /* SRC_EDIT_POOL_HPP_ */
