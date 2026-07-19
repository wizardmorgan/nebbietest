#!/usr/bin/env python3
"""Generate Nebbie Arcane Mudlet package from spell_parser.cpp spells[] table."""

import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPELL_PARSER = ROOT.parent.parent / "src" / "spell_parser.cpp"
OUT_DIR = ROOT / "nebbie-play-all-build"
PACKAGE_NAME = "nebbie-play-all"
PKG_VER = "2.2.30"
MAIN_SCRIPT_NAME = "Nebbie Play All"  # legacy profile script (cache source only)
LOADER_SCRIPT_NAME = "Nebbie Loader"
INSTALL_FILE = "nebbie-install.lua"
INSTALL_URL = (
    "https://github.com/wizardmorgan/nebbietest/raw/mudlet/docs/mudlet/"
    "nebbie-play-all-build/nebbie-install.lua"
)
PKG_URL = "https://github.com/wizardmorgan/nebbietest/raw/mudlet/docs/mudlet/nebbie-play-all.mpackage"
LEGACY_MAIN_SCRIPTS = [
    "Nebbie Spells and Skills",
    "nebbie-install",
    "Nebbie Bootloader",
    "!Nebbie Boot",
    "Nebbie Play All",
    "Nebbie Play All v2.2.12",
    "Nebbie Play All v2.2.13",
    "Nebbie Play All v2.2.14",
    "Nebbie Play All v2.2.15",
    "Nebbie Play All v2.2.16",
    "Nebbie Play All v2.2.17",
    "Nebbie Play All v2.2.18",
    "Nebbie Play All v2.2.19",
    "Nebbie Play All v2.2.20",
]
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
    ("paralyze", "ricominci a muoverti"),
    ("paralyze", "ricomincia a muoversi"),
    ("slowness", "movimenti riacquistano la loro velocita"),
    ("blindness", "svanire la tua"),
    ("heat stuff", "equipaggiamento finalmente si"),
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

# Affect negativi visibili in attribute (durata da tick, non debuff HUD separato)
ATTRIB_DEBUFF_SPELLS = [
    "web", "paralyze", "slowness", "blindness", "fear", "heat stuff", "silence",
]

# Apply immediato solo su messaggi self (fino al prossimo attribute)
SELF_AFFECT_APPLY_TRIGGERS = [
    ("web", "ragnatele che ti avvolgono"),
    ("web", "ricopert"),
    ("paralyze", "Sei paralizzato"),
    ("slowness", "mondo stia rallentando"),
    ("blindness", "accecat"),
    ("heat stuff", "frigge"),
    ("fear", "presa dal panico"),
    ("silence", "non riesci a parlare"),
]

# Debuff apply / wear-off: solo affect non in attribute (poison/curse/feeblemind)
DEBUFF_APPLY_TRIGGERS = [
    ("poison", "appare molto sofferente"),
    ("curse", "maledett"),
    ("feeblemind", "rimbecillit"),
]

DEBUFF_WEAR_OFF_TRIGGERS = [
    ("poison", "veleno non scorre"),
    ("poison", "sembrano meno forti ora"),
    ("curse", "Ti senti molto meglio"),
    ("feeblemind", "piu' intelligente"),
]

