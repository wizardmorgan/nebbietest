/* Seed listino ufficiale (una tantum → MySQL). Dopo il primo popolamento
 * la verita' e' nelle tabelle listino_*; questo file serve solo al bootstrap.
 * Includere dopo autoenums.hpp (serve APPLY_*).
 */

#ifndef LISTINO_SEED_INC_
#define LISTINO_SEED_INC_

namespace Alarmud {
namespace listino_seed {

struct AffectSeed {
	const char* id;
	const char* label;
	int location;
	int step;
	int min_total;
	int max_total;
	long pos_unit_raw;
	long neg_unit_raw;
};

struct PoolSeed {
	const char* field_key;
	const char* label;
	int cap;
	int step;
	long unit_valore;
	long xp_per_unit;
	int rune_num;
	int rune_den;
};

struct ParamSeed {
	const char* key;
	double value;
};

inline constexpr AffectSeed kAffectRows[] = {
	{"str", "Forza (STR)", APPLY_STR, 1, 0, 3, 1500, 3000},
	{"dex", "Destrezza (DEX)", APPLY_DEX, 1, 0, 3, 1500, 3000},
	{"int", "Intelligenza (INT)", APPLY_INT, 1, 0, 3, 1500, 3000},
	{"wis", "Saggezza (WIS)", APPLY_WIS, 1, 0, 3, 1500, 3000},
	{"chr", "Carisma (CHR)", APPLY_CHR, 1, 0, 3, 1500, 3000},
	{"hitroll", "Hitroll", APPLY_HITROLL, 1, 0, 2, 4500, 9000},
	{"damroll", "Damroll", APPLY_DAMROLL, 1, 0, 2, 10000, 20000},
	{"spellpower", "Spellpower", APPLY_SPELLPOWER, 1, 0, 2, 10000, 20000},
	{"armor", "Armatura (AC)", APPLY_AC, -10, -40, 0, 100, 200},
	{"spellfail", "Spellfail", APPLY_SPELLFAIL, -5, -100, 0, 400, 800},
	{"hitndam", "Hit & damage", APPLY_HITNDAM, 1, 0, 2, 14500, 29000},
	{"hitnsp", "Hit & spellpower", APPLY_HITNSP, 1, 0, 2, 14500, 29000},
};

inline constexpr PoolSeed kPoolRows[] = {
	{"hit", "Hit points", 100, 10, 300, 3000000L, 3, 1},
	{"mana", "Mana", 150, 10, 150, 1500000L, 3, 2},
	{"move", "Move", 100, 10, 100, 1000000L, 3, 2},
	{"hit_regen", "Hit regen", 50, 5, 300, 3000000L, 3, 1},
	{"mana_regen", "Mana regen", 50, 5, 300, 3000000L, 3, 1},
	{"move_regen", "Move regen", 50, 5, 200, 2000000L, 6, 1},
};

inline constexpr ParamSeed kParams[] = {
	{"storage_scale", 10000.0},
	{"class_mult_bi", 1.5},
	{"class_mult_tri", 2.0},
	/* Maggiorazione listino sugli affect (editpool / AnalyzeObjEdit). */
	{"artifact_mult", 1.5},
	/*
	 * Costo flag ARTIFACT da solo (unita' raw pre-storage_scale, come affect).
	 * 10000 → 100 MXP dopo * storage_scale; poi solo class_mult (no artifact_mult).
	 */
	{"artifact_cost_raw", 10000.0},
	{"broker_fee_percent", 25.0},
	{"seed_version", 2.0},
};

inline constexpr const char* kSeedTag = "listino_seed.inc/v2";

} /* namespace listino_seed */
} /* namespace Alarmud */

#endif /* LISTINO_SEED_INC_ */
