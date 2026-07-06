/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "thief_tactics.hpp"
#include "act.move.hpp"
#include "fight.hpp"
#include "handler.hpp"
#include "constants.hpp"
#include "multiclass.hpp"
#include "spells.hpp"
#include "structs.hpp"
#include "utility.hpp"
#include "utils.hpp"
#include <cstdio>
#include <cstring>

namespace Alarmud {

namespace {

struct thief_skill_gate {
	int skill;
	int min_level;
};

const thief_skill_gate kThiefSkillGates[] = {
	{SKILL_POCKET_SAND,   5},
	{SKILL_CHEAP_SHOT,    8},
	{SKILL_TUMBLE,       12},
	{SKILL_POISONCRAFT,  15},
	{SKILL_FEINT,        16},
	{SKILL_RIPOSTE,      20},
	{SKILL_HAMSTRING,    24},
	{SKILL_CIRCLE_KICK,  28},
	{SKILL_GOUGE,        32},
	{SKILL_GAG,          36},
	{SKILL_VAULT,        42},
	{SKILL_MIX_THROW,    45},
	{SKILL_SNATCH,       48},
	{SKILL_FIND_THE_SEAM, 51},
	{0, 0}
};

bool pierce_weapon_valid(struct char_data* ch) {
	if(ch == nullptr || ch->equipment[WIELD] == nullptr) {
		return false;
	}
	const int weaponType = ch->equipment[WIELD]->obj_flags.value[3];
	return weaponType == 11 || weaponType == 1 || weaponType == 10;
}

bool pierce_attack_type(int type) {
	return type == SKILL_BACKSTAB || type == TYPE_PIERCE || type == TYPE_STAB ||
	       type == TYPE_STING || type == TYPE_RANGE_WEAPON;
}

int thief_level(struct char_data* ch) {
	return GET_LEVEL(ch, THIEF_LEVEL_IND);
}

int skill_roll(struct char_data* ch, int skill) {
	if(ch == nullptr || ch->skills == nullptr || skill <= 0) {
		return 0;
	}
	return MIN(100, ch->skills[skill].learned);
}

bool roll_skill(struct char_data* ch, int skill, int bonus = 0) {
	return number(1, 101) <= skill_roll(ch, skill) + bonus;
}

bool roll_failed(struct char_data* ch, int skill, int bonus = 0) {
	return number(1, 101) > skill_roll(ch, skill) + bonus;
}

struct char_data* resolve_victim(struct char_data* ch, const char* arg) {
	char name[MAX_INPUT_LENGTH];
	only_argument(arg, name);
	struct char_data* victim = get_char_room_vis(ch, name);
	if(victim == nullptr && ch->specials.fighting != nullptr) {
		victim = ch->specials.fighting;
	}
	return victim;
}

bool thief_tactics_blocked(struct char_data* ch, bool need_fight) {
	if(ch == nullptr || !HasClass(ch, CLASS_THIEF)) {
		send_to_char("Non sei un ladro!\n\r", ch);
		return true;
	}
	if(MOUNTED(ch)) {
		send_to_char("Non mentre sei a cavallo.\n\r", ch);
		return true;
	}
	if(need_fight && ch->specials.fighting == nullptr) {
		send_to_char("Non stai combattendo con nessuno.\n\r", ch);
		return true;
	}
	return false;
}

void spend_move(struct char_data* ch, int amount) {
	if(ch == nullptr || amount <= 0) {
		return;
	}
	GET_MOVE(ch) = MAX(0, GET_MOVE(ch) - amount);
	alter_move(ch, 0);
}

void apply_blind_light(struct char_data* victim, struct char_data* ch, int duration) {
	struct affected_type af;
	af.type = SPELL_BLINDNESS;
	af.location = APPLY_HITROLL;
	af.modifier = -2;
	af.duration = MAX(1, duration);
	af.bitvector = AFF_BLIND;
	affect_to_char(victim, &af);
}

void cheap_shot_strike(struct char_data* ch, struct char_data* victim) {
	if(ch == nullptr || victim == nullptr || !thief_has_skill(ch, SKILL_CHEAP_SHOT)) {
		return;
	}
	if(affected_by_spell(ch, SKILL_CHEAP_SHOT)) {
		return;
	}
	struct affected_type cd;
	cd.type = SKILL_CHEAP_SHOT;
	cd.duration = 1;
	cd.modifier = 0;
	cd.location = APPLY_NONE;
	cd.bitvector = 0;
	affect_to_char(ch, &cd);

	const int pct = OnlyClass(ch, CLASS_THIEF) ? 75 : 50;
	act("$n sferra un colpo basso mentre $N e' vulnerabil$b!", TRUE, ch, 0, victim, TO_NOTVICT);
	act("Sferri un colpo basso mentre $N e' vulnerabil$b!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n approfitta del tuo momento di debolezza!", TRUE, ch, 0, victim, TO_VICT);

	const int dam = MAX(1, dice(1, 6) + thief_level(ch) / 5);
	damage(ch, victim, (dam * pct) / 100, TYPE_STAB, 0);
}

} // namespace

int thief_skill_min_level(int skill) {
	for(int i = 0; kThiefSkillGates[i].skill != 0; ++i) {
		if(kThiefSkillGates[i].skill == skill) {
			return kThiefSkillGates[i].min_level;
		}
	}
	return 0;
}

bool thief_has_skill(struct char_data* ch, int skill) {
	if(ch == nullptr || !HasClass(ch, CLASS_THIEF) || ch->skills == nullptr || skill <= 0) {
		return false;
	}
	if(thief_level(ch) < thief_skill_min_level(skill)) {
		return false;
	}
	if(skill == SKILL_VAULT || skill == SKILL_SNATCH || skill == SKILL_POISONCRAFT ||
			skill == SKILL_MIX_THROW || skill == SKILL_FIND_THE_SEAM) {
		if(!OnlyClass(ch, CLASS_THIEF)) {
			return false;
		}
	}
	return IS_SET(ch->skills[skill].flags, SKILL_KNOWN) && ch->skills[skill].learned > 0;
}

void thief_on_advance_level(struct char_data* ch) {
	if(ch == nullptr || !HasClass(ch, CLASS_THIEF) || ch->skills == nullptr) {
		return;
	}
	const int level = thief_level(ch);
	for(int i = 0; kThiefSkillGates[i].skill != 0; ++i) {
		const int sk = kThiefSkillGates[i].skill;
		if(level < kThiefSkillGates[i].min_level) {
			continue;
		}
		if((sk == SKILL_VAULT || sk == SKILL_SNATCH || sk == SKILL_POISONCRAFT ||
				sk == SKILL_MIX_THROW || sk == SKILL_FIND_THE_SEAM) &&
				!OnlyClass(ch, CLASS_THIEF)) {
			continue;
		}
		if(!IS_SET(ch->skills[sk].flags, SKILL_KNOWN)) {
			SET_BIT(ch->skills[sk].flags, SKILL_KNOWN);
			SET_BIT(ch->skills[sk].flags, SKILL_KNOWN_THIEF);
			ch->skills[sk].learned = MAX(ch->skills[sk].learned, 10 + level / 2);
			send_to_char("Hai appreso una nuova abilita' da ladro!\n\r", ch);
		}
	}
	if(level >= 51 && OnlyClass(ch, CLASS_THIEF)) {
		send_to_char("Le fessure nelle difese piu' impenetrabili ti sono rivelate.\n\r", ch);
	}
}

int thief_adjust_pierce_damage(struct char_data* attacker, struct char_data* victim,
                               int type, int dam, int raw_dam) {
	if(attacker == nullptr || victim == nullptr || raw_dam <= 0 || dam < 0) {
		return dam;
	}
	if(!pierce_attack_type(type)) {
		return dam;
	}
	if(!thief_has_skill(attacker, SKILL_FIND_THE_SEAM)) {
		return dam;
	}
	if(!pierce_weapon_valid(attacker) && type != SKILL_BACKSTAB) {
		return dam;
	}
	if(IS_SET(victim->M_immune, IMM_PIERCE) && dam <= 0) {
		if(number(1, 100) <= 10) {
			act("Colpisci tra le piastre dell'armatura di $N!", FALSE, attacker, 0, victim, TO_CHAR);
		}
		return MAX(1, raw_dam >> 1);
	}
	if(IS_SET(victim->immune, IMM_PIERCE) && dam < raw_dam) {
		if(number(1, 100) <= 10) {
			act("La tua lama trova un varco tra le piastre di $N!", FALSE, attacker, 0, victim, TO_CHAR);
		}
		return raw_dam;
	}
	return dam;
}

void thief_on_dodge_success(struct char_data* defender, struct char_data* attacker) {
	if(defender == nullptr || attacker == nullptr || !thief_has_skill(defender, SKILL_RIPOSTE)) {
		return;
	}
	if(defender->specials.fighting != attacker) {
		return;
	}
	spend_move(defender, 10);
	act("$n devia il colpo e contrattacca in un lampo!", TRUE, defender, 0, attacker, TO_NOTVICT);
	act("Devii il colpo e contrattacchi!", FALSE, defender, 0, attacker, TO_CHAR);
	act("$n devia il tuo attacco e ti colpisce!", TRUE, defender, 0, attacker, TO_VICT);
	const int pct = OnlyClass(defender, CLASS_THIEF) ? 100 : 50;
	const int dam = MAX(1, (dice(1, 8) + thief_level(defender) / 4) * pct / 100);
	damage(defender, attacker, dam, TYPE_STAB, 0);
}

void thief_on_backstab_failed(struct char_data* attacker, struct char_data* victim) {
	if(victim == nullptr || attacker == nullptr) {
		return;
	}
	if(victim->specials.fighting == attacker) {
		cheap_shot_strike(victim, attacker);
	}
}

void thief_on_victim_fell(struct char_data* victim, struct char_data* attacker) {
	if(victim == nullptr || attacker == nullptr) {
		return;
	}
	if(GET_POS(victim) > POSITION_SITTING) {
		return;
	}
	cheap_shot_strike(victim, attacker);
}

bool thief_is_feinted(struct char_data* ch) {
	return ch != nullptr && affected_by_spell(ch, SKILL_FEINT);
}

bool thief_is_hamstrung(struct char_data* ch) {
	return ch != nullptr && affected_by_spell(ch, SKILL_HAMSTRING);
}

ACTION_FUNC(do_sand) {
	if(!ch->skills || thief_tactics_blocked(ch, false)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_POCKET_SAND)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	if(check_peaceful(ch, "Non in questa stanza di pace.\n\r")) {
		return;
	}
	struct char_data* victim = resolve_victim(ch, arg);
	if(victim == nullptr) {
		send_to_char("Su chi vuoi lanciare la sabbia?\n\r", ch);
		return;
	}
	if(victim == ch) {
		send_to_char("Molto divertente.\n\r", ch);
		return;
	}
	if(!OUTSIDE(ch) && !get_obj_in_list_vis(ch, "pouch sand", ch->carrying)) {
		send_to_char("Ti serve sabbia o un sacchetto di sabbia.\n\r", ch);
		return;
	}
	spend_move(ch, 15);
	int percent = number(1, 101);
	percent -= dex_app_skill[static_cast<int>(GET_DEX(ch))].reaction * 5;
	percent += dex_app_skill[static_cast<int>(GET_DEX(victim))].reaction * 5;
	percent += GetMaxLevel(victim) - GetMaxLevel(ch);
	if(roll_failed(ch, SKILL_POCKET_SAND, dex_app_skill[static_cast<int>(GET_DEX(ch))].sneak)) {
		LearnFromMistake(ch, SKILL_POCKET_SAND, 0, 90);
		act("$n lancia della sabbia verso $N ma la manca.", TRUE, ch, 0, victim, TO_NOTVICT);
		act("La tua sabbia non va a segno.", FALSE, ch, 0, victim, TO_CHAR);
		WAIT_STATE(ch, PULSE_VIOLENCE * 2);
		return;
	}
	apply_blind_light(victim, ch, 1 + thief_level(ch) / 10);
	act("$n lancia un pugno di sabbia negli occhi di $N!", TRUE, ch, 0, victim, TO_NOTVICT);
	act("Lanci un pugno di sabbia negli occhi di $N!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n ti acceca con la sabbia!", TRUE, ch, 0, victim, TO_VICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 2);
	WAIT_STATE(victim, PULSE_VIOLENCE);
}

ACTION_FUNC(do_tumble) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_TUMBLE)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	char dirTok[MAX_INPUT_LENGTH];
	one_argument(arg, dirTok);
	if(dirTok[0] == '\0') {
		send_to_char("In quale direzione vuoi rotolare via?\n\r", ch);
		return;
	}
	const int attempt = search_block(dirTok, dirs, FALSE);
	if(attempt < 0) {
		send_to_char("Direzione non valida.\n\r", ch);
		return;
	}
	if(!CAN_GO(ch, attempt)) {
		send_to_char("Non puoi uscire da quella parte.\n\r", ch);
		return;
	}
	spend_move(ch, 25);
	const int bonus = OnlyClass(ch, CLASS_THIEF) ? 15 : 0;
	if(roll_failed(ch, SKILL_TUMBLE, bonus + dex_app_skill[static_cast<int>(GET_DEX(ch))].sneak)) {
		LearnFromMistake(ch, SKILL_TUMBLE, 0, 90);
		act("$n inciampa nel tentativo di rotolare via.", TRUE, ch, 0, 0, TO_ROOM);
		send_to_char("Inciampi e resti espost$b.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 3);
		return;
	}
	act("$n rotola via abilmente!", TRUE, ch, 0, 0, TO_ROOM);
	send_to_char("Rotoli via dal combattimento!\n\r", ch);
	stop_fighting(ch);
	if(MoveOne(ch, attempt, TRUE)) {
		send_to_char("PANICO! Non riesci a scappare!\n\r", ch);
	}
	WAIT_STATE(ch, PULSE_VIOLENCE);
}

