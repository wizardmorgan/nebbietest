'use strict';
/**
 * Listino unico `edit_listino` / `edit_listino_rules` (schema MUD Server,
 * heal_v15_edit_listino). Il portale legge e scrive QUI: niente piu'
 * listino_affect / listino_pool / listino_param / listino_cap_group.
 *
 * Mapping campi storici del portale -> colonne edit_listino:
 *   id            -> code   (alias: armor<->ac, int<->intel)
 *   label         -> label
 *   location      -> apply_loc
 *   pos_unit_raw  -> xp = pos_unit_raw * STORAGE_SCALE * step  (xp per slot)
 *   neg_unit_raw  -> derivato: pos * regola malus_mult (non salvato)
 *   step (±)      -> step = |step|, sign = segno dello step (AC -10 -> 10, -1)
 *   min/max_total -> cap_obj = |min| (sign -1) o max (sign +1)
 *   rune_num/den  -> rune_num / rune_den (per unita') ; salvati per slot
 *   cap_group     -> cap_group  (max_piece = cap_obj, max_character = cap_pc)
 *   enabled       -> enabled (interruttore; on_obj/on_pc = dove si vende)
 *   pool.step     -> buy_step (passo di acquisto 10 / 5)
 *   pool.cap      -> cap_pc ; pool.xp_per_unit -> xp (step 1)
 *   cap_group lbl -> edit_listino_cap_group.label
 *
 * Voci nuove: nascono SEMPRE spente (enabled=0, on_obj=0, on_pc=0).
 * enabled=1 solo se il MUD dichiara la voce supportata (myst
 * /internal/listino-status rows[code].supported, o colonna mud_supported se
 * il Server la pubblica).
 *   listino_param -> edit_listino_rules (num/den), es. broker_fee_percent 25/1
 *
 * Il MUD (Server e myst) tiene una cache: dopo ogni scrittura il chiamante
 * deve chiedere il reload (myst /internal/listino-reload).
 */

const STORAGE_SCALE = 10000;

const CODE_RE = /^[a-z0-9_]{1,64}$/;
const RULE_RE = /^[a-z0-9_]{1,64}$/;

/** Alias storici portale -> codice listino. */
const PORTAL_ID_TO_CODE = { armor: 'ac', int: 'intel' };
const CODE_TO_PORTAL_ID = { ac: 'armor', intel: 'int' };

/** APPLY_* pool (autoenums.hpp, identici Server/nebbietest). */
const POOL_APPLY = { 12: 'mana', 13: 'hit', 14: 'move', 50: 'mana_regen', 51: 'hit_regen', 52: 'move_regen' };
const ITEM_IMMUNE = 262144;

/** Colonne scrivibili + tipo + default per una riga nuova. */
const COLUMNS = {
  code: { type: 'code' },
  label: { type: 'str', max: 128, def: '' },
  category: { type: 'str', max: 32, def: 'custom' },
  xp: { type: 'int', min: 0, def: 0 },
  rune_num: { type: 'int', min: 0, def: 0 },
  rune_den: { type: 'int', min: 1, def: 1 },
  sign: { type: 'sign', def: 1 },
  cap_obj: { type: 'int', min: 0, def: 0 },
  step: { type: 'int', min: 1, def: 1 },
  on_obj: { type: 'bool', def: 0 },
  on_pc: { type: 'bool', def: 0 },
  cap_pc: { type: 'int', min: 0, def: 0 },
  cap_group: { type: 'str', max: 32, def: '' },
  over_cap: { type: 'int', min: 0, def: 0 },
  over_step: { type: 'int', min: 0, def: 0 },
  over_rune: { type: 'int', min: 0, def: 0 },
  over_xp: { type: 'int', min: 0, def: 0 },
  over_gold: { type: 'int', min: 0, def: 0 },
  over_inc_pct: { type: 'int', min: 0, def: 0 },
  apply_loc: { type: 'int', min: 0, def: 0 },
  apply_bit: { type: 'uint', def: 0 },
  resist_equiv: { type: 'int', min: -100, max: 100, def: 0 },
  resist_code: { type: 'str', max: 64, def: '' },
  buy_step: { type: 'int', min: 1, max: 32767, def: 1 },
  enabled: { type: 'bool', def: 0 },
};
/** Colonne che possono mancare finche' Server/myst non hanno fatto l'heal. */
const OPTIONAL_COLUMNS = ['buy_step', 'enabled', 'resist_equiv', 'resist_code'];
/* mud_supported NON e' scrivibile dal portale: la decide il MUD. */
const WRITABLE = Object.keys(COLUMNS).filter((c) => c !== 'code');

