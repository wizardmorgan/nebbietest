/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "edit_system_config.hpp"

#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>
#include <cstring>

#include "../contrib/slacking/json.hpp"
#include "autoenums.hpp"
#include "edit_pool.hpp"
#include "logging.hpp"

namespace Alarmud {
namespace {

using Json = nlohmann::json;

struct Entry {
	std::string id;
	std::string kind;
	std::string pool_field;
	unsigned damage_type = 0;
	EditSystemTarget target = EditSystemTarget::Object;
	bool enabled = true;
	std::string label;
};

	std::mutex g_mutex;
	std::vector<Entry> g_entries;
	std::string g_config_path;
	bool g_loaded = false;

	struct PortalCategories {
		bool armor = true;
		bool weapon = true;
		bool food = true;
		bool potion = true;
		bool edited = true;
	} g_portal_categories;

[[nodiscard]] EditSystemTarget parse_target(const std::string& s) {
	if(s == "character") {
		return EditSystemTarget::Character;
	}
	return EditSystemTarget::Object;
}

[[nodiscard]] const char* target_str(EditSystemTarget t) {
	return t == EditSystemTarget::Character ? "character" : "object";
}

void build_defaults() {
	g_entries.clear();
	const char* pool_fields[] = {"hit", "mana", "move", "hit_regen", "mana_regen", "move_regen"};
	const char* pool_labels[] = {"Hit points", "Mana", "Move", "Hit regen", "Mana regen", "Move regen"};
	for(int i = 0; i < 6; ++i) {
		Entry e;
		e.id = std::string("pool.") + pool_fields[i];
		e.kind = "pool";
		e.pool_field = pool_fields[i];
		e.target = EditSystemTarget::Character;
		e.enabled = true;
		e.label = pool_labels[i];
		g_entries.push_back(e);
	}

	static const struct {
		unsigned bit;
		const char* slug;
		const char* label;
	} resist[] = {
		{IMM_FIRE, "fire", "Fire"},
		{IMM_COLD, "cold", "Cold"},
		{IMM_ELEC, "elec", "Electricity"},
		{IMM_ENERGY, "energy", "Energy"},
		{IMM_BLUNT, "blunt", "Blunt"},
		{IMM_PIERCE, "pierce", "Pierce"},
		{IMM_SLASH, "slash", "Slash"},
		{IMM_ACID, "acid", "Acid"},
		{IMM_POISON, "poison", "Poison"},
		{IMM_DRAIN, "drain", "Drain"},
		{IMM_SLEEP, "sleep", "Sleep"},
		{IMM_CHARM, "charm", "Charm"},
		{IMM_HOLD, "hold", "Hold"},
		{IMM_NONMAG, "nonmag", "Non-magic"},
		{IMM_PLUS1, "plus1", "Weapon +1"},
		{IMM_PLUS2, "plus2", "Weapon +2"},
		{IMM_PLUS3, "plus3", "Weapon +3"},
		{IMM_PLUS4, "plus4", "Weapon +4"},
	};
	for(const auto& r : resist) {
		Entry e;
		e.id = std::string("resistance.") + r.slug;
		e.kind = "resistance";
		e.damage_type = r.bit;
		e.target = EditSystemTarget::Object;
		e.enabled = true;
		e.label = r.label;
		g_entries.push_back(e);
	}
}

[[nodiscard]] std::string resolve_config_path() {
	const char* env = std::getenv("EDIT_SYSTEM_CONFIG");
	if(env && *env) {
		return std::string(env);
	}
	std::ostringstream p;
	p << "lib/edit_system.json";
	return p.str();
}

[[nodiscard]] bool read_file_text(const std::string& path, std::string& out) {
	std::ifstream in(path);
	if(!in) {
		return false;
	}
	std::ostringstream ss;
	ss << in.rdbuf();
	out = ss.str();
	return true;
}

[[nodiscard]] bool write_file_text(const std::string& path, const std::string& text) {
	std::ofstream out(path, std::ios::trunc);
	if(!out) {
		return false;
	}
	out << text;
	return out.good();
}

void parse_portal_categories(const Json& root) {
	g_portal_categories = PortalCategories {};
	if(root.find("object_portal") == root.end() || !root["object_portal"].is_object()) {
		return;
	}
	const Json& p = root["object_portal"];
	g_portal_categories.armor = p.value("armor", true);
	g_portal_categories.weapon = p.value("weapon", true);
	g_portal_categories.food = p.value("food", true);
	g_portal_categories.potion = p.value("potion", true);
	g_portal_categories.edited = p.value("edited", true);
}

void parse_entries_json(const Json& root) {
	g_entries.clear();
	parse_portal_categories(root);
	if(root.find("entries") == root.end() || !root["entries"].is_array()) {
		build_defaults();
		return;
	}
	for(const auto& item : root["entries"]) {
		if(!item.is_object()) {
			continue;
		}
		Entry e;
		e.id = item.value("id", "");
		e.kind = item.value("kind", "");
		e.pool_field = item.value("pool_field", "");
		e.damage_type = static_cast<unsigned>(item.value("damage_type", 0));
		e.target = parse_target(item.value("target", "object"));
		e.enabled = item.value("enabled", true);
		e.label = item.value("label", "");
		if(e.id.empty() || e.kind.empty()) {
			continue;
		}
		g_entries.push_back(e);
	}
	if(g_entries.empty()) {
		build_defaults();
	}
}

[[nodiscard]] Json entries_to_json() {
	Json root;
	root["version"] = 1;
	Json arr = Json::array();
	for(const auto& e : g_entries) {
		Json item;
		item["id"] = e.id;
		item["kind"] = e.kind;
		if(!e.pool_field.empty()) {
			item["pool_field"] = e.pool_field;
		}
		if(e.damage_type != 0) {
			item["damage_type"] = e.damage_type;
		}
		item["target"] = target_str(e.target);
		item["enabled"] = e.enabled;
		if(!e.label.empty()) {
			item["label"] = e.label;
		}
		arr.push_back(item);
	}
	root["entries"] = arr;
	Json portal;
	portal["armor"] = g_portal_categories.armor;
	portal["weapon"] = g_portal_categories.weapon;
	portal["food"] = g_portal_categories.food;
	portal["potion"] = g_portal_categories.potion;
	portal["edited"] = g_portal_categories.edited;
	portal["comment"] =
		"Categorie oggetto editabili nel portale web (staff). edited = con flag ITEM2_EDIT.";
	root["object_portal"] = portal;
	return root;
}

struct PoolLookup {
	bool found = false;
	bool enabled = true;
	EditSystemTarget target = EditSystemTarget::Character;
};

struct ResistanceLookup {
	bool found = false;
	bool enabled = true;
	EditSystemTarget target = EditSystemTarget::Object;
};

[[nodiscard]] PoolLookup lookup_pool(const char* pool_field) {
	PoolLookup out;
	if(!pool_field || !*pool_field) {
		return out;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	for(const auto& e : g_entries) {
		if(e.kind == "pool" && e.pool_field == pool_field) {
			out.found = true;
			out.enabled = e.enabled;
			out.target = e.target;
			return out;
		}
	}
	return out;
}

[[nodiscard]] ResistanceLookup lookup_resistance(unsigned damage_type) {
	ResistanceLookup out;
	if(damage_type == 0) {
		return out;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	for(const auto& e : g_entries) {
		if(e.kind == "resistance" && e.damage_type == damage_type) {
			out.found = true;
			out.enabled = e.enabled;
			out.target = e.target;
			return out;
		}
	}
	return out;
}

[[nodiscard]] bool resistance_bits_blocked_on_object(unsigned bits) {
	if(bits == 0) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	for(const auto& e : g_entries) {
		if(e.kind != "resistance" || !e.enabled) {
			continue;
		}
		if((bits & e.damage_type) && e.target == EditSystemTarget::Character) {
			return true;
		}
	}
	return false;
}

void load_from_disk() {
	std::lock_guard<std::mutex> lock(g_mutex);
	g_config_path = resolve_config_path();
	std::string text;
	if(read_file_text(g_config_path, text)) {
		try {
			const Json root = Json::parse(text);
			parse_entries_json(root);
			g_loaded = true;
			mudlog(LOG_CHECK, "edit_system_config: loaded %zu entries from %s",
				   g_entries.size(), g_config_path.c_str());
			return;
		}
		catch(const std::exception& e) {
			mudlog(LOG_SYSERR, "edit_system_config: parse error %s — using defaults",
				   e.what());
		}
	}
	build_defaults();
	g_loaded = true;
	mudlog(LOG_CHECK, "edit_system_config: using built-in defaults (%zu entries)",
		   g_entries.size());
}

} // namespace

void edit_system_config_init() {
	load_from_disk();
}

bool edit_system_config_reload() {
	load_from_disk();
	return g_loaded;
}

std::string edit_system_config_to_json() {
	std::lock_guard<std::mutex> lock(g_mutex);
	return entries_to_json().dump(2);
}

bool edit_system_config_save_json(const std::string& json_text, std::string& err) {
	try {
		const Json parsed = Json::parse(json_text);
		if(parsed.find("entries") == parsed.end() || !parsed["entries"].is_array()) {
			err = "JSON deve contenere array entries";
			return false;
		}
		const std::string path = resolve_config_path();
		const std::string pretty = parsed.dump(2);
		if(!write_file_text(path, pretty)) {
			err = "impossibile scrivere " + path;
			return false;
		}
		parse_entries_json(parsed);
		g_config_path = path;
		g_loaded = true;
		mudlog(LOG_CHECK, "edit_system_config: saved %zu entries to %s",
			   g_entries.size(), path.c_str());
		return true;
	}
	catch(const std::exception& e) {
		err = e.what();
		return false;
	}
}

bool edit_system_blocked_on_object(int location, int modifier) noexcept {
	if(edit_pool_is_pool_apply(location)) {
		const char* field = nullptr;
		switch(location) {
		case APPLY_HIT:
			field = "hit";
			break;
		case APPLY_MANA:
			field = "mana";
			break;
		case APPLY_MOVE:
			field = "move";
			break;
		case APPLY_HIT_REGEN:
			field = "hit_regen";
			break;
		case APPLY_MANA_REGEN:
			field = "mana_regen";
			break;
		case APPLY_MOVE_REGEN:
			field = "move_regen";
			break;
		default:
			break;
		}
		if(field) {
			return edit_system_pool_target(field) == EditSystemTarget::Character;
		}
		return true;
	}

	if(location == APPLY_IMMUNE || location == APPLY_M_IMMUNE || location == APPLY_SUSC) {
		return resistance_bits_blocked_on_object(static_cast<unsigned>(modifier));
	}
	return false;
}

EditSystemTarget edit_system_pool_target(const char* pool_field) noexcept {
	const PoolLookup lk = lookup_pool(pool_field);
	if(!lk.found || !lk.enabled) {
		return EditSystemTarget::Character;
	}
	return lk.target;
}

bool edit_system_pool_enabled(const char* pool_field) noexcept {
	const PoolLookup lk = lookup_pool(pool_field);
	return lk.found && lk.enabled;
}

EditSystemTarget edit_system_resistance_target(unsigned damage_type) noexcept {
	const ResistanceLookup lk = lookup_resistance(damage_type);
	if(!lk.found || !lk.enabled) {
		return EditSystemTarget::Object;
	}
	return lk.target;
}

bool edit_system_resistance_enabled(unsigned damage_type) noexcept {
	const ResistanceLookup lk = lookup_resistance(damage_type);
	return lk.found && lk.enabled;
}

bool edit_system_portal_category_enabled(const char* category) noexcept {
	if(!category || !*category) {
		return false;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	if(strcmp(category, "armor") == 0) {
		return g_portal_categories.armor;
	}
	if(strcmp(category, "weapon") == 0) {
		return g_portal_categories.weapon;
	}
	if(strcmp(category, "food") == 0) {
		return g_portal_categories.food;
	}
	if(strcmp(category, "potion") == 0) {
		return g_portal_categories.potion;
	}
	if(strcmp(category, "edited") == 0) {
		return g_portal_categories.edited;
	}
	return false;
}

const char* edit_system_config_path() {
	if(g_config_path.empty()) {
		return resolve_config_path().c_str();
	}
	return g_config_path.c_str();
}

} // namespace Alarmud
