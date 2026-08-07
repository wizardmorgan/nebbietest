-- NEBBIE_INSTALL_VER=2.2.41
if Nebbie and Nebbie._mainLoaded and Nebbie.version == "2.2.41"
    and type(Nebbie.runFix) == "function" then return end
Nebbie.version = "2.2.41"
-- Nebbie Arcane: spell & skill aliases/triggers (auto-generated)
Nebbie = Nebbie or {}

Nebbie.MAIN_SCRIPT_NAME = "Nebbie Play All"
Nebbie._expectedPkgVer = "2.2.41"

Nebbie.castSpells = {
  ['armor'] = true,
  ['teleport'] = true,
  ['bless'] = true,
  ['blindness'] = true,
  ['burning hands'] = true,
  ['call lightning'] = true,
  ['charm person'] = true,
  ['chill touch'] = true,
  ['clone'] = true,
  ['colour spray'] = true,
  ['control weather'] = true,
  ['create food'] = true,
  ['create water'] = true,
  ['cure blind'] = true,
  ['cure critic'] = true,
  ['cure light'] = true,
  ['curse'] = true,
  ['detect evil'] = true,
  ['detect invisibility'] = true,
  ['detect magic'] = true,
  ['detect poison'] = true,
  ['dispel evil'] = true,
  ['earthquake'] = true,
  ['enchant weapon'] = true,
  ['energy drain'] = true,
  ['fireball'] = true,
  ['harm'] = true,
  ['heal'] = true,
  ['invisibility'] = true,
  ['lightning bolt'] = true,
  ['locate object'] = true,
  ['magic missile'] = true,
  ['poison'] = true,
  ['protection from evil'] = true,
  ['remove curse'] = true,
  ['sanctuary'] = true,
  ['shocking grasp'] = true,
  ['sleep'] = true,
  ['strength'] = true,
  ['summon'] = true,
  ['ventriloquate'] = true,
  ['word of recall'] = true,
  ['remove poison'] = true,
  ['sense life'] = true,
  ['identify'] = true,
  ['infravision'] = true,
  ['cause light'] = true,
  ['cause critical'] = true,
  ['flamestrike'] = true,
  ['dispel good'] = true,
  ['weakness'] = true,
  ['dispel magic'] = true,
  ['knock'] = true,
  ['know alignment'] = true,
  ['animate dead'] = true,
  ['paralyze'] = true,
  ['remove paralysis'] = true,
  ['fear'] = true,
  ['acid blast'] = true,
  ['water breath'] = true,
  ['fly'] = true,
  ['cone of cold'] = true,
  ['meteor swarm'] = true,
  ['ice storm'] = true,
  ['shield'] = true,
  ['monsum one'] = true,
  ['monsum two'] = true,
  ['monsum three'] = true,
  ['monsum four'] = true,
  ['monsum five'] = true,
  ['monsum six'] = true,
  ['monsum seven'] = true,
  ['fireshield'] = true,
  ['charm monster'] = true,
  ['cure serious'] = true,
  ['cause serious'] = true,
  ['refresh'] = true,
  ['second wind'] = true,
  ['turn'] = true,
  ['succor'] = true,
  ['create light'] = true,
  ['continual light'] = true,
  ['calm'] = true,
  ['stone skin'] = true,
  ['conjure elemental'] = true,
  ['true sight'] = true,
  ['minor creation'] = true,
  ['faerie fire'] = true,
  ['faerie fog'] = true,
  ['cacaodemon'] = true,
  ['polymorph self'] = true,
  ['mana'] = true,
  ['astral walk'] = true,
  ['resurrection'] = true,
  ['heroes feast'] = true,
  ['group fly'] = true,
  ['breath'] = true,
  ['web'] = true,
  ['minor track'] = true,
  ['major track'] = true,
  ['golem'] = true,
  ['find familiar'] = true,
  ['changestaff'] = true,
  ['holy word'] = true,
  ['unholy word'] = true,
  ['power word kill'] = true,
  ['power word blind'] = true,
  ['chain lightning'] = true,
  ['scare'] = true,
  ['aid'] = true,
  ['command'] = true,
  ['change form'] = true,
  ['feeblemind'] = true,
  ['shillelagh'] = true,
  ['goodberry'] = true,
  ['elemental blade'] = true,
  ['animal growth'] = true,
  ['insect growth'] = true,
  ['creeping death'] = true,
  ['commune'] = true,
  ['animal summon one'] = true,
  ['animal summon two'] = true,
  ['animal summon three'] = true,
  ['fire servant'] = true,
  ['earth servant'] = true,
  ['water servant'] = true,
  ['wind servant'] = true,
  ['reincarnate'] = true,
  ['charm vegetable'] = true,
  ['vegetable growth'] = true,
  ['tree'] = true,
  ['animate rock'] = true,
  ['tree travel'] = true,
  ['travelling'] = true,
  ['animal friendship'] = true,
  ['invis to animals'] = true,
  ['slow poison'] = true,
  ['entangle'] = true,
  ['snare'] = true,
  ['gust of wind'] = true,
  ['barkskin'] = true,
  ['sunray'] = true,
  ['warp weapon'] = true,
  ['heat stuff'] = true,
  ['firestorm'] = true,
  ['haste'] = true,
  ['slowness'] = true,
  ['dust devil'] = true,
  ['know monster'] = true,
  ['transport via plant'] = true,
  ['speak with plants'] = true,
  ['silence'] = true,
  ['sending'] = true,
  ['teleport without error'] = true,
  ['portal'] = true,
  ['dragon ride'] = true,
  ['mount'] = true,
  ['spring leap'] = true,
  ['geyser'] = true,
  ['mirror images'] = true,
  ['green slime'] = true,
  ['darkness'] = true,
  ['minor invulnerability'] = true,
  ['major invulnerability'] = true,
  ['protection from drain'] = true,
  ['protection from breath'] = true,
  ['anti magic shell'] = true,
  ['psi invisibility'] = true,
  ['protection from evil group'] = true,
  ['prismatic spray'] = true,
  ['incendiary cloud'] = true,
  ['disintegrate'] = true,
  ['comprehend languages'] = true,
  ['protection from fire'] = true,
  ['protection from cold'] = true,
  ['protection from energy'] = true,
  ['protection from electricity'] = true,
  ['enchant armor'] = true,
  ['messenger'] = true,
  ['protection fire breath'] = true,
  ['protection frost breath'] = true,
  ['protection electric breath'] = true,
  ['protection acid breath'] = true,
  ['protection gas breath'] = true,
  ['wizardeye'] = true,
  ['mind burn'] = true,
  ['clairvoyance'] = true,
  ['psionic danger sense'] = true,
  ['psionic disintegrate'] = true,
  ['telekinesis'] = true,
  ['levitation'] = true,
  ['cell adjustment'] = true,
  ['chameleon'] = true,
  ['psionic strength'] = true,
  ['mind over body'] = true,
  ['probability travel'] = true,
  ['psionic teleport'] = true,
  ['domination'] = true,
  ['mind wipe'] = true,
  ['psychic crush'] = true,
  ['tower of iron will'] = true,
  ['mindblank'] = true,
  ['psychic impersonation'] = true,
  ['ultra blast'] = true,
  ['intensify'] = true,
  ['\\n'] = true,
}

Nebbie.mindSpells = {
  ['cell adjustment'] = true,
  ['chameleon'] = true,
  ['clairvoyance'] = true,
  ['domination'] = true,
  ['hypnosis'] = true,
  ['intensify'] = true,
  ['levitation'] = true,
  ['mind burn'] = true,
  ['mind over body'] = true,
  ['mind wipe'] = true,
  ['mindblank'] = true,
  ['probability travel'] = true,
  ['psi invisibility'] = true,
  ['psionic danger sense'] = true,
  ['psionic disintegrate'] = true,
  ['psionic strength'] = true,
  ['psionic teleport'] = true,
  ['psychic crush'] = true,
  ['psychic impersonation'] = true,
  ['telekinesis'] = true,
  ['tower of iron will'] = true,
  ['ultra blast'] = true,
}

Nebbie.dedicatedSkills = {
  ['adrenalize'] = { cmd = 'adrenalize', hint = '<bersaglio>' },
  ['aura sight'] = { cmd = 'aura', hint = '' },
  ['backstab'] = { cmd = 'backstab', hint = '<vittima>' },
  ['bash'] = { cmd = 'bash', hint = '<vittima>' },
  ['bellow'] = { cmd = 'bellow', hint = '' },
  ['berserk'] = { cmd = 'berserk', hint = '' },
  ['blessing'] = { cmd = 'blessing', hint = '<bersaglio>' },
  ['bodyguard'] = { cmd = 'bodyguard', hint = '<bersaglio>' },
  ['brew'] = { cmd = 'brew', hint = '' },
  ['camouflage'] = { cmd = 'camouflage', hint = '' },
  ['canibalize'] = { cmd = 'canibalize', hint = '[numero]' },
  ['carve'] = { cmd = 'carve', hint = '<cadavere>' },
  ['climb'] = { cmd = 'climb', hint = '<direzione>' },
  ['daimoku'] = { cmd = 'daimoku', hint = '' },
  ['disarm'] = { cmd = 'disarm', hint = '<vittima>' },
  ['disguise'] = { cmd = 'disguise', hint = '' },
  ['doorbash'] = { cmd = 'doorbash', hint = '<porta>' },
  ['doorway'] = { cmd = 'doorway', hint = '<nome>' },
  ['eavesdrop'] = { cmd = 'eavesdrop', hint = '' },
  ['esp'] = { cmd = 'esp', hint = '' },
  ['feign death'] = { cmd = 'feign death', hint = '' },
  ['find food'] = { cmd = 'find food', hint = '' },
  ['find traps'] = { cmd = 'find traps', hint = '' },
  ['find water'] = { cmd = 'find water', hint = '' },
  ['finger'] = { cmd = 'finger', hint = '' },
  ['first aid'] = { cmd = 'first aid', hint = '' },
  ['flame shroud'] = { cmd = 'flame', hint = '' },
  ['forge'] = { cmd = 'forge', hint = '<arma> <materiale>' },
  ['great sight'] = { cmd = 'great', hint = '' },
  ['heroic rescue'] = { cmd = 'heroic', hint = '' },
  ['hide'] = { cmd = 'hide', hint = '' },
  ['hypnosis'] = { cmd = 'hypnotize', hint = '<bersaglio>' },
  ['immolation'] = { cmd = 'immolate', hint = '' },
  ['kick'] = { cmd = 'kick', hint = '<vittima>' },
  ['lay on hands'] = { cmd = 'lay on hands', hint = '[bersaglio]' },
  ['mantra'] = { cmd = 'mantra', hint = '' },
  ['meditate'] = { cmd = 'meditate', hint = '' },
  ['memorizing'] = { cmd = 'memorize', hint = '\'<incantesimo>\'' },
  ['parry'] = { cmd = 'parry', hint = '' },
  ['pick'] = { cmd = 'pick', hint = '<porta/cassa>' },
  ['pray'] = { cmd = 'pray', hint = '' },
  ['psi portal'] = { cmd = 'portal', hint = '<nome>' },
  ['psi shield'] = { cmd = 'shield', hint = '' },
  ['psi summon'] = { cmd = 'summon', hint = '<nome>' },
  ['psionic blast'] = { cmd = 'blast', hint = '<bersaglio>' },
  ['quivering palm'] = { cmd = 'quivering palm', hint = '<vittima>' },
  ['ration'] = { cmd = 'carve', hint = '<cadavere>' },
  ['rescue'] = { cmd = 'rescue', hint = '<persona>' },
  ['scry'] = { cmd = 'scry', hint = '<nome>' },
  ['sign language'] = { cmd = 'sign', hint = '' },
  ['sneak'] = { cmd = 'sneak', hint = '' },
  ['spot'] = { cmd = 'spot', hint = '' },
  ['springleap'] = { cmd = 'springleap', hint = '' },
  ['spy'] = { cmd = 'spy', hint = '' },
  ['steal'] = { cmd = 'steal', hint = '<oggetto> <vittima>' },
  ['swim'] = { cmd = 'swim', hint = '' },
  ['tan'] = { cmd = 'tan', hint = '<cadavere> <tipo>' },
  ['track'] = { cmd = 'track', hint = '<nome>' },
  ['tspy'] = { cmd = 'tspy', hint = '' },
  ['warcry'] = { cmd = 'warcry', hint = '' },
}

Nebbie.abbrevs = {
  ['acid blast'] = 'ab',
  ['adrenalize'] = 'adr',
  ['aid'] = 'aid',
  ['animate dead'] = 'adead',
  ['armor'] = 'arm',
  ['aura'] = 'aura',
  ['backstab'] = 'bs',
  ['barkskin'] = 'bark',
  ['bash'] = 'bash',
  ['bellow'] = 'bel',
  ['berserk'] = 'berz',
  ['blast'] = 'blast',
  ['bless'] = 'ble',
  ['blessing'] = 'bld',
  ['blindness'] = 'blind',
  ['bodyguard'] = 'bg',
  ['brew'] = 'brew',
  ['burning hands'] = 'bh',
  ['call lightning'] = 'clightn',
  ['camouflage'] = 'camo',
  ['canibalize'] = 'cani',
  ['carve'] = 'carve',
  ['cause critical'] = 'cac',
  ['cause light'] = 'cal',
  ['cause serious'] = 'cas',
  ['chain lightning'] = 'chain',
  ['charm monster'] = 'cmon',
  ['charm person'] = 'charm',
  ['chill touch'] = 'ct',
  ['climb'] = 'climb',
  ['colour spray'] = 'cs',
  ['command'] = 'cmd',
  ['cone of cold'] = 'coc',
  ['create food'] = 'cfood',
  ['create water'] = 'cwater',
  ['cure blind'] = 'cblind',
  ['cure critic'] = 'cc',
  ['cure light'] = 'clight',
  ['cure serious'] = 'cser',
  ['curse'] = 'curse',
  ['daimoku'] = 'dai',
  ['detect evil'] = 'dev',
  ['detect invisibility'] = 'dinv',
  ['detect magic'] = 'dmag',
  ['detect poison'] = 'dpois',
  ['disarm'] = 'disarm',
  ['disguise'] = 'disguise',
  ['disintegrate'] = 'disint',
  ['dispel evil'] = 'devl',
  ['dispel good'] = 'dg',
  ['dispel magic'] = 'dm',
  ['domination'] = 'dom',
  ['doorbash'] = 'dbash',
  ['doorway'] = 'dw',
  ['earthquake'] = 'ea',
  ['eavesdrop'] = 'eaves',
  ['enchant armor'] = 'earmor',
  ['enchant weapon'] = 'ewep',
  ['energy drain'] = 'edrain',
  ['entangle'] = 'ent',
  ['esp'] = 'esp',
  ['faerie fire'] = 'ffire',
  ['fear'] = 'fear',
  ['feeblemind'] = 'feeble',
  ['feign death'] = 'fd',
  ['find food'] = 'ffood',
  ['find traps'] = 'ftrap',
  ['find water'] = 'fwater',
  ['finger'] = 'fin',
  ['fireball'] = 'fb',
  ['fireshield'] = 'fshld',
  ['first aid'] = 'faid',
  ['flame'] = 'flm',
  ['flamestrike'] = 'fs',
  ['fly'] = 'fly',
  ['forge'] = 'forge',
  ['great'] = 'great',
  ['harm'] = 'harm',
  ['haste'] = 'haste',
  ['heal'] = 'heal',
  ['heroic rescue'] = 'hero',
  ['hide'] = 'hide',
  ['hypnotize'] = 'hyp',
  ['ice storm'] = 'is',
  ['identify'] = 'ident',
  ['immolate'] = 'imm',
  ['infravision'] = 'infra',
  ['invisibility'] = 'invis',
  ['kick'] = 'kick',
  ['knock'] = 'knock',
  ['know alignment'] = 'kalign',
  ['lay on hands'] = 'loh',
  ['levitation'] = 'lev',
  ['lightning bolt'] = 'lb',
  ['locate object'] = 'loc',
  ['magic missile'] = 'mm',
  ['mana'] = 'mana',
  ['mantra'] = 'man',
  ['meditate'] = 'medit',
  ['memorize'] = 'mem',
  ['meteor swarm'] = 'ms',
  ['mind burn'] = 'mburn',
  ['mind wipe'] = 'mwipe',
  ['mirror images'] = 'mirr',
  ['paralyze'] = 'para',
  ['parry'] = 'parry',
  ['pick'] = 'picklock',
  ['poison'] = 'pois',
  ['polymorph self'] = 'poly',
  ['portal'] = 'psiport',
  ['pray'] = 'pray',
  ['prismatic spray'] = 'prism',
  ['protection from evil'] = 'pevil',
  ['psi shield'] = 'pshld',
  ['psionic teleport'] = 'ptel',
  ['psychic crush'] = 'pcrush',
  ['quivering palm'] = 'qp',
  ['refresh'] = 'ref',
  ['reincarnate'] = 'reinc',
  ['remove curse'] = 'rcurse',
  ['remove paralysis'] = 'rpara',
  ['remove poison'] = 'rpois',
  ['rescue'] = 'resc',
  ['resurrection'] = 'resu',
  ['sanctuary'] = 'san',
  ['scry'] = 'scry',
  ['second wind'] = 'sw',
  ['sense life'] = 'slife',
  ['shield'] = 'shld',
  ['shocking grasp'] = 'sg',
  ['silence'] = 'sil',
  ['sleep'] = 'csleep',
  ['slowness'] = 'slow',
  ['snare'] = 'snare',
  ['sneak'] = 'snk',
  ['spot'] = 'spot',
  ['springleap'] = 'leap',
  ['spy'] = 'spy',
  ['steal'] = 'stl',
  ['stone skin'] = 'sskin',
  ['strength'] = 'str',
  ['summon'] = 'sum',
  ['swim'] = 'swim',
  ['tan'] = 'tan',
  ['telekinesis'] = 'telek',
  ['teleport'] = 'tele',
  ['track'] = 'track',
  ['true sight'] = 'tsight',
  ['tspy'] = 'tspy',
  ['warcry'] = 'wc',
  ['water breath'] = 'wb',
  ['weakness'] = 'weak',
  ['word of recall'] = 'wrec',
}

Nebbie.wearOff = {
  { name = 'armor', pattern = 'armatura magica' },
  { name = 'bless', pattern = 'benedizione Divina' },
  { name = 'invisibility', pattern = 'Torni visibile.' },
  { name = 'sanctuary', pattern = 'aura bianca che ti circondava svanisce' },
  { name = 'fly', pattern = 'capacita\' di volare svanisce' },
  { name = 'haste', pattern = 'Senti i tuoi movimenti rallentare' },
  { name = 'fireshield', pattern = 'scudo di fuoco' },
  { name = 'stone skin', pattern = 'pelle torna normale' },
  { name = 'shield', pattern = 'scudo magico si dissolve' },
  { name = 'sneak', pattern = 'Smetti di muoverti silenziosamente' },
  { name = 'meditate', pattern = 'meditato abbastanza' },
  { name = 'psi shield', pattern = 'creata dalla tua mente tremola' },
  { name = 'barkskin', pattern = 'pelle perde la consistenza' },
  { name = 'faerie fire', pattern = 'alone rosa' },
  { name = 'mirror images', pattern = 'immagine illusoria' },
  { name = 'strength', pattern = 'Non ti senti piu\' cosi\'' },
  { name = 'detect magic', pattern = 'presenza della magia' },
  { name = 'detect invisibility', pattern = 'vedere l\'invisibile' },
  { name = 'protection from evil', pattern = 'protezione dal Male' },
  { name = 'anti magic shell', pattern = 'anti-magia' },
  { name = 'globe darkness', pattern = 'globo di oscurita\'' },
  { name = 'minor invulnerability', pattern = 'globo protettivo attorno al tuo corpo si dissolve' },
  { name = 'lay on hands', pattern = 'Puoi curarti di nuovo' },
  { name = 'blessing', pattern = 'Puoi invocare i tuoi Dei di nuovo' },
  { name = 'first aid', pattern = 'Puoi medicarti di nuovo' },
  { name = 'spy', pattern = 'Puoi spiare di nuovo' },
  { name = 'disguise', pattern = 'Puoi mascherarti nuovamente' },
  { name = 'adrenalize', pattern = 'furia scompare' },
  { name = 'psionic blast', pattern = 'cervello si sta lentamente riprendendo' },
  { name = 'polymorph', pattern = 'Ritorni alla tua forma originale' },
  { name = 'web', pattern = 'ti liberi dalle ragnatele' },
  { name = 'paralyze', pattern = 'Lentamente ricominci a muoverti' },
  { name = 'paralyze', pattern = 'ricominci a muoverti' },
  { name = 'paralyze', pattern = 'ricomincia a muoversi' },
  { name = 'slowness', pattern = 'movimenti riacquistano la loro velocita' },
  { name = 'blindness', pattern = 'svanire la tua' },
  { name = 'heat stuff', pattern = 'equipaggiamento finalmente si' },
  { name = 'silence', pattern = 'Puoi parlare di nuovo' },
  { name = 'mana', pattern = 'protezione magica scompare' },
  { name = 'aid', pattern = 'Perdi l\'aiuto Divino' },
}

Nebbie.wearOffSoon = {
  { name = 'armor', pattern = 'armatura magica vacilla' },
  { name = 'sanctuary', pattern = 'aura bianca che ti circonda inizia' },
  { name = 'shield', pattern = 'scudo magico tremola' },
  { name = 'invisibility', pattern = 'Torni visibile per un momento' },
  { name = 'fly', pattern = 'stai perdendo la capacita\' di volare' },
}

Nebbie.failures = {
  { name = 'concentrazione', pattern = 'Perdi la tua concentrazione' },
  { name = 'no_mana', pattern = 'Non hai abbastanza' },
  { name = 'no_level', pattern = 'Devi ancora crescere' },
  { name = 'no_mem', pattern = 'Non hai questo incantesimo memorizzato' },
  { name = 'usa_mind', pattern = 'Usa la mente' },
  { name = 'usa_recall', pattern = 'Usa la memoria' },
  { name = 'no_quotes', pattern = 'simboli sacri della' },
  { name = 'unknown', pattern = 'Fantastico! Non e\' successo nulla' },
  { name = 'unimplemented', pattern = 'non e\' stato ancora inventato' },
  { name = 'backfire', pattern = 'ti si ritorce contro' },
  { name = 'fizzle', pattern = 'fallisce miseramente' },
  { name = 'no_magic_zone', pattern = 'Il mana si rifusa di scorrere' },
  { name = 'no_mind_zone', pattern = 'Non riesci a concentrarti abbastanza in questo posto' },
  { name = 'anti_magic', pattern = 'scudo anti-magia' },
  { name = 'first_aid_cd', pattern = 'Devi aspettare ancora un po\' prima di poter medicare' },
  { name = 'kick_fail', pattern = 'Non riesci ad avvicinarti abbastanza per calciare' },
  { name = 'backstab_fail', pattern = 'Non riesci ad avvicinarti abbastanza' },
}

Nebbie.debuffSpells = {
  ['web'] = true,
  ['paralyze'] = true,
  ['slowness'] = true,
  ['blindness'] = true,
  ['fear'] = true,
  ['heat stuff'] = true,
  ['silence'] = true,
}

Nebbie.selfAffectApply = {
  { name = 'web', pattern = 'ragnatele che ti avvolgono' },
  { name = 'web', pattern = 'ricopert' },
  { name = 'paralyze', pattern = 'Sei paralizzato' },
  { name = 'slowness', pattern = 'mondo stia rallentando' },
  { name = 'blindness', pattern = 'accecat' },
  { name = 'heat stuff', pattern = 'frigge' },
  { name = 'fear', pattern = 'presa dal panico' },
  { name = 'silence', pattern = 'non riesci a parlare' },
}

Nebbie.debuffApply = {
  { name = 'poison', pattern = 'appare molto sofferente' },
  { name = 'curse', pattern = 'maledett' },
  { name = 'feeblemind', pattern = 'rimbecillit' },
}

Nebbie.debuffWearOff = {
  { name = 'poison', pattern = 'veleno non scorre' },
  { name = 'poison', pattern = 'sembrano meno forti ora' },
  { name = 'curse', pattern = 'Ti senti molto meglio' },
  { name = 'feeblemind', pattern = 'piu\' intelligente' },
}

Nebbie.safeStandalone = {
  ['ab'] = true,
  ['adead'] = true,
  ['aid'] = true,
  ['arm'] = true,
  ['aura'] = true,
  ['bark'] = true,
  ['bash'] = true,
  ['berz'] = true,
  ['bg'] = true,
  ['blast'] = true,
  ['bld'] = true,
  ['ble'] = true,
  ['blind'] = true,
  ['brew'] = true,
  ['bs'] = true,
  ['carve'] = true,
  ['cblind'] = true,
  ['cc'] = true,
  ['cfood'] = true,
  ['chain'] = true,
  ['charm'] = true,
  ['clight'] = true,
  ['clightn'] = true,
  ['climb'] = true,
  ['cmd'] = true,
  ['cmon'] = true,
  ['coc'] = true,
  ['cs'] = true,
  ['cser'] = true,
  ['csleep'] = true,
  ['ct'] = true,
  ['curse'] = true,
  ['cwater'] = true,
  ['dbash'] = true,
  ['dev'] = true,
  ['devl'] = true,
  ['dinv'] = true,
  ['disarm'] = true,
  ['disguise'] = true,
  ['disint'] = true,
  ['dmag'] = true,
  ['dom'] = true,
  ['dpois'] = true,
  ['ea'] = true,
  ['earmor'] = true,
  ['edrain'] = true,
  ['esp'] = true,
  ['ewep'] = true,
  ['faid'] = true,
  ['fb'] = true,
  ['fd'] = true,
  ['fear'] = true,
  ['feeble'] = true,
  ['ffire'] = true,
  ['ffood'] = true,
  ['flm'] = true,
  ['fly'] = true,
  ['forge'] = true,
  ['fs'] = true,
  ['fshld'] = true,
  ['ftrap'] = true,
  ['fwater'] = true,
  ['great'] = true,
  ['harm'] = true,
  ['haste'] = true,
  ['heal'] = true,
  ['hide'] = true,
  ['ident'] = true,
  ['infra'] = true,
  ['invis'] = true,
  ['is'] = true,
  ['kalign'] = true,
  ['kick'] = true,
  ['knock'] = true,
  ['lb'] = true,
  ['leap'] = true,
  ['loh'] = true,
  ['mana'] = true,
  ['mburn'] = true,
  ['mirr'] = true,
  ['mm'] = true,
  ['ms'] = true,
  ['mwipe'] = true,
  ['para'] = true,
  ['parry'] = true,
  ['pcrush'] = true,
  ['pevil'] = true,
  ['picklock'] = true,
  ['pois'] = true,
  ['poly'] = true,
  ['pray'] = true,
  ['prism'] = true,
  ['pshld'] = true,
  ['psiport'] = true,
  ['ptel'] = true,
  ['qp'] = true,
  ['rcurse'] = true,
  ['reinc'] = true,
  ['resu'] = true,
  ['rpara'] = true,
  ['rpois'] = true,
  ['san'] = true,
  ['scry'] = true,
  ['sg'] = true,
  ['shld'] = true,
  ['slife'] = true,
  ['slow'] = true,
  ['snare'] = true,
  ['snk'] = true,
  ['spot'] = true,
  ['spy'] = true,
  ['sskin'] = true,
  ['stl'] = true,
  ['swim'] = true,
  ['tan'] = true,
  ['telek'] = true,
  ['track'] = true,
  ['tsight'] = true,
  ['tspy'] = true,
  ['wb'] = true,
  ['wc'] = true,
  ['weak'] = true,
  ['wrec'] = true,
  ['sign'] = true,
}