# Stima durata buff in secondi reali (1 unità attribute = 1 ora MUD = SECS_PER_MUD_HOUR)
BUFF_DURATIONS = {
    "armor": 1800, "bless": 1800, "invisibility": 1800, "sanctuary": 1800, "fly": 1800,
    "haste": 1800, "fireshield": 1800, "stone skin": 1800, "shield": 1800, "strength": 1800,
    "barkskin": 1800, "detect magic": 1800, "detect invisibility": 1800,
    "protection from evil": 1800, "anti magic shell": 1800, "minor invulnerability": 1800,
    "mana": 1800, "aid": 1800, "faerie fire": 900, "mirror images": 900,
    "psi shield": 1800, "tower of iron will": 1800, "mindblank": 1800,
    "chameleon": 1800, "levitation": 1800, "psionic strength": 1800,
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
    "charm monster", "poison", "curse", "energy drain", "feeblemind",
    "weakness", "knock", "refresh", "second wind",
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
        "eq cache sync", "eq cache on", "eq cache off",
        "generic cast c", "generic cast word",
        "memorize", "recall shortcut", "mind shortcut", "list classes", "set class",
        "list package help", "list aliases", "list triggers", "list spells ref",
        "return form", "reinstall fix", "prompt debug", "install diagnose",
        "eq cache clear", "drop recover on", "drop recover off",
        "food auto on", "food auto off", "food item set", "food manual",
    ]
    static_triggers = [
        "prompt parse", "attrib gag", "look loot parse", "eq parse wield", "mob kill exp loot",
        "cast started", "weapon drop hold", "weapon drop wield", "hunger thirst",
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
        for name, pat in SELF_AFFECT_APPLY_TRIGGERS:
            triggers.append(f"{prefix}affect on {name} {pat}")
        for name, pat in DEBUFF_APPLY_TRIGGERS:
            triggers.append(f"{prefix}debuff on {name} {pat}")
        for name, pat in DEBUFF_WEAR_OFF_TRIGGERS:
            triggers.append(f"{prefix}debuff off {name} {pat}")
        for name, _pat in FAIL_TRIGGERS:
            triggers.append(f"{prefix}fail {name}")

    return sorted(set(aliases)), sorted(set(triggers))


def lua_string_list(items, per_line=10):
    if not items:
        return "{}"
    lines = []
    for i in range(0, len(items), per_line):
        chunk = items[i : i + per_line]
        lines.append("  " + ", ".join(f'"{lua_escape(x)}"' for x in chunk))
    return "{\n" + ",\n".join(lines) + "\n}"


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
    lines.append(f"-- NEBBIE_INSTALL_VER={PKG_VER}")
    lines.append(f'if Nebbie and Nebbie._mainLoaded and Nebbie.version == "{PKG_VER}"')
    lines.append('    and type(Nebbie.runFix) == "function" then return end')
    lines.append(f'Nebbie.version = "{PKG_VER}"')
    lines.append("-- Nebbie Arcane: spell & skill aliases/triggers (auto-generated)")
    lines.append("Nebbie = Nebbie or {}")
    lines.append("")
    lines.append(f'Nebbie.MAIN_SCRIPT_NAME = "{MAIN_SCRIPT_NAME}"')
    lines.append(f'Nebbie._expectedPkgVer = "{PKG_VER}"')
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
    lines.append("Nebbie.debuffSpells = {")
    for n in ATTRIB_DEBUFF_SPELLS:
        lines.append(f"  ['{lua_escape(n)}'] = true,")
    lines.append("}")
    lines.append("")
    lines.append("Nebbie.selfAffectApply = {")
    for label, pat in SELF_AFFECT_APPLY_TRIGGERS:
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


def build_script_cleanup_lua(expect_ver, main_script):
    legacy = ", ".join(f'"{lua_escape(n)}"' for n in LEGACY_MAIN_SCRIPTS)
    # NON usare "Nebbie" da solo: matcha anche lo script principale!
    patterns = '"Play All v", "Spells and Skills", "Bootloader", "!Nebbie", "nebbie-install"'
    return f"""local NEBBIE_EXPECT = "{expect_ver}"
local MAIN_SCRIPT = "{lua_escape(main_script)}"
local LEGACY_NAMES = {{{legacy}}}

local function nebbie_find_ids(substr)
  if type(findItems) ~= "function" then return {{}} end
  local ok, ids = pcall(function() return findItems(substr, "script", false) end)
  if ok and type(ids) == "table" then return ids end
  return {{}}
end

local function nebbie_code(name, occ)
  if type(getScript) ~= "function" then return nil end
  local ok, code = pcall(function() return getScript(name, occ or 1) end)
  if not ok or not code or code == -1 or type(code) ~= "string" then return nil end
  return code
end

local function nebbie_ver_from_code(code)
  if not code then return nil end
  return code:match("NEBBIE_PKG_VER=([%d%.]+)") or code:match('Nebbie%.version = "([%d%.]+)"')
end

local function nebbie_neutralize(name, occ)
  occ = occ or 1
  if type(setScript) == "function" then
    pcall(function() setScript(name, "-- disattivato da Nebbie\\nreturn\\n", occ) end)
  end
  if type(disableScript) == "function" then
    pcall(function() disableScript(name, occ) end)
  end
end

function Nebbie_cleanupScripts(silent)
  local n_ids, n_names = 0, 0
  for _, pat in ipairs({{{patterns}}}) do
    for _, id in ipairs(nebbie_find_ids(pat)) do
      if type(disableScript) == "function" then
        if pcall(function() disableScript(id) end) then n_ids = n_ids + 1 end
      end
    end
  end
  for _, sname in ipairs(LEGACY_NAMES) do
    for occ = 1, 8 do
      local code = nebbie_code(sname, occ)
      if not code then break end
      nebbie_neutralize(sname, occ)
      n_names = n_names + 1
    end
  end
  for occ = 1, 4 do
    local code = nebbie_code(MAIN_SCRIPT, occ)
    if not code then break end
    local ver = nebbie_ver_from_code(code)
    if ver then
      nebbie_neutralize(MAIN_SCRIPT, occ)
      if not silent and ver ~= NEBBIE_EXPECT then
        cecho("<orange>Nebbie: «" .. MAIN_SCRIPT .. " #" .. occ .. "» era v" .. ver .. ", neutralizzato.\\n")
      end
    end
  end
  if type(saveProfile) == "function" then
    pcall(function() saveProfile() end)
  end
  if not silent then
    cecho("<grey>Nebbie cleanup: " .. n_ids .. " id legacy, " .. n_names .. " nomi legacy.\\n")
  end
  return n_ids + n_names
end

function Nebbie_wipeMemory()
  local saved = Nebbie and Nebbie._settings
  Nebbie = {{ package = "nebbie-play-all", _settings = saved or {{}} }}
  Nebbie._loadedPkgVer = nil
  Nebbie._mainLoaded = false
  Nebbie._installedVer = nil
end
Nebbie = Nebbie or {{}}"""


def build_loader_runtime_lua(legacy_aliases, legacy_triggers):
    purge_lua = build_bootstrap_purge_lua(legacy_aliases, legacy_triggers)
    head = f"""-- NEBBIE_LOADER_VER={PKG_VER}
Nebbie = Nebbie or {{}}
Nebbie.package = "{PACKAGE_NAME}"
local NEBBIE_EXPECT = "{PKG_VER}"
local MAIN_SCRIPT = "{lua_escape(MAIN_SCRIPT_NAME)}"
local INSTALL_FILE = "{INSTALL_FILE}"
local INSTALL_URL = "{INSTALL_URL}"
local LOADER_NAME = "{LOADER_SCRIPT_NAME}"

local function nebbie_find_ids(substr)
  if type(findItems) ~= "function" then return {{}} end
  local ok, ids = pcall(function() return findItems(substr, "script", false) end)
  if ok and type(ids) == "table" then return ids end
  return {{}}
end

local function nebbie_code(name, occ)
  if type(getScript) ~= "function" then return nil end
  local ok, code = pcall(function() return getScript(name, occ or 1) end)
  if not ok or not code or code == -1 or type(code) ~= "string" then return nil end
  return code
end

local function nebbie_ver_from_code(code)
  if not code then return nil end
  return code:match("NEBBIE_INSTALL_VER=([%d%.]+)")
    or code:match("NEBBIE_PKG_VER=([%d%.]+)")
    or code:match('Nebbie%.version = "([%d%.]+)"')
end

function Nebbie_installPath()
  local home = ""
  if type(getMudletHomeDir) == "function" then
    local ok, h = pcall(getMudletHomeDir)
    if ok and h then home = h end
  end
  if home == "" then home = "." end
  if home:sub(-1) == "/" or home:sub(-1) == "\\\\" then
    return home .. INSTALL_FILE
  end
  return home .. "/" .. INSTALL_FILE
end

function Nebbie_fileVer(path)
  path = path or Nebbie_installPath()
  local f = io.open(path, "r")
  if not f then return nil end
  local head = f:read(4096) or ""
  f:close()
  return nebbie_ver_from_code(head)
end

function Nebbie_writeInstallFile(code, silent)
  if not code or type(code) ~= "string" or #code < 1000 then
    return false, "codice install non valido"
  end
  local ver = nebbie_ver_from_code(code)
  if ver ~= NEBBIE_EXPECT then
    return false, "versione " .. tostring(ver) .. " (attesa " .. NEBBIE_EXPECT .. ")"
  end
  local path = Nebbie_installPath()
  local f = io.open(path, "w")
  if not f then return false, "impossibile scrivere " .. path end
  f:write(code)
  f:close()
  if not silent then
    cecho("<green>Nebbie: install salvato in <yellow>" .. path .. "<green> (v" .. ver .. ").\\n")
  end
  return true
end

function Nebbie_cacheInstallFromProfile(silent)
  local code = nebbie_code(MAIN_SCRIPT, 1)
  if not code then
    for occ = 2, 4 do
      code = nebbie_code(MAIN_SCRIPT, occ)
      if code then break end
    end
  end
  if not code then return false, "nessuno script «" .. MAIN_SCRIPT .. "» nel profilo" end
  local ver = nebbie_ver_from_code(code)
  if ver ~= NEBBIE_EXPECT then
    return false, "profilo v" .. tostring(ver) .. " (serve v" .. NEBBIE_EXPECT .. ")"
  end
  return Nebbie_writeInstallFile(code, silent)
end

function Nebbie_execInstallFile(path, silent)
  if not path then return false, "path nil" end
  path = tostring(path):gsub("\\\\", "/")
  local chunk, lerr = loadfile(path)
  if not chunk then
    local f = io.open(path, "rb")
    if not f then return false, "non apro " .. path .. " (" .. tostring(lerr) .. ")" end
    local code = f:read("*a") or ""
    f:close()
    if #code < 1000 then return false, "file troppo piccolo (" .. #code .. " byte)" end
    chunk, lerr = loadstring(code, "@" .. path)
  end
  if not chunk then return false, "compile: " .. tostring(lerr) end
  if type(setfenv) == "function" then
    local env = getfenv(0)
    if type(env) ~= "table" then env = _G end
    setfenv(chunk, env)
  end
  Nebbie = Nebbie or {{}}
  Nebbie.package = Nebbie.package or "{PACKAGE_NAME}"
  local prevDefer = Nebbie._deferBoot
  Nebbie._deferBoot = true
  local ok, err = pcall(chunk)
  Nebbie._deferBoot = prevDefer
  if not ok then return false, "run: " .. tostring(err) end
  if Nebbie and Nebbie.version == NEBBIE_EXPECT and type(Nebbie.runFix) == "function" then
    if not silent then
      cecho("<green>Nebbie v" .. NEBBIE_EXPECT .. " caricato.\\n")
    end
    return true
  end
  return false, "post ver=" .. tostring(Nebbie and Nebbie.version)
    .. " runFix=" .. tostring(Nebbie and type(Nebbie.runFix))
end

function Nebbie_dofileInstall(silent)
  return Nebbie_execInstallFile(Nebbie_installPath(), silent)
end

function Nebbie_findPackageInstallFile()
  local home = ""
  if type(getMudletHomeDir) == "function" then
    local ok, h = pcall(getMudletHomeDir)
    if ok and h then home = h end
  end
  if home == "" then return nil end
  local sep = "/"
  if home:sub(-1) == "/" or home:sub(-1) == "\\\\" then sep = "" end
  local pkg = "{PACKAGE_NAME}"
  local candidates = {{
    home .. sep .. pkg .. "/" .. INSTALL_FILE,
    home .. sep .. INSTALL_FILE,
  }}
  for _, p in ipairs(candidates) do
    local f = io.open(p, "r")
    if f then
      local head = f:read(4096) or ""
      f:close()
      if nebbie_ver_from_code(head) == NEBBIE_EXPECT then
        return p
      end
    end
  end
  return nil
end

function Nebbie_copyFile(src, dst, silent)
  local rf = io.open(src, "r")
  if not rf then return false, "non leggo " .. tostring(src) end
  local data = rf:read("*a") or ""
  rf:close()
  return Nebbie_writeInstallFile(data, silent)
end

function Nebbie_tryPackageInstall(silent)
  local src = Nebbie_findPackageInstallFile()
  if not src then return false, "install non nel package" end
  if not silent then
    cecho("<grey>Nebbie: install da package <yellow>" .. src .. "\\n")
  end
  local ok, err = Nebbie_execInstallFile(src, silent)
  if ok then
    pcall(function() Nebbie_copyFile(src, Nebbie_installPath(), true) end)
    return true
  end
  if not silent then
    cecho("<orange>Nebbie: package load fallito — " .. tostring(err) .. "\\n")
  end
  return false, err
end

function Nebbie_downloadInstall(callback, silent)
  if Nebbie._downloadPending then
    if callback then callback(false, "download gia in corso") end
    return false, "download gia in corso"
  end
  if type(downloadFile) ~= "function" then
    if callback then callback(false, "downloadFile non disponibile") end
    return false, "downloadFile non disponibile"
  end
  Nebbie._downloadPending = true
  local path = Nebbie_installPath()
  local tmp = path .. ".part"
  pcall(function() os.remove(tmp) end)
  local done = false
  local okHandler, errHandler
  okHandler = registerAnonymousEventHandler("sysDownloadDone", function(_, saveTo)
    if done or saveTo ~= tmp then return end
    done = true
    Nebbie._downloadPending = false
    if okHandler then pcall(function() killAnonymousEventHandler(okHandler) end) end
    if errHandler then pcall(function() killAnonymousEventHandler(errHandler) end) end
    local rf = io.open(tmp, "r")
    if not rf then
      if callback then callback(false, "download vuoto") end
      return
    end
    local data = rf:read("*a") or ""
    rf:close()
    pcall(function() os.remove(tmp) end)
    local ok, err = Nebbie_writeInstallFile(data, true)
    if not ok then
      if callback then callback(false, err) end
      return
    end
    if not silent then
      cecho("<green>Nebbie: scaricato v" .. NEBBIE_EXPECT .. " da GitHub.\\n")
    end
    if callback then callback(true) end
  end, true)
  errHandler = registerAnonymousEventHandler("sysDownloadError", function(_, msg, saveTo)
    if done or saveTo ~= tmp then return end
    done = true
    Nebbie._downloadPending = false
    if okHandler then pcall(function() killAnonymousEventHandler(okHandler) end) end
    if errHandler then pcall(function() killAnonymousEventHandler(errHandler) end) end
    pcall(function() os.remove(tmp) end)
    if callback then callback(false, tostring(msg)) end
  end, true)
  if type(tempTimer) == "function" then
    tempTimer(45, function()
      if done then return end
      done = true
      Nebbie._downloadPending = false
      if okHandler then pcall(function() killAnonymousEventHandler(okHandler) end) end
      if errHandler then pcall(function() killAnonymousEventHandler(errHandler) end) end
      if callback then callback(false, "timeout download (45s)") end
    end)
  end
  downloadFile(tmp, INSTALL_URL)
  if not silent then
    cecho("<yellow>Nebbie: scarico v" .. NEBBIE_EXPECT .. "...\\n")
  end
  return true
end

function Nebbie_neutralizeLegacyScripts(silent)
  local legacy = {{{", ".join(f'"{lua_escape(n)}"' for n in LEGACY_MAIN_SCRIPTS)}}}
  local patterns = {{"Play All v", "Spells and Skills", "Bootloader", "!Nebbie", "nebbie-install"}}
  local n = 0
  for _, pat in ipairs(patterns) do
    for _, id in ipairs(nebbie_find_ids(pat)) do
      if type(disableScript) == "function" and pcall(function() disableScript(id) end) then
        n = n + 1
      end
    end
  end
  if type(setScript) == "function" and type(disableScript) == "function" then
    for _, sname in ipairs(legacy) do
      for occ = 1, 6 do
        local code = nebbie_code(sname, occ)
        if not code then break end
        pcall(function() setScript(sname, "-- disattivato da Nebbie Loader\\nreturn\\n", occ) end)
        pcall(function() disableScript(sname, occ) end)
        n = n + 1
      end
    end
  end
  if not silent and n > 0 then
    cecho("<grey>Nebbie: " .. n .. " script legacy disattivati.\\n")
  end
  return n
end

function Nebbie_loadInstall(silent)
  if Nebbie and Nebbie.version == NEBBIE_EXPECT and type(Nebbie.runFix) == "function" and Nebbie._mainLoaded then
    return true
  end
  if Nebbie_fileVer() == NEBBIE_EXPECT then
    local ok = Nebbie_dofileInstall(silent)
    if ok then return true end
  end
  local pkgOk, pkgErr = Nebbie_tryPackageInstall(silent)
  if pkgOk then return true end
  if not silent and pkgErr then
    cecho("<grey>Nebbie: " .. tostring(pkgErr) .. "\\n")
  end
  local cached = Nebbie_cacheInstallFromProfile(true)
  if cached then
    local ok = Nebbie_dofileInstall(silent)
    if ok then return true end
  end
  return false, pkgErr or "serve download o reinstall package"
end

function Nebbie_loaderBoot()
  if Nebbie and Nebbie._loaderBootDone and Nebbie.version == NEBBIE_EXPECT and Nebbie._mainLoaded then
    return
  end
  Nebbie._loaderBootDone = true
"""
    tail = """
  if Nebbie_loadInstall(true) then
    Nebbie_neutralizeLegacyScripts(true)
    if type(Nebbie.boot) == "function" then
      local ok, err = pcall(Nebbie.boot)
      if not ok then
        cecho("<red>[Nebbie] boot error: " .. tostring(err) .. "\\n")
      end
    end
    return
  end
  if Nebbie_fileVer() ~= NEBBIE_EXPECT then
    Nebbie_downloadInstall(function(ok, err)
      if ok and Nebbie_dofileInstall(false) then
        Nebbie_neutralizeLegacyScripts(true)
        if type(Nebbie.boot) == "function" then pcall(Nebbie.boot) end
      elseif err then
        cecho("<orange>[Nebbie] download fallito: " .. tostring(err) .. " — prova <yellow>nfix<grey>.\\n")
      end
    end, true)
  end
end

if type(enableScript) == "function" then
  pcall(function() enableScript(LOADER_NAME, 1) end)
end
Nebbie_loaderBoot()
"""
    return head + purge_lua + tail


def build_nfix_lua():
    body = f"""
if Nebbie and Nebbie.version == NEBBIE_EXPECT and type(Nebbie.runFix) == "function" then
  Nebbie.runFix()
  cecho("<green>Nebbie v" .. NEBBIE_EXPECT .. " ok.\\n")
else
  local cached = false
  if type(Nebbie_cacheInstallFromProfile) == "function" then
    cached = Nebbie_cacheInstallFromProfile(true)
  end
  Nebbie_cleanupScripts(false)
  Nebbie_wipeMemory()
  local loaded, lerr = false, nil
  if type(Nebbie_loadInstall) == "function" then
    loaded, lerr = Nebbie_loadInstall(false)
  elseif type(Nebbie_tryPackageInstall) == "function" then
    loaded, lerr = Nebbie_tryPackageInstall(false)
  elseif type(Nebbie_execInstallFile) == "function" then
    loaded, lerr = Nebbie_execInstallFile(Nebbie_installPath(), false)
  elseif type(Nebbie_dofileInstall) == "function" then
    loaded, lerr = Nebbie_dofileInstall(false)
  end
  if loaded and Nebbie and type(Nebbie.runFix) == "function" then
    Nebbie.runFix()
    cecho("<green>Nebbie v" .. NEBBIE_EXPECT .. " caricato e reinstallato.\\n")
  elseif type(Nebbie_downloadInstall) == "function" then
    Nebbie_downloadInstall(function(ok, derr)
      if not ok then
        cecho("<red>Nebbie: download fallito — " .. tostring(derr) .. "\\n")
        return
      end
      local ok2, lerr2 = false, "exec mancante"
      if type(Nebbie_execInstallFile) == "function" then
        ok2, lerr2 = Nebbie_execInstallFile(Nebbie_installPath(), false)
      elseif type(Nebbie_dofileInstall) == "function" then
        ok2, lerr2 = Nebbie_dofileInstall(false)
      end
      if ok2 and Nebbie and type(Nebbie.runFix) == "function" then
        Nebbie.runFix()
        cecho("<green>Nebbie v" .. NEBBIE_EXPECT .. " pronto.\\n")
      else
        cecho("<red>Nebbie: fix fallito — " .. tostring(lerr2) .. "\\n")
        cecho("<yellow>Reinstalla package:\\n<grey>   {PKG_URL}\\n")
        cecho("<yellow>Poi <yellow>nfix<grey> di nuovo.\\n")
      end
    end, false)
  else
    local code = nebbie_code(MAIN_SCRIPT, 1)
    local fileVer = (type(Nebbie_fileVer) == "function" and Nebbie_fileVer()) or nebbie_ver_from_code(code)
    cecho("<orange>Install: v" .. tostring(fileVer or "assente") .. " — serve v" .. NEBBIE_EXPECT .. "\\n")
    cecho("<yellow>1)<grey> Alt+O → reinstalla package\\n")
    cecho("<grey>   {PKG_URL}\\n")
    cecho("<yellow>2)<grey> <yellow>nfix\\n")
  end
end"""
    return build_script_cleanup_lua(PKG_VER, MAIN_SCRIPT_NAME) + body


def build_main_bootstrap_lua(expect_ver):
    return f"""-- bootstrap v{expect_ver}: non disattivare lo script principale
if type(findItems) == "function" and type(disableScript) == "function" then
  for _, pat in ipairs({{"Play All v", "Spells and Skills", "Bootloader", "!Nebbie"}}) do
    for _, id in ipairs(findItems(pat, "script", false) or {{}}) do
      pcall(function() disableScript(id) end)
    end
  end
end
if Nebbie and Nebbie.version and Nebbie.version ~= "{expect_ver}" then
  local saved = Nebbie._settings
  Nebbie = {{ package = "nebbie-play-all", _settings = saved or {{}} }}
end
"""


def build_ndiagnose_lua():
    legacy = ", ".join(f'"{lua_escape(n)}"' for n in LEGACY_MAIN_SCRIPTS)
    return f"""cecho("<cyan><b>Nebbie diagnose v{PKG_VER}</b>\\n")
cecho("<grey>memoria Nebbie.version: <yellow>" .. tostring(Nebbie and Nebbie.version) .. "\\n")
cecho("<grey>runFix: <yellow>" .. tostring(Nebbie and type(Nebbie.runFix)) .. "\\n")
cecho("<grey>mainLoaded: <yellow>" .. tostring(Nebbie and Nebbie._mainLoaded) .. "\\n")
if type(Nebbie_installPath) == "function" then
  local path = Nebbie_installPath()
  local fv = (type(Nebbie_fileVer) == "function" and Nebbie_fileVer()) or "?"
  cecho("<grey>install file: <yellow>" .. path .. " <grey>ver=<yellow>" .. tostring(fv) .. "\\n")
end
if type(findItems) == "function" then
  local ids = findItems("Nebbie", "script", false)
  cecho("<grey>findItems Nebbie: <yellow>" .. tostring(ids and #ids or 0) .. " script\\n")
end
if type(getScript) == "function" then
  local names = {{{legacy}, "{lua_escape(MAIN_SCRIPT_NAME)}", "{lua_escape(LOADER_SCRIPT_NAME)}"}}
  for _, sname in ipairs(names) do
    for occ = 1, 4 do
      local ok, code = pcall(function() return getScript(sname, occ) end)
      if ok and code and code ~= -1 and type(code) == "string" then
        local ver = code:match("NEBBIE_INSTALL_VER=([%d%.]+)") or code:match("NEBBIE_LOADER_VER=([%d%.]+)") or code:match("NEBBIE_PKG_VER=([%d%.]+)") or code:match('Nebbie%.version = "([%d%.]+)"') or "?"
        local active = "?"
        if type(isActive) == "function" then
          local ok2, a = pcall(function() return isActive(sname, occ) end)
          if ok2 then active = tostring(a) end
        end
        cecho("<grey> " .. sname .. " #" .. occ .. " ver=" .. ver .. " active=" .. active .. " len=" .. #code .. "\\n")
      end
    end
  end
end
cecho("<grey>Atteso: <yellow>{PKG_VER}<grey> via Loader + dofile\\n")
if type(exists) == "function" then
  cecho("<grey>exists(Loader): <yellow>" .. tostring(exists("{lua_escape(LOADER_SCRIPT_NAME)}", "script")) .. "\\n")
end"""


def build_sysload_script():
    return f"""function Nebbie_sysLoadEvent()
  local ver = "{PKG_VER}"
  if type(enableScript) == "function" then
    pcall(function() enableScript("{LOADER_SCRIPT_NAME}", 1) end)
  end
  if Nebbie and Nebbie.version == ver and type(Nebbie.runFix) == "function" and Nebbie._mainLoaded then
    return
  end
  if type(Nebbie_loaderBoot) == "function" then
    local ok, err = pcall(Nebbie_loaderBoot)
    if not ok then
      cecho("<red>[Nebbie] loader error: " .. tostring(err) .. "\\n")
    elseif Nebbie and Nebbie.version == ver then
      cecho("<green>[Nebbie] v" .. ver .. " caricato (sysLoad).\\n")
    end
  elseif not (Nebbie and Nebbie.version == ver) then
    cecho("<orange>[Nebbie] Loader assente — reinstalla package, poi <yellow>nfix<grey>.\\n")
  end
end"""


def build_nenable_lua():
    return f"""if type(enableScript) == "function" then
  pcall(function() enableScript("{LOADER_SCRIPT_NAME}", 1) end)
end
if type(saveProfile) == "function" then pcall(function() saveProfile() end) end
if type(exists) == "function" then
  cecho("<green>{LOADER_SCRIPT_NAME} exists=" .. tostring(exists("{LOADER_SCRIPT_NAME}", "script")) .. "\\n")
end
if type(Nebbie_loaderBoot) == "function" then
  pcall(Nebbie_loaderBoot)
elseif type(Nebbie_loadInstall) == "function" then
  pcall(Nebbie_loadInstall)
end
cecho("<grey>Se Nebbie.version è ancora nil: <yellow>nfix<grey>.\\n")"""


def build_xml(legacy_aliases, legacy_triggers):
    loader_lua = build_loader_runtime_lua(legacy_aliases, legacy_triggers)
    escaped_loader = loader_lua.replace("]]>", "]]..']]'..[[")
    nfix_script = build_nfix_lua()
    nenable_script = build_nenable_lua()
    sysload_script = build_sysload_script().replace("]]>", "]]..']]'..[[")
    ndiagnose_script = build_ndiagnose_lua()
    npurge_script = (
        'if Nebbie_purgeLegacyPerm then Nebbie_purgeLegacyPerm() end '
        'if Nebbie and Nebbie.purgeLegacyPermItems then Nebbie.purgeLegacyPermItems(false) end '
        'cecho("<green>Nebbie: perm vecchi disattivati. Poi <yellow>nfix<grey>.\\n")'
    )
    nprompt_script = (
        'if Nebbie and Nebbie.debugPrompt then Nebbie.debugPrompt() else '
        + 'cecho("<orange>Nebbie v'
        + PKG_VER
        + ': esegui <yellow>nfix<orange> dopo install package.\\n") end'
    )
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="1.001">
 <ScriptPackage>
  <Script isActive="yes" isFolder="no">
   <name>Nebbie_sysLoadEvent</name>
   <script><![CDATA[{sysload_script}]]></script>
   <eventHandlerList>
    <string>sysLoadEvent</string>
   </eventHandlerList>
   <packageName>{PACKAGE_NAME}</packageName>
  </Script>
  <Script isActive="yes" isFolder="no">
   <name>{LOADER_SCRIPT_NAME}</name>
   <script><![CDATA[{escaped_loader}]]></script>
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
  <Alias isActive="yes" isFolder="no">
   <name>nebbie-enable</name>
   <script><![CDATA[{nenable_script}]]></script>
   <command></command>
   <packageName>{PACKAGE_NAME}</packageName>
   <regex>^nenable$</regex>
  </Alias>
  <Alias isActive="yes" isFolder="no">
   <name>nebbie-diagnose</name>
   <script><![CDATA[{ndiagnose_script}]]></script>
   <command></command>
   <packageName>{PACKAGE_NAME}</packageName>
   <regex>^ndiagnose$</regex>
  </Alias>
 </AliasPackage>
</MudletPackage>
'''


def write_alias_index(path, cast_spells):
    lines = [
        "Nebbie Arcane — indice completo alias Mudlet (generato automaticamente)",
        f"Package: {PACKAGE_NAME} v{PKG_VER} — vedi build-nebbie-package.py",
        "",
        "=== COMANDI PACKAGE ===",
        "  Pattern              | Effetto",
        "  nsetup               | avvia HUD (non cambia il prompt)",
        "  ngui / nhud          | mostra/nasconde pannello buff",
        "  npos                 | riposiziona pannello in alto a destra",
        "  nfix                 | reinstalla alias/trigger",
        "  npurge               | disattiva perm vecchi (poi riavvia e nfix)",
        "  nprompt              | debug parser prompt",
        "  ndiagnose            | diagnostica installazione",
        "  nlist                | indice documentazione",
        "  nlist aliases        | elenca alias installati in Mudlet",
        "  nlist triggers       | elenca trigger installati",
        "  nlist spells         | aiuto incantesimi multi-parola",
        "  ncast                | modalita cast",
        "  nrecall              | modalita recall (stregone)",
        "  nmind                | modalita mind (psi)",
        "  nclass               | elenca classi e slot q1-q9",
        "  nclass <classe>      | imposta classe (m s c d p r I t w k b + u)",
        "  nclass m c           | multiclasse (unisce slot)",
        "  nattrib              | sync attribute (gagged)",
        "  nattrib on/off       | sync automatico ogni 90s",
        "  nloot                | look + corp/2.corp/… + pile/2.pile/…",
        "  nloot on/off         | loot auto dopo kill mob",
        "  usa <arma>           | cambio arma da borsa sulla schiena",
        "  nkey                 | elenco chiavi eq",
        "  nkey add/del         | aggiungi/rimuovi chiave custom",
        "  neq                  | mostra cache eq + sync ora",
        "  neq on/off/clear     | sync eq automatico / svuota cache",
        "  ndrop on/off         | recupero arma caduta",
        "  nfood / nfood on/off | fame/sete auto; nfood item <oggetto>",
        "  return               | torna da polymorph self",
        "",
        "=== TASTIERINO NUMERICO (Num Lock attivo) ===",
        "  Tasto 5              | look",
        "  Tasto 8              | north",
        "  Tasto 2              | south",
        "  Tasto 6              | east",
        "  Tasto 4              | west",
        "  Tasto 9              | up",
        "  Tasto 3              | down",
        "",
        "=== CAST GENERICO (incantesimi multi-parola supportati) ===",
        "  c <spell> [tgt]      | cast 'spell' [tgt] — es. c power word kill goblin",
        "  c '<spell>' [tgt]    | con apici — es. c 'power word kill' goblin",
        "  cast <spell> [tgt]   | come c",
        "  r <spell> [tgt]      | recall 'spell' [tgt]",
        "  m <spell> [tgt]      | mind 'spell' [tgt]",
        "  mem <spell>          | memorize 'spell'",
        "  q1 … q9 [tgt]        | slot rapidi classe attiva",
        "",
        "=== ABBREVIAZIONI INCANTESIMI (pattern ^<abbr>(?: (.+))?$) ===",
    ]
    mud_cmds = parse_mud_commands()
    seen_abbr = set()
    for spell in sorted(cast_spells):
        abbr = ABBREVS.get(spell)
        if abbr and is_safe_standalone_abbr(abbr, mud_cmds) and abbr not in seen_abbr:
            seen_abbr.add(abbr)
            lines.append(f"  ^{abbr}(?: (.+))?$  → {spell}")
    for spell in sorted(MIND_SPELLS):
        if spell in cast_spells:
            continue
        abbr = ABBREVS.get(spell)
        if abbr and is_safe_standalone_abbr(abbr, mud_cmds) and abbr not in seen_abbr:
            seen_abbr.add(abbr)
            lines.append(f"  ^{abbr}(?: (.+))?$  → {spell} (mind)")
    lines.append("")
    lines.append("=== ABBREVIAZIONI SKILL (pattern ^<abbr>(?: (.+))?$) ===")
    seen_skill = set()
    for name, (cmd, hint) in sorted(DEDICATED_SKILLS.items()):
        abbr = ABBREVS.get(name) or ABBREVS.get(cmd) or cmd.replace(" ", "")
        if is_safe_standalone_abbr(abbr, mud_cmds, skill_cmd=cmd) and abbr not in seen_skill:
            seen_skill.add(abbr)
            lines.append(f"  ^{abbr}(?: (.+))?$  → {cmd} {hint}".rstrip())
    lines.append("")
    static_count = 45
    abbr_count = len(seen_abbr) + len(seen_skill)
    fav_count = sum(1 for s in FAVORITE_SPELL_ALIASES if s in cast_spells)
    lines.append(
        f"Totale alias generati all'install: ~{static_count + abbr_count + fav_count + 9} "
        f"(nomi interni: {PACKAGE_NAME}::<nome>)"
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_trigger_index(path):
    lines = [
        "Nebbie Arcane — indice completo trigger Mudlet (generato automaticamente)",
        f"Package: {PACKAGE_NAME} v{PKG_VER}",
        "",
        "=== HUD / PROMPT ===",
        "  [regex] H:\\d+/\\d+.*M:\\d+/\\d+.*V:\\d+/\\d+.*X:\\d+  → parser prompt HP/Mana/Move",
        "  [substring] Tu hai / Spells attivi / Spell :  → gag attribute + sync buff",
        "",
        "=== EQUIP / LOOT ===",
        "  [substring] Stai usando / <impugnato> / <tenuto> / <sulla schiena>  → cache eq",
        "  [substring] il corpo di / corpo sfigurato / pile of dust  → loot manuale/auto",
        "  [regex] La tua esperienza e' aumentata di N punti  → loot auto dopo kill",
        "  [substring] ti cade dalle mani  → recupero arma caduta",
        "  [substring] e ti casca anche  → recupero arma impugnata",
        "  [substring] Hai Fame./sete.  → nfood auto",
        "",
        "=== CAST / BUFF ===",
        "  [substring] Pronunci le parole  → registra buff da messaggio cast",
        "",
        "=== BUFF SCADUTI (wearOff) ===",
    ]
    for label, pat in WEAR_OFF_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    lines.append("=== PRE-SCADENZA (wearOffSoon) ===")
    for label, pat in SOON_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    lines.append("=== AFFECT SELF (apply immediato) ===")
    for label, pat in SELF_AFFECT_APPLY_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    lines.append("=== DEBUFF APPLY ===")
    for label, pat in DEBUFF_APPLY_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    lines.append("=== DEBUFF WEAR-OFF ===")
    for label, pat in DEBUFF_WEAR_OFF_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    lines.append("=== ERRORI CAST / SKILL (failures) ===")
    for label, pat in FAIL_TRIGGERS:
        lines.append(f"  [{label}] substring: {pat}")
    lines.append("")
    total = (
        8
        + len(WEAR_OFF_TRIGGERS)
        + len(SOON_TRIGGERS)
        + len(SELF_AFFECT_APPLY_TRIGGERS)
        + len(DEBUFF_APPLY_TRIGGERS)
        + len(DEBUFF_WEAR_OFF_TRIGGERS)
        + len(FAIL_TRIGGERS)
    )
    lines.append(f"Totale trigger generati all'install: ~{total}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


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
        zf.write(install_lua, INSTALL_FILE)

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
        f.write("  neq                 → mostra cache eq + sync ora\n")
        f.write("  neq on/off          → sync eq automatico ogni 1h (gagged)\n")
        f.write("\n=== TASTIERINO NUMERICO (Num Lock attivo) ===\n")
        f.write("  5=look  8=north  2=south  4=west  6=east  9=up  3=down\n")
        f.write("\n=== DOCUMENTAZIONE ALIAS / TRIGGER ===\n")
        f.write("  nebbie-alias-index.txt    — tutti gli alias e pattern regex\n")
        f.write("  nebbie-trigger-index.txt  — tutti i trigger e pattern\n")
        f.write("  HELP.md                   — guida utente\n")
        f.write("  In gioco: nlist | nlist aliases | nlist triggers | nlist spells\n")
        f.write("\n=== INCANTESIMI MULTI-PAROLA ===\n")
        f.write("  c power word kill bersaglio\n")
        f.write("  c 'power word kill' bersaglio\n")
        f.write("  c magic missile bersaglio\n")
        f.write("  c colour spray\n")
        f.write("\n=== PANNELLO HUD ===\n")
        f.write("  Gauge HP/Mana/Move + buff/debuff + parser prompt [%s]\n")
        for cls, data in sorted(CLASS_PRESETS.items()):
            slots = ", ".join(f"q{i+1}={q[0]}" for i, q in enumerate(data["quick"]))
            f.write(f"  {cls} ({data['name']}): {slots}\n")

    write_alias_index(ROOT / "nebbie-alias-index.txt", cast_spells)
    write_trigger_index(ROOT / "nebbie-trigger-index.txt")
    alias_idx = ROOT / "nebbie-alias-index.txt"
    trigger_idx = ROOT / "nebbie-trigger-index.txt"

    print(f"Wrote {mpackage} ({mpackage.stat().st_size} bytes)")
    print(f"Wrote {ref}")
    print(f"Wrote {alias_idx}")
    print(f"Wrote {trigger_idx}")
    print(f"Cast spells: {len(cast_spells)}")


if __name__ == "__main__":
    main()
