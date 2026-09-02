/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __OBJ_VALUE_HPP
#define __OBJ_VALUE_HPP
/***************************  System  include ************************************/
#include <string>
/***************************  Local    include ************************************/
#include "typedefs.hpp"

namespace Alarmud {

/**
 * Valore di edit di un oggetto (idea da branch ProvaLocale).
 *
 * - valore: costo "edit" stimato dagli APPLY sull'oggetto
 * - derent: componente legata a cost_per_day (affitto)
 * - rune:  rune stimata da cost_per_day
 *
 * CheckValueObj restituisce unita' "raw".
 * CheckDiffValue restituisce la differenza rispetto al prototipo in unita'
 * storage legacy (raw * kObjValueStorageScale) per valore/derent, come in
 * ProvaLocale quando i campi venivano cachati su obj->value_exp.
 */
struct ExpValue {
	long valore{};
	long derent{};
	int rune{};
};

/** Report completo per wiz (stat): valori + elenco modifiche vs prototipo. */
struct ObjEditAnalysis {
	ExpValue absolute{};
	ExpValue diff{};
	/** Righe descrittive delle differenze (vuoto se identico al prototipo). */
	std::string changes;
	/**
	 * true se l'oggetto e' marcato EDIT/PERSONAL, oppure ha diff di valore,
	 * oppure ha differenze strutturali vs prototipo.
	 */
	bool has_edit{};
	/** Owner usato per moltiplicatore multiclasse (vuoto se sconosciuto). */
	std::string owner_name;
	/** 0 = non risolto (si applica x1); altrimenti HowManyClasses. */
	int owner_classes{};
	/** 1.0 / 1.5 / 2.0 da listino edits (mono/bi/tri). */
	double class_mult{1.0};
};

/** Fattore usato in ProvaLocale per cachare value_exp / value_exp_total. */
inline constexpr long kObjValueStorageScale = 10000L;

/** Derent/rent legacy (non usare EditMaster/pedit come listino portal). */
inline constexpr int kObjValuePriceRune = 1;
inline constexpr long kObjValuePriceExp = 2000000L;

/** Listino https://www.nebbiearcane.it/listino-edits/ : biclasse x1.5, triclasse x2.0. */
inline constexpr double kObjValueClassMultBi = 1.5;
inline constexpr double kObjValueClassMultTri = 2.0;

/** Massimo listino edits per pezzo (STR/CON/WIS/INT/DEX/CHR). */
inline constexpr int kObjEditMaxStatPerPiece = 3;

/** Damroll/hitroll/spellpower per pezzo; tetti editabili sul personaggio. */
inline constexpr int kObjEditMaxDamrollPerPiece = 2;
inline constexpr int kObjEditMaxHitrollPerPiece = 2;
inline constexpr int kObjEditMaxSpellpowerPerPiece = 2; /* come damroll */
inline constexpr int kObjEditMaxDamrollEditableTotal = 30;
inline constexpr int kObjEditMaxSpellpowerEditableTotal = 30; /* come damroll */
/** Hitroll editato totale (2/pezzo × 21 slot, escluso simbolo clan). */
inline constexpr int kObjEditMaxHitrollEditableTotal = 42;

/** Armor: step −10, fino a −40 per pezzo (listino ufficiale).
 *  Malus AC positivo: rimozione a 2× il costo del bonus equivalente. */
inline constexpr int kObjEditArmorStep = -10;
inline constexpr int kObjEditArmorMinTotal = -40;
inline constexpr int kObjEditArmorMaxTotal = 0;
/** Raw CheckValueObj per 1 punto AC bonus (1 MXP → 10 MXP per step −10). */
inline constexpr long kObjEditArmorUnitRaw = 100;

/**
 * Spellfail: step −5, 20 MXP per step (−5).
 * Per pezzo fino a −100 oltre proto; tetto personaggio −100 (somma delta vs proto).
 * Malus positivo: rimozione a 2× il bonus spellfail.
 */
inline constexpr int kObjEditSpellfailStep = -5;
inline constexpr int kObjEditSpellfailMinTotal = -100;
inline constexpr int kObjEditSpellfailMaxTotal = 0;
/** 20 MXP / step −5 → unit_raw * 5 * 10000 = 20e6 → unit = 400. */
inline constexpr long kObjEditSpellfailUnitRaw = 400;
/** Magnitudine massima edit spellfail sul personaggio (somma pezzi). */
inline constexpr int kObjEditMaxSpellfailEditableTotal = 100;

/** Listino portal: 1 MXP listino = 1 Rune (alternativa pagamento). */
inline constexpr long kObjEditRunePerMegaXp = 1000000L;

/**
 * Max lunghezza campi testo oggetto (allineati a VARCHAR inventorio/istanza).
 * Name/short/long via portal sono gratuiti (nessun listino ufficiale).
 */
inline constexpr int kObjEditTextNameMax = 128;
inline constexpr int kObjEditTextShortMax = 128;
inline constexpr int kObjEditTextLongMax = 256;

/** Parametri listino per un APPLY editabile sull'oggetto (totale sul pezzo). */
struct ObjEditListinoSpec {
	int location = 0;
	const char* id = "";
	const char* label = "";
	int step = 1;
	int min_total = 0;
	int max_total = 0;
	/** Unità raw CheckValueObj per +1 (o magnitudine −1 su AC). */
	long positive_unit_raw = 0;
	long negative_unit_raw = 0;
};

[[nodiscard]] bool obj_edit_listino_spec(int location, ObjEditListinoSpec& out) noexcept;

/** Numero di voci listino oggetto (scalar) esposte al portale. */
[[nodiscard]] int obj_edit_listino_scalar_count() noexcept;

[[nodiscard]] bool obj_edit_listino_scalar_at(int index, ObjEditListinoSpec& out) noexcept;

/**
 * Stima il valore assoluto di un oggetto dagli affect + cost_per_day.
 * Non modifica l'oggetto. obj == nullptr -> {0,0,0}.
 */
[[nodiscard]] ExpValue CheckValueObj(const struct obj_data* obj);

/**
 * Differenza di valore rispetto al prototipo (vnum / char_vnum se PERSONAL).
 * Unita': valore/derent in scala storage (* kObjValueStorageScale), rune raw.
 * Se l'oggetto ha ITEM_IMMUNE (Artifact) — gia' presente o aggiunto nello
 * stesso edit — il valore e' aumentato del 50% sul costo finale (dopo class_mult).
 */
[[nodiscard]] ExpValue CheckDiffValue(struct obj_data* obj);

/**
 * Analisi unica (un solo load del prototipo): valori + testo modifiche.
 * Usare questo da wiz invece di chiamare Check* + Describe separati.
 */
[[nodiscard]] ObjEditAnalysis AnalyzeObjEdit(struct obj_data* obj);

/**
 * Diff vs baseline esplicito (non carica il prototipo boot).
 * staff_incremental_absolute: valore = solo affect *aggiunti* vs baseline
 * (togliere bonus gia' in create/proto non abbassa il listino).
 */
[[nodiscard]] ObjEditAnalysis AnalyzeObjEditAgainst(struct obj_data* obj,
													const struct obj_data* baseline,
													bool staff_incremental_absolute = false);

/** Listino edit solo su modifiche staff dopo il primo osave db procarea. */
[[nodiscard]] ObjEditAnalysis AnalyzeProcareaStaffEdit(struct obj_data* obj);

/**
 * Applica la scala storage legacy a un ExpValue raw (valore/derent * scale).
 */
[[nodiscard]] ExpValue ScaleObjExpValue(const ExpValue& raw,
										long scale = kObjValueStorageScale) noexcept;

} // namespace Alarmud
#endif // __OBJ_VALUE_HPP