function gcd(a, b) {
  a = Math.abs(a);
  b = Math.abs(b);
  while (b) [a, b] = [b, a % b];
  return a || 1;
}

function reduce(num, den) {
  const g = gcd(num, den);
  return [num / g, den / g];
}

function ruleValue(rules, key, fallback) {
  const r = rules && rules[key];
  if (!r || !Number(r.den)) return fallback;
  return Number(r.num) / Number(r.den);
}

/** Riga DB -> vista storica del portale (affect / pool / flag / bit). */
function toPortalView(row, rules) {
  const step = Math.max(1, Number(row.step) || 1);
  const sign = Number(row.sign) < 0 ? -1 : 1;
  const capObj = Math.abs(Number(row.cap_obj) || 0);
  const xp = Number(row.xp) || 0;
  const applyLoc = Number(row.apply_loc) || 0;
  const applyBit = Number(row.apply_bit) || 0;
  const xpUnit = Math.round(xp / step);
  const [runeNum, runeDen] = reduce(Number(row.rune_num) || 0, (Number(row.rune_den) || 1) * step);
  const malus = ruleValue(rules, 'malus_mult', 2);
  const posRaw = Math.round(xpUnit / STORAGE_SCALE);
  let kind = 'other';
  if (applyLoc === 0 && applyBit === ITEM_IMMUNE) kind = 'flag';
  else if (POOL_APPLY[applyLoc] && applyBit === 0) kind = 'pool';
  else if (applyLoc > 0 && applyBit === 0) kind = 'affect';
  else if (applyLoc > 0) kind = 'bit';
  const where = kind === 'pool' ? !!Number(row.on_pc) : !!(Number(row.on_obj) || Number(row.on_pc));
  const enabled = row.enabled !== undefined ? !!Number(row.enabled) && where : where;
  const buyStep = Math.max(1, Number(row.buy_step) || 1);
  return {
    id: CODE_TO_PORTAL_ID[row.code] || row.code,
    kind,
    enabled,
    location: applyLoc,
    step: kind === 'pool' ? (buyStep > 1 ? buyStep : step > 1 ? step : 0) : sign < 0 ? -step : step,
    min_total: sign < 0 ? -capObj : 0,
    max_total: sign < 0 ? 0 : capObj,
    pos_unit_raw: posRaw,
    neg_unit_raw: Math.round(posRaw * malus),
    rune_num: runeNum,
    rune_den: runeDen,
    cap_group: row.cap_group || '',
    pool_field: kind === 'pool' ? POOL_APPLY[applyLoc] : undefined,
    cap: kind === 'pool' ? Number(row.cap_pc) || 0 : capObj,
    xp_per_unit: xpUnit,
  };
}

function coerce(col, value) {
  const spec = COLUMNS[col];
  if (!spec) throw new Error(`colonna sconosciuta: ${col}`);
  switch (spec.type) {
    case 'code': {
      const s = String(value || '').trim().toLowerCase();
      const code = PORTAL_ID_TO_CODE[s] || s;
      if (!CODE_RE.test(code)) throw new Error('code non valido (a-z, 0-9, _; max 64)');
      return code;
    }
    case 'str': {
      const s = value == null ? '' : String(value).trim();
      if (s.length > spec.max) throw new Error(`${col}: max ${spec.max} caratteri`);
      return s;
    }
    case 'bool':
      return value === true || value === 1 || value === '1' || value === 'true' ? 1 : 0;
    case 'sign':
      return Number(value) < 0 ? -1 : 1;
    case 'uint': {
      const s = String(value == null ? 0 : value).trim();
      if (!/^\d+$/.test(s)) throw new Error(`${col}: intero >= 0`);
      return s; // BIGINT UNSIGNED: stringa per non perdere precisione
    }
    case 'int':
    default: {
      const n = Number(value);
      if (!Number.isFinite(n) || !Number.isInteger(n)) throw new Error(`${col}: intero richiesto`);
      if (spec.min != null && n < spec.min) throw new Error(`${col}: minimo ${spec.min}`);
      if (spec.max != null && n > spec.max) throw new Error(`${col}: massimo ${spec.max}`);
      return n;
    }
  }
}

