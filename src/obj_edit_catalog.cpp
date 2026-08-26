/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "obj_edit_catalog.hpp"

#include <algorithm>
#include <cstring>
#include <string>

#include "autoenums.hpp"
#include "edit_pool.hpp"
#include "edit_system_config.hpp"
#include "flags.hpp"
#include "handler.hpp"
#include "object_instance.hpp"
#include "obj_value.hpp"
#include "structs.hpp"
#include "utils.hpp"

namespace Alarmud {

struct CatalogEntry {
	const char* id;
	const char* label;
	int location;
	int step;
	int min_val;
	int max_val;
	bool armor;
	bool weapon;
	bool immune_bit;
	unsigned immune_mask;
};

[[nodiscard]] bool owner_matches(const struct obj_data* obj, const char* toon_name) {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	if(obj->personal_owner[0] != '\0' &&
	   !strcasecmp(obj->personal_owner, toon_name)) {
		return true;
	}
	const std::string ed = object_instance_extract_ed_owner(obj->name);
	return !ed.empty() && strcasecmp(ed.c_str(), toon_name) == 0;
}

const CatalogEntry kScalarCatalog[] = {
	{"str", "Forza (STR)", APPLY_STR, 1, 1, 1, true, true, false, 0},
	{"dex", "Destrezza (DEX)", APPLY_DEX, 1, 1, 2, true, true, false, 0},
	{"con", "Costituzione (CON)", APPLY_CON, 1, 1, 2, true, true, false, 0},
	{"wis", "Saggezza (WIS)", APPLY_WIS, 1, 1, 2, true, true, false, 0},
	{"int", "Intelligenza (INT)", APPLY_INT, 1, 1, 2, true, true, false, 0},
	{"chr", "Carisma (CHR)", APPLY_CHR, 3, 3, 6, true, true, false, 0},
	{"hitroll", "Hitroll", APPLY_HITROLL, 1, 1, 1, true, true, false, 0},
	{"damroll", "Damroll", APPLY_DAMROLL, 1, 1, 1, true, true, false, 0},
	{"spellpower", "Spellpower", APPLY_SPELLPOWER, 1, 1, 1, true, true, false, 0},
	{"armor", "Armatura (AC)", APPLY_AC, -5, -20, 0, true, false, false, 0},
	{"spellfail", "Spellfail", APPLY_SPELLFAIL, -2, -10, 0, true, false, false, 0},
	{"hitndam", "Hit & damage", APPLY_HITNDAM, 1, 1, 2, false, true, false, 0},
	{"hitnsp", "Hit & spellpower", APPLY_HITNSP, 1, 1, 2, false, true, false, 0},
};

[[nodiscard]] int sum_location_mod(const struct obj_data* obj, int location) {
	if(!obj) {
		return 0;
	}
	int tot = 0;
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == location) {
			tot += obj->affected[i].modifier;
		}
	}
	return tot;
}

[[nodiscard]] int find_affect_slot_for_location(const struct obj_data* obj,
												int location) {
	if(!obj) {
		return -1;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == location) {
			return i;
		}
	}
	return -1;
}

[[nodiscard]] int find_free_affect_slot(const struct obj_data* obj) {
	if(!obj) {
		return -1;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == APPLY_NONE ||
		   obj->affected[i].location == APPLY_SKIP) {
			return i;
		}
	}
	return -1;
}

[[nodiscard]] bool apply_target_modifier(struct obj_data* obj, int location,
										 int target_modifier, std::string& err) {
	if(!obj) {
		err = "oggetto null";
		return false;
	}
	if(edit_pool_location_blocked_on_eq(location)) {
		err = "campo pool: edit sul personaggio, non sull'oggetto";
		return false;
	}
	if(edit_system_blocked_on_object(location, target_modifier)) {
		err = "campo configurato sul personaggio";
		return false;
	}

	if(location == APPLY_IMMUNE || location == APPLY_M_IMMUNE) {
		const int slot = find_affect_slot_for_location(obj, location);
		if(slot >= 0) {
			obj->affected[slot].modifier |= target_modifier;
			return true;
		}
		const int free = find_free_affect_slot(obj);
		if(free < 0) {
			err = "nessuno slot affect libero";
			return false;
		}
		obj->affected[free].location = static_cast<sh_int>(location);
		obj->affected[free].modifier = target_modifier;
		return true;
	}

	int slot = find_affect_slot_for_location(obj, location);
	if(slot < 0) {
		slot = find_free_affect_slot(obj);
		if(slot < 0) {
			err = "nessuno slot affect libero";
			return false;
		}
		obj->affected[slot].location = static_cast<sh_int>(location);
	}
	obj->affected[slot].modifier = static_cast<sh_int>(target_modifier);
	return true;
}

