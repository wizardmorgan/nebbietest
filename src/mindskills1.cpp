/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
//  Original intial comments
/*$Id: mindskills1.c,v 1.3 2002/02/13 12:31:00 root Exp $
*/
/***************************  System  include ************************************/
#include <cstdio>
#include <cassert>
/***************************  General include ************************************/
#include "config.hpp"
#include "typedefs.hpp"
#include "flags.hpp"
#include "autoenums.hpp"
#include "structs.hpp"
#include "logging.hpp"
#include "constants.hpp"
#include "utils.hpp"
/***************************  Local    include ************************************/
#include "mindskills1.hpp"
#include "act.info.hpp"
#include "act.move.hpp"
#include "comm.hpp"
#include "db.hpp"
#include "fight.hpp"
#include "handler.hpp"
#include "interpreter.hpp"
#include "magic.hpp"
#include "opinion.hpp"
#include "regen.hpp"
#include "spell_parser.hpp"
#include "spells.hpp"

namespace Alarmud {

namespace {

bool psi_ultra_blast_target(struct char_data* ch, struct char_data* t) {
	if(!t || t == ch || IS_IMMORTAL(t) || in_group(ch, t)) {
		return false;
	}
	if(ch->specials.fighting == t || t->specials.fighting == ch) {
		return true;
	}
	if(Hates(t, ch) || Hates(ch, t)) {
		return true;
	}
	if(IS_NPC(t) && IS_SET(t->specials.act, ACT_AGGRESSIVE) && CAN_SEE(t, ch)) {
		return true;
	}
	return false;
}

void mind_scramble_degrade_skills(struct char_data* victim, int count, int amount) {
	int n;

	if(!victim || !victim->skills) {
		return;
	}

	for(n = 0; n < count; n++) {
		int tries = 0;
		while(tries++ < 60) {
			int i = number(0, MAX_SKILLS - 1);
			if(victim->skills[i].learned > 0 &&
					IS_SET(victim->skills[i].flags, SKILL_KNOWN)) {
				victim->skills[i].learned =
					MAX(0, victim->skills[i].learned - amount - number(0, 10));
				break;
			}
		}
	}
}

} // namespace

/*
***        PSI Skills
*/



void mind_burn(byte level, struct char_data* ch,
			   struct char_data* victim, struct obj_data* obj) {
	int dam;
	struct char_data* tmp_victim, *temp;

	if(!ch) {
		return;
	}

	dam = dice(1,4) + level/2 + 1;

	send_to_char("Crei con il pensiero delle lingue di fuoco!\n\r", ch);
	act("$n crea delle lingue di fuoco con il potere della mente!\n\r",
		FALSE, ch, 0, 0, TO_ROOM);

	for(tmp_victim = real_roomp(ch->in_room)->people; tmp_victim;
			tmp_victim = temp) {
		temp = tmp_victim->next_in_room;
		if((ch->in_room == tmp_victim->in_room) && (ch != tmp_victim)) {
			if((GetMaxLevel(tmp_victim)>IMMORTALE) && (!IS_NPC(tmp_victim))) {
				return;
			}
			if(!in_group(ch, tmp_victim)) {
				act("Vieni avvolt$b dalle fiamme!\n\r",
					FALSE, ch, 0, tmp_victim, TO_VICT);
				heat_blind(tmp_victim);
				if(saves_spell(tmp_victim, SAVING_SPELL)) {
					dam = 0;
				}
				MissileDamage(ch, tmp_victim, dam, SKILL_MIND_BURN, 5);
			}
			else {
				act("Riesci ad evitare le fiamme!\n\r",
					FALSE, ch, 0, tmp_victim, TO_VICT);
				heat_blind(tmp_victim);
			}
		}
	}
}

void mind_teleport(byte level, struct char_data* ch,
				   struct char_data* victim, struct obj_data* obj) {
	int to_room, iTry = 0;
	struct room_data* room;

	if(!ch || !victim) {
		return;
	}

	if(victim != ch) {
		if(saves_spell(victim,SAVING_SPELL)) {
			send_to_char("Non riesci a teleportare quella persona\n\r",ch);
			if(IS_NPC(victim)) {
				if(!victim->specials.fighting) {
					set_fighting(victim, ch);
				}
			}
			else {
				send_to_char("Hai una strana sensazione ma l'effetto passa.\n\r",victim);
			}
			return;
		}
		else {
			ch = victim;  /* the character (target) is now the victim */
		}
	}

	if(!IsOnPmp(victim->in_room)) {
		send_to_char("Sei in un piano extra-dimensionale!\n\r", ch);
		return;
	}