/**
 * Converte i campi storici del portale (pos_unit_raw, step ±, min/max_total,
 * location, enabled, rune per unita', pool cap/xp_per_unit) in colonne
 * edit_listino. Le colonne native passate esplicitamente vincono.
 */
function portalFieldsToColumns(input, existing) {
  const out = {};
  const has = (k) => input[k] !== undefined && input[k] !== null && input[k] !== '';
  if (has('location') && !has('apply_loc')) out.apply_loc = input.location;
  const locGuess = Number(input.apply_loc ?? input.location ?? (existing && existing.apply_loc) ?? 0);
  const step = has('step') ? Number(input.step) : null;
  if (step !== null && POOL_APPLY[locGuess] && !has('buy_step') && input.pool_field !== undefined) {
    /* step stile listino_pool (10 / 5) = passo di acquisto. */
    out.buy_step = Math.abs(step);
  } else if (step !== null && Number.isFinite(step) && step !== 0) {
    /* Step negativo stile portale (AC -10): segno -1. Positivo: segno invariato. */
    if (step < 0 && !has('sign')) out.sign = -1;
    out.step = Math.abs(step);
  }
  const effStep = Math.max(1, Number(out.step ?? (existing && existing.step) ?? 1));
  if (has('min_total') || has('max_total')) {
    if (!has('cap_obj')) {
      const mn = Math.abs(Number(input.min_total) || 0);
      const mx = Math.abs(Number(input.max_total) || 0);
      out.cap_obj = Math.max(mn, mx);
      if (!has('sign') && out.sign === undefined && mn > 0 && mx === 0) out.sign = -1;
    }
  }
  if (has('pos_unit_raw') && !has('xp')) {
    out.xp = Math.round(Number(input.pos_unit_raw) * STORAGE_SCALE * effStep);
  }
  if (has('xp_per_unit') && !has('xp')) {
    out.xp = Math.round(Number(input.xp_per_unit) * effStep);
  }
  if (has('rune_per_unit_num') && !has('rune_num')) {
    const [n, d] = reduce(Number(input.rune_per_unit_num) * effStep, Number(input.rune_per_unit_den) || 1);
    out.rune_num = n;
    out.rune_den = d;
  }
  if (has('cap') && !has('cap_pc') && !has('cap_obj')) {
    const loc = Number(out.apply_loc ?? input.apply_loc ?? (existing && existing.apply_loc) ?? 0);
    if (POOL_APPLY[loc]) out.cap_pc = input.cap;
    else out.cap_obj = input.cap;
  }
  /* enabled ora e' una colonna propria: nessuna conversione su on_obj/on_pc. */
  return out;
}

/** Valida e normalizza; per una riga nuova riempie i default. */
function normalizeItem(input, existing) {
  if (!input || typeof input !== 'object') throw new Error('item richiesto');
  const raw = { ...input, ...portalFieldsToColumns(input, existing) };
  const code = coerce('code', raw.code ?? raw.id);
  const fields = {};
  for (const col of WRITABLE) {
    if (raw[col] !== undefined && raw[col] !== null && !(raw[col] === '' && COLUMNS[col].type !== 'str')) {
      fields[col] = coerce(col, raw[col]);
    }
  }
  if (!existing) {
    for (const col of WRITABLE) {
      if (fields[col] === undefined) fields[col] = COLUMNS[col].def;
    }
    /* Regola Corrado: ogni voce nuova nasce spenta, qualunque cosa arrivi dal form. */
    fields.enabled = 0;
    fields.on_obj = 0;
    fields.on_pc = 0;
    if (!fields.label) fields.label = code;
    if (fields.category === 'custom') {
      if (POOL_APPLY[fields.apply_loc] && Number(fields.apply_bit) === 0) fields.category = 'pool';
      else if (Number(fields.apply_bit) !== 0) fields.category = 'extra';
    }
  }
  if (fields.label !== undefined && !fields.label) throw new Error('label richiesta');
  return { code, fields };
}

