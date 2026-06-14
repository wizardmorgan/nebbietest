/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __POWER_INDEX_HPP
#define __POWER_INDEX_HPP

#include "typedefs.hpp"

namespace Alarmud {

/** Snapshot dell'EQ medio online usato per il power index. */
struct PowerIndexWorldEq {
	float world_eq_avg = 1.0f;
	int online_pc_count = 0;
	float eq_factor = 1.0f;
};

/** Media GetCharBonusIndex sui PG online con equipment index > 0. */
PowerIndexWorldEq power_index_world_snapshot();

/**
 * Power index generico: livello_incantesimo * scala * fattore_EQ.
 * `world` opzionale evita un secondo scan della character_list.
 * `scale` e' un moltiplicatore libero (es. magnitudine cacaodemon 1-6, o 1
 * per spell che non usano tier).
 */
float compute_power_index(int spell_level, int scale,
		const PowerIndexWorldEq* world = nullptr);

} // namespace Alarmud

#endif // __POWER_INDEX_HPP