	do {
		to_room = number(0, top_of_world);
		room = real_roomp(to_room);
		if(room) {
			if((IS_SET(room->room_flags, PRIVATE)) ||
					(IS_SET(room->room_flags, DEATH) && IS_NPC(victim)) ||
					(IS_SET(room->room_flags, TUNNEL)) ||
					(IS_SET(room->room_flags, NO_SUM)) ||
					(IS_SET(room->room_flags, NO_MAGIC)) ||
					!IsOnPmp(to_room) ||
					((room->number >= 34000) && (room->number <= 34999))
			  ) {
				room = 0;
				iTry++;
			}
		}

	}
	while(!room && iTry < 10);

	if(iTry >= 10) {
		send_to_char("The skill fails.\n\r", ch);
		return;
	}

	act("$n viene scompost$b in piccole particelle e scompare!", FALSE, ch,0,0,TO_ROOM);
	char_from_room(ch);
	char_to_room(ch, to_room);
	act("Una massa di particelle luminose si compone nella figura di $n!", FALSE, ch,0,0,TO_ROOM);

	do_look(ch, "", 15);


	check_falling(ch);

}

/* astral travel */
#define PROBABILITY_TRAVEL_ENTRANCE   2701
void mind_probability_travel(byte level, struct char_data* ch,
							 struct char_data* victim, struct obj_data* obj) {
	struct char_data* tmp, *tmp2;
	struct room_data* rp;

	if(IS_SET(SystemFlags,SYS_NOASTRAL)) {
		send_to_char("I piani astrali si stanno spostando, non puoi!\n",ch);
		return;
	}

	rp = real_roomp(ch->in_room);

	for(tmp = rp->people; tmp; tmp = tmp2) {
		tmp2 = tmp->next_in_room;
		if(in_group_strict(ch, tmp) && !tmp->specials.fighting) {
			act("$n sbiadisce e scompare in un altro piano di esistenza.", FALSE,
				tmp, NULL, NULL, TO_ROOM);
			char_from_room(tmp);
			char_to_room(tmp, PROBABILITY_TRAVEL_ENTRANCE);
			do_look(tmp, "", 15);
			act("$n passa lentamente in questo piano di esistenza.", FALSE, tmp,
				NULL, NULL, TO_ROOM);
		}
	}
}

/* sense DT's */
void mind_danger_sense(byte level, struct char_data* ch,
					   struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_DANGER_SENSE)) {
		if(ch != victim) {
			act("$n apre la mente di $N ai pericoli nascosti.", TRUE, ch, 0,
				victim, TO_NOTVICT);
			act("$n ti apre la mente ai pericoli nascosti.", TRUE, ch, 0, victim,
				TO_VICT);
			act("Apri la mente di $N ai pericoli nascosti.", FALSE, ch, 0, victim,
				TO_CHAR);
		}
		else {
			act("$n sembra essere piu' attento al pericolo.", TRUE, victim, 0, 0,
				TO_ROOM);
			act("Apri la tua mente ai pericoli nascosti.", TRUE, victim, 0, 0,
				TO_CHAR);
		}

		af.type      = SKILL_DANGER_SENSE;
		af.duration  = (int)level/10;
		af.modifier  = 0;
		af.location  = APPLY_AFF2;
		af.bitvector = AFF2_DANGER_SENSE;
		affect_to_char(victim, &af);
	}
	else {
		if(ch != victim)
			act("$N puo' gia' percepire i pericoli nascosti.", FALSE, ch, 0,
				victim, TO_CHAR);
		else
			act("Puoi gia' percepire i pericoli nascosti.", FALSE, ch, 0, victim,
				TO_CHAR);
	}
}

/* same as thief spy skil, see into the next room */
void mind_clairvoyance(byte level, struct char_data* ch,
					   struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_CLAIRVOYANCE)) {
		if(ch != victim) {
			act("",FALSE,ch,0,victim,TO_CHAR);
			act("",FALSE,ch,0,victim,TO_ROOM);
		}
		else {
			act("$n medita per un attimo.",TRUE,victim,0,0,TO_ROOM);
			act("Apri la tua mente e visualizzi i luoghi che hai intorno.",TRUE,victim,0,0,TO_CHAR);
		}

		af.type      = SKILL_CLAIRVOYANCE;
		af.duration  = (level<IMMORTALE) ? 3 : level;
		af.modifier  = 0;
		af.location  = APPLY_NONE;
		af.bitvector = AFF_SCRYING;
		affect_to_char(victim, &af);
	}
	else {
		if(ch != victim) {
			act("$N riesce gia' a visulaizzare i luoghi che l$b circondano.",FALSE,ch,0,victim,TO_CHAR);
		}
		else {
			act("Sta gia' usando la chiaroveggenza.",FALSE,ch,0,victim,TO_CHAR);
		}
	}

}

/* single person attack skill */
void mind_disintegrate(byte level, struct char_data* ch,
					   struct char_data* victim, struct obj_data* obj) {
	spell_disintegrate(level,ch,victim,obj);
}

