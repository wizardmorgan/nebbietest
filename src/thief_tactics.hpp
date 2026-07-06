/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __THIEF_TACTICS_HPP
#define __THIEF_TACTICS_HPP
#include "typedefs.hpp"
namespace Alarmud {

int thief_skill_min_level(int skill);
bool thief_has_skill(struct char_data* ch, int skill);
void thief_on_advance_level(struct char_data* ch);
int thief_adjust_pierce_damage(struct char_data* attacker, struct char_data* victim,
                               int type, int dam, int raw_dam);
void thief_on_dodge_success(struct char_data* defender, struct char_data* attacker);
void thief_on_backstab_failed(struct char_data* attacker, struct char_data* victim);
void thief_on_victim_fell(struct char_data* victim, struct char_data* attacker);
bool thief_is_feinted(struct char_data* ch);
bool thief_is_hamstrung(struct char_data* ch);

ACTION_FUNC(do_sand);
ACTION_FUNC(do_tumble);
ACTION_FUNC(do_feint);
ACTION_FUNC(do_hamstring);
ACTION_FUNC(do_ckick);
ACTION_FUNC(do_gouge);
ACTION_FUNC(do_gag);
ACTION_FUNC(do_vault);
ACTION_FUNC(do_snatch);
ACTION_FUNC(do_poisoncraft);
ACTION_FUNC(do_envenom);
ACTION_FUNC(do_mix);
ACTION_FUNC(do_throwpotion);

} // namespace Alarmud
#endif