ACTION_FUNC(do_feint) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_FEINT)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	struct char_data* victim = ch->specials.fighting;
	if(victim == nullptr) {
		return;
	}
	spend_move(ch, 10);
	GET_MANA(ch) = MAX(0, GET_MANA(ch) - 5);
	alter_mana(ch, 0);
	if(roll_failed(ch, SKILL_FEINT)) {
		LearnFromMistake(ch, SKILL_FEINT, 0, 90);
		act("$n fa un finto movimento, ma $N non ci casca.", TRUE, ch, 0, victim, TO_NOTVICT);
		send_to_char("La tua finta non inganna il bersaglio.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 2);
		return;
	}
	struct affected_type af;
	af.type = SKILL_FEINT;
	af.duration = 1;
	af.modifier = 0;
	af.location = APPLY_NONE;
	af.bitvector = 0;
	affect_to_char(victim, &af);
	act("$n ti inganna con un finto movimento!", TRUE, ch, 0, victim, TO_VICT);
	act("Inganni $N con una finta!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n inganna $N con una finta!", TRUE, ch, 0, victim, TO_NOTVICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 2);
}

ACTION_FUNC(do_hamstring) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_HAMSTRING)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	if(!pierce_weapon_valid(ch)) {
		send_to_char("Ti serve un'arma tagliente o appuntita.\n\r", ch);
		return;
	}
	struct char_data* victim = ch->specials.fighting;
	if(victim == nullptr) {
		return;
	}
	spend_move(ch, 20);
	if(roll_failed(ch, SKILL_HAMSTRING)) {
		LearnFromMistake(ch, SKILL_HAMSTRING, 0, 90);
		act("$n tenta di colpire le gambe di $N ma fallisce.", TRUE, ch, 0, victim, TO_NOTVICT);
		send_to_char("Non riesci a mutilare le gambe del bersaglio.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 3);
		return;
	}
	struct affected_type af;
	af.type = SKILL_HAMSTRING;
	af.duration = 2 + thief_level(ch) / 12;
	af.modifier = -MIN(6, 3 + thief_level(ch) / 15);
	af.location = APPLY_DEX;
	af.bitvector = 0;
	affect_to_char(victim, &af);
	const int dam = dice(1, 4) + thief_level(ch) / 5;
	damage(ch, victim, dam, TYPE_SLASH, 0);
	act("$n colpisce le gambe di $N!", TRUE, ch, 0, victim, TO_NOTVICT);
	act("Colpisci le gambe di $N!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n ti colpisce alle gambe!", TRUE, ch, 0, victim, TO_VICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 3);
}

