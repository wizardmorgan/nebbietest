/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef SRC_LISTINO_DB_HPP_
#define SRC_LISTINO_DB_HPP_

#include "obj_value.hpp"

#include <string>
#include <vector>

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
 * Store: listino unico `edit_listino` + `edit_listino_rules` (stesso schema
 * del MUD Server, heal_v15_edit_listino). Crea le tabelle se mancano (DDL
 * identico), aggiunge con INSERT IGNORE le righe/regole di listino_seed.inc
 * che mancano, copia broker_fee_percent dal vecchio listino_param se esiste,
 * poi carica in RAM mappando le righe sulle strutture storiche del portale:
 *   on_obj + APPLY numerico  -> affect oggetto (ObjEditListinoSpec)
 *   on_obj + APPLY_IMMUNE / M_IMMUNE / SUSC + apply_bit -> voce a bit
 *   on_pc  + APPLY pool      -> ListinoPoolRow
 *   cap_group                -> ListinoCapGroupRow (max cap_obj / cap_pc)
 *   edit_listino_rules       -> param (num/den; alias class_mult_bi/tri)
 * Ricarica: boot, listino_db_reload() (/internal/listino-reload da save/Sync
 * del portale). Nessun controllo periodico della firma.
 */
void listino_db_init();

/** Ricarica RAM da edit_listino (dopo edit staff dal portale o dal MUD). */
bool listino_db_reload();

/** Stato di una riga edit_listino per il portale (supporto MUD / attiva). */
struct ListinoRowStatus {
	std::string code;
	std::string kind;   /* affect | pool | flag | bit | other */
	bool enabled = false;   /* colonna enabled */
	bool supported = false; /* questo MUD sa usarla */
	bool active = false;    /* usata davvero dal listino in RAM */
	std::string reason;     /* perche' non supportata / non attiva */
};

[[nodiscard]] std::vector<ListinoRowStatus> listino_db_row_status();

/** true se la cache RAM e' popolata. */
[[nodiscard]] bool listino_db_ready() noexcept;

[[nodiscard]] int listino_db_affect_count() noexcept;

/** Spec come obj_edit_listino_*; false se indice fuori range. */
[[nodiscard]] bool listino_db_affect_at(int index, ObjEditListinoSpec& out) noexcept;

[[nodiscard]] bool listino_db_affect_by_location(int location,
												 ObjEditListinoSpec& out) noexcept;

/** Rune listino affect (per quote su toon). false se location assente. */
[[nodiscard]] bool listino_db_affect_rune(int location, int& rune_num,
										  int& rune_den) noexcept;

/** Voce listino a bit (APPLY_IMMUNE / APPLY_M_IMMUNE / APPLY_SUSC). */
[[nodiscard]] bool listino_db_affect_by_bit(int location, unsigned long apply_bit,
											ObjEditListinoSpec& out) noexcept;

[[nodiscard]] bool listino_db_affect_rune_bit(int location, unsigned long apply_bit,
											  int& rune_num, int& rune_den) noexcept;

/**
 * Somma il raw (unita' CheckValueObj) dei bit di `bits` presenti in cache;
 * i bit assenti restano in `bits` (il chiamante usa i prezzi hardcoded).
 */
[[nodiscard]] long listino_db_take_bit_raw(int location, unsigned& bits) noexcept;

/** Chiave cap_group per location (stringa vuota se nessuna). */
[[nodiscard]] std::string listino_db_affect_cap_group(int location);

struct ListinoCapGroupRow {
	std::string group_key;
	std::string label;
	int max_piece = 0;
	int max_character = 0;
	bool enabled = true;
};

[[nodiscard]] bool listino_db_cap_group(const char* group_key,
										ListinoCapGroupRow& out) noexcept;

[[nodiscard]] bool listino_db_pool(const char* field_key, ListinoPoolRow& out) noexcept;

[[nodiscard]] double listino_db_param(const char* key, double fallback) noexcept;

/** Revisione listino: "edit_listino@<unix max(updated_at)>" (vuota se mai caricato). */
[[nodiscard]] std::string listino_db_seed_tag();

} /* namespace Alarmud */

#endif /* SRC_LISTINO_DB_HPP_ */