/***************************************************************************
 *
 * if not fighting, shove the mob/pc out a the room if suffcient
 * level and they do not save, otherwise set fighting. If fighting
 * then if they fail, treat as bashed and the mobs/pc sits.
 *
 ***************************************************************************/

void mind_telekinesis(byte level, struct char_data* ch,struct char_data* victim, int dir_num) {

	if(!ch) {
		mudlog(LOG_SYSERR, "!ch in telekenisis");
		return;
	}

	if(!victim) {
		mudlog(LOG_SYSERR, "!victim in telekenisis");
		return;
	}

	/* not fighting, shove him */
	if(!ch->specials.fighting) {
		if(dir_num < 1) {
			send_to_char("Devi indicare una direzione valida!\n\r", ch);
			return;
		}
		if(saves_spell(victim,SAVING_SPELL) ||
				(IS_SET(victim->specials.act,ACT_SENTINEL) &&
				 IS_SET(victim->specials.act,ACT_HUGE))) {
			/* saved, make fight */
			act("La tua mente si indebolisce e sei costretto a lasciare $N!", FALSE,
				ch, 0, victim, TO_CHAR);
			act("$n prova a spostarti, ma la tua mente resiste!", TRUE, ch, 0,
				victim, TO_VICT);
			act("$n prova a spostare $N senza successo!", TRUE, ch, 0, victim,
				TO_ROOM);
			hit(victim, ch, TYPE_UNDEFINED);
		}
		else {
			/* missed save, lets shove'em */
			act("Alzi $N con la forza della tua mente e l$B sposti lontano!", FALSE,
				ch, 0, victim, TO_CHAR);
			act("$n ti alza con la forza della sua mente e ti sposta lontano!",
				TRUE, ch, 0, victim, TO_VICT);
			act("$n alza $N con la forza della sua mente e l$B sposta lontano!",
				TRUE, ch, 0, victim, TO_ROOM);
			do_move(victim, "\0", dir_num);
		}
	} /* end was not fighting */
	else {
		int dam;
		int sit_chance;
		bool saved;

		/* fighting: impulso telecinetico + possibilita' di far sedere */
		saved = saves_spell(victim, SAVING_SPELL) != 0;
		dam = dice(level, 4);
		if(saved) {
			dam >>= 1;
		}
		if(IS_SET(victim->specials.act, ACT_HUGE)) {
			dam >>= 1;
		}
		if(dam > 0) {
			act("Scagli un impulso telecinetico contro $N!", FALSE, ch, 0, victim,
				TO_CHAR);
			act("$n ti colpisce con un impulso telecinetico!", TRUE, ch, 0, victim,
				TO_VICT);
			act("$n scaglia un impulso telecinetico contro $N!", TRUE, ch, 0,
				victim, TO_ROOM);
			MissileDamage(ch, victim, dam, SKILL_TELEKINESIS, 5);
		}
		else if(saved) {
			act("Non riesci a focalizzare la tua mente a sufficienza.", FALSE, ch,
				0, victim, TO_CHAR);
			act("$n fallisce nello spostarti con la forza della sua mente!", TRUE,
				ch, 0, victim, TO_VICT);
			act("$n cerca inutilmente di spostare $N con la forza della sua mente",
				TRUE, ch, 0, victim, TO_ROOM);
		}

		sit_chance = saved ? 30 : 55;
		sit_chance += (int)level / 5;
		if(IS_SET(victim->specials.act, ACT_HUGE)) {
			sit_chance = 25;
		}
		if(sit_chance > 85) {
			sit_chance = 85;
		}

		if(number(1, 100) <= sit_chance && GET_POS(victim) > POSITION_SITTING) {
			act("Sbatti $N a terra con il solo pensiero!", FALSE, ch, 0, victim,
				TO_CHAR);
			act("$n ti sbatte a terra con il solo pensiero!", TRUE, ch, 0, victim,
				TO_VICT);
			act("$n sbatte $N a terra con il solo pensiero!", TRUE, ch, 0, victim,
				TO_ROOM);
			GET_POS(victim) = POSITION_SITTING;
			if(!victim->specials.fighting) {
				set_fighting(victim, ch);
			}
			WAIT_STATE(victim, PULSE_VIOLENCE);
		}
	} /* end was fighting */
}

