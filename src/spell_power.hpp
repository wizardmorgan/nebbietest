/*ALARMUD*
 * Indice di potenza riusabile per spell/skill (stesso standard delle Dimensioni Effimere).
 *ALARMUD*/
#ifndef __SPELL_POWER_HPP
#define __SPELL_POWER_HPP

#include "typedefs.hpp"
#include "autoenums.hpp"
#include "multiclass.hpp"

namespace Alarmud {

/** Allineato a PROCAREA_POWER_SCALE_* — curva unica mud-wide. */
constexpr float SPELL_POWER_SCALE_MIN = 200.0f;
constexpr float SPELL_POWER_SCALE_MAX = 9500.0f;
constexpr float SPELL_GROUP_POWER_AVG_WEIGHT = 0.70f;
constexpr float SPELL_GROUP_POWER_MAX_WEIGHT = 0.30f;

constexpr int SPELL_POWER_TIER_MIN = 1;
constexpr int SPELL_POWER_TIER_MAX = 6;

/** Classi che possono lanciare spell basati su questo indice (cacaodemon e riuso). */
constexpr unsigned long SPELL_POWER_CASTER_CLASSES =
	CLASS_CLERIC | CLASS_MAGIC_USER | CLASS_SORCERER;

/**
 * Moltiplicatori classe.
 * Solo profili con almeno una tra CL/MU/SO (altrimenti lo spell non e' lanciabile).
 * Multiclass: non-fighter avvantaggiati rispetto a chi ha anche IS_FIGHTER.
 */
constexpr float SPELL_CLASS_MULT_MONO_SO_CL = 1.15f;
constexpr float SPELL_CLASS_MULT_MONO_MU = 1.00f;
constexpr float SPELL_CLASS_MULT_DUAL_NO_FIGHTER = 0.98f;
constexpr float SPELL_CLASS_MULT_DUAL_FIGHTER = 0.85f;
constexpr float SPELL_CLASS_MULT_TRI_NO_FIGHTER = 0.88f;
constexpr float SPELL_CLASS_MULT_TRI_FIGHTER = 0.72f;
/** Nessuna tra CL/MU/SO: non puo' usare questi spell. */
constexpr float SPELL_CLASS_MULT_NO_CASTER = 0.0f;

[[nodiscard]] float SpellPowerIndex(struct char_data* ch);
[[nodiscard]] float SpellGroupPowerIndex(struct char_data* ch);
[[nodiscard]] float SpellPowerFactor(float power_index);
[[nodiscard]] bool SpellHasPowerCasterClass(struct char_data* ch);
[[nodiscard]] float SpellClassPowerMult(struct char_data* ch);
[[nodiscard]] float SpellEffectivePower(struct char_data* ch);
[[nodiscard]] int SpellPowerTierFromFactor(float factor);

} // namespace Alarmud

#endif
