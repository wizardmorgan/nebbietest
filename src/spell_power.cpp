/*ALARMUD*
 * Indice di potenza riusabile (gruppo = formula Dimensioni Effimere).
 *ALARMUD*/
#include "spell_power.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

#include "config.hpp"
#include "structs.hpp"
#include "snew.hpp"
#include "utils.hpp"

namespace Alarmud {

namespace {

[[nodiscard]] char_data* spell_group_leader(char_data* ch) {
	if(ch == nullptr) {
		return nullptr;
	}
	char_data* leader = ch;
	while(leader->master != nullptr && IS_AFFECTED(leader, AFF_GROUP) &&
		  IS_AFFECTED(leader->master, AFF_GROUP)) {
		leader = leader->master;
	}
	return leader;
}

[[nodiscard]] bool spell_party_member_ready(char_data* member, long room) {
	return member != nullptr && IS_PC(member) && member->in_room == room &&
		   GET_POS(member) >= POSITION_STANDING && member->specials.fighting == nullptr;
}

void spell_party_add_unique(std::vector<char_data*>& party, char_data* member, long room) {
	if(!spell_party_member_ready(member, room)) {
		return;
	}
	if(std::find(party.begin(), party.end(), member) != party.end()) {
		return;
	}
	party.push_back(member);
}

[[nodiscard]] std::vector<char_data*> spell_party_in_room(char_data* ch) {
	std::vector<char_data*> party;
	if(ch == nullptr || !IS_PC(ch)) {
		return party;
	}
	const long room = ch->in_room;
	if(!IS_AFFECTED(ch, AFF_GROUP)) {
		spell_party_add_unique(party, ch, room);
		for(follow_type* fol = ch->followers; fol != nullptr; fol = fol->next) {
			spell_party_add_unique(party, fol->follower, room);
		}
		return party;
	}

	char_data* leader = spell_group_leader(ch);
	spell_party_add_unique(party, leader, room);
	for(follow_type* fol = leader->followers; fol != nullptr; fol = fol->next) {
		char_data* member = fol->follower;
		if(member != nullptr && IS_PC(member) && IS_AFFECTED(member, AFF_GROUP)) {
			spell_party_add_unique(party, member, room);
		}
	}
	return party;
}

[[nodiscard]] float spell_group_power_from_members(const std::vector<char_data*>& group) {
	if(group.empty()) {
		return 0.0f;
	}
	float sum = 0.0f;
	float peak = 0.0f;
	for(char_data* member : group) {
		const float power = ProcAreaPowerIndex(member);
		sum += power;
		peak = std::max(peak, power);
	}
	const float avg = sum / static_cast<float>(group.size());
	return SPELL_GROUP_POWER_AVG_WEIGHT * avg + SPELL_GROUP_POWER_MAX_WEIGHT * peak;
}

} // namespace

float SpellPowerIndex(struct char_data* ch) {
	return ProcAreaPowerIndex(ch);
}

float SpellGroupPowerIndex(struct char_data* ch) {
	if(ch == nullptr) {
		return 0.0f;
	}
	const auto party = spell_party_in_room(ch);
	if(party.empty()) {
		return ProcAreaPowerIndex(ch);
	}
	return spell_group_power_from_members(party);
}

float SpellPowerFactor(float power_index) {
	return std::clamp((power_index - SPELL_POWER_SCALE_MIN) /
						  (SPELL_POWER_SCALE_MAX - SPELL_POWER_SCALE_MIN),
					  0.0f, 1.0f);
}

bool SpellHasPowerCasterClass(struct char_data* ch) {
	return ch != nullptr && HasClass(ch, SPELL_POWER_CASTER_CLASSES);
}

float SpellClassPowerMult(struct char_data* ch) {
	if(ch == nullptr) {
		return SPELL_CLASS_MULT_NO_CASTER;
	}

	/* Senza CL/MU/SO non puo' lanciare: niente rami "multi senza caster". */
	if(!SpellHasPowerCasterClass(ch)) {
		return SPELL_CLASS_MULT_NO_CASTER;
	}

	const int nclass = HowManyClasses(ch);
	const bool has_fighter = IS_FIGHTER(ch);
	const bool mono_so = nclass == 1 && HasClass(ch, CLASS_SORCERER);
	const bool mono_cl = nclass == 1 && HasClass(ch, CLASS_CLERIC);
	const bool mono_mu = nclass == 1 && HasClass(ch, CLASS_MAGIC_USER);

	if(mono_so || mono_cl) {
		return SPELL_CLASS_MULT_MONO_SO_CL;
	}
	if(mono_mu) {
		return SPELL_CLASS_MULT_MONO_MU;
	}

	/* Multiclass con almeno una tra CL/MU/SO: solo fighter vs non-fighter. */
	if(nclass == 2) {
		return has_fighter ? SPELL_CLASS_MULT_DUAL_FIGHTER
						   : SPELL_CLASS_MULT_DUAL_NO_FIGHTER;
	}
	return has_fighter ? SPELL_CLASS_MULT_TRI_FIGHTER
					   : SPELL_CLASS_MULT_TRI_NO_FIGHTER;
}

float SpellEffectivePower(struct char_data* ch) {
	const float mult = SpellClassPowerMult(ch);
	if(mult <= 0.0f) {
		return 0.0f;
	}
	return SpellGroupPowerIndex(ch) * mult;
}

int SpellPowerTierFromFactor(float factor) {
	const float f = std::clamp(factor, 0.0f, 1.0f);
	const int tier = 1 + static_cast<int>(f * static_cast<float>(SPELL_POWER_TIER_MAX - 1) + 1.0e-5f);
	return std::clamp(tier, SPELL_POWER_TIER_MIN, SPELL_POWER_TIER_MAX);
}

} // namespace Alarmud
