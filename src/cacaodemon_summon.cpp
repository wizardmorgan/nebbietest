/*ALARMUD*
 * Assemblaggio procedurale summon cacaodemon + equip non lootabile.
 *ALARMUD*/
#include "cacaodemon_summon.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <sstream>
#include <ctime>

#include "config.hpp"
#include "typedefs.hpp"
#include "flags.hpp"
#include "autoenums.hpp"
#include "structs.hpp"
#include "logging.hpp"
#include "constants.hpp"
#include "utils.hpp"
#include "utility.hpp"
#include "cacaodemon_sacrifice.inc"
#include "db.hpp"
#include "handler.hpp"
#include "maximums.hpp"
#include "multiclass.hpp"
#include "spell_power.hpp"
#include "spells.hpp"

#include "cacaodemon_summon_lexicon.inc"

namespace Alarmud {

namespace {

[[nodiscard]] const char* pick_lexeme(const CacaoLexemePool& pool, unsigned& seed) {
	if(pool.count <= 0 || pool.items == nullptr) {
		return "";
	}
	seed = seed * 1103515245u + 12345u;
	const int idx = static_cast<int>((seed >> 16) % static_cast<unsigned>(pool.count));
	return pool.items[idx];
}

[[nodiscard]] std::string join_title(const char* prefix, const char* core, const char* suffix) {
	std::ostringstream os;
	os << prefix << ' ' << core << ' ' << suffix;
	return os.str();
}

[[nodiscard]] std::string make_keywords(const char* prefix, const char* core, const char* suffix) {
	std::ostringstream os;
	os << prefix << ' ' << core << ' ' << suffix << " evocato cacaodemon";
	return os.str();
}

[[nodiscard]] char* cacao_dup_nl(const std::string& text) {
	std::string with_nl = text;
	if(with_nl.empty() || with_nl.back() != '\n') {
		with_nl.push_back('\n');
	}
	return strdup(with_nl.c_str());
}

void cacao_set_hitdam(struct obj_data* obj, int bonus) {
	if(obj == nullptr || bonus <= 0) {
		return;
	}
	for(int i = 0; i < MAX_OBJ_AFFECT; ++i) {
		obj->affected[i].location = APPLY_NONE;
		obj->affected[i].modifier = 0;
	}
	obj->affected[0].location = APPLY_HITROLL;
	obj->affected[0].modifier = bonus;
	obj->affected[1].location = APPLY_DAMROLL;
	obj->affected[1].modifier = bonus;
}

void cacao_bind_pet_gear(struct obj_data* obj, struct char_data* owner, int wear_pos) {
	if(obj == nullptr) {
		return;
	}
	obj->char_vnum = CACAODEMON_PET_GEAR_MARKER;
	obj->iGeneric = wear_pos;
	obj->pGeneric = owner;
	SET_BIT(obj->obj_flags.extra_flags, ITEM_NODROP | ITEM_HUM | ITEM_IMMUNE);
	SET_BIT(obj->obj_flags.wear_flags, ITEM_TAKE);
}

[[nodiscard]] struct obj_data* cacao_load_gear(int vnum, struct char_data* owner, int wear_pos,
											  int hd_bonus) {
	struct obj_data* obj = read_object(vnum, VIRTUAL);
	if(obj == nullptr) {
		mudlog(LOG_ERROR, "cacaodemon: read_object(%d) fallito per equip summon", vnum);
		return nullptr;
	}
	cacao_bind_pet_gear(obj, owner, wear_pos);
	cacao_set_hitdam(obj, hd_bonus);
	return obj;
}

struct CacaoGearSlot {
	int wear_pos;
	int vnum;
	bool strike_slot; /* mani/braccia: ricevono il +N/+N del sigillo (ex arma) */
	bool is_armor_ac;
};

void cacao_equip_summon(struct char_data* mob, int sacrifice_tier, CacaoSummonTheme theme,
						bool monoclass) {
	(void)theme;
	if(mob == nullptr) {
		return;
	}

	/* N = bonus sigillo (mono max +5/+5, multi max +4/+4). Niente arma: combattimento a mani nude. */
	const int seal_hd = CacaoGearHitDamBonus(sacrifice_tier, monoclass);
	const int filler_hd = 1;
	const int armor_ac = 2 + seal_hd * 2;

	const CacaoGearSlot slots[] = {
		{WEAR_FINGER_R, CACAO_PET_GEAR_FINGER, false, false},
		{WEAR_FINGER_L, CACAO_PET_GEAR_FINGER, false, false},
		{WEAR_NECK_1, CACAO_PET_GEAR_NECK, false, true},
		{WEAR_NECK_2, CACAO_PET_GEAR_NECK, false, true},
		{WEAR_BODY, CACAO_PET_GEAR_BODY, false, true},
		{WEAR_HEAD, CACAO_PET_GEAR_HEAD, false, true},
		{WEAR_LEGS, CACAO_PET_GEAR_LEGS, false, true},
		{WEAR_FEET, CACAO_PET_GEAR_FEET, false, true},
		{WEAR_HANDS, CACAO_PET_GEAR_HANDS, true, true},
		{WEAR_ARMS, CACAO_PET_GEAR_ARMS, true, true},
		{WEAR_SHIELD, CACAO_PET_GEAR_SHIELD, false, true},
		{WEAR_ABOUT, CACAO_PET_GEAR_ABOUT, false, true},
		{WEAR_WAISTE, CACAO_PET_GEAR_WAIST, false, true},
		{WEAR_WRIST_R, CACAO_PET_GEAR_WRIST, false, false},
		{WEAR_WRIST_L, CACAO_PET_GEAR_WRIST, false, false},
		{WEAR_EAR_R, CACAO_PET_GEAR_EAR, false, false},
		{WEAR_EAR_L, CACAO_PET_GEAR_EAR, false, false},
		{WEAR_EYES, CACAO_PET_GEAR_EYES, false, false},
	};

	for(const CacaoGearSlot& slot : slots) {
		const int hd = slot.strike_slot ? seal_hd : filler_hd;
		struct obj_data* obj = cacao_load_gear(slot.vnum, mob, slot.wear_pos, hd);
		if(obj == nullptr) {
			continue;
		}

		if(slot.is_armor_ac) {
			obj->obj_flags.value[0] = armor_ac;
			obj->iGeneric1 = armor_ac;
		} else {
			obj->obj_flags.value[0] = std::max(1, armor_ac / 3);
			obj->iGeneric1 = obj->obj_flags.value[0];
		}

		equip_char(mob, obj, slot.wear_pos);
	}
}

[[nodiscard]] bool cacao_owner_still_valid(struct char_data* owner) {
	if(!CacaoIsPet(owner)) {
		return false;
	}
	for(struct char_data* ch = character_list; ch != nullptr; ch = ch->next) {
		if(ch == owner) {
			return true;
		}
	}
	return false;
}

void cacao_repair_pet_gear(struct obj_data* obj) {
	if(obj == nullptr || !CacaoIsPetGear(obj)) {
		return;
	}
	if(GET_ITEM_TYPE(obj) == ITEM_WEAPON) {
		if(obj->iGeneric1 > 0) {
			obj->obj_flags.value[1] = obj->iGeneric1;
		}
		if(obj->iGeneric2 > 0) {
			obj->obj_flags.value[2] = obj->iGeneric2;
		}
	} else if(GET_ITEM_TYPE(obj) == ITEM_ARMOR && obj->iGeneric1 > 0) {
		obj->obj_flags.value[0] = obj->iGeneric1;
	}
}

void cacao_reequip_one(struct char_data* mob, struct obj_data* obj) {
	if(mob == nullptr || obj == nullptr || !CacaoIsPetGear(obj)) {
		return;
	}
	const int pos = obj->iGeneric;
	if(pos < 0 || pos >= MAX_WEAR) {
		return;
	}
	if(mob->equipment[pos] != nullptr) {
		return;
	}
	if(obj->carried_by == mob) {
		obj_from_char(obj);
	} else if(obj->in_room != NOWHERE) {
		obj_from_room(obj);
	} else if(obj->equipped_by != nullptr) {
		return;
	}
	cacao_repair_pet_gear(obj);
	equip_char(mob, obj, pos);
}

} // namespace

CacaoSummonTheme CacaoThemeFromAlignment(int alignment) {
	if(alignment > 350) {
		return CacaoSummonTheme::Angelic;
	}
	if(alignment < -350) {
		return CacaoSummonTheme::Infernal;
	}
	return CacaoSummonTheme::Construct;
}

CacaoSummonIdentity CacaoGenerateSummonIdentity(int alignment, int tier, unsigned seed) {
	CacaoSummonIdentity id;
	id.theme = CacaoThemeFromAlignment(alignment);
	id.tier = std::clamp(tier, 1, 6);

	const CacaoLexemePool* prefix = nullptr;
	const CacaoLexemePool* core = nullptr;
	const CacaoLexemePool* suffix = nullptr;
	const CacaoLexemePool* look = nullptr;
	const CacaoLexemePool* presence = nullptr;
	const CacaoLexemePool* sound = nullptr;

	switch(id.theme) {
	case CacaoSummonTheme::Angelic:
		prefix = &kCacaoAngelPrefix;
		core = &kCacaoAngelCore;
		suffix = &kCacaoAngelSuffix;
		look = &kCacaoAngelLook;
		presence = &kCacaoAngelPresence;
		sound = &kCacaoAngelSound;
		id.race = RACE_GOD;
		break;
	case CacaoSummonTheme::Infernal:
		prefix = &kCacaoInfernalPrefix;
		core = &kCacaoInfernalCore;
		suffix = &kCacaoInfernalSuffix;
		look = &kCacaoInfernalLook;
		presence = &kCacaoInfernalPresence;
		sound = &kCacaoInfernalSound;
		id.race = RACE_DEMON;
		break;
	case CacaoSummonTheme::Construct:
	default:
		prefix = &kCacaoConstructPrefix;
		core = &kCacaoConstructCore;
		suffix = &kCacaoConstructSuffix;
		look = &kCacaoConstructLook;
		presence = &kCacaoConstructPresence;
		sound = &kCacaoConstructSound;
		id.race = RACE_GOLEM;
		break;
	}

	unsigned s = seed ^ (static_cast<unsigned>(id.tier) * 2654435761u) ^
				 static_cast<unsigned>(static_cast<int>(id.theme) + 1) * 97u;
	const char* p = pick_lexeme(*prefix, s);
	const char* c = pick_lexeme(*core, s);
	const char* su = pick_lexeme(*suffix, s);
	const char* lk1 = pick_lexeme(*look, s);
	const char* lk2 = pick_lexeme(*look, s);
	const char* pr = pick_lexeme(*presence, s);
	const char* so = pick_lexeme(*sound, s);

	id.short_descr = join_title(p, c, su);
	id.keywords = make_keywords(p, c, su);
	id.long_descr = id.short_descr + " e' qui, evocato da un rituale di potere.";
	{
		std::ostringstream look_os;
		look_os << lk1 << '\n' << lk2 << '\n'
				<< "La sua presenza e' legata al tier rituale " << id.tier << '.';
		id.look_descr = look_os.str();
	}
	id.arrive_msg = pr;
	id.sound_msg = so;
	return id;
}

bool CacaoIsPet(const struct char_data* ch) {
	return ch != nullptr && IS_NPC(ch) && ch->generic == CACAODEMON_PET_MARKER;
}

bool CacaoIsPetGear(const struct obj_data* obj) {
	if(obj == nullptr) {
		return false;
	}
	if(obj->char_vnum == CACAODEMON_PET_GEAR_MARKER) {
		return true;
	}
	if(obj->item_number >= 0) {
		const int vnum = obj_index[obj->item_number].iVNum;
		if(vnum >= CACAO_PET_GEAR_VNUM_MIN && vnum <= CACAO_PET_GEAR_VNUM_MAX) {
			return true;
		}
	}
	return false;
}

bool CacaoIsSacrificeItem(const struct obj_data* obj, int min_tier) {
	if(obj == nullptr) {
		return false;
	}
	if(obj->obj_flags.value[0] != CACAODEMON_SACRIFICE_MARKER) {
		return false;
	}
	const int item_tier = obj->obj_flags.value[1];
	return item_tier >= min_tier && item_tier >= 1 && item_tier <= 6;
}

struct char_data* CacaoFindExistingPet(struct char_data* master) {
	if(master == nullptr) {
		return nullptr;
	}
	for(follow_type* fol = master->followers; fol != nullptr; fol = fol->next) {
		struct char_data* pet = fol->follower;
		if(pet != nullptr && CacaoIsPet(pet) && IS_AFFECTED(pet, AFF_CHARM) &&
		   pet->master == master) {
			return pet;
		}
	}
	return nullptr;
}

int CacaoManaExtraForTier(int tier, float factor) {
	tier = std::clamp(tier, 1, kCacaoSacrificeTierCount);
	const CacaoSacrificeTierSpec& spec = kCacaoSacrificeTiers[tier - 1];
	const float f = std::clamp(factor, 0.0f, 1.0f);
	return spec.mana_extra_min +
		   static_cast<int>((spec.mana_extra_max - spec.mana_extra_min) * f + 0.5f);
}

int CacaoGearHitDamBonus(int sacrifice_tier, bool monoclass) {
	sacrifice_tier = std::clamp(sacrifice_tier, 1, 6);
	static const int kMono[6] = {1, 2, 3, 4, 5, 5};
	static const int kMulti[6] = {1, 2, 3, 3, 4, 4};
	return monoclass ? kMono[sacrifice_tier - 1] : kMulti[sacrifice_tier - 1];
}

struct char_data* CacaoCreateSummon(struct char_data* caster, int power_tier, float factor,
												  int sacrifice_tier) {
	if(caster == nullptr) {
		return nullptr;
	}

	power_tier = std::clamp(power_tier, 1, 6);
	sacrifice_tier = std::clamp(sacrifice_tier, 1, 6);
	factor = std::clamp(factor, 0.0f, 1.0f);
	const bool monoclass = HowManyClasses(caster) == 1;

	const float sac_mult = 0.95f + 0.07f * static_cast<float>(sacrifice_tier);
	const float scale = std::clamp(factor * sac_mult, 0.0f, 1.40f);
	const float seal = static_cast<float>(sacrifice_tier) / 6.0f;

	const unsigned seed = static_cast<unsigned>(time(nullptr)) ^
						  static_cast<unsigned>(reinterpret_cast<uintptr_t>(caster)) ^
						  static_cast<unsigned>(power_tier * 9973) ^
						  static_cast<unsigned>(sacrifice_tier * 131);
	const CacaoSummonIdentity id =
		CacaoGenerateSummonIdentity(GET_ALIGNMENT(caster), power_tier, seed);

	struct char_data* mob = nullptr;
	CREATE(mob, struct char_data, 1);
	if(mob == nullptr) {
		return nullptr;
	}

	clear_char(mob);
	mob->specials.last_direction = -1;
	mob->mult_att = 2.0f + 0.25f * static_cast<float>(sacrifice_tier) + 0.35f * scale +
					0.15f * static_cast<float>(power_tier);
	mob->specials.spellfail = 101;
	mob->specials.mobtype = 'L';

	mob->player.name = strdup(id.keywords.c_str());
	mob->player.short_descr = strdup(id.short_descr.c_str());
	mob->player.long_descr = cacao_dup_nl(id.long_descr);
	mob->player.description = cacao_dup_nl(id.look_descr);
	mob->player.sounds = strdup(id.sound_msg.c_str());
	mob->player.distant_snds = cacao_dup_nl(id.arrive_msg);
	mob->player.title = nullptr;

	SET_BIT(mob->specials.act, ACT_ISNPC | ACT_SENTINEL | ACT_WARRIOR);
	REMOVE_BIT(mob->specials.act, ACT_AGGRESSIVE);
	REMOVE_BIT(mob->specials.act, ACT_SCAVENGER);

	mob->player.iClass = CLASS_WARRIOR;
	mob->player.time.birth = time(nullptr);
	mob->player.time.played = 0;
	mob->player.time.logon = time(nullptr);
	mob->player.weight = 220 + power_tier * 25;
	mob->player.height = 185 + power_tier * 6;
	mob->player.sex = SEX_NEUTRAL;
	for(int i = 0; i < 3; ++i) {
		GET_COND(mob, i) = -1;
	}
	for(int i = 0; i < MAX_WEAR; ++i) {
		mob->equipment[i] = nullptr;
	}

	const int level = std::clamp(
		38 + sacrifice_tier * 2 + power_tier + static_cast<int>(scale * 8.0f),
		38, 52);
	for(int i = 0; i < ABS_MAX_CLASS; ++i) {
		GET_LEVEL(mob, i) = 0;
	}
	GET_LEVEL(mob, WARRIOR_LEVEL_IND) = level;

	mob->points.max_hit =
		550 + sacrifice_tier * 70 + power_tier * 40 + static_cast<int>(scale * 900.0f) +
		static_cast<int>(seal * 120.0f);
	mob->points.hit = mob->points.max_hit;

	/* Mani nude: i dadi e una quota di HR/DR assorbono cio' che prima dava l'arma 98215. */
	const int seal_hd = CacaoGearHitDamBonus(sacrifice_tier, monoclass);
	mob->points.damroll = static_cast<sbyte>(std::clamp(
		4 + power_tier + seal_hd + static_cast<int>(scale * 6.0f), 4, 20));
	mob->points.hitroll = static_cast<sbyte>(std::clamp(
		4 + power_tier + seal_hd + static_cast<int>(scale * 6.0f), 4, 20));
	mob->points.armor = std::clamp(
		10 - sacrifice_tier * 6 - power_tier * 2 - static_cast<int>(scale * 30.0f), -60, 40);
	mob->specials.damnodice = std::clamp(3 + seal_hd / 2, 3, 6);
	mob->specials.damsizedice = std::clamp(6 + seal_hd, 6, 12);
	/* attack_type non usato: in fight.cpp i pet a mani nude forzano TYPE_UNDEFINED. */
	mob->specials.attack_type = TYPE_UNDEFINED;
	mob->points.max_mana = 100;
	mob->points.max_move = NewMobMov(mob);
	GET_EXP(mob) = 0;
	GET_GOLD(mob) = 0;
	GET_ALIGNMENT(mob) = GET_ALIGNMENT(caster);

	mob->abilities.str = 18;
	mob->abilities.str_add = static_cast<sbyte>(std::clamp(40 + sacrifice_tier * 10, 40, 100));
	mob->abilities.intel = static_cast<ubyte>(std::min(12 + power_tier / 2 + number(0, 2), 18));
	mob->abilities.wis = static_cast<ubyte>(std::min(12 + power_tier / 2 + number(0, 2), 18));
	mob->abilities.dex = static_cast<ubyte>(std::min(14 + sacrifice_tier / 2 + number(0, 2), 18));
	mob->abilities.con = 18;
	mob->abilities.chr = static_cast<ubyte>(std::min(11 + power_tier / 2 + number(0, 2), 18));
	mob->tmpabilities = mob->abilities;
	for(int i = 0; i < 5; ++i) {
		mob->specials.apply_saving_throw[i] = static_cast<sbyte>(std::max(20 - level, 2));
	}

	SET_BIT(mob->specials.affected_by, AFF_TRUE_SIGHT | AFF_DETECT_INVISIBLE);
	if(sacrifice_tier >= 5) {
		SET_BIT(mob->specials.affected_by, AFF_SANCTUARY);
	}

	mob->nr = -1;
	mob->generic = CACAODEMON_PET_MARKER;
	mob->commandp = 0;
	mob->commandp2 = power_tier;
	GET_RACE(mob) = id.race;
	SetRacialStuff(mob);
	SET_BIT(mob->specials.affected_by, AFF_TRUE_SIGHT | AFF_DETECT_INVISIBLE);
	if(sacrifice_tier >= 5) {
		SET_BIT(mob->specials.affected_by, AFF_SANCTUARY);
	}
	mob->points.mana = mana_limit(mob);
	mob->points.move = move_limit(mob);
	mob->specials.position = POSITION_STANDING;
	mob->specials.default_pos = POSITION_STANDING;
	mob->specials.tick = mob_tick_count++;
	if(mob_tick_count == TICK_WRAP_COUNT) {
		mob_tick_count = 0;
	}

	mob->next = character_list;
	character_list = mob;
	mob_count++;

	cacao_equip_summon(mob, sacrifice_tier, id.theme, monoclass);
	return mob;
}

void CacaoCleanupPetGear(struct char_data* mob) {
	if(mob == nullptr) {
		return;
	}
	for(int i = 0; i < MAX_WEAR; ++i) {
		if(mob->equipment[i] != nullptr && CacaoIsPetGear(mob->equipment[i])) {
			struct obj_data* obj = unequip_char(mob, i);
			if(obj != nullptr) {
				extract_obj(obj);
			}
		}
	}
	struct obj_data* next = nullptr;
	for(struct obj_data* obj = mob->carrying; obj != nullptr; obj = next) {
		next = obj->next_content;
		if(CacaoIsPetGear(obj)) {
			obj_from_char(obj);
			extract_obj(obj);
		}
	}
	/* Anche a terra nella stanza (disarm / drop intercettati in ritardo). */
	if(mob->in_room != NOWHERE && real_roomp(mob->in_room) != nullptr) {
		for(struct obj_data* obj = real_roomp(mob->in_room)->contents; obj != nullptr;
			obj = next) {
			next = obj->next_content;
			if(CacaoIsPetGear(obj) && obj->pGeneric == mob) {
				obj_from_room(obj);
				extract_obj(obj);
			}
		}
	}
}

void CacaoReequipPetGear(struct char_data* mob) {
	if(!CacaoIsPet(mob)) {
		return;
	}
	struct obj_data* next = nullptr;
	for(struct obj_data* obj = mob->carrying; obj != nullptr; obj = next) {
		next = obj->next_content;
		if(CacaoIsPetGear(obj)) {
			cacao_reequip_one(mob, obj);
		}
	}
}

bool CacaoTryKeepPetGear(struct obj_data* obj) {
	if(!CacaoIsPetGear(obj)) {
		return false;
	}

	struct char_data* owner = static_cast<struct char_data*>(obj->pGeneric);
	if(!cacao_owner_still_valid(owner)) {
		if(obj->in_room != NOWHERE) {
			obj_from_room(obj);
		}
		if(obj->carried_by != nullptr) {
			obj_from_char(obj);
		}
		extract_obj(obj);
		return true;
	}

	if(obj->equipped_by != nullptr) {
		const int pos = obj->eq_pos;
		if(pos >= 0 && pos < MAX_WEAR && obj->equipped_by->equipment[pos] == obj) {
			unequip_char(obj->equipped_by, pos);
		}
	}
	cacao_repair_pet_gear(obj);
	if(obj->carried_by != owner) {
		if(obj->in_room != NOWHERE) {
			obj_from_room(obj);
		}
		obj_to_char(obj, owner);
	}
	cacao_reequip_one(owner, obj);
	return true;
}

} // namespace Alarmud
