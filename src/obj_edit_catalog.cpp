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
#include "db.hpp"
#include "edit_pool.hpp"
#include "edit_system_config.hpp"
#include "flags.hpp"
#include "handler.hpp"
#include "object_instance.hpp"
#include "obj_value.hpp"
#include "clan_symbol.hpp"
#include "spell_parser.hpp"
#include "structs.hpp"
#include "typedefs.hpp"
#include "utility.hpp"
#include "utils.hpp"

namespace Alarmud {

/**
 * Copia di lavoro per quote/apply portal: a differenza di clone_obj() (solo
 * proto + name/short/long), conserva affect, flags, valori e char_vnum dello
 * stato attuale. Senza questo il delta listino e' spesso 0 (after=proto+nuovo
 * vs before=pezzo gia' editato).
 */
[[nodiscard]] static struct obj_data* portal_clone_obj_state(struct obj_data* obj) {
	if(!obj || obj->item_number < 0) {
		return nullptr;
	}
	struct obj_data* ocopy = read_object(obj->item_number, REAL);
	if(!ocopy) {
		return nullptr;
	}

	auto replace_str = [](char*& dst, const char* src) {
		if(dst) {
			free(dst);
			dst = nullptr;
		}
		if(src) {
			dst = strdup(src);
		}
	};
	replace_str(ocopy->name, obj->name);
	replace_str(ocopy->short_description, obj->short_description);
	replace_str(ocopy->description, obj->description);
	replace_str(ocopy->action_description, obj->action_description);
	replace_str(ocopy->szForbiddenWearToChar, obj->szForbiddenWearToChar);
	replace_str(ocopy->szForbiddenWearToRoom, obj->szForbiddenWearToRoom);

	ocopy->obj_flags = obj->obj_flags;
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		ocopy->affected[i] = obj->affected[i];
	}
	ocopy->char_vnum = obj->char_vnum;
	ocopy->sector = obj->sector;
	/* Non collegare a instance/inventario: e' un scratch per AnalyzeObjEdit. */
	ocopy->db_instance_id = 0;
	ocopy->db_inventory_id = 0;
	return ocopy;
}

[[nodiscard]] static struct obj_data* load_edit_prototype(const struct obj_data* obj);

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
	/* Costo per uno step UI (es. armor step −10 → 10 MXP, non 1 MXP/punto). */
	const int abs_step = std::abs(spec.step) > 0 ? std::abs(spec.step) : 1;
	const long raw =
		spec.positive_unit_raw * static_cast<long>(abs_step) * kObjValueStorageScale;
	j["xp_raw_per_step"] = raw;
	j["mxp_per_step"] = raw / 1000000L;
	j["mxp_frac_per_step"] = (raw % 1000000L) / 10000L;
	j["rune_per_step"] = raw / kObjEditRunePerMegaXp;
	j["unit_raw"] = spec.positive_unit_raw;
	j["step_abs"] = abs_step;
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

/**
 * Cap listino = bonus *oltre* il prototipo (stats +3, armor −40, hit/dam +2, …).
 * Tutti gli scalar del listino oggetto usano questo modello.
 */
[[nodiscard]] static bool listino_uses_proto_relative_range(int location) noexcept {
	ObjEditListinoSpec spec;
	return obj_edit_listino_spec(location, spec);
}

[[nodiscard]] static int prototype_display_current(const struct obj_data* obj,
												   int location) noexcept {
	struct obj_data* proto = load_edit_prototype(obj);
	if(!proto) {
		return 0;
	}
	const int v = object_edit_display_current(proto, location);
	extract_obj(proto);
	return v;
}

