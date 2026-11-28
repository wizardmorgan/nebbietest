'use strict';

/**
 * Listino ufficiale su MySQL (verita' dopo seed da listino_seed.inc nel mud).
 * Il portale legge/scrive queste tabelle; myst tiene cache RAM e la ricarica
 * via /internal/listino-reload.
 */

/** Stesso contenuto di src/listino_seed.inc (bootstrap se myst non ha ancora seedato). */
const SEED_AFFECT = [
  ['str', 'Forza (STR)', 1, 1, 0, 3, 1500, 3000],
  ['dex', 'Destrezza (DEX)', 2, 1, 0, 3, 1500, 3000],
  ['int', 'Intelligenza (INT)', 3, 1, 0, 3, 1500, 3000],
  ['wis', 'Saggezza (WIS)', 4, 1, 0, 3, 1500, 3000],
  ['chr', 'Carisma (CHR)', 6, 1, 0, 3, 1500, 3000],
  ['hitroll', 'Hitroll', 18, 1, 0, 2, 4500, 9000],
  ['damroll', 'Damroll', 19, 1, 0, 2, 10000, 20000],
  ['spellpower', 'Spellpower', 65, 1, 0, 2, 10000, 20000],
  ['armor', 'Armatura (AC)', 17, -10, -40, 0, 100, 200],
  ['spellfail', 'Spellfail', 41, -5, -100, 0, 400, 800],
  ['hitndam', 'Hit & damage', 40, 1, 0, 2, 14500, 29000],
  ['hitnsp', 'Hit & spellpower', 66, 1, 0, 2, 14500, 29000],
];
const SEED_POOL = [
  ['hit', 'Hit points', 100, 10, 300, 3000000, 3, 1],
  ['mana', 'Mana', 150, 10, 150, 1500000, 3, 2],
  ['move', 'Move', 100, 10, 100, 1000000, 3, 2],
  ['hit_regen', 'Hit regen', 50, 5, 300, 3000000, 3, 1],
  ['mana_regen', 'Mana regen', 50, 5, 300, 3000000, 3, 1],
  ['move_regen', 'Move regen', 50, 5, 200, 2000000, 6, 1],
];
const SEED_PARAMS = [
  ['storage_scale', 10000],
  ['class_mult_bi', 1.5],
  ['class_mult_tri', 2.0],
  ['artifact_mult', 1.5],
  ['artifact_cost_raw', 10000],
  ['broker_fee_percent', 25],
  ['seed_version', 2],
];
const SEED_TAG = 'listino_seed.inc/v2';

/** APPLY_* usabili dallo staff per nuovi valori listino (codice gioco). */
const APPLY_CATALOG = [
  { location: 1, name: 'APPLY_STR', label: 'Forza' },
  { location: 2, name: 'APPLY_DEX', label: 'Destrezza' },
  { location: 3, name: 'APPLY_INT', label: 'Intelligenza' },
  { location: 4, name: 'APPLY_WIS', label: 'Saggezza' },
  { location: 5, name: 'APPLY_CON', label: 'Costituzione' },
  { location: 6, name: 'APPLY_CHR', label: 'Carisma' },
  { location: 12, name: 'APPLY_MANA', label: 'Mana (affect)' },
  { location: 13, name: 'APPLY_HIT', label: 'Hit (affect)' },
  { location: 14, name: 'APPLY_MOVE', label: 'Move (affect)' },
  { location: 17, name: 'APPLY_AC', label: 'Armatura' },
  { location: 18, name: 'APPLY_HITROLL', label: 'Hitroll' },
  { location: 19, name: 'APPLY_DAMROLL', label: 'Damroll' },
  { location: 40, name: 'APPLY_HITNDAM', label: 'Hit & damage' },
  { location: 41, name: 'APPLY_SPELLFAIL', label: 'Spellfail' },
  { location: 50, name: 'APPLY_MANA_REGEN', label: 'Mana regen (affect)' },
  { location: 51, name: 'APPLY_HIT_REGEN', label: 'Hit regen (affect)' },
  { location: 52, name: 'APPLY_MOVE_REGEN', label: 'Move regen (affect)' },
  { location: 65, name: 'APPLY_SPELLPOWER', label: 'Spellpower' },
  { location: 66, name: 'APPLY_HITNSP', label: 'Hit & spellpower' },
];

