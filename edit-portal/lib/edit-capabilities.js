'use strict';

/**
 * Manifest capacita' edit da myst (/internal/edit-capabilities).
 * Solo i tender dichiarati possono pagare il listino; mix sempre valuta+rune.
 */

const DEFAULT_CAPS = Object.freeze({
  ready: false,
  tenders: [
    {
      id: 'xp',
      slug: 'mxp',
      label: 'MXP',
      api_field: 'pay_xp',
      is_rune: false,
      can_pay: true,
      mix_with_rune: true,
      object_mix: 'cover_xp',
      rune_per_mega_xp: 1000000,
      editpool_mix: 'parallel_pct',
    },
    {
      id: 'rune',
      slug: 'rune',
      label: 'Rune degli eroi',
      api_field: 'pay_rune',
      is_rune: true,
      can_pay: true,
      mix_with_rune: false,
    },
  ],
  apply_routes: [
    { kind: 'pool', path: '/internal/apply-pool', payment_model: 'editpool' },
    { kind: 'object_affect', path: '/internal/apply-affect', payment_model: 'object' },
    {
      kind: 'char_affect',
      path: '/internal/apply-char-affect',
      payment_model: 'editpool',
    },
    { kind: 'resistance', path: '/internal/apply-resistance', payment_model: 'object' },
  ],
  supported_pay_fields: ['pay_xp', 'pay_rune'],
  pq_per_mega_xp: 1000000,
  listino_revision: null,
  source: 'default',
});

let cache = {
  at: 0,
  fromMyst: false,
  data: { ...DEFAULT_CAPS, tenders: DEFAULT_CAPS.tenders.map((t) => ({ ...t })) },
};

const CACHE_TTL_MS = 30_000;

function normalizeCaps(raw) {
  const base = {
    ...DEFAULT_CAPS,
    tenders: DEFAULT_CAPS.tenders.map((t) => ({ ...t })),
    apply_routes: DEFAULT_CAPS.apply_routes.map((r) => ({ ...r })),
    supported_pay_fields: [...DEFAULT_CAPS.supported_pay_fields],
  };
  if (!raw || typeof raw !== 'object') return base;

  const tenders = Array.isArray(raw.tenders)
    ? raw.tenders
        .filter((t) => t && t.id && t.api_field)
        .map((t) => ({
          id: String(t.id),
          slug: String(t.slug || t.id),
          label: String(t.label || t.slug || t.id),
          api_field: String(t.api_field),
          is_rune: !!t.is_rune,
          can_pay: t.can_pay !== false,
          mix_with_rune: !!t.mix_with_rune,
          object_mix: t.object_mix ? String(t.object_mix) : null,
          editpool_mix: t.editpool_mix ? String(t.editpool_mix) : null,
          rune_per_mega_xp:
            t.rune_per_mega_xp != null ? Number(t.rune_per_mega_xp) : undefined,
        }))
    : base.tenders;

  const apply_routes = Array.isArray(raw.apply_routes)
    ? raw.apply_routes
        .filter((r) => r && r.path)
        .map((r) => ({
          kind: String(r.kind || ''),
          path: String(r.path),
          payment_model: String(r.payment_model || ''),
        }))
    : base.apply_routes;

  const fields = Array.isArray(raw.supported_pay_fields)
    ? raw.supported_pay_fields.map(String)
    : tenders.map((t) => t.api_field);

  return {
    ready: !!raw.ready,
    tenders,
    apply_routes,
    supported_pay_fields: fields,
    pq_per_mega_xp: Number(raw.pq_per_mega_xp || base.pq_per_mega_xp),
    listino_revision: raw.listino_revision != null ? raw.listino_revision : raw.seed_tag,
    affect_count: raw.affect_count,
    seed_tag: raw.seed_tag,
    broker_fee_percent: raw.broker_fee_percent,
    artifact_mult: raw.artifact_mult,
    artifact_cost_raw: raw.artifact_cost_raw,
    source: 'myst',
  };
}

