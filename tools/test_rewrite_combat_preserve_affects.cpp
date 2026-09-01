/*
 * Standalone repro: combat rewrite must preserve APPLY_IMMUNE / APPLY_SPELL.
 * g++ -std=c++17 -O0 -o /tmp/test_rewrite_combat \
 *   tools/test_rewrite_combat_preserve_affects.cpp && /tmp/test_rewrite_combat
 */
#include <cstdio>
#include <cstring>

enum {
	APPLY_NONE = 0,
	APPLY_SKIP = 1,
	APPLY_HIT = 12,
	APPLY_HITROLL = 18,
	APPLY_DAMROLL = 19,
	APPLY_IMMUNE = 26,
	APPLY_SPELL = 29,
	APPLY_HIT_REGEN = 60,
	APPLY_HITNDAM = 63,
	APPLY_SPELLPOWER = 65,
	APPLY_HITNSP = 66,
};

constexpr int MAX_OBJ_AFFECT = 5;
constexpr int IMM_ACID = 128;
constexpr int AFF_SCRYING = 67108864;

struct obj_affected_type {
	short location;
	int modifier;
};

struct obj_data {
	obj_affected_type affected[MAX_OBJ_AFFECT];
};

static int find_affect_slot_for_location(const obj_data* obj, int location) {
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == location) {
			return i;
		}
	}
	return -1;
}

static int find_free_affect_slot(const obj_data* obj) {
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == APPLY_NONE ||
		   obj->affected[i].location == APPLY_SKIP) {
			return i;
		}
	}
	return -1;
}

static bool place_buggy(obj_data* obj, int location, int modifier) {
	if(modifier == 0) {
		const int existing = find_affect_slot_for_location(obj, location);
		if(existing >= 0) {
			obj->affected[existing].location = APPLY_NONE;
			obj->affected[existing].modifier = 0;
		}
		return true;
	}
	int slot = find_affect_slot_for_location(obj, location);
	if(slot < 0) {
		slot = find_free_affect_slot(obj);
		if(slot < 0) {
			return false;
		}
		obj->affected[slot].location = static_cast<short>(location);
	}
	obj->affected[slot].modifier = static_cast<short>(modifier);
	return true;
}

static bool place_fixed(obj_data* obj, int location, int modifier) {
	if(modifier == 0) {
		const int existing = find_affect_slot_for_location(obj, location);
		if(existing >= 0) {
			obj->affected[existing].location = APPLY_NONE;
			obj->affected[existing].modifier = 0;
		}
		return true;
	}
	int slot = find_affect_slot_for_location(obj, location);
	if(slot < 0) {
		slot = find_free_affect_slot(obj);
		if(slot < 0) {
			return false;
		}
		obj->affected[slot].location = static_cast<short>(location);
	}
	obj->affected[slot].modifier = modifier;
	return true;
}

using place_fn = bool (*)(obj_data*, int, int);

static void scrub_zero(obj_data* obj) {
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		if(loc == APPLY_NONE || loc == APPLY_SKIP) {
			continue;
		}
		if(obj->affected[i].modifier != 0) {
			continue;
		}
		obj->affected[i].location = APPLY_NONE;
		obj->affected[i].modifier = 0;
	}
}