/* same as fly */
void mind_levitation(byte level, struct char_data* ch,
					 struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_LEVITATION)) {
		if(ch != victim) {
			act("Sollevi $N  da terra con la sola forza del pensiero.",FALSE,ch,0,victim,TO_CHAR);
			act("$N viene sollevat$b in aria con un semplice pensiero di $n.",FALSE,ch,0,victim,TO_ROOM);
		}
		else {
			act("$n si solleva da terra con la mente.",TRUE,victim,0,0,TO_ROOM);
			act("Ti sollevi da terra con il potere della mente",TRUE,victim,0,0,TO_CHAR);
		}

		af.type      = SKILL_LEVITATION;
		af.duration  = static_cast<int>(level) / 5;
		af.modifier  = 0;
		af.location  = APPLY_NONE;
		af.bitvector = AFF_FLYING;
		affect_to_char(victim, &af);
	}
	else {
		if(ch != victim) {
			act("$N sta gia' levitando.",FALSE,ch,0,victim,TO_CHAR);
		}
		else {
			act("Stai gia' levitando.",FALSE,ch,0,victim,TO_CHAR);
		}
	}
}

/* healing, 100 points max, cost 100 mana, and stuns the */
/* psi and lags along time, simular results as mage spell id */
void mind_cell_adjustment(byte level, struct char_data* ch,
						  struct char_data* victim, struct obj_data* obj) {

	if(!ch) {
		mudlog(LOG_SYSERR, "!ch in cell_adjustment");
		return;
	}

	if(ch != victim) {
		send_to_char("Non puoi usare questa abilita' sugli altri.\n\r",ch);
		return;
	}

	act("Inizi il processo di alterazione cellulare.", FALSE, ch, 0,
		victim,TO_CHAR);
	act("$n cade in un profondo trance.",FALSE,ch,0,victim,TO_ROOM);

	const long long current_hit = static_cast<long long>(GET_HIT(victim));
	const long long max_hit = static_cast<long long>(GET_MAX_HIT(victim));
	const long long max_partial_heal = max_hit - 100LL;
	if(current_hit > max_partial_heal) {
		act("Guarisci completamente il tuo corpo.",FALSE,victim,0,0,TO_CHAR);
		GET_HIT(victim) = GET_MAX_HIT(victim);
	}
	else {
		act("Riesci a guarire parte del tuo corpo attraverso l'alterazione cellulare.",FALSE,victim,0,0,TO_CHAR);
		GET_HIT(victim) +=100;
		alter_hit(victim,0);
	}

	if(GetMaxLevel(ch)<IMMORTALE) {
		act("Vieni sopraffatt$b dalla stanchezza.",FALSE,ch,0,0,TO_CHAR);
		act("$n crolla a terra esaust$b.",FALSE,ch,0,0,TO_ROOM);
		WAIT_STATE(ch,PULSE_VIOLENCE*12);
		GET_POS(ch) = POSITION_STUNNED;
	}

}

/* hide */
void mind_chameleon(byte level, struct char_data* ch,
					struct char_data* victim, struct obj_data* obj) {

	if(!ch) {
		return;
	}

	if(IS_AFFECTED(ch,AFF_HIDE)) {
		REMOVE_BIT(ch->specials.affected_by,AFF_HIDE);
	}

	act("Nascondi te stess$b alle altre menti.", FALSE, ch, 0, 0, TO_CHAR);
	act("Il corpo di $n svanisce nei dintorni.", FALSE, ch, 0, 0, TO_ROOM);
	SET_BIT(ch->specials.affected_by,AFF_HIDE);

}

/* strength */
void mind_psi_strength(byte level, struct char_data* ch,
					   struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!victim || !ch) {
		return;
	}


	if(!affected_by_spell(victim,SKILL_PSI_STRENGTH)) {
		act("Ti senti piu' forte.", FALSE, victim,0,0,TO_CHAR);
		act("$n sembra piu' forte.", TRUE, victim, 0, 0, TO_ROOM);
		af.type      = SKILL_PSI_STRENGTH;
		af.duration  = 2*level;
		if(IS_NPC(victim)) {
			if(level >= CREATOR) {
				af.modifier = 25 - GET_STR(victim);
			}
			else {
				af.modifier = number(1,6);
			}
		}
		else {
			if(HasClass(ch, CLASS_WARRIOR | CLASS_BARBARIAN)) {
				af.modifier = number(1,8);
			}
			else if(HasClass(ch, CLASS_CLERIC | CLASS_THIEF | CLASS_PSI)) {
				af.modifier = number(1,6);
			}
			else {
				af.modifier = number(1,4);
			}
		}
		af.location  = APPLY_STR;
		af.bitvector = 0;
		affect_to_char(victim, &af);
	}
	else {
		act("Non sembra succedere nulla.", FALSE, ch, 0, 0, TO_CHAR);
	}
}

