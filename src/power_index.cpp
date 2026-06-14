/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "config.hpp"
#include "typedefs.hpp"
#include "flags.hpp"
#include "structs.hpp"
#include "utils.hpp"
#include "snew.hpp"
#include "power_index.hpp"
#include <algorithm>

namespace Alarmud {

extern struct char_data* character_list;

namespace {

PowerIndexWorldEq snapshot_online_eq() {
	PowerIndexWorldEq out {};
	float total_eq = 0.0f;

	for(struct char_data* i = character_list; i != nullptr; i = i->next) {
		if(!IS_NPC(i) && GetCharBonusIndex(i) > 0.0f) {
			total_eq += GetCharBonusIndex(i);
			out.online_pc_count++;
		}
	}

	if(out.online_pc_count == 0) {
		out.world_eq_avg = 1.0f;
	} else {
		out.world_eq_avg = total_eq / static_cast<float>(out.online_pc_count);
	}
	out.eq_factor = std::max(1.0f, out.world_eq_avg / 100.0f);
	return out;
}

} // namespace

PowerIndexWorldEq power_index_world_snapshot() {
	return snapshot_online_eq();
}

float compute_power_index(int spell_level, int scale, const PowerIndexWorldEq* world) {
	const PowerIndexWorldEq local = world ? *world : snapshot_online_eq();
	const int lvl = std::max(1, spell_level);
	const int sc = std::max(1, scale);
	return static_cast<float>(lvl * sc) * local.eq_factor;
}

} // namespace Alarmud
