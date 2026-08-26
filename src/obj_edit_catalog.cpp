/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "obj_edit_catalog.hpp"

#include <algorithm>
#include <cstring>
#include <string>

#include "autoenums.hpp"
#include "constants.hpp"
#include "edit_pool.hpp"
#include "edit_system_config.hpp"
#include "flags.hpp"
#include "handler.hpp"
#include "object_instance.hpp"
#include "obj_value.hpp"
#include "structs.hpp"
#include "typedefs.hpp"
#include "utils.hpp"

namespace Alarmud {

struct index_data {
	int iVNum;
	long pos;
	int number;
	genericspecial_func func;
	const char* specname;
	char* specparms;
	void* data;
	char* name;
	char* short_desc;
	char* long_desc;
};

extern int top_of_objt;
extern struct index_data* obj_index;

struct obj_data* clone_obj(struct obj_data* obj);

[[nodiscard]] static bool proto_vnum_is_tan(int vnum) noexcept {
	return vnum == TAN_BAG || vnum == TAN_SHIELD || vnum == TAN_JACKET
		   || vnum == TAN_BOOTS || vnum == TAN_GLOVES || vnum == TAN_LEGGINGS
		   || vnum == TAN_SLEEVES || vnum == TAN_HELMET || vnum == TAN_ARMOR;
}

bool object_vnum_is_tan_proto(int vnum) noexcept {
	return proto_vnum_is_tan(vnum);
}

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

[[nodiscard]] int count_free_affect_slots(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	int free_slots = 0;
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		if(obj->affected[i].location == APPLY_NONE ||
		   obj->affected[i].location == APPLY_SKIP) {
			++free_slots;
		}
	}
	return free_slots;
}

static void json_listino_pricing(Json& j, const ObjEditListinoSpec& spec) {
	const long raw = spec.positive_unit_raw * kObjValueStorageScale;
	j["xp_raw_per_step"] = raw;
	j["mxp_per_step"] = raw / 1000000L;
	j["mxp_frac_per_step"] = (raw % 1000000L) / 10000L;
	j["rune_per_step"] = raw / kObjEditRunePerMegaXp;
}

[[nodiscard]] static int combat_hitroll_total(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	return sum_location_mod(obj, APPLY_HITROLL) + sum_location_mod(obj, APPLY_HITNDAM) +
		   sum_location_mod(obj, APPLY_HITNSP);
}

[[nodiscard]] static int combat_damroll_total(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	return sum_location_mod(obj, APPLY_DAMROLL) + sum_location_mod(obj, APPLY_HITNDAM);
}

[[nodiscard]] static int combat_spellpower_total(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	return sum_location_mod(obj, APPLY_SPELLPOWER) + sum_location_mod(obj, APPLY_HITNSP);
}

static bool place_affect_modifier(struct obj_data* obj, int location,
												int modifier) {
	if(modifier == 0) {
		return true;
	}
	int slot = find_affect_slot_for_location(obj, location);
	if(slot < 0) {
		slot = find_free_affect_slot(obj);
		if(slot < 0) {
			return false;
		}
		obj->affected[slot].location = static_cast<sh_int>(location);
	}
	obj->affected[slot].modifier = static_cast<sh_int>(modifier);
	return true;
}

void object_compact_edit_affects(struct obj_data* obj) noexcept {
	if(!obj) {
		return;
	}

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
			if(saved_count < MAX_OBJ_AFFECT) {
				saved[saved_count].location = loc;
				saved[saved_count].modifier = mod;
				++saved_count;
			}
			break;
		}
	}

	if(hitroll > 0 && hitroll == damroll && damroll > 0) {
		place_affect_modifier(obj, APPLY_HITNDAM, hitroll);
		hitroll = 0;
		damroll = 0;
	}
	if(hitroll > 0 && hitroll == spellpower && damroll == 0) {
		place_affect_modifier(obj, APPLY_HITNSP, hitroll);
		hitroll = 0;
		spellpower = 0;
	}

	if(hitroll > 0) {
		place_affect_modifier(obj, APPLY_HITROLL, hitroll);
	}
	if(damroll > 0) {
		place_affect_modifier(obj, APPLY_DAMROLL, damroll);
	}
	if(spellpower > 0) {
		place_affect_modifier(obj, APPLY_SPELLPOWER, spellpower);
	}

	for(int i = 0; i < saved_count; ++i) {
		place_affect_modifier(obj, saved[i].location, saved[i].modifier);
	}
}