/* long lag time, but after that they get 12 hrs of no hunger/thirst */
void mind_mind_over_body(byte level, struct char_data* ch,
						 struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_MIND_OVER_BODY)) {
		if(ch != victim) {
			act("",FALSE,ch,0,victim,TO_CHAR);
			act("",FALSE,ch,0,victim,TO_ROOM);
		}
		else {
			act("$n appare assort$b in meditazione.", TRUE, victim, 0, 0, TO_ROOM);
			act("Costringi il tuo corpo a non aver bisogno di cibo ed acqua!",
				TRUE, victim, 0,0, TO_CHAR);
		}

		af.type      = SKILL_MIND_OVER_BODY;
		af.duration  = 12;
		af.modifier  = -1;
		af.location  = APPLY_MOD_THIRST;
		af.bitvector = 0;
		affect_to_char(victim, &af);

		af.type      = SKILL_MIND_OVER_BODY;
		af.duration  = 12;
		af.modifier  = -1;
		af.location  = APPLY_MOD_HUNGER;
		af.bitvector = 0;
		affect_to_char(victim, &af);


	}
	else {
		if(ch != victim) {
			act("$N non ha bisogno del tuo aiuto.", FALSE, ch, 0, victim, TO_CHAR);
		}
		else
			act("Il tuo corpo non ha bisogno di mangiare o bere!", FALSE, ch, 0,
				victim, TO_CHAR);
	}
}

/* mind scramble (mind wipe): effetti diversi su PG e mob */
void mind_mind_wipe(byte level, struct char_data* ch,
					struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;
	int dur;

	(void)obj;

	if(!ch || !victim) {
		return;
	}

	if(affected_by_spell(victim, SKILL_MINDBLANK)) {
		act("La mente di $N e' troppo protetta per essere cancellata.", FALSE, ch,
			0, victim, TO_CHAR);
		if(!victim->specials.fighting && victim != ch && !IS_PC(victim)) {
			set_fighting(victim, ch);
		}
		return;
	}

	if(saves_spell(victim, SAVING_SPELL)) {
		act("La mente di $N resiste al tuo assalto psionico.", FALSE, ch, 0,
			victim, TO_CHAR);
		act("$n tenta di frantumare la tua mente, ma tu resisti!", FALSE, ch, 0,
			victim, TO_VICT);
		if(!victim->specials.fighting && victim != ch) {
			hit(victim, ch, TYPE_UNDEFINED);
		}
		return;
	}

	if(IS_PC(victim)) {
		if(affected_by_spell(victim, SPELL_FEEBLEMIND)) {
			send_to_char("La sua mente e' gia' in subbuglio.\n\r", ch);
			return;
		}

		act("Assali la mente di $N lasciandola in subbuglio!", FALSE, ch, 0,
			victim, TO_CHAR);
		act("$n assala la tua mente: i pensieri si confondono!", FALSE, ch, 0,
			victim, TO_VICT);
		act("$n assala la mente di $N!", FALSE, ch, 0, victim, TO_NOTVICT);

		af.type      = SPELL_FEEBLEMIND;
		af.duration  = 18;
		af.modifier  = -3;
		af.location  = APPLY_INT;
		af.bitvector = 0;
		affect_to_char(victim, &af);

		af.duration  = 18;
		af.modifier  = 35;
		af.location  = APPLY_SPELLFAIL;
		af.bitvector = 0;
		affect_to_char(victim, &af);

		mind_scramble_degrade_skills(victim, level >= 40 ? 2 : 1, 15);
		return;
	}

	if(affected_by_spell(victim, SKILL_MIND_WIPE)) {
		send_to_char("La creatura e' gia' confusa dalla tua precedente assalto.\n\r",
					 ch);
		return;
	}

	dur = MAX(4, (int)level / 4);
	act("Assali la mente di $N confondendone i riflessi!", FALSE, ch, 0, victim,
		TO_CHAR);
	act("$n assala la tua mente: i tuoi pensieri si confondono!", FALSE, ch, 0,
		victim, TO_VICT);
	act("$n assala la mente di $N!", FALSE, ch, 0, victim, TO_NOTVICT);

	af.type      = SKILL_MIND_WIPE;
	af.duration  = dur;
	af.bitvector = 0;

	af.location  = APPLY_HITROLL;
	af.modifier  = -MAX(2, (int)level / 4);
	affect_to_char(victim, &af);

	af.location  = APPLY_DAMROLL;
	af.modifier  = -MAX(2, (int)level / 5);
	affect_to_char(victim, &af);

	af.location  = APPLY_AC;
	af.modifier  = MAX(2, (int)level / 3);
	affect_to_char(victim, &af);

	if(IS_CASTER_N(victim)) {
		af.location  = APPLY_SPELLFAIL;
		af.modifier  = 40;
		affect_to_char(victim, &af);
	}
}


