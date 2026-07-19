/* cacaodemon_sacrifice.inc
 *
 * Specifiche sacrificio / mana per tier (alternativa A, power index).
 * Gli oggetti NON si usurano: fallimento PRIMA del consumo, altrimenti distruzione totale.
 *
 * Ottenimento in gioco (metodo 2): shop / quest / drop con:
 *   type ITEM_OTHER o ITEM_TREASURE
 *   value[0] == CACAODEMON_SACRIFICE_MARKER
 *   value[1] == tier 1..6 (accettato se >= tier calcolato)
 * Consumo solo dopo NoSummon e controlli OK.
 */

#ifndef __CACAODEMON_SACRIFICE_INC
#define __CACAODEMON_SACRIFICE_INC

namespace Alarmud {

constexpr int CACAODEMON_SACRIFICE_MARKER = 98001;

struct CacaoSacrificeTierSpec {
	int tier;
	int mana_extra_min;
	int mana_extra_max;
	int cost_min;
	int cost_max;
	const char* builder_hint;
};

static const CacaoSacrificeTierSpec kCacaoSacrificeTiers[] = {
	{ 1, 10,  25,   500,   2000, "sigillo minore / frammento rituale" },
	{ 2, 25,  45,  2000,   5000, "sigillo comune / cuore di costrutto" },
	{ 3, 45,  70,  5000,  12000, "sigillo maggiore / essenza legata" },
	{ 4, 70, 100, 12000,  25000, "sigillo arcano / nucleo risonante" },
	{ 5,100, 140, 25000,  50000, "sigillo solenne / reliquia di patto" },
	{ 6,140, 200, 50000, 100000, "sigillo rituale supremo" },
};

constexpr int kCacaoSacrificeTierCount =
	static_cast<int>(sizeof(kCacaoSacrificeTiers) / sizeof(kCacaoSacrificeTiers[0]));

} // namespace Alarmud

#endif
