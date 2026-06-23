#!/usr/bin/env python3
"""Generate Nebbie Arcane Mudlet package from spell_parser.cpp spells[] table."""

import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPELL_PARSER = ROOT.parent.parent / "src" / "spell_parser.cpp"
OUT_DIR = ROOT / "nebbie-play-all-build"
PACKAGE_NAME = "nebbie-play-all"
INSTALLER_CORE = ROOT / "nebbie-installer-core.lua"

# Never shadow common MUD command prefixes (inventory, equipment, rest, …)
ALWAYS_RESERVED_ABBREVS = {
    "inv", "eq", "i", "in", "rest", "sleep", "kill", "look", "score", "status",
    "get", "drop", "wear", "remove", "open", "close", "quit", "who", "help",
    "tell", "say", "cast", "recall", "read", "mem", "order", "follow", "give",
    "buy", "sell", "list", "save", "hit", "stand", "sit", "inventory", "equipment",
}

# Explicit player-approved abbreviations (may share MUD prefix but must work standalone)
FORCE_STANDALONE_ABBREVS = {"invis", "ea", "ble"}  # ble → cast 'bless' (non bleed/blessing MUD)

# Alias sempre su nome intero spell (oltre alle abbreviazioni)
FAVORITE_SPELL_ALIASES = [
    "aid", "armor", "bless", "shield", "stone skin", "mirror images",
]

# Skill indices in spells[] (not cast via cast/recall/mind)
RESERVED_SKILL_IDS = {45, 46, 47, 48, 49, 50, 51, 52}

# Dedicated command skills (interpreter.cpp) — not cast '...'
DEDICATED_SKILLS = {
    "sneak": ("sneak", ""),
    "hide": ("hide", ""),
    "camouflage": ("camouflage", ""),
    "steal": ("steal", "<oggetto> <vittima>"),
    "backstab": ("backstab", "<vittima>"),
    "pick": ("pick", "<porta/cassa>"),
    "kick": ("kick", "<vittima>"),
    "bash": ("bash", "<vittima>"),
    "rescue": ("rescue", "<persona>"),
    "disarm": ("disarm", "<vittima>"),
    "parry": ("parry", ""),
    "mantra": ("mantra", ""),
    "finger": ("finger", ""),
    "quivering palm": ("quivering palm", "<vittima>"),
    "springleap": ("springleap", ""),
    "feign death": ("feign death", ""),
    "daimoku": ("daimoku", ""),
    "sign language": ("sign", ""),
    "first aid": ("first aid", ""),
    "spy": ("spy", ""),
    "tspy": ("tspy", ""),
    "eavesdrop": ("eavesdrop", ""),
    "disguise": ("disguise", ""),
    "climb": ("climb", "<direzione>"),
    "doorbash": ("doorbash", "<porta>"),
    "swim": ("swim", ""),
    "berserk": ("berserk", ""),
    "tan": ("tan", "<cadavere> <tipo>"),
    "bellow": ("bellow", ""),
    "find food": ("find food", ""),
    "find water": ("find water", ""),
    "find traps": ("find traps", ""),
    "track": ("track", "<nome>"),
    "carve": ("carve", "<cadavere>"),
    "ration": ("carve", "<cadavere>"),
    "brew": ("brew", ""),
    "forge": ("forge", "<arma> <materiale>"),
    "pray": ("pray", ""),
    "warcry": ("warcry", ""),
    "lay on hands": ("lay on hands", "[bersaglio]"),
    "blessing": ("blessing", "<bersaglio>"),
    "heroic rescue": ("heroic", ""),
    "doorway": ("doorway", "<nome>"),
    "psi portal": ("portal", "<nome>"),
    "psi summon": ("summon", "<nome>"),
    "canibalize": ("canibalize", "[numero]"),
    "flame shroud": ("flame", ""),
    "aura sight": ("aura", ""),
    "great sight": ("great", ""),
    "psionic blast": ("blast", "<bersaglio>"),
    "hypnosis": ("hypnotize", "<bersaglio>"),
    "scry": ("scry", "<nome>"),
    "adrenalize": ("adrenalize", "<bersaglio>"),
    "meditate": ("meditate", ""),
    "psi shield": ("shield", ""),
    "esp": ("esp", ""),
    "immolation": ("immolate", ""),
    "bodyguard": ("bodyguard", "<bersaglio>"),
    "spot": ("spot", ""),
    "memorizing": ("memorize", "'<incantesimo>'"),
}

# Psionist abilities cast with mind '...'
MIND_SPELLS = {
    "psi invisibility", "mind burn", "clairvoyance", "psionic danger sense",
    "psionic disintegrate", "telekinesis", "levitation", "cell adjustment",
    "chameleon", "psionic strength", "mind over body", "probability travel",
    "psionic teleport", "domination", "mind wipe", "psychic crush",
    "tower of iron will", "mindblank", "psychic impersonation", "ultra blast",
    "intensify", "hypnosis",
}