/* psi protective skill, immune to some psi skills */
void mind_tower_iron_will(byte level, struct char_data* ch,
						  struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_TOWER_IRON_WILL)) {
		if(ch != victim) {
			act("",FALSE,ch,0,victim,TO_CHAR);
			act("",FALSE,ch,0,victim,TO_ROOM);
		}
		else {
			act("$n appare assort$b in meditazione.", TRUE, victim, 0, 0, TO_ROOM);
			act("Alzi una torre di metallo psichico intorno a te!", TRUE, victim,
				0, 0, TO_CHAR);
		}

		af.type      = SKILL_TOWER_IRON_WILL;
		af.duration  = (int)level/10;
		af.modifier  = 0;
		af.location  = APPLY_NONE;
		af.bitvector = 0;
		affect_to_char(victim, &af);
	}
	else {
		if(ch != victim) {
			act("$N e' gia' protett$B.",FALSE,ch,0,victim,TO_CHAR);
		}
		else {
			act("Sei gia' protett$b.",FALSE,ch,0,victim,TO_CHAR);
		}
	}
}

/* psi protective skill, immune to feeblemind, etc... */
void mind_mindblank(byte level, struct char_data* ch,
					struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	if(!affected_by_spell(victim, SKILL_MINDBLANK)) {
		if(ch != victim) {
			act("",FALSE,ch,0,victim,TO_CHAR);
			act("",FALSE,ch,0,victim,TO_ROOM);
		}
		else {
			act("$n appare assort$b in meditazione.", TRUE, victim, 0, 0, TO_ROOM);
			act("Mischi i tuoi pensieri svuotando apparentemente la tua mente.",
				TRUE, victim, 0, 0, TO_CHAR);
		}

		af.type      = SKILL_MINDBLANK;
		af.duration  = static_cast<int>(level) / 5;
		af.modifier  = 0;
		af.location  = APPLY_NONE;
		af.bitvector = 0;
		affect_to_char(victim, &af);
	}
	else {
		if(ch != victim) {
			act("$N e' gia' protett$B.", FALSE, ch, NULL, victim, TO_CHAR);
		}
		else {
			act("Sei gia' protett$b.", FALSE, ch, NULL, victim, TO_CHAR);
		}
	}

}

/* same as thief disguise */
void mind_psychic_impersonation(byte level, struct char_data* ch,
								struct char_data* victim,
								struct obj_data* obj) {
	struct affected_type af;
	struct char_data* k;

	if(affected_by_spell(victim, SKILL_PSYCHIC_IMPERSONATION)) {
		send_to_char("Gia' stai provando a impersonare qualcun altro.\n\r",
					 victim);
		return;
	}

	act("Modifichi i tuoi lineamenti con la sola concentrazione.", FALSE, ch,
		NULL, victim, TO_VICT);
	act("Il lineamenti di $N cambiano sotto i tuoi occhi!", TRUE, ch, NULL,
		victim, TO_NOTVICT);

	for(k = character_list; k; k = k->next) {
		if(k->specials.hunting == victim) {
			k->specials.hunting = NULL;
		}
		if(Hates(k, victim)) {
			RemHated(k, victim);
		}
		if(Fears(k, victim)) {
			RemFeared(k, victim);
		}
	} /* end for */

	af.type = SKILL_PSYCHIC_IMPERSONATION;
	af.duration = static_cast<int>(level) / 5;
	af.modifier = 0;
	af.location = APPLY_NONE;
	af.bitvector = 0;
	affect_to_char(victim, &af);

}




/* area effect psionic blast type skill */
void mind_ultra_blast(byte level, struct char_data* ch,
					  struct char_data* victim, struct obj_data* obj) {
	int dam;
	int tdam;
	struct char_data* tmp_victim;
	struct char_data* temp;
	struct affected_type af;

	assert(ch);
	assert((level >= 1) && (level <= ABS_MAX_LVL));
	(void)victim;
	(void)obj;

	dam = dice(level, 6);
	dam += level * 2;

	act("Generi una spaventosa ondata di energia psionica!", FALSE,
		ch, 0, 0, TO_CHAR);
	act("$n genera una spaventosa ondata di energia psionica!", FALSE,
		ch, 0, 0, TO_ROOM);

	for(tmp_victim = character_list; tmp_victim; tmp_victim = temp) {
		temp = tmp_victim->next;
		bool saved;

		if(ch->in_room != tmp_victim->in_room || !psi_ultra_blast_target(ch, tmp_victim)) {
			continue;
		}

		saved = saves_spell(tmp_victim, SAVING_SPELL) != 0;
		tdam = dam;
		if(saved) {
			tdam >>= 1;
		}
		if(affected_by_spell(tmp_victim, SKILL_TOWER_IRON_WILL)) {
			tdam >>= 1;
		}
		if(tdam <= 0) {
			act("Resisti alla psionica onda d'urto!", FALSE, ch, 0, tmp_victim,
				TO_VICT);
			continue;
		}

		MissileDamage(ch, tmp_victim, tdam, SKILL_ULTRA_BLAST, 5);

		if(!saved) {
			af.type      = SKILL_ULTRA_BLAST;
			af.duration  = 2;
			af.modifier  = -2;
			af.location  = APPLY_HITROLL;
			af.bitvector = 0;
			affect_join(tmp_victim, &af, FALSE, FALSE);
		}
	}
}