ACTION_FUNC(do_ckick) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_CIRCLE_KICK)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	struct char_data* victim = resolve_victim(ch, arg);
	if(victim == nullptr) {
		send_to_char("Chi vuoi colpire?\n\r", ch);
		return;
	}
	spend_move(ch, 15);
	if(roll_failed(ch, SKILL_CIRCLE_KICK)) {
		LearnFromMistake(ch, SKILL_CIRCLE_KICK, 0, 90);
		act("$n tenta un calcio circolare ma sbaglia.", TRUE, ch, 0, 0, TO_ROOM);
		WAIT_STATE(ch, PULSE_VIOLENCE * 2);
		return;
	}
	const int dam = dice(1, 6) + thief_level(ch) / 4;
	damage(ch, victim, dam, TYPE_BLUDGEON, 0);
	if(roll_skill(ch, SKILL_CIRCLE_KICK, -10)) {
		GET_POS(victim) = POSITION_SITTING;
		WAIT_STATE(victim, PULSE_VIOLENCE * 3);
		thief_on_victim_fell(victim, ch);
	}
	act("$n sferra un calcio circolare a $N!", TRUE, ch, 0, victim, TO_NOTVICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 2);
}

ACTION_FUNC(do_gouge) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_GOUGE)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	if(!pierce_weapon_valid(ch)) {
		send_to_char("Ti serve un'arma perforante o tagliente.\n\r", ch);
		return;
	}
	struct char_data* victim = resolve_victim(ch, arg);
	if(victim == nullptr) {
		send_to_char("Chi vuoi colpire?\n\r", ch);
		return;
	}
	if(victim == ch) {
		send_to_char("Molto spiritoso.\n\r", ch);
		return;
	}
	spend_move(ch, 20);
	int percent = number(1, 101);
	percent -= dex_app_skill[static_cast<int>(GET_DEX(ch))].reaction * 10;
	percent += dex_app_skill[static_cast<int>(GET_DEX(victim))].reaction * 10;
	percent += GetMaxLevel(victim) - GetMaxLevel(ch);
	if(IS_AFFECTED(ch, AFF_HIDE)) {
		percent -= 10;
	}
	if(percent > skill_roll(ch, SKILL_GOUGE)) {
		LearnFromMistake(ch, SKILL_GOUGE, 0, 95);
		act("$n tenta di colpire gli occhi di $N ma fallisce.", TRUE, ch, 0, victim, TO_NOTVICT);
		send_to_char("Il tuo attacco agli occhi fallisce.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 2);
		return;
	}
	struct affected_type af;
	af.type = SKILL_GOUGE;
	af.location = APPLY_HITROLL;
	af.modifier = -3;
	af.duration = MAX(1, thief_level(ch) / 10);
	af.bitvector = AFF_BLIND;
	affect_to_char(victim, &af);
	const int dam = dice(2, 4) + dex_app_skill[static_cast<int>(GET_DEX(ch))].reaction;
	damage(ch, victim, dam, TYPE_PIERCE, 0);
	act("$n colpisce gli occhi di $N con la punta dell'arma!", TRUE, ch, 0, victim, TO_NOTVICT);
	act("Colpisci gli occhi di $N!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n ti colpisce agli occhi!", TRUE, ch, 0, victim, TO_VICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 3);
}