Nebbie.buffDurations = {
  ['aid'] = 1800,
  ['anti magic shell'] = 1800,
  ['armor'] = 1800,
  ['barkskin'] = 1800,
  ['bless'] = 1800,
  ['chameleon'] = 1800,
  ['detect invisibility'] = 1800,
  ['detect magic'] = 1800,
  ['faerie fire'] = 900,
  ['fireshield'] = 1800,
  ['fly'] = 1800,
  ['haste'] = 1800,
  ['invisibility'] = 1800,
  ['levitation'] = 1800,
  ['mana'] = 1800,
  ['mindblank'] = 1800,
  ['minor invulnerability'] = 1800,
  ['mirror images'] = 900,
  ['protection from evil'] = 1800,
  ['psi shield'] = 1800,
  ['psionic strength'] = 1800,
  ['sanctuary'] = 1800,
  ['shield'] = 1800,
  ['stone skin'] = 1800,
  ['strength'] = 1800,
  ['tower of iron will'] = 1800,
}

Nebbie.noBuffSpells = {
  ['acid blast'] = true,
  ['animate dead'] = true,
  ['astral walk'] = true,
  ['burning hands'] = true,
  ['chain lightning'] = true,
  ['charm monster'] = true,
  ['charm person'] = true,
  ['chill touch'] = true,
  ['clairvoyance'] = true,
  ['colour spray'] = true,
  ['cone of cold'] = true,
  ['continual light'] = true,
  ['create food'] = true,
  ['create light'] = true,
  ['create water'] = true,
  ['cure critic'] = true,
  ['cure light'] = true,
  ['cure serious'] = true,
  ['curse'] = true,
  ['darkness'] = true,
  ['dispel evil'] = true,
  ['dispel good'] = true,
  ['dispel magic'] = true,
  ['earthquake'] = true,
  ['enchant armor'] = true,
  ['enchant weapon'] = true,
  ['energy drain'] = true,
  ['faerie fog'] = true,
  ['feeblemind'] = true,
  ['fireball'] = true,
  ['flamestrike'] = true,
  ['geyser'] = true,
  ['green slime'] = true,
  ['harm'] = true,
  ['heal'] = true,
  ['heroes feast'] = true,
  ['ice storm'] = true,
  ['identify'] = true,
  ['incendiary cloud'] = true,
  ['knock'] = true,
  ['lightning bolt'] = true,
  ['locate object'] = true,
  ['magic missile'] = true,
  ['messenger'] = true,
  ['meteor swarm'] = true,
  ['poison'] = true,
  ['refresh'] = true,
  ['reincarnate'] = true,
  ['remove curse'] = true,
  ['resurrection'] = true,
  ['second wind'] = true,
  ['shocking grasp'] = true,
  ['sleep'] = true,
  ['summon'] = true,
  ['teleport'] = true,
  ['turn'] = true,
  ['weakness'] = true,
  ['wizardeye'] = true,
  ['word of recall'] = true,
}

Nebbie.classes = {
  ['+'] = {
    name = 'Cast universale',
    mode = 'cast',
    quick = {
      { abbr = 'aid', kind = 'cast', target = 'aid' },
      { abbr = 'arm', kind = 'cast', target = 'armor' },
      { abbr = 'ble', kind = 'cast', target = 'bless' },
      { abbr = 'shld', kind = 'cast', target = 'shield' },
      { abbr = 'sskin', kind = 'cast', target = 'stone skin' },
      { abbr = 'mirr', kind = 'cast', target = 'mirror images' },
      { abbr = 'heal', kind = 'cast', target = 'heal' },
      { abbr = 'san', kind = 'cast', target = 'sanctuary' },
      { abbr = 'invis', kind = 'cast', target = 'invisibility' },
    },
  },
  ['I'] = {
    name = 'Psionista',
    mode = 'mind',
    quick = {
      { abbr = 'pshld', kind = 'skill', target = 'psi shield' },
      { abbr = 'mb', kind = 'mind', target = 'mindblank' },
      { abbr = 'pcrush', kind = 'mind', target = 'psychic crush' },
      { abbr = 'lev', kind = 'mind', target = 'levitation' },
      { abbr = 'ptel', kind = 'mind', target = 'psionic teleport' },
      { abbr = 'medit', kind = 'skill', target = 'meditate' },
      { abbr = 'blast', kind = 'skill', target = 'psionic blast' },
      { abbr = 'dw', kind = 'skill', target = 'doorway' },
      { abbr = 'psiport', kind = 'skill', target = 'psi portal' },
    },
  },
  ['b'] = {
    name = 'Barbaro',
    mode = 'cast',
    quick = {
      { abbr = 'berz', kind = 'skill', target = 'berserk' },
      { abbr = 'bel', kind = 'skill', target = 'bellow' },
      { abbr = 'kick', kind = 'skill', target = 'kick' },
      { abbr = 'bash', kind = 'skill', target = 'bash' },
      { abbr = 'camo', kind = 'skill', target = 'camouflage' },
      { abbr = 'ffood', kind = 'skill', target = 'find food' },
      { abbr = 'fwater', kind = 'skill', target = 'find water' },
      { abbr = 'tan', kind = 'skill', target = 'tan' },
      { abbr = 'faid', kind = 'skill', target = 'first aid' },
    },
  },
  ['c'] = {
    name = 'Chierico',
    mode = 'cast',
    quick = {
      { abbr = 'heal', kind = 'cast', target = 'heal' },
      { abbr = 'cser', kind = 'cast', target = 'cure serious' },
      { abbr = 'cc', kind = 'cast', target = 'cure critic' },
      { abbr = 'clight', kind = 'cast', target = 'cure light' },
      { abbr = 'ble', kind = 'cast', target = 'bless' },
      { abbr = 'san', kind = 'cast', target = 'sanctuary' },
      { abbr = 'pevil', kind = 'cast', target = 'protection from evil' },
      { abbr = 'devl', kind = 'cast', target = 'dispel evil' },
      { abbr = 'aid', kind = 'cast', target = 'aid' },
    },
  },
  ['d'] = {
    name = 'Druido',
    mode = 'cast',
    quick = {
      { abbr = 'bark', kind = 'cast', target = 'barkskin' },
      { abbr = 'clightn', kind = 'cast', target = 'call lightning' },
      { abbr = 'ent', kind = 'cast', target = 'entangle' },
      { abbr = 'snare', kind = 'cast', target = 'snare' },
      { abbr = 'clight', kind = 'cast', target = 'cure light' },
      { abbr = 'fly', kind = 'cast', target = 'fly' },
      { abbr = 'sskin', kind = 'cast', target = 'stone skin' },
      { abbr = 'ffood', kind = 'skill', target = 'find food' },
      { abbr = 'brew', kind = 'skill', target = 'brew' },
    },
  },
  ['k'] = {
    name = 'Monaco',
    mode = 'cast',
    quick = {
      { abbr = 'man', kind = 'skill', target = 'mantra' },
      { abbr = 'fin', kind = 'skill', target = 'finger' },
      { abbr = 'qp', kind = 'skill', target = 'quivering palm' },
      { abbr = 'leap', kind = 'skill', target = 'springleap' },
      { abbr = 'fd', kind = 'skill', target = 'feign death' },
      { abbr = 'kick', kind = 'skill', target = 'kick' },
      { abbr = 'bash', kind = 'skill', target = 'bash' },
      { abbr = 'dai', kind = 'skill', target = 'daimoku' },
      { abbr = 'faid', kind = 'skill', target = 'first aid' },
    },
  },
  ['m'] = {
    name = 'Mago',
    mode = 'cast',
    quick = {
      { abbr = 'arm', kind = 'cast', target = 'armor' },
      { abbr = 'shld', kind = 'cast', target = 'shield' },
      { abbr = 'fly', kind = 'cast', target = 'fly' },
      { abbr = 'mm', kind = 'cast', target = 'magic missile' },
      { abbr = 'fb', kind = 'cast', target = 'fireball' },
      { abbr = 'lb', kind = 'cast', target = 'lightning bolt' },
      { abbr = 'invis', kind = 'cast', target = 'invisibility' },
      { abbr = 'str', kind = 'cast', target = 'strength' },
      { abbr = 'tele', kind = 'cast', target = 'teleport' },
    },
  },
  ['p'] = {
    name = 'Paladino',
    mode = 'cast',
    quick = {
      { abbr = 'heal', kind = 'cast', target = 'heal' },
      { abbr = 'loh', kind = 'skill', target = 'lay on hands' },
      { abbr = 'wc', kind = 'skill', target = 'warcry' },
      { abbr = 'ble', kind = 'cast', target = 'bless' },
      { abbr = 'san', kind = 'cast', target = 'sanctuary' },
      { abbr = 'fs', kind = 'cast', target = 'flamestrike' },
      { abbr = 'hero', kind = 'skill', target = 'heroic rescue' },
      { abbr = 'bld', kind = 'skill', target = 'blessing' },
      { abbr = 'pray', kind = 'skill', target = 'pray' },
    },
  },
  ['r'] = {
    name = 'Ranger',
    mode = 'cast',
    quick = {
      { abbr = 'track', kind = 'skill', target = 'track' },
      { abbr = 'clight', kind = 'cast', target = 'cure light' },
      { abbr = 'bark', kind = 'cast', target = 'barkskin' },
      { abbr = 'camo', kind = 'skill', target = 'camouflage' },
      { abbr = 'snk', kind = 'skill', target = 'sneak' },
      { abbr = 'carve', kind = 'skill', target = 'carve' },
      { abbr = 'ffood', kind = 'skill', target = 'find food' },
      { abbr = 'fwater', kind = 'skill', target = 'find water' },
      { abbr = 'ent', kind = 'cast', target = 'entangle' },
    },
  },
  ['s'] = {
    name = 'Stregone',
    mode = 'recall',
    quick = {
      { abbr = 'arm', kind = 'recall', target = 'armor' },
      { abbr = 'shld', kind = 'recall', target = 'shield' },
      { abbr = 'mm', kind = 'recall', target = 'magic missile' },
      { abbr = 'fb', kind = 'recall', target = 'fireball' },
      { abbr = 'lb', kind = 'recall', target = 'lightning bolt' },
      { abbr = 'invis', kind = 'recall', target = 'invisibility' },
      { abbr = 'str', kind = 'recall', target = 'strength' },
      { abbr = 'fly', kind = 'recall', target = 'fly' },
      { abbr = 'tele', kind = 'recall', target = 'teleport' },
    },
  },
  ['t'] = {
    name = 'Ladro',
    mode = 'cast',
    quick = {
      { abbr = 'bs', kind = 'skill', target = 'backstab' },
      { abbr = 'snk', kind = 'skill', target = 'sneak' },
      { abbr = 'hide', kind = 'skill', target = 'hide' },
      { abbr = 'stl', kind = 'skill', target = 'steal' },
      { abbr = 'picklock', kind = 'skill', target = 'pick' },
      { abbr = 'spy', kind = 'skill', target = 'spy' },
      { abbr = 'tspy', kind = 'skill', target = 'tspy' },
      { abbr = 'disguise', kind = 'skill', target = 'disguise' },
      { abbr = 'eaves', kind = 'skill', target = 'eavesdrop' },
    },
  },
  ['w'] = {
    name = 'Guerriero',
    mode = 'cast',
    quick = {
      { abbr = 'kick', kind = 'skill', target = 'kick' },
      { abbr = 'bash', kind = 'skill', target = 'bash' },
      { abbr = 'resc', kind = 'skill', target = 'rescue' },
      { abbr = 'disarm', kind = 'skill', target = 'disarm' },
      { abbr = 'bel', kind = 'skill', target = 'bellow' },
      { abbr = 'parry', kind = 'skill', target = 'parry' },
      { abbr = 'faid', kind = 'skill', target = 'first aid' },
      { abbr = 'dbash', kind = 'skill', target = 'doorbash' },
      { abbr = 'climb', kind = 'skill', target = 'climb' },
    },
  },
}

Nebbie.favoriteSpells = {
  'aid',
  'armor',
  'bless',
  'shield',
  'stone skin',
  'mirror images',
}

Nebbie.legacyPermAliases = {
  "attrib off", "attrib on", "attrib sync", "drop recover off", "drop recover on", "eq cache clear", "eq cache off", "eq cache on", "eq cache sync", "eq key add",
  "eq key del", "eq key list", "food auto off", "food auto on", "food item set", "food manual", "generic cast c", "generic cast word", "install diagnose", "keypad refresh",
  "list aliases", "list classes", "list package help", "list spells ref", "list triggers", "loot manual", "loot off", "loot on", "memorize", "mind shortcut",
  "mode cast", "mode mind", "mode recall", "nebbie-play-all::abbr cast ab", "nebbie-play-all::abbr cast adead", "nebbie-play-all::abbr cast aid", "nebbie-play-all::abbr cast arm", "nebbie-play-all::abbr cast bark", "nebbie-play-all::abbr cast ble", "nebbie-play-all::abbr cast blind",
  "nebbie-play-all::abbr cast cblind", "nebbie-play-all::abbr cast cc", "nebbie-play-all::abbr cast cfood", "nebbie-play-all::abbr cast chain", "nebbie-play-all::abbr cast charm", "nebbie-play-all::abbr cast clight", "nebbie-play-all::abbr cast clightn", "nebbie-play-all::abbr cast cmd", "nebbie-play-all::abbr cast cmon", "nebbie-play-all::abbr cast coc",
  "nebbie-play-all::abbr cast cs", "nebbie-play-all::abbr cast cser", "nebbie-play-all::abbr cast csleep", "nebbie-play-all::abbr cast ct", "nebbie-play-all::abbr cast curse", "nebbie-play-all::abbr cast cwater", "nebbie-play-all::abbr cast dev", "nebbie-play-all::abbr cast devl", "nebbie-play-all::abbr cast dinv", "nebbie-play-all::abbr cast disint",
  "nebbie-play-all::abbr cast dmag", "nebbie-play-all::abbr cast dom", "nebbie-play-all::abbr cast dpois", "nebbie-play-all::abbr cast ea", "nebbie-play-all::abbr cast earmor", "nebbie-play-all::abbr cast edrain", "nebbie-play-all::abbr cast ewep", "nebbie-play-all::abbr cast fb", "nebbie-play-all::abbr cast fear", "nebbie-play-all::abbr cast feeble",
  "nebbie-play-all::abbr cast ffire", "nebbie-play-all::abbr cast fly", "nebbie-play-all::abbr cast fs", "nebbie-play-all::abbr cast fshld", "nebbie-play-all::abbr cast harm", "nebbie-play-all::abbr cast haste", "nebbie-play-all::abbr cast heal", "nebbie-play-all::abbr cast ident", "nebbie-play-all::abbr cast infra", "nebbie-play-all::abbr cast invis",
  "nebbie-play-all::abbr cast is", "nebbie-play-all::abbr cast kalign", "nebbie-play-all::abbr cast knock", "nebbie-play-all::abbr cast lb", "nebbie-play-all::abbr cast mana", "nebbie-play-all::abbr cast mburn", "nebbie-play-all::abbr cast mirr", "nebbie-play-all::abbr cast mm", "nebbie-play-all::abbr cast ms", "nebbie-play-all::abbr cast mwipe",
  "nebbie-play-all::abbr cast para", "nebbie-play-all::abbr cast pcrush", "nebbie-play-all::abbr cast pevil", "nebbie-play-all::abbr cast pois", "nebbie-play-all::abbr cast poly", "nebbie-play-all::abbr cast prism", "nebbie-play-all::abbr cast psiport", "nebbie-play-all::abbr cast ptel", "nebbie-play-all::abbr cast rcurse", "nebbie-play-all::abbr cast reinc",
  "nebbie-play-all::abbr cast resu", "nebbie-play-all::abbr cast rpara", "nebbie-play-all::abbr cast rpois", "nebbie-play-all::abbr cast san", "nebbie-play-all::abbr cast sg", "nebbie-play-all::abbr cast shld", "nebbie-play-all::abbr cast slife", "nebbie-play-all::abbr cast slow", "nebbie-play-all::abbr cast snare", "nebbie-play-all::abbr cast sskin",
  "nebbie-play-all::abbr cast telek", "nebbie-play-all::abbr cast tsight", "nebbie-play-all::abbr cast wb", "nebbie-play-all::abbr cast weak", "nebbie-play-all::abbr cast wrec", "nebbie-play-all::attrib off", "nebbie-play-all::attrib on", "nebbie-play-all::attrib sync", "nebbie-play-all::drop recover off", "nebbie-play-all::drop recover on",
  "nebbie-play-all::eq cache clear", "nebbie-play-all::eq cache off", "nebbie-play-all::eq cache on", "nebbie-play-all::eq cache sync", "nebbie-play-all::eq key add", "nebbie-play-all::eq key del", "nebbie-play-all::eq key list", "nebbie-play-all::fav cast aid", "nebbie-play-all::fav cast armor", "nebbie-play-all::fav cast bless",
  "nebbie-play-all::fav cast mirror images", "nebbie-play-all::fav cast shield", "nebbie-play-all::fav cast stone skin", "nebbie-play-all::food auto off", "nebbie-play-all::food auto on", "nebbie-play-all::food item set", "nebbie-play-all::food manual", "nebbie-play-all::generic cast c", "nebbie-play-all::generic cast word", "nebbie-play-all::install diagnose",
  "nebbie-play-all::keypad refresh", "nebbie-play-all::list aliases", "nebbie-play-all::list classes", "nebbie-play-all::list package help", "nebbie-play-all::list spells ref", "nebbie-play-all::list triggers", "nebbie-play-all::loot manual", "nebbie-play-all::loot off", "nebbie-play-all::loot on", "nebbie-play-all::memorize",
  "nebbie-play-all::mind shortcut", "nebbie-play-all::mode cast", "nebbie-play-all::mode mind", "nebbie-play-all::mode recall", "nebbie-play-all::prompt debug", "nebbie-play-all::quick slot 1", "nebbie-play-all::quick slot 2", "nebbie-play-all::quick slot 3", "nebbie-play-all::quick slot 4", "nebbie-play-all::quick slot 5",
  "nebbie-play-all::quick slot 6", "nebbie-play-all::quick slot 7", "nebbie-play-all::quick slot 8", "nebbie-play-all::quick slot 9", "nebbie-play-all::recall shortcut", "nebbie-play-all::reinstall fix", "nebbie-play-all::reposition gui", "nebbie-play-all::return form", "nebbie-play-all::set class", "nebbie-play-all::setup hud",
  "nebbie-play-all::skill aura", "nebbie-play-all::skill backstab", "nebbie-play-all::skill bash", "nebbie-play-all::skill berserk", "nebbie-play-all::skill blast", "nebbie-play-all::skill blessing", "nebbie-play-all::skill bodyguard", "nebbie-play-all::skill brew", "nebbie-play-all::skill carve", "nebbie-play-all::skill climb",
  "nebbie-play-all::skill disarm", "nebbie-play-all::skill disguise", "nebbie-play-all::skill doorbash", "nebbie-play-all::skill esp", "nebbie-play-all::skill feign death", "nebbie-play-all::skill find food", "nebbie-play-all::skill find traps", "nebbie-play-all::skill find water", "nebbie-play-all::skill first aid", "nebbie-play-all::skill flame",
  "nebbie-play-all::skill forge", "nebbie-play-all::skill great", "nebbie-play-all::skill hide", "nebbie-play-all::skill kick", "nebbie-play-all::skill lay on hands", "nebbie-play-all::skill parry", "nebbie-play-all::skill pick", "nebbie-play-all::skill portal", "nebbie-play-all::skill pray", "nebbie-play-all::skill quivering palm",
  "nebbie-play-all::skill scry", "nebbie-play-all::skill shield", "nebbie-play-all::skill sign", "nebbie-play-all::skill sneak", "nebbie-play-all::skill spot", "nebbie-play-all::skill springleap", "nebbie-play-all::skill spy", "nebbie-play-all::skill steal", "nebbie-play-all::skill swim", "nebbie-play-all::skill tan",
  "nebbie-play-all::skill track", "nebbie-play-all::skill tspy", "nebbie-play-all::skill warcry", "nebbie-play-all::swap weapon", "nebbie-play-all::toggle gui", "nebbie-play-all::toggle hud", "nebbie-spells-skills::abbr cast ab", "nebbie-spells-skills::abbr cast adead", "nebbie-spells-skills::abbr cast aid", "nebbie-spells-skills::abbr cast arm",
  "nebbie-spells-skills::abbr cast bark", "nebbie-spells-skills::abbr cast ble", "nebbie-spells-skills::abbr cast blind", "nebbie-spells-skills::abbr cast cblind", "nebbie-spells-skills::abbr cast cc", "nebbie-spells-skills::abbr cast cfood", "nebbie-spells-skills::abbr cast chain", "nebbie-spells-skills::abbr cast charm", "nebbie-spells-skills::abbr cast clight", "nebbie-spells-skills::abbr cast clightn",
  "nebbie-spells-skills::abbr cast cmd", "nebbie-spells-skills::abbr cast cmon", "nebbie-spells-skills::abbr cast coc", "nebbie-spells-skills::abbr cast cs", "nebbie-spells-skills::abbr cast cser", "nebbie-spells-skills::abbr cast csleep", "nebbie-spells-skills::abbr cast ct", "nebbie-spells-skills::abbr cast curse", "nebbie-spells-skills::abbr cast cwater", "nebbie-spells-skills::abbr cast dev",
  "nebbie-spells-skills::abbr cast devl", "nebbie-spells-skills::abbr cast dinv", "nebbie-spells-skills::abbr cast disint", "nebbie-spells-skills::abbr cast dmag", "nebbie-spells-skills::abbr cast dom", "nebbie-spells-skills::abbr cast dpois", "nebbie-spells-skills::abbr cast ea", "nebbie-spells-skills::abbr cast earmor", "nebbie-spells-skills::abbr cast edrain", "nebbie-spells-skills::abbr cast ewep",
  "nebbie-spells-skills::abbr cast fb", "nebbie-spells-skills::abbr cast fear", "nebbie-spells-skills::abbr cast feeble", "nebbie-spells-skills::abbr cast ffire", "nebbie-spells-skills::abbr cast fly", "nebbie-spells-skills::abbr cast fs", "nebbie-spells-skills::abbr cast fshld", "nebbie-spells-skills::abbr cast harm", "nebbie-spells-skills::abbr cast haste", "nebbie-spells-skills::abbr cast heal",
  "nebbie-spells-skills::abbr cast ident", "nebbie-spells-skills::abbr cast infra", "nebbie-spells-skills::abbr cast invis", "nebbie-spells-skills::abbr cast is", "nebbie-spells-skills::abbr cast kalign", "nebbie-spells-skills::abbr cast knock", "nebbie-spells-skills::abbr cast lb", "nebbie-spells-skills::abbr cast mana", "nebbie-spells-skills::abbr cast mburn", "nebbie-spells-skills::abbr cast mirr",
  "nebbie-spells-skills::abbr cast mm", "nebbie-spells-skills::abbr cast ms", "nebbie-spells-skills::abbr cast mwipe", "nebbie-spells-skills::abbr cast para", "nebbie-spells-skills::abbr cast pcrush", "nebbie-spells-skills::abbr cast pevil", "nebbie-spells-skills::abbr cast pois", "nebbie-spells-skills::abbr cast poly", "nebbie-spells-skills::abbr cast prism", "nebbie-spells-skills::abbr cast psiport",
  "nebbie-spells-skills::abbr cast ptel", "nebbie-spells-skills::abbr cast rcurse", "nebbie-spells-skills::abbr cast reinc", "nebbie-spells-skills::abbr cast resu", "nebbie-spells-skills::abbr cast rpara", "nebbie-spells-skills::abbr cast rpois", "nebbie-spells-skills::abbr cast san", "nebbie-spells-skills::abbr cast sg", "nebbie-spells-skills::abbr cast shld", "nebbie-spells-skills::abbr cast slife",
  "nebbie-spells-skills::abbr cast slow", "nebbie-spells-skills::abbr cast snare", "nebbie-spells-skills::abbr cast sskin", "nebbie-spells-skills::abbr cast telek", "nebbie-spells-skills::abbr cast tsight", "nebbie-spells-skills::abbr cast wb", "nebbie-spells-skills::abbr cast weak", "nebbie-spells-skills::abbr cast wrec", "nebbie-spells-skills::attrib off", "nebbie-spells-skills::attrib on",
  "nebbie-spells-skills::attrib sync", "nebbie-spells-skills::drop recover off", "nebbie-spells-skills::drop recover on", "nebbie-spells-skills::eq cache clear", "nebbie-spells-skills::eq cache off", "nebbie-spells-skills::eq cache on", "nebbie-spells-skills::eq cache sync", "nebbie-spells-skills::eq key add", "nebbie-spells-skills::eq key del", "nebbie-spells-skills::eq key list",
  "nebbie-spells-skills::fav cast aid", "nebbie-spells-skills::fav cast armor", "nebbie-spells-skills::fav cast bless", "nebbie-spells-skills::fav cast mirror images", "nebbie-spells-skills::fav cast shield", "nebbie-spells-skills::fav cast stone skin", "nebbie-spells-skills::food auto off", "nebbie-spells-skills::food auto on", "nebbie-spells-skills::food item set", "nebbie-spells-skills::food manual",
  "nebbie-spells-skills::generic cast c", "nebbie-spells-skills::generic cast word", "nebbie-spells-skills::install diagnose", "nebbie-spells-skills::keypad refresh", "nebbie-spells-skills::list aliases", "nebbie-spells-skills::list classes", "nebbie-spells-skills::list package help", "nebbie-spells-skills::list spells ref", "nebbie-spells-skills::list triggers", "nebbie-spells-skills::loot manual",
  "nebbie-spells-skills::loot off", "nebbie-spells-skills::loot on", "nebbie-spells-skills::memorize", "nebbie-spells-skills::mind shortcut", "nebbie-spells-skills::mode cast", "nebbie-spells-skills::mode mind", "nebbie-spells-skills::mode recall", "nebbie-spells-skills::prompt debug", "nebbie-spells-skills::quick slot 1", "nebbie-spells-skills::quick slot 2",
  "nebbie-spells-skills::quick slot 3", "nebbie-spells-skills::quick slot 4", "nebbie-spells-skills::quick slot 5", "nebbie-spells-skills::quick slot 6", "nebbie-spells-skills::quick slot 7", "nebbie-spells-skills::quick slot 8", "nebbie-spells-skills::quick slot 9", "nebbie-spells-skills::recall shortcut", "nebbie-spells-skills::reinstall fix", "nebbie-spells-skills::reposition gui",
  "nebbie-spells-skills::return form", "nebbie-spells-skills::set class", "nebbie-spells-skills::setup hud", "nebbie-spells-skills::skill aura", "nebbie-spells-skills::skill backstab", "nebbie-spells-skills::skill bash", "nebbie-spells-skills::skill berserk", "nebbie-spells-skills::skill blast", "nebbie-spells-skills::skill blessing", "nebbie-spells-skills::skill bodyguard",
  "nebbie-spells-skills::skill brew", "nebbie-spells-skills::skill carve", "nebbie-spells-skills::skill climb", "nebbie-spells-skills::skill disarm", "nebbie-spells-skills::skill disguise", "nebbie-spells-skills::skill doorbash", "nebbie-spells-skills::skill esp", "nebbie-spells-skills::skill feign death", "nebbie-spells-skills::skill find food", "nebbie-spells-skills::skill find traps",
  "nebbie-spells-skills::skill find water", "nebbie-spells-skills::skill first aid", "nebbie-spells-skills::skill flame", "nebbie-spells-skills::skill forge", "nebbie-spells-skills::skill great", "nebbie-spells-skills::skill hide", "nebbie-spells-skills::skill kick", "nebbie-spells-skills::skill lay on hands", "nebbie-spells-skills::skill parry", "nebbie-spells-skills::skill pick",
  "nebbie-spells-skills::skill portal", "nebbie-spells-skills::skill pray", "nebbie-spells-skills::skill quivering palm", "nebbie-spells-skills::skill scry", "nebbie-spells-skills::skill shield", "nebbie-spells-skills::skill sign", "nebbie-spells-skills::skill sneak", "nebbie-spells-skills::skill spot", "nebbie-spells-skills::skill springleap", "nebbie-spells-skills::skill spy",
  "nebbie-spells-skills::skill steal", "nebbie-spells-skills::skill swim", "nebbie-spells-skills::skill tan", "nebbie-spells-skills::skill track", "nebbie-spells-skills::skill tspy", "nebbie-spells-skills::skill warcry", "nebbie-spells-skills::swap weapon", "nebbie-spells-skills::toggle gui", "nebbie-spells-skills::toggle hud", "prompt debug",
  "recall shortcut", "reinstall fix", "reposition gui", "return form", "set class", "setup hud", "swap weapon", "toggle gui", "toggle hud"
}
Nebbie.legacyPermTriggers = {
  "attrib gag", "cast started", "eq parse wield", "hunger thirst", "look loot parse", "mob kill exp loot", "nebbie-play-all::affect on blindness accecat", "nebbie-play-all::affect on fear presa dal panico", "nebbie-play-all::affect on heat stuff frigge", "nebbie-play-all::affect on paralyze Sei paralizzato",
  "nebbie-play-all::affect on silence non riesci a parlare", "nebbie-play-all::affect on slowness mondo stia rallentando", "nebbie-play-all::affect on web ragnatele che ti avvolgono", "nebbie-play-all::affect on web ricopert", "nebbie-play-all::attrib gag", "nebbie-play-all::cast started", "nebbie-play-all::debuff off curse Ti senti molto meglio", "nebbie-play-all::debuff off feeblemind piu\' intelligente", "nebbie-play-all::debuff off poison sembrano meno forti ora", "nebbie-play-all::debuff off poison veleno non scorre",
  "nebbie-play-all::debuff on curse maledett", "nebbie-play-all::debuff on feeblemind rimbecillit", "nebbie-play-all::debuff on poison appare molto sofferente", "nebbie-play-all::eq parse wield", "nebbie-play-all::fail anti_magic", "nebbie-play-all::fail backfire", "nebbie-play-all::fail backstab_fail", "nebbie-play-all::fail concentrazione", "nebbie-play-all::fail first_aid_cd", "nebbie-play-all::fail fizzle",
  "nebbie-play-all::fail kick_fail", "nebbie-play-all::fail no_level", "nebbie-play-all::fail no_magic_zone", "nebbie-play-all::fail no_mana", "nebbie-play-all::fail no_mem", "nebbie-play-all::fail no_mind_zone", "nebbie-play-all::fail no_quotes", "nebbie-play-all::fail unimplemented", "nebbie-play-all::fail unknown", "nebbie-play-all::fail usa_mind",
  "nebbie-play-all::fail usa_recall", "nebbie-play-all::hunger thirst", "nebbie-play-all::look loot parse", "nebbie-play-all::mob kill exp loot", "nebbie-play-all::prompt parse", "nebbie-play-all::soon armor", "nebbie-play-all::soon fly", "nebbie-play-all::soon invisibility", "nebbie-play-all::soon sanctuary", "nebbie-play-all::soon shield",
  "nebbie-play-all::weapon drop hold", "nebbie-play-all::weapon drop wield", "nebbie-play-all::wearoff adrenalize", "nebbie-play-all::wearoff aid", "nebbie-play-all::wearoff anti magic shell", "nebbie-play-all::wearoff armor", "nebbie-play-all::wearoff barkskin", "nebbie-play-all::wearoff bless", "nebbie-play-all::wearoff blessing", "nebbie-play-all::wearoff blindness",
  "nebbie-play-all::wearoff detect invisibility", "nebbie-play-all::wearoff detect magic", "nebbie-play-all::wearoff disguise", "nebbie-play-all::wearoff faerie fire", "nebbie-play-all::wearoff fireshield", "nebbie-play-all::wearoff first aid", "nebbie-play-all::wearoff fly", "nebbie-play-all::wearoff globe darkness", "nebbie-play-all::wearoff haste", "nebbie-play-all::wearoff heat stuff",
  "nebbie-play-all::wearoff invisibility", "nebbie-play-all::wearoff lay on hands", "nebbie-play-all::wearoff mana", "nebbie-play-all::wearoff meditate", "nebbie-play-all::wearoff minor invulnerability", "nebbie-play-all::wearoff mirror images", "nebbie-play-all::wearoff paralyze", "nebbie-play-all::wearoff polymorph", "nebbie-play-all::wearoff protection from evil", "nebbie-play-all::wearoff psi shield",
  "nebbie-play-all::wearoff psionic blast", "nebbie-play-all::wearoff sanctuary", "nebbie-play-all::wearoff shield", "nebbie-play-all::wearoff silence", "nebbie-play-all::wearoff slowness", "nebbie-play-all::wearoff sneak", "nebbie-play-all::wearoff spy", "nebbie-play-all::wearoff stone skin", "nebbie-play-all::wearoff strength", "nebbie-play-all::wearoff web",
  "nebbie-spells-skills::affect on blindness accecat", "nebbie-spells-skills::affect on fear presa dal panico", "nebbie-spells-skills::affect on heat stuff frigge", "nebbie-spells-skills::affect on paralyze Sei paralizzato", "nebbie-spells-skills::affect on silence non riesci a parlare", "nebbie-spells-skills::affect on slowness mondo stia rallentando", "nebbie-spells-skills::affect on web ragnatele che ti avvolgono", "nebbie-spells-skills::affect on web ricopert", "nebbie-spells-skills::attrib gag", "nebbie-spells-skills::cast started",
  "nebbie-spells-skills::debuff off curse Ti senti molto meglio", "nebbie-spells-skills::debuff off feeblemind piu\' intelligente", "nebbie-spells-skills::debuff off poison sembrano meno forti ora", "nebbie-spells-skills::debuff off poison veleno non scorre", "nebbie-spells-skills::debuff on curse maledett", "nebbie-spells-skills::debuff on feeblemind rimbecillit", "nebbie-spells-skills::debuff on poison appare molto sofferente", "nebbie-spells-skills::eq parse wield", "nebbie-spells-skills::fail anti_magic", "nebbie-spells-skills::fail backfire",
  "nebbie-spells-skills::fail backstab_fail", "nebbie-spells-skills::fail concentrazione", "nebbie-spells-skills::fail first_aid_cd", "nebbie-spells-skills::fail fizzle", "nebbie-spells-skills::fail kick_fail", "nebbie-spells-skills::fail no_level", "nebbie-spells-skills::fail no_magic_zone", "nebbie-spells-skills::fail no_mana", "nebbie-spells-skills::fail no_mem", "nebbie-spells-skills::fail no_mind_zone",
  "nebbie-spells-skills::fail no_quotes", "nebbie-spells-skills::fail unimplemented", "nebbie-spells-skills::fail unknown", "nebbie-spells-skills::fail usa_mind", "nebbie-spells-skills::fail usa_recall", "nebbie-spells-skills::hunger thirst", "nebbie-spells-skills::look loot parse", "nebbie-spells-skills::mob kill exp loot", "nebbie-spells-skills::prompt parse", "nebbie-spells-skills::soon armor",
  "nebbie-spells-skills::soon fly", "nebbie-spells-skills::soon invisibility", "nebbie-spells-skills::soon sanctuary", "nebbie-spells-skills::soon shield", "nebbie-spells-skills::weapon drop hold", "nebbie-spells-skills::weapon drop wield", "nebbie-spells-skills::wearoff adrenalize", "nebbie-spells-skills::wearoff aid", "nebbie-spells-skills::wearoff anti magic shell", "nebbie-spells-skills::wearoff armor",
  "nebbie-spells-skills::wearoff barkskin", "nebbie-spells-skills::wearoff bless", "nebbie-spells-skills::wearoff blessing", "nebbie-spells-skills::wearoff blindness", "nebbie-spells-skills::wearoff detect invisibility", "nebbie-spells-skills::wearoff detect magic", "nebbie-spells-skills::wearoff disguise", "nebbie-spells-skills::wearoff faerie fire", "nebbie-spells-skills::wearoff fireshield", "nebbie-spells-skills::wearoff first aid",
  "nebbie-spells-skills::wearoff fly", "nebbie-spells-skills::wearoff globe darkness", "nebbie-spells-skills::wearoff haste", "nebbie-spells-skills::wearoff heat stuff", "nebbie-spells-skills::wearoff invisibility", "nebbie-spells-skills::wearoff lay on hands", "nebbie-spells-skills::wearoff mana", "nebbie-spells-skills::wearoff meditate", "nebbie-spells-skills::wearoff minor invulnerability", "nebbie-spells-skills::wearoff mirror images",
  "nebbie-spells-skills::wearoff paralyze", "nebbie-spells-skills::wearoff polymorph", "nebbie-spells-skills::wearoff protection from evil", "nebbie-spells-skills::wearoff psi shield", "nebbie-spells-skills::wearoff psionic blast", "nebbie-spells-skills::wearoff sanctuary", "nebbie-spells-skills::wearoff shield", "nebbie-spells-skills::wearoff silence", "nebbie-spells-skills::wearoff slowness", "nebbie-spells-skills::wearoff sneak",
  "nebbie-spells-skills::wearoff spy", "nebbie-spells-skills::wearoff stone skin", "nebbie-spells-skills::wearoff strength", "nebbie-spells-skills::wearoff web", "prompt parse", "weapon drop hold", "weapon drop wield"
}


