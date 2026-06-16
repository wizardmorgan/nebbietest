/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/

#include "psi_skill_migration.hpp"

#include "flags.hpp"
#include "spell_parser.hpp"
#include "spells.hpp"
#include "structs.hpp"
#include "utils.hpp"

namespace Alarmud {

void migrate_psi_skills(struct char_data* ch) {
	if(ch == nullptr || ch->skills == nullptr || !HasClass(ch, CLASS_PSI)) {
		return;
	}

	for(int i = 1; i < MAX_SPL_LIST; ++i) {
		const ubyte min_psi = spell_info[i].min_level_psi;
		if(min_psi == 0 || min_psi >= IMMORTALE) {
			continue;
		}
		if(ch->skills[i].learned <= 0) {
			continue;
		}

		if(!IS_SET(ch->skills[i].flags, SKILL_KNOWN)) {
			SET_BIT(ch->skills[i].flags, SKILL_KNOWN);
		}
		if(!IS_SET(ch->skills[i].flags, SKILL_KNOWN_PSI)) {
			SET_BIT(ch->skills[i].flags, SKILL_KNOWN_PSI);
		}
	}
}

} // namespace Alarmud
