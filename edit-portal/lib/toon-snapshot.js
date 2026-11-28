'use strict';

/**
 * Snapshot MySQL a select-toon: inventario + affects + pool + n_classes.
 * Serve alle quote locali (fase A) senza chiamare myst per ogni pezzo.
 */

async function countClasses(pool, toonId) {
  try {
    /* Allineato a myst class_count_for_toon / HowManyClasses: solo classi con level > 0.
     * Contare tutte le righe (anche level 0) gonfiava i triclasse verso class_mult_tri
     * oppure, con snapshot parziali, poteva dare 1. */
    const [rows] = await pool.query(
      'SELECT COUNT(*) AS c FROM character_classes WHERE toon_id = ? AND level > 0',
      [toonId],
    );
    return Math.max(1, Number(rows[0]?.c || 1));
  } catch {
    return 1;
  }
}

async function loadPool(pool, toonId) {
  try {
    const [rows] = await pool.query(
      `SELECT edit_hp, edit_mana, edit_move, edit_hp_regen, edit_mana_regen,
              edit_move_regen, overedit_hp, overedit_mana, overedit_move,
              overedit_hp_regen, overedit_mana_regen, overedit_move_regen,
              exp, p_rune_dei
       FROM character_stats WHERE toon_id = ? LIMIT 1`,
      [toonId],
    );
    if (!rows.length) return null;
    const r = rows[0];
    return {
      hit: Number(r.edit_hp || 0),
      mana: Number(r.edit_mana || 0),
      move: Number(r.edit_move || 0),
      hit_regen: Number(r.edit_hp_regen || 0),
      mana_regen: Number(r.edit_mana_regen || 0),
      move_regen: Number(r.edit_move_regen || 0),
      overedit_hit: Number(r.overedit_hp || 0),
      overedit_mana: Number(r.overedit_mana || 0),
      overedit_move: Number(r.overedit_move || 0),
      overedit_hit_regen: Number(r.overedit_hp_regen || 0),
      overedit_mana_regen: Number(r.overedit_mana_regen || 0),
      overedit_move_regen: Number(r.overedit_move_regen || 0),
      exp: Number(r.exp || 0),
      rune: Number(r.p_rune_dei || 0),
    };
  } catch {
    return null;
  }
}

function sumModsByLocation(affectRows) {
  const byLoc = {};
  for (const a of affectRows || []) {
    const loc = Number(a.location || 0);
    if (!loc) continue;
    byLoc[loc] = (byLoc[loc] || 0) + Number(a.modifier || 0);
  }
  return byLoc;
}

async function loadAffectsForInventoryIds(pool, inventoryIds) {
  const out = new Map();
  if (!inventoryIds.length) return out;
  const placeholders = inventoryIds.map(() => '?').join(',');
  try {
    const [rows] = await pool.query(
      `SELECT inventory_id, affect_slot, location, modifier
       FROM character_inventory_affect
       WHERE inventory_id IN (${placeholders})
       ORDER BY inventory_id, affect_slot`,
      inventoryIds,
    );
    for (const r of rows) {
      const id = Number(r.inventory_id);
      if (!out.has(id)) out.set(id, []);
      out.get(id).push({
        slot: Number(r.affect_slot),
        location: Number(r.location),
        modifier: Number(r.modifier),
      });
    }
  } catch {
    /* tabella assente: snapshot senza affects */
  }
  return out;
}

async function loadInstanceAffects(pool, instanceIds) {
  const out = new Map();
  if (!instanceIds.length) return out;
  const placeholders = instanceIds.map(() => '?').join(',');
  try {
    const [rows] = await pool.query(
      `SELECT key_instance_id, key_affect_slot, location, modifier
       FROM object_instance_affect
       WHERE key_instance_id IN (${placeholders})
       ORDER BY key_instance_id, key_affect_slot`,
      instanceIds,
    );
    for (const r of rows) {
      const id = Number(r.key_instance_id);
      if (!out.has(id)) out.set(id, []);
      out.get(id).push({
        slot: Number(r.key_affect_slot),
        location: Number(r.location),
        modifier: Number(r.modifier),
      });
    }
  } catch {
    /* ok */
  }
  return out;
}