Nebbie.version = "2.2.41"

Nebbie.DEFAULT_EQ_KEYWORDS = {
  { match = "borsa inesauribile dei korred", key = "korred" },
  { match = "forza della natura", key = "forza" },
  { match = "elf slayer", key = "elf" },
  { match = "il redentore", key = "redentore" },
  { match = "lama danzante", key = "lama" },
}

Nebbie.EQ_STOPWORDS = {
  ["del"] = true, ["dei"] = true, ["della"] = true, ["delle"] = true, ["degli"] = true,
  ["de"] = true, ["di"] = true, ["da"] = true, ["in"] = true, ["su"] = true,
  ["the"] = true, ["pair"] = true, ["paio"] = true,
}
Nebbie.buffs = Nebbie.buffs or {}
Nebbie.debuffs = Nebbie.debuffs or {}
Nebbie.stats = Nebbie.stats or {}
Nebbie.promptBuffs = Nebbie.promptBuffs or {}
Nebbie._aliasNames = Nebbie._aliasNames or {}
Nebbie._triggerNames = Nebbie._triggerNames or {}
Nebbie._aliasIds = Nebbie._aliasIds or {}
Nebbie._triggerIds = Nebbie._triggerIds or {}
Nebbie._keyIds = Nebbie._keyIds or {}
Nebbie._keyNames = Nebbie._keyNames or {}

Nebbie.keypadBindings = {
  { cmd = "look", label = "look", keys = {"5", "Clear"} },
  { cmd = "north", label = "north", keys = {"8", "Up"} },
  { cmd = "south", label = "south", keys = {"2", "Down"} },
  { cmd = "east", label = "east", keys = {"6", "Right"} },
  { cmd = "west", label = "west", keys = {"4", "Left"} },
  { cmd = "up", label = "up", keys = {"9", "PageUp"} },
  { cmd = "down", label = "down", keys = {"3", "PageDown"} },
}
Nebbie._settings = Nebbie._settings or {}
Nebbie.playerClass = Nebbie.playerClass or nil
Nebbie.attribAuto = false
Nebbie.attribGag = false
Nebbie._attribBusy = false
Nebbie.lootAuto = true
Nebbie._lootBusy = false
Nebbie.weaponDropRecover = true
Nebbie._weaponDropBusy = false
Nebbie.foodDrinkAuto = true
Nebbie._foodDrinkBusy = false
Nebbie.eqAuto = true
Nebbie._eqCacheBusy = false
Nebbie._eqCacheGag = false
Nebbie.eqCache = Nebbie.eqCache or {
  wield = nil, back = nil, hold = nil,
  wieldKey = nil, backKey = nil, holdKey = nil,
  updatedAt = 0, wieldScannedAt = 0,
}

local PKG = Nebbie.package
local LEGACY_PKGS = {"nebbie-play-all", "nebbie-spells-skills"}
local CLASS_VAR = "nebbie_class"
function Nebbie.getSettingsFile()
  if not Nebbie._settingsFile then
    local home = ""
    if type(getMudletHomeDir) == "function" then
      local ok, h = pcall(getMudletHomeDir)
      if ok and h then home = h end
    end
    Nebbie._settingsFile = home .. "/nebbie-play-all-settings.lua"
  end
  return Nebbie._settingsFile
end

Nebbie.PROMPT_SLOTS = {
  { code = "P", name = "polymorph self" },
  { code = "P", name = "change form" },
  { code = "P", name = "tree" },
  { code = "F", name = "fireshield" },
  { code = "S", name = "sanctuary" },
  { code = "I", name = "invisibility" },
  { code = "T", name = "true sight" },
  { code = "M", name = "mirror images" },
  { code = "D", name = "prot energy drain" },
  { code = "A", name = "anti magic shell" },
  { code = "Q", name = "quest" },
}

function Nebbie.now()
  if type(getEpoch) == "function" then return getEpoch() end
  if type(getEpochTime) == "function" then return getEpochTime() end
  return os.time()
end

function Nebbie.stripColors(line)
  if not line then return "" end
  line = line:gsub("%$c%d%d%d%d", "")
  line = line:gsub("\27%[[%d;]*m", "")
  return line
end

function Nebbie.normalizePromptLine(line)
  local plain = Nebbie.stripColors(line)
  plain = plain:gsub("\r", "")
  plain = plain:gsub(">>%s*$", "")
  plain = plain:gsub("^%s+", ""):gsub("%s+$", "")
  return plain
end

function Nebbie.extractPromptChunk(plain)
  if not plain or plain == "" then return plain end
  local pos = plain:find("[Hh]:%s*%d+/%d+")
  if not pos then pos = plain:find("[Hh]%s*%d+/%d+") end
  if not pos then return plain end
  if pos > 1 then
    local prefix = plain:sub(1, pos - 1)
    local name = prefix:match("(%S+)%s*$")
    if name and #name >= 2 and name:match("^[%a]") then
      return name .. " " .. plain:sub(pos)
    end
  end
  return plain:sub(pos)
end

function Nebbie.parsePromptPair(plain, letter)
  local letters = { letter, letter:lower(), letter:upper() }
  for _, L in ipairs(letters) do
    local cur, maxv = plain:match(L .. ":%s*(%-?%d+)%s*/%s*(%-?%d+)")
    if cur then return tonumber(cur), tonumber(maxv) end
    cur, maxv = plain:match(L .. "%s*(%-?%d+)%s*/%s*(%-?%d+)")
    if cur then return tonumber(cur), tonumber(maxv) end
    cur = plain:match(L .. ":%s*(%-?%d+)")
    if cur then local n = tonumber(cur); return n, n end
    cur = plain:match(L .. "%s*(%-?%d+)")
    if cur then local n = tonumber(cur); return n, n end
  end
  return nil, nil
end

function Nebbie.parsePromptStats(line)
  local plain = Nebbie.extractPromptChunk(Nebbie.normalizePromptLine(line))
  if plain == "" then
    Nebbie._lastParseError = "riga vuota"
    return nil
  end

  local hp, hpmax = Nebbie.parsePromptPair(plain, "H")
  local mana, manamax = Nebbie.parsePromptPair(plain, "M")
  local move, movemax = Nebbie.parsePromptPair(plain, "V")
  local xp = tonumber(plain:match("[xX]:%s*(-?%d+)") or plain:match("[xX]%s*(-?%d+)"))
  if not hp or not mana or not move or not xp then
    Nebbie._lastParseError = "mancano H/M/V/X in: " .. plain:sub(1, 100)
    return nil
  end
  Nebbie._lastParseError = nil

  local name = plain:match("^(%S+)%s+[Hh]") or plain:match("^(%S+)")
  local gold = tonumber(plain:match("G:%s*(%d+)") or plain:match("g:%s*(%d+)") or plain:match("G(%d+)"))
  local codes = plain:match("%[%[([^%]]*)%]%]") or plain:match("%[([^%]]*)%]")

  local tankC, tankN, mobC, mobT = "*", "*", "*", "*"
  local tail = plain:match("[xX]:%s*-?%d+%s*(.*)$") or plain:match("[xX]%s*-?%d+%s*(.*)$") or ""
  tail = tail:gsub("%s+$", "")
  local fc, ft, mc, mt = tail:match("^%s*([^/]+)/(%S+)%s+([^/]+)/(%S+)")
  if fc then
    tankC, tankN = Nebbie.stripColors(fc), ft
    mobC, mobT = Nebbie.stripColors(mc), mt
  else
    local t1, t2 = tail:match("^%s*(%S+)%s+(%S+)")
    if t1 and t2 then
      tankC, tankN = t1:match("^([^:]*):?(.*)$")
      mobC, mobT = t2:match("^([^:]*):?(.*)$")
      if tankN == "" then tankN = "*" end
      if mobT == "" then mobT = "*" end
    end
  end

  return {
    name = name,
    hp = hp, hpmax = hpmax or hp,
    mana = mana, manamax = manamax or mana,
    move = move, movemax = movemax or move,
    xp = xp, gold = gold,
    tankCond = Nebbie.stripColors(tankC or "*"),
    tankName = (tankN ~= "*" and tankN) or nil,
    mobCond = Nebbie.stripColors(mobC or "*"),
    mobName = (mobT ~= "*" and mobT) or nil,
    codes = codes or "",
  }
end

function Nebbie.resolveTriggerLine()
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  return text or ""
end

function Nebbie.pollPromptFromBuffer()
  if type(getLastLineNumber) ~= "function" or type(getLines) ~= "function" then return false end
  local last = getLastLineNumber()
  if not last or last < 1 then return false end
  local from = math.max(1, last - 30)
  local lines = getLines(from, last)
  if type(lines) ~= "table" then return false end
  for abs = last, from, -1 do
    local rel = abs - from + 1
    local text = lines[rel]
    if type(text) == "string" and text ~= "" then
      local parsed = Nebbie.parsePromptStats(text)
      if parsed then
        Nebbie.stats = parsed
        Nebbie.promptBuffs = Nebbie.parsePromptCodes(parsed.codes or "")
        Nebbie._lastPromptRaw = text
        return true
      end
    end
  end
  return false
end

function Nebbie.onPrompt(line)
  Nebbie._lastPromptRaw = line
  local parsed = Nebbie.parsePromptStats(line)
  if not parsed then return end
  Nebbie.stats = parsed
  if parsed.name and parsed.name ~= "" and parsed.name ~= Nebbie._charName then
    Nebbie.switchCharProfile(parsed.name, true)
  end
  Nebbie.promptBuffs = Nebbie.parsePromptCodes(parsed.codes or "")
  Nebbie.updateGauges()
  Nebbie.refreshGUI()
end

function Nebbie.onPromptLine()
  Nebbie.onPrompt(Nebbie.resolveTriggerLine())
end

function Nebbie.debugPrompt()
  local polled = false
  if not Nebbie.stats then polled = Nebbie.pollPromptFromBuffer() end
  cecho("<cyan>Nebbie v" .. tostring(Nebbie.version) .. " — debug prompt\n")
  cecho("<grey>ultima riga vista: <white>" .. tostring(Nebbie._lastPromptRaw or "(nessuna)") .. "\n")
  cecho("<grey>poll buffer: <yellow>" .. tostring(polled) .. "\n")
  if Nebbie._lastParseError then
    cecho("<orange>parse error: <white>" .. Nebbie._lastParseError .. "\n")
  end
  if Nebbie.stats then
    local s = Nebbie.stats
    cecho(string.format("<green>stats ok: HP %s/%s MN %s/%s MV %s/%s\n",
      tostring(s.hp), tostring(s.hpmax), tostring(s.mana), tostring(s.manamax),
      tostring(s.move), tostring(s.movemax)))
    Nebbie.updateGauges()
  else
    cecho("<orange>stats=nil — digita un comando qualsiasi, poi ripeti nprompt.\n")
  end
end

function Nebbie.testPromptParse(silent)
  local samples = {
    "Mirari H:652/652 M:532/532 V:265/265 X:280457721 - */* - *-* - [[------Tm---]] - G:49287175 >>",
    "NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449815 >>",
  }
  for _, sample in ipairs(samples) do
    local parsed = Nebbie.parsePromptStats(sample)
    if not parsed or not parsed.hp or not parsed.mana or not parsed.move then
      if not silent then
        cecho("<red>Nebbie: parser prompt FALLITO su: " .. sample:sub(1, 60) .. "…\n")
        cecho("<orange>" .. tostring(Nebbie._lastParseError) .. "\n")
      end
      return false
    end
  end
  if not silent then cecho("<green>Nebbie: parser prompt OK (v" .. Nebbie.version .. ").\n") end
  return true
end

function Nebbie.reloadMainScript()
  Nebbie._installedVer = nil
  Nebbie._mainLoaded = false
  Nebbie.boot()
  return true
end

function Nebbie.installPromptHooks()
  Nebbie._promptTrigIds = Nebbie._promptTrigIds or {}
  for _, id in ipairs(Nebbie._promptTrigIds) do
    pcall(function() killTrigger(id) end)
  end
  Nebbie._promptTrigIds = {}
  local hook = [[if Nebbie and Nebbie.onPromptLine then Nebbie.onPromptLine() end]]
  if type(tempSubstringTrigger) == "function" then
    for _, sub in ipairs({ " H:", " M:", " V:", " X:" }) do
      local id = tempSubstringTrigger(sub, hook)
      if id then table.insert(Nebbie._promptTrigIds, id) end
    end
  end
  if type(tempRegexTrigger) == "function" then
    for _, pat in ipairs({
      [[H:\d+/\d+.*M:\d+/\d+.*V:\d+/\d+.*X:\d+]],
      [[H\d+/\d+.*M\d+/\d+.*V\d+/\d+.*X\d+]],
      [[%s+H:\d+/\d+%s+M:\d+/\d+]],
    }) do
      local ok, id = pcall(function() return tempRegexTrigger(pat, hook) end)
      if ok and id then table.insert(Nebbie._promptTrigIds, id) end
    end
  end
  if type(tempPromptTrigger) == "function" then
    pcall(function()
      local id = tempPromptTrigger(hook)
      if id then table.insert(Nebbie._promptTrigIds, id) end
    end)
  end
  if Nebbie._promptEventId and type(killAnonymousEventHandler) == "function" then
    pcall(function() killAnonymousEventHandler(Nebbie._promptEventId) end)
    Nebbie._promptEventId = nil
  end
  if type(registerAnonymousEventHandler) == "function" then
    local ok, id = pcall(function()
      return registerAnonymousEventHandler("sysPromptLine", function(_, line)
        if Nebbie and Nebbie.onPrompt and type(line) == "string" then
          Nebbie.onPrompt(line)
        end
      end)
    end)
    if ok and id then Nebbie._promptEventId = id end
  end
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

function Nebbie.loadSettings()
  Nebbie._settings = Nebbie._settings or {}
  if type(table.load) == "function" then
    pcall(function() table.load(Nebbie.getSettingsFile(), Nebbie._settings) end)
  end
  Nebbie._settings.eqKeywords = Nebbie._settings.eqKeywords or {}
  if type(Nebbie._settings.eqCache) == "table" then
    local sc = Nebbie._settings.eqCache
    Nebbie.eqCache = {
      wield = sc.wield,
      back = sc.back,
      hold = sc.hold,
      wieldKey = sc.wieldKey,
      backKey = sc.backKey,
      holdKey = sc.holdKey,
      updatedAt = sc.updatedAt or 0,
      wieldScannedAt = sc.wieldScannedAt or 0,
    }
  end
  if Nebbie._settings.eqAuto == false then
    Nebbie.eqAuto = false
  else
    Nebbie.eqAuto = true
  end
  Nebbie.weaponDropRecover = Nebbie._settings.weaponDropRecover ~= false
  Nebbie.foodDrinkAuto = Nebbie._settings.foodDrinkAuto ~= false
  Nebbie._settings.foodItemKey = Nebbie._settings.foodItemKey or "cornu"
end

function Nebbie.saveSettings()
  if type(table.save) == "function" then
    pcall(function() table.save(Nebbie.getSettingsFile(), Nebbie._settings) end)
  end
end

Nebbie._charName = Nebbie._charName or nil
Nebbie._charMenu = Nebbie._charMenu or {}
Nebbie._charMenuActive = false

function Nebbie.defaultCharProfile()
  return { weapons = {}, utility = {}, paths = {} }
end

function Nebbie.copyEqCacheTable(sc)
  if type(sc) ~= "table" then return nil end
  return {
    wield = sc.wield,
    back = sc.back,
    hold = sc.hold,
    wieldKey = sc.wieldKey,
    backKey = sc.backKey,
    holdKey = sc.holdKey,
    updatedAt = sc.updatedAt or 0,
    wieldScannedAt = sc.wieldScannedAt or 0,
  }
end

