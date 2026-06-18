#!/usr/bin/env python3
"""Generate Nebbie Arcane Mudlet package from spell_parser.cpp spells[] table."""

import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPELL_PARSER = ROOT.parent.parent / "src" / "spell_parser.cpp"
OUT_DIR = ROOT / "nebbie-spells-skills-build"
PACKAGE_NAME = "nebbie-spells-skills"

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
    "armor": "arm", "teleport": "tel", "bless": "ble", "blindness": "blind",
    "burning hands": "bh", "call lightning": "cl", "charm person": "charm",
    "chill touch": "ct", "colour spray": "cs", "create food": "cfood",
    "create water": "cwater", "cure blind": "cblind", "cure critic": "cc",
    "cure light": "clight", "cure serious": "cser", "curse": "curse",
    "detect evil": "dev", "detect invisibility": "dinv", "detect magic": "dmag",
    "detect poison": "dpois", "dispel evil": "de", "dispel good": "dg",
    "dispel magic": "dm", "earthquake": "eq", "enchant weapon": "ewep",
    "energy drain": "edrain", "fireball": "fb", "harm": "harm", "heal": "heal",
    "invisibility": "inv", "lightning bolt": "lb", "locate object": "loc",
    "magic missile": "mm", "poison": "pois", "protection from evil": "pevil",
    "remove curse": "rcurse", "sanctuary": "san", "shocking grasp": "sg",
    "sleep": "sleep", "strength": "str", "summon": "summ", "word of recall": "rec",
    "remove poison": "rpois", "sense life": "slife", "identify": "id",
    "infravision": "infra", "cause light": "cal", "cause critical": "cac",
    "cause serious": "cas", "flamestrike": "fs", "weakness": "weak",
    "knock": "knock", "know alignment": "kalign", "animate dead": "ad",
    "paralyze": "para", "remove paralysis": "rpara", "fear": "fear",
    "acid blast": "ab", "water breath": "wb", "fly": "fly", "cone of cold": "coc",
    "meteor swarm": "ms", "ice storm": "is", "shield": "shld", "fireshield": "fshld",
    "charm monster": "cmon", "refresh": "ref", "second wind": "sw",
    "stone skin": "sskin", "true sight": "tsight", "faerie fire": "ffire",
    "polymorph self": "poly", "mana": "mana", "resurrection": "resu",
    "chain lightning": "chain", "haste": "haste", "slowness": "slow",
    "entangle": "ent", "snare": "snare", "barkskin": "bark", "silence": "sil",
    "heal": "heal", "aid": "aid", "command": "cmd", "feeblemind": "feeble",
    "reincarnate": "reinc", "prismatic spray": "prism", "disintegrate": "disint",
    "enchant armor": "earmor", "mind burn": "mburn", "psychic crush": "pcrush",
    "psionic teleport": "ptel", "levitation": "lev", "telekinesis": "telek",
    "domination": "dom", "mind wipe": "mwipe", "backstab": "bs", "kick": "k",
    "bash": "b", "rescue": "res", "steal": "stl", "sneak": "sn", "hide": "hi",
    "pick": "pick", "track": "tr", "berserk": "berz", "warcry": "wc",
    "lay on hands": "loh", "blessing": "bld", "heroic rescue": "hero",
    "meditate": "med", "blast": "blast", "hypnotize": "hyp", "first aid": "fa",
    "quivering palm": "qp", "feign death": "fd", "springleap": "sl",
    "mantra": "man", "finger": "fin", "daimoku": "dai", "bellow": "bel",
    "brew": "brew", "forge": "forge", "carve": "carve", "doorway": "dw",
    "portal": "port", "summon": "sum", "canibalize": "cani", "flame": "flm",
    "aura": "aura",     "great": "great", "esp": "esp",
    "immolate": "imm", "scry": "scry", "adrenalize": "adr", "pray": "pray",
    "psi shield": "pshld",
    "spy": "spy", "tspy": "tspy", "eavesdrop": "ed", "disguise": "dis",
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