[[nodiscard]] static bool scalar_can_edit(const struct obj_data* obj, int location,
										  int free_slots) noexcept {
	if(!obj) {
		return false;
	}
	if(find_affect_slot_for_location(obj, location) >= 0) {
		return true;
	}
	if(sum_location_mod(obj, location) != 0) {
		return true;
	}
	if(free_slots > 0) {
		return true;
	}
	const int hr = combat_hitroll_total(obj);
	const int dr = combat_damroll_total(obj);
	const int sp = combat_spellpower_total(obj);
	if(location == APPLY_DAMROLL && hr > 0 && dr == 0) {
		return true;
	}
	if(location == APPLY_HITROLL && dr > 0 && hr == 0) {
		return true;
	}
	if(location == APPLY_SPELLPOWER && hr > 0 && sp == 0) {
		return true;
	}
	if(location == APPLY_HITNDAM && hr > 0 && dr > 0) {
		return true;
	}
	if(location == APPLY_HITNSP && hr > 0 && sp > 0) {
		return true;
	}
	return false;
}

[[nodiscard]] static bool object_has_owner_lock(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	if(obj->personal_owner[0] != '\0') {
		return true;
	}
	return !object_instance_extract_ed_owner(obj->name).empty();
}

[[nodiscard]] bool owner_matches(const struct obj_data* obj, const char* toon_name) {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	/* Proto / non ancora editato: nessun ED nel name né personal_owner. */
	if(!object_has_owner_lock(obj)) {
		return true;
	}
	if(obj->personal_owner[0] != '\0' &&
	   strcasecmp(obj->personal_owner, toon_name) == 0) {
		return true;
	}
	const std::string ed = object_instance_extract_ed_owner(obj->name);
	return !ed.empty() && strcasecmp(ed.c_str(), toon_name) == 0;
}

[[nodiscard]] static bool is_combat_edit_location(int location) noexcept {
	switch(location) {
	case APPLY_HITROLL:
	case APPLY_DAMROLL:
	case APPLY_SPELLPOWER:
	case APPLY_HITNDAM:
	case APPLY_HITNSP:
		return true;
	default:
		return false;
	}
}

static void rewrite_combat_totals(struct obj_data* obj, int hitroll,
												int damroll, int spellpower) {
	if(!obj) {
		return;
	}

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
			if(saved_count < MAX_OBJ_AFFECT) {
				saved[saved_count].location = loc;
				saved[saved_count].modifier = mod;
				++saved_count;
			}
			break;
		}
	}

	if(hitroll > 0) {
		place_affect_modifier(obj, APPLY_HITROLL, hitroll);
	}
	if(damroll > 0) {
		place_affect_modifier(obj, APPLY_DAMROLL, damroll);
	}
	if(spellpower > 0) {
		place_affect_modifier(obj, APPLY_SPELLPOWER, spellpower);
	}

	for(int i = 0; i < saved_count; ++i) {
		place_affect_modifier(obj, saved[i].location, saved[i].modifier);
	}

	object_compact_edit_affects(obj);
}