/* massive single person attack */
void mind_psychic_crush(byte level, struct char_data* ch,
						struct char_data* victim, struct obj_data* obj) {
	int dam;

	assert(victim && ch);
	assert((level >= 1) && (level <= ABS_MAX_LVL));

	/* damage = level d6, +1 for every two levels of the psionist */

	dam = dice(level,6);
	dam +=(int)level/2;

	if(saves_spell(victim, SAVING_SPELL)) {
		dam >>= 1;
		if(affected_by_spell(victim,SKILL_TOWER_IRON_WILL)) {
			dam =0;
		}
	}

	/* half dam if tower up */
	if(affected_by_spell(victim,SKILL_TOWER_IRON_WILL)) {
		dam >>=1;
	}

	MissileDamage(ch, victim, dam, SKILL_PSYCHIC_CRUSH, 5);
}


/* increate int,wis or con, reduce the unselected attribs the same */

void mind_intensify(byte level, struct char_data* ch,
					struct char_data* victim, struct obj_data* obj) {
    
    send_to_char("Work in progress :-)", ch);
    return;
}


/* same as cleric COMMAND spell */
void mind_domination(byte level, struct char_data* ch,
					 struct char_data* victim, struct obj_data* obj)

{
    send_to_char("Work in progress :-)", ch);
    return;
}

void mind_ego_whip(byte level, struct char_data* ch,
				   struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;
	int dam;

	(void)obj;
	if(!ch || !victim) {
		return;
	}

	dam = dice(level, 5);
	if(saves_spell(victim, SAVING_SPELL)) {
		dam >>= 1;
	}
	MissileDamage(ch, victim, dam, SKILL_EGO_WHIP, 5);

	if(!saves_spell(victim, SAVING_SPELL)) {
		af.type      = SKILL_EGO_WHIP;
		af.duration  = MAX(3, (int)level / 8);
		af.modifier  = -2;
		af.location  = APPLY_INT;
		af.bitvector = 0;
		affect_join(victim, &af, FALSE, FALSE);
		act("$N barcolla sotto il colpo del tuo frustino psichico!", FALSE, ch, 0,
			victim, TO_CHAR);
	}
}

void mind_psychic_vampirism(byte level, struct char_data* ch,
							struct char_data* victim, struct obj_data* obj) {
	int drain;

	(void)obj;
	if(!ch || !victim) {
		return;
	}

	if(IS_PC(victim) && !IS_NPC(victim)) {
		send_to_char("Non puoi prosciugare cosi' un altro giocatore.\n\r", ch);
		return;
	}

	drain = MIN(GET_MANA(victim), MAX(10, (int)level * 3));
	if(saves_spell(victim, SAVING_SPELL)) {
		drain >>= 1;
	}
	if(drain <= 0) {
		act("$N resiste al tuo assalto vampirico.", FALSE, ch, 0, victim, TO_CHAR);
		return;
	}

	GET_MANA(victim) = MAX(0, GET_MANA(victim) - drain);
	GET_MANA(ch) = MIN(GET_MAX_MANA(ch), GET_MANA(ch) + drain / 2);
	act("Prosciugbi l'energia mentale di $N!", FALSE, ch, 0, victim, TO_CHAR);
	act("$n prosciuga la tua energia mentale!", FALSE, ch, 0, victim, TO_VICT);
	MissileDamage(ch, victim, MAX(1, drain / 4), SKILL_PSYCHIC_VAMPIRISM, 5);
}

void mind_metapsionic_surge(byte level, struct char_data* ch,
							struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	(void)obj;
	if(!ch) {
		return;
	}
	if(!victim) {
		victim = ch;
	}

	if(affected_by_spell(victim, SKILL_METAPSIONIC_SURGE)) {
		send_to_char("Sei gia' in stato di surge metapsionico.\n\r", ch);
		return;
	}

	af.type      = SKILL_METAPSIONIC_SURGE;
	af.duration  = MAX(4, (int)level / 4);
	af.modifier  = MAX(2, (int)level / 10);
	af.location  = APPLY_HITROLL;
	af.bitvector = 0;
	affect_to_char(victim, &af);

	af.location  = APPLY_DAMROLL;
	affect_to_char(victim, &af);

	act("Un'ondata di potere metapsionico ti pervade!", FALSE, ch, 0, victim,
		TO_VICT);
	act("$n e' avvolt$B da un'ondata di potere metapsionico!", FALSE, ch, 0,
		victim, TO_NOTVICT);
}