# Scorciatoie rapide per classe (lettera practice in-game) — 9 slot ciascuna (q1-q9)
CLASS_PRESETS = {
    "m": {
        "name": "Mago", "mode": "cast",
        "quick": [
            ("arm", "cast", "armor"), ("shld", "cast", "shield"), ("fly", "cast", "fly"),
            ("mm", "cast", "magic missile"), ("fb", "cast", "fireball"),
            ("lb", "cast", "lightning bolt"), ("inv", "cast", "invisibility"),
            ("str", "cast", "strength"), ("tel", "cast", "teleport"),
        ],
    },
    "s": {
        "name": "Stregone", "mode": "recall",
        "quick": [
            ("arm", "recall", "armor"), ("shld", "recall", "shield"),
            ("mm", "recall", "magic missile"), ("fb", "recall", "fireball"),
            ("lb", "recall", "lightning bolt"), ("inv", "recall", "invisibility"),
            ("str", "recall", "strength"), ("fly", "recall", "fly"),
            ("tel", "recall", "teleport"),
        ],
    },
    "c": {
        "name": "Chierico", "mode": "cast",
        "quick": [
            ("heal", "cast", "heal"), ("cser", "cast", "cure serious"),
            ("cc", "cast", "cure critic"), ("clight", "cast", "cure light"),
            ("ble", "cast", "bless"), ("san", "cast", "sanctuary"),
            ("pevil", "cast", "protection from evil"), ("de", "cast", "dispel evil"),
            ("aid", "cast", "aid"),
        ],
    },
    "d": {
        "name": "Druido", "mode": "cast",
        "quick": [
            ("bark", "cast", "barkskin"), ("cl", "cast", "call lightning"),
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
            ("tr", "skill", "track"), ("clight", "cast", "cure light"),
            ("bark", "cast", "barkskin"), ("camo", "skill", "camouflage"),
            ("sn", "skill", "sneak"), ("carve", "skill", "carve"),
            ("ffood", "skill", "find food"), ("fwater", "skill", "find water"),
            ("ent", "cast", "entangle"),
        ],
    },
    "I": {
        "name": "Psionista", "mode": "mind",
        "quick": [
            ("pshld", "skill", "psi shield"), ("mb", "mind", "mindblank"),
            ("pcrush", "mind", "psychic crush"), ("lev", "mind", "levitation"),
            ("ptel", "mind", "psionic teleport"), ("med", "skill", "meditate"),
            ("blast", "skill", "psionic blast"), ("dw", "skill", "doorway"),
            ("port", "skill", "psi portal"),
        ],
    },
    "t": {
        "name": "Ladro", "mode": "cast",
        "quick": [
            ("bs", "skill", "backstab"), ("sn", "skill", "sneak"),
            ("hi", "skill", "hide"), ("stl", "skill", "steal"),
            ("pick", "skill", "pick"), ("spy", "skill", "spy"),
            ("tspy", "skill", "tspy"), ("dis", "skill", "disguise"),
            ("ed", "skill", "eavesdrop"),
        ],
    },
    "w": {
        "name": "Guerriero", "mode": "cast",
        "quick": [
            ("k", "skill", "kick"), ("b", "skill", "bash"),
            ("res", "skill", "rescue"), ("disarm", "skill", "disarm"),
            ("bel", "skill", "bellow"), ("parry", "skill", "parry"),
            ("fa", "skill", "first aid"), ("dbash", "skill", "doorbash"),
            ("climb", "skill", "climb"),
        ],
    },
    "k": {
        "name": "Monaco", "mode": "cast",
        "quick": [
            ("man", "skill", "mantra"), ("fin", "skill", "finger"),
            ("qp", "skill", "quivering palm"), ("sl", "skill", "springleap"),
            ("fd", "skill", "feign death"), ("k", "skill", "kick"),
            ("b", "skill", "bash"), ("dai", "skill", "daimoku"),
            ("fa", "skill", "first aid"),
        ],
    },
    "b": {
        "name": "Barbaro", "mode": "cast",
        "quick": [
            ("berz", "skill", "berserk"), ("bel", "skill", "bellow"),
            ("k", "skill", "kick"), ("b", "skill", "bash"),
            ("camo", "skill", "camouflage"), ("ffood", "skill", "find food"),
            ("fwater", "skill", "find water"), ("tan", "skill", "tan"),
            ("fa", "skill", "first aid"),
        ],
    },
}