# Spells that typically need no target (room/self)
NO_TARGET_SPELLS = {
    "burning hands", "fireball", "earthquake", "control weather", "create food",
    "create water", "word of recall", "ice storm", "faerie fog", "heroes feast",
    "group fly", "breath", "golem", "changestaff", "holy word", "unholy word",
    "commune", "tree", "travelling", "invis to animals", "slow poison",
    "gust of wind", "find traps", "firestorm", "dust devil", "goodberry",
    "elemental blade", "fire servant", "earth servant", "water servant",
    "wind servant", "animal summon one", "animal summon two", "animal summon three",
    "monsum one", "monsum two", "monsum three", "monsum four", "monsum five",
    "monsum six", "monsum seven", "conjure elemental", "animate dead", "turn",
    "succor", "create light", "continual light", "calm", "minor creation",
    "astral walk", "geyser", "mirror images", "green slime", "darkness",
    "minor invulnerability", "major invulnerability", "protection from drain",
    "protection from breath", "anti magic shell", "protection from evil group",
    "incendiary cloud", "comprehend languages", "protection from fire",
    "protection from cold", "protection from energy", "protection from electricity",
    "messenger", "protection fire breath", "protection frost breath",
    "protection electric breath", "protection acid breath", "protection gas breath",
    "wizardeye", "mind burn", "clairvoyance", "psionic danger sense",
    "tower of iron will", "mindblank", "psychic impersonation", "ultra blast",
    "intensify", "cell adjustment", "chameleon", "psionic strength",
    "mind over body", "probability travel", "dragon ride", "mount",
    "fireshield", "shillelagh", "ventriloquate", "identify",
}

SKIP_SPELLS = {"", "168 non implementata", "\n"}

# Common abbreviations for fast casting
ABBREVS = {
    "armor": "arm", "teleport": "tele", "bless": "ble", "blindness": "blind",
    "burning hands": "bh", "call lightning": "clightn", "charm person": "charm",
    "chill touch": "ct", "colour spray": "cs", "create food": "cfood",
    "create water": "cwater", "cure blind": "cblind", "cure critic": "cc",
    "cure light": "clight", "cure serious": "cser", "curse": "curse",
    "detect evil": "dev", "detect invisibility": "dinv", "detect magic": "dmag",
    "detect poison": "dpois", "dispel evil": "devl", "dispel good": "dg",
    "dispel magic": "dm", "earthquake": "ea", "enchant weapon": "ewep",
    "energy drain": "edrain", "fireball": "fb", "harm": "harm", "heal": "heal",
    "invisibility": "invis", "lightning bolt": "lb", "locate object": "loc",
    "magic missile": "mm", "poison": "pois", "protection from evil": "pevil",
    "remove curse": "rcurse", "sanctuary": "san", "shocking grasp": "sg",
    "sleep": "csleep", "strength": "str", "summon": "summ", "word of recall": "wrec",
    "remove poison": "rpois", "sense life": "slife", "identify": "ident",
    "infravision": "infra", "cause light": "cal", "cause critical": "cac",
    "cause serious": "cas", "flamestrike": "fs", "weakness": "weak",
    "knock": "knock", "know alignment": "kalign", "animate dead": "adead",
    "paralyze": "para", "remove paralysis": "rpara", "fear": "fear",
    "acid blast": "ab", "water breath": "wb", "fly": "fly", "cone of cold": "coc",
    "meteor swarm": "ms", "ice storm": "is", "shield": "shld", "fireshield": "fshld",
    "charm monster": "cmon", "refresh": "ref", "second wind": "sw",
    "stone skin": "sskin", "mirror images": "mirr", "true sight": "tsight", "faerie fire": "ffire",
    "polymorph self": "poly", "mana": "mana", "resurrection": "resu",
    "chain lightning": "chain", "haste": "haste", "slowness": "slow",
    "entangle": "ent", "snare": "snare", "barkskin": "bark", "silence": "sil",
    "heal": "heal", "aid": "aid", "command": "cmd", "feeblemind": "feeble",
    "reincarnate": "reinc", "prismatic spray": "prism", "disintegrate": "disint",
    "enchant armor": "earmor", "mind burn": "mburn", "psychic crush": "pcrush",
    "psionic teleport": "ptel", "levitation": "lev", "telekinesis": "telek",
    "domination": "dom", "mind wipe": "mwipe", "backstab": "bs", "kick": "kick",
    "bash": "bash", "rescue": "resc", "steal": "stl", "sneak": "snk", "hide": "hide",
    "pick": "picklock", "track": "track", "berserk": "berz", "warcry": "wc",
    "lay on hands": "loh", "blessing": "bld", "heroic rescue": "hero",
    "meditate": "medit", "blast": "blast", "hypnotize": "hyp", "first aid": "faid",
    "quivering palm": "qp", "feign death": "fd", "springleap": "leap",
    "mantra": "man", "finger": "fin", "daimoku": "dai", "bellow": "bel",
    "brew": "brew", "forge": "forge", "carve": "carve", "doorway": "dw",
    "portal": "psiport", "summon": "sum", "canibalize": "cani", "flame": "flm",
    "aura": "aura",     "great": "great", "esp": "esp",
    "immolate": "imm", "scry": "scry", "adrenalize": "adr", "pray": "pray",
    "psi shield": "pshld",
    "spy": "spy", "tspy": "tspy", "eavesdrop": "eaves", "disguise": "disguise",
    "camouflage": "camo", "climb": "climb", "swim": "swim", "doorbash": "dbash",
    "bodyguard": "bg", "spot": "spot", "parry": "parry", "disarm": "disarm",
    "tan": "tan", "find food": "ffood", "find water": "fwater",
    "find traps": "ftrap", "memorize": "mem",
}

