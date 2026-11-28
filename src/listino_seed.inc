/* Seed di bootstrap del listino unico `edit_listino` / `edit_listino_rules`.
 *
 * La fonte di verita' e' la tabella MySQL `edit_listino` condivisa con il MUD
 * (Server: heal_v15_edit_listino + kEditListinoDefaults in obj_value.cpp).
 * Questo file serve SOLO se il portale/myst parte su un DB dove il MUD non ha
 * ancora creato e seminato il listino: le righe vanno con INSERT IGNORE, quindi
 * non sovrascrivono mai valori gia' presenti (staff, configure editpool, web).
 *
 * I valori DEVONO restare identici a kEditListinoDefaults del Server (prezzi
 * BASE, senza artifact/classe). Qui c'e' solo il sottoinsieme che il portale
 * usa (stat, combat, pool, spellfail PG, artifact) e le 54 voci a bit
 * (resist_bit / immune_bit / susc_bit, con resist_equiv e resist_code).
 * Le altre (weapon_spell, resist_num, unused, aff2) le aggiunge il MUD al boot.
 *
 * Semantica colonne (vedi Server src/edit_listino.hpp):
 *   xp          prezzo base per `step` unita' (AC: 10M per slot da 10)
 *   rune_num/den rune per `step` unita'
 *   sign        +1 meglio se positivo, -1 meglio se negativo (ac, spellfail)
 *   cap_obj     max per pezzo (in unita', positivo anche per AC: 40 = -40)
 *   on_obj/on_pc vendibile su oggetto / sul PG (editpool). 0/0 = disattivata
 *   cap_pc      cap totale sul PG; cap_group raggruppa (dam_sp)
 *   buy_step    passo di acquisto (pool 10, regen 5); 1 = libero
 *   enabled     interruttore voce (0 = spenta; le voci nuove nascono spente)
 *   resist_equiv +50 resi, +100 immu, -50 susc; 0 altrimenti
 *   resist_code  riga numerica resist_<elem> collegata, o ""
 *
 * Includere dopo autoenums.hpp (serve APPLY_* / IMM_* / ITEM_IMMUNE).
 */

#ifndef LISTINO_SEED_INC_
#define LISTINO_SEED_INC_