CLASS_VAR = "nebbie_class"


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


def build_install_lua(spells):
    cast_spells = build_cast_spell_list(spells)
    lines = []
    lines.append("-- Nebbie Arcane: spell & skill aliases/triggers (auto-generated)")
    lines.append("Nebbie = Nebbie or {}")
    lines.append("")
    lines.append("Nebbie.package = 'nebbie-spells-skills'")
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
    lines.append("Nebbie.buffDurations = {")
    for k, v in sorted(BUFF_DURATIONS.items()):
        lines.append(f"  ['{lua_escape(k)}'] = {v},")
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
    lines.append(INSTALLER_LUA)
    return "\n".join(lines)


INSTALLER_LUA = r'''
Nebbie.version = "1.0.5"
Nebbie.buffs = Nebbie.buffs or {}
Nebbie._aliasNames = Nebbie._aliasNames or {}
Nebbie._triggerNames = Nebbie._triggerNames or {}
Nebbie.playerClass = Nebbie.playerClass or nil

local PKG = Nebbie.package
local CLASS_VAR = "nebbie_class"

function Nebbie.now()
  if type(getEpoch) == "function" then
    return getEpoch()
  end
  if type(getEpochTime) == "function" then
    return getEpochTime()
  end
  return os.time()
end

function Nebbie.stripColors(line)
  return line:gsub("%$c%d%d%d%d", "")
end

function Nebbie.setCastMode(mode)
  if mode ~= "cast" and mode ~= "recall" and mode ~= "mind" then
    cecho("<orange>Modalita' cast: cast | recall | mind\n")
    return
  end
  Nebbie.castMode = mode
  cecho("<green>Nebbie cast mode: <yellow>" .. mode .. "\n")
  Nebbie.refreshGUI()
end

function Nebbie.listClasses()
  cecho("<cyan><b>Classi Nebbie</b> <grey>(una per profilo Mudlet, salvata con nclass):\n")
  local order = {"m", "s", "c", "d", "p", "r", "I", "t", "w", "k", "b"}
  for _, cls in ipairs(order) do
    local preset = Nebbie.classes[cls]
    if preset then
      local mark = (cls == Nebbie.playerClass) and "<green>* " or "  "
      local slots = {}
      for i, q in ipairs(preset.quick) do slots[i] = "q" .. i .. "=" .. q.abbr end
      cecho(mark .. "<yellow>" .. cls .. " <white>" .. preset.name
        .. " <grey>[" .. table.concat(slots, " ") .. "]\n")
    end
  end
end

function Nebbie.saveClass(cls)
  setVariable(CLASS_VAR, cls)
end

function Nebbie.loadClass()
  local saved = getVariable(CLASS_VAR)
  if saved and saved ~= "" and Nebbie.classes[saved] then
    Nebbie.setClass(saved, true)
    return true
  end
  return false
end

function Nebbie.setClass(cls, silent)
  local preset = Nebbie.classes[cls]
  if not preset then
    if not silent then
      cecho("<orange>Classi: m s c d p r I t w k b — es. <yellow>nclass m<grey> | <yellow>nclass<grey> elenca tutte\n")
    end
    return false
  end
  Nebbie.playerClass = cls
  Nebbie.saveClass(cls)
  Nebbie.castMode = preset.mode
  if not silent then
    cecho("<green>Classe Nebbie: <yellow>" .. preset.name .. " <grey>(" .. cls .. ") <grey>salvata per questo profilo.\n")
  else
    cecho("<green>Nebbie: profilo <yellow>" .. preset.name .. " <grey>(" .. cls .. ", " .. preset.mode .. ")\n")
  end
  Nebbie.refreshGUI()
  return true
end

function Nebbie.formatTime(secs)
  secs = math.max(0, math.floor(secs))
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

function Nebbie.onBuffApplied(spell)
  local dur = Nebbie.buffDurations[spell] or 0
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = dur,
    soon = false,
    active = true,
  }
  Nebbie.buffs._lastCast = spell
  Nebbie.refreshGUI()
end

function Nebbie.onBuffWearOff(spell)
  Nebbie.buffs[spell] = nil
  Nebbie.refreshGUI()
end

function Nebbie.onBuffSoon(spell)
  if Nebbie.buffs[spell] then
    Nebbie.buffs[spell].soon = true
  else
    Nebbie.buffs[spell] = { since = Nebbie.now(), duration = 0, soon = true, active = true }
  end
  Nebbie.refreshGUI()
end

function Nebbie.execQuick(entry, target)
  if entry.kind == "cast" then
    Nebbie.sendCast(entry.target, target)
  elseif entry.kind == "recall" then
    local cmd = "recall '" .. entry.target .. "'"
    if target and target ~= "" then cmd = cmd .. " " .. target end
    send(cmd)
  elseif entry.kind == "mind" then
    local cmd = "mind '" .. entry.target .. "'"
    if target and target ~= "" then cmd = cmd .. " " .. target end
    send(cmd)
  elseif entry.kind == "skill" then
    local info = Nebbie.dedicatedSkills[entry.target]
    local cmd = info and info.cmd or entry.target
    if target and target ~= "" then send(cmd .. " " .. target) else send(cmd) end
  end
end

function Nebbie.stopGUI()
  if Nebbie.guiTimer then
    killTimer(Nebbie.guiTimer)
    Nebbie.guiTimer = nil
  end
end

function Nebbie.initGUI()
  Nebbie.stopGUI()
  if not Nebbie.buffConsole then
    local _, sh = getMainWindowSize()
    local h, w = 200, 250
    createMiniConsole("NebbieBuffs", 10, math.max(10, sh - h - 10), w, h, true)
    setMiniConsoleFontSize("NebbieBuffs", 9)
    setBackgroundColor("NebbieBuffs", 20, 20, 30, 220)
    setFgColor("NebbieBuffs", 200, 200, 200)
    showWindow("NebbieBuffs")
    Nebbie.buffConsole = true
  end
  Nebbie.guiTimer = tempTimer(1, function() Nebbie.refreshGUI() end, true)
end

function Nebbie.toggleGUI()
  if isHidden("NebbieBuffs") then showWindow("NebbieBuffs") else hideWindow("NebbieBuffs") end
end

function Nebbie.refreshGUI()
  if not Nebbie.buffConsole then return end
  local ok, err = pcall(function()
    clearUserWindow("NebbieBuffs")

    local classLine = "(nclass non impostata)"
    local modeLine = tostring(Nebbie.castMode or "cast")
    if Nebbie.playerClass and Nebbie.playerClass ~= "" then
      local preset = Nebbie.classes[Nebbie.playerClass]
      if preset then
        classLine = tostring(preset.name or "?") .. " (" .. tostring(Nebbie.playerClass) .. ")"
        modeLine = tostring(preset.mode or modeLine)
      else
        classLine = "classe sconosciuta (" .. tostring(Nebbie.playerClass) .. ")"
      end
    end

    cecho("NebbieBuffs", "<cyan><b>=== Nebbie Buffs v" .. Nebbie.version .. " ===</b>\n")
    cecho("NebbieBuffs", "<grey>Classe: <yellow>" .. classLine .. " <grey>| mode: <yellow>" .. modeLine .. "\n")
    local now = Nebbie.now()
    local count = 0
    for spell, data in pairs(Nebbie.buffs) do
      if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
        count = count + 1
        local elapsed = now - (data.since or now)
        local status = "<green>OK"
        local timeTxt = Nebbie.formatTime(elapsed)
        if data.soon then status = "<orange>!" end
        if data.duration and data.duration > 0 then
          local left = data.duration - elapsed
          timeTxt = Nebbie.formatTime(left) .. " <grey>(" .. Nebbie.formatTime(elapsed) .. ")"
          if left <= 0 then status = "<red>SCAD" end
        end
        cecho("NebbieBuffs", status .. " <reset><white>" .. tostring(spell) .. "  <grey>" .. timeTxt .. "\n")
      end
    end
    if count == 0 then
      cecho("NebbieBuffs", "<grey>(nessun buff tracciato)\n")
    end
    local preset = Nebbie.playerClass and Nebbie.classes[Nebbie.playerClass]
    if preset and preset.quick then
      cecho("NebbieBuffs", "<grey>Quick: ")
      for i, q in ipairs(preset.quick) do
        cecho("NebbieBuffs", "<dark_green>q" .. i .. "<grey>=" .. tostring(q.abbr) .. " ")
      end
      cecho("NebbieBuffs", "\n")
    end
  end)
  if not ok then
    cecho("<red>[Nebbie GUI] " .. tostring(err) .. "\n")
  end
end

function Nebbie.resolveSpell(token)
  local lower = token:lower()
  for spell, abbr in pairs(Nebbie.abbrevs) do
    if abbr == lower then return spell end
  end
  for spell, _ in pairs(Nebbie.castSpells) do
    if spell:lower() == lower or spell:lower():gsub(" ", "") == lower:gsub(" ", "") then
      return spell
    end
  end
  for name, _ in pairs(Nebbie.dedicatedSkills) do
    if name:lower() == lower then return name end
  end
  for name, _ in pairs(Nebbie.mindSpells) do
    if name:lower() == lower then return name end
  end
  return token
end

function Nebbie.sendCast(spell, target)
  local mode = Nebbie.castMode
  if Nebbie.mindSpells[spell] then mode = "mind" end
  local cmd
  if mode == "mind" then
    cmd = "mind '" .. spell .. "'"
  elseif mode == "recall" then
    cmd = "recall '" .. spell .. "'"
  else
    cmd = "cast '" .. spell .. "'"
  end
  if target and target ~= "" then cmd = cmd .. " " .. target end
  send(cmd)
end

function Nebbie.uninstall()
  for _, name in ipairs(Nebbie._aliasNames) do
    if exists(name, "alias") ~= 0 then killAlias(name) end
  end
  for _, name in ipairs(Nebbie._triggerNames) do
    if exists(name, "trigger") ~= 0 then disableTrigger(name) end
  end
  if Nebbie.guiTimer then killTimer(Nebbie.guiTimer) end
  Nebbie.stopGUI()
  Nebbie._aliasNames = {}
  Nebbie._triggerNames = {}
  cecho("<orange>Nebbie spells/skills: alias disattivati.\n")
end

function Nebbie.install()
  Nebbie.stopGUI()
  for _, name in ipairs(Nebbie._aliasNames) do
    if exists(name, "alias") ~= 0 then killAlias(name) end
  end
  Nebbie._aliasNames = {}

  local function perm(short, pattern, script)
    local full = PKG .. "::" .. short
    if exists(full, "alias") ~= 0 then killAlias(full) end
    permAlias(full, "", pattern, script)
    if exists(full, "alias") == 0 then
      cecho("<red>[Nebbie] alias non creato: " .. full .. "\n")
    else
      table.insert(Nebbie._aliasNames, full)
    end
  end

  local function trig(short, patterns, script)
    local full = PKG .. "::" .. short
    if exists(full, "trigger") ~= 0 then disableTrigger(full) end
    if type(patterns) == "string" then
      permRegexTrigger(full, "", {patterns}, script)
    else
      permSubstringTrigger(full, "", patterns, script)
    end
    if exists(full, "trigger") ~= 0 then
      table.insert(Nebbie._triggerNames, full)
    end
  end

  -- Cast mode switchers
  perm("mode cast", [[^ncast$]], [[Nebbie.setCastMode("cast")]])
  perm("mode recall", [[^nrecall$]], [[Nebbie.setCastMode("recall")]])
  perm("mode mind", [[^nmind$]], [[Nebbie.setCastMode("mind")]])
  perm("toggle gui", [[^ngui$]], [[Nebbie.toggleGUI()]])
  perm("reinstall fix", [[^nfix$]], [[
    Nebbie.stopGUI()
    Nebbie.install()
    Nebbie.loadClass()
    cecho("<green>Nebbie v" .. Nebbie.version .. " reinstallato. Se vedi ancora errori, disinstalla il package da Alt+O e reinstalla.\n")
  ]])

  -- Generic cast: c <spell> [target]  |  cast <spell> [target]
  perm("generic cast c", [[^c (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    Nebbie.sendCast(spell, target)
  ]])
  perm("generic cast word", [[^cast (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    Nebbie.sendCast(spell, target)
  ]])

  -- Sorcerer memorize / recall shortcuts
  perm("memorize", [[^mem (.+)$]], [[
    local spell = Nebbie.resolveSpell(matches[2])
    send("memorize '" .. spell .. "'")
  ]])
  perm("recall shortcut", [[^r (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    local cmd = "recall '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])

  -- Psi mind shortcut
  perm("mind shortcut", [[^m (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    local cmd = "mind '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])

  -- Per-spell abbreviations (fb, mm, heal, ...)
  for spell, abbr in pairs(Nebbie.abbrevs) do
  if Nebbie.castSpells[spell] or Nebbie.mindSpells[spell] then
    local s = spell:gsub("'", "\\'")
    local a = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    perm("abbr cast " .. abbr, "^" .. a .. "(?: (.+))?$", string.format([[
      local target = matches[2]
      Nebbie.sendCast('%s', target)
    ]], s))
  end
  end

  -- Dedicated skill abbreviations
  for skillName, info in pairs(Nebbie.dedicatedSkills) do
    local abbr = Nebbie.abbrevs[skillName] or Nebbie.abbrevs[info.cmd] or info.cmd:gsub(" ", "")
    abbr = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    local cmd = info.cmd
    perm("skill " .. info.cmd, "^" .. abbr .. "(?: (.+))?$", string.format([[
      local args = matches[2]
      if args and args ~= "" then send("%s " .. args) else send("%s") end
    ]], cmd, cmd))
  end

  -- Class selection: nclass | nclass m | nclass I | ...
  perm("set class", [[^nclass(?: ([A-Za-z]))?$]], [[
    if not matches[2] or matches[2] == "" then
      Nebbie.listClasses()
      return
    end
    Nebbie.setClass(matches[2])
  ]])

  -- Quick slots q1-q9 [target] for current class preset
  for slot = 1, 9 do
    perm("quick slot " .. slot, "^q" .. slot .. "(?: (.+))?$", string.format([[
      local preset = Nebbie.classes[Nebbie.playerClass]
      if not preset or not preset.quick[%d] then
        cecho("<red>Slot q%d non configurato per questa classe.\n")
        return
      end
      Nebbie.execQuick(preset.quick[%d], matches[2])
    ]], slot, slot, slot))
  end

  -- Return from polymorph
  perm("return form", [[^return$]], [[send("return")]])

  -- Buff tracker triggers (substring: ignora codici colore ANSI del MUD)
  trig("cast started", {"Pronunci le parole"}, [[
    local plain = Nebbie.stripColors(line)
    local spell = plain:match("Pronunci le parole, '(.+)'")
    if spell then Nebbie.onBuffApplied(spell) end
  ]])

  for _, entry in ipairs(Nebbie.wearOff) do
    local label = entry.name:gsub("'", "\\'")
    trig("wearoff " .. entry.name, {entry.pattern}, string.format([[
      Nebbie.onBuffWearOff('%s')
      cecho("<grey>[buff] <yellow>%s <grey>scaduto\n")
    ]], label, entry.name))
  end

  for _, entry in ipairs(Nebbie.wearOffSoon) do
    trig("soon " .. entry.name, {entry.pattern}, string.format([[
      Nebbie.onBuffSoon('%s')
      cecho("<grey>[buff] <orange>%s <grey>in scadenza\n")
    ]], entry.name:gsub("'", "\\'"), entry.name))
  end

  for _, entry in ipairs(Nebbie.failures) do
    trig("fail " .. entry.name, {entry.pattern}, string.format([[
      cecho("<grey>[cast] <red>%s<reset>\n")
    ]], entry.name))
  end

  cecho("<green>Nebbie v" .. Nebbie.version .. ": " .. #Nebbie._aliasNames .. " alias, " .. #Nebbie._triggerNames .. " trigger.\n")
  cecho("<grey>Alias: <yellow>c/r/m <spell><grey>, <yellow>q1-q9 [tgt]<grey>, <yellow>nclass<grey>, <yellow>ngui<grey>.\n")
  Nebbie.initGUI()
end

Nebbie.install()
if not Nebbie.loadClass() then
  Nebbie.castMode = Nebbie.castMode or "cast"
  cecho("<grey>Nebbie: imposta la classe con <yellow>nclass m<grey> (m s c d p r I t w k b). Salvata per profilo.\n")
end
'''


