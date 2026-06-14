/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __PROC_CACAODEMON_HPP
#define __PROC_CACAODEMON_HPP

#include "typedefs.hpp"
#include <string>

namespace Alarmud {

/* Magnitudine 1-6 da vnum mob 20-25 (default 1). */
int cacaodemon_magnitude_from_vnum(int vnum);

bool is_cacaodemon(const struct char_data* mob);

/* Guardia del corpo: sempre il master; gruppo AFF_GROUP se livello demone <= 49. */
void cacaodemon_assign_bodyguard(struct char_data* demon, struct char_data* master);

bool cacaodemon_is_vigila_order(const std::string& command);

/* order <demon> vigila|guardia|proteggi — ripristina bodyguard master (+ gruppo se <= 49). */
bool cacaodemon_order_vigila(struct char_data* master, struct char_data* demon,
		const std::string& command);

// Modifica proceduralmente il mob appena allocato dall'engine prima del piazzamento
void proc_modify_cacaodemon(struct char_data* caster, struct char_data* demon, int spell_level);

// Special proc unica: smista il comportamento in base all'allineamento del demone
MOBSPECIAL_FUNC(spec_cacaodemon);

} // namespace Alarmud

#endif // __PROC_CACAODEMON_HPP