[[nodiscard]] static bool listino_target_allowed(const struct obj_data* obj,
												 const ObjEditListinoSpec& spec,
												 int target_modifier,
												 std::string& err) {
	if(!listino_uses_proto_relative_range(spec.location)) {
		if(target_modifier < spec.min_total || target_modifier > spec.max_total) {
			err = std::string("valore fuori listino per ") + spec.label + " (consentito "
				  + std::to_string(spec.min_total) + "…" + std::to_string(spec.max_total)
				  + ", richiesto " + std::to_string(target_modifier) + ")";
			return false;
		}
		return true;
	}

	const int proto_val = prototype_display_current(obj, spec.location);
	const int delta = target_modifier - proto_val;
	const int abs_step = std::abs(spec.step) > 0 ? std::abs(spec.step) : 1;

	if(spec.min_total < 0) {
		/* Armor/spellfail: extra da min_total…0 (es. −40…0) oltre il proto. */
		if(delta > 0 || delta < spec.min_total) {
			err = std::string("extra fuori listino per ") + spec.label + " (consentito "
				  + std::to_string(spec.min_total) + "…0 oltre proto "
				  + std::to_string(proto_val) + "; richiesto extra "
				  + std::to_string(delta) + ", totale " + std::to_string(target_modifier)
				  + ")";
			return false;
		}
	}
	else if(delta < spec.min_total || delta > spec.max_total) {
		err = std::string("extra fuori listino per ") + spec.label + " (consentito +"
			  + std::to_string(spec.min_total) + "…+" + std::to_string(spec.max_total)
			  + " oltre proto " + std::to_string(proto_val) + "; richiesto extra +"
			  + std::to_string(delta) + ", totale " + std::to_string(target_modifier)
			  + ")";
		return false;
	}

	if((std::abs(delta) % abs_step) != 0) {
		err = std::string("step non allineato per ") + spec.label + " (step "
			  + std::to_string(spec.step) + ")";
		return false;
	}
	return true;
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

/** Etichetta umana per modifier (bitvector spell/immune, nomi spell, ecc.). */
[[nodiscard]] static std::string format_portal_affect_modifier(int loc, int mod) {
	char buf[MAX_STRING_LENGTH];
	buf[0] = '\0';
	switch(loc) {
	case APPLY_M_IMMUNE:
	case APPLY_IMMUNE:
	case APPLY_SUSC:
		sprintbit(static_cast<unsigned long>(mod), immunity_names, buf);
		return buf;
	case APPLY_SPELL:
		sprintbit(static_cast<unsigned long>(mod), affected_bits, buf);
		return buf;
	case APPLY_AFF2:
		sprintbit(static_cast<unsigned long>(mod), affected_bits2, buf);
		return buf;
	case APPLY_WEAPON_SPELL:
	case APPLY_EAT_SPELL:
		if(mod >= 1 && spells[mod - 1] && *spells[mod - 1] && *spells[mod - 1] != '\n') {
			return spells[mod - 1];
		}
		return std::to_string(mod);
	case APPLY_RACE_SLAYER:
		if(mod >= 0 && RaceName[mod] && *RaceName[mod] && *RaceName[mod] != '\n') {
			return RaceName[mod];
		}
		return std::to_string(mod);
	case APPLY_ALIGN_SLAYER:
		sprintbit(static_cast<unsigned long>(mod), gaszAlignSlayerBits, buf);
		return buf;
	case APPLY_ATTACKS: {
		char num[64];
		snprintf(num, sizeof(num), "%.1f", static_cast<double>(mod) / 10.0);
		return num;
	}
	default:
		return std::to_string(mod);
	}
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
			const std::string label = format_portal_affect_modifier(loc, mod);
			s["modifier_label"] = label;
			/* Retrocompat UI: immune_labels resta per RESI/IMM. */
			if(loc == APPLY_IMMUNE || loc == APPLY_M_IMMUNE || loc == APPLY_SUSC) {
				s["immune_labels"] = label;
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

	if(location == APPLY_IMMUNE || location == APPLY_M_IMMUNE
	   || location == APPLY_SPELL || location == APPLY_AFF2) {
		if(target_modifier == 0) {
			err = (location == APPLY_SPELL || location == APPLY_AFF2)
					  ? "spell bit mancante"
					  : "immune bit mancante";
			return false;
		}
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
	if(!listino_target_allowed(obj, spec, target_modifier, err)) {
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

bool object_portal_allows_worn_edit(const struct obj_data* obj) noexcept {
	/* Apply/quote/options lavorano su character_inventory MySQL a PG offline:
	 * wear_pos e' solo un flag sulla riga, non eq live. Primo edit e ri-edit
	 * sono entrambi sicuri anche se indossato. */
	return obj != nullptr;
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

[[nodiscard]] static bool object_portal_hard_block(const struct obj_data* obj) noexcept {
	if(!obj) {
		return true;
	}
	if(obj->obj_flags.type_flag == ITEM_CLAN_SYMBOL) {
		return true;
	}
	/* HAS-GEMS (extra_bits2) = ITEM2_INSERT. */
	if(IS_OBJ_STAT2(obj, ITEM2_INSERT)) {
		return true;
	}
	return false;
}

/**
 * Esclusioni per il *primo* edit su prototipo: TAN, RARO, simbolo, HAS-GEMS.
 * I pezzi gia' personalizzati (EDIT/instance/owner) bypassano TAN/RARO in
 * show/editable: altrimenti eq editato "costoso" o da tan sparisce dalla lista.
 */
[[nodiscard]] static bool object_portal_passes_exclusions(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	if(object_portal_hard_block(obj)) {
		return false;
	}
	/* TAN_* prototipi / pezzi da skill tan. */
	if(object_is_tanned(obj)) {
		return false;
	}
	/* [RARO] in stat/ident: cost >= LIM_ITEM_COST_MIN (non c'e' un flag dedicato). */
	if(obj->obj_flags.cost >= LIM_ITEM_COST_MIN) {
		return false;
	}
	return true;
}

[[nodiscard]] static bool object_portal_is_existing_edit(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	/* Flag impostato dal portale/oedit. */
	if(IS_OBJ_STAT2(obj, ITEM2_EDIT)) {
		return true;
	}
	/* Istanza MySQL: edit salvato anche se extra_flags2 non ha ITEM2_EDIT
	 * (legacy / migrate / persist senza flag). */
	if(obj->db_instance_id != 0) {
		return true;
	}
	/* Personalizzato EDIT personal_owner: ri-edit / indossato. */
	if(object_has_owner_lock(obj)) {
		return true;
	}
	return false;
}

[[nodiscard]] static bool object_portal_included(const struct obj_data* obj) noexcept {
	if(!obj) {
		return false;
	}
	const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
	if(slug && edit_system_portal_type_always_hidden(slug)) {
		return false;
	}
	/*
	 * Pezzi gia' personalizzati: sempre in lista per ri-edit, anche se la
	 * categoria ITEM_* e' spenta. Altrimenti PG come Martin/Cataklisma
	 * "non vedono i loro edit".
	 */
	if(object_portal_is_existing_edit(obj)) {
		return true;
	}
	/* Spunta staff = visibile per il primo edit su prototipo. */
	if(slug) {
		return edit_system_portal_category_enabled(slug);
	}
	return false;
}

std::string object_portal_skip_reason(const struct obj_data* obj,
									  const char* toon_name) {
	if(!obj || !toon_name || !*toon_name) {
		return "oggetto o PG non valido";
	}
	if(object_portal_hard_block(obj)) {
		if(obj->obj_flags.type_flag == ITEM_CLAN_SYMBOL) {
			return "simbolo clan";
		}
		if(IS_OBJ_STAT2(obj, ITEM2_INSERT)) {
			return "HAS-GEMS (insert)";
		}
		return "bloccato";
	}
	const bool existing = object_portal_is_existing_edit(obj);
	if(!existing) {
		if(object_is_tanned(obj)) {
			return "conciato (skill tan)";
		}
		if(obj->obj_flags.cost >= LIM_ITEM_COST_MIN) {
			return "RARO";
		}
	}
	if(!owner_matches(obj, toon_name)) {
		return "owner diverso dal PG (ED/personal per altro PG)";
	}
	if(!object_portal_included(obj)) {
		const char* slug = object_portal_item_type_slug(ITEM_TYPE(obj));
		if(slug) {
			return "categoria disabilitata (staff)";
		}
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
	/*
	 * Visibilita' inventario:
	 * - pezzi gia' personalizzati (EDIT / instance / owner): sempre in lista
	 *   (tranne HAS-GEMS / simbolo clan); TAN/RARO non li nascondono
	 * - prototipi: esclusioni dure + categorie staff
	 */
	if(object_portal_is_existing_edit(obj)) {
		return !object_portal_hard_block(obj);
	}
	if(!object_portal_passes_exclusions(obj)) {
		return false;
	}
	return object_portal_included(obj);
}

bool object_portal_editable(const struct obj_data* obj, const char* toon_name) noexcept {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	if(object_portal_hard_block(obj)) {
		return false;
	}
	if(!owner_matches(obj, toon_name)) {
		return false;
	}
	if(object_portal_is_existing_edit(obj)) {
		return true;
	}
	if(!object_portal_passes_exclusions(obj)) {
		return false;
	}
	return object_portal_included(obj);
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
		const int proto_total = prototype_display_current(obj, spec.location);
		const bool relative = listino_uses_proto_relative_range(spec.location);
		const bool has_affect = occupied_slot >= 0 || current_total != 0;
		const bool can_edit = scalar_can_edit(obj, spec.location, free_slots);
		Json j;
		j["id"] = spec.id;
		j["label"] = spec.label;
		j["location"] = spec.location;
		j["step"] = spec.step;
		j["min"] = spec.min_total;
		j["max"] = spec.max_total;
		j["proto"] = proto_total;
		j["relative"] = relative;
		j["kind"] = "scalar";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = occupied_slot;
		j["can_add"] = can_edit && !has_affect;
		j["can_edit"] = can_edit;
		json_listino_pricing(j, spec);
		entries.push_back(j);
	}

	/*
	 * Listino https://www.nebbiearcane.it/listino-edits/
	 * Resistenze (APPLY_IMMUNE) ≠ Immunità concesse (APPLY_M_IMMUNE).
	 * Solo voci del listino: niente sleep/charm/nonmag come "resistenza".
	 */
	static const struct {
		unsigned bit;
		const char* slug;
		const char* label;
		long mxp;
		long rune;
	} listino_resists[] = {
		/* Resistenze Spells */
		{IMM_ACID, "acid", "Res. Acid", 75, 90},
		{IMM_ELEC, "elec", "Res. Electricity", 150, 180},
		{IMM_FIRE, "fire", "Res. Fire", 100, 120},
		{IMM_COLD, "cold", "Res. Cold", 75, 90},
		{IMM_ENERGY, "energy", "Res. Energy", 150, 180},
		{IMM_DRAIN, "drain", "Res. Drain", 30, 35},
		{IMM_HOLD, "hold", "Res. Hold", 75, 90},
		{IMM_POISON, "poison", "Res. Poison", 30, 35},
		/* Resistenze ai Fisici */
		{IMM_SLASH, "slash", "Res. Slash", 150, 200},
		{IMM_PIERCE, "pierce", "Res. Pierce", 150, 200},
		{IMM_BLUNT, "blunt", "Res. Blunt", 300, 400},
	};
	for(const auto& r : listino_resists) {
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
		j["id"] = std::string("resist.") + r.slug;
		j["label"] = r.label;
		j["location"] = APPLY_IMMUNE;
		j["immune_bit"] = r.bit;
		j["kind"] = "immune";
		j["listino_group"] = "resistance";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = imm_slot;
		j["can_add"] = can_add;
		j["can_edit"] = has_affect || can_add;
		j["mxp_per_step"] = r.mxp;
		j["rune_per_step"] = r.rune;
		entries.push_back(j);
	}

	/* Immunità Concesse — APPLY_M_IMMUNE (listino), non confondere con Res. */
	static const struct {
		unsigned bit;
		const char* slug;
		const char* label;
		long mxp;
		long rune;
	} listino_immunities[] = {
		{IMM_DRAIN, "drain", "Imm. Drain", 100, 100},
		{IMM_CHARM, "charm", "Imm. Charm", 60, 60},
		{IMM_POISON, "poison", "Imm. Poison", 100, 100},
	};
	for(const auto& r : listino_immunities) {
		const int bits = object_m_immune_current_bits(obj);
		const bool has_affect = (bits & static_cast<int>(r.bit)) != 0;
		const int slot = find_affect_slot_for_location(obj, APPLY_M_IMMUNE);
		const bool can_add = !has_affect && (slot >= 0 || free_slots > 0);
		Json j;
		j["id"] = std::string("immunity.") + r.slug;
		j["label"] = r.label;
		j["location"] = APPLY_M_IMMUNE;
		j["immune_bit"] = r.bit;
		j["kind"] = "m_immune";
		j["listino_group"] = "immunity";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = slot;
		j["can_add"] = can_add;
		j["can_edit"] = has_affect || can_add;
		j["mxp_per_step"] = r.mxp;
		j["rune_per_step"] = r.rune;
		entries.push_back(j);
	}

	/* Spell editabili — listino https://www.nebbiearcane.it/listino-edits/
	 * Spy = AFF_SCRYING (APPLY_SPELL); Danger Sense = AFF2_DANGER_SENSE (APPLY_AFF2). */
	static const struct {
		int location;
		unsigned long bit;
		const char* slug;
		const char* label;
		long mxp;
		long rune;
	} spell_edits[] = {
		{APPLY_SPELL, AFF_TELEPATHY, "telepathy", "Telepathy", 50, 70},
		{APPLY_SPELL, AFF_GLOBE_DARKNESS, "darkness", "Darkness", 50, 70},
		{APPLY_SPELL, AFF_WATERBREATH, "waterbreath", "Waterbreath", 50, 70},
		{APPLY_SPELL, AFF_TRUE_SIGHT, "true_sight", "True Sight", 50, 70},
		{APPLY_SPELL, AFF_INVISIBLE, "invisibility", "Invisibility", 30, 70},
		{APPLY_SPELL, AFF_SENSE_LIFE, "sense_life", "Sense Life", 50, 70},
		{APPLY_AFF2, AFF2_DANGER_SENSE, "danger_sense", "Psionic Danger Sense", 150, 180},
		{APPLY_SPELL, AFF_SCRYING, "spy", "Spy", 150, 180},
		{APPLY_SPELL, AFF_PROTECT_FROM_EVIL, "prot_evil", "Protection from Evil", 50, 70},
		{APPLY_SPELL, AFF_FLYING, "fly", "Fly", 50, 70},
	};
	for(const auto& sp : spell_edits) {
		const int bits = sum_location_mod(obj, sp.location);
		const int sp_slot = find_affect_slot_for_location(obj, sp.location);
		const bool has_affect = (bits & static_cast<int>(sp.bit)) != 0;
		const bool can_add = !has_affect && (sp_slot >= 0 || free_slots > 0);
		Json j;
		j["id"] = std::string("spell.") + sp.slug;
		j["label"] = sp.label;
		j["location"] = sp.location;
		j["spell_bit"] = sp.bit;
		j["kind"] = "spell";
		j["has_affect"] = has_affect;
		j["occupied_slot"] = sp_slot;
		j["can_add"] = can_add;
		j["can_edit"] = has_affect || can_add;
		j["can_remove"] = false;
		j["mxp_per_step"] = sp.mxp;
		j["rune_per_step"] = sp.rune;
		entries.push_back(j);
	}

	/* Flag ARTIFACT (extra_bits / ITEM_IMMUNE): +50% sul costo finale listino
	 * (gia' presente OPPURE aggiunto nello stesso pacchetto). Non rimovibile. */
	{
		const bool is_artifact = IS_OBJ_STAT(obj, ITEM_IMMUNE);
		Json j;
		j["id"] = "artifact";
		j["label"] = "Artifact";
		j["kind"] = "flag";
		j["flag"] = "artifact";
		j["location"] = 0;
		j["current"] = is_artifact ? 1 : 0;
		j["has_affect"] = is_artifact;
		j["occupied_slot"] = -1;
		j["can_add"] = !is_artifact;
		j["can_edit"] = !is_artifact;
		j["can_remove"] = false;
		j["hint"] = is_artifact
						? "Permanente: +50% sul costo finale di ogni edit (listino)"
						: "Flag gratis; +50% sul costo finale di questo edit; poi permanente";
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
	case APPLY_HITNDAM: {
		const int combined = sum_location_mod(obj, APPLY_HITNDAM);
		if(combined != 0) {
			return combined;
		}
		/* Se hit e dam sono separati ma uguali, tratta come hitndam effettivo. */
		const int hr = combat_hitroll_total(obj);
		const int dr = combat_damroll_total(obj);
		if(hr > 0 && hr == dr) {
			return hr;
		}
		return 0;
	}
	case APPLY_HITNSP: {
		const int combined = sum_location_mod(obj, APPLY_HITNSP);
		if(combined != 0) {
			return combined;
		}
		const int hr = combat_hitroll_total(obj);
		const int sp = combat_spellpower_total(obj);
		if(hr > 0 && hr == sp) {
			return hr;
		}
		return 0;
	}
	default:
		return sum_location_mod(obj, location);
	}
}

int object_immune_current_bits(const struct obj_data* obj) noexcept {
	return sum_location_mod(obj, APPLY_IMMUNE);
}

int object_m_immune_current_bits(const struct obj_data* obj) noexcept {
	return sum_location_mod(obj, APPLY_M_IMMUNE);
}

int object_spell_current_bits(const struct obj_data* obj) noexcept {
	return sum_location_mod(obj, APPLY_SPELL);
}

int object_aff2_current_bits(const struct obj_data* obj) noexcept {
	return sum_location_mod(obj, APPLY_AFF2);
}

bool object_edit_location_affects_dam(int location) noexcept {
	return location == APPLY_DAMROLL || location == APPLY_HITNDAM;
}

bool object_edit_location_affects_spellpower(int location) noexcept {
	return location == APPLY_SPELLPOWER || location == APPLY_HITNSP;
}

int object_edit_damroll_total(const struct obj_data* obj) noexcept {
	return combat_damroll_total(obj);
}

int object_edit_spellpower_total(const struct obj_data* obj) noexcept {
	return combat_spellpower_total(obj);
}

int object_edit_hitroll_total(const struct obj_data* obj) noexcept {
	return combat_hitroll_total(obj);
}

[[nodiscard]] static int resolve_edit_prototype_vnum(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	int iVNum = (obj->item_number >= 0) ? obj_index[obj->item_number].iVNum : 0;
	const bool useOriginal =
		(IS_OBJ_STAT2(obj, ITEM2_PERSONAL) || IS_OBJ_STAT2(obj, ITEM2_EDIT)) &&
		obj->char_vnum > 0 && static_cast<int>(obj->char_vnum) != iVNum;
	if(useOriginal) {
		return static_cast<int>(obj->char_vnum);
	}
	/* object_instance: prefer base world vnum when available. */
	const int base = object_instance_resolve_base_vnum(obj);
	if(base > 0) {
		return base;
	}
	return iVNum;
}

[[nodiscard]] static struct obj_data* load_edit_prototype(const struct obj_data* obj) {
	const int iVNum = resolve_edit_prototype_vnum(obj);
	if(iVNum <= 0) {
		return nullptr;
	}
	const int rNum = real_object(iVNum);
	if(rNum < 0) {
		return nullptr;
	}
	return read_object(rNum, REAL);
}

int object_edit_damroll_edited_delta(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	const int cur = combat_damroll_total(obj);
	struct obj_data* proto = load_edit_prototype(obj);
	if(!proto) {
		return 0;
	}
	const int base = combat_damroll_total(proto);
	extract_obj(proto);
	return std::max(0, cur - base);
}

int object_edit_spellpower_edited_delta(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	const int cur = combat_spellpower_total(obj);
	struct obj_data* proto = load_edit_prototype(obj);
	if(!proto) {
		return 0;
	}
	const int base = combat_spellpower_total(proto);
	extract_obj(proto);
	return std::max(0, cur - base);
}

int object_edit_hitroll_edited_delta(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	const int cur = combat_hitroll_total(obj);
	struct obj_data* proto = load_edit_prototype(obj);
	if(!proto) {
		return 0;
	}
	const int base = combat_hitroll_total(proto);
	extract_obj(proto);
	return std::max(0, cur - base);
}

int object_edit_damroll_prototype_total(const struct obj_data* obj) noexcept {
	if(!obj) {
		return 0;
	}
	struct obj_data* proto = load_edit_prototype(obj);
	if(!proto) {
		return 0;
	}
	const int base = combat_damroll_total(proto);
	extract_obj(proto);
	return base;
}

int object_edit_prototype_vnum(const struct obj_data* obj) noexcept {
	return resolve_edit_prototype_vnum(obj);
}

bool object_edit_counts_toward_combat_budget(const struct obj_data* obj,
											 const char* toon_name) noexcept {
	if(!obj || !toon_name || !*toon_name) {
		return false;
	}
	if(!IS_OBJ_STAT2(obj, ITEM2_EDIT)) {
		return false;
	}
	/* Simbolo di clan: dam/sp non entrano nei tetti edit di nessun toon. */
	if(clan_symbol_is_obj(obj) || obj->obj_flags.type_flag == ITEM_CLAN_SYMBOL) {
		return false;
	}
	/* Deve essere dell'owner (personal_owner o keyword ED<nome>). */
	if(obj->personal_owner[0] != '\0') {
		return strcasecmp(obj->personal_owner, toon_name) == 0;
	}
	const std::string ed = object_instance_extract_ed_owner(obj->name);
	return !ed.empty() && strcasecmp(ed.c_str(), toon_name) == 0;
}

[[nodiscard]] static bool enforce_char_dam_budget(const struct obj_data* after_obj,
												  int other_worn_edited_dam,
												  std::string& err) {
	if(other_worn_edited_dam < 0 || !after_obj) {
		return true;
	}
	const int piece_dam = object_edit_damroll_edited_delta(after_obj);
	const int total = other_worn_edited_dam + piece_dam;
	if(total > kObjEditMaxDamrollEditableTotal) {
		err = "tetto dam editabile personaggio superato (" + std::to_string(total) + "/"
			  + std::to_string(kObjEditMaxDamrollEditableTotal)
			  + "; altri pezzi EDIT +" + std::to_string(other_worn_edited_dam)
			  + ", questo pezzo +" + std::to_string(piece_dam) + " vs proto)";
		return false;
	}
	return true;
}

[[nodiscard]] static bool enforce_char_sp_budget(const struct obj_data* after_obj,
												 int other_worn_edited_sp,
												 std::string& err) {
	if(other_worn_edited_sp < 0 || !after_obj) {
		return true;
	}
	const int piece_sp = object_edit_spellpower_edited_delta(after_obj);
	const int total = other_worn_edited_sp + piece_sp;
	if(total > kObjEditMaxSpellpowerEditableTotal) {
		err = "tetto spellpower editabile personaggio superato (" +
			  std::to_string(total) + "/" +
			  std::to_string(kObjEditMaxSpellpowerEditableTotal)
			  + "; altri pezzi EDIT +" + std::to_string(other_worn_edited_sp)
			  + ", questo pezzo +" + std::to_string(piece_sp) + " vs proto)";
		return false;
	}
	return true;
}

bool object_quote_affect_target(struct obj_data* obj, int location, int target_modifier,
								long& xp_raw, int& pq, std::string& err,
								int other_worn_edited_dam, int other_worn_edited_sp) {
	if(!obj) {
		err = "oggetto null";
		return false;
	}
	struct obj_data* clone = portal_clone_obj_state(obj);
	if(!clone) {
		err = "impossibile clonare oggetto";
		return false;
	}
	const ObjEditAnalysis before = AnalyzeObjEdit(obj);
	if(!apply_target_modifier(clone, location, target_modifier, err)) {
		extract_obj(clone);
		return false;
	}
	if(object_edit_location_affects_dam(location)
	   && !enforce_char_dam_budget(clone, other_worn_edited_dam, err)) {
		extract_obj(clone);
		return false;
	}
	if(object_edit_location_affects_spellpower(location)
	   && !enforce_char_sp_budget(clone, other_worn_edited_sp, err)) {
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
								std::string& err, int other_worn_edited_dam,
								int other_worn_edited_sp) {
	if(!obj) {
		err = "oggetto null";
		return false;
	}
	const bool need_budget = (object_edit_location_affects_dam(location)
							  && other_worn_edited_dam >= 0)
							 || (object_edit_location_affects_spellpower(location)
								 && other_worn_edited_sp >= 0);
	if(need_budget) {
		struct obj_data* clone = portal_clone_obj_state(obj);
		if(!clone) {
			err = "impossibile clonare oggetto";
			return false;
		}
		if(!apply_target_modifier(clone, location, target_modifier, err)) {
			extract_obj(clone);
			return false;
		}
		if(!enforce_char_dam_budget(clone, other_worn_edited_dam, err)
		   || !enforce_char_sp_budget(clone, other_worn_edited_sp, err)) {
			extract_obj(clone);
			return false;
		}
		extract_obj(clone);
	}
	return apply_target_modifier(obj, location, target_modifier, err);
}

} // namespace Alarmud