namespace Alarmud {
namespace listino_seed {

struct EditListinoSeedRow {
	const char* code;
	const char* label;
	const char* category;
	long xp;
	int rune_num;
	int rune_den;
	int sign;
	int cap_obj;
	int step;
	int on_obj;
	int on_pc;
	int cap_pc;
	const char* cap_group;
	int over_cap;
	int over_step;
	int over_rune;
	long over_xp;
	long over_gold;
	int over_inc_pct;
	int apply_loc;
	unsigned long apply_bit;
	int resist_equiv;        /* +50 resi, +100 immu, -50 susc; 0 altrimenti */
	const char* resist_code; /* riga numerica resist_<elem>, o "" */
	int buy_step; /* passo di acquisto (pool 10 / regen 5), 1 altrimenti */
	int enabled;  /* 1 = voce attiva (seed: attive quelle con on_obj/on_pc) */
};

struct EditListinoRuleSeed {
	const char* conf_key;
	int num;
	int den;
};

/* clang-format off */
inline constexpr EditListinoSeedRow kListinoRows[] = {
	{"str", "Forza", "stat", 15000000L, 15, 1, 1, 3, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_STR, 0UL, 0, "", 1, 1},
	{"dex", "Destrezza", "stat", 15000000L, 15, 1, 1, 3, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_DEX, 0UL, 0, "", 1, 1},
	{"intel", "Intelligenza", "stat", 15000000L, 15, 1, 1, 3, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_INT, 0UL, 0, "", 1, 1},
	{"wis", "Saggezza", "stat", 15000000L, 15, 1, 1, 3, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_WIS, 0UL, 0, "", 1, 1},
	{"con", "Costituzione", "unused", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_CON, 0UL, 0, "", 1, 0},
	{"chr", "Carisma", "stat", 15000000L, 10, 1, 1, 3, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_CHR, 0UL, 0, "", 1, 1},
	{"mana", "Mana", "pool", 1500000L, 22, 15, 1, 0, 1, 0, 1, 150, "", 0, 0, 0, 0L, 0L, 0, APPLY_MANA, 0UL, 0, "", 10, 1},
	{"hit", "Hit", "pool", 3000000L, 3, 1, 1, 0, 1, 0, 1, 100, "", 0, 0, 0, 0L, 0L, 0, APPLY_HIT, 0UL, 0, "", 10, 1},
	{"move", "Move", "pool", 1000000L, 1, 1, 1, 0, 1, 0, 1, 100, "", 0, 0, 0, 0L, 0L, 0, APPLY_MOVE, 0UL, 0, "", 10, 1},
	{"mana_regen", "Mana regen", "pool", 3000000L, 44, 15, 1, 0, 1, 0, 1, 50, "", 0, 0, 0, 0L, 0L, 0, APPLY_MANA_REGEN, 0UL, 0, "", 5, 1},
	{"hit_regen", "Hit regen", "pool", 3000000L, 44, 15, 1, 0, 1, 0, 1, 50, "", 0, 0, 0, 0L, 0L, 0, APPLY_HIT_REGEN, 0UL, 0, "", 5, 1},
	{"move_regen", "Move regen", "pool", 2000000L, 4, 1, 1, 0, 1, 0, 1, 50, "", 0, 0, 0, 0L, 0L, 0, APPLY_MOVE_REGEN, 0UL, 0, "", 5, 1},
	{"spellfail", "Spellfail", "pool", 20000000L, 24, 1, -1, 0, 1, 0, 1, 100, "", 50, 5, 120, 100000000L, 500000L, 50, APPLY_SPELLFAIL, 0UL, 0, "", 1, 1},
	{"ac", "Classe armatura", "combat", 10000000L, 15, 1, -1, 40, 10, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_AC, 0UL, 0, "", 1, 1},
	{"hitroll", "Hitroll", "combat", 45000000L, 50, 1, 1, 2, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_HITROLL, 0UL, 0, "", 1, 1},
	{"damroll", "Damroll", "combat", 100000000L, 120, 1, 1, 2, 1, 1, 0, 30, "dam_sp", 0, 0, 0, 0L, 0L, 0, APPLY_DAMROLL, 0UL, 0, "", 1, 1},
	{"spellpower", "Spellpower", "combat", 100000000L, 120, 1, 1, 2, 1, 1, 0, 30, "dam_sp", 0, 0, 0, 0L, 0L, 0, APPLY_SPELLPOWER, 0UL, 0, "", 1, 1},
	{"hitndam", "Hit-n-Dam", "combat", 145000000L, 170, 1, 1, 2, 1, 1, 0, 30, "dam_sp", 0, 0, 0, 0L, 0L, 0, APPLY_HITNDAM, 0UL, 0, "", 1, 1},
	{"hitnsp", "Hit-n-SP", "combat", 145000000L, 170, 1, 1, 2, 1, 1, 0, 30, "dam_sp", 0, 0, 0, 0L, 0L, 0, APPLY_HITNSP, 0UL, 0, "", 1, 1},
	{"artifact", "Artifact", "extra", 100000000L, 100, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, 0, ITEM_IMMUNE, 0, "", 1, 1},
	{"immune_acid", "Resi acido", "resist_bit", 75000000L, 90, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_ACID, 50, "resist_acid", 1, 1},
	{"immune_elec", "Resi elettricita", "resist_bit", 150000000L, 180, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_ELEC, 50, "resist_elec", 1, 1},
	{"immune_fire", "Resi fuoco", "resist_bit", 100000000L, 120, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_FIRE, 50, "resist_fire", 1, 1},
	{"immune_cold", "Resi freddo", "resist_bit", 75000000L, 90, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_COLD, 50, "resist_cold", 1, 1},
	{"immune_energy", "Resi energia", "resist_bit", 150000000L, 180, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_ENERGY, 50, "resist_energy", 1, 1},
	{"immune_drain", "Resi drain", "resist_bit", 30000000L, 35, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_DRAIN, 50, "resist_drain", 1, 1},
	{"immune_hold", "Resi hold", "resist_bit", 75000000L, 90, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_HOLD, 50, "resist_hold", 1, 1},
	{"immune_poison", "Resi veleno", "resist_bit", 30000000L, 35, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_POISON, 50, "resist_poison", 1, 1},
	{"immune_slash", "Resi slash", "resist_bit", 150000000L, 200, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_SLASH, 50, "resist_slash", 1, 1},
	{"immune_pierce", "Resi pierce", "resist_bit", 150000000L, 200, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_PIERCE, 50, "resist_pierce", 1, 1},
	{"immune_blunt", "Resi blunt", "resist_bit", 300000000L, 400, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_BLUNT, 50, "resist_blunt", 1, 1},
	{"immune_sleep", "Resi sleep", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_SLEEP, 50, "resist_sleep", 1, 0},
	{"immune_charm", "Resi charm", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_CHARM, 50, "resist_charm", 1, 0},
	{"immune_nonmag", "Resi nonmag", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_NONMAG, 50, "resist_nonmag", 1, 0},
	{"immune_plus1", "Resi plus1", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_PLUS1, 50, "resist_plus1", 1, 0},
	{"immune_plus2", "Resi plus2", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_PLUS2, 50, "resist_plus2", 1, 0},
	{"immune_plus3", "Resi plus3", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_PLUS3, 50, "resist_plus3", 1, 0},
	{"immune_plus4", "Resi plus4", "resist_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_IMMUNE, IMM_PLUS4, 50, "resist_plus4", 1, 0},
	{"mimmune_drain", "Immunita drain", "immune_bit", 100000000L, 100, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_DRAIN, 100, "resist_drain", 1, 1},
	{"mimmune_charm", "Immunita charm", "immune_bit", 60000000L, 60, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_CHARM, 100, "resist_charm", 1, 1},
	{"mimmune_poison", "Immunita veleno", "immune_bit", 100000000L, 100, 1, 1, 1, 1, 1, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_POISON, 100, "resist_poison", 1, 1},
	{"mimmune_fire", "Immunita fire", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_FIRE, 100, "resist_fire", 1, 0},
	{"mimmune_cold", "Immunita cold", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_COLD, 100, "resist_cold", 1, 0},
	{"mimmune_elec", "Immunita elec", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_ELEC, 100, "resist_elec", 1, 0},
	{"mimmune_energy", "Immunita energy", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_ENERGY, 100, "resist_energy", 1, 0},
	{"mimmune_blunt", "Immunita blunt", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_BLUNT, 100, "resist_blunt", 1, 0},
	{"mimmune_pierce", "Immunita pierce", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_PIERCE, 100, "resist_pierce", 1, 0},
	{"mimmune_slash", "Immunita slash", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_SLASH, 100, "resist_slash", 1, 0},
	{"mimmune_acid", "Immunita acid", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_ACID, 100, "resist_acid", 1, 0},
	{"mimmune_sleep", "Immunita sleep", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_SLEEP, 100, "resist_sleep", 1, 0},
	{"mimmune_hold", "Immunita hold", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_HOLD, 100, "resist_hold", 1, 0},
	{"mimmune_nonmag", "Immunita nonmag", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_NONMAG, 100, "resist_nonmag", 1, 0},
	{"mimmune_plus1", "Immunita plus1", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_PLUS1, 100, "resist_plus1", 1, 0},
	{"mimmune_plus2", "Immunita plus2", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_PLUS2, 100, "resist_plus2", 1, 0},
	{"mimmune_plus3", "Immunita plus3", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_PLUS3, 100, "resist_plus3", 1, 0},
	{"mimmune_plus4", "Immunita plus4", "immune_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_M_IMMUNE, IMM_PLUS4, 100, "resist_plus4", 1, 0},
	{"susc_fire", "Suscettibilita fire", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_FIRE, -50, "resist_fire", 1, 0},
	{"susc_cold", "Suscettibilita cold", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_COLD, -50, "resist_cold", 1, 0},
	{"susc_elec", "Suscettibilita elec", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_ELEC, -50, "resist_elec", 1, 0},
	{"susc_energy", "Suscettibilita energy", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_ENERGY, -50, "resist_energy", 1, 0},
	{"susc_blunt", "Suscettibilita blunt", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_BLUNT, -50, "resist_blunt", 1, 0},
	{"susc_pierce", "Suscettibilita pierce", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_PIERCE, -50, "resist_pierce", 1, 0},
	{"susc_slash", "Suscettibilita slash", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_SLASH, -50, "resist_slash", 1, 0},
	{"susc_acid", "Suscettibilita acid", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_ACID, -50, "resist_acid", 1, 0},
	{"susc_poison", "Suscettibilita poison", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_POISON, -50, "resist_poison", 1, 0},
	{"susc_drain", "Suscettibilita drain", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_DRAIN, -50, "resist_drain", 1, 0},
	{"susc_sleep", "Suscettibilita sleep", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_SLEEP, -50, "resist_sleep", 1, 0},
	{"susc_charm", "Suscettibilita charm", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_CHARM, -50, "resist_charm", 1, 0},
	{"susc_hold", "Suscettibilita hold", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_HOLD, -50, "resist_hold", 1, 0},
	{"susc_nonmag", "Suscettibilita nonmag", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_NONMAG, -50, "resist_nonmag", 1, 0},
	{"susc_plus1", "Suscettibilita plus1", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_PLUS1, -50, "resist_plus1", 1, 0},
	{"susc_plus2", "Suscettibilita plus2", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_PLUS2, -50, "resist_plus2", 1, 0},
	{"susc_plus3", "Suscettibilita plus3", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_PLUS3, -50, "resist_plus3", 1, 0},
	{"susc_plus4", "Suscettibilita plus4", "susc_bit", 0L, 0, 1, 1, 0, 1, 0, 0, 0, "", 0, 0, 0, 0L, 0L, 0, APPLY_SUSC, IMM_PLUS4, -50, "resist_plus4", 1, 0},
};
/* clang-format on */

/* Regole: le prime otto come kEditListinoRulesDefaults del Server.
 * broker_fee_percent (num/den = percentuale) e' del portale.
 * artifact_cost_xp: costo base flag artifact, x class_mult (regole
 * class_mult_1/2/3), niente artifact_mult; default anche nel Server. */
inline constexpr EditListinoRuleSeed kRuleRows[] = {
	{"artifact_mult", 3, 2},
	{"class_mult_1", 1, 1},
	{"class_mult_2", 3, 2},
	{"class_mult_3", 2, 1},
	{"malus_mult", 2, 1},
	{"xp_split_by_classes", 1, 1},
	{"rune_rounding", 1, 1},
	{"over_progression", 1, 1},
	{"broker_fee_percent", 25, 1},
	/* Flag artifact: xp base x class_mult (mono 100M, bi 150M, tri 200M). */
	{"artifact_cost_xp", 100000000, 1},
};

/* Etichette gruppi cap (tabella edit_listino_cap_group). */
struct CapGroupSeed {
	const char* code;
	const char* label;
};
inline constexpr CapGroupSeed kCapGroupRows[] = {
	{"dam_sp", "Damroll + Spellpower"},
};

/* Scala storica raw CheckValueObj -> xp (unit_raw * 10000 = xp). */
inline constexpr long kStorageScale = 10000L;

inline constexpr const char* kSeedTag = "edit_listino";

} /* namespace listino_seed */
} /* namespace Alarmud */

#endif /* LISTINO_SEED_INC_ */
