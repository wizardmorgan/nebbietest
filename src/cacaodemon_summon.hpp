/*ALARMUD*
 * Generazione procedurale del summon cacaodemon (temi good/evil/neutral).
 *ALARMUD*/
#ifndef __CACAODEMON_SUMMON_HPP
#define __CACAODEMON_SUMMON_HPP

#include <string>

#include "typedefs.hpp"

namespace Alarmud {

constexpr int CACAODEMON_PET_MARKER = 98002;
constexpr int CACAODEMON_PET_GEAR_MARKER = 98003;

/** Overlay objects/98201-98214 — equip del summon (no arma; 98215 legacy unused). */
constexpr int CACAO_PET_GEAR_VNUM_MIN = 98201;
constexpr int CACAO_PET_GEAR_VNUM_MAX = 98214;
constexpr int CACAO_PET_GEAR_FINGER = 98201;
constexpr int CACAO_PET_GEAR_NECK = 98202;
constexpr int CACAO_PET_GEAR_BODY = 98203;
constexpr int CACAO_PET_GEAR_HEAD = 98204;
constexpr int CACAO_PET_GEAR_LEGS = 98205;
constexpr int CACAO_PET_GEAR_FEET = 98206;
constexpr int CACAO_PET_GEAR_HANDS = 98207;
constexpr int CACAO_PET_GEAR_ARMS = 98208;
constexpr int CACAO_PET_GEAR_SHIELD = 98209;
constexpr int CACAO_PET_GEAR_ABOUT = 98210;
constexpr int CACAO_PET_GEAR_WAIST = 98211;
constexpr int CACAO_PET_GEAR_WRIST = 98212;
constexpr int CACAO_PET_GEAR_EAR = 98213;
constexpr int CACAO_PET_GEAR_EYES = 98214;
constexpr int CACAO_PET_GEAR_WEAPON = 98215; /* legacy, non equippato */

enum class CacaoSummonTheme {
	Angelic = 0,
	Infernal = 1,
	Construct = 2
};

struct CacaoSummonIdentity {
	CacaoSummonTheme theme = CacaoSummonTheme::Construct;
	int tier = 1;
	int race = 0;
	std::string keywords;
	std::string short_descr;
	std::string long_descr;
	std::string look_descr;
	std::string arrive_msg;
	std::string sound_msg;
};

[[nodiscard]] CacaoSummonTheme CacaoThemeFromAlignment(int alignment);
[[nodiscard]] CacaoSummonIdentity CacaoGenerateSummonIdentity(int alignment, int tier,
															  unsigned seed);

[[nodiscard]] bool CacaoIsPet(const struct char_data* ch);
[[nodiscard]] bool CacaoIsPetGear(const struct obj_data* obj);
[[nodiscard]] bool CacaoIsSacrificeItem(const struct obj_data* obj, int min_tier);
[[nodiscard]] struct char_data* CacaoFindExistingPet(struct char_data* master);
[[nodiscard]] int CacaoManaExtraForTier(int tier, float factor);
[[nodiscard]] int CacaoGearHitDamBonus(int sacrifice_tier, bool monoclass);
[[nodiscard]] struct char_data* CacaoCreateSummon(struct char_data* caster, int power_tier,
												  float factor, int sacrifice_tier);
void CacaoCleanupPetGear(struct char_data* mob);
void CacaoReequipPetGear(struct char_data* mob);
/** Se obj e' gear del pet: lo tiene in inventario e lo ri-equipaggia. true = non mettere a terra. */
[[nodiscard]] bool CacaoTryKeepPetGear(struct obj_data* obj);

} // namespace Alarmud

#endif
