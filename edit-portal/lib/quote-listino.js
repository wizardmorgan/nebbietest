'use strict';

/**
 * Quote locali da listino MySQL (fase A).
 * Allineato a EditAffectDeltaListinoCost / edit_pool_quote_paid / EditArtifactFlagListinoCost.
 * Non gestisce combat merge, bitfield immune, tetti dam/sp → caller fa fallback myst.
 */

const APPLY_AC = 17;
const APPLY_SPELLFAIL = 41;
const APPLY_HITNDAM = 40;
const APPLY_HITNSP = 66;
const APPLY_DAMROLL = 19;
const APPLY_SPELLPOWER = 65;
const APPLY_HITROLL = 18;

const COMBAT_LOCS = new Set([
  APPLY_HITNDAM,
  APPLY_HITNSP,
  APPLY_DAMROLL,
  APPLY_SPELLPOWER,
  APPLY_HITROLL,
]);

function paramsFromSnapshot(listinoSnap) {
  const out = {};
  for (const row of listinoSnap?.params || []) {
    out[row.param_key] = Number(row.param_value);
  }
  return out;
}

function paramNum(params, key, fallback) {
  const n = Number(params[key]);
  return Number.isFinite(n) ? n : fallback;
}

function classMultFromCount(nClasses, params) {
  const c = Number(nClasses || 1);
  if (c >= 3) return paramNum(params, 'class_mult_tri', 2);
  if (c === 2) return paramNum(params, 'class_mult_bi', 1.5);
  return 1;
}

function affectByLocation(listinoSnap, location) {
  const loc = Number(location);
  const rows = listinoSnap?.affect || [];
  return rows.find((r) => Number(r.location) === loc && Number(r.enabled) !== 0) || null;
}

function poolByField(listinoSnap, fieldKey) {
  const key = String(fieldKey || '');
  const rows = listinoSnap?.pool || [];
  return rows.find((r) => r.field_key === key && Number(r.enabled) !== 0) || null;
}

function affectSlotRaw(location, mod, spec) {
  const m = Number(mod);
  const pos = Number(spec.pos_unit_raw || 0);
  const neg = Number(spec.neg_unit_raw || 0);
  if (location === APPLY_AC || location === APPLY_SPELLFAIL) {
    return -m * pos;
  }
  if (m < 0) return m * neg;
  return m * pos;
}

/**
 * Come EditAffectDeltaListinoCost: raw × storage_scale × class_mult,
 * e × artifact_mult solo se applyArtifact (pezzo Artifact / pending in coda).
 */
function editAffectDeltaListinoCost(
  listinoSnap,
  location,
  deltaMod,
  nClasses,
  applyArtifact = false,
) {
  if (!deltaMod) return 0;
  const spec = affectByLocation(listinoSnap, location);
  if (!spec) return 0;
  const params = paramsFromSnapshot(listinoSnap);
  const raw = affectSlotRaw(location, deltaMod, spec);
  if (raw <= 0) return 0;
  const scale = paramNum(params, 'storage_scale', 10000);
  let scaled = raw * scale;
  const mult = classMultFromCount(nClasses, params);
  if (mult !== 1) scaled = Math.round(scaled * mult);
  if (applyArtifact && scaled > 0) {
    const art = paramNum(params, 'artifact_mult', 1.5);
    scaled = Math.round(scaled * art);
  }
  return Math.max(0, scaled);
}

function quoteXpJson(xpRaw, pq = 0) {
  const xp = Math.max(0, Math.floor(Number(xpRaw) || 0));
  const mega = Math.floor(xp / 1000000);
  const frac = Math.floor((xp % 1000000) / 10000);
  return {
    ok: true,
    xp_raw: xp,
    diff_xp_raw: xp,
    mxp: mega,
    mxp_frac: frac,
    pq: Math.max(0, Math.floor(Number(pq) || 0)),
    diff_rune: 0,
    quote_source: 'local_listino',
  };
}

function isMalusCurrent(location, current) {
  if (location === APPLY_AC || location === APPLY_SPELLFAIL) return current > 0;
  return current < 0;
}