async function tableColumns(pool, table) {
  const [rows] = await pool.query(
    'SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
    [table]
  );
  return new Set(rows.map((r) => r.c));
}

async function loadCapGroupLabels(pool) {
  try {
    const [rows] = await pool.query('SELECT code, label FROM edit_listino_cap_group');
    const out = {};
    rows.forEach((r) => {
      out[r.code] = r.label;
    });
    return out;
  } catch {
    return {}; /* tabella non ancora creata (heal MUD/myst) */
  }
}

/**
 * Supporto MUD per riga. Fonte: stato myst (rows[code].supported) se
 * disponibile, altrimenti colonna mud_supported (proposta Server), altrimenti
 * sconosciuto (null).
 */
function mudSupportFor(row, mudRows, columnInUse = null) {
  /* Colonna mud_supported (scritta dal MUD Server al boot): conta solo se il
   * Server l'ha gia' valorizzata su almeno una riga. */
  const useColumn =
    columnInUse === null ? row.mud_supported !== undefined && Number(row.mud_supported) === 1 : columnInUse;
  const colOk = !useColumn || Number(row.mud_supported) === 1;
  const st = mudRows && mudRows[row.code];
  if (st) {
    const supported = !!st.supported && colOk;
    let reason = st.reason || '';
    if (st.supported && !colOk) reason = 'il MUD Server non la implementa ancora (mud_supported=0)';
    return { supported, active: !!st.active, reason, source: useColumn ? 'myst+column' : 'myst' };
  }
  if (useColumn) {
    return { supported: colOk, active: null, reason: colOk ? '' : 'mud_supported=0', source: 'column' };
  }
  return { supported: null, active: null, reason: 'stato MUD non disponibile', source: null };
}

async function loadRules(pool) {
  const [rows] = await pool.query('SELECT conf_key, num, den, updated_at FROM edit_listino_rules ORDER BY conf_key');
  const rules = {};
  for (const r of rows) rules[r.conf_key] = { num: Number(r.num), den: Number(r.den) || 1, updated_at: r.updated_at };
  return rules;
}

async function listListino(pool, mudRows = null) {
  const rules = await loadRules(pool);
  const labels = await loadCapGroupLabels(pool);
  const [rows] = await pool.query(
    'SELECT *, CAST(apply_bit AS CHAR) AS apply_bit FROM edit_listino ORDER BY category, code'
  );
  const columnInUse = rows.some((r) => Number(r.mud_supported) === 1);
  const items = rows.map((r) => ({
    ...r,
    portal: toPortalView(r, rules),
    mud: mudSupportFor(r, mudRows, columnInUse),
  }));
  const capGroups = {};
  for (const it of items) {
    if (!it.cap_group || it.portal.kind !== 'affect') continue;
    const g = capGroups[it.cap_group] || {
      group_key: it.cap_group,
      label: labels[it.cap_group] || it.cap_group,
      max_piece: 0,
      max_character: 0,
      members: [],
    };
    g.max_piece = Math.max(g.max_piece, Number(it.cap_obj) || 0);
    g.max_character = Math.max(g.max_character, Number(it.cap_pc) || 0);
    g.members.push(it.code);
    capGroups[it.cap_group] = g;
  }
  return {
    source: 'edit_listino',
    storage_scale: STORAGE_SCALE,
    items,
    rules,
    cap_groups: Object.values(capGroups),
    cap_group_labels: labels,
    broker_fee_percent: ruleValue(rules, 'broker_fee_percent', 25),
  };
}