void mind_thought_barrier(byte level, struct char_data* ch,
						  struct char_data* victim, struct obj_data* obj) {
	struct affected_type af;

	(void)obj;
	if(!ch) {
		return;
	}
	if(!victim) {
		victim = ch;
	}

	if(affected_by_spell(victim, SKILL_THOUGHT_BARRIER)) {
		send_to_char("La tua barriera mentale e' gia' attiva.\n\r", ch);
		return;
	}

	af.type      = SKILL_THOUGHT_BARRIER;
	af.duration  = MAX(5, (int)level / 3);
	af.modifier  = -MAX(10, (int)level / 2);
	af.location  = APPLY_AC;
	af.bitvector = 0;
	affect_to_char(victim, &af);

	act("Intrecci una barriera di pensieri intorno a te.", FALSE, ch, 0, victim,
		TO_VICT);
	act("$n e' circondat$B da una barriera di pensieri.", FALSE, ch, 0, victim,
		TO_NOTVICT);
}

void mind_neural_spike(byte level, struct char_data* ch,
					   struct char_data* victim, struct obj_data* obj) {
	int dam;

	(void)obj;
	if(!ch || !victim) {
		return;
	}

	dam = dice(level, 8) + level;
	if(saves_spell(victim, SAVING_SPELL)) {
		dam >>= 1;
		if(affected_by_spell(victim, SKILL_TOWER_IRON_WILL)) {
			dam = 0;
		}
	}
	if(affected_by_spell(victim, SKILL_TOWER_IRON_WILL)) {
		dam >>= 1;
	}
	MissileDamage(ch, victim, dam, SKILL_NEURAL_SPIKE, 5);
}

void mind_mass_confusion(byte level, struct char_data* ch,
						 struct char_data* victim, struct obj_data* obj) {
	struct char_data* tmp;
	struct affected_type af;
	int dur;

	(void)victim;
	(void)obj;
	if(!ch) {
		return;
	}

	dur = MAX(3, (int)level / 6);
	act("Scateni un turbine di impulsi confusi nella stanza!", FALSE, ch, 0, 0,
		TO_CHAR);
	act("$n scatena un turbine di impulsi psichici confusi!", FALSE, ch, 0, 0,
		TO_ROOM);

	for(tmp = real_roomp(ch->in_room)->people; tmp; tmp = tmp->next_in_room) {
		if(tmp == ch || IS_IMMORTAL(tmp) || in_group(ch, tmp)) {
			continue;
		}
		if(IS_PC(tmp)) {
			continue;
		}
		if(saves_spell(tmp, SAVING_SPELL)) {
			continue;
		}

		af.type      = SKILL_MASS_CONFUSION;
		af.duration  = dur;
		af.bitvector = 0;

		af.location  = APPLY_HITROLL;
		af.modifier  = -MAX(2, (int)level / 6);
		affect_join(tmp, &af, FALSE, FALSE);

		af.location  = APPLY_DAMROLL;
		af.modifier  = -MAX(2, (int)level / 8);
		affect_join(tmp, &af, FALSE, FALSE);

		af.location  = APPLY_AC;
		af.modifier  = MAX(2, (int)level / 4);
		affect_join(tmp, &af, FALSE, FALSE);
	}
}

void mind_cataclysm_mind(byte level, struct char_data* ch,
						 struct char_data* victim, struct obj_data* obj) {
	int dam;
	int tdam;
	struct char_data* tmp_victim;
	struct char_data* temp;
	struct affected_type af;

	(void)victim;
	(void)obj;
	if(!ch) {
		return;
	}

	dam = dice(level, 8) + level * 3;

	act("Concentri ogni fibra della mente in un cataclisma psionico!", FALSE, ch,
		0, 0, TO_CHAR);
	act("$n scatena un cataclisma di pura energia mentale!", FALSE, ch, 0, 0,
		TO_ROOM);

	for(tmp_victim = character_list; tmp_victim; tmp_victim = temp) {
		bool saved;

		temp = tmp_victim->next;
		if(ch->in_room != tmp_victim->in_room ||
				!psi_ultra_blast_target(ch, tmp_victim)) {
			continue;
		}

		saved = saves_spell(tmp_victim, SAVING_SPELL) != 0;
		tdam = dam;
		if(saved) {
			tdam >>= 1;
		}
		if(affected_by_spell(tmp_victim, SKILL_TOWER_IRON_WILL)) {
			tdam >>= 1;
		}
		if(tdam <= 0) {
			continue;
		}

		MissileDamage(ch, tmp_victim, tdam, SKILL_CATACLYSM_MIND, 5);

		if(!saved && IS_NPC(tmp_victim)) {
			af.type      = SKILL_CATACLYSM_MIND;
			af.duration  = 2;
			af.modifier  = -3;
			af.location  = APPLY_HITROLL;
			af.bitvector = 0;
			affect_join(tmp_victim, &af, FALSE, FALSE);
		}
	}
}

} // namespace Alarmud