function recoversMalus(location, current, target, clearSlot) {
  if (clearSlot) return false;
  if (!isMalusCurrent(location, current)) return false;
  if (location === APPLY_AC || location === APPLY_SPELLFAIL) return target < current;
  return target > current;
}

function crossesToBonus(location, current, target) {
  if (!isMalusCurrent(location, current)) return false;
  if (location === APPLY_AC || location === APPLY_SPELLFAIL) return target < 0;
  return target > 0;
}

/**
 * Quote Artifact flag (EditArtifactFlagListinoCost): raw × scale × class_mult, no artifact_mult.
 */
function quoteArtifact(listinoSnap, nClasses, current) {
  const params = paramsFromSnapshot(listinoSnap);
  const raw = paramNum(params, 'artifact_cost_raw', 10000);
  const scale = paramNum(params, 'storage_scale', 10000);
  const classes = Math.max(1, Number(nClasses) || 1);
  const mult = classMultFromCount(classes, params);
  const xpRaw = Math.round(raw * scale * mult);
  const q = quoteXpJson(xpRaw, 0);
  q.current = Number(current || 0);
  q.target = 1;
  q.n_classes = classes;
  q.class_mult = mult;
  q.apply_artifact = false;
  /* Nota UI: stesso schema "Dettaglio costo" del carrello (no jargon class_mult). */
  q.note = `Dettaglio costo: 100 × ${mult} (${classes >= 3 ? 'tri' : classes === 2 ? 'bi' : 'mono'})`;
  q.artifact_bundled = false;
  q.flag = 'artifact';
  return q;
}

/**
 * Quote pool come edit_pool_quote_paid.
 */
function quotePool(listinoSnap, fieldKey, units, nClasses) {
  const row = poolByField(listinoSnap, fieldKey);
  if (!row) return { ok: false, error: 'campo pool sconosciuto nel listino', fallback_myst: true };
  const u = Math.abs(Number(units) || 0);
  if (u <= 0) {
    const q = quoteXpJson(0, 0);
    q.payment_model = 'editpool';
    return q;
  }
  const params = paramsFromSnapshot(listinoSnap);
  const classes = Math.max(1, Number(nClasses) || 1);
  const mult = classMultFromCount(classes, params);
  const art = paramNum(params, 'artifact_mult', 1.5);
  const xpPerUnit = Number(row.xp_per_unit || 0);
  const runeNum = Number(row.rune_num || 0);
  const runeDen = Math.max(1, Number(row.rune_den || 1));
  const listinoXp = xpPerUnit * u;
  const listinoRune = (runeNum * u) / runeDen;
  const xpRaw = Math.max(0, Math.floor((listinoXp * art * mult) / classes));
  const pq = Math.max(0, Math.ceil(listinoRune * art * mult));
  const q = quoteXpJson(xpRaw, pq);
  q.pq = pq;
  q.payment_model = 'editpool';
  return q;
}

/**
 * Quote affect scalare. Ritorna fallback_myst se non gestibile in locale.
 */
