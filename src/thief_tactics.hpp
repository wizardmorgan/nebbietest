/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __THIEF_TACTICS_HPP
#define __THIEF_TACTICS_HPP
#include "typedefs.hpp"
#include <string>
namespace Alarmud {

enum ThiefPoisonType : int {
	THIEF_POISON_WEAK = 1,
	THIEF_POISON_NUMB,
	THIEF_POISON_BLEED,
	THIEF_POISON_PARALYTIC,
	THIEF_POISON_NIGHTFALL,
	THIEF_POISON_BLACKLOTUS
};

enum ThiefPotionType : int {
	THIEF_POTION_ACID = 1,
	THIEF_POTION_SMOKE,
	THIEF_POTION_FIRE,
	THIEF_POTION_CHOKING,
	THIEF_POTION_SHRAPNEL,
	THIEF_POTION_SAND
};

int thief_skill_min_level(int skill);
bool thief_has_skill(struct char_data* ch, int skill);
bool thief_skill_practice_allowed(struct char_data* ch, int skill);
int thief_resolve_guild_practice(const char* arg);
void thief_send_guild_practice_list(struct char_data* ch);
void thief_append_skill_sheet(struct char_data* ch, std::string& buffer);
void thief_on_advance_level(struct char_data* ch);
int thief_adjust_pierce_damage(struct char_data* attacker, struct char_data* victim,
                               int type, int dam, int raw_dam);
void thief_on_dodge_success(struct char_data* defender, struct char_data* attacker);
void thief_on_backstab_failed(struct char_data* attacker, struct char_data* victim);
void thief_on_victim_fell(struct char_data* victim, struct char_data* attacker);
bool thief_is_feinted(struct char_data* ch);
bool thief_is_hamstrung(struct char_data* ch);
void thief_on_weapon_hit(struct char_data* ch, struct char_data* victim, DamageResult result);
int thief_poison_type_from_obj(struct obj_data* obj);
int thief_potion_type_from_obj(struct obj_data* obj);

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