static void compact(obj_data* obj, place_fn place) {
	struct SavedAffect {
		int location;
		int modifier;
	};
	SavedAffect saved[MAX_OBJ_AFFECT];
	int saved_count = 0;
	int hitroll = 0;
	int damroll = 0;
	int spellpower = 0;

	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		obj->affected[i].location = APPLY_NONE;
		obj->affected[i].modifier = 0;
		switch(loc) {
		case APPLY_HITROLL:
			hitroll += mod;
			break;
		case APPLY_DAMROLL:
			damroll += mod;
			break;
		case APPLY_HITNDAM:
			hitroll += mod;
			damroll += mod;
			break;
		case APPLY_SPELLPOWER:
			spellpower += mod;
			break;
		case APPLY_HITNSP:
			hitroll += mod;
			spellpower += mod;
			break;
		case APPLY_NONE:
		case APPLY_SKIP:
			break;
		default:
			if(mod != 0 && saved_count < MAX_OBJ_AFFECT) {
				saved[saved_count].location = loc;
				saved[saved_count].modifier = mod;
				++saved_count;
			}
			break;
		}
	}
	if(hitroll > 0 && hitroll == damroll && damroll > 0) {
		place(obj, APPLY_HITNDAM, hitroll);
		hitroll = 0;
		damroll = 0;
	}
	if(hitroll > 0 && hitroll == spellpower && damroll == 0) {
		place(obj, APPLY_HITNSP, hitroll);
		hitroll = 0;
		spellpower = 0;
	}
	if(hitroll > 0) {
		place(obj, APPLY_HITROLL, hitroll);
	}
	if(damroll > 0) {
		place(obj, APPLY_DAMROLL, damroll);
	}
	if(spellpower > 0) {
		place(obj, APPLY_SPELLPOWER, spellpower);
	}
	for(int i = 0; i < saved_count; ++i) {
		place(obj, saved[i].location, saved[i].modifier);
	}
	scrub_zero(obj);
}

static void rewrite_buggy(obj_data* obj, int hitroll, int damroll, int spellpower) {
	struct SavedAffect {
		int location;
		int modifier;
	};
	SavedAffect saved[MAX_OBJ_AFFECT];
	int saved_count = 0;
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		obj->affected[i].location = APPLY_NONE;
		obj->affected[i].modifier = 0;
		switch(loc) {
		case APPLY_HITROLL:
		case APPLY_DAMROLL:
		case APPLY_HITNDAM:
		case APPLY_SPELLPOWER:
		case APPLY_HITNSP:
		case APPLY_NONE:
		case APPLY_SKIP:
			break;
		default:
			if(mod != 0 && saved_count < MAX_OBJ_AFFECT) {
				saved[saved_count].location = loc;
				saved[saved_count].modifier = mod;
				++saved_count;
			}
			break;
		}
	}
	if(hitroll > 0) {
		place_buggy(obj, APPLY_HITROLL, hitroll);
	}
	if(damroll > 0) {
		place_buggy(obj, APPLY_DAMROLL, damroll);
	}
	if(spellpower > 0) {
		place_buggy(obj, APPLY_SPELLPOWER, spellpower);
	}
	for(int i = 0; i < saved_count; ++i) {
		place_buggy(obj, saved[i].location, saved[i].modifier);
	}
	compact(obj, place_buggy);
}

static void rewrite_fixed(obj_data* obj, int hitroll, int damroll, int spellpower) {
	struct SavedAffect {
		int location;
		int modifier;
	};
	SavedAffect saved[MAX_OBJ_AFFECT];
	int saved_count = 0;
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		obj->affected[i].location = APPLY_NONE;
		obj->affected[i].modifier = 0;
		switch(loc) {
		case APPLY_HITROLL:
		case APPLY_DAMROLL:
		case APPLY_HITNDAM:
		case APPLY_SPELLPOWER:
		case APPLY_HITNSP:
		case APPLY_NONE:
		case APPLY_SKIP:
			break;
		default:
			if(mod != 0 && saved_count < MAX_OBJ_AFFECT) {
				saved[saved_count].location = loc;
				saved[saved_count].modifier = mod;
				++saved_count;
			}
			break;
		}
	}
	int hr = hitroll;
	int dr = damroll;
	int sp = spellpower;
	if(hr > 0 && hr == dr && dr > 0) {
		place_fixed(obj, APPLY_HITNDAM, hr);
		hr = 0;
		dr = 0;
	}
	if(hr > 0 && hr == sp && dr == 0) {
		place_fixed(obj, APPLY_HITNSP, hr);
		hr = 0;
		sp = 0;
	}
	if(hr > 0) {
		place_fixed(obj, APPLY_HITROLL, hr);
	}
	if(dr > 0) {
		place_fixed(obj, APPLY_DAMROLL, dr);
	}
	if(sp > 0) {
		place_fixed(obj, APPLY_SPELLPOWER, sp);
	}
	for(int i = 0; i < saved_count; ++i) {
		place_fixed(obj, saved[i].location, saved[i].modifier);
	}
	compact(obj, place_fixed);
}

