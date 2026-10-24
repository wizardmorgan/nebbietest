/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#ifndef __PROC_CACAODEMON_HPP
#define __PROC_CACAODEMON_HPP

#include "typedefs.hpp"
#include <string>

namespace Alarmud {

static constexpr float CACAODEMON_WORLD_EQ_WEIGHT = 0.7f;
static constexpr float CACAODEMON_CASTER_EQ_WEIGHT = 0.3f;
static constexpr int CACAODEMON_BASE_MANA_COST = 50;

/* Magnitudine 1-6 da vnum mob 20-25 (default 1). */
int cacaodemon_magnitude_from_vnum(int vnum);

/* Magnitudine 1-6 dall'argomento cast (one..six / 1..6); 0 se non valido. */
int cacaodemon_magnitude_from_cast_arg(const char* arg);

/**
 * Fattore EQ per cacaodemon: 70% pressione mondo (EQ riferimento online) +
 * 30% potenza personale relativa al mondo; entrambi su curva soft-cap.
 */
float cacaodemon_eq_factor(struct char_data* caster);

float cacaodemon_power_index(struct char_data* caster, int spell_level, int magnitude);

int cacaodemon_mana_cost(struct char_data* caster, int magnitude);

/** Valore minimo offerta per riutilizzo chierico malvagio (base 200 * fattore EQ). */
int cacaodemon_min_offering_cost(struct char_data* caster);

/** Divisore logoramento offerta chierico malvagio (cresce col fattore EQ). */
int cacaodemon_offering_wear_divisor(struct char_data* caster);

bool is_cacaodemon(const struct char_data* mob);

/* Guardia del corpo: sempre il master; gruppo AFF_GROUP se livello demone <= 49. */
void cacaodemon_assign_bodyguard(struct char_data* demon, struct char_data* master);

bool cacaodemon_is_vigila_order(const std::string& command);

/* order <demon> vigila|guardia|proteggi — ripristina bodyguard master (+ gruppo se <= 49). */
bool cacaodemon_order_vigila(struct char_data* master, struct char_data* demon,
		const std::string& command);

// Modifica proceduralmente il mob appena allocato dall'engine prima del piazzamento
void proc_modify_cacaodemon(struct char_data* caster, struct char_data* demon, int spell_level);

// Special proc unica: smista il comportamento in base all'allineamento del demone
MOBSPECIAL_FUNC(spec_cacaodemon);

} // namespace Alarmud

#endif // __PROC_CACAODEMON_HPP