ACTION_FUNC(do_gag) {
	if(!ch->skills || thief_tactics_blocked(ch, false)) {
		return;
	}
	if(!thief_has_skill(ch, SKILL_GAG)) {
		send_to_char("Non conosci questa tecnica.\n\r", ch);
		return;
	}
	struct char_data* victim = resolve_victim(ch, arg);
	if(victim == nullptr) {
		send_to_char("Chi vuoi silenziare?\n\r", ch);
		return;
	}
	if(GET_POS(victim) > POSITION_SITTING && ch->specials.fighting != victim) {
		send_to_char("Devi colpire la gola alle spalle o contro un bersaglio a terra.\n\r", ch);
		return;
	}
	spend_move(ch, 25);
	int save = (GET_INT(victim) + GET_WIS(victim)) / 2;
	if(HasClass(victim, CLASS_PSI)) {
		save += 20;
	}
	if(roll_failed(ch, SKILL_GAG, save / 3)) {
		LearnFromMistake(ch, SKILL_GAG, 0, 90);
		act("$n tenta di soffocare le parole di $N ma fallisce.", TRUE, ch, 0, victim, TO_NOTVICT);
		WAIT_STATE(ch, PULSE_VIOLENCE * 3);
		return;
	}
	struct affected_type af;
	af.type = SKILL_GAG;
	af.duration = MIN(4, 1 + thief_level(ch) / 15);
	af.modifier = 0;
	af.location = APPLY_NONE;
	af.bitvector = AFF_SILENCE;
	affect_to_char(victim, &af);
	act("$n stringe la gola di $N impedendogli di parlare!", TRUE, ch, 0, victim, TO_NOTVICT);
	act("Stringi la gola di $N!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n ti impedisce di parlare!", TRUE, ch, 0, victim, TO_VICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 3);
}

