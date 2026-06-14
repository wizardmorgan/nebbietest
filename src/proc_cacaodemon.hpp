/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __PROC_CACAODEMON_HPP
#define __PROC_CACAODEMON_HPP

#include "typedefs.hpp"

namespace Alarmud {

// Modifica proceduralmente il mob appena allocato dall'engine prima del piazzamento
void proc_modify_cacaodemon(struct char_data* caster, struct char_data* demon, int spell_level);

// Special proc unica: smista il comportamento in base all'allineamento del demone
MOBSPECIAL_FUNC(spec_cacaodemon);

} // namespace Alarmud

#endif // __PROC_CACAODEMON_HPP