/**
 * @returns {{
 *   toonId: number,
 *   n_classes: number,
 *   class_mult: number,
 *   pool: object|null,
 *   items: Array<object>,
 *   byInventoryId: Record<string, object>,
 *   source: string
 * }}
 */
async function fetchToonEditSnapshot(pool, toonId, listinoParams) {
  const nClasses = await countClasses(pool, toonId);
  const classMult =
    nClasses >= 3
      ? Number(listinoParams?.class_mult_tri ?? 2)
      : nClasses === 2
        ? Number(listinoParams?.class_mult_bi ?? 1.5)
        : 1;

  let invRows = [];
  try {
    const [rows] = await pool.query(
      `SELECT id, list_index, item_number, short_desc, obj_name, wear_pos, depth,
              parent_inventory_id, instance_id, extra_flags, extra_flags2, deleted
       FROM character_inventory WHERE toon_id = ? ORDER BY list_index`,
      [toonId],
    );
    invRows = rows.filter((r) => r.deleted === 0 || r.deleted == null);
  } catch {
    const [rows] = await pool.query(
      `SELECT id, list_index, item_number, short_desc, obj_name, wear_pos, depth,
              parent_inventory_id, instance_id, deleted
       FROM character_inventory WHERE toon_id = ? ORDER BY list_index`,
      [toonId],
    );
    invRows = rows.filter((r) => r.deleted === 0 || r.deleted == null);
  }

  const invIds = invRows.map((r) => Number(r.id));
  const instanceIds = invRows
    .map((r) => Number(r.instance_id || 0))
    .filter((id) => id > 0);
  const loadCharAffects = async () => {
    try {
      const [rows] = await pool.query(
        `SELECT location, value FROM character_edit_affect WHERE toon_id = ?`,
        [toonId],
      );
      return rows.map((r) => ({
        location: Number(r.location),
        value: Number(r.value),
      }));
    } catch {
      return [];
    }
  };

  const [invAffects, instAffects, editPool, charAffects] = await Promise.all([
    loadAffectsForInventoryIds(pool, invIds),
    loadInstanceAffects(pool, instanceIds),
    loadPool(pool, toonId),
    loadCharAffects(),
  ]);

  const items = invRows.map((r) => {
    const inventoryId = Number(r.id);
    const instanceId = Number(r.instance_id || 0);
    const affRows =
      instanceId > 0 && instAffects.has(instanceId)
        ? instAffects.get(instanceId)
        : invAffects.get(inventoryId) || [];
    const mods = sumModsByLocation(affRows);
    const extraFlags = Number(r.extra_flags || 0);
    const extraFlags2 = Number(r.extra_flags2 || 0);
    /* ITEM_IMMUNE = 262144 (autoenums): flag Artifact in gioco. */
    const ITEM_IMMUNE = 262144;
    return {
      inventory_id: inventoryId,
      list_index: r.list_index,
      item_number: r.item_number,
      short_desc: r.short_desc,
      name: r.obj_name,
      wear_pos: Number(r.wear_pos || 0),
      depth: Number(r.depth || 0),
      parent_inventory_id: r.parent_inventory_id,
      instance_id: instanceId || null,
      worn: Number(r.wear_pos || 0) > 0,
      extra_flags: extraFlags,
      extra_flags2: extraFlags2,
      has_artifact: (extraFlags & ITEM_IMMUNE) !== 0,
      affects: affRows,
      mods_by_location: mods,
    };
  });

  const byInventoryId = {};
  for (const it of items) {
    byInventoryId[String(it.inventory_id)] = it;
  }

  return {
    toonId: Number(toonId),
    n_classes: nClasses,
    class_mult: classMult,
    pool: editPool,
    char_affects: charAffects,
    items,
    byInventoryId,
    source: 'mysql',
  };
}

module.exports = {
  fetchToonEditSnapshot,
  countClasses,
  loadPool,
};