ACTION_FUNC(do_vault) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_VAULT)) {
		send_to_char("Solo un ladro puro padroneggia questa tecnica.\n\r", ch);
		return;
	}
	char name[MAX_INPUT_LENGTH];
	one_argument(arg, name);
	struct char_data* ally = get_char_room_vis(ch, name);
	if(ally == nullptr || ally == ch) {
		send_to_char("Su chi vuoi passare l'attenzione?\n\r", ch);
		return;
	}
	if(GET_MAX_HIT(ally) <= GET_MAX_HIT(ch) * 12 / 10) {
		send_to_char("Il tuo alleato non e' abbastanza robusto per attirare l'attenzione.\n\r", ch);
		return;
	}
	if(affected_by_spell(ch, SKILL_VAULT)) {
		send_to_char("Devi aspettare prima di usare di nuovo questa tecnica.\n\r", ch);
		return;
	}
	spend_move(ch, 40);
	struct affected_type cd;
	cd.type = SKILL_VAULT;
	cd.duration = 30;
	cd.modifier = 0;
	cd.location = APPLY_NONE;
	cd.bitvector = 0;
	affect_to_char(ch, &cd);

	for(struct char_data* mob = combat_list; mob != nullptr; ) {
		struct char_data* const next = mob->next_fighting;
		if(mob->specials.fighting == ch) {
			stop_fighting(mob);
			SetVictFighting(mob, ally);
			SetCharFighting(mob, ally);
		}
		mob = next;
	}
	stop_fighting(ch);
	act("$n salta oltre $N attirando l'attenzione dei nemici su di l$b!", TRUE, ch, 0, ally, TO_NOTVICT);
	act("Passi l'attenzione dei nemici a $N!", FALSE, ch, 0, ally, TO_CHAR);
	act("$n ti passa addosso l'attenzione dei nemici!", TRUE, ch, 0, ally, TO_VICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 4);
	WAIT_STATE(ally, PULSE_VIOLENCE);
}