bool object_portal_editable(const struct obj_data* obj, const char* toon_name) noexcept {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	if(obj->obj_flags.cost >= LIM_ITEM_COST_MIN) {
		return false;
	}
	if(obj->obj_flags.type_flag == ITEM_CLAN_SYMBOL) {
		return false;
	}
	if(IS_OBJ_STAT2(obj, ITEM2_INSERT)) {
		return false;
	}
	if(!IS_OBJ_STAT2(obj, ITEM2_EDIT)) {
		return false;
	}
	const int type = ITEM_TYPE(obj);
	if(type != ITEM_ARMOR && type != ITEM_WEAPON) {
		return false;
	}
	return owner_matches(obj, toon_name);
}

Json object_edit_catalog_json(bool is_armor, bool is_weapon) {
	Json entries = Json::array();
	for(const auto& e : kScalarCatalog) {
		if(e.armor && !is_armor) {
			continue;
		}
		if(e.weapon && !is_weapon) {
			continue;
		}
		if(edit_pool_location_blocked_on_eq(e.location)) {
			continue;
		}
		Json j;
		j["id"] = e.id;
		j["label"] = e.label;
		j["location"] = e.location;
		j["step"] = e.step;
		j["min"] = e.min_val;
		j["max"] = e.max_val;
		j["kind"] = "scalar";
		entries.push_back(j);
	}

	static const struct {
		unsigned bit;
		const char* slug;
		const char* label;
	} resist[] = {
		{IMM_FIRE, "fire", "Fuoco"},
		{IMM_COLD, "cold", "Freddo"},
		{IMM_ELEC, "elec", "Elettricità"},
		{IMM_ENERGY, "energy", "Energia"},
		{IMM_BLUNT, "blunt", "Contundente"},
		{IMM_PIERCE, "pierce", "Perforante"},
		{IMM_SLASH, "slash", "Taglio"},
		{IMM_ACID, "acid", "Acido"},
		{IMM_POISON, "poison", "Veleno"},
		{IMM_DRAIN, "drain", "Drain"},
		{IMM_SLEEP, "sleep", "Sleep"},
		{IMM_CHARM, "charm", "Charm"},
		{IMM_HOLD, "hold", "Hold"},
		{IMM_NONMAG, "nonmag", "Non-magia"},
		{IMM_PLUS1, "plus1", "Arma +1"},
		{IMM_PLUS2, "plus2", "Arma +2"},
		{IMM_PLUS3, "plus3", "Arma +3"},
		{IMM_PLUS4, "plus4", "Arma +4"},
	};
	for(const auto& r : resist) {
		if(!edit_system_resistance_enabled(r.bit)) {
			continue;
		}
		if(edit_system_resistance_target(r.bit) != EditSystemTarget::Object) {
			continue;
		}
		Json j;
		j["id"] = std::string("immune.") + r.slug;
		j["label"] = r.label;
		j["location"] = APPLY_IMMUNE;
		j["immune_bit"] = r.bit;
		j["kind"] = "immune";
		entries.push_back(j);
	}

	return entries;
}

int object_affect_current_modifier(const struct obj_data* obj, int location) noexcept {
	return sum_location_mod(obj, location);
}

int object_immune_current_bits(const struct obj_data* obj) noexcept {
	return sum_location_mod(obj, APPLY_IMMUNE);
}

bool object_quote_affect_target(struct obj_data* obj, int location, int target_modifier,
								long& xp_raw, int& pq, std::string& err) {
	if(!obj) {
		err = "oggetto null";
		return false;
	}
	struct obj_data* clone = clone_obj(obj);
	if(!clone) {
		err = "impossibile clonare oggetto";
		return false;
	}
	const ObjEditAnalysis before = AnalyzeObjEdit(obj);
	if(!apply_target_modifier(clone, location, target_modifier, err)) {
		extract_obj(clone);
		return false;
	}
	const ObjEditAnalysis after = AnalyzeObjEdit(clone);
	extract_obj(clone);
	xp_raw = std::max(0L, after.diff.valore - before.diff.valore);
	pq = std::max(0, after.diff.rune - before.diff.rune);
	return true;
}

bool object_apply_affect_target(struct obj_data* obj, int location, int target_modifier,
								std::string& err) {
	return apply_target_modifier(obj, location, target_modifier, err);
}

} // namespace Alarmud