def build_xml(lua_body):
    escaped = lua_body.replace("]]>", "]]..']]'..[[")
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="1.001">
 <ScriptPackage>
  <Script isActive="yes" isFolder="no">
   <name>Nebbie Spells and Skills</name>
   <script><![CDATA[{escaped}]]></script>
   <eventHandlerList />
   <packageName>{PACKAGE_NAME}</packageName>
  </Script>
 </ScriptPackage>
</MudletPackage>
'''


def main():
    spells = parse_spells()
    cast_spells = build_cast_spell_list(spells)
    for cls, data in CLASS_PRESETS.items():
        n = len(data["quick"])
        if n != 9:
            raise SystemExit(f"Class {cls} has {n} quick slots, expected 9")
    lua = build_install_lua(spells)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "config.lua").write_text(f'return "{PACKAGE_NAME}"\n', encoding="utf-8")
    xml_name = f"{PACKAGE_NAME}.xml"
    (OUT_DIR / xml_name).write_text(build_xml(lua), encoding="utf-8")
    mpackage = ROOT / f"{PACKAGE_NAME}.mpackage"
    with zipfile.ZipFile(mpackage, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(OUT_DIR / "config.lua", "config.lua")
        zf.write(OUT_DIR / xml_name, xml_name)

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
        f.write("  nclass m            → imposta classe (salvata per profilo Mudlet)\n")
        f.write("  nclass              → elenca tutte le classi e slot q1-q9\n")
        f.write("  q1-q9 [tgt]         → slot rapidi della classe corrente\n")
        f.write("  fb mm heal arm ...  → abbreviazioni rapide\n")
        f.write("\n=== PANNELLO GUI ===\n")
        f.write("  MiniConsole 'NebbieBuffs' in basso a sinistra\n")
        f.write("  Timer buff, stato OK/!/SCAD, countdown stimato\n")
        for cls, data in sorted(CLASS_PRESETS.items()):
            slots = ", ".join(f"q{i+1}={q[0]}" for i, q in enumerate(data["quick"]))
            f.write(f"  {cls} ({data['name']}): {slots}\n")

    print(f"Wrote {mpackage} ({mpackage.stat().st_size} bytes)")
    print(f"Wrote {ref}")
    print(f"Cast spells: {len(cast_spells)}")


if __name__ == "__main__":
    main()