ACTION_FUNC(do_snatch) {
	if(!ch->skills || thief_tactics_blocked(ch, true)) {
		return;
	}
	if(!OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_SNATCH)) {
		send_to_char("Solo un ladro puro padroneggia questa tecnica.\n\r", ch);
		return;
	}
	struct char_data* victim = ch->specials.fighting;
	if(victim == nullptr || victim->equipment[WIELD] == nullptr) {
		send_to_char("Il tuo avversario non impugna nulla.\n\r", ch);
		return;
	}
	spend_move(ch, 35);
	int percent = number(1, 101);
	if(GET_STR(victim) > 17) {
		percent += (GET_STR(victim) - 17) * 10;
	}
	if(percent > skill_roll(ch, SKILL_SNATCH)) {
		LearnFromMistake(ch, SKILL_SNATCH, 0, 90);
		act("$n tenta di strappare l'arma a $N ma fallisce.", TRUE, ch, 0, victim, TO_NOTVICT);
		send_to_char("Non riesci a strappare l'arma.\n\r", ch);
		damage(victim, ch, dice(1, 6), TYPE_BLUDGEON, 0);
		WAIT_STATE(ch, PULSE_VIOLENCE * 4);
		return;
	}
	struct obj_data* weapon = unequip_char(victim, WIELD);
	if(weapon != nullptr) {
		obj_to_char(weapon, ch);
		act("$n strappa $p dalle mani di $N e la infila nella sua borsa!", TRUE, ch, weapon, victim, TO_NOTVICT);
		act("Strappi $p a $N!", FALSE, ch, weapon, victim, TO_CHAR);
		act("$n ti strappa $p di mano!", TRUE, ch, weapon, victim, TO_VICT);
	}
	WAIT_STATE(ch, PULSE_VIOLENCE * 4);
}

