/*ALARMUD* (Do not remove *ALARMUD*, used to automagically manage these lines
 *ALARMUD* AlarMUD 2.0
 *ALARMUD* See COPYING for licence information
 *ALARMUD*/
#include "config.hpp"
#include "typedefs.hpp"
#include "flags.hpp"
#include "autoenums.hpp"
#include "structs.hpp"
#include "logging.hpp"
#include "constants.hpp"
#include "utils.hpp"
#include "db.hpp"
#include "handler.hpp"
#include "comm.hpp"
#include "spells.hpp"
#include "magic.hpp"
#include "fight.hpp"
#include "handler.hpp"
#include "interpreter.hpp"
#include "multiclass.hpp"
#include "power_index.hpp"
#include "snew.hpp"
#include "act.comm.hpp"
#include "proc_cacaodemon.hpp"
#include <cstdio>
#include <cstring>
#include <string>
#include <algorithm>

namespace Alarmud {

extern struct char_data *character_list;
extern struct index_data *mob_index;

namespace {

struct DemonStrings {
    const char* keywords;
    const char* short_desc;
    const char* long_desc;
    const char* detailed_desc;
};

DemonStrings pick_random_variant(const DemonStrings* pool, int count) {
    if (!pool || count <= 0) {
        return { "creatura evocata", "una Creatura Evocata",
                 "Una creatura evocata attende ordini.\n\r",
                 "Generata dal rituale del cacaodemon." };
    }
    return pool[number(0, count - 1)];
}

// Buono, magnitudine 1-2
static const DemonStrings kGoodLow[] = {
    { "spirito celeste guardiano", "uno Spirito Celeste",
      "Uno Spirito Celeste armato di lancia di luce fluttua qui.\n\r",
      "Una figura radiosa di pura energia positiva, evocata per proteggere." },
    { "sentinella alba sacra", "una Sentinella dell'Alba",
      "Una Sentinella dell'Alba veglia immobile, circondata da un alone dorato.\n\r",
      "Le sue braccia sembrano fatte di luce solida; ogni passo lascia scintille benigne." },
    { "guerriero luce minore", "un Guerriero di Luce",
      "Un giovane Guerriero di Luce compare dal fumo, pronto a servire.\n\r",
      "Non parla: comunica con sguardi limpidi e gesti precisi, come un soldato celeste." },
    { "angelo custode frammento", "un Frammento di Angelo Custode",
      "Un Frammento di Angelo Custode ruota lentamente nell'aria.\n\r",
      "Emana calore e profumo d'incenso; sembra un pezzo di un coro piu' vasto." },
};

// Buono, magnitudine 3-4
static const DemonStrings kGoodMid[] = {
    { "arconte giustizia", "un Arconte della Giustizia",
      "Un possente Arconte della Giustizia scruta l'orizzonte.\n\r",
      "Le sue ali di luce solida illuminano l'oscurita'. Emana un'aura rassicurante." },
    { "paladino astrale evocato", "un Paladino Astrale",
      "Un Paladino Astrale avanza con passo misurato, scudo e spada di luce.\n\r",
      "La sua armatura e' incisa con rune che pulsano a ritmo di preghiera." },
    { "serafino guerriero", "un Serafino Guerriero",
      "Un Serafino Guerriero fluttua brandendo una spada di fuoco bianco.\n\r",
      "Tre paia d'ali lo sostengono; la sua voce risuona come campane lontane." },
    { "campione solare", "un Campione Solare",
      "Un Campione Solare si erge dal fumo, corona di raggi intorno al volto.\n\r",
      "Dove guarda, le ombre indietreggiano; e' chiaro che e' stato chiamato per punire il male." },
};

// Buono, magnitudine 5-6
static const DemonStrings kGoodHigh[] = {
    { "avatar dominus luce", "l'Avatar della Luce",
      "Un Avatar della Luce Assoluta si erge maestoso, pronto al giudizio.\n\r",
      "L'incarnazione della purezza. Non ha volto, solo un bagliore accecante che brucia le ombre." },
    { "manifestazione sol invictus", "la Manifestazione del Sole Invictus",
      "La Manifestazione del Sole Invictus riempie la stanza di luce pura.\n\r",
      "Ogni fibra del suo corpo e' un raggio concentrato; la sola presenza purifica l'aria." },
    { "giudice celeste supremo", "il Giudice Celeste",
      "Il Giudice Celeste materializza una bilancia di luce e una spada di cristallo.\n\r",
      "Non chiede pieta': pesa le anime con sguardo imperturbabile." },
    { "dominus aurora", "il Dominus dell'Aurora",
      "Il Dominus dell'Aurora dissolve il fumo nero in una brezza profumata.\n\r",
      "Sembra nato dal confine tra sogno e giorno; la sua voce e' un coro di mille preghiere." },
};

// Neutro, magnitudine 1-2
static const DemonStrings kNeutralLow[] = {
    { "costrutto pietra runica", "un Costrutto di Pietra Runica",
      "Un Costrutto di Pietra Runica attende ordini immobile.\n\r",
      "Animato dalla magia grigia dell'equilibrio, non prova emozioni ne' stanchezza." },
    { "golem argilla sigillata", "un Golem d'Argilla Sigillata",
      "Un Golem d'Argilla Sigillata si alza dal pavimento, rune ancora umide.\n\r",
      "Le sue giunture scricchiolano appena; obbedisce con precisione meccanica." },
    { "servitore bronzo antico", "un Servitore di Bronzo",
      "Un Servitore di Bronzo verdeggiante attende con mani incrociate.\n\r",
      "I suoi occhi sono due gemme opache; e' stato forgiato per durare secoli." },
    { "automaton cristallo opaco", "un Automaton di Cristallo",
      "Un Automaton di Cristallo opaco fluttua a mezz'aria, immobile.\n\r",
      "All'interno del torso si vedono ingranaggi magici che girano senza rumore." },
};

// Neutro, magnitudine 3-4
static const DemonStrings kNeutralMid[] = {
    { "golem ferro astrale", "un Golem di Ferro Astrale",
      "Un colossale Golem di Ferro Astrale fa tremare il suolo ad ogni passo.\n\r",
      "Le articolazioni di questo titano metallico brillano di energia cosmica neutrale." },
    { "colosso runico errante", "un Colosso Runico",
      "Un Colosso Runico emerge dal fumo, piastre di metallo incise a spirale.\n\r",
      "Ogni runa pulsa con lo stesso ritmo del battito del suo evocatore." },
    { "guardiano marmo vivente", "un Guardiano di Marmo",
      "Un Guardiano di Marmo vivente blocca l'accesso con un muro di spalle.\n\r",
      "La pietra e' fredda al tatto ma calda di mana contenuta." },
    { "titano equilibrio", "un Titano dell'Equilibrio",
      "Un Titano dell'Equilibrio si materializza, alto quanto un portone.\n\r",
      "Non distingue amici e nemici finche' non riceve ordini precisi." },
};

// Neutro, magnitudine 5-6
static const DemonStrings kNeutralHigh[] = {
    { "spirito equilibrio primordiale", "uno Spirito dell'Equilibrio",
      "Uno Spirito Primordiale dell'Equilibrio fonde in se' gravita' e vuoto.\n\r",
      "Una tempesta di forza cinetica controllata. La sua semplice presenza distorce lo spazio attorno." },
    { "entita ordine assoluto", "un'Entita' dell'Ordine",
      "Un'Entita' dell'Ordine Assoluto flutua come un eclissi immobile.\n\r",
      "Attorno a lei il tempo sembra scorrere piu' lento; e' la personificazione della neutralita'." },
    { "constructo cosmos", "un Constructo del Cosmos",
      "Un Constructo del Cosmos e' composto da anelli di luce e ombra intrecciati.\n\r",
      "Ogni movimento e' calcolato al millimetro; e' una macchina cosmica di guerra." },
    { "sentinella vuoto grigio", "la Sentinella del Vuoto Grigio",
      "La Sentinella del Vuoto Grigio piega leggermente la luce attorno a se'.\n\r",
      "Non ha volto ne' voce: esiste solo per ristabilire l'equilibrio spezzato." },
};

// Malvagio, magnitudine 1-2
static const DemonStrings kEvilLow[] = {
    { "orrore ceneri demone", "un Orrore delle Ceneri",
      "Un Orrore formato da ceneri e sussurri striscia sul pavimento.\n\r",
      "Dita adunche e vuoti dove dovrebbero esserci gli occhi. Odora di carne bruciata." },
    { "larva abisso viscida", "una Larva dell'Abisso",
      "Una Larva dell'Abisso si strappa fuori dal fumo con un verso viscoso.\n\r",
      "La pelle luccica di ichor nero; lascia una scia che brucia le pietre." },
    { "imp corruzione", "un Imp della Corruzione",
      "Un Imp della Corruzione sghignazza, artigli pronti a graffiare.\n\r",
      "Piccolo ma vorace: i suoi occhi rossi non battono mai le palpebre." },
    { "ombra famelica", "un'Ombra Famelica",
      "Un'Ombra Famelica si stacca dal fumo e si arrampica sulle pareti.\n\r",
      "Assorbe luce e calore; sussurra insulti in lingue dimenticate." },
};

// Malvagio, magnitudine 3-4
static const DemonStrings kEvilMid[] = {
    { "mietitore abisso demone", "un Mietitore dell'Abisso",
      "Un Mietitore dell'Abisso fluttua brandendo una falce di fiamme nere.\n\r",
      "Il vero volto della morte. Catene spettrali avvolgono il suo mantello lacero." },
    { "carnefice infernale", "un Carnefice Infernale",
      "Un Carnefice Infernale trascina catene che sferragliano da sole.\n\r",
      "La maschera di ferro e' macchiata di sangue secco; ride senza gioia." },
    { "demone scaglie nere", "un Demone dalle Scaglie Nere",
      "Un Demone dalle Scaglie Nere sbuca dal fumo sbuffando zolfo.\n\r",
      "Le corna sono spezzate ma ancora letali; ogni passo lascia impronte bruciacchiate." },
    { "predatore notte profonda", "un Predatore della Notte Profonda",
      "Un Predatore della Notte Profonda si avvolge in ali oleose.\n\r",
      "I suoi artigli gocciolano veleno; attende solo un cenno per scattare." },
};

// Malvagio, magnitudine 5-6
static const DemonStrings kEvilHigh[] = {
    { "signore corruzione cacaodemon", "il Signore della Corruzione",
      "Il Signore della Corruzione piega la realta' con la sua empia presenza.\n\r",
      "Un Cacaodemon di magnitudo suprema. Sette occhi iniettati di sangue ti fissano promettendo agonia." },
    { "principe fiamme nere", "il Principe delle Fiamme Nere",
      "Il Principe delle Fiamme Nere incendia l'aria senza calore, solo dolore.\n\r",
      "La sua corona e' fatta di ossa fuse; parla con voce di terremoto lontano." },
    { "arconte abisso antico", "l'Arconte dell'Abisso Antico",
      "L'Arconte dell'Abisso Antico dissolve il fumo in urla soffocate.\n\r",
      "Porta segni di battaglie cosmiche; ogni cicatrice pulsa di odio concentrato." },
    { "cacaodemon primordiale", "un Cacaodemon Primordiale",
      "Un Cacaodemon Primordiale emerge distorto, troppo grande per lo spazio.\n\r",
      "La realta' scricchiola attorno a lui; e' la forma che il patto richiama quando niente altro basta." },
};

DemonStrings generate_good_strings(int magnitude) {
    if (magnitude <= 2) {
        return pick_random_variant(kGoodLow, sizeof(kGoodLow) / sizeof(kGoodLow[0]));
    }
    if (magnitude <= 4) {
        return pick_random_variant(kGoodMid, sizeof(kGoodMid) / sizeof(kGoodMid[0]));
    }
    return pick_random_variant(kGoodHigh, sizeof(kGoodHigh) / sizeof(kGoodHigh[0]));
}

DemonStrings generate_neutral_strings(int magnitude) {
    if (magnitude <= 2) {
        return pick_random_variant(kNeutralLow, sizeof(kNeutralLow) / sizeof(kNeutralLow[0]));
    }
    if (magnitude <= 4) {
        return pick_random_variant(kNeutralMid, sizeof(kNeutralMid) / sizeof(kNeutralMid[0]));
    }
    return pick_random_variant(kNeutralHigh, sizeof(kNeutralHigh) / sizeof(kNeutralHigh[0]));
}

DemonStrings generate_evil_strings(int magnitude) {
    if (magnitude <= 2) {
        return pick_random_variant(kEvilLow, sizeof(kEvilLow) / sizeof(kEvilLow[0]));
    }
    if (magnitude <= 4) {
        return pick_random_variant(kEvilMid, sizeof(kEvilMid) / sizeof(kEvilMid[0]));
    }
    return pick_random_variant(kEvilHigh, sizeof(kEvilHigh) / sizeof(kEvilHigh[0]));
}

bool cacaodemon_good_tick(struct char_data* demon) {
    struct char_data* master = demon->master;
    if (!master || master->in_room != demon->in_room) {
        return false;
    }

    int chance = number(1, 100);
    if (chance > 80) {
        if (GET_HIT(master) < (GET_MAX_HIT(master) / 2)) {
            act("$n irradia una luce dorata che avvolge $N!", FALSE, demon, nullptr, master, TO_NOTVICT);
            act("$n ti tocca e le tue ferite si rimarginano!", FALSE, demon, nullptr, master, TO_VICT);
            GET_HIT(master) = std::min(GET_MAX_HIT(master), GET_HIT(master) + dice(4, 10) + GetMaxLevel(demon));
            update_pos(master);
            return true;
        } else if (!IS_AFFECTED(master, AFF_SANCTUARY) && chance > 90) {
            act("$n intona un canto celestiale per proteggere $N.", FALSE, demon, nullptr, master, TO_NOTVICT);
            send_to_char("Senti un'aura sacra che ti protegge!\n\r", master);
            master->points.armor -= 20;
            return true;
        }
    }
    return false;
}

bool cacaodemon_neutral_tick(struct char_data* demon) {
    if (number(1, 100) > 85) {
        act("\n\r$n solleva i pugni massicci e li schianta al suolo con forza devastante!", FALSE, demon, nullptr, nullptr, TO_ROOM);
        send_to_room("L'onda d'urto del COLPO SISMICO vi travolge!\n\r", demon->in_room);

        struct char_data* next_vict = nullptr;
        for (struct char_data* vict = real_roomp(demon->in_room)->people; vict; vict = next_vict) {
            next_vict = vict->next_in_room;
            if (vict != demon && vict != demon->master && !is_same_group(vict, demon)) {
                int damage_amount = dice(GetMaxLevel(demon) / 2, 8);
                damage(demon, vict, damage_amount, TYPE_BLAST, 5);
            }
        }
        return true;
    }
    return false;
}

bool cacaodemon_evil_tick(struct char_data* demon) {
    struct char_data* victim = demon->specials.fighting;
    if (!victim) {
        return false;
    }

    int chance = number(1, 100);
    if (chance > 85) {
        act("$n affonda gli artigli d'ombra nel petto di $N!", FALSE, demon, nullptr, victim, TO_NOTVICT);
        act("$n ti strappa l'energia vitale!", FALSE, demon, nullptr, victim, TO_VICT);

        int drain = dice(4, 12) + (GetMaxLevel(demon) / 2);
        damage(demon, victim, drain, TYPE_UNDEFINED, 5);
        GET_HIT(demon) = std::min(GET_MAX_HIT(demon), GET_HIT(demon) + drain);
        return true;
    } else if (chance > 75 && !IS_AFFECTED(victim, AFF_POISON)) {
        act("$n sputa un ichore nero e corrosivo su $N!", FALSE, demon, nullptr, victim, TO_NOTVICT);
        act("Il veleno demoniaco ti entra in circolo!", FALSE, demon, nullptr, victim, TO_VICT);

        struct affected_type af;
        af.type = SPELL_POISON;
        af.duration = 2;
        af.modifier = -2;
        af.location = APPLY_STR;
        af.bitvector = AFF_POISON;
        affect_join(victim, &af, FALSE, FALSE);
        return true;
    }
    return false;
}

} // namespace anonimo

int cacaodemon_magnitude_from_vnum(int vnum) {
	if(vnum >= 20 && vnum <= 25) {
		return vnum - 19;
	}
	return 1;
}

MOBSPECIAL_FUNC(spec_cacaodemon) {
    if (cmd) {
        return FALSE;
    }

    struct char_data* demon = mob;
    if (!demon || !demon->specials.fighting) {
        return FALSE;
    }

    int align = GET_ALIGNMENT(demon);
    if (align >= 350) {
        return cacaodemon_good_tick(demon) ? TRUE : FALSE;
    }
    if (align <= -350) {
        return cacaodemon_evil_tick(demon) ? TRUE : FALSE;
    }
    return cacaodemon_neutral_tick(demon) ? TRUE : FALSE;
}

void proc_modify_cacaodemon(struct char_data* caster, struct char_data* demon, int spell_level) {
    if (!demon || !caster) {
        return;
    }

    int magnitude = cacaodemon_magnitude_from_vnum(GET_MOB_VNUM(demon));
    magnitude = std::clamp(magnitude, 1, 6);

    const PowerIndexWorldEq world_eq = power_index_world_snapshot();
    const float power_index =
        compute_power_index(spell_level, magnitude, &world_eq);

    int align = GET_ALIGNMENT(caster);
    DemonStrings strings;

    if (align >= 350) {
        strings = generate_good_strings(magnitude);
        GET_ALIGNMENT(demon) = 1000;
    } else if (align <= -350) {
        strings = generate_evil_strings(magnitude);
        GET_ALIGNMENT(demon) = -1000;
    } else {
        strings = generate_neutral_strings(magnitude);
        GET_ALIGNMENT(demon) = 0;
    }

    if (demon->player.name) {
        free(demon->player.name);
    }
    if (demon->player.short_descr) {
        free(demon->player.short_descr);
    }
    if (demon->player.long_descr) {
        free(demon->player.long_descr);
    }
    if (demon->player.description) {
        free(demon->player.description);
    }

    demon->player.name = strdup(strings.keywords);
    demon->player.short_descr = strdup(strings.short_desc);
    demon->player.long_descr = strdup(strings.long_desc);
    demon->player.description = strdup(strings.detailed_desc);

    int final_level = std::clamp(spell_level + (magnitude * 2), 1, 60);
    GET_LEVEL(demon, WARRIOR_LEVEL_IND) = final_level;

    int base_hp = (final_level * 15) + (magnitude * 50);
    int bonus_hp = static_cast<int>(base_hp * (power_index / 500.0f));
    demon->points.max_hit = base_hp + bonus_hp;
    demon->points.hit = demon->points.max_hit;

    demon->points.armor = 10 - (final_level / 2) - (magnitude * 3);

    demon->specials.damnodice = std::max(2, final_level / 10);
    demon->specials.damsizedice = 6 + (magnitude / 2);
    demon->points.damroll = static_cast<sbyte>(magnitude * 2 + static_cast<int>(power_index / 50.0f));
    demon->points.hitroll = static_cast<sbyte>(magnitude * 2 + static_cast<int>(power_index / 50.0f));

    if (magnitude >= 4) {
        SET_BIT(demon->specials.affected_by, AFF_SANCTUARY);
    }
    if (magnitude == 6) {
        SET_BIT(demon->specials.affected_by, AFF_FIRESHIELD);
    }

    mob_index[demon->nr].func = reinterpret_cast<genericspecial_func>(spec_cacaodemon);
    mob_index[demon->nr].specname = "spec_cacaodemon";

    mudlog(LOG_CHECK, "proc_cacaodemon: Modificata creatura liv %d, Mag %d, HP %d, forma '%s' per %s (PI %.2f)",
           final_level, magnitude, demon->points.max_hit, strings.short_desc, GET_NAME(caster), power_index);
}

namespace {

bool cacaodemon_guard_name_matches(const char* assigned, struct char_data* guard) {
	return assigned && guard && GET_NAME(guard) &&
	       !strcasecmp(assigned, GET_NAME(guard));
}

void clear_bodyguard_link(struct char_data* victim, struct char_data* guard) {
	if(!victim || !guard || !victim->specials.bodyguard) {
		return;
	}
	if(!cacaodemon_guard_name_matches(victim->specials.bodyguard, guard)) {
		return;
	}
	free(victim->specials.bodyguard);
	victim->specials.bodyguard = nullptr;
}

void clear_bodyguarding_target(struct char_data* guard, struct char_data* victim) {
	if(!guard || !victim || !guard->specials.bodyguarding) {
		return;
	}
	if(strcasecmp(guard->specials.bodyguarding, GET_NAME(victim))) {
		return;
	}
	free(guard->specials.bodyguarding);
	guard->specials.bodyguarding = nullptr;
}

void detach_old_bodyguard_of_victim(struct char_data* victim) {
	if(!victim || !victim->specials.bodyguard) {
		return;
	}
	struct char_data* old_guard = get_char(victim->specials.bodyguard);
	if(old_guard) {
		clear_bodyguarding_target(old_guard, victim);
	}
	free(victim->specials.bodyguard);
	victim->specials.bodyguard = nullptr;
}

void set_victim_bodyguard(struct char_data* guard, struct char_data* victim) {
	if(!guard || !victim || guard == victim || !GET_NAME(guard)) {
		return;
	}
	detach_old_bodyguard_of_victim(victim);
	victim->specials.bodyguard = strdup(GET_NAME(guard));
}

void set_bodyguard_pair(struct char_data* guard, struct char_data* victim) {
	if(!guard || !victim || guard == victim || !GET_NAME(guard) || !GET_NAME(victim)) {
		return;
	}
	if(guard->specials.bodyguarding) {
		struct char_data* old_victim = get_char(guard->specials.bodyguarding);
		if(old_victim) {
			clear_bodyguard_link(old_victim, guard);
		}
		free(guard->specials.bodyguarding);
		guard->specials.bodyguarding = nullptr;
	}
	set_victim_bodyguard(guard, victim);
	guard->specials.bodyguarding = strdup(GET_NAME(victim));
}

bool cacaodemon_protects_victim(struct char_data* demon, struct char_data* victim) {
	return demon && victim && HAS_BODYGUARD(victim) &&
	       cacaodemon_guard_name_matches(GET_BODYGUARD(victim), demon);
}

int cacaodemon_count_unprotected(struct char_data* demon, struct char_data* master) {
	int missing = 0;
	if(!cacaodemon_protects_victim(demon, master)) {
		missing++;
	}
	if(GetMaxLevel(demon) > 49) {
		return missing;
	}
	for(struct char_data* t = character_list; t != nullptr; t = t->next) {
		if(IS_NPC(t) || t == master || t == demon) {
			continue;
		}
		if(!is_same_group(master, t)) {
			continue;
		}
		if(!cacaodemon_protects_victim(demon, t)) {
			missing++;
		}
	}
	return missing;
}

void cacaodemon_strip_group_bodyguard(struct char_data* demon, struct char_data* master) {
	for(struct char_data* t = character_list; t != nullptr; t = t->next) {
		if(IS_NPC(t) || t == master || t == demon) {
			continue;
		}
		if(!is_same_group(master, t)) {
			continue;
		}
		clear_bodyguard_link(t, demon);
	}
}

} // namespace

bool is_cacaodemon(const struct char_data* mob) {
	if(!mob || !IS_NPC(mob) || mob->nr < 0) {
		return false;
	}
	const char* spec = mob_index[mob->nr].specname;
	return spec && !strcmp(spec, "spec_cacaodemon");
}

void cacaodemon_assign_bodyguard(struct char_data* demon, struct char_data* master) {
	if(!demon || !master || !is_cacaodemon(demon) || !GET_NAME(demon)) {
		return;
	}

	set_bodyguard_pair(demon, master);

	if(GetMaxLevel(demon) > 49) {
		cacaodemon_strip_group_bodyguard(demon, master);
		return;
	}

	for(struct char_data* t = character_list; t != nullptr; t = t->next) {
		if(IS_NPC(t) || t == master || t == demon) {
			continue;
		}
		if(!is_same_group(master, t)) {
			continue;
		}
		set_victim_bodyguard(demon, t);
	}
}

bool cacaodemon_is_vigila_order(const std::string& command) {
	char line[MAX_INPUT_LENGTH];
	char word[MAX_INPUT_LENGTH];
	if(command.empty() || command.size() >= MAX_INPUT_LENGTH) {
		return false;
	}
	std::snprintf(line, sizeof(line), "%s", command.c_str());
	one_argument(line, word);
	if(!*word) {
		return false;
	}
	if(!strcasecmp(word, "vigila") || !strcasecmp(word, "guardia") ||
			!strcasecmp(word, "proteggi")) {
		return true;
	}
	if(!strcasecmp(word, "bodyguard")) {
		one_argument(line, word);
		return !*word;
	}
	return false;
}

bool cacaodemon_order_vigila(struct char_data* master, struct char_data* demon,
		const std::string& command) {
	if(!cacaodemon_is_vigila_order(command)) {
		return false;
	}
	if(!master || !demon || !is_cacaodemon(demon)) {
		return false;
	}
	if(demon->master != master || !IS_AFFECTED(demon, AFF_CHARM)) {
		send_to_char("Non e' un tuo cacaodemon sotto incantesimo.\n\r", master);
		return true;
	}

	const int missing = cacaodemon_count_unprotected(demon, master);
	cacaodemon_assign_bodyguard(demon, master);

	if(missing > 0) {
		act("$n passa in rassegna il gruppo e riprende la guardia del corpo.",
			FALSE, demon, nullptr, master, TO_ROOM);
		act("$N ti fa da guardia del corpo di nuovo.",
			FALSE, demon, nullptr, master, TO_CHAR);
		if(GetMaxLevel(demon) <= 49) {
			send_to_char("Il cacaodemon estende la protezione a tutto il gruppo.\n\r",
				master);
		}
	} else {
		act("$n annuisce: la guardia del corpo e' gia' al suo posto.",
			FALSE, demon, nullptr, master, TO_ROOM);
		if(GetMaxLevel(demon) <= 49) {
			send_to_char(
				"Il cacaodemon e' gia' in guardia su di te e su tutto il gruppo.\n\r",
				master);
		} else {
			send_to_char("Il cacaodemon e' gia' in guardia su di te.\n\r", master);
		}
	}
	return true;
}

} // namespace Alarmud