async function ensureListinoTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS listino_meta (
      meta_key VARCHAR(64) NOT NULL,
      meta_value VARCHAR(255) NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (meta_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS listino_affect (
      id VARCHAR(32) NOT NULL,
      label VARCHAR(64) NOT NULL,
      location INT NOT NULL,
      step INT NOT NULL DEFAULT 1,
      min_total INT NOT NULL DEFAULT 0,
      max_total INT NOT NULL DEFAULT 0,
      pos_unit_raw BIGINT NOT NULL DEFAULT 0,
      neg_unit_raw BIGINT NOT NULL DEFAULT 0,
      rune_num INT NOT NULL DEFAULT 0,
      rune_den INT NOT NULL DEFAULT 1,
      cap_group VARCHAR(32) NULL,
      enabled TINYINT NOT NULL DEFAULT 1,
      PRIMARY KEY (id),
      UNIQUE KEY uq_listino_affect_location (location)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS listino_pool (
      field_key VARCHAR(32) NOT NULL,
      label VARCHAR(64) NOT NULL,
      cap INT NOT NULL DEFAULT 0,
      step INT NOT NULL DEFAULT 1,
      unit_valore BIGINT NOT NULL DEFAULT 0,
      xp_per_unit BIGINT NOT NULL DEFAULT 0,
      rune_num INT NOT NULL DEFAULT 0,
      rune_den INT NOT NULL DEFAULT 1,
      enabled TINYINT NOT NULL DEFAULT 1,
      PRIMARY KEY (field_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS listino_param (
      param_key VARCHAR(64) NOT NULL,
      param_value DOUBLE NOT NULL,
      PRIMARY KEY (param_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS listino_cap_group (
      group_key VARCHAR(32) NOT NULL,
      label VARCHAR(64) NOT NULL,
      max_piece INT NOT NULL DEFAULT 0,
      max_character INT NOT NULL DEFAULT 0,
      enabled TINYINT NOT NULL DEFAULT 1,
      PRIMARY KEY (group_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS character_edit_affect (
      toon_id BIGINT UNSIGNED NOT NULL,
      location INT NOT NULL,
      value INT NOT NULL DEFAULT 0,
      PRIMARY KEY (toon_id, location),
      KEY idx_char_edit_affect_loc (location)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  const ensureCol = async (table, col, ddl) => {
    try {
      await pool.query(`SELECT ${col} FROM ${table} LIMIT 0`);
    } catch {
      await pool.query(`ALTER TABLE ${table} ADD COLUMN ${col} ${ddl}`);
    }
  };
  await ensureCol('listino_affect', 'rune_num', 'INT NOT NULL DEFAULT 0');
  await ensureCol('listino_affect', 'rune_den', 'INT NOT NULL DEFAULT 1');
  await ensureCol('listino_affect', 'cap_group', 'VARCHAR(32) NULL');

  const [cntRows] = await pool.query('SELECT COUNT(*) AS c FROM listino_affect');
  if (Number(cntRows[0].c) === 0) {
    for (const r of SEED_AFFECT) {
      await pool.query(
        `INSERT INTO listino_affect
          (id, label, location, step, min_total, max_total, pos_unit_raw, neg_unit_raw, enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`,
        r,
      );
    }
    for (const r of SEED_POOL) {
      await pool.query(
        `INSERT INTO listino_pool
          (field_key, label, cap, step, unit_valore, xp_per_unit, rune_num, rune_den, enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`,
        r,
      );
    }
  }
  for (const [k, v] of SEED_PARAMS) {
    await pool.query(
      `INSERT IGNORE INTO listino_param (param_key, param_value) VALUES (?, ?)`,
      [k, v],
    );
  }
  await pool.query(
    `INSERT IGNORE INTO listino_cap_group
      (group_key, label, max_piece, max_character, enabled)
     VALUES ('dam_sp', 'Damroll + Spellpower', 2, 30, 1)`,
  );
  await pool.query(
    `UPDATE listino_affect SET cap_group = 'dam_sp'
     WHERE id IN ('damroll','spellpower','hitndam','hitnsp')
       AND (cap_group IS NULL OR cap_group = '')`,
  );
  await pool.query(
    `INSERT INTO listino_meta (meta_key, meta_value) VALUES ('seed_tag', ?)
     ON DUPLICATE KEY UPDATE meta_value = VALUES(meta_value)`,
    [SEED_TAG],
  );
}

async function fetchListinoSnapshot(pool) {
  const [affect] = await pool.query(
    `SELECT id, label, location, step, min_total, max_total, pos_unit_raw,
            neg_unit_raw, rune_num, rune_den, cap_group, enabled
     FROM listino_affect ORDER BY id`,
  );
  const [poolRows] = await pool.query(
    `SELECT field_key, label, cap, step, unit_valore, xp_per_unit, rune_num,
            rune_den, enabled FROM listino_pool ORDER BY field_key`,
  );
  const [params] = await pool.query(
    `SELECT param_key, param_value FROM listino_param ORDER BY param_key`,
  );
  const [capGroups] = await pool.query(
    `SELECT group_key, label, max_piece, max_character, enabled
     FROM listino_cap_group ORDER BY group_key`,
  );
  const [meta] = await pool.query(`SELECT meta_key, meta_value FROM listino_meta`);
  return {
    affect,
    pool: poolRows,
    params,
    cap_groups: capGroups,
    meta,
    apply_catalog: APPLY_CATALOG,
    source: 'mysql',
  };
}

async function bumpListinoRevision(pool, reason = 'portal') {
  await pool.query(
    `INSERT INTO listino_meta (meta_key, meta_value) VALUES ('revision', '1')
     ON DUPLICATE KEY UPDATE meta_value = CAST(meta_value AS UNSIGNED) + 1`,
  );
  await pool.query(
    `INSERT INTO listino_meta (meta_key, meta_value) VALUES ('last_change_reason', ?)
     ON DUPLICATE KEY UPDATE meta_value = VALUES(meta_value)`,
    [String(reason).slice(0, 255)],
  );
}

function slugifyId(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 32);
}

/**
 * Salva listino completo (upsert affect/pool/param/cap_group; delete affect rimossi
 * solo se explicitly listed in delete_affect_ids).
 */
async function saveListinoAdmin(pool, body) {
  const affect = Array.isArray(body.affect) ? body.affect : [];
  const poolRows = Array.isArray(body.pool) ? body.pool : [];
  const params = Array.isArray(body.params) ? body.params : [];
  const capGroups = Array.isArray(body.cap_groups) ? body.cap_groups : [];
  const deleteAffectIds = Array.isArray(body.delete_affect_ids)
    ? body.delete_affect_ids.map((x) => String(x))
    : [];
  const deleteCapGroups = Array.isArray(body.delete_cap_group_keys)
    ? body.delete_cap_group_keys.map((x) => String(x))
    : [];

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    for (const key of deleteCapGroups) {
      const k = String(key).slice(0, 32);
      if (!k) continue;
      await conn.query(`UPDATE listino_affect SET cap_group = NULL WHERE cap_group = ?`, [k]);
      await conn.query(`DELETE FROM listino_cap_group WHERE group_key = ?`, [k]);
    }

    for (const g of capGroups) {
      const groupKey = slugifyId(g.group_key || g.id);
      if (!groupKey) throw new Error('cap_group senza group_key');
      await conn.query(
        `INSERT INTO listino_cap_group
          (group_key, label, max_piece, max_character, enabled)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           label = VALUES(label),
           max_piece = VALUES(max_piece),
           max_character = VALUES(max_character),
           enabled = VALUES(enabled)`,
        [
          groupKey,
          String(g.label || groupKey).slice(0, 64),
          Number(g.max_piece) || 0,
          Number(g.max_character) || 0,
          Number(g.enabled) === 0 ? 0 : 1,
        ],
      );
    }

    for (const id of deleteAffectIds) {
      const aid = String(id).slice(0, 32);
      if (!aid) continue;
      await conn.query(`DELETE FROM listino_affect WHERE id = ?`, [aid]);
    }

    const seenLoc = new Set();
    const seenId = new Set();
    for (const row of affect) {
      const id = slugifyId(row.id);
      if (!id) throw new Error('affect senza id');
      if (seenId.has(id)) throw new Error(`affect id duplicato: ${id}`);
      seenId.add(id);
      const location = Number(row.location);
      if (!Number.isFinite(location) || location === 0) {
        throw new Error(`affect ${id}: location non valida`);
      }
      if (seenLoc.has(location)) {
        throw new Error(`affect location duplicata: ${location}`);
      }
      seenLoc.add(location);
      const capGroup = row.cap_group ? slugifyId(row.cap_group) : null;
      await conn.query(
        `INSERT INTO listino_affect
          (id, label, location, step, min_total, max_total, pos_unit_raw, neg_unit_raw,
           rune_num, rune_den, cap_group, enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           label = VALUES(label),
           location = VALUES(location),
           step = VALUES(step),
           min_total = VALUES(min_total),
           max_total = VALUES(max_total),
           pos_unit_raw = VALUES(pos_unit_raw),
           neg_unit_raw = VALUES(neg_unit_raw),
           rune_num = VALUES(rune_num),
           rune_den = VALUES(rune_den),
           cap_group = VALUES(cap_group),
           enabled = VALUES(enabled)`,
        [
          id,
          String(row.label || id).slice(0, 64),
          location,
          Number(row.step) || 1,
          Number(row.min_total) || 0,
          Number(row.max_total) || 0,
          Number(row.pos_unit_raw) || 0,
          Number(row.neg_unit_raw) || 0,
          Number(row.rune_num) || 0,
          Math.max(1, Number(row.rune_den) || 1),
          capGroup || null,
          Number(row.enabled) === 0 ? 0 : 1,
        ],
      );
    }

    for (const row of poolRows) {
      const fieldKey = slugifyId(row.field_key || row.id);
      if (!fieldKey) throw new Error('pool senza field_key');
      await conn.query(
        `INSERT INTO listino_pool
          (field_key, label, cap, step, unit_valore, xp_per_unit, rune_num, rune_den, enabled)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           label = VALUES(label),
           cap = VALUES(cap),
           step = VALUES(step),
           unit_valore = VALUES(unit_valore),
           xp_per_unit = VALUES(xp_per_unit),
           rune_num = VALUES(rune_num),
           rune_den = VALUES(rune_den),
           enabled = VALUES(enabled)`,
        [
          fieldKey,
          String(row.label || fieldKey).slice(0, 64),
          Number(row.cap) || 0,
          Number(row.step) || 1,
          Number(row.unit_valore) || 0,
          Number(row.xp_per_unit) || 0,
          Number(row.rune_num) || 0,
          Math.max(1, Number(row.rune_den) || 1),
          Number(row.enabled) === 0 ? 0 : 1,
        ],
      );
    }

    for (const row of params) {
      const key = String(row.param_key || row.key || '').slice(0, 64);
      if (!key) continue;
      const val = Number(row.param_value != null ? row.param_value : row.value);
      if (!Number.isFinite(val)) throw new Error(`param ${key}: valore non numerico`);
      await conn.query(
        `INSERT INTO listino_param (param_key, param_value) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE param_value = VALUES(param_value)`,
        [key, val],
      );
    }

    await bumpListinoRevision(conn, body.reason || 'staff-admin');
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }

  return fetchListinoSnapshot(pool);
}

/**
 * Costruisce entries kind=affect da listino + routing staff.
 * routingMap: { 'affect.damroll': { target, enabled }, ... }
 */
function buildAffectRoutingEntries(listinoSnap, routingMap = {}) {
  const out = [];
  for (const row of listinoSnap.affect || []) {
    const id = `affect.${row.id}`;
    const prev = routingMap[id] || routingMap[row.id] || {};
    out.push({
      id,
      kind: 'affect',
      location: Number(row.location),
      listino_id: row.id,
      label: row.label,
      step: Number(row.step),
      min_total: Number(row.min_total),
      max_total: Number(row.max_total),
      cap_group: row.cap_group || null,
      target: prev.target === 'character' ? 'character' : 'object',
      enabled:
        prev.enabled !== undefined
          ? !!prev.enabled
          : Number(row.enabled) !== 0,
    });
  }
  return out;
}

module.exports = {
  ensureListinoTables,
  fetchListinoSnapshot,
  bumpListinoRevision,
  saveListinoAdmin,
  buildAffectRoutingEntries,
  APPLY_CATALOG,
  SEED_TAG,
};
