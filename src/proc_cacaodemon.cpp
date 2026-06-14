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

float calc_world_eq_index() {
    float total_eq = 0.0f;
    int pc_count = 0;

    for (struct char_data* i = character_list; i != nullptr; i = i->next) {
        if (!IS_NPC(i) && GetCharBonusIndex(i) > 0) {
            total_eq += GetCharBonusIndex(i);
            pc_count++;
        }
    }

    if (pc_count == 0) {
        return 1.0f;
    }
    return total_eq / static_cast<float>(pc_count);
}

struct DemonStrings {
    const char* keywords;
    const char* short_desc;
    const char* long_desc;
    const char* detailed_desc;
};

DemonStrings generate_good_strings(int magnitude) {
    if (magnitude <= 2) {
        return { "spirito celeste guardiano", "uno Spirito Celeste", "Uno Spirito Celeste armato di lancia di luce fluttua qui.\n\r", "Una figura radiosa di pura energia positiva, evocata per proteggere." };
    } else if (magnitude <= 4) {
        return { "arconte giustizia", "un Arconte della Giustizia", "Un possente Arconte della Giustizia scruta l'orizzonte.\n\r", "Le sue ali di luce solida illuminano l'oscurita'. Emana un'aura rassicurante." };
    } else {
        return { "avatar dominus luce", "l'Avatar della Luce", "Un Avatar della Luce Assoluta si erge maestoso, pronto al giudizio.\n\r", "L'incarnazione della purezza. Non ha volto, solo un bagliore accecante che brucia le ombre." };
    }
}

DemonStrings generate_neutral_strings(int magnitude) {
    if (magnitude <= 2) {
        return { "costrutto pietra runica", "un Costrutto di Pietra Runica", "Un Costrutto di Pietra Runica attende ordini immobile.\n\r", "Animato dalla magia grigia dell'equilibrio, non prova emozioni ne' stanchezza." };
    } else if (magnitude <= 4) {
        return { "golem ferro astrale", "un Golem di Ferro Astrale", "Un colossale Golem di Ferro Astrale fa tremare il suolo ad ogni passo.\n\r", "Le articolazioni di questo titano metallico brillano di energia cosmica neutrale." };
    } else {
        return { "spirito equilibrio primordiale", "uno Spirito dell'Equilibrio", "Uno Spirito Primordiale dell'Equilibrio fonde in se' gravita' e vuoto.\n\r", "Una tempesta di forza cinetica controllata. La sua semplice presenza distorce lo spazio attorno." };
    }
}

DemonStrings generate_evil_strings(int magnitude) {
    if (magnitude <= 2) {
        return { "orrore ceneri demone", "un Orrore delle Ceneri", "Un Orrore formato da ceneri e sussurri striscia sul pavimento.\n\r", "Dita adunche e vuoti dove dovrebbero esserci gli occhi. Odora di carne bruciata." };
    } else if (magnitude <= 4) {
        return { "mietitore abisso demone", "un Mietitore dell'Abisso", "Un Mietitore dell'Abisso fluttua brandendo una falce di fiamme nere.\n\r", "Il vero volto della morte. Catene spettrali avvolgono il suo mantello lacero." };
    } else {
        return { "signore corruzione cacaodemon", "il Signore della Corruzione", "Il Signore della Corruzione piega la realta' con la sua empia presenza.\n\r", "Un Cacaodemon di magnitudo suprema. Sette occhi iniettati di sangue ti fissano promettendo agonia." };
    }
}

int cacaodemon_magnitude_from_vnum(int vnum) {
    if (vnum >= 20 && vnum <= 25) {
        return vnum - 19;
    }
    return 1;
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

    float world_eq_avg = calc_world_eq_index();
    float eq_factor = std::max(1.0f, world_eq_avg / 100.0f);
    float power_index = (spell_level * magnitude) * eq_factor;

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

    mudlog(LOG_CHECK, "proc_cacaodemon: Modificata creatura liv %d, Mag %d, HP %d per %s (PI %.2f)",
           final_level, magnitude, demon->points.max_hit, GET_NAME(caster), power_index);
}

} // namespace Alarmud