/** Inserisce una riga nuova o aggiorna solo i campi passati. */
async function upsertItem(pool, input, mudRows = null) {
  const probeCode = coerce('code', input && (input.code ?? input.id));
  const [found] = await pool.query('SELECT * FROM edit_listino WHERE code = ? LIMIT 1', [probeCode]);
  const existing = found[0] || null;
  if (existing && input.create_only) throw new Error(`codice ${probeCode} gia' presente`);
  const { code, fields } = normalizeItem(input, existing);
  if (existing && Number(fields.enabled) === 1 && !Number(existing.enabled)) {
    let columnInUse = false;
    try {
      const [[c]] = await pool.query('SELECT IFNULL(SUM(mud_supported),0) AS n FROM edit_listino');
      columnInUse = Number(c.n) > 0;
    } catch {
      columnInUse = false; /* colonna non ancora creata */
    }
    const sup = mudSupportFor(existing, mudRows, columnInUse);
    if (sup.supported !== true) {
      throw new Error(
        sup.supported === false
          ? `voce ${code} non supportata dal MUD: non attivabile (${sup.reason || 'funzione non implementata'})`
          : `voce ${code}: impossibile verificare il supporto MUD (myst non raggiungibile), non attivabile ora`
      );
    }
  }
  const present = await tableColumns(pool, 'edit_listino');
  for (const col of Object.keys(fields)) {
    if (!present.has(col)) {
      if (OPTIONAL_COLUMNS.includes(col)) delete fields[col];
      else throw new Error(`colonna ${col} assente in edit_listino`);
    }
  }
  const cols = Object.keys(fields);
  if (existing) {
    if (!cols.length) return { code, created: false, changed: 0 };
    const sets = cols.map((c) => `\`${c}\` = ?`).join(', ');
    const [res] = await pool.query(`UPDATE edit_listino SET ${sets} WHERE code = ?`, [
      ...cols.map((c) => fields[c]),
      code,
    ]);
    return { code, created: false, changed: res.affectedRows };
  }
  const allCols = ['code', ...cols];
  const [res] = await pool.query(
    `INSERT INTO edit_listino (${allCols.map((c) => `\`${c}\``).join(', ')}) VALUES (${allCols.map(() => '?').join(', ')})`,
    [code, ...cols.map((c) => fields[c])]
  );
  return { code, created: true, changed: res.affectedRows };
}

/** Etichetta gruppo cap (edit_listino_cap_group). */
async function setCapGroupLabel(pool, code, label) {
  const key = String(code || '').trim().toLowerCase();
  if (!/^[a-z0-9_]{1,32}$/.test(key)) throw new Error('codice gruppo non valido');
  const lbl = String(label || '').trim();
  if (!lbl || lbl.length > 128) throw new Error('label gruppo richiesta (max 128)');
  await pool.query(
    'INSERT INTO edit_listino_cap_group (code, label) VALUES (?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)',
    [key, lbl]
  );
  return { code: key, label: lbl };
}

/** Regola num/den (anche nuove, es. broker_fee_percent). */
async function setRule(pool, confKey, num, den = 1) {
  const key = String(confKey || '').trim().toLowerCase();
  if (!RULE_RE.test(key)) throw new Error('conf_key non valida');
  const n = Number(num);
  const d = Number(den);
  if (!Number.isInteger(n)) throw new Error('num intero richiesto');
  if (!Number.isInteger(d) || d < 1) throw new Error('den intero >= 1 richiesto');
  await pool.query(
    'INSERT INTO edit_listino_rules (conf_key, num, den) VALUES (?, ?, ?) ' +
      'ON DUPLICATE KEY UPDATE num = VALUES(num), den = VALUES(den)',
    [key, n, d]
  );
  return { conf_key: key, num: n, den: d };
}

module.exports = {
  STORAGE_SCALE,
  COLUMNS,
  PORTAL_ID_TO_CODE,
  CODE_TO_PORTAL_ID,
  toPortalView,
  portalFieldsToColumns,
  normalizeItem,
  listListino,
  loadRules,
  upsertItem,
  setRule,
  setCapGroupLabel,
  mudSupportFor,
};
