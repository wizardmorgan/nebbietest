/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "config.hpp"
#include "typedefs.hpp"
#include "flags.hpp"
#include "structs.hpp"
#include "utils.hpp"
#include "multiclass.hpp"
#include "snew.hpp"
#include "signals.hpp"
#include "power_index.hpp"
#include <algorithm>
#include <cmath>
#include <vector>

namespace Alarmud {

extern struct char_data* character_list;

namespace {

struct SampleEntry {
	float eq = 0.0f;
	float weight = 1.0f;
};

float sample_level_weight(struct char_data* ch) {
	const int level = std::max(1, GetMaxLevel(ch));
	const float raw = std::sqrt(static_cast<float>(level) / 40.0f);
	return std::clamp(raw, POWER_INDEX_LEVEL_WEIGHT_MIN,
		POWER_INDEX_LEVEL_WEIGHT_MAX);
}

float weighted_median(std::vector<SampleEntry>& entries) {
	if(entries.empty()) {
		return 1.0f;
	}
	std::sort(entries.begin(), entries.end(),
		[](const SampleEntry& a, const SampleEntry& b) {
			return a.eq < b.eq;
		});
	float total_weight = 0.0f;
	for(const SampleEntry& entry : entries) {
		total_weight += entry.weight;
	}
	const float half = total_weight * 0.5f;
	float cumulative = 0.0f;
	for(const SampleEntry& entry : entries) {
		cumulative += entry.weight;
		if(cumulative >= half) {
			return entry.eq;
		}
	}
	return entries.back().eq;
}

float weighted_harmonic(const std::vector<SampleEntry>& entries) {
	float weight_sum = 0.0f;
	float weighted_reciprocal = 0.0f;
	for(const SampleEntry& entry : entries) {
		if(entry.eq <= 0.0f) {
			continue;
		}
		weight_sum += entry.weight;
		weighted_reciprocal += entry.weight / entry.eq;
	}
	if(weight_sum <= 0.0f || weighted_reciprocal <= 0.0f) {
		return 1.0f;
	}
	return weight_sum / weighted_reciprocal;
}

float blend_reference_eq(float median, float harmonic) {
	return (POWER_INDEX_MEDIAN_BLEND * median) +
		(POWER_INDEX_HARMONIC_BLEND * harmonic);
}

float stabilize_thin_sample(float reference, int online_count) {
	if(online_count <= 0 || online_count > POWER_INDEX_THIN_SAMPLE_MAX) {
		return reference;
	}
	const float historic = AverageEqIndex(-1);
	if(historic < 100.0f) {
		return reference;
	}
	const float online_weight =
		static_cast<float>(online_count) /
		static_cast<float>(POWER_INDEX_THIN_SAMPLE_MAX + 1);
	return (online_weight * reference) + ((1.0f - online_weight) * historic);
}

PowerIndexWorldEq snapshot_online_eq() {
	PowerIndexWorldEq out {};
	std::vector<SampleEntry> entries;
	float arithmetic_total = 0.0f;
	float arithmetic_weight = 0.0f;

	for(struct char_data* i = character_list; i != nullptr; i = i->next) {
		if(IS_NPC(i) || IS_IMMORTAL(i)) {
			continue;
		}
		const float eq = GetCharBonusIndex(i);
		if(eq <= 0.0f) {
			continue;
		}
		const float weight = sample_level_weight(i);
		entries.push_back({eq, weight});
		arithmetic_total += eq * weight;
		arithmetic_weight += weight;
		out.online_pc_count++;
	}

	if(out.online_pc_count == 0) {
		out.world_eq_arithmetic = 1.0f;
		out.world_eq_median = 1.0f;
		out.world_eq_harmonic = 1.0f;
		out.world_eq_reference = 1.0f;
		out.world_eq_avg = 1.0f;
		out.eq_factor = power_index_eq_factor_from_reference(out.world_eq_reference);
		return out;
	}

	out.world_eq_arithmetic = arithmetic_total / arithmetic_weight;
	out.world_eq_median = weighted_median(entries);
	out.world_eq_harmonic = weighted_harmonic(entries);
	out.world_eq_reference = blend_reference_eq(out.world_eq_median,
		out.world_eq_harmonic);
	out.world_eq_reference = stabilize_thin_sample(out.world_eq_reference,
		out.online_pc_count);
	out.world_eq_avg = out.world_eq_arithmetic;
	out.eq_factor = power_index_eq_factor_from_reference(out.world_eq_reference);
	return out;
}

} // namespace

float power_index_eq_factor_from_reference(float eq_reference) {
	if(eq_reference <= 0.0f) {
		return POWER_INDEX_EQ_FACTOR_FLOOR;
	}
	const float raw = eq_reference / POWER_INDEX_EQ_ANCHOR;
	const float span = POWER_INDEX_EQ_FACTOR_MAX - POWER_INDEX_EQ_FACTOR_FLOOR;
	const float factor = POWER_INDEX_EQ_FACTOR_FLOOR +
		(span * raw / (1.0f + raw));
	return std::max(POWER_INDEX_EQ_FACTOR_FLOOR, factor);
}

float power_index_eq_factor_from_avg(float eq_avg) {
	return power_index_eq_factor_from_reference(eq_avg);
}

float power_index_caster_eq_factor(float caster_eq, float world_eq_reference) {
	if(caster_eq <= 0.0f) {
		return POWER_INDEX_EQ_FACTOR_FLOOR;
	}
	const float reference = std::max(world_eq_reference, 1.0f);
	const float ratio = std::max(0.0f, caster_eq / reference);
	const float span = POWER_INDEX_EQ_FACTOR_MAX - POWER_INDEX_EQ_FACTOR_FLOOR;
	return POWER_INDEX_EQ_FACTOR_FLOOR +
		(span * ratio / (1.0f + ratio));
}

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