function quoteAffectScalar(opts) {
  const {
    listinoSnap,
    location,
    current,
    targetModifier,
    clearSlot,
    allowCombatMerge,
    nClasses,
    flag,
    applyArtifact = false,
  } = opts;

  if (flag && flag !== 'artifact') {
    return { ok: false, error: 'flag non locale', fallback_myst: true };
  }
  if (flag === 'artifact') {
    if (clearSlot) return { ok: false, error: 'clear artifact via myst', fallback_myst: true };
    return quoteArtifact(listinoSnap, nClasses, current);
  }
  if (clearSlot) {
    return { ok: false, error: 'clear_slot via myst', fallback_myst: true };
  }
  const loc = Number(location);
  /* Hit-n-dam / Hit-n-sp e merge: canali effective solo su myst. */
  if (
    loc === APPLY_HITNDAM ||
    loc === APPLY_HITNSP ||
    (allowCombatMerge && COMBAT_LOCS.has(loc))
  ) {
    return { ok: false, error: 'combat combined/merge via myst', fallback_myst: true };
  }

  const cur = Number(current);
  const target = Number(targetModifier);
  const spec = affectByLocation(listinoSnap, loc);
  if (!spec) {
    return { ok: false, error: 'location non in listino', fallback_myst: true };
  }
  const withArt = !!applyArtifact;

  if (recoversMalus(loc, cur, target, false)) {
    if (crossesToBonus(loc, cur, target)) {
      const malusUnit = editAffectDeltaListinoCost(
        listinoSnap,
        loc,
        0 - cur,
        nClasses,
        withArt,
      );
      const malusXp = malusUnit > 0 ? malusUnit * 2 : 0;
      const bonusXp = editAffectDeltaListinoCost(
        listinoSnap,
        loc,
        target - 0,
        nClasses,
        withArt,
      );
      const total = malusXp + Math.max(0, bonusXp);
      const q = quoteXpJson(total, 0);
      q.current = cur;
      q.target = target;
      q.malus_split = 1;
      q.malus_part = { ...quoteXpJson(malusXp, 0), from: cur, to: 0 };
      q.bonus_part = { ...quoteXpJson(Math.max(0, bonusXp), 0), from: 0, to: target };
      return q;
    }
    const delta = target - cur;
    const unit = editAffectDeltaListinoCost(
      listinoSnap,
      loc,
      delta,
      nClasses,
      withArt,
    );
    const xp = unit > 0 ? unit * 2 : 0;
    const q = quoteXpJson(xp, 0);
    q.current = cur;
    q.target = target;
    q.recovered_malus = 1;
    return q;
  }

  const delta = target - cur;
  const xp = editAffectDeltaListinoCost(
    listinoSnap,
    loc,
    delta,
    nClasses,
    withArt,
  );
  const q = quoteXpJson(xp, 0);
  q.current = cur;
  q.target = target;
  const params = paramsFromSnapshot(listinoSnap);
  const classes = Math.max(1, Number(nClasses) || 1);
  const mult = classMultFromCount(classes, params);
  q.n_classes = classes;
  q.class_mult = mult;
  q.apply_artifact = withArt;
  q.delta = delta;
  /* Il carrello costruisce gia' "Dettaglio costo: …"; evita note duplicate/divergenti. */
  q.note = '';
  return q;
}

/**
 * Quote affect sul toon: listino affect x scale x class_mult x artifact sempre.
 * Pagamento modello editpool (XP + rune parallele da rune_num/den).
 */
function quoteCharAffect(listinoSnap, location, units, nClasses) {
  const u = Number(units) || 0;
  if (!u) {
    const q = quoteXpJson(0, 0);
    q.payment_model = 'editpool';
    return q;
  }
  const spec = affectByLocation(listinoSnap, location);
  if (!spec) {
    return { ok: false, error: 'location non in listino', fallback_myst: true };
  }
  const params = paramsFromSnapshot(listinoSnap);
  const classes = Math.max(1, Number(nClasses) || 1);
  const mult = classMultFromCount(classes, params);
  const art = paramNum(params, 'artifact_mult', 1.5);
  const scale = paramNum(params, 'storage_scale', 10000);
  const raw = affectSlotRaw(Number(location), u, spec);
  if (raw <= 0) {
    const q = quoteXpJson(0, 0);
    q.payment_model = 'editpool';
    return q;
  }
  let scaled = raw * scale;
  if (mult !== 1) scaled = Math.round(scaled * mult);
  scaled = Math.round(scaled * art);
  const runeNum = Number(spec.rune_num || 0);
  const runeDen = Math.max(1, Number(spec.rune_den || 1));
  let pq = 0;
  if (runeNum) {
    pq = Math.ceil(((Math.abs(u) * runeNum) / runeDen) * art * mult);
  }
  const q = quoteXpJson(scaled, pq);
  q.pq = pq;
  q.payment_model = 'editpool';
  q.cap_group = spec.cap_group || null;
  return q;
}

module.exports = {
  paramsFromSnapshot,
  classMultFromCount,
  quoteArtifact,
  quotePool,
  quoteAffectScalar,
  quoteCharAffect,
  editAffectDeltaListinoCost,
  APPLY_AC,
  APPLY_SPELLFAIL,
  COMBAT_LOCS,
};