WEAR_OFF_TRIGGERS = [
    ("armor", "armatura magica"),
    ("bless", "benedizione Divina"),
    ("invisibility", "Torni visibile."),
    ("sanctuary", "aura bianca che ti circondava svanisce"),
    ("fly", "capacita' di volare svanisce"),
    ("haste", "Senti i tuoi movimenti rallentare"),
    ("fireshield", "scudo di fuoco"),
    ("stone skin", "pelle torna normale"),
    ("shield", "scudo magico si dissolve"),
    ("sneak", "Smetti di muoverti silenziosamente"),
    ("meditate", "meditato abbastanza"),
    ("psi shield", "creata dalla tua mente tremola"),
    ("barkskin", "pelle perde la consistenza"),
    ("faerie fire", "alone rosa"),
    ("mirror images", "immagine illusoria"),
    ("strength", "Non ti senti piu' cosi'"),
    ("detect magic", "presenza della magia"),
    ("detect invisibility", "vedere l'invisibile"),
    ("protection from evil", "protezione dal Male"),
    ("anti magic shell", "anti-magia"),
    ("globe darkness", "globo di oscurita'"),
    ("minor invulnerability", "globo protettivo attorno al tuo corpo si dissolve"),
    ("lay on hands", "Puoi curarti di nuovo"),
    ("blessing", "Puoi invocare i tuoi Dei di nuovo"),
    ("first aid", "Puoi medicarti di nuovo"),
    ("spy", "Puoi spiare di nuovo"),
    ("disguise", "Puoi mascherarti nuovamente"),
    ("adrenalize", "furia scompare"),
    ("psionic blast", "cervello si sta lentamente riprendendo"),
    ("polymorph", "Ritorni alla tua forma originale"),
    ("web", "ti liberi dalle ragnatele"),
    ("paralyze", "Lentamente ricominci a muoverti"),
    ("silence", "Puoi parlare di nuovo"),
    ("mana", "protezione magica scompare"),
    ("aid", "Perdi l'aiuto Divino"),
]

FAIL_TRIGGERS = [
    ("concentrazione", "Perdi la tua concentrazione"),
    ("no_mana", "Non hai abbastanza"),
    ("no_level", "Devi ancora crescere"),
    ("no_mem", "Non hai questo incantesimo memorizzato"),
    ("usa_mind", "Usa la mente"),
    ("usa_recall", "Usa la memoria"),
    ("no_quotes", "simboli sacri della"),
    ("unknown", "Fantastico! Non e' successo nulla"),
    ("unimplemented", "non e' stato ancora inventato"),
    ("backfire", "ti si ritorce contro"),
    ("fizzle", "fallisce miseramente"),
    ("no_magic_zone", "Il mana si rifusa di scorrere"),
    ("no_mind_zone", "Non riesci a concentrarti abbastanza in questo posto"),
    ("anti_magic", "scudo anti-magia"),
    ("first_aid_cd", "Devi aspettare ancora un po' prima di poter medicare"),
    ("kick_fail", "Non riesci ad avvicinarti abbastanza per calciare"),
    ("backstab_fail", "Non riesci ad avvicinarti abbastanza"),
]

SOON_TRIGGERS = [
    ("armor", "armatura magica vacilla"),
    ("sanctuary", "aura bianca che ti circonda inizia"),
    ("shield", "scudo magico tremola"),
    ("invisibility", "Torni visibile per un momento"),
    ("fly", "stai perdendo la capacita' di volare"),
]

# Debuff apply / wear-off (substring triggers; poison/curse hidden from attribute)
DEBUFF_APPLY_TRIGGERS = [
    ("poison", "appare molto sofferente"),
    ("curse", "maledett"),
    ("paralyze", "pare impedit"),
    ("paralyze", "Sei paralizzato"),
    ("slowness", "rallentatore"),
    ("slowness", "Sembra che il mondo stia rallentando"),
    ("web", "dalle ragnatele"),
    ("web", "della ragnatela"),
    ("web", "di ragnatele"),
    ("web", "in ragnatele"),
    ("heat stuff", "frigge"),
    ("heat stuff", "bruciare"),
    ("blindness", "accecat"),
    ("feeblemind", "rimbecillit"),
    ("fear", "viene presa dal panico"),
]

DEBUFF_WEAR_OFF_TRIGGERS = [
    ("poison", "veleno non scorre"),
    ("poison", "sembrano meno forti ora"),
    ("curse", "Ti senti molto meglio"),
    ("paralyze", "ricominci a muoverti"),
    ("paralyze", "ricomincia a muoversi"),
    ("slowness", "movimenti riacquistano la loro velocita"),
    ("web", "ti liberi dalle"),
    ("web", "liberarsi dalla ragnatela"),
    ("heat stuff", "raffredda"),
    ("blindness", "cecita"),
    ("feeblemind", "piu' intelligente"),
]

# Stima durata buff in secondi (tick MUD ~4s; molti affect = 24 tick)
BUFF_DURATIONS = {
    "armor": 96, "bless": 96, "invisibility": 96, "sanctuary": 96, "fly": 96,
    "haste": 96, "fireshield": 96, "stone skin": 96, "shield": 96, "strength": 96,
    "barkskin": 96, "detect magic": 96, "detect invisibility": 96,
    "protection from evil": 96, "anti magic shell": 96, "minor invulnerability": 96,
    "mana": 96, "aid": 96, "faerie fire": 48, "mirror images": 48,
    "psi shield": 96, "tower of iron will": 96, "mindblank": 96,
    "chameleon": 96, "levitation": 96, "psionic strength": 96,
}