static void clear_obj(obj_data* obj) {
	std::memset(obj, 0, sizeof(*obj));
}

static void setup_full_bracelet(obj_data* obj, bool spy_before_acid) {
	clear_obj(obj);
	obj->affected[0].location = APPLY_HITNDAM;
	obj->affected[0].modifier = 1;
	obj->affected[1].location = APPLY_HIT;
	obj->affected[1].modifier = 10;
	obj->affected[2].location = APPLY_HIT_REGEN;
	obj->affected[2].modifier = 5;
	if(spy_before_acid) {
		obj->affected[3].location = APPLY_SPELL;
		obj->affected[3].modifier = AFF_SCRYING;
		obj->affected[4].location = APPLY_IMMUNE;
		obj->affected[4].modifier = IMM_ACID;
	}
	else {
		obj->affected[3].location = APPLY_IMMUNE;
		obj->affected[3].modifier = IMM_ACID;
		obj->affected[4].location = APPLY_SPELL;
		obj->affected[4].modifier = AFF_SCRYING;
	}
}

static bool has_loc_mod(const obj_data* obj, int loc, int mod) {
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == loc && obj->affected[i].modifier == mod) {
			return true;
		}
	}
	return false;
}

static void print_obj(const char* tag, const obj_data* obj) {
	std::printf("%s:", tag);
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		std::printf(" [%d]=%d/%d", i, static_cast<int>(obj->affected[i].location),
					obj->affected[i].modifier);
	}
	std::printf("\n");
}

static int g_fail = 0;

static void expect(bool cond, const char* name, const obj_data* obj) {
	if(cond) {
		std::printf("PASS %s\n", name);
	}
	else {
		std::printf("FAIL %s\n", name);
		++g_fail;
	}
	if(obj) {
		print_obj(name, obj);
	}
}

int main() {
	{
		const int truncated = static_cast<short>(AFF_SCRYING);
		expect(truncated == 0, "sh_int_truncates_AFF_SCRYING", nullptr);
	}

	obj_data obj;
	clear_obj(&obj);

	setup_full_bracelet(&obj, true);
	rewrite_buggy(&obj, 2, 2, 0);
	expect(!has_loc_mod(&obj, APPLY_IMMUNE, IMM_ACID) &&
			   !has_loc_mod(&obj, APPLY_SPELL, AFF_SCRYING),
		   "buggy_spy_first_wipes_both", &obj);

	setup_full_bracelet(&obj, false);
	rewrite_buggy(&obj, 2, 2, 0);
	expect(!has_loc_mod(&obj, APPLY_SPELL, AFF_SCRYING),
		   "buggy_acid_first_wipes_spy", &obj);

	setup_full_bracelet(&obj, true);
	rewrite_fixed(&obj, 2, 2, 0);
	expect(has_loc_mod(&obj, APPLY_HITNDAM, 2) && has_loc_mod(&obj, APPLY_HIT, 10) &&
			   has_loc_mod(&obj, APPLY_HIT_REGEN, 5) &&
			   has_loc_mod(&obj, APPLY_IMMUNE, IMM_ACID) &&
			   has_loc_mod(&obj, APPLY_SPELL, AFF_SCRYING),
		   "fixed_spy_first_preserves_all", &obj);

	setup_full_bracelet(&obj, false);
	rewrite_fixed(&obj, 2, 2, 0);
	expect(has_loc_mod(&obj, APPLY_HITNDAM, 2) &&
			   has_loc_mod(&obj, APPLY_IMMUNE, IMM_ACID) &&
			   has_loc_mod(&obj, APPLY_SPELL, AFF_SCRYING),
		   "fixed_acid_first_preserves_all", &obj);

	if(g_fail) {
		std::printf("%d FAILED\n", g_fail);
		return 1;
	}
	std::printf("ALL PASSED\n");
	return 0;
}