function Nebbie.copyEqKeywordsTable(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for _, r in ipairs(src) do
    if r.match and r.key then
      table.insert(out, { match = r.match, key = r.key })
    end
  end
  return out
end

function Nebbie.getCharProfileRecord(name, create)
  if not name or name == "" then return nil end
  Nebbie.loadSettings()
  Nebbie._settings.charProfiles = Nebbie._settings.charProfiles or {}
  local profile = Nebbie._settings.charProfiles[name]
  if not profile and create then
    profile = Nebbie.defaultCharProfile()
    if Nebbie._settings.class and Nebbie._settings.class ~= "" then
      profile.class = Nebbie._settings.class
    end
    if type(Nebbie._settings.eqKeywords) == "table" and #Nebbie._settings.eqKeywords > 0 then
      profile.eqKeywords = Nebbie.copyEqKeywordsTable(Nebbie._settings.eqKeywords)
    end
    if type(Nebbie._settings.eqCache) == "table" and Nebbie._settings.eqCache.back then
      profile.eqCache = Nebbie.copyEqCacheTable(Nebbie._settings.eqCache)
    end
    Nebbie._settings.charProfiles[name] = profile
    Nebbie.saveSettings()
  end
  return profile
end

function Nebbie.persistCharState()
  local name = Nebbie._charName
  if not name or name == "" then return end
  local profile = Nebbie.getCharProfileRecord(name, true)
  if not profile then return end
  if Nebbie.playerClass and Nebbie.playerClass ~= "" then
    profile.class = Nebbie.playerClass
  end
  if Nebbie.eqCache then
    profile.eqCache = Nebbie.copyEqCacheTable(Nebbie.eqCache)
  end
  profile.eqKeywords = Nebbie.copyEqKeywordsTable(Nebbie._settings.eqKeywords or {})
  Nebbie.saveSettings()
end

function Nebbie.applyCharState(profile)
  if not profile then return end
  local cls = profile.class or Nebbie._settings.class or "+"
  if Nebbie.classes[cls] or #Nebbie.parseClassArg(cls) > 1 then
    Nebbie.setClass(cls, true)
  else
    Nebbie.setClass("+", true)
  end
  if profile.eqCache then
    Nebbie.eqCache = Nebbie.copyEqCacheTable(profile.eqCache)
  else
    Nebbie.eqCache = {
      wield = nil, back = nil, hold = nil,
      wieldKey = nil, backKey = nil, holdKey = nil,
      updatedAt = 0, wieldScannedAt = 0,
    }
  end
  if profile.eqKeywords then
    Nebbie._settings.eqKeywords = Nebbie.copyEqKeywordsTable(profile.eqKeywords)
  else
    Nebbie._settings.eqKeywords = Nebbie._settings.eqKeywords or {}
  end
end

function Nebbie.switchCharProfile(name, silent)
  if not name or name == "" then return false end
  name = name:match("^%s*(.-)%s*$")
  if name == "" then return false end
  if Nebbie._charName and Nebbie._charName ~= name then
    Nebbie.persistCharState()
  end
  Nebbie._charName = name
  Nebbie._settings = Nebbie._settings or {}
  Nebbie._settings.lastChar = name
  local profile = Nebbie.getCharProfileRecord(name, true)
  Nebbie.applyCharState(profile)
  Nebbie.saveSettings()
  Nebbie._charMenuActive = false
  if Nebbie.stats then Nebbie.stats.name = name end
  if not silent then
    local cls = profile.class or "+"
    cecho("<green>Nebbie: profilo <yellow>" .. name .. "<green> — classe <yellow>" .. cls .. "\n")
  end
  if Nebbie.refreshGUI then Nebbie.refreshGUI() end
  return true
end

function Nebbie.onCharMenuStart()
  Nebbie._charMenuActive = true
  Nebbie._charMenu = {}
end

function Nebbie.onCharMenuLine(line)
  if not Nebbie._charMenuActive then return end
  local plain = Nebbie.stripColors(line or "")
  local idx, firstWord = plain:match("^%s*(%d+)%.%s+(%S+)")
  if not idx or not firstWord then return end
  idx = tonumber(idx)
  if not idx or idx <= 0 then return end
  local low = firstWord:lower()
  if low == "crea" or low == "quit" then return end
  Nebbie._charMenu[idx] = firstWord
end

function Nebbie.onCharMenuSend(cmd)
  if not Nebbie._charMenuActive or type(cmd) ~= "string" then return end
  local idx = tonumber(cmd:match("^%s*(%d+)%s*$"))
  if not idx or idx <= 0 then return end
  local name = Nebbie._charMenu and Nebbie._charMenu[idx]
  if name then Nebbie.switchCharProfile(name, false) end
end

function Nebbie.bootCharProfile()
  Nebbie.loadSettings()
  local last = Nebbie._settings.lastChar
  if last and last ~= "" then
    Nebbie.switchCharProfile(last, true)
    return true
  end
  return false
end

function Nebbie.stripQuotes(token)
  if not token then return "" end
  local s = token:match("^%s*(.-)%s*$")
  while true do
    local inner = s:match("^['\"](.+)['\"]$")
    if not inner then break end
    s = inner
  end
  return s
end

function Nebbie.killAllByName(name, typ)
  if not name or name == "" then return end
  typ = typ or "trigger"
  if type(findItems) == "function" then
    local ids = findItems(name, typ, true)
    if type(ids) == "table" then
      for _, id in ipairs(ids) do
        if typ == "alias" then
          if type(disableAlias) == "function" then pcall(function() disableAlias(id) end) end
          if type(killAlias) == "function" then pcall(function() killAlias(id) end) end
        elseif typ == "trigger" then
          if type(disableTrigger) == "function" then pcall(function() disableTrigger(id) end) end
          if type(killTrigger) == "function" then pcall(function() killTrigger(id) end) end
        end
      end
    end
  end
  if type(exists) ~= "function" then return end
  local tries = 0
  while exists(name, typ) > 0 and tries < 64 do
    local before = exists(name, typ)
    if typ == "alias" then
      if type(killAlias) == "function" then pcall(function() killAlias(name) end) end
      if exists(name, typ) >= before and type(disableAlias) == "function" then
        disableAlias(name)
      end
    elseif typ == "trigger" then
      if type(killTrigger) == "function" then pcall(function() killTrigger(name) end) end
      if exists(name, typ) >= before and type(disableTrigger) == "function" then
        disableTrigger(name)
      end
    end
    tries = tries + 1
  end
end

function Nebbie.killAllByNameVariants(short, typ)
  if not short or short == "" then return end
  Nebbie.killAllByName(PKG .. "::" .. short, typ)
  Nebbie.killAllByName(short, typ)
  Nebbie.killAllByName("nebbie-spells-skills::" .. short, typ)
end

function Nebbie.killAllTrackedTemps()
  for _, id in pairs(Nebbie._aliasIds or {}) do
    if type(killAlias) == "function" then pcall(function() killAlias(id) end) end
  end
  for _, ids in pairs(Nebbie._triggerIds or {}) do
    for _, id in ipairs(ids) do
      if type(killTrigger) == "function" then pcall(function() killTrigger(id) end) end
    end
  end
  for _, id in pairs(Nebbie._keyIds or {}) do
    if type(killKey) == "function" then pcall(function() killKey(id) end) end
  end
  local seenA, seenT = {}, {}
  for _, name in ipairs(Nebbie._aliasNames or {}) do
    if not seenA[name] then
      seenA[name] = true
      Nebbie.killAllByName(name, "alias")
      local short = name:match("::(.+)$")
      if short then Nebbie.killAllByName(short, "alias") end
    end
  end
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    if not seenT[name] then
      seenT[name] = true
      Nebbie.killAllByName(name, "trigger")
      local short = name:match("::(.+)$")
      if short then Nebbie.killAllByName(short, "trigger") end
    end
  end
end

function Nebbie.killTempAlias(full)
  if Nebbie._aliasIds and Nebbie._aliasIds[full] then
    pcall(function() killAlias(Nebbie._aliasIds[full]) end)
    Nebbie._aliasIds[full] = nil
  end
end

function Nebbie.killTempTriggers(full)
  if not Nebbie._triggerIds or not Nebbie._triggerIds[full] then return end
  for _, id in ipairs(Nebbie._triggerIds[full]) do
    pcall(function() killTrigger(id) end)
  end
  Nebbie._triggerIds[full] = nil
end

function Nebbie.killTempKey(full)
  if Nebbie._keyIds and Nebbie._keyIds[full] then
    local id = Nebbie._keyIds[full]
    if type(id) == "number" and type(killKey) == "function" then
      pcall(function() killKey(id) end)
    elseif type(id) == "string" and type(killKey) == "function" then
      pcall(function() killKey(id) end)
    end
    Nebbie._keyIds[full] = nil
  end
end

function Nebbie.killPermKeyByName(name)
  if not name or name == "" or type(exists) ~= "function" then return end
  local n = 0
  while (exists(name, "key") or 0) > 0 and n < 16 do
    if type(killKey) == "function" then pcall(function() killKey(name) end) end
    n = n + 1
  end
end

function Nebbie.resolveMudletKey(name)
  if not mudlet or not mudlet.key then return nil end
  return mudlet.key[name] or mudlet.key[tostring(name)]
end

function Nebbie.killLegacyKeypadTemps()
  for _, entry in ipairs(Nebbie.keypadBindings or {}) do
    Nebbie.killTempKey(PKG .. "::keypad " .. entry.label)
    for ki, _ in ipairs(entry.keys or {}) do
      local suffix = (ki == 1) and "num" or "nav"
      Nebbie.killTempKey(PKG .. "::keypad " .. entry.label .. " " .. suffix)
    end
  end
end

function Nebbie.killKeypadBindings()
  Nebbie.killLegacyKeypadTemps()
  for _, entry in ipairs(Nebbie.keypadBindings or {}) do
    for ki, _ in ipairs(entry.keys or {}) do
      local suffix = (ki == 1) and "num" or "nav"
      Nebbie.killPermKeyByName("nebbie-keypad " .. entry.label .. " " .. suffix)
    end
  end
end

function Nebbie.installKeypadBindings(force)
  if not mudlet or not mudlet.keymodifier or not mudlet.key then return 0 end
  if type(permKey) ~= "function" then return 0 end
  local mod = mudlet.keymodifier.Keypad
  local n = 0
  for _, entry in ipairs(Nebbie.keypadBindings or {}) do
    for ki, keyName in ipairs(entry.keys or {}) do
      local suffix = (ki == 1) and "num" or "nav"
      local permName = "nebbie-keypad " .. entry.label .. " " .. suffix
      local keyCode = Nebbie.resolveMudletKey(keyName)
      if keyCode then
        local present = type(exists) == "function" and (exists(permName, "key") or 0) > 0
        if force or not present then
          Nebbie.killPermKeyByName(permName)
          local script = string.format([[send(%q)]], entry.cmd)
          local ok, id = pcall(function() return permKey(permName, "", mod, keyCode, script) end)
          if ok and id then
            Nebbie._keyIds[permName] = id
            table.insert(Nebbie._keyNames, permName)
            n = n + 1
          end
        else
          n = n + 1
        end
      end
    end
  end
  return n
end

function Nebbie.isKeepPackageAlias(name)
  return name == "nebbie-fix" or name == "nebbie-purge" or name == "nebbie-nprompt"
end

function Nebbie.purgeLegacyPermItems(silent)
  if type(exists) ~= "function" then return end
  local ta, tt = 0, 0
  for _, name in ipairs(Nebbie.legacyPermTriggers or {}) do
    local before = exists(name, "trigger")
    if before > 0 then
      Nebbie.killAllByName(name, "trigger")
      tt = tt + before
    end
    local short = name:match("::(.+)$")
    if short then
      local b2 = exists(short, "trigger")
      if b2 > 0 then
        Nebbie.killAllByName(short, "trigger")
        tt = tt + b2
      end
    end
  end
  for _, name in ipairs(Nebbie.legacyPermAliases or {}) do
    if not Nebbie.isKeepPackageAlias(name) then
      local before = exists(name, "alias")
      if before > 0 then
        Nebbie.killAllByName(name, "alias")
        ta = ta + before
      end
      local short = name:match("::(.+)$")
      if short and not Nebbie.isKeepPackageAlias(short) then
        local b2 = exists(short, "alias")
        if b2 > 0 then
          Nebbie.killAllByName(short, "alias")
          ta = ta + b2
        end
      end
    end
  end
  if not silent and ta > 0 then
    cecho("<orange>Nebbie: disattivati perm vecchi (~" .. ta .. " item).\n")
  end
  return ta
end

function Nebbie.disableAllLegacyNfixAliases(silent)
  return Nebbie.purgeLegacyPermItems(silent)
end

function Nebbie.disablePackagePermItems()
  Nebbie.purgeLegacyPermItems(true)
  if type(getAliasList) == "function" then
    for _, entry in ipairs(getAliasList()) do
      local name = entry
      if type(getAliasName) == "function" then
        local ok, n = pcall(function() return getAliasName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" and not Nebbie.isKeepPackageAlias(name) then
        for _, pkg in ipairs(LEGACY_PKGS) do
          if name:find(pkg, 1, true) and type(disableAlias) == "function" then
            disableAlias(name)
            break
          end
        end
      end
    end
  end
  if type(getTriggerList) == "function" then
    for _, entry in ipairs(getTriggerList()) do
      local name = entry
      if type(getTriggerName) == "function" then
        local ok, n = pcall(function() return getTriggerName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" then
        for _, pkg in ipairs(LEGACY_PKGS) do
          if name:find(pkg, 1, true) and type(disableTrigger) == "function" then
            disableTrigger(name)
            break
          end
        end
      end
    end
  end
end

function Nebbie.purgeTrackedAliases()
  local seen = {}
  for _, name in ipairs(Nebbie._aliasNames or {}) do
    if not seen[name] then
      seen[name] = true
      Nebbie.killAllByName(name, "alias")
    end
  end
end

function Nebbie.purgeTrackedTriggers()
  local seen = {}
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    if not seen[name] then
      seen[name] = true
      Nebbie.killAllByName(name, "trigger")
    end
  end
end

function Nebbie.purgePackageTriggers()
  if type(getTriggerList) ~= "function" then return end
  for _, entry in ipairs(getTriggerList()) do
    local name = entry
    if type(getTriggerName) == "function" then
      local ok, n = pcall(function() return getTriggerName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, pkg in ipairs(LEGACY_PKGS) do
        if name:find(pkg, 1, true) then
          Nebbie.killAllByName(name, "trigger")
          break
        end
      end
    end
  end
end

function Nebbie.purgeOrphanNebbieTriggers()
  local patterns = {
    "debuff on", "debuff off", "wear off", "soon ", "fail ", "cast started",
    "prompt parse", "attrib gag", "look loot", "eq parse", "mob kill", "coin loot",
  }
  if type(getTriggerList) == "function" then
    for _, entry in ipairs(getTriggerList()) do
      local name = entry
      if type(getTriggerName) == "function" then
        local ok, n = pcall(function() return getTriggerName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" then
        for _, frag in ipairs(patterns) do
          if name:find(frag, 1, true) then
            Nebbie.killAllByName(name, "trigger")
            break
          end
        end
      end
    end
    return
  end
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    for _, frag in ipairs(patterns) do
      if name:find(frag, 1, true) then
        Nebbie.killAllByName(name, "trigger")
        break
      end
    end
  end
end

function Nebbie.purgePackageAliases()
  if type(getAliasList) ~= "function" then return end
  for _, entry in ipairs(getAliasList()) do
    local name = entry
    if type(getAliasName) == "function" then
      local ok, n = pcall(function() return getAliasName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, pkg in ipairs(LEGACY_PKGS) do
        if name:find(pkg, 1, true) then
          Nebbie.killAllByName(name, "alias")
          break
        end
      end
    end
  end
end

function Nebbie.purgeOrphanNebbieAliases()
  if type(getAliasList) ~= "function" then return end
  local patterns = {
    "set class", "list classes", "reinstall fix", "reposition gui", "attrib sync",
    "setup hud", "toggle hud", "toggle gui", "loot manual", "loot on", "loot off",
    "swap weapon", "eq key", "eq cache", "generic cast", "recall shortcut", "mind shortcut", "memorize", "mode cast",
    "mode recall", "mode mind", "abbr cast", "fav cast", "quick slot", "return form",
  }
  for _, entry in ipairs(getAliasList()) do
    local name = entry
    if type(getAliasName) == "function" then
      local ok, n = pcall(function() return getAliasName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, frag in ipairs(patterns) do
        if name:find(frag, 1, true) then
          Nebbie.killAllByName(name, "alias")
          break
        end
      end
    end
  end
end

function Nebbie.warnLegacyPackages()
  if type(getPackageList) ~= "function" then return end
  local ok, pkgs = pcall(getPackageList)
  if not ok or type(pkgs) ~= "table" then return end
  local legacy = false
  for _, name in ipairs(pkgs) do
    if name == "nebbie-spells-skills" then legacy = true break end
  end
  if legacy then
    cecho("<orange>Nebbie: disinstalla il package vecchio <yellow>nebbie-spells-skills<orange> (Alt+O) per evitare cast doppi.\n")
  end
end

function Nebbie.purgeOrphanMainScripts(silent)
  if type(Nebbie_cleanupScripts) == "function" then
    return Nebbie_cleanupScripts(silent)
  end
  if type(getScript) ~= "function" or type(disableScript) ~= "function" then return 0 end
  local disabled = 0
  local keep = Nebbie.MAIN_SCRIPT_NAME or "Nebbie Play All"
  local legacy = {
    "Nebbie Spells and Skills",
    "nebbie-install",
    "Nebbie Bootloader",
    "!Nebbie Boot",
    "Nebbie Play All v2.2.12",
    "Nebbie Play All v2.2.13",
    "Nebbie Play All v2.2.14",
    "Nebbie Play All v2.2.15",
    "Nebbie Play All v2.2.16",
    "Nebbie Play All v2.2.17",
    "Nebbie Play All v2.2.18",
    "Nebbie Play All v2.2.19",
  }
  for _, sname in ipairs(legacy) do
    if sname ~= keep then
      for occ = 1, 16 do
        local sid = getScript(sname, occ)
        if not sid or sid == -1 then break end
        pcall(function() disableScript(sname, occ) end)
        disabled = disabled + 1
      end
    end
  end
  if keep and type(enableScript) == "function" then
    for occ = 1, 4 do
      local sid = getScript(keep, occ)
      if sid and sid ~= -1 then pcall(function() enableScript(keep, occ) end) end
    end
  end
  if not silent and disabled > 0 then
    cecho("<orange>Nebbie: disattivati " .. disabled .. " script obsoleti.\n")
    cecho("<grey>Se la versione resta vecchia: <yellow>riavvia Mudlet<grey> e ripeti <yellow>nfix<grey>.\n")
  end
  return disabled
end

function Nebbie.diagnoseInstall()
  cecho("<cyan><b>Nebbie diagnose</b>\n")
  cecho("<grey>version: <yellow>" .. tostring(Nebbie.version) .. " <grey>expected: <yellow>" .. tostring(Nebbie._expectedPkgVer or "?") .. "\n")
  cecho("<grey>runFix: <yellow>" .. tostring(type(Nebbie.runFix)) .. " <grey>mainLoaded: <yellow>" .. tostring(Nebbie._mainLoaded) .. "\n")
  cecho("<grey>loadedPkgVer: <yellow>" .. tostring(Nebbie._loadedPkgVer) .. " <grey>installedVer: <yellow>" .. tostring(Nebbie._installedVer) .. "\n")
  cecho("<grey>main script: <yellow>" .. tostring(Nebbie.MAIN_SCRIPT_NAME or "?") .. "\n")
  if type(getScript) == "function" then
    for _, sname in ipairs({ "Nebbie Play All", Nebbie.MAIN_SCRIPT_NAME or "?", "Nebbie Spells and Skills" }) do
      for occ = 1, 4 do
        local sid = getScript(sname, occ)
        if sid and sid ~= -1 then
          local active = "?"
          if type(isActive) == "function" then
            local ok, a = pcall(function() return isActive(sname, occ) end)
            if ok then active = tostring(a) end
          end
          cecho("<grey> script <white>" .. sname .. " #" .. occ .. " <grey>id=" .. tostring(sid) .. " active=" .. active .. "\n")
        end
      end
    end
  end
end

function Nebbie.parseClassArg(arg)
  if not arg or arg == "" then return {} end
  if arg == "u" then return {"+"} end
  local parts = {}
  for letter in arg:gmatch("%S+") do table.insert(parts, letter) end
  return parts
end

function Nebbie.buildMergedPreset(parts)
  local key = table.concat(parts, " ")
  Nebbie._mergedCache = Nebbie._mergedCache or {}
  if Nebbie._mergedCache[key] then return Nebbie._mergedCache[key] end
  local quick, seen, names = {}, {}, {}
  for _, cls in ipairs(parts) do
    local p = Nebbie.classes[cls]
    if p then
      table.insert(names, p.name)
      for _, entry in ipairs(p.quick) do
        local sk = entry.abbr .. "\0" .. entry.kind .. "\0" .. entry.target
        if not seen[sk] and #quick < 9 then
          seen[sk] = true
          table.insert(quick, entry)
        end
      end
    end
  end
  local preset = { name = table.concat(names, " + "), mode = "cast", quick = quick }
  Nebbie._mergedCache[key] = preset
  return preset
end

function Nebbie.getActivePreset()
  if not Nebbie.playerClass or Nebbie.playerClass == "" then return nil end
  if Nebbie.classes[Nebbie.playerClass] then return Nebbie.classes[Nebbie.playerClass] end
  local parts = Nebbie.parseClassArg(Nebbie.playerClass)
  if #parts > 1 then return Nebbie.buildMergedPreset(parts) end
  return nil
end

function Nebbie.listClasses()
  cecho("<cyan><b>Classi Nebbie</b> <grey>(default multiclasse: <yellow>nclass +<grey>):\n")
  local order = {"+", "m", "s", "c", "d", "p", "r", "I", "t", "w", "k", "b"}
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
  cecho("<grey>Multiclasse: <yellow>nclass m c<grey> | universale: <yellow>nclass +<grey>\n")
end

function Nebbie.saveClass(cls)
  Nebbie._settings = Nebbie._settings or {}
  Nebbie._settings.class = cls
  if Nebbie._charName and Nebbie._charName ~= "" then
    local profile = Nebbie.getCharProfileRecord(Nebbie._charName, true)
    if profile then profile.class = cls end
  end
  if type(setVariable) == "function" then pcall(function() setVariable(CLASS_VAR, cls) end) end
  Nebbie.saveSettings()
end

function Nebbie.loadClass()
  Nebbie.loadSettings()
  local saved = Nebbie._settings.class
  if type(getVariable) == "function" then
    local ok, v = pcall(function() return getVariable(CLASS_VAR) end)
    if ok and v and v ~= "" then saved = v end
  end
  if saved and saved ~= "" then
    if Nebbie.classes[saved] or #Nebbie.parseClassArg(saved) > 1 then
      Nebbie.setClass(saved, true)
      return true
    end
  end
  return false
end

function Nebbie.setMulticlass(parts, silent)
  local names, missing = {}, {}
  for _, cls in ipairs(parts) do
    if Nebbie.classes[cls] then table.insert(names, Nebbie.classes[cls].name)
    else table.insert(missing, cls) end
  end
  if #missing > 0 then
    if not silent then cecho("<orange>Classe sconosciuta: <yellow>" .. table.concat(missing, ", ") .. "\n") end
    return false
  end
  local key = table.concat(parts, " ")
  local preset = Nebbie.buildMergedPreset(parts)
  Nebbie.playerClass = key
  Nebbie.saveClass(key)
  Nebbie.castMode = preset.mode
  if not silent then
    cecho("<green>Nebbie multiclasse: <yellow>" .. preset.name .. "\n")
  end
  Nebbie.refreshGUI()
  return true
end

function Nebbie.setClass(cls, silent)
  local parts = Nebbie.parseClassArg(cls)
  if #parts > 1 then return Nebbie.setMulticlass(parts, silent) end
  if #parts == 1 then cls = parts[1] end
  local preset = Nebbie.classes[cls]
  if not preset then
    if not silent then
      cecho("<orange>Classi: + u m s c d p r I t w k b — <yellow>nclass +<grey> consigliato\n")
    end
    return false
  end
  Nebbie.playerClass = cls
  Nebbie.saveClass(cls)
  Nebbie.castMode = preset.mode
  if not silent then
    cecho("<green>Nebbie classe: <yellow>" .. preset.name .. " <grey>(" .. cls .. ")\n")
  end
  Nebbie.refreshGUI()
  return true
end

-- 1 unità in attribute = 1 ora MUD (SECS_PER_MUD_HOUR nel sorgente server)
Nebbie.TICK_SECONDS = 75
Nebbie.MUD_HOUR_SECONDS = 75

function Nebbie.formatTime(secs)
  secs = math.max(0, math.floor(secs))
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

function Nebbie.isDebuffSpell(spell)
  return spell and Nebbie.debuffSpells and Nebbie.debuffSpells[spell] or false
end

function Nebbie.isSelfAffectLine(plain)
  if not plain or plain == "" then return false end
  local low = plain:lower()
  if low:find("^sei ", 1, true) or low:find("^ti ", 1, true)
      or low:find(" ti ", 1, true) or low:find(" tue ", 1, true)
      or low:find(" tuo ", 1, true) or low:find(" tua ", 1, true)
      or low:find("nelle tue vene", 1, true) then
    return true
  end
  local name = Nebbie.stats and Nebbie.stats.name
  if name and name ~= "" then
    local esc = name:gsub("(%W)", "%%%1")
    if plain:find("^" .. esc) then return true end
  end
  return false
end

function Nebbie.shouldTrackBuff(spell)
  if not spell or spell == "" then return false end
  if Nebbie.noBuffSpells and Nebbie.noBuffSpells[spell] then return false end
  if Nebbie.debuffSpells and Nebbie.debuffSpells[spell] then return true end
  if Nebbie.buffDurations and Nebbie.buffDurations[spell] then return true end
  for _, entry in ipairs(Nebbie.wearOff or {}) do
    if entry.name == spell then return true end
  end
  for _, entry in ipairs(Nebbie.wearOffSoon or {}) do
    if entry.name == spell then return true end
  end
  return false
end

function Nebbie.normalizeBuffSpell(spell)
  if not spell or spell == "" then return nil end
  spell = spell:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.$", "")
  if spell == "" then return nil end
  if Nebbie.buffDurations and Nebbie.buffDurations[spell] then return spell end
  if Nebbie.debuffSpells and Nebbie.debuffSpells[spell] then return spell end
  local lower = spell:lower()
  for name, _ in pairs(Nebbie.buffDurations or {}) do
    if name:lower() == lower then return name end
  end
  for name, _ in pairs(Nebbie.debuffSpells or {}) do
    if name:lower() == lower then return name end
  end
  for _, entry in ipairs(Nebbie.wearOff or {}) do
    if entry.name:lower() == lower then return entry.name end
  end
  for _, entry in ipairs(Nebbie.wearOffSoon or {}) do
    if entry.name:lower() == lower then return entry.name end
  end
  return spell
end

function Nebbie.buffTimeLeft(data, now)
  now = now or Nebbie.now()
  if not data or not data.since then return nil end
  if data.duration and data.duration > 0 then
    return data.duration - (now - data.since)
  end
  return nil
end

function Nebbie.isBuffExpired(data, now)
  if not data then return true end
  now = now or Nebbie.now()
  if data.synced then
    local left = Nebbie.buffTimeLeft(data, now)
    if left == nil then return false end
    return left <= 0
  end
  if not data.duration or data.duration <= 0 then return false end
  local left = Nebbie.buffTimeLeft(data, now)
  if left == nil then return false end
  return left <= 0
end

function Nebbie.pruneExpiredBuffs()
  local now = Nebbie.now()
  local remove = {}
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
      if Nebbie.isBuffExpired(data, now) then
        table.insert(remove, spell)
      end
    end
  end
  for _, spell in ipairs(remove) do
    Nebbie.buffs[spell] = nil
  end
end

function Nebbie.pruneStaleDebuffs()
  for name, _ in pairs(Nebbie.debuffs or {}) do
    if Nebbie.debuffSpells and Nebbie.debuffSpells[name] then
      Nebbie.debuffs[name] = nil
    end
  end
end

function Nebbie.beginAttribScan()
  Nebbie._attribScanActive = true
  Nebbie._attribSeenSpells = {}
end

function Nebbie.endAttribScan()
  if not Nebbie._attribScanActive then return end
  Nebbie._attribScanActive = false
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
      if data.synced and Nebbie.shouldTrackBuff(spell) and not Nebbie._attribSeenSpells[spell] then
        Nebbie.buffs[spell] = nil
      end
    end
  end
  Nebbie._attribSeenSpells = nil
end

function Nebbie.pruneInvalidBuffs()
  for spell, _ in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and not Nebbie.shouldTrackBuff(spell) then
      Nebbie.buffs[spell] = nil
    end
  end
end

function Nebbie.onBuffApplied(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  local lower = spell:lower()
  for key, _ in pairs(Nebbie.buffs or {}) do
    if type(key) == "string" and key:sub(1, 1) ~= "_" and key:lower() == lower and key ~= spell then
      Nebbie.buffs[key] = nil
    end
  end
  local est = Nebbie.buffDurations[spell] or 0
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = est,
    soon = false,
    active = true,
    synced = false,
    source = "cast",
  }
  Nebbie.buffs._lastCast = spell
  if Nebbie.isDebuffSpell(spell) and (not est or est <= 0) then
    tempTimer(0.8, function()
      if Nebbie and Nebbie.requestAttrib and not Nebbie._attribBusy then
        Nebbie.requestAttrib(true)
      end
    end)
  end
  Nebbie.refreshGUI()
end

function Nebbie.onBuffWearOff(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if spell then Nebbie.buffs[spell] = nil end
  Nebbie.refreshGUI()
end

function Nebbie.onBuffSoon(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  if Nebbie.buffs[spell] then Nebbie.buffs[spell].soon = true
  else
    Nebbie.buffs[spell] = {
      since = Nebbie.now(),
      duration = Nebbie.buffDurations[spell] or 0,
      soon = true,
      active = true,
      synced = false,
    }
  end
  Nebbie.refreshGUI()
end

function Nebbie.matchDebuffApply(name, plain)
  if not plain or plain == "" then return false end
  return Nebbie.isSelfAffectLine(plain)
end

function Nebbie.onDebuffApplied(name)
  if Nebbie.debuffSpells and Nebbie.debuffSpells[name] then return end
  Nebbie.debuffs[name] = { since = Nebbie.now(), active = true }
  Nebbie.refreshGUI()
end

function Nebbie.onDebuffWearOff(name)
  Nebbie.debuffs[name] = nil
  Nebbie.refreshGUI()
end

-- Loot mob corpo / pile of dust and bones (not PC corpses).
-- Uses look snapshot: corp, 2.corp, 3.corp … / pile, 2.pile, 3.pile …
function Nebbie.isMobKillExpLine(line)
  local plain = Nebbie.stripColors(line or "")
  if plain == "" then return false end
  if plain:find("%$c") then return false end
  return plain:match("^La tua esperienza e' aumentata di %d+ punti%.?$") ~= nil
end

function Nebbie.isTrustedCoinLine(line)
  local plain = Nebbie.stripColors(line or "")
  if plain == "" then return false end
  if plain:find("%$c") then return false end
  if plain:match("^%S+%s+C'erano") or plain:match("^%S+%s+C'era") then return false end
  return plain:match("^C'erano %d+ monete%.?$") ~= nil
    or plain:match("^C'era una miserabile moneta%.?$") ~= nil
end

function Nebbie.classifyCorpseLookLine(plain)
  if not plain or plain == "" then return nil end
  local low = plain:lower()
  if low:find("pile of dust and bones") or low:find("polvere") and low:find("ossa") then
    return "pile"
  end
  if low:find("corpo sfigurato") then return "corp" end
  if low:find("il corpo di un ") or low:find("il corpo di una ") or low:find("il corpo di uno ") then
    return "corp"
  end
  if low:find("il corpo di ") then
    if plain:match("il corpo di [%u%u'][%a']*$") or plain:match("il corpo di [%u%u'][%a']*%s") then
      return "pc"
    end
    return "corp"
  end
  return nil
end

function Nebbie.resetLookLoot()
  Nebbie._lookLootActive = false
  Nebbie._lookLootCorpses = 0
  Nebbie._lookLootPiles = 0
end

function Nebbie.onLookLootLine(line)
  if not Nebbie._lookLootActive then return end
  local plain = Nebbie.stripColors(line or "")
  local kind = Nebbie.classifyCorpseLookLine(plain)
  if kind == "corp" then
    Nebbie._lookLootCorpses = (Nebbie._lookLootCorpses or 0) + 1
  elseif kind == "pile" then
    Nebbie._lookLootPiles = (Nebbie._lookLootPiles or 0) + 1
  end
end

function Nebbie.runCmdQueue(cmds, idx, onDone)
  idx = idx or 1
  if not cmds or idx > #cmds then
    if onDone then onDone() end
    return
  end
  send(cmds[idx])
  tempTimer(0.5, function() Nebbie.runCmdQueue(cmds, idx + 1, onDone) end)
end

function Nebbie.runLootQueue(cmds, idx)
  Nebbie.runCmdQueue(cmds, idx, function() Nebbie._lootBusy = false end)
end

function Nebbie.buildLootCommands()
  local cmds = {}
  local corpses = Nebbie._lookLootCorpses or 0
  local piles = Nebbie._lookLootPiles or 0
  for i = 1, corpses do
    if i == 1 then
      table.insert(cmds, "get all corp")
    else
      table.insert(cmds, "get all " .. i .. ".corp")
    end
  end
  for i = 1, piles do
    if i == 1 then
      table.insert(cmds, "get all pile")
    else
      table.insert(cmds, "get all " .. i .. ".pile")
    end
  end
  if corpses == 0 and piles == 0 then
    cmds = {"get all corp", "get all pile"}
  end
  return cmds
end

function Nebbie.finishLookLoot(verbose)
  Nebbie._lookLootActive = false
  local cmds = Nebbie.buildLootCommands()
  if verbose then
    cecho("<green>Nebbie: loot <yellow>" .. #cmds .. "<green> comandi"
      .. " (<grey>corp=" .. tostring(Nebbie._lookLootCorpses or 0)
      .. " pile=" .. tostring(Nebbie._lookLootPiles or 0) .. "<grey>).\n")
  end
  Nebbie._lootBusy = true
  Nebbie.runLootQueue(cmds, 1)
end

function Nebbie.startLookLoot(verbose)
  if Nebbie._lootBusy then
    if verbose then cecho("<orange>Nebbie: loot gia' in corso.\n") end
    return
  end
  Nebbie.resetLookLoot()
  Nebbie._lookLootActive = true
  Nebbie._lookLootCorpses = 0
  Nebbie._lookLootPiles = 0
  send("look")
  if Nebbie._lookLootTimer then killTimer(Nebbie._lookLootTimer) end
  Nebbie._lookLootTimer = tempTimer(1.0, function()
    Nebbie._lookLootTimer = nil
    Nebbie.finishLookLoot(verbose)
  end)
end

function Nebbie.lootMobRemains(verbose)
  Nebbie.startLookLoot(verbose)
end

-- Cambio arma da borsa sulla schiena: usa <arma>
function Nebbie.normalizeEqDesc(desc)
  if not desc or desc == "" then return "" end
  local plain = Nebbie.stripColors(desc)
  plain = plain:gsub("%s*%b()", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return plain:lower()
end

function Nebbie.getEqKeywordRules()
  Nebbie.loadSettings()
  local rules = {}
  for _, r in ipairs(Nebbie.DEFAULT_EQ_KEYWORDS or {}) do
    table.insert(rules, r)
  end
  for _, r in ipairs(Nebbie._settings.eqKeywords or {}) do
    if type(r) == "table" and r.match and r.key then
      table.insert(rules, r)
    end
  end
  return rules
end

function Nebbie.guessEqKeyword(desc)
  local plain = Nebbie.normalizeEqDesc(desc)
  if plain == "" then return "" end
  local orig = Nebbie.stripColors(desc):gsub("%s*%b()", "")
  for word in orig:gmatch("[%w']+") do
    if word:match("^%u") and #word >= 4 then
      local low = word:lower()
      if not Nebbie.EQ_STOPWORDS[low] then return low end
    end
  end
  plain = plain:gsub("^un[oa']%s+", ""):gsub("^uno%s+", ""):gsub("^il%s+", "")
  plain = plain:gsub("^la%s+", ""):gsub("^lo%s+", ""):gsub("^i%s+", "")
  plain = plain:gsub("^le%s+", ""):gsub("^gli%s+", ""):gsub("^l['']", "")
  plain = plain:gsub("^a%s+", ""):gsub("^an%s+", "")
  local first = plain:match("^(%S+)")
  return first or plain
end

function Nebbie.lookupEqKeyword(desc)
  local norm = Nebbie.normalizeEqDesc(desc)
  if norm == "" then return "" end
  local bestKey, bestLen = nil, 0
  for _, r in ipairs(Nebbie.getEqKeywordRules()) do
    local m = (r.match or ""):lower()
    if m ~= "" and norm:find(m, 1, true) and #m > bestLen then
      bestKey = r.key
      bestLen = #m
    end
  end
  if bestKey then return bestKey end
  return Nebbie.guessEqKeyword(desc)
end

function Nebbie.eqItemKeyword(desc)
  return Nebbie.lookupEqKeyword(desc)
end

function Nebbie.addEqKey(key, pattern)
  key = Nebbie.stripQuotes(key or ""):lower()
  pattern = Nebbie.stripQuotes(pattern or ""):lower()
  if key == "" or pattern == "" then
    cecho("<orange>Nebbie: <yellow>nkey add <chiave> <testo nel nome eq><orange>\n")
    cecho("<grey>Esempio: <yellow>nkey add korred borsa inesauribile korred\n")
    return
  end
  Nebbie.loadSettings()
  Nebbie._settings.eqKeywords = Nebbie._settings.eqKeywords or {}
  for i, r in ipairs(Nebbie._settings.eqKeywords) do
    if r.match == pattern then
      Nebbie._settings.eqKeywords[i] = { match = pattern, key = key }
      if Nebbie._charName then Nebbie.persistCharState() end
      Nebbie.saveSettings()
      cecho("<green>Nebbie: aggiornato <yellow>" .. pattern .. " <green>→ <yellow>" .. key .. "\n")
      return
    end
  end
  table.insert(Nebbie._settings.eqKeywords, { match = pattern, key = key })
  if Nebbie._charName then Nebbie.persistCharState() end
  Nebbie.saveSettings()
  cecho("<green>Nebbie: chiave <yellow>" .. key .. " <green>per nome che contiene <yellow>" .. pattern .. "\n")
end

function Nebbie.delEqKey(pattern)
  pattern = Nebbie.stripQuotes(pattern or ""):lower()
  if pattern == "" then
    cecho("<orange>Nebbie: <yellow>nkey del <testo nel nome eq><orange>\n")
    cecho("<grey>  oppure: <yellow>nkey del key <parola MUD>\n")
    return
  end
  Nebbie.loadSettings()
  local kept, removed = {}, false
  for _, r in ipairs(Nebbie._settings.eqKeywords or {}) do
    if r.match == pattern or r.key == pattern then
      removed = true
    else
      table.insert(kept, r)
    end
  end
  Nebbie._settings.eqKeywords = kept
  if Nebbie._charName then Nebbie.persistCharState() end
  Nebbie.saveSettings()
  if removed then
    cecho("<green>Nebbie: rimossa regola custom <yellow>" .. pattern .. "\n")
  else
    cecho("<orange>Nebbie: nessuna regola custom per <yellow>" .. pattern .. "\n")
    cecho("<grey>  I default (korred, elf, …) non si cancellano.\n")
  end
end

function Nebbie.listEqKeys()
  cecho("<cyan><b>Chiavi eq Nebbie</b>\n")
  cecho("<grey>Da un nome lungo in <white>eq<grey> alla parola per <white>get / rem / wie / hold<grey>.\n\n")
  cecho("<dark_green><b>Default</b> <grey>(integrate, non cancellabili):\n")
  for _, r in ipairs(Nebbie.DEFAULT_EQ_KEYWORDS or {}) do
    cecho("<grey>  <yellow>" .. r.key .. " <grey>← <white>" .. r.match .. "\n")
  end
  Nebbie.loadSettings()
  local custom = Nebbie._settings.eqKeywords or {}
  cecho("<grey><b>Custom</b> <grey>(tue regole):\n")
  if #custom == 0 then
    cecho("<grey>  (nessuna)\n")
  else
    for _, r in ipairs(custom) do
      cecho("<grey>  <yellow>" .. r.key .. " <grey>← <white>" .. r.match .. "\n")
    end
  end
  cecho("\n<yellow>nkey add <parola> <testo nel nome eq>\n")
  cecho("<grey>  es. <white>nkey add redentore il redentore\n")
  cecho("<yellow>nkey del <testo nel nome eq>\n")
  cecho("<grey>  es. <white>nkey del il redentore<grey> — cancella la regola con quel testo\n")
  cecho("<yellow>nkey del key <parola>\n")
  cecho("<grey>  es. <white>nkey del key redentore<grey> — cancella per parola MUD\n")
  cecho("<yellow>neq clear<grey> — azzera impugnato in cache (se rimasta una chiave sbagliata)\n")
end

function Nebbie.trimEqItemName(item)
  if not item then return nil end
  item = item:gsub("^%s+", ""):gsub("%s+$", "")
  if item == "" or item == "Qualcosa." then return nil end
  return item
end

function Nebbie.parseEqSlotLine(line)
  if not line or line == "" then return nil, nil end
  local plain = Nebbie.stripColors(line)

  -- eq MUD: "[18] <sulla schiena>         Nome oggetto" — match ovunque nella riga
  local wield = Nebbie.trimEqItemName(plain:match(".*<impugnato>%s+(.+)"))
  if wield then return "wield", wield end

  local hold = Nebbie.trimEqItemName(plain:match(".*<tenuto>%s+(.+)"))
  if hold then return "hold", hold end

  local back = Nebbie.trimEqItemName(plain:match(".*<sulla schiena>%s+(.+)"))
  if back then return "back", back end

  -- tag senza nome sulla stessa riga (nome sulla riga dopo)
  if plain:find("<impugnato>", 1, true) and not plain:match(".*<impugnato>%s+%S") then
    return "wield", ""
  end
  if plain:find("<tenuto>", 1, true) and not plain:match(".*<tenuto>%s+%S") then
    return "hold", ""
  end
  if plain:find("<sulla schiena>", 1, true) and not plain:match(".*<sulla schiena>%s+%S") then
    return "back", ""
  end

  return nil, nil
end

function Nebbie.isEqListLine(plain)
  if not plain or plain == "" then return false end
  if plain:find("Stai usando", 1, true) then return true end
  if plain:match("^Nulla%.?") then return true end
  if plain:match("^%[%s*%d+%]") then return true end
  if plain:find("<impugnato>", 1, true) then return true end
  if plain:find("<tenuto>", 1, true) then return true end
  if plain:find("<sulla schiena>", 1, true) then return true end
  return false
end

Nebbie.EQ_AUTO_INTERVAL = 3600
Nebbie.EQ_CACHE_MAX_AGE = 3600
Nebbie.EQ_WIELD_TRUST_AGE = 600
Nebbie.EQ_SWAP_FIRST_WAIT = 4.0
Nebbie.EQ_SWAP_AFTER_EQ = 2.0
Nebbie.EQ_SWAP_RETRY_WAIT = 2.5
Nebbie.EQ_SWAP_MAX_RETRIES = 2
Nebbie.EQ_SWAP_POLL_LINES = 200

function Nebbie.saveEqCache()
  Nebbie._settings = Nebbie._settings or {}
  Nebbie._settings.eqCache = Nebbie.eqCache
  if Nebbie._charName and Nebbie._charName ~= "" then
    local profile = Nebbie.getCharProfileRecord(Nebbie._charName, true)
    if profile then profile.eqCache = Nebbie.copyEqCacheTable(Nebbie.eqCache) end
  end
  Nebbie.saveSettings()
end

function Nebbie.eqCacheAge()
  local c = Nebbie.eqCache
  if not c or not c.updatedAt or c.updatedAt <= 0 then return nil end
  return Nebbie.now() - c.updatedAt
end

function Nebbie.eqCacheIsFresh()
  local c = Nebbie.eqCache or {}
  if not c.back or c.back == "" then return false end
  local age = Nebbie.eqCacheAge()
  return age ~= nil and age <= Nebbie.EQ_CACHE_MAX_AGE
end

function Nebbie.eqCacheWieldTrustworthy()
  local c = Nebbie.eqCache or {}
  if not c.wieldScannedAt or c.wieldScannedAt <= 0 then return false end
  return (Nebbie.now() - c.wieldScannedAt) <= Nebbie.EQ_WIELD_TRUST_AGE
end

function Nebbie.eqCacheIsFreshForSwap()
  return Nebbie.eqCacheIsFresh()
end

function Nebbie.inCombat()
  local s = Nebbie.stats
  if not s then return false end
  if s.mobName and s.mobName ~= "" and s.mobName ~= "*" then return true end
  if s.tankName and s.tankName ~= "" and s.tankName ~= "*" then return true end
  return false
end

function Nebbie.clearEqCacheWield()
  Nebbie.eqCache = Nebbie.eqCache or {}
  Nebbie.eqCache.wield = nil
  Nebbie.eqCache.wieldKey = nil
  Nebbie.eqCache.wieldScannedAt = 0
  Nebbie.saveEqCache()
  cecho("<green>Nebbie: cache <impugnato> azzerata. Usa <yellow>neq<green> per aggiornare.\n")
end

function Nebbie.isPromptLine(plain)
  if not plain or plain == "" then return false end
  return plain:find("H:%d+/%d+") ~= nil or plain:find("H%d+/%d+") ~= nil
end

function Nebbie.scanEqBufferSnapshot()
  if type(getLastLineNumber) ~= "function" or type(getLines) ~= "function" then return false end
  local last = getLastLineNumber()
  if not last or last < 1 then return false end
  local from = math.max(1, last - 200)
  local lines = getLines(from, last)
  if type(lines) ~= "table" then return false end

  -- Usa l'ultimo "Stai usando:" nel buffer (eq più recente)
  local startIdx = nil
  for i = #lines, 1, -1 do
    local plain = Nebbie.stripColors(lines[i] or "")
    if plain:find("Stai usando", 1, true) then
      startIdx = i
      break
    end
  end
  if not startIdx then return false end

  local wield, back, hold = nil, nil, nil
  local pendingSlot, pendingText = nil, nil

  for i = startIdx + 1, #lines do
    local text = lines[i]
    if type(text) == "string" then
      local plain = Nebbie.stripColors(text)
      if plain ~= "" then
        if Nebbie.isPromptLine(plain) then break end
        if plain:match("^Nulla%.?") then
          wield, back, hold = nil, nil, nil
          break
        end
        local slot, item = Nebbie.parseEqSlotLine(text)
        if slot then
          if item == "" then
            pendingSlot = slot
            pendingText = nil
          else
            pendingSlot, pendingText = nil, nil
            if slot == "wield" then wield = item
            elseif slot == "hold" then hold = item
            else back = item end
          end
        elseif pendingSlot and plain ~= "" and not plain:match("^%[%s*%d+%]") and not Nebbie.isPromptLine(plain) then
          pendingText = pendingText and (pendingText .. " " .. plain) or plain
          local combined = Nebbie.trimEqItemName(pendingText)
          if combined then
            if pendingSlot == "wield" then wield = combined
            elseif pendingSlot == "hold" then hold = combined
            else back = combined end
            pendingSlot, pendingText = nil, nil
          end
        end
      end
    end
  end

  Nebbie.eqCache = Nebbie.eqCache or {}
  Nebbie.eqCache.wield = wield
  Nebbie.eqCache.back = back
  Nebbie.eqCache.hold = hold
  Nebbie.eqCache.wieldKey = wield and Nebbie.eqItemKeyword(wield) or nil
  Nebbie.eqCache.backKey = back and Nebbie.eqItemKeyword(back) or nil
  Nebbie.eqCache.holdKey = hold and Nebbie.eqItemKeyword(hold) or nil
  Nebbie.eqCache.updatedAt = Nebbie.now()
  Nebbie.eqCache.wieldScannedAt = Nebbie.now()
  Nebbie.saveEqCache()

  if Nebbie._weaponSwap and Nebbie._eqParseActive then
    Nebbie._weaponSwap.wield = wield
    Nebbie._weaponSwap.back = back
    Nebbie._weaponSwap.hold = hold
    Nebbie._weaponSwap.wieldConfirmed = true
    if back and back ~= "" then
      Nebbie._weaponSwap._eqSeen = true
      if not Nebbie._weaponSwap._finishScheduled then
        Nebbie._weaponSwap._finishScheduled = true
        Nebbie.scheduleWeaponSwapTimeout(0.25)
      end
    end
  end
  return true
end

function Nebbie.scheduleEqCacheScan(delay)
  delay = delay or 1.5
  if Nebbie._eqScanTimer then killTimer(Nebbie._eqScanTimer) end
  Nebbie._eqScanTimer = tempTimer(delay, function()
    Nebbie._eqScanTimer = nil
    Nebbie.scanEqBufferSnapshot()
  end)
end

function Nebbie.installEqSendHook()
  if Nebbie._eqSendHookId then return end
  if type(registerAnonymousEventHandler) ~= "function" then return end
  local ok, id = pcall(function()
    return registerAnonymousEventHandler("sysDataSendEvent", function(_, cmd)
      if type(cmd) ~= "string" then return end
      local word = cmd:match("^%s*(%S+)")
      if word and word:lower() == "eq" then
        Nebbie.scheduleEqCacheScan(2.0)
      end
      if Nebbie.onCharMenuSend then Nebbie.onCharMenuSend(cmd) end
    end)
  end)
  if ok and id then Nebbie._eqSendHookId = id end
end

function Nebbie.beginEqSnapshot()
  Nebbie._eqSnapshot = { wield = nil, back = nil }
end

function Nebbie.applyEqSlot(slot, item)
  if not slot then return end
  Nebbie.eqCache = Nebbie.eqCache or {}
  if slot == "wield" then
    Nebbie.eqCache.wield = item
    Nebbie.eqCache.wieldKey = (item and item ~= "") and Nebbie.eqItemKeyword(item) or nil
    Nebbie.eqCache.wieldScannedAt = Nebbie.now()
  elseif slot == "hold" then
    Nebbie.eqCache.hold = item
    Nebbie.eqCache.holdKey = (item and item ~= "") and Nebbie.eqItemKeyword(item) or nil
  elseif slot == "back" then
    Nebbie.eqCache.back = item
    Nebbie.eqCache.backKey = (item and item ~= "") and Nebbie.eqItemKeyword(item) or nil
  end
  Nebbie.eqCache.updatedAt = Nebbie.now()
  Nebbie.saveEqCache()
  if Nebbie._eqSnapshot then Nebbie._eqSnapshot[slot] = item end
end

function Nebbie.onEqLine(line)
  local plain = Nebbie.stripColors(line or "")
  local isEqOutput = false

  if plain:find("Stai usando", 1, true) then
    isEqOutput = true
    Nebbie.scheduleEqCacheScan(2.0)
  elseif plain:match("^Nulla%.?") then
    isEqOutput = true
    Nebbie.scheduleEqCacheScan(0.5)
  elseif Nebbie.isEqListLine(plain) then
    isEqOutput = true
  end

  if Nebbie._eqCacheGag and isEqOutput and type(deleteLine) == "function" then
    deleteLine()
  end
  return isEqOutput
end

function Nebbie.testEqParse(silent)
  local samples = {
    { line = "[16] <impugnato>             Elf Slayer (ha un alone di luce rossa) (emette un forte ronzio)", slot = "wield", want = "Elf Slayer" },
    { line = "[18] <sulla schiena>         Borsa Inesauribile dei Korred", slot = "back", want = "Borsa Inesauribile dei Korred" },
  }
  local ok = true
  for _, s in ipairs(samples) do
    local slot, item = Nebbie.parseEqSlotLine(s.line)
    if slot ~= s.slot or not item or not item:find(s.want, 1, true) then
      ok = false
      if not silent then
        cecho("<red>Nebbie EQ parse FAIL: " .. tostring(slot) .. " / " .. tostring(item) .. "\n")
      end
    end
  end
  if not silent then
    cecho(ok and ("<green>Nebbie: EQ parse OK (v" .. Nebbie.version .. ").\n")
      or ("<red>Nebbie: EQ parse FALLITO (v" .. Nebbie.version .. ").\n"))
  end
  return ok
end

function Nebbie.showEqCache()
  Nebbie.loadSettings()
  local c = Nebbie.eqCache or {}
  cecho("<cyan><b>Cache eq Nebbie</b> <grey>(schiena + impugnato + tenuto)\n")
  cecho("<grey>  schiena: <white>" .. tostring(c.back or "(vuoto)"))
  if c.backKey and c.backKey ~= "" then
    cecho(" <dark_green>[" .. c.backKey .. "]")
  end
  cecho("\n")
  cecho("<grey>  impugnato: <white>" .. tostring(c.wield or "(vuoto)"))
  if c.wieldKey and c.wieldKey ~= "" then
    cecho(" <dark_green>[" .. c.wieldKey .. "]")
  end
  if Nebbie.eqCacheWieldTrustworthy() then
    cecho(" <dark_green>(affidabile)")
  elseif c.wieldKey and c.wieldKey ~= "" then
    cecho(" <orange>(vecchia — <yellow>neq clear<orange> o <yellow>neq<orange> per aggiornare)")
  end
  cecho("\n")
  cecho("<grey>  tenuto: <white>" .. tostring(c.hold or "(vuoto)"))
  if c.holdKey and c.holdKey ~= "" then
    cecho(" <dark_green>[" .. c.holdKey .. "]")
  end
  cecho("\n")
  local age = Nebbie.eqCacheAge()
  if age and age > 0 then
    if age >= 3600 then
      cecho(string.format("<grey>  aggiornato: <yellow>%.1f h fa\n", age / 3600))
    else
      cecho("<grey>  aggiornato: <yellow>" .. math.floor(age) .. " s fa\n")
    end
  else
    cecho("<grey>  aggiornato: <yellow>mai\n")
  end
  cecho("<grey>  sync auto 1h: <yellow>" .. (Nebbie.eqAuto and "on" or "off") .. "\n")
end

function Nebbie.requestEqCache(silent)
  if Nebbie._eqCacheBusy then return false end
  if Nebbie.inCombat() then
    if not silent then
      cecho("<orange>Nebbie: <yellow>eq<orange> automatico saltato in combattimento (evita lag).\n")
      cecho("<grey>  <yellow>usa<grey> usa la cache; <yellow>neq clear<grey> se impugnato in cache e' sbagliato.\n")
    end
    return false
  end
  Nebbie._eqCacheBusy = true
  Nebbie._eqCacheGag = silent == true
  send("eq")
  Nebbie.scheduleEqCacheScan(2.5)
  tempTimer(3, function()
    Nebbie._eqCacheBusy = false
    Nebbie._eqCacheGag = false
  end)
  return true
end

function Nebbie.setEqAuto(on)
  Nebbie.eqAuto = on
  Nebbie._settings.eqAuto = on
  Nebbie.saveSettings()
  Nebbie.syncEqCacheTimer()
  if on then
    cecho("<green>Nebbie: sync eq ogni 1h attivo (gagged).\n")
    if not Nebbie.eqCacheIsFresh() and not Nebbie.inCombat() then
      tempTimer(1, function() Nebbie.requestEqCache(true) end)
    end
  else
    cecho("<green>Nebbie: sync eq automatico disattivato.\n")
  end
end

function Nebbie.syncEqCacheTimer()
  if Nebbie.eqCacheTimer then killTimer(Nebbie.eqCacheTimer); Nebbie.eqCacheTimer = nil end
  if Nebbie.eqAuto then
    Nebbie.eqCacheTimer = tempTimer(Nebbie.EQ_AUTO_INTERVAL, function()
      if Nebbie.eqAuto and not Nebbie._weaponSwapBusy and not Nebbie.inCombat() then
        Nebbie.requestEqCache(true)
      end
    end, true)
  end
end

function Nebbie.maybeRefreshEqCacheOnBoot()
  if not Nebbie.eqAuto then return end
  tempTimer(8, function()
    if Nebbie._weaponSwapBusy or Nebbie._eqCacheBusy or Nebbie.inCombat() then return end
    local age = Nebbie.eqCacheAge()
    if not age or age >= Nebbie.EQ_AUTO_INTERVAL then
      Nebbie.requestEqCache(true)
    end
  end)
end

function Nebbie.onEqParseLine()
  local line = Nebbie.resolveTriggerLine()
  Nebbie.onEqLine(line)

  if not Nebbie._weaponSwap or not Nebbie._eqParseActive then return end
  local plain = Nebbie.stripColors(line or "")
  if plain:find("Stai usando", 1, true) then
    Nebbie._weaponSwap._eqSeen = true
    Nebbie._weaponSwap.wield = nil
    Nebbie._weaponSwap.back = nil
    Nebbie._weaponSwap.hold = nil
    Nebbie._weaponSwap.wieldConfirmed = false
    Nebbie.scheduleWeaponSwapTimeout(Nebbie.EQ_SWAP_AFTER_EQ)
    Nebbie.scheduleEqCacheScan(2.0)
  end
end

function Nebbie.pollEqFromBuffer(maxLines)
  if type(getLastLineNumber) ~= "function" or type(getLines) ~= "function" then return end
  local last = getLastLineNumber()
  if not last or last < 1 then return end
  local span = maxLines or (Nebbie._eqParseActive and Nebbie.EQ_SWAP_POLL_LINES or 80)
  local from = math.max(1, last - span)
  local lines = getLines(from, last)
  if type(lines) ~= "table" then return end
  for _, text in ipairs(lines) do
    if type(text) == "string" and text ~= "" then
      Nebbie.onEqParseLine(text)
    end
  end
end

function Nebbie.scheduleWeaponSwapTimeout(delay)
  if Nebbie._weaponSwapTimer then killTimer(Nebbie._weaponSwapTimer) end
  Nebbie._weaponSwapTimer = tempTimer(delay, function()
    Nebbie._weaponSwapTimer = nil
    Nebbie.pollEqFromBuffer(Nebbie.EQ_SWAP_POLL_LINES)
    local ws = Nebbie._weaponSwap
    if ws and ws.back then
      Nebbie.finishWeaponSwap(ws._verbose)
      return
    end
    if ws and (ws._retries or 0) < Nebbie.EQ_SWAP_MAX_RETRIES then
      ws._retries = (ws._retries or 0) + 1
      ws._eqSeen = false
      ws._finishScheduled = false
      if Nebbie.inCombat() then
        cecho("<grey>Nebbie: eq in combattimento saltato — uso cache borsa.\n")
        Nebbie.finishWeaponSwap(ws._verbose)
        return
      end
      if ws._retries == 1 then
        cecho("<grey>Nebbie: eq in ritardo — riprovo...\n")
      end
      send("eq")
      Nebbie.scheduleWeaponSwapTimeout(Nebbie.EQ_SWAP_RETRY_WAIT)
      return
    end
    Nebbie.finishWeaponSwap(ws and ws._verbose)
  end)
end

function Nebbie.buildWeaponSwapCommands(ws)
  local backKw = Nebbie.eqItemKeyword(ws.back)
  local wieldKw = ws.wield and Nebbie.eqItemKeyword(ws.wield) or nil
  local weapon = ws.weapon
  if backKw == "" or not weapon or weapon == "" then return nil end
  local cmds = {
    "rem " .. backKw,
    "get " .. weapon .. " " .. backKw,
  }
  if ws.wieldConfirmed and wieldKw and wieldKw ~= "" then
    table.insert(cmds, "rem " .. wieldKw)
  end
  table.insert(cmds, "wie " .. weapon)
  if ws.wieldConfirmed and wieldKw and wieldKw ~= "" then
    table.insert(cmds, "put " .. wieldKw .. " " .. backKw)
  end
  table.insert(cmds, "wear " .. backKw)
  return cmds
end

function Nebbie.finishWeaponSwapFromState(ws)
  if not ws then return end
  if not ws.back then
    cecho("<red>Nebbie: nessun oggetto nello slot <sulla schiena> — controlla con eq.\n")
    if not ws._eqSeen then
      cecho("<grey>  (eq non ancora parsato — riprova o fai <yellow>neq<grey>)\n")
    end
    return
  end
  local cmds = Nebbie.buildWeaponSwapCommands(ws)
  if not cmds then
    cecho("<red>Nebbie: impossibile costruire la sequenza cambio arma.\n")
    return
  end
  if ws._verbose then
    local src = ws._fromCache and "cache eq" or "eq live"
    local wieldLabel = "(vuoto)"
    if ws.wield and ws.wield ~= "" then
      wieldLabel = Nebbie.lookupEqKeyword(ws.wield)
      if not ws.wieldConfirmed then wieldLabel = wieldLabel .. "?" end
    end
    cecho("<green>Nebbie: cambio arma → <yellow>" .. ws.weapon
      .. "<green> (" .. src .. ", borsa: <yellow>" .. Nebbie.lookupEqKeyword(ws.back)
      .. "<green>, impugnato: <yellow>" .. wieldLabel
      .. "<green>).\n")
  end
  Nebbie._weaponSwapBusy = true
  Nebbie.runCmdQueue(cmds, 1, function()
    Nebbie._weaponSwapBusy = false
    tempTimer(1.5, function()
      if not Nebbie.inCombat() then
        Nebbie.requestEqCache(true)
      end
    end)
  end)
end

function Nebbie.finishWeaponSwap(verbose)
  if Nebbie._weaponSwapTimer then
    killTimer(Nebbie._weaponSwapTimer)
    Nebbie._weaponSwapTimer = nil
  end
  local ws = Nebbie._weaponSwap
  if ws then Nebbie.pollEqFromBuffer(Nebbie.EQ_SWAP_POLL_LINES) end
  Nebbie._eqParseActive = false
  Nebbie._weaponSwap = nil
  if not ws then return end
  ws._verbose = verbose
  Nebbie.finishWeaponSwapFromState(ws)
end

function Nebbie.swapWeapon(weaponKw, verbose)
  weaponKw = Nebbie.stripQuotes(weaponKw or "")
  if weaponKw == "" then
    cecho("<orange>Nebbie: sintassi <yellow>usa <arma><orange> (es. <yellow>usa redentore<orange>).\n")
    return
  end
  if Nebbie._weaponSwapBusy then
    if verbose ~= false then cecho("<orange>Nebbie: cambio arma gia' in corso.\n") end
    return
  end
  Nebbie.loadSettings()
  Nebbie.pollPromptFromBuffer()

  local function buildWsFromCache()
    local wieldConfirmed = Nebbie.eqCacheWieldTrustworthy()
    return {
      weapon = weaponKw,
      wield = wieldConfirmed and Nebbie.eqCache.wield or nil,
      back = Nebbie.eqCache.back,
      hold = Nebbie.eqCache.hold,
      wieldConfirmed = wieldConfirmed,
      _verbose = verbose ~= false,
      _fromCache = true,
    }
  end

  if Nebbie.inCombat() then
    if not Nebbie.eqCacheIsFreshForSwap() then
      cecho("<red>Nebbie: in combattimento serve la cache borsa — fai <yellow>neq<red> fuori fight.\n")
      return
    end
    local ws = buildWsFromCache()
    if not ws.wieldConfirmed and Nebbie.eqCache.wieldKey and Nebbie.eqCache.wieldKey ~= "" then
      if verbose ~= false then
        cecho("<grey>Nebbie: impugnato in cache non affidabile — salto <yellow>rem "
          .. Nebbie.eqCache.wieldKey .. "<grey>.\n")
      end
    end
    Nebbie.finishWeaponSwapFromState(ws)
    return
  end

  if Nebbie.eqCacheIsFreshForSwap() then
    Nebbie.finishWeaponSwapFromState(buildWsFromCache())
    return
  end
  Nebbie._weaponSwap = {
    weapon = weaponKw, wield = nil, back = nil, hold = nil,
    wieldConfirmed = false,
    _eqSeen = false, _retries = 0, _finishScheduled = false,
    _verbose = verbose ~= false,
  }
  Nebbie._eqParseActive = true
  send("eq")
  Nebbie.scheduleWeaponSwapTimeout(Nebbie.EQ_SWAP_FIRST_WAIT)
end

function Nebbie.getBackBagKeyword()
  Nebbie.loadSettings()
  local c = Nebbie.eqCache or {}
  if c.backKey and c.backKey ~= "" then return c.backKey end
  if c.back and c.back ~= "" then
    local kw = Nebbie.lookupEqKeyword(c.back)
    if kw and kw ~= "" then return kw end
  end
  return nil
end

function Nebbie.setWeaponDropRecover(on)
  Nebbie.weaponDropRecover = on
  Nebbie._settings.weaponDropRecover = on
  Nebbie.saveSettings()
  cecho("<green>Nebbie: recupero armi cadute <yellow>" .. (on and "on" or "off") .. "\n")
end

function Nebbie._weaponDropKeyword(slot, dropDesc)
  local c = Nebbie.eqCache or {}
  if slot == "hold" and c.holdKey and c.holdKey ~= "" then
    return c.holdKey
  end
  if slot == "wield" and c.wieldKey and c.wieldKey ~= "" and Nebbie.eqCacheWieldTrustworthy() then
    return c.wieldKey
  end
  if dropDesc and dropDesc ~= "" then
    return Nebbie.lookupEqKeyword(dropDesc)
  end
  return nil
end

function Nebbie._pumpWeaponDropQueue()
  if Nebbie._weaponDropBusy then return end
  local q = Nebbie._weaponDropQueue
  if not q or #q == 0 then return end

  local job = table.remove(q, 1)
  local key = Nebbie._weaponDropKeyword(job.slot, job.desc)
  if not key or key == "" then
    cecho("<orange>Nebbie drop: keyword sconosciuta per <yellow>"
      .. tostring(job.desc) .. "<orange> — <yellow>neq<orange> o <yellow>nkey add ...\n")
    Nebbie._pumpWeaponDropQueue()
    return
  end

  local reeq = (job.slot == "hold") and ("hold " .. key) or ("wie " .. key)
  Nebbie._weaponDropBusy = true
  Nebbie.runCmdQueue({"get " .. key, reeq}, 1, function()
    Nebbie._weaponDropBusy = false
    tempTimer(0.8, function()
      if not Nebbie.inCombat() and Nebbie.requestEqCache then
        Nebbie.requestEqCache(true)
      end
      Nebbie._pumpWeaponDropQueue()
    end)
  end)
end

function Nebbie.enqueueWeaponDrop(slot, dropDesc)
  if Nebbie.weaponDropRecover == false then return end
  dropDesc = (dropDesc or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if dropDesc == "" then return end
  Nebbie._weaponDropQueue = Nebbie._weaponDropQueue or {}
  table.insert(Nebbie._weaponDropQueue, { slot = slot, desc = dropDesc })
  Nebbie._pumpWeaponDropQueue()
end

function Nebbie.onWeaponDropHoldLine(line)
  if not Nebbie.enqueueWeaponDrop then return end
  local plain = Nebbie.stripColors(line or "")
  local desc = plain:match("^(.-)%s+ti cade dalle mani%.?$")
  if desc then Nebbie.enqueueWeaponDrop("hold", desc) end
end

function Nebbie.onWeaponDropWieldLine(line)
  if not Nebbie.enqueueWeaponDrop then return end
  local plain = Nebbie.stripColors(line or "")
  local desc = plain:match("^e ti casca anche%s+(.+)!$")
  if desc then Nebbie.enqueueWeaponDrop("wield", desc) end
end

function Nebbie.setFoodDrinkAuto(on)
  Nebbie.foodDrinkAuto = on
  Nebbie._settings.foodDrinkAuto = on
  Nebbie.saveSettings()
  cecho("<green>Nebbie: fame/sete automatiche <yellow>" .. (on and "on" or "off") .. "\n")
end

function Nebbie.setFoodItemKey(itemKw)
  itemKw = Nebbie.stripQuotes(itemKw or ""):lower()
  if itemKw == "" then
    cecho("<orange>Nebbie: <yellow>nfood item <cornu|carne|...><orange>\n")
    return
  end
  Nebbie._settings.foodItemKey = itemKw
  Nebbie.saveSettings()
  cecho("<green>Nebbie: oggetto fame/sete → <yellow>" .. itemKw .. "\n")
end

function Nebbie.buildFoodDrinkCommands()
  local bagKw = Nebbie.getBackBagKeyword()
  if not bagKw or bagKw == "" then return nil end
  Nebbie.loadSettings()
  local itemKw = Nebbie._settings.foodItemKey or "cornu"
  return {
    "rem " .. bagKw,
    "get " .. itemKw .. " " .. bagKw,
    "dri " .. itemKw,
    "dri " .. itemKw,
    "dri " .. itemKw,
    "dri " .. itemKw,
    "dri " .. itemKw,
    "put " .. itemKw .. " " .. bagKw,
    "wear " .. bagKw,
  }
end

function Nebbie.autoFoodDrink()
  if Nebbie.foodDrinkAuto == false then return end
  if Nebbie._foodDrinkBusy then return end
  local cmds = Nebbie.buildFoodDrinkCommands()
  if not cmds then
    cecho("<orange>Nebbie: fame/sete — borsa sconosciuta (<yellow>neq<orange> per aggiornare cache).\n")
    return
  end
  Nebbie._foodDrinkBusy = true
  Nebbie.runCmdQueue(cmds, 1, function()
    Nebbie._foodDrinkBusy = false
  end)
end

function Nebbie.onMobKillExp(line)
  if not Nebbie.lootAuto then return end
  if not Nebbie.isMobKillExpLine(line) then return end
  tempTimer(0.25, function() Nebbie.startLookLoot(false) end)
end

function Nebbie.setLootAuto(on)
  Nebbie.lootAuto = on
  Nebbie._settings.lootAuto = on
  Nebbie.saveSettings()
  if on then
    cecho("<green>Nebbie: loot automatico mob attivo (su exp reale).\n")
  else
    cecho("<green>Nebbie: loot automatico disattivato — usa <yellow>nloot<green>.\n")
  end
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

Nebbie.layoutLeftW = 220
Nebbie.layoutRightW = 280
Nebbie.layoutHudH = 260
Nebbie.layoutMargin = 8
Nebbie.layoutGap = 6
Nebbie.guiHeaderH = 22
Nebbie.guiMargin = Nebbie.layoutMargin
Nebbie.guiLayoutVer = 9
Nebbie.guiGaugeH = 22
Nebbie.guiGaugeGap = 6
Nebbie.guiGaugeArea = 96
Nebbie.guiFontSize = 11
Nebbie.guiBar = "NebbieHUDBar"
Nebbie.guiConsole = "NebbieHUD"
Nebbie._bars = Nebbie._bars or {}

function Nebbie.dashboardPanelsVisible()
  return not Nebbie._dashboardHidden
end

function Nebbie.computeUILayout()
  local mw, mh = 800, 600
  if type(getMainWindowSize) == "function" then
    local ok, w, h = pcall(getMainWindowSize)
    if ok and w and h then mw, mh = w, h end
  end
  local m = Nebbie.layoutMargin or 8
  local leftW = Nebbie.layoutLeftW or 220
  local rightW = Nebbie.layoutRightW or 280
  local hudH = Nebbie.layoutHudH or 260
  local spellH = Nebbie.dashSpellH or 130
  local pathsH = Nebbie.dashPathsH or 110
  local gap = Nebbie.layoutGap or 6
  local showHud = Nebbie.guiExists() and not Nebbie.guiHidden()
  local showDash = Nebbie.dashboardPanelsVisible()
  local borderLeft = showDash and leftW or 0
  local borderRight = (showHud or showDash) and rightW or 0
  local rightX = mw - rightW
  local topY = m
  local rightY = topY
  local hud, eq, spells, paths, config = nil, nil, nil, nil, nil
  if showHud then
    hud = { x = rightX, y = rightY, w = rightW, h = hudH }
    rightY = rightY + hudH + gap
  end
  if showDash then
    eq = { x = m, y = topY, w = leftW - m, h = mh - 2 * m }
    spells = { x = rightX, y = rightY, w = rightW, h = spellH }
    paths = { x = rightX, y = rightY + spellH + gap, w = rightW, h = pathsH }
    local configY = rightY + spellH + gap + pathsH + gap
    config = { x = rightX, y = configY, w = rightW, h = math.max(72, mh - configY - m) }
  end
  return {
    mw = mw, mh = mh,
    borderLeft = borderLeft,
    borderRight = borderRight,
    hud = hud,
    eq = eq,
    spells = spells,
    paths = paths,
    config = config,
  }
end

function Nebbie.applyMainBorders(u)
  u = u or Nebbie.computeUILayout()
  if type(setBorderLeft) == "function" then
    pcall(setBorderLeft, u.borderLeft or 0)
  end
  if type(setBorderRight) == "function" then
    pcall(setBorderRight, u.borderRight or 0)
  end
end

function Nebbie.applyUILayout()
  local u = Nebbie.computeUILayout()
  Nebbie.applyMainBorders(u)
  if u.hud and Nebbie.guiExists() then
    Nebbie.applyGUIPosition(u.hud.x, u.hud.y, u.hud.w, u.hud.h)
  end
  if Nebbie.repositionDashboard then
    Nebbie.repositionDashboard(u)
  end
end

function Nebbie.guiExists()
  return Nebbie._guiBuilt == true
end

function Nebbie.guiHidden()
  return Nebbie._guiHidden == true
end

function Nebbie.showGUI()
  if type(showWindow) ~= "function" then return end
  showWindow(Nebbie.guiConsole)
  showWindow(Nebbie.guiBar)
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.showBar(key)
  end
  Nebbie._guiHidden = false
  Nebbie.applyUILayout()
end

function Nebbie.hideGUI()
  if type(hideWindow) ~= "function" then return end
  hideWindow(Nebbie.guiConsole)
  hideWindow(Nebbie.guiBar)
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.hideBar(key)
  end
  Nebbie._guiHidden = true
  Nebbie.applyUILayout()
end

function Nebbie.calcGUIPos()
  local u = Nebbie.computeUILayout()
  if u.hud then return u.hud.x, u.hud.y, u.hud.w, u.hud.h end
  local mw, mh = u.mw, u.mh
  return mw - Nebbie.layoutRightW, Nebbie.layoutMargin, Nebbie.layoutRightW, Nebbie.layoutHudH
end

function Nebbie.raiseBarLayers(key)
  if type(raiseWindow) ~= "function" then return end
  local bar = Nebbie._bars[key]
  if not bar then return end
  pcall(function() raiseWindow(bar.back) end)
  pcall(function() raiseWindow(bar.front) end)
  pcall(function() raiseWindow(bar.text) end)
end

function Nebbie.showBar(key)
  local bar = Nebbie._bars[key]
  if not bar or type(showWindow) ~= "function" then return end
  showWindow(bar.back)
  showWindow(bar.front)
  showWindow(bar.text)
end

function Nebbie.hideBar(key)
  local bar = Nebbie._bars[key]
  if not bar or type(hideWindow) ~= "function" then return end
  hideWindow(bar.back)
  hideWindow(bar.front)
  hideWindow(bar.text)
end

function Nebbie.deleteBar(key)
  local bar = Nebbie._bars[key]
  if not bar then return end
  if type(deleteLabel) == "function" then
    pcall(function() deleteLabel(bar.back) end)
    pcall(function() deleteLabel(bar.front) end)
    pcall(function() deleteLabel(bar.text) end)
  end
  Nebbie._bars[key] = nil
end

function Nebbie.deleteLegacyGauges()
  local keys = {"NebbieHP", "NebbieMN", "NebbieMV"}
  if type(deleteGauge) ~= "function" then return end
  for _, key in ipairs(keys) do
    pcall(function() deleteGauge(key) end)
  end
end

function Nebbie.paintBar(key, rgb, backRgb)
  backRgb = backRgb or {42, 42, 56}
  local bar = Nebbie._bars[key]
  if not bar or type(setBackgroundColor) ~= "function" then return end
  local r, g, b = rgb[1], rgb[2], rgb[3]
  pcall(function() setBackgroundColor(bar.back, backRgb[1], backRgb[2], backRgb[3], 255) end)
  pcall(function() setBackgroundColor(bar.front, r, g, b, 255) end)
  pcall(function() setBackgroundColor(bar.text, 0, 0, 0, 0) end)
  if type(setFgColor) == "function" then
    pcall(function() setFgColor(bar.text, 240, 240, 240) end)
  end
  Nebbie.raiseBarLayers(key)
end

Nebbie.paintGauge = Nebbie.paintBar

function Nebbie.createBar(spec, gx, gy2, gw)
  if type(createLabel) ~= "function" then return false end
  local x, y = math.floor(gx), math.floor(gy2)
  local h = Nebbie.guiGaugeH
  local backK = spec.key .. "_back"
  local frontK = spec.key .. "_front"
  local textK = spec.key .. "_text"
  local ok = pcall(function()
    createLabel(backK, x, y, gw, h, 0)
    createLabel(frontK, x, y, 1, h, 0)
    createLabel(textK, x, y, gw, h, 0)
  end)
  if not ok then return false end
  Nebbie._bars[spec.key] = { x = x, y = y, w = gw, h = h, back = backK, front = frontK, text = textK }
  Nebbie.paintBar(spec.key, spec.color, {42, 42, 56})
  Nebbie.showBar(spec.key)
  return true
end

function Nebbie.moveBar(key, gx, gy2, gw)
  local bar = Nebbie._bars[key]
  if not bar or type(moveWindow) ~= "function" or type(resizeWindow) ~= "function" then
    return false
  end
  local x, y = math.floor(gx), math.floor(gy2)
  local h = Nebbie.guiGaugeH
  bar.x, bar.y, bar.w, bar.h = x, y, gw, h
  pcall(function() moveWindow(bar.back, x, y) end)
  pcall(function() resizeWindow(bar.back, gw, h) end)
  pcall(function() moveWindow(bar.text, x, y) end)
  pcall(function() resizeWindow(bar.text, gw, h) end)
  return true
end

function Nebbie.ensureBars(x, y, w)
  local gx, gy = x + 12, y + Nebbie.guiHeaderH + 6
  local gw = w - 24
  Nebbie._barSpecs = {
    NebbieHP = { key = "NebbieHP", label = "HP", color = {45, 200, 70} },
    NebbieMN = { key = "NebbieMN", label = "MN", color = {70, 150, 255} },
    NebbieMV = { key = "NebbieMV", label = "MV", color = {230, 190, 50} },
  }
  local specs = {
    Nebbie._barSpecs.NebbieHP,
    Nebbie._barSpecs.NebbieMN,
    Nebbie._barSpecs.NebbieMV,
  }
  for i, spec in ipairs(specs) do
    local gy2 = gy + (i - 1) * (Nebbie.guiGaugeH + Nebbie.guiGaugeGap)
    if Nebbie._bars[spec.key] then
      if not Nebbie.moveBar(spec.key, gx, gy2, gw) then
        Nebbie.deleteBar(spec.key)
      end
    end
    if not Nebbie._bars[spec.key] then
      Nebbie.createBar(spec, gx, gy2, gw)
    else
      Nebbie.paintBar(spec.key, spec.color, {42, 42, 56})
    end
  end
  Nebbie.updateGauges()
end

function Nebbie.setBarText(key, text)
  local bar = Nebbie._bars[key]
  if not bar then return end
  if type(clearWindow) == "function" then
    pcall(function() clearWindow(bar.text) end)
  end
  if type(echo) == "function" then
    pcall(function() echo(bar.text, " " .. text) end)
  end
end

function Nebbie.applyBarValue(key, cur, max, label)
  local bar = Nebbie._bars[key]
  if not bar or not cur or not max or max <= 0 then return end
  local pct = math.max(0, math.min(1, cur / max))
  local fw = math.max(1, math.floor(bar.w * pct))
  local text = label .. " " .. cur .. "/" .. max
  if type(moveWindow) == "function" and type(resizeWindow) == "function" then
    pcall(function() moveWindow(bar.front, bar.x, bar.y) end)
    pcall(function() resizeWindow(bar.front, fw, bar.h) end)
  end
  Nebbie.setBarText(key, text)
  local spec = Nebbie._barSpecs and Nebbie._barSpecs[key]
  if spec then Nebbie.paintBar(key, spec.color, {42, 42, 56}) end
  Nebbie.showBar(key)
  Nebbie.raiseBarLayers(key)
end

function Nebbie.setGauge(key, cur, max, text)
  local label = key:gsub("^Nebbie", "")
  if text and text ~= "" then
    local fromText = text:match("^(%S+)")
    if fromText then label = fromText end
  end
  Nebbie.applyBarValue(key, cur, max, label)
end

function Nebbie.updateGauges()
  local s = Nebbie.stats
  if s and s.hp and s.hpmax and s.hpmax > 0 then
    Nebbie.applyBarValue("NebbieHP", s.hp, s.hpmax, "HP")
    Nebbie.applyBarValue("NebbieMN", s.mana, s.manamax, "MN")
    Nebbie.applyBarValue("NebbieMV", s.move, s.movemax, "MV")
    return
  end
  Nebbie.applyBarValue("NebbieHP", 0, 1, "HP")
  Nebbie.applyBarValue("NebbieMN", 0, 1, "MN")
  Nebbie.applyBarValue("NebbieMV", 0, 1, "MV")
end

function Nebbie.applyGUIPosition(x, y, w, h)
  local bar, con = Nebbie.guiBar, Nebbie.guiConsole
  local hh = Nebbie.guiHeaderH
  if type(moveWindow) == "function" and type(resizeWindow) == "function" then
    moveWindow(bar, x, y)
    resizeWindow(bar, w, hh)
    local conY = y + hh + Nebbie.guiGaugeArea
    moveWindow(con, x, conY)
    resizeWindow(con, w, h - hh - Nebbie.guiGaugeArea)
    if type(raiseWindow) == "function" then raiseWindow(bar) end
  end
  Nebbie.ensureBars(x, y, w)
  for key, _ in pairs(Nebbie._bars or {}) do Nebbie.raiseBarLayers(key) end
  Nebbie._guiX, Nebbie._guiY = x, y
end

function Nebbie.moveGUITo(x, y, persist)
  local u = Nebbie.computeUILayout()
  if u.hud then
    Nebbie.applyGUIPosition(u.hud.x, u.hud.y, u.hud.w, u.hud.h)
  end
  if persist then
    Nebbie._settings.guiCustom = false
    Nebbie._settings.guiX = nil
    Nebbie._settings.guiY = nil
    Nebbie.saveSettings()
  end
end

function Nebbie.positionGUI(verbose)
  if not Nebbie.guiExists() then
    if verbose then cecho("<orange>Nebbie: HUD assente — <yellow>nfix<orange>.\n") end
    return false
  end
  Nebbie.buffConsole = true
  Nebbie.applyUILayout()
  if verbose then
    local u = Nebbie.computeUILayout()
  cecho("<green>Nebbie: layout applicato — bordi L=" .. tostring(u.borderLeft)
    .. " R=" .. tostring(u.borderRight) .. " (testo MUD al centro).\n")
  end
  return true
end

function Nebbie.resetGUIPosition()
  Nebbie._settings.guiCustom = false
  Nebbie._settings.guiX = nil
  Nebbie._settings.guiY = nil
  Nebbie.saveSettings()
  return Nebbie.positionGUI(true)
end

function Nebbie.barClick(event)
  Nebbie._drag = Nebbie._drag or {}
  Nebbie._drag.active = false
end

function Nebbie.barMove(event)
end

function Nebbie.barRelease()
  if Nebbie._drag then Nebbie._drag.active = false end
end

function Nebbie.setupDragBar()
  if Nebbie._dragReady then return end
  if type(setLabelClickCallback) == "function" then setLabelClickCallback(Nebbie.guiBar, "Nebbie.barClick") end
  if type(setLabelMoveCallback) == "function" then setLabelMoveCallback(Nebbie.guiBar, "Nebbie.barMove") end
  if type(setLabelReleaseCallback) == "function" then setLabelReleaseCallback(Nebbie.guiBar, "Nebbie.barRelease") end
  Nebbie._dragReady = true
end

function Nebbie.buildGUI()
  local x, y, w, h = Nebbie.calcGUIPos()
  local hh = Nebbie.guiHeaderH
  createLabel(Nebbie.guiBar, x, y, w, hh, 1)
  setBackgroundColor(Nebbie.guiBar, 45, 45, 60, 255)
  setFgColor(Nebbie.guiBar, 200, 200, 220)
  echo(Nebbie.guiBar, " Nebbie HUD — colonna laterale")
  local conY = y + hh + Nebbie.guiGaugeArea
  createMiniConsole(Nebbie.guiConsole, x, conY, w, h - hh - Nebbie.guiGaugeArea, true)
  setMiniConsoleFontSize(Nebbie.guiConsole, Nebbie.guiFontSize or 11)
  setBackgroundColor(Nebbie.guiConsole, 20, 20, 30, 200)
  setFgColor(Nebbie.guiConsole, 200, 200, 200)
  showWindow(Nebbie.guiBar)
  showWindow(Nebbie.guiConsole)
  Nebbie._guiBuilt = true
  Nebbie._guiHidden = false
  Nebbie.buffConsole = true
  Nebbie.setupDragBar()
  Nebbie.applyGUIPosition(x, y, w, h)
end

function Nebbie.destroyGUI()
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.deleteBar(key)
  end
  Nebbie._bars = {}
  Nebbie.deleteLegacyGauges()
  if type(deleteMiniConsole) == "function" then pcall(function() deleteMiniConsole(Nebbie.guiConsole) end) end
  if type(deleteLabel) == "function" then pcall(function() deleteLabel(Nebbie.guiBar) end) end
  Nebbie._guiBuilt = false
  Nebbie._guiHidden = nil
  Nebbie.buffConsole = false
  Nebbie._dragReady = false
end

function Nebbie.stopGUI()
  if Nebbie.guiTimer then killTimer(Nebbie.guiTimer); Nebbie.guiTimer = nil end
  if Nebbie.attribTimer then killTimer(Nebbie.attribTimer); Nebbie.attribTimer = nil end
  if Nebbie.eqCacheTimer then killTimer(Nebbie.eqCacheTimer); Nebbie.eqCacheTimer = nil end
end

function Nebbie.initGUI()
  Nebbie.stopGUI()
  Nebbie.loadSettings()
  local layout = Nebbie._settings.guiLayout or 0
  if layout < Nebbie.guiLayoutVer then
    Nebbie.destroyGUI()
    Nebbie._settings.guiLayout = Nebbie.guiLayoutVer
    Nebbie._settings.guiCustom = false
    Nebbie._settings.guiX = nil
    Nebbie._settings.guiY = nil
    Nebbie.saveSettings()
  elseif Nebbie.guiExists() and not Nebbie.buffConsole then
    Nebbie.destroyGUI()
  end
  if not Nebbie.guiExists() then Nebbie.buildGUI()
  else
    Nebbie.buffConsole = true
    Nebbie.setupDragBar()
    Nebbie.positionGUI(false)
  end
  if not Nebbie.resizeHandler and type(registerAnonymousEventHandler) == "function" then
    Nebbie.resizeHandler = registerAnonymousEventHandler("sysWindowResizeEvent", function()
      if Nebbie.applyUILayout then Nebbie.applyUILayout() end
    end)
  end
  tempTimer(0.05, function() Nebbie.applyUILayout() end)
  tempTimer(0.3, function()
    if Nebbie.applyUILayout then Nebbie.applyUILayout() end
    if Nebbie.pollPromptFromBuffer then Nebbie.pollPromptFromBuffer() end
    if Nebbie.updateGauges then Nebbie.updateGauges() end
  end)
  Nebbie.guiTimer = tempTimer(1, function() Nebbie.refreshGUI() end, true)
  Nebbie.syncAttribTimer()
end

function Nebbie.toggleGUI()
  if not Nebbie.guiExists() then
    Nebbie.initGUI()
    return
  end
  if Nebbie.guiHidden() then Nebbie.showGUI() else Nebbie.hideGUI() end
end

function Nebbie.populatePanels()
  Nebbie.pollPromptFromBuffer()
  Nebbie.updateGauges()
  if Nebbie.refreshGUI then Nebbie.refreshGUI() end
  if Nebbie.refreshDashboard then Nebbie.refreshDashboard() end
  if Nebbie.stats and Nebbie.stats.name then
    if Nebbie.requestAttrib then tempTimer(0.3, function() Nebbie.requestAttrib(true) end) end
    if Nebbie.requestEqPanel then tempTimer(0.6, function() Nebbie.requestEqPanel() end) end
  end
end

function Nebbie.parsePromptCodes(raw)
  local out = {}
  if not raw or raw == "" then return out end
  local i = 1
  for _, slot in ipairs(Nebbie.PROMPT_SLOTS) do
    local ch = raw:sub(i, i)
    if ch and ch ~= "-" and ch ~= " " then
      table.insert(out, slot.name)
    end
    i = i + 1
  end
  return out
end

function Nebbie.parseAttribSpellLine(line)
  local plain = Nebbie.stripColors(line)
  local spell, dur = plain:match("Spell%s*:%s*'(.-)'%s*%-%s*(%d+)")
  if not spell or not dur then return end
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  local n = tonumber(dur) or 0
  if Nebbie._attribSeenSpells then Nebbie._attribSeenSpells[spell] = true end
  if n <= 0 then
    Nebbie.buffs[spell] = nil
    return
  end
  local prev = Nebbie.buffs[spell]
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = n * Nebbie.TICK_SECONDS,
    ticks = n,
    soon = prev and prev.soon or false,
    active = true,
    source = "attribute",
    synced = true,
  }
end

function Nebbie.onAttribLine(line)
  local plain = Nebbie.stripColors(line)
  if plain:find("Spells attivi", 1, true) then
    Nebbie.beginAttribScan()
    if Nebbie.attribGag and type(deleteLine) == "function" then deleteLine() end
    return
  end
  if plain:find("Spell%s*:%s*'") then
    if not Nebbie._attribScanActive then Nebbie.beginAttribScan() end
    Nebbie.parseAttribSpellLine(line)
    if Nebbie.attribGag and type(deleteLine) == "function" then deleteLine() end
    return
  end
  if not Nebbie.attribGag then return end
  if plain:match("^Tu hai") or plain:match("^Stai trasportando") or plain:match("^Tu sei")
      or plain:match("^Armor class") or plain:match("^Spellfail") or plain:match("^La tua capacita")
      or plain:match("^I tuoi hit") or plain:match("^Il tuo equipaggiamento") or plain:match("^Hit:")
      or plain:match("^anni e") then
    if type(deleteLine) == "function" then deleteLine() end
  end
end

function Nebbie.requestAttrib(silent)
  if Nebbie._attribBusy then return end
  Nebbie._attribBusy = true
  Nebbie.attribGag = true
  Nebbie.beginAttribScan()
  send("attribute")
  tempTimer(2, function()
    Nebbie.endAttribScan()
    Nebbie.attribGag = false
    Nebbie._attribBusy = false
    Nebbie.refreshGUI()
    if not silent then cecho("<green>Nebbie: attribute sincronizzato.\n") end
  end)
end

function Nebbie.setAttribAuto(on)
  Nebbie.attribAuto = on
  Nebbie._settings.attribAuto = on
  Nebbie.saveSettings()
  Nebbie.syncAttribTimer()
  if on then cecho("<green>Nebbie: sync attribute ogni 90s attivo (gagged).\n")
  else cecho("<green>Nebbie: sync attribute automatico disattivato.\n") end
end

function Nebbie.syncAttribTimer()
  if Nebbie.attribTimer then killTimer(Nebbie.attribTimer); Nebbie.attribTimer = nil end
  if Nebbie.attribAuto then
    Nebbie.attribTimer = tempTimer(90, function()
      if Nebbie.attribAuto then Nebbie.requestAttrib(true) end
    end, true)
  end
end

function Nebbie.setupHUD()
  if Nebbie._setupRunning then return end
  Nebbie._setupRunning = true
  cecho("<green>Nebbie HUD v" .. Nebbie.version .. ": parser prompt attivo.\n")
  cecho("<grey>Comandi MUD liberi: <yellow>inv<grey>, <yellow>eq<grey>. Loot mob: <yellow>nloot<grey> | auto <yellow>nloot on<grey>\n")
  if not Nebbie.playerClass or Nebbie.playerClass == "" then Nebbie.setClass("+", true) end
  Nebbie.initGUI()
  Nebbie.pollPromptFromBuffer()
  Nebbie.updateGauges()
  Nebbie.populatePanels()
  Nebbie._setupRunning = false
end

function Nebbie.refreshGUI()
  if not Nebbie.guiExists() then return end
  if not Nebbie.stats then Nebbie.pollPromptFromBuffer() end
  Nebbie.pruneStaleDebuffs()
  Nebbie.pruneInvalidBuffs()
  Nebbie.pruneExpiredBuffs()
  local ok, err = pcall(function()
    clearWindow(Nebbie.guiConsole)
    local hud = Nebbie.guiConsole
    local s = Nebbie.stats or {}
    cecho(hud, "<cyan><b>=== Nebbie HUD v" .. Nebbie.version .. " ===</b>\n")
    if s.name then
      cecho(hud, "<white>" .. s.name .. "  <grey>XP:<yellow>" .. tostring(s.xp or "?")
        .. " <grey>Oro:<yellow>" .. tostring(s.gold or "?") .. "\n")
    else
      cecho(hud, "<orange>Nome non rilevato — digita un comando, poi <yellow>nprompt\n")
    end
    if s.hp then
      cecho(hud, "<grey>HP <white>" .. s.hp .. "/" .. s.hpmax
        .. "  <grey>MN <white>" .. s.mana .. "/" .. s.manamax
        .. "  <grey>MV <white>" .. s.move .. "/" .. s.movemax .. "\n")
    else
      cecho(hud, "<orange>Prompt non letto — <yellow>nprompt<orange> per diagnostica\n")
    end
    if s.mobName and s.mobName ~= "*" then
      cecho(hud, "<orange>Fight: <white>" .. (s.tankCond or "?") .. "/" .. (s.tankName or "?")
        .. " <grey>— <red>" .. (s.mobCond or "?") .. "/" .. s.mobName .. "\n")
    end
    if Nebbie.promptBuffs and #Nebbie.promptBuffs > 0 then
      cecho(hud, "<grey>Prompt: <green>" .. table.concat(Nebbie.promptBuffs, ", ") .. "\n")
    end
    local now = Nebbie.now()
    local scount = 0
    cecho(hud, "<cyan>Spell attivi:\n")
    for spell, data in pairs(Nebbie.buffs) do
      if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
        scount = scount + 1
        local status = Nebbie.isDebuffSpell(spell) and "<red>!!" or "<green>OK"
        local timeTxt = Nebbie.formatTime(now - (data.since or now))
        if data.soon then status = "<orange>!" end
        if data.duration and data.duration > 0 then
          local left = Nebbie.buffTimeLeft(data, now)
          timeTxt = Nebbie.formatTime(left or 0)
          if data.synced and left and left <= 0 then
            status = "<grey>--"
          elseif not data.synced and left and left <= 0 then
            timeTxt = timeTxt .. " ~"
          end
        elseif data.synced then
          timeTxt = "--:--"
        else
          timeTxt = "~attrib"
        end
        local src = ""
        if data.synced and data.ticks then
          src = " <dark_grey>[" .. tostring(data.ticks) .. "h]"
        elseif data.synced then src = " <dark_grey>[attrib]"
        elseif data.source == "cast" then src = " <dark_grey>[cast]" end
        cecho(hud, " " .. status .. " <white>" .. spell .. "  <grey>" .. timeTxt .. src .. "\n")
      end
    end
    if scount == 0 then cecho(hud, " <grey>(nessuno — <yellow>nattrib<grey> sincronizza)\n") end
    local dcount = 0
    cecho(hud, "<red>Debuff (no attrib):\n")
    for name, data in pairs(Nebbie.debuffs) do
      if type(name) == "string" and type(data) == "table" then
        dcount = dcount + 1
        local elapsed = now - (data.since or now)
        cecho(hud, " <red>!! <white>" .. name .. "  <grey>" .. Nebbie.formatTime(elapsed) .. "\n")
      end
    end
    if dcount == 0 then cecho(hud, " <grey>(nessuno)\n") end
    local preset = Nebbie.getActivePreset()
    if preset and preset.quick then
      cecho(hud, "<grey>Quick: ")
      for i, q in ipairs(preset.quick) do
        cecho(hud, "<dark_green>q" .. i .. "<grey>=" .. tostring(q.abbr) .. " ")
      end
      cecho(hud, "\n")
    end
  end)
  if not ok then cecho("<red>[Nebbie GUI] " .. tostring(err) .. "\n") end
  Nebbie.updateGauges()
end

function Nebbie.getAllSpellNames()
  if Nebbie._spellNamesByLen then return Nebbie._spellNamesByLen end
  local names = {}
  for spell, _ in pairs(Nebbie.castSpells) do names[#names + 1] = spell end
  for spell, _ in pairs(Nebbie.mindSpells) do names[#names + 1] = spell end
  table.sort(names, function(a, b) return #a > #b end)
  Nebbie._spellNamesByLen = names
  return names
end

function Nebbie.parseSpellAndTarget(rest)
  if not rest or rest == "" then return nil, nil end
  rest = rest:match("^%s*(.-)%s*$")
  local qspell, qtail = rest:match("^['\"]([^'\"]+)['\"]%s*(.*)$")
  if qspell then
    local target = (qtail and qtail ~= "") and Nebbie.stripQuotes(qtail:match("^%s+(.+)$") or qtail) or nil
    return Nebbie.resolveSpell(qspell), target
  end
  local lower = rest:lower()
  for _, spell in ipairs(Nebbie.getAllSpellNames()) do
    local sl = spell:lower()
    if lower == sl or lower:gsub(" ", "") == sl:gsub(" ", "") then
      return spell, nil
    end
    if #lower >= #sl and lower:sub(1, #sl) == sl then
      local nextc = rest:sub(#sl + 1, #sl + 1)
      if nextc == "" or nextc:match("%s") then
        local target = rest:sub(#sl + 1):match("^%s+(.+)$")
        if target then target = Nebbie.stripQuotes(target) end
        return spell, target
      end
    end
  end
  local spell, target = rest:match("^(%S+)%s+(.+)$")
  if spell then
    return Nebbie.resolveSpell(spell), Nebbie.stripQuotes(target)
  end
  return Nebbie.resolveSpell(rest), nil
end

function Nebbie.resolveSpell(token)
  local lower = Nebbie.stripQuotes(token):lower()
  for spell, abbr in pairs(Nebbie.abbrevs) do
    if abbr == lower then return spell end
  end
  for spell, _ in pairs(Nebbie.castSpells) do
    if spell:lower() == lower or spell:lower():gsub(" ", "") == lower:gsub(" ", "") then return spell end
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
  if mode == "mind" then cmd = "mind '" .. spell .. "'"
  elseif mode == "recall" then cmd = "recall '" .. spell .. "'"
  else cmd = "cast '" .. spell .. "'" end
  if target and target ~= "" then cmd = cmd .. " " .. target end
  send(cmd)
end

function Nebbie.listInstalledAliases()
  cecho("<cyan><b>Alias Nebbie</b> <grey>(" .. #(Nebbie._aliasNames or {}) .. " registrati; indice: nebbie-alias-index.txt):\n")
  local n = 0
  for full, _ in pairs(Nebbie._aliasIds or {}) do
    n = n + 1
    cecho("<grey>  " .. tostring(full) .. "\n")
  end
  if n == 0 then
    for _, name in ipairs(Nebbie._aliasNames or {}) do
      cecho("<grey>  " .. name .. "\n")
    end
  end
  if n == 0 and #(Nebbie._aliasNames or {}) == 0 then
    cecho("<orange>Nessun alias — <yellow>nfix<orange>\n")
  end
end

function Nebbie.listInstalledTriggers()
  cecho("<cyan><b>Trigger Nebbie</b> <grey>(" .. #(Nebbie._triggerNames or {}) .. " registrati; indice: nebbie-trigger-index.txt):\n")
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    cecho("<grey>  " .. name .. "\n")
  end
end

function Nebbie.listPackageHelp()
  cecho("<cyan><b>Nebbie v" .. Nebbie.version .. " — indici</b>\n")
  cecho("<grey>Repository branch <yellow>mudlet<grey> (docs/mudlet/):\n")
  cecho("  <yellow>nebbie-alias-index.txt<grey>    — tutti gli alias\n")
  cecho("  <yellow>nebbie-trigger-index.txt<grey>  — tutti i trigger\n")
  cecho("  <yellow>nebbie-spells-reference.txt<grey> — spell e abbreviazioni\n")
  cecho("  <yellow>HELP.md<grey>                    — guida installazione\n")
  cecho("  <yellow>PACKAGE-GUIDE.md<grey>            — guida completa logica + alias/trigger\n")
  cecho("<grey>In gioco: <yellow>nlist aliases<grey> | <yellow>nlist triggers<grey> | <yellow>nlist spells\n")
  cecho("<grey>Incantesimi multi-parola: <yellow>c power word kill bersaglio<grey> o <yellow>c 'power word kill' bersaglio\n")
end

function Nebbie.uninstall()
  for full, _ in pairs(Nebbie._aliasIds or {}) do Nebbie.killTempAlias(full) end
  for full, _ in pairs(Nebbie._triggerIds or {}) do Nebbie.killTempTriggers(full) end
  for full, _ in pairs(Nebbie._keyIds or {}) do Nebbie.killTempKey(full) end
  Nebbie.killKeypadBindings()
  Nebbie.purgePackageAliases()
  Nebbie.purgePackageTriggers()
  Nebbie.stopGUI()
  Nebbie.destroyGUI()
  Nebbie._aliasNames = {}
  Nebbie._triggerNames = {}
  Nebbie._aliasIds = {}
  Nebbie._triggerIds = {}
  Nebbie._keyIds = {}
  Nebbie._keyNames = {}
  cecho("<orange>Nebbie play-all: alias/trigger disattivati.\n")
end

function Nebbie.runFix()
  if Nebbie._fixRunning then return end
  Nebbie._fixRunning = true
  Nebbie.purgeOrphanMainScripts(true)
  Nebbie.killAllTrackedTemps()
  Nebbie.purgeLegacyPermItems(true)
  Nebbie.disablePackagePermItems()
  Nebbie.killAllByNameVariants("reinstall fix", "alias")
  Nebbie.stopGUI()
  Nebbie.destroyGUI()
  Nebbie._installedVer = nil
  Nebbie.install()
  Nebbie.loadClass()
  if not Nebbie.playerClass then Nebbie.setClass("+", true) end
  cecho("<green>Nebbie v" .. Nebbie.version .. " reinstallato.\n")
  cecho("<grey>Alias vecchi perm disattivati. Se restano in Scripts, riavvia Mudlet una volta.\n")
  if type(tempTimer) == "function" then
    tempTimer(3, function() Nebbie._fixRunning = false end)
  else
    Nebbie._fixRunning = false
  end
end

function Nebbie.install()
  if Nebbie._installing then return end
  Nebbie._installing = true
  Nebbie.stopGUI()
  Nebbie.killAllTrackedTemps()
  Nebbie.killLegacyKeypadTemps()
  Nebbie.disablePackagePermItems()
  Nebbie.purgeTrackedAliases()
  Nebbie.purgeTrackedTriggers()
  Nebbie.purgePackageAliases()
  Nebbie.purgePackageTriggers()
  Nebbie.purgeOrphanNebbieAliases()
  Nebbie.purgeOrphanNebbieTriggers()
  Nebbie._aliasNames = {}
  Nebbie._triggerNames = {}
  Nebbie._aliasIds = {}
  Nebbie._triggerIds = {}
  Nebbie._keyIds = {}
  Nebbie._keyNames = {}

  local function perm(short, pattern, script)
    if type(tempAlias) ~= "function" then return end
    local full = PKG .. "::" .. short
    Nebbie.killTempAlias(full)
    Nebbie.killAllByNameVariants(short, "alias")
    local id = tempAlias(pattern, script)
    if id then
      Nebbie._aliasIds[full] = id
      table.insert(Nebbie._aliasNames, full)
    else
      cecho("<red>[Nebbie] alias non creato: " .. full .. "\n")
    end
  end

  local function trig(short, patterns, script, isRegex)
    local full = PKG .. "::" .. short
    Nebbie.killTempTriggers(full)
    Nebbie.killAllByNameVariants(short, "trigger")
    local ids = {}
    if isRegex then
      if type(tempRegexTrigger) ~= "function" then return end
      local pats = type(patterns) == "table" and patterns or {patterns}
      for _, p in ipairs(pats) do
        local id = tempRegexTrigger(p, script)
        if id then table.insert(ids, id) end
      end
    elseif type(patterns) == "table" then
      if type(tempTrigger) ~= "function" then return end
      for _, p in ipairs(patterns) do
        local id = tempTrigger(p, script)
        if id then table.insert(ids, id) end
      end
    else
      if type(tempTrigger) ~= "function" then return end
      local id = tempTrigger(patterns, script)
      if id then table.insert(ids, id) end
    end
    if #ids > 0 then
      Nebbie._triggerIds[full] = ids
      table.insert(Nebbie._triggerNames, full)
    end
  end

  perm("mode cast", [[^ncast$]], [[Nebbie.setCastMode("cast")]])
  perm("mode recall", [[^nrecall$]], [[Nebbie.setCastMode("recall")]])
  perm("mode mind", [[^nmind$]], [[Nebbie.setCastMode("mind")]])
  perm("toggle gui", [[^ngui$]], [[Nebbie.toggleGUI()]])
  perm("toggle hud", [[^nhud$]], [[Nebbie.toggleGUI()]])
  perm("reposition gui", [[^npos$]], [[Nebbie.resetGUIPosition()]])
  perm("setup hud", [[^nsetup$]], [[Nebbie.setupHUD()]])
  perm("prompt debug", [[^nprompt$]], [[Nebbie.debugPrompt()]])
  perm("install diagnose", [[^ndiagnose$]], [[Nebbie.diagnoseInstall()]])
  perm("keypad refresh", [[^nkeys$]], [[
    Nebbie.killKeypadBindings()
    local n = Nebbie.installKeypadBindings(true)
    cecho("<green>Nebbie: " .. n .. " binding tastierino reinstallati.\n")
    cecho("<grey>Num Lock ON: cifre 5/8/2/4/6/9/3 — OFF: frecce + PgSu/PgGiu/Canc\n")
  ]])
  perm("attrib sync", [[^nattrib$]], [[Nebbie.requestAttrib(false)]])
  perm("attrib on", [[^nattrib on$]], [[Nebbie.setAttribAuto(true)]])
  perm("attrib off", [[^nattrib off$]], [[Nebbie.setAttribAuto(false)]])
  perm("loot manual", [[^nloot$]], [[Nebbie.lootMobRemains(true)]])
  perm("loot on", [[^nloot on$]], [[Nebbie.setLootAuto(true)]])
  perm("loot off", [[^nloot off$]], [[Nebbie.setLootAuto(false)]])
  perm("swap weapon", [[^usa (.+)$]], [[Nebbie.swapWeapon(matches[2], true)]])
  perm("eq key list", [[^nkey$]], [[Nebbie.listEqKeys()]])
  perm("eq key add", [[^nkey add (.+) (.+)$]], [[Nebbie.addEqKey(matches[2], matches[3])]])
  perm("eq key del", [[^nkey del (.+)$]], [[Nebbie.delEqKey(matches[2])]])
  perm("eq cache clear", [[^neq clear$]], [[Nebbie.clearEqCacheWield()]])
  perm("drop recover on", [[^ndrop on$]], [[Nebbie.setWeaponDropRecover(true)]])
  perm("drop recover off", [[^ndrop off$]], [[Nebbie.setWeaponDropRecover(false)]])
  perm("food auto on", [[^nfood on$]], [[Nebbie.setFoodDrinkAuto(true)]])
  perm("food auto off", [[^nfood off$]], [[Nebbie.setFoodDrinkAuto(false)]])
  perm("food item set", [[^nfood item (.+)$]], [[Nebbie.setFoodItemKey(matches[2])]])
  perm("food manual", [[^nfood$]], [[Nebbie.autoFoodDrink()]])
  perm("eq cache sync", [[^neq$]], [[
    if Nebbie.requestEqCache(false) then
      cecho("<grey>Nebbie: sync eq...\n")
      tempTimer(3.2, function()
        Nebbie.scanEqBufferSnapshot()
        Nebbie.showEqCache()
      end)
    else
      Nebbie.showEqCache()
    end
  ]])
  perm("eq cache on", [[^neq on$]], [[Nebbie.setEqAuto(true)]])
  perm("eq cache off", [[^neq off$]], [[Nebbie.setEqAuto(false)]])
  -- nfix: unico alias XML nel package (nebbie-fix), non crearlo qui

  perm("generic cast c", [[^c (.+)$]], [[
    local spell, target = Nebbie.parseSpellAndTarget(matches[2])
    if spell then Nebbie.sendCast(spell, target) end
  ]])
  perm("generic cast word", [[^cast (.+)$]], [[
    local spell, target = Nebbie.parseSpellAndTarget(matches[2])
    if spell then Nebbie.sendCast(spell, target) end
  ]])

  perm("memorize", [[^mem (.+)$]], [[
    local spell = Nebbie.parseSpellAndTarget(matches[2])
    if spell then send("memorize '" .. spell .. "'") end
  ]])
  perm("recall shortcut", [[^r (.+)$]], [[
    local spell, target = Nebbie.parseSpellAndTarget(matches[2])
    if not spell then return end
    local cmd = "recall '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])
  perm("mind shortcut", [[^m (.+)$]], [[
    local spell, target = Nebbie.parseSpellAndTarget(matches[2])
    if not spell then return end
    local cmd = "mind '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])

  for spell, abbr in pairs(Nebbie.abbrevs) do
    if (Nebbie.castSpells[spell] or Nebbie.mindSpells[spell]) and Nebbie.safeStandalone[abbr] then
      local s = spell:gsub("'", "\\'")
      local a = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
      perm("abbr cast " .. abbr, "^" .. a .. "(?: (.+))?$", string.format([[
        local target = matches[2]
        Nebbie.sendCast('%s', target)
      ]], s))
    end
  end

  for _, spell in ipairs(Nebbie.favoriteSpells or {}) do
    if Nebbie.castSpells[spell] or Nebbie.mindSpells[spell] then
      local s = spell:gsub("'", "\\'")
      local abbr = Nebbie.abbrevs[spell]
      if not abbr or abbr ~= spell then
        local p = spell:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
        perm("fav cast " .. spell, "^" .. p .. "(?: (.+))?$", string.format([[
          local target = matches[2]
          Nebbie.sendCast('%s', target)
        ]], s))
      end
    end
  end

  for skillName, info in pairs(Nebbie.dedicatedSkills) do
    local abbr = Nebbie.abbrevs[skillName] or Nebbie.abbrevs[info.cmd] or info.cmd:gsub(" ", "")
    if Nebbie.safeStandalone[abbr] then
      abbr = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
      local cmd = info.cmd
      perm("skill " .. info.cmd, "^" .. abbr .. "(?: (.+))?$", string.format([[
        local args = matches[2]
        if args and args ~= "" then send("%s " .. args) else send("%s") end
      ]], cmd, cmd))
    end
  end

  perm("list classes", [[^nclass$]], [[Nebbie.listClasses()]])
  perm("set class", [[^nclass (.+)$]], [[Nebbie.setClass(matches[2])]])
  perm("set char profile", [[^nchar (.+)$]], [[Nebbie.switchCharProfile(matches[2], false)]])

  perm("list package help", [[^nlist$]], [[Nebbie.listPackageHelp()]])
  perm("list aliases", [[^nlist aliases$]], [[Nebbie.listInstalledAliases()]])
  perm("list triggers", [[^nlist triggers$]], [[Nebbie.listInstalledTriggers()]])
  perm("list spells ref", [[^nlist spells$]], [[
    cecho("<cyan><b>Incantesimi multi-parola</b> — esempi:\n")
    cecho("<grey>  c power word kill goblin\n")
    cecho("<grey>  c 'power word kill' goblin\n")
    cecho("<grey>  c magic missile goblin\n")
    cecho("<grey>  c colour spray\n")
    cecho("<grey>Elenco: <yellow>nebbie-spells-reference.txt<grey> (branch mudlet).\n")
  ]])

  for slot = 1, 9 do
    perm("quick slot " .. slot, "^q" .. slot .. "(?: (.+))?$", string.format([[
      local preset = Nebbie.getActivePreset()
      if not preset or not preset.quick[%d] then
        cecho("<red>Slot q%d non configurato.\n")
        return
      end
      Nebbie.execQuick(preset.quick[%d], matches[2])
    ]], slot, slot, slot))
  end

  perm("return form", [[^return$]], [[send("return")]])

  perm("path list", [[^npath$]], [[Nebbie.listPaths()]])
  perm("path add", [[^npath add (.+) (.+)$]], [[Nebbie.addPath(matches[2], matches[3])]])
  perm("path del", [[^npath del (.+)$]], [[Nebbie.delPath(matches[2])]])
  perm("path run", [[^npath run (.+)$]], [[Nebbie.runPath(matches[2])]])
  perm("weapon set", [[^nweapon ([%w]+) (.+)$]], [[Nebbie.setWeaponKey(matches[2], matches[3])]])
  perm("utility set", [[^nutility ([%w]+) (.+)$]], [[Nebbie.setUtilityKey(matches[2], matches[3])]])
  perm("dashboard toggle", [[^ndashboard$]], [[Nebbie.toggleDashboard()]])
  perm("layout refresh", [[^nlayout$]], [[Nebbie.applyUILayout(); cecho("<green>Nebbie: layout finestre aggiornato.\n")]])
  perm("eq panel sync", [[^neq panel$]], [[Nebbie.requestEqPanel()]])

  trig("prompt parse", {[[H:\d+/\d+.*M:\d+/\d+.*V:\d+/\d+.*X:\d+]]}, [[if Nebbie and Nebbie.onPromptLine then Nebbie.onPromptLine() end]], true)
  trig("char menu start", {"Scegli un personagggio", "Scegli un personaggio"}, [[if Nebbie and Nebbie.onCharMenuStart then Nebbie.onCharMenuStart() end]])
  trig("char menu line", {[[^\s*\d+\.\s+\S+]]}, [[if Nebbie and Nebbie.onCharMenuLine then Nebbie.onCharMenuLine(line) end]], true)
  trig("attrib gag", {"Tu hai", "Spells attivi", "Spell :"}, [[if Nebbie and Nebbie.onAttribLine then Nebbie.onAttribLine(line) end]])

  trig("eq parse wield", {"Stai usando", "<impugnato>", "<tenuto>", "<sulla schiena>", "<sul corpo>", "<in testa>", "<sulle mani>"}, [[
    if Nebbie and Nebbie.onEqParseLine then Nebbie.onEqParseLine() end
  ]])

  trig("look loot parse", {"il corpo di", "corpo sfigurato", "pile of dust", "Pile of dust"}, [[
    if Nebbie and Nebbie._lookLootActive and Nebbie.onLookLootLine then Nebbie.onLookLootLine(line) end
  ]])

  trig("mob kill exp loot", {[[^La tua esperienza e' aumentata di \d+ punti\.?$]]}, [[
    if Nebbie and Nebbie.onMobKillExp then Nebbie.onMobKillExp(line) end
  ]], true)

  trig("weapon drop hold", {" ti cade dalle mani"}, [[
    if Nebbie and Nebbie.onWeaponDropHoldLine then Nebbie.onWeaponDropHoldLine(line) end
  ]])

  trig("weapon drop wield", {"e ti casca anche"}, [[
    if Nebbie and Nebbie.onWeaponDropWieldLine then Nebbie.onWeaponDropWieldLine(line) end
  ]])

  trig("hunger thirst", {"Hai Fame.", "Hai fame.", "Hai sete.", "Hai Sete."}, [[
    if Nebbie and Nebbie.autoFoodDrink then Nebbie.autoFoodDrink() end
  ]])

  trig("cast started", {"Pronunci le parole"}, [[
    if Nebbie and Nebbie.stripColors and Nebbie.onBuffApplied then
      local plain = Nebbie.stripColors(line)
      local spell = plain:match("Pronunci le parole, '(.-)'")
      if spell then Nebbie.onBuffApplied(spell) end
    end
  ]])

  for _, entry in ipairs(Nebbie.wearOff) do
    local label = entry.name:gsub("'", "\\'")
    trig("wearoff " .. entry.name, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.onBuffWearOff then Nebbie.onBuffWearOff('%s') end
    ]], label))
  end

  for _, entry in ipairs(Nebbie.wearOffSoon) do
    trig("soon " .. entry.name, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.onBuffSoon then Nebbie.onBuffSoon('%s') end
    ]], entry.name:gsub("'", "\\'")))
  end

  for _, entry in ipairs(Nebbie.selfAffectApply or {}) do
    local label = entry.name:gsub("'", "\\'")
    trig("affect on " .. entry.name .. " " .. entry.pattern, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.stripColors and Nebbie.onBuffApplied and Nebbie.isSelfAffectLine then
        local plain = Nebbie.stripColors(line)
        if plain:find("%s", 1, true) and Nebbie.isSelfAffectLine(plain) then
          Nebbie.onBuffApplied('%s')
        end
      end
    ]], entry.pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), label))
  end

  for _, entry in ipairs(Nebbie.debuffApply or {}) do
    local label = entry.name:gsub("'", "\\'")
    trig("debuff on " .. entry.name .. " " .. entry.pattern, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.stripColors and Nebbie.onDebuffApplied then
        local plain = Nebbie.stripColors(line)
        if plain:find("%s", 1, true) and Nebbie.matchDebuffApply('%s', plain) then
          Nebbie.onDebuffApplied('%s')
        end
      end
    ]], entry.pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), label, label))
  end

  for _, entry in ipairs(Nebbie.debuffWearOff or {}) do
    local label = entry.name:gsub("'", "\\'")
    trig("debuff off " .. entry.name .. " " .. entry.pattern, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.stripColors and Nebbie.onDebuffWearOff then
        local plain = Nebbie.stripColors(line)
        if plain:find("%s", 1, true) then Nebbie.onDebuffWearOff('%s') end
      end
    ]], entry.pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), label))
  end

  for _, entry in ipairs(Nebbie.failures) do
    trig("fail " .. entry.name, {entry.pattern}, "")
  end

  Nebbie.installPromptHooks()
  Nebbie.installEqSendHook()
  Nebbie.testPromptParse(true)
  Nebbie.testEqParse(true)
  local keypadN = Nebbie.installKeypadBindings(false)

  cecho("<green>Nebbie v" .. Nebbie.version .. ": " .. #Nebbie._aliasNames .. " alias, " .. #Nebbie._triggerNames .. " trigger.\n")
  if keypadN > 0 then
    cecho("<grey>Tastierino: <yellow>8<grey>=north <yellow>2<grey>=south <yellow>4<grey>=west <yellow>6<grey>=east <yellow>9<grey>=up <yellow>3<grey>=down <yellow>5<grey>=look")
    cecho("<grey> (Num Lock ON o OFF) — <yellow>nkeys<grey> se non risponde\n")
  else
    cecho("<orange>Tastierino non attivo — reinstalla package o digita <yellow>nkeys<orange>\n")
  end
  cecho("<grey>Layout: margini L/R — testo MUD al centro | <yellow>nlayout<grey> | <yellow>ngui\n")
  cecho("<grey>Pronto: <yellow>nclass +<grey>, <yellow>q1<grey>, <yellow>ngui<grey> | <yellow>nfix<grey> <yellow>nprompt<grey> | <yellow>nlist<grey>\n")
  cecho("<grey>Dashboard: <yellow>neq<grey>/<yellow>neq panel<grey> equip | <yellow>npath<grey> paths | <yellow>nweapon slash spada<grey> | <yellow>usa redentore<grey>\n")
  cecho("<grey>inv/eq liberi per MUD. Loot: corp/2.corp/… + pile/2.pile/…; <yellow>nloot off<grey> disattiva auto.\n")
  cecho("<grey>Armi cadute: <yellow>ndrop off<grey> | Fame/sete: <yellow>nfood off<grey> | Oggetto: <yellow>nfood item cornu\n")
  Nebbie._installing = false
  Nebbie.initGUI()
end

function Nebbie.boot()
  if Nebbie._bootInProgress then return end
  Nebbie._bootInProgress = true
  Nebbie.loadSettings()
  if Nebbie._settings.attribAuto then Nebbie.attribAuto = true end
  if Nebbie._settings.lootAuto == false then Nebbie.lootAuto = false end
  if Nebbie._settings.eqAuto == false then Nebbie.eqAuto = false end
  Nebbie.warnLegacyPackages()
  Nebbie.purgeOrphanMainScripts(true)
  if Nebbie._expectedPkgVer and Nebbie.version ~= Nebbie._expectedPkgVer then
    cecho("<orange>Nebbie: versione caricata <yellow>" .. tostring(Nebbie.version)
      .. "<orange> ≠ package <yellow>" .. Nebbie._expectedPkgVer .. "<orange> — reinstalla il .mpackage (non solo nfix).\n")
  elseif Nebbie.version and Nebbie._expectedPkgVer and Nebbie.version == Nebbie._expectedPkgVer then
    cecho("<green>Nebbie v" .. Nebbie.version .. " layout finestre attivo.\n")
  end
  Nebbie.pruneStaleDebuffs()
  Nebbie.pruneInvalidBuffs()
  Nebbie.pruneExpiredBuffs()
  Nebbie.purgeLegacyPermItems(true)
  if Nebbie._installedVer == Nebbie.version and Nebbie._aliasIds and next(Nebbie._aliasIds) ~= nil then
    if not Nebbie.guiExists() then Nebbie.initGUI() end
    if not Nebbie.bootCharProfile() and not Nebbie.loadClass() then Nebbie.setClass("+", true) end
    Nebbie.syncAttribTimer()
    Nebbie.syncEqCacheTimer()
    Nebbie.installEqSendHook()
    Nebbie.maybeRefreshEqCacheOnBoot()
    Nebbie._mainLoaded = true
    Nebbie._bootInProgress = false
    return
  end
  Nebbie._installedVer = Nebbie.version
  Nebbie.install()
  Nebbie.testPromptParse(false)
  if not Nebbie.bootCharProfile() and not Nebbie.loadClass() then Nebbie.setClass("+", true) end
  Nebbie.syncAttribTimer()
  Nebbie.syncEqCacheTimer()
  Nebbie.maybeRefreshEqCacheOnBoot()
  Nebbie._mainLoaded = true
  Nebbie._bootInProgress = false
end

if not (Nebbie and Nebbie._deferBoot) then
  local _nb_boot_ok, _nb_boot_err = pcall(function() Nebbie.boot() end)
  if not _nb_boot_ok then
    cecho("<red>[Nebbie] boot error: " .. tostring(_nb_boot_err) .. "\n")
  elseif Nebbie and Nebbie.version then
    cecho("<green>[Nebbie] v" .. Nebbie.version .. " pronto.\n")
  end
end


-- Nebbie dashboard panels (equip, spells, paths, weapon config) — per-character profiles
-- Loaded after nebbie-installer-core.lua; hooks existing GUI/buff/eq handlers.

Nebbie.dashboardVer = 4
Nebbie.EQ_LABEL_WIDTH = 13
Nebbie.expiredSpells = Nebbie.expiredSpells or {}
Nebbie.eqWornByLabel = Nebbie.eqWornByLabel or {}
Nebbie._dashboardHidden = Nebbie._dashboardHidden or false
Nebbie.dashSpellH = 130
Nebbie.dashPathsH = 110
Nebbie.dashHeaderH = 18

-- Ordine e etichette come pannello equip italiano (screenshot Lamreloc / Nebbie)
Nebbie.EQ_SLOTS = {
  { tag = "<sul dito destro>", label = "Dito Dx" },
  { tag = "<sul dito sinistro>", label = "Dito Sx" },
  { tag = "<intorno al collo>", label = "Collo", alt = 1 },
  { tag = "<intorno al collo>", label = "Collo 2", alt = 2 },
  { tag = "<sul corpo>", label = "Corpo" },
  { tag = "<in testa>", label = "Testa" },
  { tag = "<sulle gambe>", label = "Gambe" },
  { tag = "<ai piedi>", label = "Piedi" },
  { tag = "<sulle mani>", label = "Mani" },
  { tag = "<sulle braccia>", label = "Braccia" },
  { tag = "<come scudo>", label = "Scudo" },
  { tag = "<intorno al corpo>", label = "Sopra" },
  { tag = "<intorno alla vita>", label = "Vita" },
  { tag = "<al polso destro>", label = "Polso Dx" },
  { tag = "<al polso sinistro>", label = "Polso Sx" },
  { tag = "<impugnato>", label = "Impugnato" },
  { tag = "<tenuto>", label = "Tenuto" },
  { tag = "<sulla schiena>", label = "Schiena" },
  { tag = "<all'orecchio destro>", label = "Orecchio Dx" },
  { tag = "<all'orecchio sinistro>", label = "Orecchio Sx" },
  { tag = "<davanti agli occhi>", label = "Occhi" },
  { tag = "<incoccata>", label = "Incoccata" },
  { tag = "<come luce>", label = "Luce" },
}

Nebbie.WEAPON_SLOTS = {
  { key = "current", label = "arma attuale" },
  { key = "slash", label = "slash" },
  { key = "blunt", label = "blunt" },
  { key = "pierce", label = "pierce" },
}

Nebbie.UTILITY_SLOTS = {
  { key = "tiro", label = "tiro" },
  { key = "hold", label = "hold" },
  { key = "sacca", label = "sacca" },
  { key = "bevanda", label = "bevanda" },
}

Nebbie.panels = {
  eq = { bar = "NebbieEqBar", con = "NebbieEq", title = "Equip" },
  spells = { bar = "NebbieSpellsBar", con = "NebbieSpells", title = "SpellWindow" },
  paths = { bar = "NebbiePathsBar", con = "NebbiePaths", title = "UpWindow" },
  config = { bar = "NebbieConfigBar", con = "NebbieConfig", title = "ConfigWindow" },
}

function Nebbie.getCharName()
  if Nebbie.stats and Nebbie.stats.name then return Nebbie.stats.name end
  if Nebbie._charName and Nebbie._charName ~= "" then return Nebbie._charName end
  return nil
end

function Nebbie.ensureCharProfile()
  local name = Nebbie.getCharName()
  if not name then return nil end
  local profile = Nebbie.getCharProfileRecord(name, true)
  return profile, name
end

function Nebbie.setWeaponKey(slot, value)
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then
    cecho("<orange>Nebbie: nome PG non rilevato — esegui un comando e riprova.\n")
    return
  end
  slot = (slot or ""):lower()
  value = Nebbie.stripQuotes(value or ""):lower()
  if value == "" then
    cecho("<orange>Nebbie: <yellow>nweapon " .. slot .. " <parola_mud>\n")
    return
  end
  profile.weapons = profile.weapons or {}
  profile.weapons[slot] = value
  Nebbie.saveSettings()
  cecho("<green>Nebbie [" .. name .. "]: <yellow>" .. slot .. " <green>= <white>" .. value .. "\n")
  Nebbie.refreshConfigPanel()
end

function Nebbie.setUtilityKey(slot, value)
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then return end
  slot = (slot or ""):lower()
  value = Nebbie.stripQuotes(value or ""):lower()
  if value == "" then return end
  profile.utility = profile.utility or {}
  profile.utility[slot] = value
  Nebbie.saveSettings()
  cecho("<green>Nebbie [" .. name .. "]: <yellow>" .. slot .. " <green>= <white>" .. value .. "\n")
  Nebbie.refreshConfigPanel()
end

function Nebbie.addPath(name, route)
  local profile = Nebbie.ensureCharProfile()
  if not profile then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  route = (route or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" or route == "" then
    cecho("<orange>Nebbie: <yellow>npath add <nome> <percorso>\n")
    return
  end
  profile.paths = profile.paths or {}
  for i, p in ipairs(profile.paths) do
    if p.name == name then
      profile.paths[i] = { name = name, route = route }
      Nebbie.saveSettings()
      cecho("<green>Nebbie: path <yellow>" .. name .. "<green> aggiornato.\n")
      Nebbie.refreshPathsPanel()
      return
    end
  end
  table.insert(profile.paths, { name = name, route = route })
  Nebbie.saveSettings()
  cecho("<green>Nebbie: path <yellow>" .. name .. "<green> aggiunto.\n")
  Nebbie.refreshPathsPanel()
end

function Nebbie.delPath(name)
  local profile = Nebbie.ensureCharProfile()
  if not profile then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local kept, found = {}, false
  for _, p in ipairs(profile.paths or {}) do
    if p.name == name then found = true else table.insert(kept, p) end
  end
  profile.paths = kept
  Nebbie.saveSettings()
  if found then
    cecho("<green>Nebbie: path <yellow>" .. name .. "<green> rimosso.\n")
    Nebbie.refreshPathsPanel()
  else
    cecho("<orange>Nebbie: path non trovato.\n")
  end
end

function Nebbie.listPaths()
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then return end
  cecho("<cyan><b>Paths [" .. tostring(name) .. "]</b>\n")
  if not profile.paths or #profile.paths == 0 then
    cecho("<grey>  (nessuno) — <yellow>npath add <nome> <percorso>\n")
    return
  end
  for i, p in ipairs(profile.paths) do
    cecho("<grey>  <yellow>" .. i .. ". " .. p.name .. " <white>" .. p.route .. "\n")
  end
end

function Nebbie.normalizeSpeedwalk(route)
  if not route then return "" end
  local s = route:gsub("%([^)]+%)", "")
  s = s:gsub(",", "")
  s = s:gsub("%s+", "")
  return s
end

function Nebbie.runPath(indexOrName)
  local profile = Nebbie.ensureCharProfile()
  if not profile or not profile.paths then return end
  local idx = tonumber(indexOrName)
  local path
  if idx then path = profile.paths[idx]
  else
    for _, p in ipairs(profile.paths) do
      if p.name == indexOrName then path = p break end
    end
  end
  if not path then
    cecho("<orange>Nebbie: path non trovato.\n")
    return
  end
  local sw = Nebbie.normalizeSpeedwalk(path.route)
  if sw == "" then
    cecho("<orange>Nebbie: percorso vuoto.\n")
    return
  end
  if type(speedWalk) == "function" then
    cecho("<green>Nebbie: speedwalk <yellow>" .. path.name .. "<green> → <white>" .. sw .. "\n")
    speedWalk(sw)
  else
    send(sw)
  end
end

function Nebbie.onDashboardEqLine(line)
  if not Nebbie._dashEqActive then return end
  local plain = Nebbie.stripColors(line or "")
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    if plain:find(slot.tag, 1, true) then
      local item = plain:match("%]%s*(.+)$") or plain:match(">%s*(.+)$")
      if item then
        item = item:gsub("^%s+", ""):gsub("%s+$", "")
        if slot.alt == 1 then
          Nebbie._dashNeck = 1
        elseif slot.alt == 2 then
          Nebbie._dashNeck = 2
        end
        Nebbie.eqWornByLabel[slot.label] = item
        if slot.label == "Impugnato" then
          local profile = Nebbie.ensureCharProfile()
          if profile then
            profile.weapons = profile.weapons or {}
            profile.weapons.current = Nebbie.eqShortName(item)
            Nebbie.saveSettings()
          end
        end
      end
      Nebbie.refreshEqPanel()
      break
    end
  end
end

function Nebbie.requestEqPanel()
  Nebbie._dashEqActive = true
  Nebbie.eqWornByLabel = {}
  if Nebbie.requestEqCache then
    Nebbie.requestEqCache(false)
    if type(tempTimer) == "function" then
      tempTimer(2.5, function()
        Nebbie._dashEqActive = false
        Nebbie.refreshEqPanel()
      end)
    end
  else
    send("eq")
    if type(tempTimer) == "function" then
      tempTimer(2, function()
        Nebbie._dashEqActive = false
        Nebbie.refreshEqPanel()
      end)
    end
  end
end

function Nebbie.trackExpiredSpell(spell)
  if not spell then return end
  if Nebbie.normalizeBuffSpell then spell = Nebbie.normalizeBuffSpell(spell) end
  Nebbie.expiredSpells = Nebbie.expiredSpells or {}
  Nebbie.expiredSpells[spell:lower()] = spell
end

function Nebbie.dashboardLayout()
  return Nebbie.computeUILayout()
end

function Nebbie.panelExists(key)
  local p = Nebbie.panels[key]
  if not p then return false end
  if type(getMiniConsoleLines) == "function" then
    local ok = pcall(function() return getMiniConsoleLines(p.con) end)
    if ok then return true end
  end
  if type(isHidden) == "function" then
    local ok = pcall(function() return isHidden(p.con) end)
    return ok
  end
  return false
end

function Nebbie.buildPanel(key, layout)
  local p = Nebbie.panels[key]
  local l = layout[key]
  if not p or not l or type(createLabel) ~= "function" then return end
  local hh = Nebbie.dashHeaderH
  if not Nebbie.panelExists(key) then
    createLabel(p.bar, l.x, l.y, l.w, hh, 1)
    setBackgroundColor(p.bar, 50, 42, 30, 255)
    setFgColor(p.bar, 220, 190, 120)
    echo(p.bar, " " .. p.title)
    createMiniConsole(p.con, l.x, l.y + hh, l.w, l.h - hh, true)
    setMiniConsoleFontSize(p.con, 9)
    setBackgroundColor(p.con, 18, 18, 24, 255)
    setFgColor(p.con, 200, 200, 200)
  end
  Nebbie.movePanel(key, l)
end

function Nebbie.movePanel(key, l)
  local p = Nebbie.panels[key]
  if not p or not l or type(moveWindow) ~= "function" then return end
  local hh = Nebbie.dashHeaderH
  local x, y, w, h = math.floor(l.x), math.floor(l.y), math.floor(l.w), math.floor(l.h)
  pcall(function() moveWindow(p.bar, x, y) end)
  pcall(function() resizeWindow(p.bar, w, hh) end)
  pcall(function() moveWindow(p.con, x, y + hh) end)
  pcall(function() resizeWindow(p.con, w, math.max(24, h - hh)) end)
  if type(raiseWindow) == "function" then
    pcall(function() raiseWindow(p.bar) end)
    pcall(function() raiseWindow(p.con) end)
  end
  showWindow(p.bar)
  showWindow(p.con)
end

function Nebbie.repositionDashboard(u)
  if not u then u = Nebbie.computeUILayout() end
  local map = { eq = u.eq, spells = u.spells, paths = u.paths, config = u.config }
  for key, l in pairs(map) do
    if l and Nebbie.panelExists(key) then
      Nebbie.movePanel(key, l)
    end
  end
end

function Nebbie.clearPanel(con)
  if type(clearWindow) == "function" then pcall(function() clearWindow(con) end) end
end

function Nebbie.echoLinkLine(con, text, cmd, hint)
  if type(echoLink) == "function" then
    echoLink(con, text, cmd, hint or text, true)
  else
    cecho(con, text)
  end
end

function Nebbie.formatEqSlotLabel(label)
  local w = Nebbie.EQ_LABEL_WIDTH or 13
  if #label > w then return label:sub(1, w) end
  return label .. string.rep(" ", w - #label)
end

function Nebbie.refreshEqPanel()
  local p = Nebbie.panels.eq
  if not p or not Nebbie.panelExists("eq") then return end
  Nebbie.clearPanel(p.con)
  cecho(p.con, "<grey>digita <yellow>neq<grey> per aggiornare\n")
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    local item = Nebbie.eqWornByLabel[slot.label]
    local label = Nebbie.formatEqSlotLabel(slot.label)
    cecho(p.con, "<goldenrod>" .. label .. "<grey>: ")
    if item and item ~= "" then
      cecho(p.con, "<light_green>" .. item .. "\n")
    else
      cecho(p.con, "<dark_grey>(vuoto)\n")
    end
  end
end

function Nebbie.refreshSpellPanel()
  local p = Nebbie.panels.spells
  if not p or not Nebbie.panelExists("spells") then return end
  Nebbie.clearPanel(p.con)
  local activeLower = {}
  local activeCount = 0
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" and data.active then
      activeLower[spell:lower()] = spell
      activeCount = activeCount + 1
      local label = spell:upper()
      local esc = spell:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<light_green>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Lancia " .. spell)
    end
  end
  local expiredCount = 0
  for lower, spell in pairs(Nebbie.expiredSpells or {}) do
    if not activeLower[lower] then
      expiredCount = expiredCount + 1
      local label = (type(spell) == "string" and spell:upper()) or lower:upper()
      local esc = (type(spell) == "string" and spell) or lower
      esc = esc:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<red>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Rilancia " .. esc)
    end
  end
  if activeCount == 0 and expiredCount == 0 then
    cecho(p.con, "<grey>(nessuna spell — <yellow>nattrib<grey> o lancia)\n")
  end
end

function Nebbie.refreshPathsPanel()
  local p = Nebbie.panels.paths
  if not p or not Nebbie.panelExists("paths") then return end
  Nebbie.clearPanel(p.con)
  local profile = Nebbie.ensureCharProfile()
  if profile and profile.paths and #profile.paths > 0 then
    for i, path in ipairs(profile.paths) do
      Nebbie.echoLinkLine(p.con, "<cyan>" .. path.name .. ":<grey> ",
        "Nebbie.runPath(" .. i .. ")", "Esegui " .. path.name)
      cecho(p.con, "<sky_blue>" .. path.route:sub(1, 70) .. "\n")
    end
  else
    cecho(p.con, "<grey>npath add <nome> <percorso>\n")
  end
end

function Nebbie.refreshConfigPanel()
  local p = Nebbie.panels.config
  if not p or not Nebbie.panelExists("config") then return end
  Nebbie.clearPanel(p.con)
  local profile, name = Nebbie.ensureCharProfile()
  if name then
    cecho(p.con, "<goldenrod>Personaggio: <white>" .. name .. "\n")
  else
    cecho(p.con, "<grey>PG: scegli dal menu login o <yellow>nchar Nome\n")
  end
  if not profile then
    cecho(p.con, "<grey>Config con <yellow>nweapon slash spada\n")
    return
  end
  profile.weapons = profile.weapons or {}
  profile.utility = profile.utility or {}
  for _, slot in ipairs(Nebbie.WEAPON_SLOTS) do
    local val = profile.weapons[slot.key] or "-"
    cecho(p.con, "<yellow>" .. slot.label .. ":<grey> ")
    if val ~= "-" then
      local esc = val:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<light_green>" .. val .. "\n",
        "Nebbie.useWeaponKeyword('" .. esc .. "')", "usa " .. val)
    else
      cecho(p.con, "<dark_grey>-\n")
    end
  end
  for _, slot in ipairs(Nebbie.UTILITY_SLOTS) do
    local val = profile.utility[slot.key] or "-"
    cecho(p.con, "<yellow>" .. slot.label .. ":<grey> ")
    if val ~= "-" then
      local esc = val:gsub("'", "\\'")
      local cmd = slot.key == "hold" and ("hold " .. esc) or ("get " .. esc)
      Nebbie.echoLinkLine(p.con, "<light_green>" .. val .. "\n",
        "send('" .. cmd .. "')", cmd)
    else
      cecho(p.con, "<dark_grey>-\n")
    end
  end
  cecho(p.con, "<grey>nweapon slash spada | nkey add korred ...\n")
end

function Nebbie.refreshDashboard()
  if not Nebbie.dashboardPanelsVisible() then return end
  Nebbie.refreshEqPanel()
  Nebbie.refreshSpellPanel()
  Nebbie.refreshPathsPanel()
  Nebbie.refreshConfigPanel()
end

function Nebbie.dashboardExists()
  return Nebbie.panelExists("eq")
end

function Nebbie.showDashboard()
  for key, p in pairs(Nebbie.panels) do
    if Nebbie.panelExists(key) then
      showWindow(p.bar)
      showWindow(p.con)
    end
  end
  Nebbie._dashboardHidden = false
  if Nebbie.applyUILayout then Nebbie.applyUILayout() end
  Nebbie.refreshDashboard()
end

function Nebbie.hideDashboard()
  for _, p in pairs(Nebbie.panels) do
    hideWindow(p.bar)
    hideWindow(p.con)
  end
  Nebbie._dashboardHidden = true
  if Nebbie.applyUILayout then Nebbie.applyUILayout() end
end

function Nebbie.toggleDashboard()
  if not Nebbie.dashboardExists() then
    Nebbie.initDashboard()
    return
  end
  if Nebbie._dashboardHidden then Nebbie.showDashboard() else Nebbie.hideDashboard() end
end

function Nebbie.destroyDashboard()
  for _, p in pairs(Nebbie.panels) do
    if type(deleteMiniConsole) == "function" then pcall(function() deleteMiniConsole(p.con) end) end
    if type(deleteLabel) == "function" then pcall(function() deleteLabel(p.bar) end) end
  end
end

function Nebbie.buildDashboard()
  local layout = Nebbie.computeUILayout()
  for key, _ in pairs(Nebbie.panels) do
    local slot = layout[key]
    if slot then Nebbie.buildPanel(key, layout) end
  end
  Nebbie.refreshDashboard()
end

function Nebbie.initDashboard()
  Nebbie.loadSettings()
  local ver = Nebbie._settings.dashboardVer or 0
  if ver < Nebbie.dashboardVer then
    Nebbie.destroyDashboard()
    Nebbie._settings.dashboardVer = Nebbie.dashboardVer
    Nebbie.saveSettings()
  end
  if not Nebbie.dashboardExists() then
    Nebbie.buildDashboard()
  else
    if Nebbie.applyUILayout then Nebbie.applyUILayout() end
    Nebbie.refreshDashboard()
  end
  if type(tempTimer) == "function" then
    tempTimer(0.8, function()
      if Nebbie.populatePanels then Nebbie.populatePanels() end
    end)
  end
end

-- Hook play-all handlers (dashboard loads after installer core)
do
  local _origOnEqParseLine = Nebbie.onEqParseLine
  function Nebbie.onEqParseLine()
    if Nebbie.onDashboardEqLine then
      Nebbie.onDashboardEqLine(Nebbie.resolveTriggerLine())
    end
    if _origOnEqParseLine then return _origOnEqParseLine() end
  end

  local _origOnBuffWearOff = Nebbie.onBuffWearOff
  function Nebbie.onBuffWearOff(spell)
    if _origOnBuffWearOff then _origOnBuffWearOff(spell) end
    Nebbie.trackExpiredSpell(spell)
    Nebbie.refreshSpellPanel()
  end

  local _origOnBuffApplied = Nebbie.onBuffApplied
  function Nebbie.onBuffApplied(spell)
    if _origOnBuffApplied then _origOnBuffApplied(spell) end
    if spell and Nebbie.expiredSpells then
      local key = spell
      if Nebbie.normalizeBuffSpell then key = Nebbie.normalizeBuffSpell(spell) end
      Nebbie.expiredSpells[key:lower()] = nil
    end
    Nebbie.refreshSpellPanel()
  end

  local _origRefreshGUI = Nebbie.refreshGUI
  function Nebbie.refreshGUI()
    if _origRefreshGUI then _origRefreshGUI() end
    Nebbie.refreshDashboard()
  end

  local _origInitGUI = Nebbie.initGUI
  function Nebbie.initGUI()
    if _origInitGUI then _origInitGUI() end
    Nebbie.initDashboard()
  end

  local _origDestroyGUI = Nebbie.destroyGUI
  function Nebbie.destroyGUI()
    Nebbie.destroyDashboard()
    if _origDestroyGUI then _origDestroyGUI() end
  end

  local _origShowGUI = Nebbie.showGUI
  function Nebbie.showGUI()
    if _origShowGUI then _origShowGUI() end
    Nebbie.showDashboard()
  end

  local _origHideGUI = Nebbie.hideGUI
  function Nebbie.hideGUI()
    Nebbie.hideDashboard()
    if _origHideGUI then _origHideGUI() end
  end
end