# Cast che non sono buff sul personaggio (utility, danno, creazione oggetti, ecc.)
NO_BUFF_SPELLS = [
    "heroes feast", "create food", "create water", "create light", "continual light",
    "identify", "locate object", "word of recall", "teleport", "summon",
    "enchant weapon", "enchant armor", "remove curse", "dispel magic", "dispel evil",
    "dispel good", "resurrection", "reincarnate", "animate dead", "turn",
    "fireball", "magic missile", "lightning bolt", "harm", "heal", "cure light",
    "cure serious", "cure critic", "flamestrike", "earthquake", "meteor swarm",
    "cone of cold", "acid blast", "chain lightning", "ice storm", "burning hands",
    "chill touch", "shocking grasp", "colour spray", "sleep", "charm person",
    "charm monster", "blindness", "poison", "curse", "energy drain", "feeblemind",
    "paralyze", "fear", "weakness", "knock", "refresh", "second wind",
    "messenger", "wizardeye", "clairvoyance", "astral walk", "geyser",
    "faerie fog", "ice storm", "green slime", "darkness", "incendiary cloud",
]

# Scorciatoie rapide per classe (lettera practice in-game) — 9 slot ciascuna (q1-q9)
CLASS_PRESETS = {
    "+": {
        "name": "Cast universale", "mode": "cast",
        "quick": [
            ("aid", "cast", "aid"), ("arm", "cast", "armor"), ("ble", "cast", "bless"),
            ("shld", "cast", "shield"), ("sskin", "cast", "stone skin"), ("mirr", "cast", "mirror images"),
            ("heal", "cast", "heal"), ("san", "cast", "sanctuary"), ("invis", "cast", "invisibility"),
        ],
    },
    "m": {
        "name": "Mago", "mode": "cast",
        "quick": [
            ("arm", "cast", "armor"), ("shld", "cast", "shield"), ("fly", "cast", "fly"),
            ("mm", "cast", "magic missile"), ("fb", "cast", "fireball"),
            ("lb", "cast", "lightning bolt"), ("invis", "cast", "invisibility"),
            ("str", "cast", "strength"), ("tele", "cast", "teleport"),
        ],
    },
    "s": {
        "name": "Stregone", "mode": "recall",
        "quick": [
            ("arm", "recall", "armor"), ("shld", "recall", "shield"),
            ("mm", "recall", "magic missile"), ("fb", "recall", "fireball"),
            ("lb", "recall", "lightning bolt"), ("invis", "recall", "invisibility"),
            ("str", "recall", "strength"), ("fly", "recall", "fly"),
            ("tele", "recall", "teleport"),
        ],
    },
    "c": {
        "name": "Chierico", "mode": "cast",
        "quick": [
            ("heal", "cast", "heal"), ("cser", "cast", "cure serious"),
            ("cc", "cast", "cure critic"), ("clight", "cast", "cure light"),
            ("ble", "cast", "bless"), ("san", "cast", "sanctuary"),
            ("pevil", "cast", "protection from evil"), ("devl", "cast", "dispel evil"),
            ("aid", "cast", "aid"),
        ],
    },
    "d": {
        "name": "Druido", "mode": "cast",
        "quick": [
            ("bark", "cast", "barkskin"), ("clightn", "cast", "call lightning"),
            ("ent", "cast", "entangle"), ("snare", "cast", "snare"),
            ("clight", "cast", "cure light"), ("fly", "cast", "fly"),
            ("sskin", "cast", "stone skin"), ("ffood", "skill", "find food"),
            ("brew", "skill", "brew"),
        ],
    },
    "p": {
        "name": "Paladino", "mode": "cast",
        "quick": [
            ("heal", "cast", "heal"), ("loh", "skill", "lay on hands"),
            ("wc", "skill", "warcry"), ("ble", "cast", "bless"),
            ("san", "cast", "sanctuary"), ("fs", "cast", "flamestrike"),
            ("hero", "skill", "heroic rescue"), ("bld", "skill", "blessing"),
            ("pray", "skill", "pray"),
        ],
    },
    "r": {
        "name": "Ranger", "mode": "cast",
        "quick": [
            ("track", "skill", "track"), ("clight", "cast", "cure light"),
            ("bark", "cast", "barkskin"), ("camo", "skill", "camouflage"),
            ("snk", "skill", "sneak"), ("carve", "skill", "carve"),
            ("ffood", "skill", "find food"), ("fwater", "skill", "find water"),
            ("ent", "cast", "entangle"),
        ],
    },
    "I": {
        "name": "Psionista", "mode": "mind",
        "quick": [
            ("pshld", "skill", "psi shield"), ("mb", "mind", "mindblank"),
            ("pcrush", "mind", "psychic crush"), ("lev", "mind", "levitation"),
            ("ptel", "mind", "psionic teleport"), ("medit", "skill", "meditate"),
            ("blast", "skill", "psionic blast"), ("dw", "skill", "doorway"),
            ("psiport", "skill", "psi portal"),
        ],
    },
    "t": {
        "name": "Ladro", "mode": "cast",
        "quick": [
            ("bs", "skill", "backstab"), ("snk", "skill", "sneak"),
            ("hide", "skill", "hide"), ("stl", "skill", "steal"),
            ("picklock", "skill", "pick"), ("spy", "skill", "spy"),
            ("tspy", "skill", "tspy"), ("disguise", "skill", "disguise"),
            ("eaves", "skill", "eavesdrop"),
        ],
    },
    "w": {
        "name": "Guerriero", "mode": "cast",
        "quick": [
            ("kick", "skill", "kick"), ("bash", "skill", "bash"),
            ("resc", "skill", "rescue"), ("disarm", "skill", "disarm"),
            ("bel", "skill", "bellow"), ("parry", "skill", "parry"),
            ("faid", "skill", "first aid"), ("dbash", "skill", "doorbash"),
            ("climb", "skill", "climb"),
        ],
    },
    "k": {
        "name": "Monaco", "mode": "cast",
        "quick": [
            ("man", "skill", "mantra"), ("fin", "skill", "finger"),
            ("qp", "skill", "quivering palm"), ("leap", "skill", "springleap"),
            ("fd", "skill", "feign death"), ("kick", "skill", "kick"),
            ("bash", "skill", "bash"), ("dai", "skill", "daimoku"),
            ("faid", "skill", "first aid"),
        ],
    },
    "b": {
        "name": "Barbaro", "mode": "cast",
        "quick": [
            ("berz", "skill", "berserk"), ("bel", "skill", "bellow"),
            ("kick", "skill", "kick"), ("bash", "skill", "bash"),
            ("camo", "skill", "camouflage"), ("ffood", "skill", "find food"),
            ("fwater", "skill", "find water"), ("tan", "skill", "tan"),
            ("faid", "skill", "first aid"),
        ],
    },
}

