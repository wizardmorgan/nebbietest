/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __POWER_INDEX_HPP
#define __POWER_INDEX_HPP

#include "typedefs.hpp"

namespace Alarmud {

/** EQ di riferimento tipico endgame per la curva soft-cap del fattore. */
static constexpr float POWER_INDEX_EQ_ANCHOR = 3000.0f;

/** Asintoto superiore del fattore EQ (soft cap, non clamp lineare). */
static constexpr float POWER_INDEX_EQ_FACTOR_MAX = 4.0f;
static constexpr float POWER_INDEX_EQ_FACTOR_FLOOR = 1.0f;

/** Blend mediana / media armonica nel EQ di riferimento mondo. */
static constexpr float POWER_INDEX_MEDIAN_BLEND = 0.6f;
static constexpr float POWER_INDEX_HARMONIC_BLEND = 0.4f;

/** Peso campione per livello: sqrt(livello/40), clamp [MIN, MAX]. */
static constexpr float POWER_INDEX_LEVEL_WEIGHT_MIN = 0.25f;
static constexpr float POWER_INDEX_LEVEL_WEIGHT_MAX = 1.0f;

/** Con pochissimi PG online, stabilizza EQ_ref verso la media storica rent. */
static constexpr int POWER_INDEX_THIN_SAMPLE_MAX = 2;

/** Snapshot dell'EQ online usato per il power index. */
struct PowerIndexWorldEq {
	float world_eq_arithmetic = 1.0f;
	float world_eq_median = 1.0f;
	float world_eq_harmonic = 1.0f;
	float world_eq_reference = 1.0f;
	int online_pc_count = 0;
	float eq_factor = 1.0f;

	/** Compatibilita' con codice che leggeva la media aritmetica. */
	float world_eq_avg = 1.0f;
};

/** Curva soft-cap: factor = floor + (max-floor) * (eq/anchor) / (1 + eq/anchor). */
float power_index_eq_factor_from_reference(float eq_reference);

/** @deprecated Usare power_index_eq_factor_from_reference(); mappa eq/anchor. */
float power_index_eq_factor_from_avg(float eq_avg);

/**
 * Fattore personale relativo all'EQ di riferimento del mondo (rapporto caster/ref).
 */
float power_index_caster_eq_factor(float caster_eq, float world_eq_reference);

/** Media GetCharBonusIndex sui PG mortali online con equipment index > 0. */
PowerIndexWorldEq power_index_world_snapshot();

/**
 * Power index generico neutro: livello_incantesimo * scala * fattore_EQ_mondo.
 * Usabile da spell, skill, mob procedurali, ecc.
 */
float compute_power_index(int spell_level, int scale,
		const PowerIndexWorldEq* world = nullptr);

} // namespace Alarmud

#endif // __POWER_INDEX_HPP