ACTION_FUNC(do_poisoncraft) {
	if(!ch->skills || !OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_POISONCRAFT)) {
		send_to_char("Solo un ladro puro conosce l'arte dei veleni.\n\r", ch);
		return;
	}
	char recipe[MAX_INPUT_LENGTH];
	one_argument(arg, recipe);
	if(recipe[0] == '\0') {
		send_to_char("Sintassi: poison <weak|numb|bleed|paralytic|nightfall|blacklotus>\n\r", ch);
		return;
	}
	if(roll_failed(ch, SKILL_POISONCRAFT)) {
		LearnFromMistake(ch, SKILL_POISONCRAFT, 0, 90);
		send_to_char("Rovini il composto.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 6);
		return;
	}
	send_to_char("Prepari un vial di veleno.\n\r", ch);
	act("$n prepara un composto tossico.", TRUE, ch, 0, 0, TO_ROOM);
	WAIT_STATE(ch, PULSE_VIOLENCE * 6);
}

ACTION_FUNC(do_envenom) {
	if(!ch->skills || !OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_POISONCRAFT)) {
		send_to_char("Solo un ladro puro conosce l'arte dei veleni.\n\r", ch);
		return;
	}
	if(ch->equipment[WIELD] == nullptr) {
		send_to_char("Devi impugnare un'arma.\n\r", ch);
		return;
	}
	if(!get_obj_in_list_vis(ch, "vial poison", ch->carrying)) {
		send_to_char("Non hai un vial di veleno pronto.\n\r", ch);
		return;
	}
	ch->equipment[WIELD]->obj_flags.value[2] = MAX(ch->equipment[WIELD]->obj_flags.value[2], 1);
	send_to_char("Avveleni la tua arma.\n\r", ch);
	act("$n avvelena la propria arma.", TRUE, ch, 0, 0, TO_ROOM);
	WAIT_STATE(ch, PULSE_VIOLENCE * 2);
}

ACTION_FUNC(do_mix) {
	if(!ch->skills || !OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_MIX_THROW)) {
		send_to_char("Solo un ladro puro conosce questa arte.\n\r", ch);
		return;
	}
	char recipe[MAX_INPUT_LENGTH];
	one_argument(arg, recipe);
	if(recipe[0] == '\0') {
		send_to_char("Sintassi: mix <acid|smoke|fire|choking|shrapnel>\n\r", ch);
		return;
	}
	if(roll_failed(ch, SKILL_MIX_THROW)) {
		LearnFromMistake(ch, SKILL_MIX_THROW, 0, 90);
		send_to_char("Il composto esplode tra le tue mani... quasi.\n\r", ch);
		WAIT_STATE(ch, PULSE_VIOLENCE * 6);
		return;
	}
	send_to_char("Prepari una fiala lanciabile.\n\r", ch);
	act("$n prepara una fiala chimica.", TRUE, ch, 0, 0, TO_ROOM);
	WAIT_STATE(ch, PULSE_VIOLENCE * 6);
}

ACTION_FUNC(do_throwpotion) {
	if(!ch->skills || !OnlyClass(ch, CLASS_THIEF) || !thief_has_skill(ch, SKILL_MIX_THROW)) {
		send_to_char("Solo un ladro puro conosce questa arte.\n\r", ch);
		return;
	}
	struct char_data* victim = resolve_victim(ch, arg);
	if(victim == nullptr) {
		send_to_char("Chi vuoi colpire con la fiala?\n\r", ch);
		return;
	}
	spend_move(ch, 20);
	const int dam = dice(2, 6) + thief_level(ch) / 3;
	damage(ch, victim, dam, TYPE_GENERIC_ACID, 0);
	act("$n lancia una fiala contro $N!", TRUE, ch, 0, victim, TO_NOTVICT);
	WAIT_STATE(ch, PULSE_VIOLENCE * 2);
}

} // namespace Alarmud