CLASS_VAR = "nebbie_class"


def parse_mud_commands():
    text = (ROOT.parent.parent / "src" / "interpreter.cpp").read_text(encoding="utf-8", errors="replace")
    cmds = re.findall(r'AddCommand\(\s*"([^"]+)"', text)
    out = set()
    for cmd in cmds:
        if cmd and cmd[0].isalpha():
            out.add(cmd.lower())
    return sorted(out)


def mud_prefix_match(typed, cmd):
    return cmd.startswith(typed)


def is_safe_standalone_abbr(abbr, mud_cmds, skill_cmd=None):
    abbr = abbr.lower()
    if abbr in ALWAYS_RESERVED_ABBREVS:
        return False
    if abbr in FORCE_STANDALONE_ABBREVS:
        return True
    matching = [c for c in mud_cmds if mud_prefix_match(abbr, c)]
    if not matching:
        return True
    if skill_cmd and abbr == skill_cmd.lower():
        return True
    if len(matching) == 1 and matching[0] == abbr:
        return True
    return False


def parse_spells():
    text = SPELL_PARSER.read_text(encoding="utf-8", errors="replace")
    m = re.search(r'const char\* spells\[\]= \{(.*?)\n\};', text, re.S)
    if not m:
        raise SystemExit("spells[] not found in spell_parser.cpp")
    raw = m.group(1)
    names = []
    for line in raw.splitlines():
        line = line.strip().rstrip(",")
        if not line or line.startswith("/*"):
            continue
        sm = re.search(r'"([^"]*)"', line)
        if sm:
            names.append(sm.group(1))
    return names