Json object_affect_slots_json(const struct obj_data* obj) {
	Json root;
	Json slots = Json::array();
	int used = 0;
	if(!obj) {
		root["slots"] = slots;
		root["max_slots"] = MAX_OBJ_AFFECT;
		root["used"] = 0;
		root["free_count"] = MAX_OBJ_AFFECT;
		return root;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		const int loc = obj->affected[i].location;
		const int mod = obj->affected[i].modifier;
		const bool free =
			loc == APPLY_NONE || loc == APPLY_SKIP || (loc == 0 && mod == 0);
		Json s;
		s["slot"] = i;
		s["free"] = free;
		if(!free) {
			++used;
			s["location"] = loc;
			if(loc > APPLY_NONE) {
				char buf[MAX_STRING_LENGTH];
				sprinttype(loc, apply_types, buf);
				s["location_name"] = buf;
			}
			s["modifier"] = mod;
			if(loc == APPLY_IMMUNE || loc == APPLY_M_IMMUNE) {
				char buf[MAX_STRING_LENGTH];
				sprintbit(static_cast<unsigned long>(mod), immunity_names, buf);
				s["immune_labels"] = buf;
			}
		}
		slots.push_back(s);
	}
	root["slots"] = slots;
	root["max_slots"] = MAX_OBJ_AFFECT;
	root["used"] = used;
	root["free_count"] = MAX_OBJ_AFFECT - used;
	return root;
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

	ObjEditListinoSpec spec;
	if(!obj_edit_listino_spec(location, spec)) {
		err = "campo non presente nel listino oggetto";
		return false;
	}
	if(target_modifier < spec.min_total || target_modifier > spec.max_total) {
		err = "valore fuori listino (massimo per pezzo)";
		return false;
	}

	if(is_combat_edit_location(location)) {
		int hitroll = combat_hitroll_total(obj);
		int damroll = combat_damroll_total(obj);
		int spellpower = combat_spellpower_total(obj);
		switch(location) {
		case APPLY_HITROLL:
			hitroll = target_modifier;
			break;
		case APPLY_DAMROLL:
			damroll = target_modifier;
			break;
		case APPLY_SPELLPOWER:
			spellpower = target_modifier;
			break;
		case APPLY_HITNDAM:
			hitroll = target_modifier;
			damroll = target_modifier;
			break;
		case APPLY_HITNSP:
			hitroll = target_modifier;
			spellpower = target_modifier;
			break;
		default:
			break;
		}
		rewrite_combat_totals(obj, hitroll, damroll, spellpower);
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

bool inventory_row_is_worn(int wearpos) noexcept {
	return wearpos > 0;
}

bool object_is_tanned(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	if(obj->item_number >= 0 && obj->item_number <= top_of_objt
	   && proto_vnum_is_tan(obj_index[obj->item_number].iVNum)) {
		return true;
	}
	if(obj->char_vnum > 0 && proto_vnum_is_tan(obj->char_vnum)) {
		return true;
	}
	return false;
}

const char* object_portal_item_type_slug(int item_type) noexcept {
	switch(item_type) {
	case ITEM_LIGHT:
		return "light";
	case ITEM_SCROLL:
		return "scroll";
	case ITEM_WAND:
		return "wand";
	case ITEM_STAFF:
		return "staff";
	case ITEM_WEAPON:
		return "weapon";
	case ITEM_FIREWEAPON:
		return "fireweapon";
	case ITEM_MISSILE:
		return "missile";
	case ITEM_TREASURE:
		return "treasure";
	case ITEM_ARMOR:
		return "armor";
	case ITEM_POTION:
		return "potion";
	case ITEM_WORN:
		return "worn";
	case ITEM_OTHER:
		return "other";
	case ITEM_TRASH:
		return "trash";
	case ITEM_TRAP:
		return "trap";
	case ITEM_CONTAINER:
		return "container";
	case ITEM_NOTE:
		return "note";
	case ITEM_DRINKCON:
		return "drinkcon";
	case ITEM_KEY:
		return "key";
	case ITEM_FOOD:
		return "food";
	case ITEM_MONEY:
		return "money";
	case ITEM_PEN:
		return "pen";
	case ITEM_BOAT:
		return "boat";
	case ITEM_AUDIO:
		return "audio";
	case ITEM_BOARD:
		return "board";
	case ITEM_TREE:
		return "tree";
	case ITEM_ROCK:
		return "rock";
	case ITEM_M_GEM:
		return "m_gem";
	case ITEM_M_MINERAL:
		return "m_mineral";
	case ITEM_BAR:
		return "bar";
	case ITEM_JEWEL:
		return "jewel";
	case ITEM_CLAN_SYMBOL:
		return "clan_symbol";
	default:
		return nullptr;
	}
}

[[nodiscard]] static bool object_portal_passes_exclusions(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	if(object_is_tanned(obj)) {
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
	return true;
}

std::string object_portal_skip_reason(const struct obj_data* obj,
									  const char* toon_name) {
	if(!obj || !toon_name || !*toon_name) {
		return "oggetto o PG non valido";
	}
	if(object_is_tanned(obj)) {
		return "conciato (skill tan)";
	}
	if(obj->obj_flags.cost >= LIM_ITEM_COST_MIN) {
		return "RARO";
	}
	if(obj->obj_flags.type_flag == ITEM_CLAN_SYMBOL) {
		return "simbolo clan";
	}
	if(IS_OBJ_STAT2(obj, ITEM2_INSERT)) {
		return "oggetto con insert";
	}
	if(!owner_matches(obj, toon_name)) {
		return "owner diverso dal PG (ED/personal per altro PG)";
	}
	if(IS_OBJ_STAT2(obj, ITEM2_EDIT) && !edit_system_portal_category_enabled("edited")) {
		return "categoria EDIT disabilitata (staff)";
	}
	const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
	if(slug && !edit_system_portal_category_enabled(slug)) {
		return "categoria disabilitata (staff)";
	}
	if(!slug && !IS_OBJ_STAT2(obj, ITEM2_EDIT)) {
		return "tipo non supportato nel portale";
	}
	return {};
}

bool object_portal_show_in_inventory_list(const struct obj_data* obj,
										  const char* toon_name) noexcept {
	(void)toon_name;
	if(!obj) {
		return false;
	}
	const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
	if(slug && edit_system_portal_type_always_hidden(slug)) {
		return false;
	}
	return true;
}

bool object_portal_editable(const struct obj_data* obj, const char* toon_name) noexcept {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	if(!object_portal_passes_exclusions(obj)) {
		return false;
	}
	if(!owner_matches(obj, toon_name)) {
		return false;
	}
	const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
	if(slug && edit_system_portal_category_enabled(slug)) {
		return true;
	}
	if(IS_OBJ_STAT2(obj, ITEM2_EDIT) && edit_system_portal_category_enabled("edited")) {
		return true;
	}
	return false;
}

Json object_edit_catalog_json(const struct obj_data* obj) {
	const int free_slots = count_free_affect_slots(obj);

	Json entries = Json::array();
	for(int i = 0; i < obj_edit_listino_scalar_count(); ++i) {
		ObjEditListinoSpec spec;
		if(!obj_edit_listino_scalar_at(i, spec)) {
			continue;
		}
		if(edit_pool_location_blocked_on_eq(spec.location)) {
			continue;
		}
		const int occupied_slot = find_affect_slot_for_location(obj, spec.location);
		const int current_total = object_edit_display_current(obj, spec.location);
		const bool has_affect = occupied_slot >= 0 || current_total != 0;
		const bool can_edit = scalar_can_edit(obj, spec.location, free_slots);
		Json j;
		j["id"] = spec.id;
		j["label"] = spec.label;
		j["location"] = spec.location;
		j["step"] = spec.step;
		j["min"] = spec.min_total;
		j["max"] = spec.max_total;
		j["kind"] = "scalar";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = occupied_slot;
		j["can_add"] = can_edit && !has_affect;
		j["can_edit"] = can_edit;
		json_listino_pricing(j, spec);
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
		const int immune_bits = object_immune_current_bits(obj);
		const bool has_affect = (immune_bits & static_cast<int>(r.bit)) != 0;
		const int imm_slot = find_affect_slot_for_location(obj, APPLY_IMMUNE);
		const bool can_add = !has_affect && (imm_slot >= 0 || free_slots > 0);
		Json j;
		j["id"] = std::string("immune.") + r.slug;
		j["label"] = r.label;
		j["location"] = APPLY_IMMUNE;
		j["immune_bit"] = r.bit;
		j["kind"] = "immune";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = imm_slot;
		j["can_add"] = can_add;
		j["can_edit"] = has_affect || can_add;
		entries.push_back(j);
	}

	return entries;
}

int object_affect_current_modifier(const struct obj_data* obj, int location) noexcept {
	return sum_location_mod(obj, location);
}

int object_edit_display_current(const struct obj_data* obj, int location) noexcept {
	if(!obj) {
		return 0;
	}
	switch(location) {
	case APPLY_HITROLL:
		return combat_hitroll_total(obj);
	case APPLY_DAMROLL:
		return combat_damroll_total(obj);
	case APPLY_SPELLPOWER:
		return combat_spellpower_total(obj);
	default:
		return sum_location_mod(obj, location);
	}
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