function payableSlugSet(caps) {
  const set = new Set();
  for (const t of caps.tenders || []) {
    if (t.can_pay) set.add(t.slug);
  }
  return set;
}

function primaryTenders(caps) {
  return (caps.tenders || []).filter((t) => t.can_pay && !t.is_rune && t.mix_with_rune);
}

function runeTender(caps) {
  return (caps.tenders || []).find((t) => t.is_rune && t.can_pay) || null;
}

/**
 * @param {Function} mystPost - (path, body) => Promise<{ok, data, error}>
 * @param {{force?: boolean}} opts
 */
async function fetchCapabilities(mystPost, opts = {}) {
  const now = Date.now();
  if (!opts.force && cache.at && now - cache.at < CACHE_TTL_MS && cache.fromMyst) {
    return { ok: true, data: cache.data, cached: true };
  }
  try {
    const myst = await mystPost('/internal/edit-capabilities', {});
    if (!myst.ok) {
      /* Fallback: vecchio listino-status senza tenders. */
      const st = await mystPost('/internal/listino-status', {});
      if (st.ok && Array.isArray(st.data?.tenders)) {
        const data = normalizeCaps(st.data);
        cache = { at: now, fromMyst: true, data };
        return { ok: true, data, cached: false };
      }
      if (cache.fromMyst) {
        return { ok: true, data: cache.data, cached: true, stale: true };
      }
      return {
        ok: false,
        error: myst.error || 'edit-capabilities non disponibile',
        data: cache.data,
      };
    }
    const data = normalizeCaps(myst.data);
    cache = { at: now, fromMyst: true, data };
    return { ok: true, data, cached: false };
  } catch (err) {
    return {
      ok: false,
      error: err.message || String(err),
      data: cache.data,
    };
  }
}

function getCached() {
  return cache.data;
}

function invalidate() {
  cache.at = 0;
  cache.fromMyst = false;
}

/**
 * Blocca campi pay_* non supportati e path apply fuori manifest.
 * @returns {{ ok: true } | { ok: false, error: string }}
 */
function validateApplyStep(step, caps) {
  const c = caps || cache.data;
  const allowedPaths = new Set((c.apply_routes || []).map((r) => r.path));
  const payFields = new Set(c.supported_pay_fields || ['pay_xp', 'pay_rune']);
  const path = String(step.path || '');
  if (path.startsWith('/internal/lab-')) {
    return { ok: true };
  }
  if (!allowedPaths.has(path)) {
    return { ok: false, error: `route non supportata da myst: ${path}` };
  }
  const body = step.body && typeof step.body === 'object' ? step.body : {};
  for (const [key, val] of Object.entries(body)) {
    if (!key.startsWith('pay_')) continue;
    const n = Number(val || 0);
    if (!Number.isFinite(n) || n === 0) continue;
    if (!payFields.has(key)) {
      return {
        ok: false,
        error: `pagamento ${key} non supportato da myst (solo: ${[...payFields].join(', ')})`,
      };
    }
  }
  return { ok: true };
}

/**
 * Forza pays_listino=false sulle valute non dichiarate come tender pagabili.
 */
function clampCurrenciesPaysListino(currencies, caps) {
  const payable = payableSlugSet(caps || cache.data);
  const list = Array.isArray(currencies?.catalog)
    ? currencies.catalog
    : Array.isArray(currencies)
      ? currencies
      : null;
  if (!list) return currencies;
  const catalog = list.map((row) => {
    if (!row || !row.slug) return row;
    if (!payable.has(row.slug)) {
      return { ...row, pays_listino: false };
    }
    return row;
  });
  if (Array.isArray(currencies?.catalog) || (currencies && !Array.isArray(currencies))) {
    return { ...currencies, catalog };
  }
  return catalog;
}

module.exports = {
  DEFAULT_CAPS,
  fetchCapabilities,
  getCached,
  invalidate,
  normalizeCaps,
  payableSlugSet,
  primaryTenders,
  runeTender,
  validateApplyStep,
  clampCurrenciesPaysListino,
};