def lua_escape(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def build_cast_spell_list(spells):
    cast_spells = []
    for i, name in enumerate(spells, start=1):
        if name in SKIP_SPELLS or not name.strip():
            continue
        if i in RESERVED_SKILL_IDS:
            continue
        if name in DEDICATED_SKILLS:
            continue
        if name.startswith("language ") or name in {
            "necromancy", "vegetable lore", "demonology", "animal lore",
            "reptile lore", "people lore", "giant lore", "other lore",
            "dodge", "retreat", "safe fall", "evaluate", "read magic",
            "miner", "determine", "equilibrium", "riding", "switch opponents",
            "remove trap", "find trap", "hunt", "avoid back attack", "Parry",
            "dual wield", "quest", "spot",
        }:
            continue
        cast_spells.append(name)
    return cast_spells


def build_legacy_perm_names(spells):
    """Full names of old permAlias/permTrigger items (for exists()-based purge)."""
    cast_spells = build_cast_spell_list(spells)
    mud_cmds = parse_mud_commands()
    pkgs = [PACKAGE_NAME, "nebbie-spells-skills"]
    aliases, triggers = [], []

    static_alias = [
        "mode cast", "mode recall", "mode mind", "toggle gui", "toggle hud",
        "reposition gui", "setup hud", "attrib sync", "attrib on", "attrib off",
        "loot manual", "loot on", "loot off", "swap weapon",
        "eq key list", "eq key add", "eq key del",
        "generic cast c", "generic cast word",
        "memorize", "recall shortcut", "mind shortcut", "list classes", "set class",
        "return form", "reinstall fix", "prompt debug",
    ]
    static_triggers = [
        "prompt parse", "attrib gag", "look loot parse", "eq parse wield", "mob kill exp loot", "cast started",
    ]

    for pkg in pkgs:
        prefix = f"{pkg}::"
        aliases.extend(prefix + s for s in static_alias)
        triggers.extend(prefix + s for s in static_triggers)
        aliases.extend(static_alias)
        triggers.extend(static_triggers)
        for slot in range(1, 10):
            aliases.append(f"{prefix}quick slot {slot}")
        seen_abbr = set()
        for spell, abbr in sorted(ABBREVS.items()):
            if spell in cast_spells or spell in MIND_SPELLS:
                if is_safe_standalone_abbr(abbr, mud_cmds) and abbr not in seen_abbr:
                    seen_abbr.add(abbr)
                    aliases.append(f"{prefix}abbr cast {abbr}")
        for spell in FAVORITE_SPELL_ALIASES:
            if spell in cast_spells:
                aliases.append(f"{prefix}fav cast {spell}")
        seen_skill = set()
        for skill_name, (cmd, _hint) in DEDICATED_SKILLS.items():
            abbr = ABBREVS.get(skill_name, ABBREVS.get(cmd, cmd.replace(" ", "")))
            if is_safe_standalone_abbr(abbr, mud_cmds, skill_cmd=cmd) and abbr not in seen_skill:
                seen_skill.add(abbr)
                aliases.append(f"{prefix}skill {cmd}")
        for name, _pat in WEAR_OFF_TRIGGERS:
            triggers.append(f"{prefix}wearoff {name}")
        for name, _pat in SOON_TRIGGERS:
            triggers.append(f"{prefix}soon {name}")
        for name, pat in DEBUFF_APPLY_TRIGGERS:
            triggers.append(f"{prefix}debuff on {name} {pat}")
        for name, pat in DEBUFF_WEAR_OFF_TRIGGERS:
            triggers.append(f"{prefix}debuff off {name} {pat}")
        for name, _pat in FAIL_TRIGGERS:
            triggers.append(f"{prefix}fail {name}")

    return sorted(set(aliases)), sorted(set(triggers))


def lua_string_list(items):
    return "{" + ", ".join(f'"{lua_escape(x)}"' for x in items) + "}"


def build_bootstrap_purge_lua(legacy_aliases, legacy_triggers):
    return f"""
local function Nebbie_killNamed(name, typ)
  if type(exists) ~= "function" then return end
  local n = 0
  while exists(name, typ) > 0 and n < 64 do
    if typ == "trigger" then
      if type(disableTrigger) == "function" then disableTrigger(name) end
      if type(killTrigger) == "function" then killTrigger(name) end
    else
      if type(disableAlias) == "function" then disableAlias(name) end
      if type(killAlias) == "function" then killAlias(name) end
    end
    n = n + 1
  end
end
function Nebbie_purgeLegacyPerm()
  local triggers = {lua_string_list(legacy_triggers)}
  local aliases = {lua_string_list(legacy_aliases)}
  for _, name in ipairs(triggers) do Nebbie_killNamed(name, "trigger") end
  for _, name in ipairs(aliases) do
    if name ~= "nebbie-fix" and not name:find("nebbie%-fix", 1, true) and name ~= "nebbie-nprompt" then
      Nebbie_killNamed(name, "alias")
    end
  end
end
Nebbie_purgeLegacyPerm()
"""


def build_install_lua(spells):
    cast_spells = build_cast_spell_list(spells)
    lines = []
    lines.append("-- Nebbie Arcane: spell & skill aliases/triggers (auto-generated)")
    lines.append("Nebbie = Nebbie or {}")
    lines.append("")
    lines.append("Nebbie.package = 'nebbie-play-all'")
    lines.append("Nebbie.castMode = Nebbie.castMode or 'cast'  -- cast | recall | mind")
    lines.append("")
    lines.append("Nebbie.castSpells = {")
    for n in cast_spells:
        lines.append(f"  ['{lua_escape(n)}'] = true,")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.mindSpells = {")
    for n in sorted(MIND_SPELLS):
        lines.append(f"  ['{lua_escape(n)}'] = true,")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.dedicatedSkills = {")
    for name, (cmd, args) in sorted(DEDICATED_SKILLS.items(), key=lambda x: x[0]):
        lines.append(f"  ['{lua_escape(name)}'] = {{ cmd = '{lua_escape(cmd)}', hint = '{lua_escape(args)}' }},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.abbrevs = {")
    for k, v in sorted(ABBREVS.items()):
        lines.append(f"  ['{lua_escape(k)}'] = '{lua_escape(v)}',")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.wearOff = {")
    for label, pat in WEAR_OFF_TRIGGERS:
        lines.append(f"  {{ name = '{lua_escape(label)}', pattern = '{lua_escape(pat)}' }},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.wearOffSoon = {")
    for label, pat in SOON_TRIGGERS:
        lines.append(f"  {{ name = '{lua_escape(label)}', pattern = '{lua_escape(pat)}' }},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.failures = {")
    for label, pat in FAIL_TRIGGERS:
        lines.append(f"  {{ name = '{lua_escape(label)}', pattern = '{lua_escape(pat)}' }},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.debuffApply = {")
    for label, pat in DEBUFF_APPLY_TRIGGERS:
        lines.append(f"  {{ name = '{lua_escape(label)}', pattern = '{lua_escape(pat)}' }},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.debuffWearOff = {")
    for label, pat in DEBUFF_WEAR_OFF_TRIGGERS:
        lines.append(f"  {{ name = '{lua_escape(label)}', pattern = '{lua_escape(pat)}' }},")
    lines.append("}")
    lines.append("")
    mud_cmds = parse_mud_commands()
    lines.append("Nebbie.safeStandalone = {")
    seen = set()
    for _spell, abbr in sorted(ABBREVS.items(), key=lambda x: x[1]):
        if abbr not in seen and is_safe_standalone_abbr(abbr, mud_cmds):
            seen.add(abbr)
            lines.append(f"  ['{lua_escape(abbr)}'] = true,")
    for name, (cmd, _hint) in sorted(DEDICATED_SKILLS.items()):
        abbr = ABBREVS.get(name, ABBREVS.get(cmd, cmd.replace(" ", "")))
        if abbr not in seen and is_safe_standalone_abbr(abbr, mud_cmds, skill_cmd=cmd):
            seen.add(abbr)
            lines.append(f"  ['{lua_escape(abbr)}'] = true,")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.buffDurations = {")
    for k, v in sorted(BUFF_DURATIONS.items()):
        lines.append(f"  ['{lua_escape(k)}'] = {v},")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.noBuffSpells = {")
    for n in sorted(set(NO_BUFF_SPELLS)):
        lines.append(f"  ['{lua_escape(n)}'] = true,")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.classes = {")
    for cls, data in sorted(CLASS_PRESETS.items()):
        lines.append(f"  ['{lua_escape(cls)}'] = {{")
        lines.append(f"    name = '{lua_escape(data['name'])}',")
        lines.append(f"    mode = '{lua_escape(data['mode'])}',")
        lines.append("    quick = {")
        for abbr, kind, target in data["quick"]:
            lines.append(
                f"      {{ abbr = '{lua_escape(abbr)}', kind = '{lua_escape(kind)}', target = '{lua_escape(target)}' }},"
            )
        lines.append("    },")
        lines.append("  },")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.favoriteSpells = {")
    for n in FAVORITE_SPELL_ALIASES:
        lines.append(f"  '{lua_escape(n)}',")
    lines.append("}")
    lines.append("")
    legacy_aliases, legacy_triggers = build_legacy_perm_names(spells)
    lines.append("Nebbie.legacyPermAliases = " + lua_string_list(legacy_aliases))
    lines.append("Nebbie.legacyPermTriggers = " + lua_string_list(legacy_triggers))
    lines.append("")
    core = INSTALLER_CORE.read_text(encoding="utf-8")
    lines.append(core)
    return "\n".join(lines)


def build_xml(legacy_aliases, legacy_triggers):
    purge_lua = build_bootstrap_purge_lua(legacy_aliases, legacy_triggers)
    pkg_ver = "2.2.4"
    bootstrap = (
        r'''-- Nebbie Arcane play-all bootstrap
Nebbie = Nebbie or {}
Nebbie.package = "nebbie-play-all"
local NEBBIE_PKG_VER = "'''
        + pkg_ver
        + r'''"
if Nebbie._loadedPkgVer == NEBBIE_PKG_VER and Nebbie._mainLoaded then return end
Nebbie._loadedPkgVer = NEBBIE_PKG_VER
Nebbie._mainLoaded = false
'''
        + purge_lua
        + r'''
local function Nebbie_loadMain()
  if Nebbie._mainLoaded and Nebbie._loadedPkgVer == NEBBIE_PKG_VER then return end
  Nebbie._mainLoaded = false
  Nebbie_purgeLegacyPerm()
  local path = getMudletHomeDir() .. "/nebbie-play-all/nebbie-install.lua"
  local ok, err = pcall(dofile, path)
  if not ok then
    cecho("<red>[Nebbie] errore caricamento: " .. tostring(err) .. "\n")
    cecho("<grey>File atteso: <yellow>" .. path .. "\n")
    Nebbie._mainLoaded = false
  else
    Nebbie._mainLoaded = true
    if Nebbie.testPromptParse then Nebbie.testPromptParse(true) end
  end
end
if type(tempTimer) == "function" then
  tempTimer(0, Nebbie_loadMain)
else
  Nebbie_loadMain()
end'''
    )
    escaped = bootstrap.replace("]]>", "]]..']]'..[[")
    reload_lua = (
        'local _p=getMudletHomeDir().."/nebbie-play-all/nebbie-install.lua" '
        'pcall(dofile,_p) '
    )
    nfix_script = (
        reload_lua
        + 'if Nebbie and Nebbie.runFix then Nebbie.runFix() else '
        + 'cecho("<orange>Nebbie: caricamento in corso, riprova tra 2s.\\n") end'
    )
    npurge_script = (
        'if Nebbie_purgeLegacyPerm then Nebbie_purgeLegacyPerm() end '
        'if Nebbie and Nebbie.purgeLegacyPermItems then Nebbie.purgeLegacyPermItems(false) end '
        'cecho("<green>Nebbie: perm vecchi disattivati. Riavvia Mudlet, reinstalla v'
        + pkg_ver
        + ', poi nfix.\\n")'
    )
    nprompt_script = (
        reload_lua
        + 'if Nebbie and Nebbie.debugPrompt then Nebbie.debugPrompt() else '
        + 'cecho("<orange>Nebbie: reinstalla package v'
        + pkg_ver
        + ' da GitHub, poi nfix.\\n") end'
    )
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="1.001">
 <ScriptPackage>
  <Script isActive="yes" isFolder="no">
   <name>Nebbie Play All</name>
   <script><![CDATA[{escaped}]]></script>
   <eventHandlerList />
   <packageName>{PACKAGE_NAME}</packageName>
  </Script>
 </ScriptPackage>
 <AliasPackage>
  <Alias isActive="yes" isFolder="no">
   <name>nebbie-fix</name>
   <script><![CDATA[{nfix_script}]]></script>
   <command></command>
   <packageName>{PACKAGE_NAME}</packageName>
   <regex>^nfix$</regex>
  </Alias>
  <Alias isActive="yes" isFolder="no">
   <name>nebbie-purge</name>
   <script><![CDATA[{npurge_script}]]></script>
   <command></command>
   <packageName>{PACKAGE_NAME}</packageName>
   <regex>^npurge$</regex>
  </Alias>
  <Alias isActive="yes" isFolder="no">
   <name>nebbie-nprompt</name>
   <script><![CDATA[{nprompt_script}]]></script>
   <command></command>
   <packageName>{PACKAGE_NAME}</packageName>
   <regex>^nprompt$</regex>
  </Alias>
 </AliasPackage>
</MudletPackage>
'''


def main():
    spells = parse_spells()
    cast_spells = build_cast_spell_list(spells)
    for cls, data in CLASS_PRESETS.items():
        n = len(data["quick"])
        if n != 9:
            raise SystemExit(f"Class {cls} has {n} quick slots, expected 9")
    legacy_aliases, legacy_triggers = build_legacy_perm_names(spells)
    lua = build_install_lua(spells)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    install_lua = OUT_DIR / "nebbie-install.lua"
    install_lua.write_text(lua, encoding="utf-8")
    (OUT_DIR / "config.lua").write_text(f'mpackage = "{PACKAGE_NAME}"\n', encoding="utf-8")
    xml_name = f"{PACKAGE_NAME}.xml"
    (OUT_DIR / xml_name).write_text(build_xml(legacy_aliases, legacy_triggers), encoding="utf-8")
    mpackage = ROOT / f"{PACKAGE_NAME}.mpackage"
    with zipfile.ZipFile(mpackage, "w", zipfile.ZIP_STORED) as zf:
        zf.write(OUT_DIR / "config.lua", "config.lua")
        zf.write(OUT_DIR / xml_name, xml_name)
        zf.write(install_lua, "nebbie-install.lua")

    # Reference list for players (not imported by Mudlet)
    ref = ROOT / "nebbie-spells-reference.txt"
    with ref.open("w", encoding="utf-8") as f:
        f.write("Nebbie Arcane — riferimento spell/skill (generato da src/spell_parser.cpp)\n\n")
        f.write("=== INCANTESIMI (cast 'nome' [bersaglio]) ===\n")
        for n in cast_spells:
            ab = ABBREVS.get(n, "")
            f.write(f"  {n}" + (f"  [{ab}]" if ab else "") + "\n")
        f.write("\n=== PSI via mind 'nome' ===\n")
        for n in sorted(MIND_SPELLS):
            ab = ABBREVS.get(n, "")
            f.write(f"  {n}" + (f"  [{ab}]" if ab else "") + "\n")
        f.write("\n=== SKILL (comando diretto) ===\n")
        for name, (cmd, hint) in sorted(DEDICATED_SKILLS.items()):
            ab = ABBREVS.get(name, ABBREVS.get(cmd, ""))
            f.write(f"  {name}: {cmd} {hint}" + (f"  [{ab}]" if ab else "") + "\n")
        f.write("\n=== ALIAS MUDLET ===\n")
        f.write("  c <spell> [tgt]     → cast (modalita' corrente)\n")
        f.write("  r <spell> [tgt]     → recall (stregone)\n")
        f.write("  m <spell> [tgt]     → mind (psi)\n")
        f.write("  mem <spell>         → memorize\n")
        f.write("  ncast/nrecall/nmind → cambia modalita' predefinita\n")
        f.write("  nclass +            → preset cast universale (multiclasse cast)\n")
        f.write("  nclass m c          → unisce slot di piu' classi\n")
        f.write("  nclass m            → imposta classe (salvata per profilo Mudlet)\n")
        f.write("  nclass              → elenca tutte le classi e slot q1-q9\n")
        f.write("  q1-q9 [tgt]         → slot rapidi della classe corrente\n")
        f.write("  nattrib             → sync attribute (gagged)\n")
        f.write("  nattrib on/off      → sync automatico ogni 90s\n")
        f.write("  nsetup              → avvia HUD (non cambia il prompt)\n")
        f.write("  ngui / nhud         → mostra/nasconde HUD\n")
        f.write("  inv / eq            → comandi MUD nativi (non aliasati)\n")
        f.write("  nloot               → look, poi corp/2.corp/… + pile/2.pile/…\n")
        f.write("  nloot on/off        → loot auto dopo kill mob (exp reale)\n")
        f.write("  usa <arma>          → cambio arma da borsa sulla schiena\n")
        f.write("  nkey                → elenco chiavi eq (nome → parola MUD)\n")
        f.write("  nkey add <k> <txt>  → aggiungi chiave custom\n")
        f.write("\n=== PANNELLO HUD ===\n")
        f.write("  Gauge HP/Mana/Move + buff/debuff + parser prompt [%s]\n")
        for cls, data in sorted(CLASS_PRESETS.items()):
            slots = ", ".join(f"q{i+1}={q[0]}" for i, q in enumerate(data["quick"]))
            f.write(f"  {cls} ({data['name']}): {slots}\n")

    print(f"Wrote {mpackage} ({mpackage.stat().st_size} bytes)")
    print(f"Wrote {ref}")
    print(f"Cast spells: {len(cast_spells)}")


if __name__ == "__main__":
    main()
