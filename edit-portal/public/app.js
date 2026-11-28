'use strict';

const PQ_PER_MEGA_XP = 1000000;
const PRINCE_LEVEL = 51;
const LOGIN_STORAGE_KEY = 'nebbie-edit-login';
const INVENTORY_SORT_KEY = 'nebbie-edit-inventory-sort';
const TOOLS_OPEN_KEY = 'nebbie-edit-tools-open';
/** Bump insieme a index.html ?v= e a kEditPortalApiVersion (marker UI deploy). */
const EDIT_PORTAL_UI_BUILD = 101;
/** Keepalive sessione edit DB (TTL server, default 30 min). */
let editSessionTouchTimer = null;
/** Allineato a kLabExpCap in edit_portal.cpp (Lab set XP/Rune). */
const LAB_EXP_CAP = 2000000000;
const PRINCE_SORT_KEY = 'nebbie-edit-prince-sort';

/** Catalogo valute (staff). Solo visible+enabled compaiono in pagamento. */
let portalCurrencies = null;
/** Manifest myst: tender pagabili + route apply. */
let editCapabilities = null;

const DEFAULT_CURRENCIES = [
  { slug: 'mxp', label: 'MXP', enabled: true, visible: true, pays_listino: true },
  { slug: 'rune', label: 'Rune degli eroi', enabled: true, visible: true, pays_listino: true },
  { slug: 'gold', label: 'Gold', enabled: false, visible: false, pays_listino: false },
  { slug: 'token', label: 'Token', enabled: false, visible: false, pays_listino: false },
  { slug: 'credit', label: 'Credito edit', enabled: false, visible: false, pays_listino: false },
];

function normalizeCurrencies(raw) {
  const bySlug = new Map();
  DEFAULT_CURRENCIES.forEach((d) => bySlug.set(d.slug, { ...d }));
  const list = Array.isArray(raw?.catalog)
    ? raw.catalog
    : Array.isArray(raw)
      ? raw
      : [];
  list.forEach((row) => {
    if (!row || !row.slug) return;
    const prev = bySlug.get(row.slug) || {
      slug: row.slug,
      label: row.slug,
      enabled: false,
      visible: false,
      pays_listino: false,
    };
    bySlug.set(row.slug, {
      slug: row.slug,
      label: row.label != null && String(row.label).trim() ? String(row.label) : prev.label,
      enabled: row.enabled !== undefined ? !!row.enabled : prev.enabled,
      visible: row.visible !== undefined ? !!row.visible : prev.visible,
      pays_listino:
        row.pays_listino !== undefined ? !!row.pays_listino : prev.pays_listino,
    });
  });
  return [...bySlug.values()];
}

function currencyLabel(slug) {
  const list = portalCurrencies || DEFAULT_CURRENCIES;
  const row = list.find((c) => c.slug === slug);
  return row?.label || (slug === 'rune' ? 'Rune degli eroi' : slug === 'mxp' ? 'MXP' : slug);
}

function currencyVisibleEnabled(slug) {
  const list = portalCurrencies || DEFAULT_CURRENCIES;
  const row = list.find((c) => c.slug === slug);
  return !!(row && row.enabled && row.visible);
}

function payableTenderSlugs() {
  const caps = editCapabilities;
  if (!caps || !Array.isArray(caps.tenders)) {
    return new Set(['mxp', 'rune']);
  }
  return new Set(caps.tenders.filter((t) => t.can_pay !== false).map((t) => t.slug));
}

function primaryPayTenders() {
  const caps = editCapabilities;
  const tenders = Array.isArray(caps?.tenders) ? caps.tenders : [];
  const fromCaps = tenders.filter(
    (t) => t.can_pay !== false && !t.is_rune && t.mix_with_rune
  );
  if (fromCaps.length) return fromCaps;
  return [
    {
      id: 'xp',
      slug: 'mxp',
      label: currencyLabel('mxp'),
      api_field: 'pay_xp',
      mix_with_rune: true,
    },
  ];
}

/** % rune → mode legacy usato da buildPaymentPlan. */
function payModeFromRunePct(pct) {
  const n = Math.max(0, Math.min(100, Math.round(Number(pct) || 0)));
  if (n <= 0) return 'mxp';
  if (n >= 100) return 'runes';
  return 'mix';
}

function syncPayModeFromSlider() {
  const pct = Number($('pay-rune-pct')?.value || 0);
  const mode = payModeFromRunePct(pct);
  const payMode = $('pay-mode');
  if (payMode) payMode.value = mode;
  return mode;
}

async function loadEditCapabilities(force = false) {
  const q = force ? '?refresh=1' : '';
  const data = await api(`/api/edit-capabilities${q}`);
  if (data.ok && data.data) {
    editCapabilities = data.data;
    if (data.data.pq_per_mega_xp && editCatalog) {
      editCatalog.pq_per_mega_xp = data.data.pq_per_mega_xp;
    }
  } else if (!editCapabilities) {
    editCapabilities = {
      tenders: [
        {
          id: 'xp',
          slug: 'mxp',
          label: 'MXP',
          api_field: 'pay_xp',
          is_rune: false,
          can_pay: true,
          mix_with_rune: true,
        },
        {
          id: 'rune',
          slug: 'rune',
          label: 'Rune degli eroi',
          api_field: 'pay_rune',
          is_rune: true,
          can_pay: true,
        },
      ],
      supported_pay_fields: ['pay_xp', 'pay_rune'],
      source: 'fallback',
    };
  }
  rebuildPayTenderSelect();
  updateCapabilitiesStaffHint();
  return editCapabilities;
}

function rebuildPayTenderSelect() {
  const sel = $('pay-tender');
  if (!sel) return;
  const tenders = primaryPayTenders();
  const prev = sel.value;
  sel.innerHTML = '';
  tenders.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = t.id;
    opt.textContent = currencyLabel(t.slug) || t.label || t.id;
    opt.dataset.slug = t.slug;
    sel.appendChild(opt);
  });
  if ([...sel.options].some((o) => o.value === prev)) sel.value = prev;
  else if (sel.options.length) sel.selectedIndex = 0;
}

function updateCapabilitiesStaffHint() {
  const el = $('portal-capabilities-hint');
  if (!el) return;
  const caps = editCapabilities;
  if (!caps) {
    el.textContent = 'Capabilities myst: non caricate.';
    return;
  }
  const pay = (caps.tenders || [])
    .filter((t) => t.can_pay !== false)
    .map((t) => t.slug)
    .join(', ');
  const src = caps.source === 'myst' ? 'myst' : caps.source || '?';
  el.textContent = `Tender pagabili (${src}): ${pay || 'nessuno'}. Mix: ogni valuta non-rune solo con rune.`;
}


/** Prefisso reverse-proxy (es. "/edit"); da config.js o meta. */
function portalBasePath() {
  const fromCfg = window.EDIT_PORTAL_CONFIG?.basePath;
  if (typeof fromCfg === 'string') return fromCfg.replace(/\/+$/, '');
  const meta = document.querySelector('meta[name="edit-base"]');
  if (meta && meta.content) return String(meta.content).replace(/\/+$/, '');
  return '';
}

function portalUrl(path) {
  const base = portalBasePath();
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

function portalAuthConfig() {
  return window.EDIT_PORTAL_CONFIG || {};
}

/**
 * Mostra SSO e/o form password in base a config.js (EDIT_SSO_REQUIRED / ALLOW_PASSWORD).
 */
function applyLoginUiMode() {
  const cfg = portalAuthConfig();
  const ssoBlock = $('sso-login-block');
  const pwdBlock = $('password-login-block');
  const ssoLink = $('sso-wp-link');
  const ssoHint = $('sso-login-hint');
  const allowPassword = cfg.allowPasswordLogin !== false;
  const ssoRequired = cfg.ssoRequired === true;
  const wpEntry =
    cfg.wpSsoEntryUrl || cfg.wpLoginUrl || cfg.wpSiteUrl || '';

  if (ssoBlock) {
    if (ssoRequired || cfg.wordpressSsoConfigured) {
      ssoBlock.classList.remove('hidden');
      if (ssoLink) {
        if (wpEntry) {
          ssoLink.href = wpEntry;
          ssoLink.classList.remove('disabled');
        } else {
          ssoLink.href = '#';
          ssoLink.classList.add('disabled');
        }
      }
      if (ssoHint) {
        ssoHint.textContent = wpEntry
          ? 'Se sei già loggato sul sito verrai autenticato subito; altrimenti prima il login WordPress.'
          : 'SSO WordPress attivo sul server, ma EDIT_WP_SITE_URL non è impostato.';
      }
    } else {
      ssoBlock.classList.add('hidden');
    }
  }

  if (pwdBlock) {
    if (allowPassword) {
      pwdBlock.classList.remove('hidden');
      const email = $('login-email');
      const password = $('login-password');
      if (email) email.required = true;
      if (password) password.required = true;
    } else {
      pwdBlock.classList.add('hidden');
      const email = $('login-email');
      const password = $('login-password');
      if (email) email.required = false;
      if (password) password.required = false;
    }
  }
}

let session = null;
let targetToonId = null;
let charState = null;
let editCatalog = null;
let selectedInventoryId = null;
let selectedObjectOptions = null;
let pendingEdit = null;
/** Ultima lista inventario grezza (per ri-ordinare senza ricaricare). */
let inventoryItemsCache = [];
/** Coda edit oggetto corrente (stesso pezzo). */
let objectEditCart = new Map();
/** Generazione requote: evita che un requote async rimetta voci gia' tolte. */
let objectCartRequoteGen = 0;
/**
 * Carrelli oggetto per inventory_id: restano al cambio pezzo finche' non
 * «Applica tutto» / reset. Valore = Map(entryId -> item).
 */
let objectCartsByInv = new Map();
/** Cache options pezzo (evita re-fetch myst a ogni select). */
let objectOptionsCache = new Map();
/** Bozze name/short/long per pezzo (persiste al cambio oggetto). */
let objectTextDraftsByInv = new Map();
/** Snapshot listino MySQL (quote locali es. Artifact). */
let listinoSnapshot = null;
/** Snapshot inventario/affects/pool MySQL (fase A). */
let toonEditSnapshot = null;
/** Coda edit personaggio: più voci pool/resistenze insieme → somma costi. */
let characterEditCart = new Map();

const $ = (id) => document.getElementById(id);

function parseToonId(raw) {
  if (raw == null || raw === '') return 0;
  const s = String(raw).trim();
  if (/^\d+$/.test(s)) {
    try {
      const bi = BigInt(s);
      if (bi > 0 && bi <= BigInt(Number.MAX_SAFE_INTEGER)) return Number(bi);
    } catch {
      /* ignore */
    }
  }
  const n = Number(s);
  return Number.isSafeInteger(n) && n > 0 ? n : 0;
}

function getTargetToonId() {
  const fromSelect = parseToonId($('target-toon')?.value);
  if (fromSelect > 0) return fromSelect;
  // Staff: senza selezione esplicita non usare il toon di sessione (inventario staff inutile).
  if (session?.role === 'staff') return 0;
  return parseToonId(session?.sessionToonId || targetToonId || 0);
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Palette foreground DaleMUD / AlarMUD ($cMBFG, FG 00–15). */
const MUD_FG_COLORS = [
  '#000000', // 00 black
  '#aa0000', // 01 red
  '#00aa00', // 02 green
  '#aa5500', // 03 brown
  '#0000aa', // 04 blue
  '#aa00aa', // 05 magenta
  '#00aaaa', // 06 cyan
  '#aaaaaa', // 07 lt gray
  '#555555', // 08 dk gray
  '#ff5555', // 09 lt red
  '#55ff55', // 10 lt green
  '#ffff55', // 11 yellow
  '#5555ff', // 12 lt blue
  '#ff55ff', // 13 lt magenta
  '#55ffff', // 14 lt cyan
  '#ffffff', // 15 white
];

const MUD_BG_COLORS = [
  'transparent',
  '#aa0000',
  '#00aa00',
  '#aa5500',
  '#0000aa',
  '#aa00aa',
  '#00aaaa',
  '#aaaaaa',
];

/**
 * Converte `$cMBFG` / `$CMBFG` in HTML colorato (nasconde i codici).
 * M=mod, B=bg, FG=foreground 00-15 — vedi ansi_parser.cpp.
 * `$$` → `$` letterale, ma `$$cXXXX` = fine wrapper `$parola$` + codice colore
 * (non mostrare `$`). Wrapper `$parola$` isolati: i `$` non si vedono.
 */
function mudTextToHtml(raw) {
  const text = String(raw ?? '');
  if (!text) return '';
  if (!/\$[cC]\d{4}/.test(text) && !text.includes('$')) {
    return escapeHtml(text);
  }
  let html = '';
  let i = 0;
  let style = { color: 'var(--text)', bg: 'transparent', bold: false };
  const openSpan = () => {
    const parts = [`color:${style.color}`];
    if (style.bg && style.bg !== 'transparent') parts.push(`background-color:${style.bg}`);
    if (style.bold) parts.push('font-weight:700');
    return `<span class="mud-color" style="${parts.join(';')}">`;
  };
  let open = false;
  const close = () => {
    if (open) {
      html += '</span>';
      open = false;
    }
  };
  const isColorCodeAt = (idx) =>
    text[idx] === '$' &&
    (text[idx + 1] === 'c' || text[idx + 1] === 'C') &&
    /^\d{4}/.test(text.slice(idx + 2, idx + 6));
  while (i < text.length) {
    if (text[i] === '$' && text[i + 1] === '$') {
      if (isColorCodeAt(i + 1)) {
        /*
         * `$Vita$$c0007` → fine wrapper + colore: scarta un `$`, poi il
         * `$cXXXX`. Per un `$` letterale prima del colore usare `$$$cXXXX`.
         */
        i += 1;
        continue;
      }
      if (!open) {
        html += openSpan();
        open = true;
      }
      html += '$';
      i += 2;
      continue;
    }
    if (isColorCodeAt(i)) {
      const code = text.slice(i + 2, i + 6);
      const mod = code[0];
      const bg = Number(code[1]);
      const fg = Number(code.slice(2, 4));
      close();
      style = {
        color: MUD_FG_COLORS[fg] || 'var(--text)',
        bg: MUD_BG_COLORS[bg] || 'transparent',
        bold: mod === '1',
      };
      html += openSpan();
      open = true;
      i += 6;
      continue;
    }
    if (text[i] === '$') {
      /* Wrapper `$parola$` usato con i codici colore: non mostrare. */
      i += 1;
      continue;
    }
    if (!open) {
      html += openSpan();
      open = true;
    }
    let j = i;
    while (j < text.length && text[j] !== '$') j += 1;
    html += escapeHtml(text.slice(i, j));
    i = j;
  }
  close();
  return html;
}

function restoreSavedLogin() {
  try {
    const raw = localStorage.getItem(LOGIN_STORAGE_KEY);
    if (!raw) return;
    const saved = JSON.parse(raw);
    if (!saved?.remember) return;
    if (saved.email) $('login-email').value = saved.email;
    if (saved.password) $('login-password').value = saved.password;
    $('login-remember').checked = true;
  } catch {
    localStorage.removeItem(LOGIN_STORAGE_KEY);
  }
}

function persistLogin(email, password, remember) {
  if (!remember) {
    localStorage.removeItem(LOGIN_STORAGE_KEY);
    return;
  }
  localStorage.setItem(
    LOGIN_STORAGE_KEY,
    JSON.stringify({ remember: true, email, password }),
  );
}

async function api(path, opts = {}) {
  let res;
  try {
    res = await fetch(portalUrl(path), {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        ...(opts.headers || {}),
      },
    });
  } catch (err) {
    const msg = err && err.message ? String(err.message) : String(err);
    return {
      ok: false,
      error: /abort|timeout/i.test(msg)
        ? 'Timeout di rete verso il portale. Ricarica e verifica se l\'operazione e\' stata applicata.'
        : `Rete non raggiungibile: ${msg}`,
    };
  }
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    const raw = String(text || '');
    const pre = raw.match(/<pre[^>]*>([\s\S]*?)<\/pre>/i);
    const snippet = (pre ? pre[1] : raw)
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 160);
    return {
      ok: false,
      error: snippet
        ? `Risposta non JSON dal portale (HTTP ${res.status}): ${snippet}`
        : `Risposta vuota dal portale (HTTP ${res.status}). Riprova; se era un Lab XP/rune, ricarica lo stato del PG.`,
    };
  }
  if (!res.ok && data.ok === undefined) data.ok = false;
  return data;
}

function sleepMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Da result_json del job: payload myst reale (singolo apply) o wrapper batch.
 */
function mystFromJobResult(parsed) {
  if (!parsed || typeof parsed !== 'object') return null;
  if (parsed.myst && typeof parsed.myst === 'object') {
    const m = parsed.myst;
    if (
      m.data &&
      Array.isArray(m.data.steps) &&
      m.data.steps.length === 1 &&
      m.data.steps[0] &&
      m.data.steps[0].myst &&
      typeof m.data.steps[0].myst === 'object'
    ) {
      return m.data.steps[0].myst;
    }
    return m;
  }
  if (
    Array.isArray(parsed.steps) &&
    parsed.steps.length === 1 &&
    parsed.steps[0] &&
    parsed.steps[0].myst &&
    typeof parsed.steps[0].myst === 'object'
  ) {
    return parsed.steps[0].myst;
  }
  return null;
}

/**
 * Attende esito job myst_apply (B2). Restituisce il payload myst se presente.
 */
async function waitForJob(
  jobId,
  { timeoutMs = 120000, label = 'Salvataggio', statusEl = null } = {},
) {
  const t0 = Date.now();
  const el = statusEl || $('apply-result');
  while (Date.now() - t0 < timeoutMs) {
    if (el) {
      el.textContent = `${label} in corso (job #${jobId})… non chiudere la pagina.`;
      el.classList.remove('warn');
    }
    const data = await api(`/api/jobs/${jobId}`);
    if (!data.ok) {
      return { ok: false, error: data.error || 'job non leggibile' };
    }
    const job = data.job || {};
    if (job.status === 'done') {
      let parsed = {};
      try {
        parsed = job.result_json ? JSON.parse(job.result_json) : {};
      } catch {
        parsed = {};
      }
      const myst = mystFromJobResult(parsed);
      if (myst) {
        return { ...myst, jobId, async: true };
      }
      return { ok: true, data: parsed, jobId, async: true };
    }
    if (job.status === 'failed') {
      let parsed = {};
      try {
        parsed = job.result_json ? JSON.parse(job.result_json) : {};
      } catch {
        parsed = {};
      }
      const myst = mystFromJobResult(parsed);
      if (myst) {
        return {
          ...myst,
          ok: false,
          error: myst.error || job.error_message || 'apply fallito',
          jobId,
        };
      }
      return {
        ok: false,
        error: job.error_message || 'job fallito',
        jobId,
      };
    }
    await sleepMs(400);
  }
  return {
    ok: false,
    error:
      'Timeout in attesa del salvataggio. Se hai chiuso il browser, aspetta comunque qualche minuto prima di entrare in gioco.',
    jobId,
  };
}

/** POST apply/lab: se risponde con jobId, attende il worker. */
async function apiApply(path, body, label, opts = {}) {
  const enq = await api(path, { method: 'POST', body: JSON.stringify(body) });
  if (!enq.ok) return enq;
  if (enq.jobId) {
    return waitForJob(enq.jobId, {
      label: label || 'Salvataggio edit',
      statusEl: opts.statusEl || null,
    });
  }
  return enq;
}

function show(id) {
  $(id).classList.remove('hidden');
}
function hide(id) {
  $(id).classList.add('hidden');
}

function formatMxp(mxp, frac = 0) {
  if (!frac) return `${mxp} MXP`;
  return `${mxp},${String(frac).padStart(2, '0')} MXP`;
}

function quoteMxpFromRaw(xpRaw) {
  const mega = Math.floor(xpRaw / 1000000);
  const frac = Math.floor((xpRaw % 1000000) / 10000);
  return { mega, frac, raw: xpRaw };
}

function formatMxpFromQuote(q) {
  if (!q) return '0 MXP';
  return formatMxp(Number(q.mxp || 0), Number(q.mxp_frac || 0));
}

function canPayMxp() {
  return session && (session.role === 'staff' || Number(session.maxLevel || 0) >= PRINCE_LEVEL);
}

function buildPaymentPlan(quote, mode, runePct) {
  const xpRaw = Number(quote.xp_raw || quote.diff_xp_raw || 0);
  const runeListino = Number(quote.diff_rune || 0);
  const pqAlt = Number(quote.pq || 0);
  const runePerMega = Number(editCatalog?.pq_per_mega_xp || PQ_PER_MEGA_XP);
  const { mega, frac, raw } = quoteMxpFromRaw(xpRaw);
  /* Pool PG (editpool): pq = costo rune completo alternativo, non additivo. */
  const editpoolPay =
    quote.payment_model === 'editpool' ||
    (pqAlt > 0 && runeListino === 0 && quote.free_edit !== 1 && quote.free_edit !== true);

  let payXp = 0;
  let payRune = 0;

  if (Number(quote.free_edit) === 1 || quote.free_edit === true) {
    return {
      payXp: 0,
      payRune: 0,
      displayMxp: 'gratis',
      xpRaw: 0,
      runeListino: 0,
      editpoolPay: false,
    };
  }

  if (mode === 'mxp') {
    /* Slider rune a 0%: solo XP, nessuna rune (né listino né conversione). */
    payXp = raw;
    payRune = 0;
  } else if (mode === 'runes') {
    if (editpoolPay) {
      payXp = 0;
      payRune = pqAlt;
    } else {
      const runesFromMxp = raw > 0 ? Math.ceil(raw / runePerMega) : 0;
      payXp = 0;
      payRune = runesFromMxp + runeListino;
    }
  } else if (editpoolPay) {
    /* Misto come editpool ok misto: % su listino XP e % su listino rune. */
    const pctRune = Math.max(0, Math.min(100, Math.round(Number(runePct) || 0)));
    const pctXp = 100 - pctRune;
    payXp = Math.floor((raw * pctXp) / 100);
    payRune = Math.floor((pqAlt * pctRune) / 100);
  } else {
    /* Oggetti: % dello MXP convertito in rune; rune listino solo se % rune > 0. */
    const pctRune = Math.max(0, Math.min(100, Math.round(Number(runePct) || 0)));
    const runeMega = (mega * pctRune) / 100;
    const runeFrac = (frac * pctRune) / 100;
    const runeMegaTotal = runeMega + runeFrac / 100;
    const runesFromMxp = Math.ceil(runeMegaTotal);
    const xpCovered = runesFromMxp * runePerMega;
    payXp = Math.max(0, raw - xpCovered);
    payRune = (pctRune > 0 ? runeListino : 0) + runesFromMxp;
  }

  return {
    payXp,
    payRune,
    displayMxp: formatMxp(mega, frac),
    xpRaw,
    /* Solo le rune che si stanno davvero pagando, non il listino "alternativo". */
    runeListino: payRune,
    editpoolPay,
  };
}

/** Piano pagamento: in coda somma i piani per voce (editpool vs oggetti restano distinti). */
function buildPendingPaymentPlan(pending, mode, runePct) {
  const items = Array.isArray(pending?.items) ? pending.items : null;
  if (items && items.length) {
    let payXp = 0;
    let payRune = 0;
    let xpRaw = 0;
    let runeListino = 0;
    let anyEditpool = false;
    for (const it of items) {
      const p = buildPaymentPlan(it.quote || {}, mode, runePct);
      payXp += Number(p.payXp || 0);
      payRune += Number(p.payRune || 0);
      xpRaw += Number(p.xpRaw || 0);
      runeListino += Number(p.runeListino || 0);
      if (p.editpoolPay) anyEditpool = true;
    }
    const { mega, frac } = quoteMxpFromRaw(xpRaw);
    return {
      payXp,
      payRune,
      displayMxp: formatMxp(mega, frac),
      xpRaw,
      runeListino,
      editpoolPay: anyEditpool,
    };
  }
  return buildPaymentPlan(pending?.quote || {}, mode, runePct);
}

function formatQuoteCostShort(quote) {
  const xpRaw = Number(quote?.xp_raw || quote?.diff_xp_raw || 0);
  const rune = Number(quote?.diff_rune || quote?.pq || 0);
  const mxp = Math.floor(xpRaw / PQ_PER_MEGA_XP);
  const frac = Math.floor((xpRaw % PQ_PER_MEGA_XP) / 10000);
  const parts = [];
  if (xpRaw > 0) parts.push(formatMxp(mxp, frac));
  if (rune > 0) parts.push(`${rune} ${currencyLabel('rune')}`);
  if (!parts.length) parts.push('gratis');
  return parts.join(' + ');
}

function formatMxpRaw(xpRaw) {
  const raw = Math.max(0, Math.floor(Number(xpRaw) || 0));
  const { mega, frac } = quoteMxpFromRaw(raw);
  return formatMxp(mega, frac);
}

function mxpNumberString(xpRaw) {
  const raw = Math.max(0, Math.floor(Number(xpRaw) || 0));
  const { mega, frac } = quoteMxpFromRaw(raw);
  if (!frac) return String(mega);
  return `${mega},${String(frac).padStart(2, '0')}`;
}

function quoteNClasses(quote) {
  const n = Number(
    quote?.n_classes ||
      selectedObjectOptions?.owner_classes ||
      charState?.n_classes ||
      charState?.owner_classes ||
      1
  );
  return Math.max(1, Number.isFinite(n) && n > 0 ? Math.floor(n) : 1);
}

function quoteClassMultValue(quote, classes) {
  const m = Number(quote?.class_mult);
  if (Number.isFinite(m) && m > 0) return m;
  if (classes >= 3) return listinoParamNumber('class_mult_tri', 2);
  if (classes === 2) return listinoParamNumber('class_mult_bi', 1.5);
  return resolveListinoClassMult(selectedObjectOptions || charState || {});
}

function quoteIsEditpool(quote) {
  if (!quote) return false;
  if (quote.payment_model === 'editpool') return true;
  const pq = Number(quote.pq || 0);
  const runeListino = Number(quote.diff_rune || 0);
  return (
    pq > 0 &&
    runeListino === 0 &&
    quote.free_edit !== 1 &&
    quote.free_edit !== true
  );
}

function quoteAppliesArtifactMult(quote) {
  if (!quote) return false;
  if (quoteIsEditpool(quote)) return true;
  if (quote.apply_artifact != null) {
    return !!(Number(quote.apply_artifact) || quote.apply_artifact === true);
  }
  if (quote.artifact_bundled) return true;
  return !!(Number(quote.artifact) || Number(quote.pending_artifact));
}

/**
 * Note tecniche da quote locale/myst: non mostrarle a parte — il dettaglio
 * costo e' gia' in formatQuoteCostDetail (stesso testo ovunque).
 */
function isRedundantCostNote(note) {
  const n = String(note || '');
  if (!n) return true;
  if (/^Dettaglio costo:/i.test(n)) return true;
  if (/^Listino:\s*delta/i.test(n)) return true;
  if (/class_mult/i.test(n)) return true;
  if (/maggiorazione Artifact/i.test(n)) return true;
  if (/Include maggiorazione/i.test(n)) return true;
  if (/senza Artifact/i.test(n) && /listino/i.test(n)) return true;
  return false;
}

/**
 * Visualizzazione costi (formato editpool):
 * - riga principale = MXP che si addebitano (oggetti: totale listino×mult×art;
 *   pool: gia' ÷ n_classi come editpool)
 * - dettaglio = "Dettaglio costo: base × mult (bi|tri|mono) [× art (artifact)]"
 * Niente "per classe" fittizio sugli oggetti (fuorviante: si paga il totale).
 */
function quoteCostBreakdown(quote) {
  const xpRaw = Math.max(0, Math.floor(Number(quote?.xp_raw || quote?.diff_xp_raw || 0)));
  const rune = Math.max(0, Math.floor(Number(quote?.diff_rune || 0)));
  const pq = Math.max(0, Math.floor(Number(quote?.pq || 0)));
  const free =
    Number(quote?.free_edit) === 1 ||
    quote?.free_edit === true ||
    (xpRaw <= 0 && rune <= 0 && pq <= 0);
  if (free) {
    return {
      free: true,
      classes: quoteNClasses(quote),
      chargeRaw: 0,
      runeAlt: 0,
      pq: 0,
      editpool: quoteIsEditpool(quote),
    };
  }
  const classes = quoteNClasses(quote);
  const classMult = quoteClassMultValue(quote, classes);
  const artMult = listinoParamNumber('artifact_mult', 1.5);
  const editpool = quoteIsEditpool(quote);
  const withArt = quoteAppliesArtifactMult(quote);
  let chargeRaw;
  let baseRaw;
  if (editpool) {
    /* xp_raw = (listino x art x mult) / n_classes — cifra ufficiale editpool */
    chargeRaw = xpRaw;
    const productRaw = xpRaw * classes;
    const denom = artMult * classMult;
    baseRaw = denom > 0 ? Math.round(productRaw / denom) : productRaw;
  } else {
    /* oggetti: xp_raw = listino x mult [x art] — totale da addebitare */
    chargeRaw = xpRaw;
    let denom = classMult;
    if (withArt) denom *= artMult;
    baseRaw = denom > 0 ? Math.round(xpRaw / denom) : xpRaw;
  }
  return {
    free: false,
    editpool,
    classes,
    classMult,
    artMult,
    withArt,
    baseRaw,
    chargeRaw,
    runeAlt: editpool ? pq : 0,
    pq,
  };
}

function classCountWord(classes) {
  if (classes >= 3) return 'tri';
  if (classes === 2) return 'bi';
  return 'mono';
}

/** Fattori: "50 × 1.5 (bi) × 1.5 (artifact)" */
function formatCostFactors(b) {
  const bits = [
    mxpNumberString(b.baseRaw),
    `× ${b.classMult} (${classCountWord(b.classes)})`,
  ];
  if (b.withArt) bits.push(`× ${b.artMult} (artifact)`);
  return bits.join(' ');
}

/** Solo i fattori; l'importo in evidenza e' gia' l'addebito. */
function formatQuoteCostDetail(b) {
  if (!b || b.free) return '';
  let detail = `Dettaglio costo: ${formatCostFactors(b)}`;
  if (b.editpool && b.runeAlt > 0) {
    detail += ` · oppure ${b.runeAlt} ${currencyLabel('rune')}`;
  }
  return detail;
}

function formatQuoteCostCartHtml(quote) {
  const b = quoteCostBreakdown(quote);
  if (b.free) {
    return {
      html: '<span class="edit-cart-cost-main">gratis</span>',
      chargeRaw: 0,
      classes: b.classes,
      editpool: b.editpool,
    };
  }
  /* Importo = quanto si addebita (totale oggetti / cifra editpool sul pool). */
  const main = formatMxpRaw(b.chargeRaw);
  const detail = formatQuoteCostDetail(b);
  const html = detail
    ? `<span class="edit-cart-cost-main">${escapeHtml(main)}</span><span class="edit-cart-cost-detail">${escapeHtml(detail)}</span>`
    : `<span class="edit-cart-cost-main">${escapeHtml(main)}</span>`;
  return {
    html,
    chargeRaw: b.chargeRaw,
    classes: b.classes,
    editpool: b.editpool,
  };
}

function formatCartItemsTotalHtml(items) {
  let chargeRaw = 0;
  for (const it of items) {
    const b = quoteCostBreakdown(it.quote);
    chargeRaw += b.chargeRaw || 0;
  }
  const main = chargeRaw > 0 ? formatMxpRaw(chargeRaw) : 'gratis';
  const html = `<span class="edit-cart-cost-main">${escapeHtml(main)}</span>`;
  return { html, chargeRaw, main };
}

function isObjectPendingType(type) {
  return (
    type === 'object' ||
    type === 'object-batch' ||
    type === 'object-text' ||
    type === 'checkout-batch'
  );
}

function isCharacterPendingType(type) {
  return (
    type === 'pool' ||
    type === 'resistance' ||
    type === 'char-affect' ||
    type === 'character-batch' ||
    type === 'checkout-batch'
  );
}

function inventoryShortLabel(inventoryId) {
  const it = inventoryItemsCache.find(
    (row) => Number(row.inventory_id) === Number(inventoryId)
  );
  if (!it) return `pezzo #${inventoryId}`;
  return stripMudColorCodes(it.short_desc || it.name || `pezzo #${inventoryId}`);
}

function stashCurrentObjectCart() {
  if (!selectedInventoryId) return;
  const invId = Number(selectedInventoryId);
  if (objectEditCart.size) {
    objectCartsByInv.set(invId, new Map(objectEditCart));
  } else {
    objectCartsByInv.delete(invId);
  }
  const draft = getObjectTextDraft();
  if (draft && objectTextDraftIsDirty(draft)) {
    objectTextDraftsByInv.set(invId, { ...draft });
  } else if (!objectEditCart.size) {
    objectTextDraftsByInv.delete(invId);
  }
}

function restoreObjectCart(inventoryId) {
  const invId = Number(inventoryId);
  const saved = objectCartsByInv.get(invId);
  objectEditCart = saved ? new Map(saved) : new Map();
}

function clearAllObjectCarts({ resetSelectors = false } = {}) {
  objectCartRequoteGen += 1;
  if (resetSelectors) {
    objectEditCart.forEach((it) => {
      if (it.selectEl && it.selectEl.dataset.current != null) {
        it.selectEl.value = it.selectEl.dataset.current;
      }
    });
  }
  objectEditCart.clear();
  objectCartsByInv.clear();
  objectTextDraftsByInv.clear();
}

function collectGlobalCheckoutItems() {
  stashCurrentObjectCart();
  const items = [];
  for (const [invId, cart] of objectCartsByInv.entries()) {
    const piece = inventoryShortLabel(invId);
    const opts = objectOptionsCache.get(Number(invId));
    const entries = Array.isArray(opts?.entries) ? opts.entries : [];
    const artEntry = entries.find((e) => e.kind === 'flag' && e.flag === 'artifact');
    const alreadyArt = Number(artEntry?.current || 0) === 1;
    const useArt =
      alreadyArt ||
      [...cart.values()].some(
        (it) => it.flag === 'artifact' && Number(it.targetModifier) === 1
      );
    for (const it of cart.values()) {
      items.push({
        ...it,
        type: 'object',
        inventoryId: Number(invId),
        usesArtifactPricing: it.flag !== 'artifact' && useArt,
        label: `${piece}: ${it.label}`,
        pieceLabel: piece,
      });
    }
  }
  for (const it of characterEditCart.values()) {
    items.push({ ...it, pieceLabel: 'PG' });
  }
  return items;
}

function rebuildGlobalPendingFromCarts() {
  const items = collectGlobalCheckoutItems();
  if (!items.length) {
    pendingEdit = null;
    updateObjectCartUI();
    updateCharacterCartUI();
    updatePaymentUI();
    markInventoryQueued();
    return;
  }
  const totals = sumQuotes(items);
  const labels = items.map((it) => it.label);
  const notes = [];
  items.forEach((it) => {
    const n = String(it.quote?.note || '');
    if (n && !isRedundantCostNote(n)) notes.push(n);
  });
  const objCount = items.filter((it) => it.type === 'object' || it.inventoryId).length;
  const charCount = items.length - objCount;
  let note = notes.find((n) => /malus|rimuovi|spezzat|gratis|baseline/i.test(String(n)));
  if (!note && items.length > 1) {
    const parts = [];
    if (objCount) parts.push(`${objCount} edit oggetto`);
    if (charCount) parts.push(`${charCount} edit personaggio`);
    note = `${parts.join(' + ')} — un solo Applica tutto`;
  }
  pendingEdit = {
    type: 'checkout-batch',
    entryId: 'checkout-batch',
    label: labels.join('\n'),
    quote: { ...totals, note },
    items,
  };
  updateObjectCartUI();
  updateCharacterCartUI();
  updatePaymentUI();
  markInventoryQueued();
}

function markInventoryQueued() {
  const queued = new Set(
    [...objectCartsByInv.keys()].map((id) => Number(id)).filter((id) => {
      const cart = objectCartsByInv.get(id);
      return cart && cart.size > 0;
    })
  );
  if (selectedInventoryId && objectEditCart.size) {
    queued.add(Number(selectedInventoryId));
  }
  document.querySelectorAll('#inventory-list .item').forEach((li) => {
    const inv = Number(li.title?.match(/inventory_id (\d+)/)?.[1] || 0);
    /* title e' "inventory_id N" solo se editable — fallback via onclick closure non disponibile */
    li.classList.toggle('item-queued', false);
  });
  /* Usa cache inventario + dataset per marcare le li in ordine */
  const list = $('inventory-list');
  if (!list) return;
  const lis = [...list.querySelectorAll('.item')];
  const sorted = sortInventoryItems(inventoryItemsCache, getInventorySortMode());
  sorted.forEach((it, idx) => {
    const li = lis[idx];
    if (!li) return;
    li.classList.toggle(
      'item-queued',
      queued.has(Number(it.inventory_id))
    );
  });
}

function listinoParamNumber(key, fallback) {
  const rows = listinoSnapshot?.params;
  if (!Array.isArray(rows)) return fallback;
  const row = rows.find((r) => r.param_key === key);
  const n = row != null ? Number(row.param_value) : NaN;
  return Number.isFinite(n) ? n : fallback;
}

/** Metadati class_mult / artifact sulle quote oggetto (anche da myst). */
function enrichObjectQuoteMeta(qd, opts = {}) {
  if (!qd || typeof qd !== 'object') return qd;
  const classes = quoteNClasses(qd);
  if (qd.n_classes == null) qd.n_classes = classes;
  if (qd.class_mult == null) qd.class_mult = quoteClassMultValue(qd, classes);
  if (qd.apply_artifact == null) {
    const pending = !!(opts.pendingArtifact || opts.pending_artifact);
    qd.apply_artifact =
      pending ||
      objectAlreadyArtifact() ||
      !!Number(qd.artifact) ||
      !!Number(qd.pending_artifact)
        ? 1
        : 0;
  }
  return qd;
}

/** class_mult listino Artifact/affect: bi 1.5 / tri 2 (mai 1 se il PG e' bi/tri). */
function resolveListinoClassMult(opts) {
  const classes = Number(
    opts?.owner_classes || charState?.n_classes || charState?.owner_classes || 0
  );
  if (classes >= 3) return listinoParamNumber('class_mult_tri', 2);
  if (classes === 2) return listinoParamNumber('class_mult_bi', 1.5);
  const fromOpts = Number(opts?.class_mult);
  if (Number.isFinite(fromOpts) && fromOpts > 0) return fromOpts;
  const fromChar = Number(charState?.class_mult);
  if (Number.isFinite(fromChar) && fromChar > 0) return fromChar;
  return 1;
}

/**
 * Quote Artifact da solo: artifact_cost_raw * storage_scale * class_mult
 * (come EditArtifactFlagListinoCost). Mai artifact_mult su questa voce.
 */
function localArtifactQuote(opts, entry) {
  const raw = listinoParamNumber('artifact_cost_raw', 10000);
  const scale = listinoParamNumber('storage_scale', 10000);
  const classMult = resolveListinoClassMult(opts);
  const xpRaw = Math.round(raw * scale * classMult);
  return {
    xp_raw: xpRaw,
    diff_xp_raw: xpRaw,
    mxp: Math.floor(xpRaw / PQ_PER_MEGA_XP),
    mxp_frac: Math.floor((xpRaw % PQ_PER_MEGA_XP) / 10000),
    diff_rune: 0,
    current: Number(entry?.current || 0),
    target: 1,
    note: `Artifact da solo: ${Math.floor(
      xpRaw / PQ_PER_MEGA_XP
    )} MXP (100 x class_mult ${classMult}, senza +50%)`,
    artifact_bundled: false,
  };
}

/** Affect pagati in coda (escluso flag Artifact e clear gratis). */
function objectCartHasPaidNonArtifact(cart = objectEditCart) {
  return [...cart.values()].some((it) => {
    if (it.flag === 'artifact') return false;
    if (it.clearSlot) return false;
    const xp = Number(it.quote?.xp_raw || it.quote?.diff_xp_raw || 0);
    const rune = Number(it.quote?.diff_rune || it.quote?.pq || 0);
    return xp > 0 || rune > 0;
  });
}

/**
 * Regola portale (non broker): Artifact da solo = listino flag;
 * Artifact + altri edit sullo stesso pezzo = voce Artifact a 0 (il +50%
 * e' gia' nel listino affect / AnalyzeObjEditAgainst).
 */
function syncArtifactLineInCart(cart = objectEditCart) {
  let artKey = null;
  let art = null;
  for (const [k, it] of cart.entries()) {
    if (it.flag === 'artifact') {
      artKey = k;
      art = it;
      break;
    }
  }
  if (!art) return;
  const baseLabel = String(art.label || 'Artifact: No → Sì')
    .replace(/\s*\(pacchetto[^)]*\)/gi, '')
    .trim();
  if (objectCartHasPaidNonArtifact(cart)) {
    art.artifactBundled = true;
    art.quote = {
      xp_raw: 0,
      diff_xp_raw: 0,
      mxp: 0,
      mxp_frac: 0,
      diff_rune: 0,
      current: Number(art.quote?.current ?? art.entry?.current ?? 0),
      target: 1,
      note: 'Artifact in pacchetto: senza costo proprio; gli affect usano listino con +50%',
      artifact_bundled: true,
    };
    art.label = `${baseLabel} (pacchetto: gratis)`;
  } else {
    art.artifactBundled = false;
    art.quote = localArtifactQuote(selectedObjectOptions, art.entry);
    art.label = baseLabel;
  }
  cart.set(artKey, art);
}

async function ensureListinoSnapshot(force = false) {
  if (listinoSnapshot && !force) return listinoSnapshot;
  const data = await api('/api/listino');
  if (!data.ok) return null;
  listinoSnapshot = {
    affect: data.affect || [],
    pool: data.pool || [],
    params: data.params || [],
    meta: data.meta || [],
    cap_groups: data.cap_groups || [],
  };
  return listinoSnapshot;
}

function sumQuotes(items) {
  let xpRaw = 0;
  let rune = 0;
  items.forEach((it) => {
    /* Solo costi >= 0: niente crediti fantasma da quote stale. */
    const xp = Number(it.quote?.xp_raw || it.quote?.diff_xp_raw || 0);
    const r = Number(it.quote?.diff_rune || it.quote?.pq || 0);
    if (Number.isFinite(xp) && xp > 0) xpRaw += xp;
    if (Number.isFinite(r) && r > 0) rune += r;
  });
  return {
    xp_raw: xpRaw,
    mxp: Math.floor(xpRaw / PQ_PER_MEGA_XP),
    mxp_frac: Math.floor((xpRaw % PQ_PER_MEGA_XP) / 10000),
    diff_rune: rune,
  };
}

function renderEditCartBox(el, items, emptyHint) {
  if (!el) return;
  if (!items.length) {
    el.innerHTML = '';
    el.classList.add('hidden');
    return;
  }
  const rows = items
    .map((it) => {
      const cost = formatQuoteCostCartHtml(it.quote);
      return `<div class="edit-cart-line"><span class="edit-cart-label">${escapeHtml(
        it.label
      )}</span><span class="edit-cart-cost">${cost.html}</span></div>`;
    })
    .join('');
  const tot = formatCartItemsTotalHtml(items);
  el.innerHTML = `
    <div class="edit-cart-title">In coda (${items.length})</div>
    ${rows}
    <div class="edit-cart-total">Totale listino: <strong class="edit-cart-cost">${tot.html}</strong></div>
    <p class="hint edit-cart-hint">${escapeHtml(emptyHint || '')}</p>
  `;
  el.classList.remove('hidden');
}

function updateCharacterCartUI() {
  const items = [...characterEditCart.values()];
  renderEditCartBox(
    $('char-edit-cart'),
    items,
    'Costi aggiornati a ogni selettore. Paga dal pannello in basso.'
  );
  document
    .querySelectorAll('#pool-edits .edit-row, #resistance-edits .edit-row')
    .forEach((row) => {
      const key = row.dataset.cartKey;
      row.classList.toggle('edit-row--dirty', key && characterEditCart.has(key));
    });
}

function updateObjectCartUI() {
  const items = [...objectEditCart.values()];
  const otherPieces = [...objectCartsByInv.entries()].filter(
    ([id, cart]) => Number(id) !== Number(selectedInventoryId) && cart.size
  ).length;
  const hint =
    otherPieces > 0
      ? `Altri ${otherPieces} pezzi in coda globale. Un solo «Applica tutto» in basso.`
      : 'Coda pezzo corrente. Puoi cambiare oggetto e aggiungere altro prima di applicare.';
  renderEditCartBox($('object-edit-cart'), items, hint);
  document.querySelectorAll('#object-edits .edit-row').forEach((row) => {
    const key = row.dataset.cartKey;
    row.classList.toggle('edit-row--dirty', key && objectEditCart.has(key));
  });
}

function clearCharacterEditCart({ resetSelectors = false } = {}) {
  if (resetSelectors) {
    characterEditCart.forEach((it) => {
      if (it.selectEl && it.selectEl.dataset.current != null) {
        it.selectEl.value = it.selectEl.dataset.current;
      }
    });
  }
  characterEditCart.clear();
  rebuildGlobalPendingFromCarts();
}

function rebuildCharacterPendingFromCart() {
  rebuildGlobalPendingFromCarts();
}

/** Carrello globale: oggetto e personaggio possono stare nello stesso pacchetto. */
function ensureCharacterCartExclusive() {}
function ensureObjectCartExclusive() {}

function validatePayment(plan) {
  if (!charState) return { ok: false, reason: 'Stato PG non caricato' };
  if (charState.stats_missing) {
    return { ok: false, reason: 'character_stats assente: impossibile pagare edit' };
  }
  const availXp = Number(charState.available_xp || 0);
  const availRune = Number(charState.rune || 0);
  const okXp = plan.payXp <= availXp;
  const okRune = plan.payRune <= availRune;
  return {
    ok: okXp && okRune,
    okXp,
    okRune,
    availXp,
    availRune,
  };
}

function updatePaymentUI() {
  const panel = $('payment-panel');
  if (!pendingEdit || !charState) {
    hide('payment-panel');
    document.body.classList.remove('payment-dock-open');
    document.body.classList.remove('payment-insufficient');
    if ($('btn-pay-edit')) $('btn-pay-edit').disabled = true;
    if ($('btn-pay-edit-logout')) $('btn-pay-edit-logout').disabled = true;
    return;
  }
  show('payment-panel');
  document.body.classList.add('payment-dock-open');

  const runePct = Number($('pay-rune-pct').value);
  const mode = syncPayModeFromSlider();
  $('pay-rune-pct-label').textContent = `${runePct}%`;
  const runePctWrap = $('rune-pct-wrap');
  if (runePctWrap) runePctWrap.classList.remove('hidden');
  refreshPayModeLabels();

  const plan = buildPendingPaymentPlan(pendingEdit, mode, runePct);
  const check = validatePayment(plan);
  if (runePctWrap) {
    const tenderLab =
      $('pay-tender')?.selectedOptions?.[0]?.textContent || currencyLabel('mxp');
    const mixHint = plan.editpoolPay
      ? `% listino ${currencyLabel('rune')} (resto in ${tenderLab})`
      : `% copertura con ${currencyLabel('rune')} (resto in ${tenderLab})`;
    const first = runePctWrap.childNodes[0];
    if (first && first.nodeType === Node.TEXT_NODE) {
      first.textContent = `${mixHint} `;
    }
  }
  document.body.classList.toggle('payment-insufficient', !check.ok);
  panel.classList.toggle('payment-dock--insufficient', !check.ok);

  /* Artifact in pacchetto (costo 0): non mostrarlo come riga a pagamento. */
  const cartItems = Array.isArray(pendingEdit.items)
    ? pendingEdit.items.filter(
        (it) =>
          !(
            it.flag === 'artifact' &&
            (it.artifactBundled || it.quote?.artifact_bundled)
          )
      )
    : null;
  const lines = cartItems
    ? cartItems.map((it) => it.label)
    : String(pendingEdit.label || '')
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean);
  const queueCount = $('payment-queue-count');
  if (queueCount) {
    if (lines.length > 1) {
      queueCount.textContent = `${lines.length} in coda`;
      queueCount.classList.remove('hidden');
    } else {
      queueCount.textContent = '';
      queueCount.classList.add('hidden');
    }
  }

  const labelHtml = cartItems
    ? cartItems
        .map((it) => {
          const cost = formatQuoteCostCartHtml(it.quote);
          return `<div class="payment-cart-line"><span>${escapeHtml(
            it.label
          )}</span><span class="payment-cart-cost">${cost.html}</span></div>`;
        })
        .join('')
    : lines.map((line) => escapeHtml(line)).join('<br>');

  const cartTot = cartItems
    ? formatCartItemsTotalHtml(cartItems)
    : formatQuoteCostCartHtml(pendingEdit.quote || {});
  const listinoBlock = `<div class="payment-cost-line"><span class="payment-cost-label">Costo listino</span><div class="edit-cart-cost payment-cost-value">${
    cartTot.html || escapeHtml(plan.displayMxp)
  }</div></div>`;

  const specialNote =
    pendingEdit.quote?.note && !isRedundantCostNote(pendingEdit.quote.note)
      ? pendingEdit.quote.note
      : '';
  $('payment-summary').innerHTML = `
    <div class="payment-queue-list">${labelHtml}</div>
    ${listinoBlock}
    ${
      specialNote
        ? `<div class="slot-hint">${escapeHtml(specialNote)}</div>`
        : ''
    }
  `;

  const insuffHint = !check.ok
    ? `<div class="payment-insufficient-msg">Fondi insufficienti sul personaggio target${
        !check.okXp ? ' (XP/MXP)' : ''
      }${!check.okRune ? ` (${currencyLabel('rune')})` : ''}.</div>`
    : '';

  const payRunePart =
    Number(plan.payRune) > 0
      ? ` + <strong>${plan.payRune} ${currencyLabel('rune')}</strong>`
      : '';
  $('payment-breakdown').innerHTML = `
    <div class="payment-pay-line">
      Pagherai: <strong>${plan.payXp.toLocaleString('it-IT')} XP</strong>${payRunePart}
    </div>
    <div class="payment-avail-line">
      Disponibili: ${formatMxp(charState.available_mxp || 0, charState.available_mxp_frac || 0)}
      · ${charState.rune || 0} ${currencyLabel('rune')}
      · <span class="${check.okXp ? 'ok' : 'bad'}">MXP ${check.okXp ? 'OK' : 'insufficienti'}</span>
      · <span class="${check.okRune ? 'ok' : 'bad'}">${currencyLabel('rune')} ${check.okRune ? 'OK' : 'insufficienti'}</span>
    </div>
    ${insuffHint}
  `;

  $('btn-pay-edit').disabled = !check.ok;
  const btnLogout = $('btn-pay-edit-logout');
  if (btnLogout) btnLogout.disabled = !check.ok;
  pendingEdit.plan = plan;
}

async function refreshMe() {
  const me = await api('/api/me');
  if (!me.ok) {
    session = null;
    targetToonId = null;
    pendingEdit = null;
    clearAllObjectCarts();
    characterEditCart.clear();
    objectOptionsCache.clear();
    listinoSnapshot = null;
    toonEditSnapshot = null;
    document.body.classList.remove('payment-dock-open');
    document.body.classList.remove('payment-insufficient');
    applyLoginUiMode();
    if ($('header-meta')) {
      $('header-meta').textContent = `UI build ${EDIT_PORTAL_UI_BUILD}`;
    }
    if ($('toon-list')) $('toon-list').innerHTML = '';
    if ($('char-stats')) $('char-stats').textContent = '';
    if ($('apply-result')) $('apply-result').textContent = '';
    show('login-panel');
    hide('toon-panel');
    hide('work-panel');
    hide('payment-panel');
    hide('btn-logout');
    hide('btn-change-toon');
    return;
  }
  session = me;
  hide('login-panel');
  show('btn-logout');
  $('header-meta').textContent = me.email;
  if (me.sessionToonId) {
    show('btn-change-toon');
    await enterWorkMode();
  } else {
    hide('btn-change-toon');
    show('toon-panel');
    hide('work-panel');
    await loadToons();
  }
}

async function loadToons() {
  const box = $('toon-list');
  box.innerHTML = '<p class="hint">Caricamento riepilogo personaggi…</p>';
  const data = await api('/api/account-overview');
  box.innerHTML = '';
  if (!data.ok) {
    box.textContent = data.error || 'errore';
    const plain = await api('/api/toons');
    if (plain.ok) {
      plain.toons.forEach((t) => box.appendChild(makeToonSelectButton(t)));
    }
    return;
  }

  const princeLevel = Number(data.princeLevel || PRINCE_LEVEL);
  const under = [];
  const princes = [];
  const staffBand = [];
  (data.toons || []).forEach((t) => {
    const lv = Number(t.maxLevel) || 0;
    if (lv >= princeLevel + 1) staffBand.push(t);
    else if (lv >= princeLevel) princes.push(t);
    else under.push(t);
  });
  under.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'it'));
  staffBand.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'it'));

  const layout = document.createElement('div');
  layout.className = 'toon-overview-layout';

  const left = document.createElement('div');
  left.className = 'toon-overview-left';
  left.appendChild(makeStaffColumn(staffBand));
  left.appendChild(makeUnderColumn(under, princeLevel));
  layout.appendChild(left);

  const right = document.createElement('div');
  right.className = 'toon-overview-right';
  right.appendChild(makePrincesColumn(princes, princeLevel));
  layout.appendChild(right);

  box.appendChild(layout);
}

function makeStaffColumn(list) {
  const sec = document.createElement('section');
  sec.className = 'toon-band toon-band-staff';
  const h = document.createElement('h3');
  h.className = 'toon-band-title';
  h.textContent = `Staff (52+) (${list.length})`;
  sec.appendChild(h);
  if (!list.length) {
    const empty = document.createElement('p');
    empty.className = 'hint';
    empty.textContent = 'Nessun personaggio staff.';
    sec.appendChild(empty);
    return sec;
  }
  list.forEach((t) => sec.appendChild(makeStaffToonCard(t)));
  return sec;
}

function makeUnderColumn(list, princeLevel) {
  const sec = document.createElement('section');
  sec.className = 'toon-band toon-band-under';
  const h = document.createElement('h3');
  h.className = 'toon-band-title';
  h.textContent = `Sotto il ${princeLevel} (${list.length})`;
  sec.appendChild(h);
  if (!list.length) {
    const empty = document.createElement('p');
    empty.className = 'hint';
    empty.textContent = 'Nessun personaggio in questa fascia.';
    sec.appendChild(empty);
    return sec;
  }
  const wrap = document.createElement('div');
  wrap.className = 'toon-under-list';
  list.forEach((t) => wrap.appendChild(makeToonSelectButton(t)));
  sec.appendChild(wrap);
  return sec;
}

function makePrincesColumn(list, princeLevel) {
  const sec = document.createElement('section');
  sec.className = 'toon-band toon-band-princes';

  const head = document.createElement('div');
  head.className = 'toon-princes-head';
  const h = document.createElement('h3');
  h.className = 'toon-band-title';
  h.textContent = `Principi (livello ${princeLevel})`;
  head.appendChild(h);

  const sortLabel = document.createElement('label');
  sortLabel.className = 'prince-sort-label';
  sortLabel.innerHTML = 'Ordina ';
  const sortSel = document.createElement('select');
  sortSel.id = 'prince-sort';
  sortSel.innerHTML = `
    <option value="alpha">Alfabetico (A→Z)</option>
    <option value="mxp">MXP disponibili</option>
    <option value="clan">Simbolo del clan</option>
  `;
  let saved = 'alpha';
  try {
    saved = localStorage.getItem(PRINCE_SORT_KEY) || 'alpha';
  } catch (_) {
    /* ignore */
  }
  if (![...sortSel.options].some((o) => o.value === saved)) saved = 'alpha';
  sortSel.value = saved;
  sortLabel.appendChild(sortSel);
  head.appendChild(sortLabel);
  sec.appendChild(head);

  const countHint = document.createElement('p');
  countHint.className = 'hint prince-count-hint';
  sec.appendChild(countHint);

  const listBox = document.createElement('div');
  listBox.className = 'prince-cards';
  sec.appendChild(listBox);

  const render = () => {
    const mode = sortSel.value || 'alpha';
    try {
      localStorage.setItem(PRINCE_SORT_KEY, mode);
    } catch (_) {
      /* ignore */
    }
    const sorted = sortPrinceToons(list.slice(), mode);
    countHint.textContent = `${sorted.length} personaggi`;
    listBox.innerHTML = '';
    if (!sorted.length) {
      const empty = document.createElement('p');
      empty.className = 'hint';
      empty.textContent = 'Nessun principe in questa fascia.';
      listBox.appendChild(empty);
      return;
    }
    sorted.forEach((t) => listBox.appendChild(makePrinceToonCard(t)));
  };
  sortSel.onchange = render;
  render();
  return sec;
}

function toonAvailableMxp(t) {
  const s = t.summary || {};
  const whole = Number(s.available_mxp);
  if (Number.isFinite(whole)) return whole;
  return 0;
}

function toonHasClan(t) {
  return !!(t.summary && t.summary.clan_symbol && t.summary.clan_symbol.present);
}

function sortPrinceToons(list, mode) {
  const byName = (a, b) =>
    String(a.name || '').localeCompare(String(b.name || ''), 'it', {
      sensitivity: 'base',
    });
  if (mode === 'mxp') {
    list.sort((a, b) => {
      const d = toonAvailableMxp(b) - toonAvailableMxp(a);
      return d !== 0 ? d : byName(a, b);
    });
  } else if (mode === 'clan') {
    list.sort((a, b) => {
      const ca = toonHasClan(a) ? 1 : 0;
      const cb = toonHasClan(b) ? 1 : 0;
      if (ca !== cb) return cb - ca;
      return byName(a, b);
    });
  } else {
    list.sort(byName);
  }
  return list;
}

function makeToonSelectButton(t) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'toon-pick-btn';
  btn.textContent = `${t.name} — livello ${t.maxLevel}, ruolo ${t.role}`;
  btn.onclick = () => selectAccountToon(t.id);
  return btn;
}

function ynMark(ok) {
  return ok
    ? '<span class="ov-yes">sì</span>'
    : '<span class="ov-no">no</span>';
}

function resistLine(label, entry) {
  const e =
    entry && typeof entry === 'object' && !Array.isArray(entry)
      ? entry
      : { present: !!entry, origin_label: '' };
  const present = !!e.present;
  const origin = present && e.origin_label
    ? ` <span class="ov-origin">(${escapeHtml(e.origin_label)})</span>`
    : '';
  return `<li>${escapeHtml(label)} ${ynMark(present)}${origin}</li>`;
}

function meterLine(label, used, cap, remaining, remainWord = 'ancora') {
  const u = Number(used) || 0;
  const c = Number(cap) || 0;
  const r = remaining != null ? Number(remaining) : Math.max(0, c - u);
  return `<div class="ov-meter"><span class="ov-meter-label">${escapeHtml(label)}</span>` +
    `<strong>${u}/${c}</strong><span class="ov-remain">${escapeHtml(remainWord)} ${r}</span></div>`;
}

function meterLineWithNote(label, entry) {
  const line = meterLine(label, entry?.used, entry?.cap, entry?.remaining);
  const note = entry?.note
    ? `<div class="ov-meter-note">${escapeHtml(entry.note)}</div>`
    : '';
  return line + note;
}

/** Riepilogo DAM+SP: tetto condiviso 30 (non 30+30). */
function damSpOverviewMeters(main) {
  const shared = main?.dam_sp;
  const dam = main?.dam || {};
  const sp = main?.spellpower || {};
  if (shared && shared.cap != null) {
    const used = Number(shared.used) || 0;
    const cap = Number(shared.cap) || 0;
    const rem =
      shared.remaining != null ? Number(shared.remaining) : Math.max(0, cap - used);
    const damU =
      shared.dam_used != null ? Number(shared.dam_used) : Number(dam.used) || 0;
    const spU =
      shared.sp_used != null ? Number(shared.sp_used) : Number(sp.used) || 0;
    const note = shared.note
      ? `<div class="ov-meter-note">${escapeHtml(shared.note)}</div>`
      : '';
    return (
      meterLine('DAM+SP editato', used, cap, rem) +
      `<div class="ov-meter-note">di cui Dam ${damU} · Spellpower ${spU}</div>` +
      note
    );
  }
  /* Fallback API vecchia: ricalcola remaining sul pool condiviso. */
  const damU = Number(dam.used) || 0;
  const spU = Number(sp.used) || 0;
  const cap = Number(dam.cap || sp.cap || 30) || 30;
  const used = damU + spU;
  const rem = Math.max(0, cap - used);
  return (
    meterLine('DAM+SP editato', used, cap, rem) +
    `<div class="ov-meter-note">di cui Dam ${damU} · Spellpower ${spU} (tetto condiviso)</div>`
  );
}

function isToolsColumnOpen() {
  return localStorage.getItem(TOOLS_OPEN_KEY) === '1';
}

function syncToolsColumnUI() {
  const layout = $('work-layout');
  const col = $('tools-column');
  const btn = $('btn-toggle-tools');
  if (!layout || !col) return;
  const open = isToolsColumnOpen();
  layout.classList.toggle('layout--tools-open', open);
  col.classList.toggle('hidden', !open);
  if (btn) {
    btn.classList.toggle('btn-active', open);
    btn.setAttribute('aria-pressed', open ? 'true' : 'false');
    btn.textContent = open ? 'Nascondi colonna' : 'Opzioni sistema';
  }
}

function setToolsColumnOpen(open) {
  localStorage.setItem(TOOLS_OPEN_KEY, open ? '1' : '0');
  syncToolsColumnUI();
}

function initStaffToolsColumn() {
  show('btn-toggle-tools');
  show('staff-view-wrap');
  syncToolsColumnUI();
  const sel = $('staff-view-select');
  if (sel && !sel.dataset.bound) {
    sel.dataset.bound = '1';
    sel.addEventListener('change', () => setStaffView(sel.value));
  }
  document.querySelectorAll('.staff-economy-tab').forEach((btn) => {
    if (btn.dataset.bound) return;
    btn.dataset.bound = '1';
    btn.addEventListener('click', () => setEconomyTab(btn.dataset.econTab));
  });
  setStaffView(sel?.value || 'edit');
}

function hideStaffToolsColumn() {
  hide('btn-toggle-tools');
  hide('staff-view-wrap');
  hide('tools-column');
  hide('staff-economy-page');
  $('work-layout')?.classList.remove('layout--tools-open');
  $('work-layout')?.classList.remove('work-layout-economy-hidden');
}

function setEconomyTab(tab) {
  const want = tab === 'listino' ? 'listino' : 'currencies';
  document.querySelectorAll('.staff-economy-tab').forEach((btn) => {
    const on = btn.dataset.econTab === want;
    btn.classList.toggle('is-active', on);
    btn.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  $('staff-econ-currencies')?.classList.toggle('hidden', want !== 'currencies');
  $('staff-econ-listino')?.classList.toggle('hidden', want !== 'listino');
  if (want === 'listino' && !listinoAdminState) {
    loadListinoAdmin().catch(() => {});
  }
}

function setStaffView(view) {
  const v = view === 'economy' || view === 'ops' ? view : 'edit';
  const sel = $('staff-view-select');
  if (sel && sel.value !== v) sel.value = v;

  const economy = $('staff-economy-page');
  const layout = $('work-layout');
  const toolsBtn = $('btn-toggle-tools');

  if (v === 'economy') {
    show('staff-economy-page');
    layout?.classList.add('work-layout-economy-hidden');
    hide('tools-column');
    layout?.classList.remove('layout--tools-open');
    if (toolsBtn) toolsBtn.classList.add('hidden');
    setEconomyTab(
      document.querySelector('.staff-economy-tab.is-active')?.dataset.econTab ||
        'currencies',
    );
    return;
  }

  hide('staff-economy-page');
  layout?.classList.remove('work-layout-economy-hidden');
  if (toolsBtn) toolsBtn.classList.remove('hidden');

  if (v === 'ops') {
    setToolsColumnOpen(true);
  } else {
    syncToolsColumnUI();
  }
}

function syncLabPanelVisibility(me) {
  const labOn = !!(me && (me.labEnabled || Number(me.maxLevel || 0) >= Number(me.labLevel || 58)));
  if (labOn) {
    show('lab-panel');
    show('lab-clone-hint');
  } else {
    hide('lab-panel');
    hide('lab-clone-hint');
  }
  refreshLabTargetStats();
}

const PRINCE_EXP_RESERVE = 400000000;
let labSelectedObj = null;
let labObjSearchTimer = null;

function labPrinceReserveForTarget() {
  const lvl = Number(charState?.max_level || 0);
  return lvl >= PRINCE_LEVEL ? PRINCE_EXP_RESERVE : 0;
}

function formatLabMxp(availableXp) {
  const v = Math.max(0, Number(availableXp) || 0);
  const mega = Math.floor(v / 1000000);
  const frac = Math.floor((v % 1000000) / 10000);
  return `${mega},${String(frac).padStart(2, '0')} MXP`;
}

function refreshLabTargetStats() {
  const el = $('lab-target-stats');
  if (!el) return;
  const tid = getTargetToonId();
  if (!tid) {
    el.textContent = 'Seleziona un target per vedere XP/Rune.';
    updateLabStatPreviews();
    return;
  }
  const s = charState;
  if (!s) {
    el.textContent = `Target #${tid}: carica lo stato PG per vedere XP/Rune.`;
    updateLabStatPreviews();
    return;
  }
  const exp = s.exp != null ? s.exp : '(n/d)';
  const rune = s.rune != null ? s.rune : '(n/d)';
  const reserve = labPrinceReserveForTarget();
  const avail = s.exp != null ? Math.max(0, Number(s.exp) - reserve) : 0;
  el.textContent =
    `Target #${tid} ${s.name || ''}: XP ${exp} · Rune ${rune}` +
    (s.exp != null ? ` · editabili ora ${formatLabMxp(avail)}` : '');
  if ($('lab-exp') && ( $('lab-exp').value === '' || $('lab-exp').value == null) && s.exp != null) {
    $('lab-exp').placeholder = String(s.exp);
  }
  if ($('lab-rune') && ($('lab-rune').value === '' || $('lab-rune').value == null) && s.rune != null) {
    $('lab-rune').placeholder = String(s.rune);
  }
  updateLabStatPreviews();
}

/** Anteprima live: XP/Rune disponibili per edit dopo il valore digitato. */
function updateLabStatPreviews() {
  const expPrev = $('lab-exp-preview');
  const runePrev = $('lab-rune-preview');
  const reserve = labPrinceReserveForTarget();
  const expRaw = $('lab-exp')?.value;
  if (expPrev) {
    if (expRaw === '' || expRaw == null) {
      const cur = charState?.exp;
      if (cur == null) {
        expPrev.textContent = 'Disponibili per edit: —';
      } else {
        const avail = Math.max(0, Number(cur) - reserve);
        expPrev.textContent =
          `Disponibili per edit (attuale): -${avail.toLocaleString('it-IT')} XP` +
          ` (${formatLabMxp(avail)})`;
      }
    } else {
      const exp = Number(expRaw);
      if (!Number.isFinite(exp) || exp < 0) {
        expPrev.textContent = 'Disponibili per edit: valore non valido';
      } else {
        const avail = Math.max(0, exp - reserve);
        const note =
          reserve > 0
            ? ` (riserva principi ${reserve.toLocaleString('it-IT')} XP)`
            : '';
        expPrev.textContent =
          `Disponibili per edit: -${avail.toLocaleString('it-IT')} XP` +
          ` (${formatLabMxp(avail)})${note}`;
      }
    }
  }
  if (runePrev) {
    const runeRaw = $('lab-rune')?.value;
    if (runeRaw === '' || runeRaw == null) {
      const cur = charState?.rune;
      runePrev.textContent =
        cur == null
          ? 'Rune disponibili per edit: —'
          : `Rune disponibili per edit (attuale): ${Number(cur).toLocaleString('it-IT')}`;
    } else {
      const rune = Number(runeRaw);
      runePrev.textContent =
        !Number.isFinite(rune) || rune < 0
          ? 'Rune disponibili per edit: valore non valido'
          : `Rune disponibili per edit: ${rune.toLocaleString('it-IT')}`;
    }
  }
}

function labResult(msg, { isError = false } = {}) {
  const el = $('lab-result');
  if (!el) return;
  el.textContent = msg || '';
  el.classList.toggle('warn', !!isError);
  if (msg) {
    try {
      el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    } catch {
      /* ignore */
    }
  }
}

function renderLabObjSelected() {
  const el = $('lab-obj-selected');
  if (!el) return;
  if (!labSelectedObj) {
    el.textContent = 'Nessun oggetto selezionato.';
    return;
  }
  el.textContent = `Selezionato: #${labSelectedObj.vnum} ${labSelectedObj.short_desc || labSelectedObj.name || ''}`;
}

async function labSearchObjects(q) {
  const list = $('lab-obj-results');
  if (!list) return;
  list.innerHTML = '';
  if (!q || q.length < 2) return;
  const data = await api(`/api/lab/search-objects?q=${encodeURIComponent(q)}`);
  if (!data.ok) {
    labResult(data.error || 'ricerca oggetti fallita');
    return;
  }
  const rows = data.data?.results || [];
  if (!rows.length) {
    const li = document.createElement('li');
    li.className = 'hint';
    li.textContent = 'Nessun oggetto trovato';
    list.appendChild(li);
    return;
  }
  rows.forEach((r) => {
    const li = document.createElement('li');
    li.className = 'lab-obj-item';
    const label = `${r.short_desc || r.name || '(senza nome)'} · vnum ${r.vnum}`;
    li.innerHTML = `<button type="button" class="linkish">${escapeHtml(label)}</button>`;
    const btn = li.querySelector('button');
    btn.onclick = () => {
      labSelectedObj = {
        vnum: Number(r.vnum),
        name: r.name || '',
        short_desc: r.short_desc || '',
      };
      renderLabObjSelected();
      list.innerHTML = '';
      if ($('lab-obj-search')) $('lab-obj-search').value = r.name || r.short_desc || '';
    };
    list.appendChild(li);
  });
}

async function labSetStats() {
  const tid = getTargetToonId();
  if (!tid) {
    labResult('Seleziona un personaggio target', { isError: true });
    return;
  }
  const body = { targetToonId: tid };
  const exp = $('lab-exp')?.value;
  const rune = $('lab-rune')?.value;
  if (exp !== '' && exp != null) body.exp = Number(exp);
  if (rune !== '' && rune != null) body.rune = Number(rune);
  if (body.exp == null && body.rune == null) {
    labResult('Compila XP e/o Rune', { isError: true });
    return;
  }
  if (body.exp != null && (!Number.isFinite(body.exp) || body.exp < 0)) {
    labResult('XP non valido', { isError: true });
    return;
  }
  if (body.exp != null && body.exp > LAB_EXP_CAP) {
    labResult(
      `XP fuori range: richiesto ${body.exp}, massimo ${LAB_EXP_CAP}`,
      { isError: true },
    );
    return;
  }
  if (body.rune != null && (!Number.isFinite(body.rune) || body.rune < 0)) {
    labResult('Rune non valide', { isError: true });
    return;
  }
  if (body.rune != null && body.rune > LAB_EXP_CAP) {
    labResult(
      `Rune fuori range: richiesto ${body.rune}, massimo ${LAB_EXP_CAP}`,
      { isError: true },
    );
    return;
  }
  labResult('Applicazione XP/Rune…');
  try {
    const data = await apiApply('/api/lab/set-stats', body, 'Lab XP/Rune', {
      statusEl: $('lab-result'),
    });
    if (!data.ok) {
      const err = data.error || 'errore lab set-stats';
      labResult(err, { isError: true });
      window.alert(err);
      return;
    }
    const expOut = data.data?.exp;
    const runeOut = data.data?.rune;
    labResult(
      `OK — XP ${expOut != null ? Number(expOut).toLocaleString('it-IT') : '?'} · Rune ${
        runeOut != null ? Number(runeOut).toLocaleString('it-IT') : '?'
      }`,
    );
    if ($('lab-exp')) $('lab-exp').value = '';
    if ($('lab-rune')) $('lab-rune').value = '';
    await loadCharacterState();
    refreshLabTargetStats();
  } catch (err) {
    const msg = err && err.message ? String(err.message) : String(err);
    labResult(msg, { isError: true });
    window.alert(msg);
  }
}

async function labGiveVnum() {
  const tid = getTargetToonId();
  if (!tid) {
    labResult('Seleziona un personaggio target');
    return;
  }
  const vnum = Number(labSelectedObj?.vnum);
  const qty = Number($('lab-qty')?.value || 1);
  if (!Number.isFinite(vnum) || vnum <= 0) {
    labResult('Seleziona un oggetto dalla ricerca');
    return;
  }
  labResult(`Carico vnum ${vnum} x${qty}…`);
  const data = await apiApply(
    '/api/lab/give-vnum',
    { targetToonId: tid, vnum, qty },
    'Lab dai oggetto',
    { statusEl: $('lab-result') },
  );
  if (!data.ok) {
    const err = data.error || 'errore lab give-vnum';
    labResult(err, { isError: true });
    window.alert(err);
    return;
  }
  const created = Array.isArray(data.data?.created) ? data.data.created : [];
  const n = created.length || qty;
  const ids = created
    .map((r) => r?.inventory_id)
    .filter((id) => id != null)
    .slice(0, 5)
    .join(', ');
  labResult(
    `OK: creati ${n} oggetti (vnum ${vnum}` +
      (ids ? `, inv ${ids}${created.length > 5 ? '…' : ''}` : '') +
      ') — personalizzati sul target, ricarico inventario…',
  );
  await loadInventory();
  const found = (inventoryItemsCache || []).filter((it) =>
    created.some((c) => Number(c.inventory_id) === Number(it.inventory_id)),
  );
  if (created.length && found.length === 0) {
    labResult(
      `Creati ${n} pezzi (vnum ${vnum}) ma non compaiono in lista inventario: ` +
        `controlla filtri RARO/categorie o ricarica la pagina.`,
      { isError: true },
    );
  } else if (found.length) {
    labResult(
      `OK: ${found.length}/${n} in inventario (vnum ${vnum}` +
        (ids ? `, inv ${ids}` : '') +
        ')',
    );
  }
}

async function labCloneInstance(instanceId) {
  const tid = getTargetToonId();
  if (!tid) {
    labResult('Seleziona un personaggio target prima di clonare');
    return;
  }
  const ok = window.confirm(
    `Clonare istanza #${instanceId} sull'inventario del target #${tid}?`,
  );
  if (!ok) return;
  labResult(`Clono istanza #${instanceId}…`);
  const data = await apiApply(
    '/api/lab/clone-instance',
    { targetToonId: tid, instanceId: Number(instanceId) },
    'Lab clone',
    { statusEl: $('lab-result') },
  );
  if (!data.ok) {
    const err = data.error || 'errore lab clone-instance';
    labResult(err, { isError: true });
    window.alert(err);
    return;
  }
  labResult(
    `OK clone: nuova istanza #${data.data?.new_instance_id ?? '?'} ` +
      `(inv #${data.data?.inventory_id ?? '?'})`,
  );
  await loadInventory();
}

function formatCommandsDetails(summary, open = false) {
  const cmds = Array.isArray(summary?.commands) ? summary.commands : [];
  if (!cmds.length) {
    return '<p class="hint">Nessun comando staff disponibile (myst offline o lista vuota).</p>';
  }
  const rows = cmds
    .map((c) => {
      const name = escapeHtml(c.name || '');
      const min = Number(c.min_level) || 0;
      const g = escapeHtml(c.grade || '');
      return `<li><code>${name}</code> <span class="ov-cmd-meta">lv≥${min}${g ? ` · ${g}` : ''}</span></li>`;
    })
    .join('');
  return `<details class="ov-commands-details"${open ? ' open' : ''}>
      <summary>Comandi abilitati (${cmds.length})</summary>
      <ul class="ov-cmd-list">${rows}</ul>
    </details>`;
}

function formatGoldAmount(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return '0';
  return Math.trunc(v).toLocaleString('it-IT');
}

function moneyMetaLine(summary) {
  if (!summary) return '';
  const gold = formatGoldAmount(summary.gold);
  const bank = formatGoldAmount(summary.bank_gold);
  return `<span class="toon-overview-meta toon-overview-money">Soldi: ${gold} addosso · ${bank} in banca</span>`;
}

function makeStaffToonCard(t) {
  const card = document.createElement('div');
  card.className = 'toon-overview-card toon-staff-card';
  const s = t.summary && t.summary.ok !== false ? t.summary : null;
  const grade = (s && s.grade) || '';
  card.innerHTML = `
    <div class="toon-overview-head toon-overview-head-stack">
      <div>
        <strong class="toon-overview-name">${escapeHtml(t.name)}</strong>
        <span class="toon-overview-meta">lv ${t.maxLevel}${
          grade ? ` · ${escapeHtml(grade)}` : ''
        }</span>
        ${moneyMetaLine(s)}
      </div>
    </div>
    <div class="toon-overview-body">
      ${s ? formatCommandsDetails(s) : '<p class="hint">Comandi non disponibili.</p>'}
    </div>
  `;
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'btn-primary toon-enter-btn';
  btn.textContent = 'Entra';
  btn.onclick = () => selectAccountToon(t.id);
  card.appendChild(btn);
  return card;
}

function makePrinceToonCard(t) {
  const card = document.createElement('div');
  card.className = 'toon-overview-card toon-prince-card';
  const s = t.summary && t.summary.ok !== false ? t.summary : null;
  const grade = (s && s.grade) || '';
  const title = String(t.title || '').trim();
  const mxp = s ? Number(s.available_mxp) || 0 : 0;
  const mxpFrac = s ? Number(s.available_mxp_frac) || 0 : 0;
  const runeN = s && s.rune != null ? Number(s.rune) : null;

  const head = document.createElement('div');
  head.className = 'toon-overview-head toon-overview-head-stack';
  head.innerHTML =
    `<div><strong class="toon-overview-name">${escapeHtml(t.name)}</strong>` +
    `<span class="toon-overview-meta">lv ${t.maxLevel}` +
    (title ? ` · ${mudTextToHtml(title)}` : '') +
    (grade ? ` · ${escapeHtml(grade)}` : '') +
    ` · ${escapeHtml(formatMxp(mxp, mxpFrac))} disponibili` +
    (runeN != null && Number.isFinite(runeN)
      ? ` · ${escapeHtml(String(Math.trunc(runeN)))} ${escapeHtml(currencyLabel('rune'))}`
      : '') +
    `</span>` +
    moneyMetaLine(s) +
    `</div>`;
  card.appendChild(head);

  if (!s) {
    const miss = document.createElement('p');
    miss.className = 'hint';
    miss.textContent =
      (t.summary && t.summary.error) ||
      'Riepilogo non disponibile (myst offline o PG senza inventorio leggibile).';
    card.appendChild(miss);
    const btnEarly = document.createElement('button');
    btnEarly.type = 'button';
    btnEarly.className = 'btn-primary toon-enter-btn';
    btnEarly.textContent = 'Entra';
    btnEarly.onclick = () => selectAccountToon(t.id);
    card.appendChild(btnEarly);
    return card;
  }

  const main = s.main_edits || {};
  const clan = s.clan_symbol || {};
  const pool = s.pool || {};
  const stripMudColors = (t) =>
    String(t || '')
      .replace(/\$\$/g, '$')
      .replace(/\$c[0-9]{4}/gi, '')
      .replace(/\$[cC]/g, '');
  const residualObjs = Array.isArray(pool.residual_objects)
    ? pool.residual_objects
    : [];
  const residualBits = (o) =>
    [
      o.hit ? `HIT ${o.hit}` : '',
      o.mana ? `MANA ${o.mana}` : '',
      o.move ? `MOVE ${o.move}` : '',
      o.hit_regen ? `HRgn ${o.hit_regen}` : '',
      o.mana_regen ? `MRgn ${o.mana_regen}` : '',
      o.move_regen ? `VRgn ${o.move_regen}` : '',
    ]
      .filter(Boolean)
      .join(', ');
  const onPg = pool.on_character !== false && pool.values_from !== 'objects';
  const isStaffViewer = session?.role === 'staff';
  const poolMigrated =
    Number(pool.edit_pool_migrated ?? pool.migrated ?? 0) === 1;
  const poolSource = isStaffViewer
    ? pool.values_from === 'objects'
      ? 'sorgente: oggetti EDIT'
      : poolMigrated
        ? 'sorgente: character_stats · migrato=1'
        : 'sorgente: character_stats · migrato=0'
    : '';
  const poolWarn = pool.warning
    ? `<p class="ov-warn">${escapeHtml(String(pool.warning))}</p>`
    : '';
  const poolStaffWarn =
    isStaffViewer && pool.staff_warning
      ? `<p class="ov-warn ov-warn-staff">${escapeHtml(String(pool.staff_warning))}</p>`
      : '';
  const residualList =
    residualObjs.length > 0
      ? `<p class="ov-meter-note">${
          onPg
            ? 'Ancora presenti su oggetti EDIT (da ripulire):'
            : 'Dettaglio pezzi che portano ancora HIT/MANA/MOVE/regen:'
        }</p>
      <ul class="ov-checklist ov-residual-list">${residualObjs
        .map(
          (o) =>
            `<li><code>#${escapeHtml(String(o.item_number || ''))}</code> ${escapeHtml(
              stripMudColors(String(o.short_desc || 'oggetto')),
            )} <span class="ov-source">(${escapeHtml(
              residualBits(o) || 'delta',
            )})</span></li>`,
        )
        .join('')}</ul>`
      : '';
  const clanLabel = !clan.present
    ? '<span class="ov-no">No</span>'
    : clan.label
      ? `<span class="ov-yes">${escapeHtml(String(clan.label))}</span>`
      : `<span class="ov-yes">SI - del clan di ${escapeHtml(
          String(clan.owner_name || s.name || 'sconosciuto'),
        )}</span>`;
  const poolFieldLabel = {
    hit: 'Hit',
    mana: 'Mana',
    move: 'Move',
    hit_regen: 'Hit regen',
    mana_regen: 'Mana regen',
    move_regen: 'Move regen',
  };
  const body = document.createElement('div');
  body.className = 'toon-overview-body';
  body.innerHTML = `
    <details class="ov-collapse">
      <summary>Edit principali</summary>
      <div class="ov-collapse-body">
        <ul class="ov-checklist">
          ${resistLine('Res. Slash', main.res_slash)}
          ${resistLine('Res. Pierce', main.res_pierce)}
          ${resistLine('Res. Blunt', main.res_blunt)}
        </ul>
        ${damSpOverviewMeters(main)}
        ${meterLine('Hitroll editato', main.hitroll?.used, main.hitroll?.cap, main.hitroll?.remaining)}
        ${meterLine('Spellfail editato', main.spellfail?.used, main.spellfail?.cap, main.spellfail?.remaining)}
      </div>
    </details>
    <details class="ov-collapse">
      <summary>Pool sul PG <span class="ov-source">(editpool · hit/mana/move/regen)</span></summary>
      <div class="ov-collapse-body">
        ${poolSource ? `<p class="ov-meter-note">${escapeHtml(poolSource)}</p>` : ''}
        ${poolWarn}
        ${poolStaffWarn}
        ${(pool.fields || [])
          .map((f) =>
            meterLine(
              poolFieldLabel[f.key] || f.key,
              f.used,
              f.cap,
              f.remaining,
              'ancora editabili',
            ),
          )
          .join('')}
        ${residualList}
      </div>
    </details>
    <div class="ov-block ov-clan">
      <h4>Simbolo del clan</h4>
      <p>${clanLabel}</p>
    </div>
  `;
  card.appendChild(body);

  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'btn-primary toon-enter-btn';
  btn.textContent = 'Entra';
  btn.onclick = () => selectAccountToon(t.id);
  card.appendChild(btn);
  return card;
}

async function selectAccountToon(toonId) {
  const sel = await api('/api/select-toon', {
    method: 'POST',
    body: JSON.stringify({ toonId }),
  });
  if (!sel.ok) {
    alert(sel.error);
    return;
  }
  toonEditSnapshot = sel.snapshot || null;
  await refreshMe();
}

async function ensureToonEditSnapshot(force = false) {
  if (!force && toonEditSnapshot && Number(toonEditSnapshot.toonId) === Number(targetToonId)) {
    return toonEditSnapshot;
  }
  if (!targetToonId) return null;
  const data = await api(`/api/toon-snapshot/${targetToonId}?refresh=${force ? 1 : 0}`);
  if (data.ok) toonEditSnapshot = data.snapshot || null;
  return toonEditSnapshot;
}

function stopEditSessionTouch() {
  if (editSessionTouchTimer) {
    clearInterval(editSessionTouchTimer);
    editSessionTouchTimer = null;
  }
}

function startEditSessionTouch() {
  stopEditSessionTouch();
  const beat = async () => {
    try {
      const data = await api('/api/session/touch', { method: 'POST', body: '{}' });
      if (!data.ok) {
        stopEditSessionTouch();
        console.warn('[edit-session]', data.error || 'touch fallito');
      }
    } catch (err) {
      console.warn('[edit-session] touch', err && err.message ? err.message : err);
    }
  };
  beat();
  /* Ogni 2 min: resta sotto TTL (default 5 min). */
  editSessionTouchTimer = setInterval(beat, 120000);
}

async function enterWorkMode() {
  hide('toon-panel');
  show('work-panel');
  const me = await api('/api/me');
  $('header-meta').textContent =
    `${me.email} — ${me.sessionToonName} (${me.role}, lv ${me.maxLevel}) · UI ${EDIT_PORTAL_UI_BUILD}`;
  startEditSessionTouch();

  await loadEditCapabilities();
  const payTender = $('pay-tender');
  const payRunePct = $('pay-rune-pct');
  if (canPayMxp()) {
    if (payTender) payTender.disabled = false;
    if (payRunePct) {
      payRunePct.disabled = false;
      if (Number(payRunePct.value) === 100) payRunePct.value = 0;
    }
  } else {
    if (payTender) payTender.disabled = true;
    if (payRunePct) {
      payRunePct.value = 100;
      payRunePct.disabled = true;
    }
  }
  syncPayModeFromSlider();
  refreshPayModeLabels();

  if (me.role === 'staff') {
    initStaffToolsColumn();
    syncLabPanelVisibility(me);
    show('target-toon-wrap');
    const hint = $('session-role-hint');
    if (hint) {
      hint.textContent =
        `Sessione: ${me.sessionToonName} (staff). Cerca sotto il personaggio su cui vuoi lavorare. Usa «Vista staff» per Economia/listino.`;
    }
    loadSystemConfig();
  } else {
    hideStaffToolsColumn();
    syncLabPanelVisibility(me);
    hide('target-toon-wrap');
    const hint = $('session-role-hint');
    if (hint) hint.textContent = `Personaggio: ${me.sessionToonName}`;
  }

  await loadEditCatalog();
  await loadTargetToons();
}

async function loadEditCatalog() {
  const data = await api('/api/edit-catalog');
  if (data.ok) {
    editCatalog = data.data;
  } else {
    editCatalog = null;
    showApiWarn(`Catalogo edit: ${data.error || 'errore myst'}`);
  }
}

function getSelectedTargetLabel() {
  const sel = $('target-toon');
  if (!sel || !sel.value) return '';
  const opt = sel.selectedOptions?.[0];
  return (opt?.textContent || '').replace(/\s*\(lv.*$/, '') || '';
}

function updateInventoryHeading() {
  const title = $('inventory-title');
  const hint = $('inventory-target-hint');
  const name = getSelectedTargetLabel() || charState?.name || '';
  if (session?.role === 'staff') {
    if (!getTargetToonId() || !name) {
      if (title) title.textContent = 'Inventario';
      if (hint) {
        hint.textContent =
          'Nessun personaggio target: cerca e seleziona un PG sopra. Non viene mostrato l\'inventario del login staff.';
      }
      return;
    }
    if (title) title.textContent = `Inventario di ${name}`;
    if (hint) {
      hint.textContent = `Stai vedendo/editando gli oggetti di ${name} (deve essere offline per gli apply).`;
    }
  } else {
    if (title) title.textContent = name ? `Inventario di ${name}` : 'Inventario';
    if (hint) hint.textContent = '';
  }
}

let targetSearchTimer = null;

function resetStaffTargetSelect(message) {
  const sel = $('target-toon');
  if (!sel) return;
  sel.innerHTML = '';
  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = message || '— cerca un nome sopra —';
  sel.appendChild(placeholder);
  sel.value = '';
  targetToonId = null;
}

async function searchTargetToons(q) {
  const sel = $('target-toon');
  if (!sel) return;
  const query = String(q || '').trim();
  const prevTarget = targetToonId;
  // Nuova ricerca: non tenere selezionato/auto-caricato il primo risultato.
  resetStaffTargetSelect(
    query.length < 2 ? '— digita almeno 2 lettere —' : '— seleziona un personaggio —',
  );
  if (prevTarget) {
    clearTargetWorkspace('Cerca e seleziona di nuovo il personaggio target.');
    updateInventoryHeading();
  }
  if (query.length < 2) {
    return;
  }
  const data = await api(`/api/target-toons?q=${encodeURIComponent(query)}`);
  if (!data.ok) {
    resetStaffTargetSelect(data.error || 'errore ricerca');
    return;
  }
  if (!data.toons?.length) {
    resetStaffTargetSelect('Nessun personaggio trovato');
    return;
  }
  // Placeholder obbligatorio: senza, il browser seleziona il primo PG da solo.
  resetStaffTargetSelect('— seleziona un personaggio —');
  data.toons.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = String(t.id);
    opt.textContent = `${t.name} (lv ${t.max_level ?? '?'})`;
    sel.appendChild(opt);
  });
  sel.value = '';
}

async function loadTargetToons() {
  const sel = $('target-toon');
  if (!sel) return;

  if (session.role === 'staff') {
    targetToonId = null;
    const search = $('target-toon-search');
    if (search) {
      search.value = '';
      if (!search.dataset.bound) {
        search.dataset.bound = '1';
        search.addEventListener('input', () => {
          clearTimeout(targetSearchTimer);
          targetSearchTimer = setTimeout(() => searchTargetToons(search.value), 250);
        });
      }
    }
    resetStaffTargetSelect('— cerca un nome sopra —');
    sel.onchange = async () => {
      targetToonId = getTargetToonId();
      clearTargetWorkspace(
        targetToonId
          ? 'Caricamento personaggio…'
          : 'Seleziona un personaggio dalla lista.'
      );
      updateInventoryHeading();
      if (!targetToonId) {
        return;
      }
      await loadCharacterState();
      await loadInventory();
    };
    clearTargetWorkspace('Cerca e seleziona un personaggio target.');
    updateInventoryHeading();
    return;
  }

  const data = await api('/api/target-toons');
  sel.innerHTML = '';
  if (!data.ok) return;
  data.toons.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = String(t.id);
    opt.textContent = `${t.name} (lv ${t.max_level ?? '?'})`;
    sel.appendChild(opt);
  });
  if (session.sessionToonId) {
    sel.value = String(session.sessionToonId);
  }
  targetToonId = getTargetToonId();
  sel.onchange = async () => {
    targetToonId = getTargetToonId();
    clearTargetWorkspace(
      targetToonId ? 'Caricamento personaggio…' : 'Personaggio non selezionato'
    );
    if (!targetToonId) return;
    await ensureToonEditSnapshot(true);
    await loadCharacterState();
    await loadInventory();
  };
  clearTargetWorkspace('Caricamento personaggio…');
  await ensureToonEditSnapshot(true);
  await loadCharacterState();
  await loadInventory();
}

function showApiWarn(msg) {
  const el = $('api-warn');
  el.textContent = msg;
  show('api-warn');
}

function hideApiWarn() {
  hide('api-warn');
}

function clearTargetWorkspace(message) {
  clearAllObjectCarts();
  characterEditCart.clear();
  objectOptionsCache.clear();
  listinoSnapshot = null;
  toonEditSnapshot = null;
  pendingEdit = null;
  selectedInventoryId = null;
  selectedObjectOptions = null;
  charState = null;
  inventoryItemsCache = [];
  updatePaymentUI();
  const statsMsg =
    message || 'Seleziona un personaggio target.';
  if ($('char-stats')) $('char-stats').textContent = statsMsg;
  if ($('inventory-list')) $('inventory-list').innerHTML = '';
  if ($('inventory-empty')) {
    $('inventory-empty').textContent = '';
    $('inventory-empty').classList.add('hidden');
  }
  if ($('object-edits')) $('object-edits').innerHTML = '';
  if ($('object-text-edit')) $('object-text-edit').innerHTML = '';
  if ($('object-massimali')) $('object-massimali').innerHTML = '';
  if ($('object-edit-cart')) {
    $('object-edit-cart').innerHTML = '';
    $('object-edit-cart').classList.add('hidden');
  }
  if ($('char-edit-cart')) {
    $('char-edit-cart').innerHTML = '';
    $('char-edit-cart').classList.add('hidden');
  }
  if ($('object-affect-slots')) {
    $('object-affect-slots').innerHTML = '';
    hide('object-affect-slots');
  }
  setMainColumnSplit(false);
  if ($('pool-edits')) $('pool-edits').innerHTML = '';
  if ($('resistance-edits')) $('resistance-edits').innerHTML = '';
  if ($('quote-box')) {
    $('quote-box').textContent =
      'Seleziona un personaggio target, poi un oggetto editabile.';
  }
  if ($('apply-result')) $('apply-result').textContent = '';
  hideApiWarn();
  updateInventoryHeading();
}

async function loadCharacterState() {
  hideApiWarn();
  targetToonId = getTargetToonId();
  if (!targetToonId) {
    clearTargetWorkspace('Personaggio non selezionato');
    return;
  }
  ensureListinoSnapshot().catch(() => {});
  const data = await api(`/api/character-state/${targetToonId}`);
  if (!data.ok) {
    charState = null;
    if ($('pool-edits')) $('pool-edits').innerHTML = '';
    if ($('resistance-edits')) $('resistance-edits').innerHTML = '';
    $('char-stats').textContent = data.error || 'Impossibile caricare stato PG (myst attivo?)';
    showApiWarn(`Stato personaggio: ${data.error}`);
    return;
  }
  charState = data.data;
  renderCharStats();
  refreshLabTargetStats();
  if (charState.stats_missing) {
    if ($('pool-edits')) $('pool-edits').innerHTML = '';
    if ($('resistance-edits')) $('resistance-edits').innerHTML = '';
    showApiWarn(charState.warning || 'character_stats assente per questo toon');
  } else {
    renderCharacterEdits();
  }
  updateInventoryHeading();
}

function renderCharStats() {
  const s = charState;
  if (!s) return;
  const missing = s.stats_missing
    ? `<div class="stat-row hint">character_stats assente — solo consultazione inventario</div>`
    : '';
  $('char-stats').innerHTML = `
    <div class="stat-row"><span>Nome</span><strong>${escapeHtml(s.name || '')}</strong></div>
    <div class="stat-row"><span>Livello</span><strong>${s.max_level}</strong></div>
    <div class="stat-row"><span>MXP Disponibili</span><strong>${formatMxp(s.available_mxp, s.available_mxp_frac)}</strong></div>
    <div class="stat-row"><span>${currencyLabel('rune')}</span><strong>${s.rune}</strong></div>
    ${s.prince_reserve_mxp
      ? `<div class="stat-row hint"><span>Limite minimo xp per i principi</span><strong>${s.prince_reserve_mxp} MXP</strong></div>`
      : ''}
    ${missing}
  `;
}

function catalogEntries(kind, target) {
  if (!editCatalog || !editCatalog.entries) return [];
  return editCatalog.entries.filter(
    (e) => e.kind === kind && e.target === target && e.enabled !== false
  );
}

function buildStepOptions(cap, step, current) {
  /* Pool: solo valori >= attuale (non si riduce un edit gia' pagato). */
  const opts = [];
  const start = Math.max(0, Number(current) || 0);
  for (let v = start; v <= cap; v += step) {
    opts.push(v);
  }
  if (!opts.includes(current)) opts.push(current);
  opts.sort((a, b) => a - b);
  return opts;
}

function resistanceValueOptions(min, max, step) {
  const opts = [];
  for (let v = min; v <= max; v += step) {
    opts.push(v);
  }
  return opts;
}

function renderCharacterEdits() {
  const poolBox = $('pool-edits');
  const resBox = $('resistance-edits');
  poolBox.innerHTML = '';
  resBox.innerHTML = '';
  if ($('char-edit-cart')) {
    $('char-edit-cart').innerHTML = '';
    $('char-edit-cart').classList.add('hidden');
  }

  if (!charState || session.role === 'limited') {
    poolBox.innerHTML = '<p class="hint">Tier limited: edit non consentito.</p>';
    return;
  }

  const poolEntries = catalogEntries('pool', 'character');
  if (poolEntries.length) {
    const details = document.createElement('details');
    details.className = 'edit-section';
    details.open = true;
    const summary = document.createElement('summary');
    summary.className = 'edit-section-summary';
    summary.innerHTML =
      `<span class="edit-section-name">Pool</span>` +
      `<span class="edit-section-count">${poolEntries.length}</span>`;
    details.appendChild(summary);
    const body = document.createElement('div');
    body.className = 'edit-section-body';
    poolEntries.forEach((entry) => {
    const field = entry.pool_field;
    const cartKey = `pool:${field}`;
    const cap = Number(entry.cap || charState.pool?.caps?.[field] || 0);
    const step = Number(entry.step || 10);
    const current = Number(charState.pool?.[field] || 0);
    const row = document.createElement('div');
    row.className = 'edit-row';
    row.dataset.cartKey = cartKey;
    const select = document.createElement('select');
    select.dataset.current = String(current);
    buildStepOptions(cap, step, current).forEach((v) => {
      const opt = document.createElement('option');
      opt.value = v;
      const d = v - current;
      opt.textContent =
        d > 0 ? `${v} (+${d})` : d === 0 ? `${v} (attuale)` : String(v);
      if (v === current) opt.selected = true;
      select.appendChild(opt);
    });
    const queued = characterEditCart.get(cartKey);
    if (queued && queued.newValue != null) {
      select.value = String(queued.newValue);
      if (queued.selectEl !== select) queued.selectEl = select;
    }
    select.addEventListener('change', () => {
      if (Number(select.value) === current) {
        if (characterEditCart.has(cartKey)) {
          characterEditCart.delete(cartKey);
          rebuildCharacterPendingFromCart();
        }
        return;
      }
      queuePoolQuote(field, Number(select.value), entry.label || field, select, cartKey);
    });
    row.innerHTML = `
      <div>
        <label class="effect-name">${entry.label || field}</label>
        <div class="current">Attuale: ${current} / ${cap}</div>
      </div>
    `;
    row.appendChild(select);
    body.appendChild(row);
    });
    details.appendChild(body);
    poolBox.appendChild(details);
  }

  const affEntries = catalogEntries('affect', 'character');
  if (affEntries.length) {
    const details = document.createElement('details');
    details.className = 'edit-section';
    details.open = true;
    const summary = document.createElement('summary');
    summary.className = 'edit-section-summary';
    summary.innerHTML =
      `<span class="edit-section-name">Affect personaggio</span>` +
      `<span class="edit-section-count">${affEntries.length}</span>`;
    details.appendChild(summary);
    const body = document.createElement('div');
    body.className = 'edit-section-body';
    const byLoc = {};
    for (const a of charState.char_affects || toonEditSnapshot?.char_affects || []) {
      byLoc[Number(a.location)] = Number(a.value || 0);
    }
    affEntries.forEach((entry) => {
      const location = Number(entry.location);
      const cartKey = `char-affect:${location}`;
      const cap = Number(entry.cap ?? entry.max ?? entry.max_total ?? 0);
      const minT = Number(entry.min ?? entry.min_total ?? 0);
      const step = Number(entry.step || 1);
      const current = Number(byLoc[location] || 0);
      const row = document.createElement('div');
      row.className = 'edit-row';
      row.dataset.cartKey = cartKey;
      const select = document.createElement('select');
      select.dataset.current = String(current);
      const opts = [];
      const start = Math.max(minT, current);
      const end = cap >= minT ? cap : start;
      for (let v = start; v <= end; v += Math.abs(step) || 1) opts.push(v);
      if (!opts.includes(current)) opts.push(current);
      opts.sort((a, b) => a - b);
      opts.forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        const d = v - current;
        opt.textContent =
          d > 0 ? `${v} (+${d})` : d === 0 ? `${v} (attuale)` : String(v);
        if (v === current) opt.selected = true;
        select.appendChild(opt);
      });
      const queued = characterEditCart.get(cartKey);
      if (queued && queued.newValue != null) {
        select.value = String(queued.newValue);
        if (queued.selectEl !== select) queued.selectEl = select;
      }
      select.addEventListener('change', () => {
        if (Number(select.value) === current) {
          if (characterEditCart.has(cartKey)) {
            characterEditCart.delete(cartKey);
            rebuildCharacterPendingFromCart();
          }
          return;
        }
        queueCharAffectQuote(
          location,
          Number(select.value),
          entry.label || `loc ${location}`,
          select,
          cartKey,
        );
      });
      const groupHint = entry.cap_group
        ? `<div class="current">Gruppo cap: ${escapeHtml(entry.cap_group)}</div>`
        : '';
      row.innerHTML = `
        <div>
          <label class="effect-name">${escapeHtml(entry.label || String(location))}</label>
          <div class="current">Attuale: ${current} / ${cap}</div>
          ${groupHint}
        </div>
      `;
      row.appendChild(select);
      body.appendChild(row);
    });
    details.appendChild(body);
    poolBox.appendChild(details);
  }

  const resEntries = catalogEntries('resistance', 'character');
  if (resEntries.length) {
    const details = document.createElement('details');
    details.className = 'edit-section';
    details.open = true;
    const summary = document.createElement('summary');
    summary.className = 'edit-section-summary';
    summary.innerHTML =
      `<span class="edit-section-name">Resistenze</span>` +
      `<span class="edit-section-count">${resEntries.length}</span>`;
    details.appendChild(summary);
    const body = document.createElement('div');
    body.className = 'edit-section-body';
    const grid = document.createElement('div');
    grid.className = 'resistance-grid';
    resEntries.forEach((entry) => {
      const dt = Number(entry.damage_type);
      const cartKey = `res:${dt}`;
      const currentRow = (charState.resistances || []).find((r) => Number(r.damage_type) === dt);
      const current = currentRow ? Number(currentRow.value) : 0;
      const min = Number(entry.min ?? -100);
      const max = Number(entry.max ?? 100);
      const step = Number(entry.step ?? 25);
      const row = document.createElement('div');
      row.className = 'edit-row';
      row.dataset.cartKey = cartKey;
      const select = document.createElement('select');
      select.dataset.current = String(current);
      resistanceValueOptions(min, max, step).forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        if (v === current) opt.selected = true;
        select.appendChild(opt);
      });
      const queued = characterEditCart.get(cartKey);
      if (queued && queued.value != null) {
        select.value = String(queued.value);
        if (queued.selectEl !== select) queued.selectEl = select;
      }
      select.addEventListener('change', () => {
        if (Number(select.value) === current) {
          if (characterEditCart.has(cartKey)) {
            characterEditCart.delete(cartKey);
            rebuildCharacterPendingFromCart();
          }
          return;
        }
        queueResistanceQuote(dt, Number(select.value), entry.label || entry.id, select, cartKey);
      });
      row.innerHTML = `
        <div>
          <label class="effect-name">${entry.label || entry.id}</label>
          <div class="current">Attuale: ${current}</div>
        </div>
      `;
      row.appendChild(select);
      grid.appendChild(row);
    });
    body.appendChild(grid);
    details.appendChild(body);
    resBox.appendChild(details);
  }
  updateCharacterCartUI();
}

async function queuePoolQuote(field, newValue, label, selectEl, cartKey) {
  const requested = Number(selectEl.value);
  const data = await api('/api/quote-pool', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, field, newValue }),
  });
  if (Number(selectEl.value) !== requested) return;
  if (!data.ok) {
    alert(data.error || 'Quote pool fallita');
    selectEl.value = selectEl.dataset.current || String(data.data?.current ?? selectEl.value);
    return;
  }
  ensureCharacterCartExclusive();
  const key = cartKey || `pool:${field}`;
  characterEditCart.set(key, {
    key,
    type: 'pool',
    field,
    newValue,
    label: `${label}: ${data.data.current} → ${data.data.target}`,
    quote: data.data,
    selectEl,
  });
  rebuildCharacterPendingFromCart();
}

async function queueCharAffectQuote(location, newValue, label, selectEl, cartKey) {
  const requested = Number(selectEl.value);
  const data = await api('/api/quote-char-affect', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, location, newValue }),
  });
  if (Number(selectEl.value) !== requested) return;
  if (!data.ok) {
    alert(data.error || 'Quote affect PG fallita');
    selectEl.value = selectEl.dataset.current || String(data.data?.current ?? selectEl.value);
    return;
  }
  ensureCharacterCartExclusive();
  const key = cartKey || `char-affect:${location}`;
  characterEditCart.set(key, {
    key,
    type: 'char-affect',
    location,
    newValue,
    label: `${label}: ${data.data.current} → ${data.data.target}`,
    quote: data.data,
    selectEl,
  });
  rebuildCharacterPendingFromCart();
}

async function queueResistanceQuote(damageType, value, label, selectEl, cartKey) {
  const requested = Number(selectEl.value);
  const data = await api('/api/quote-resistance', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, damageType, value }),
  });
  if (Number(selectEl.value) !== requested) return;
  if (!data.ok) {
    alert(data.error || 'Quote resistenza fallita');
    selectEl.value = selectEl.dataset.current || String(selectEl.value);
    return;
  }
  ensureCharacterCartExclusive();
  const key = cartKey || `res:${damageType}`;
  characterEditCart.set(key, {
    key,
    type: 'resistance',
    damageType,
    value,
    label: `${label}: ${data.data.current} → ${data.data.target}`,
    quote: data.data,
    selectEl,
  });
  rebuildCharacterPendingFromCart();
}

function stripMudColorCodes(raw) {
  return String(raw ?? '')
    .replace(/\$\$/g, '\u0000')
    .replace(/\$[cC]\d{4}/g, '')
    .replace(/\$/g, '')
    .replace(/\u0000/g, '$')
    .trim();
}

function inventorySortKeyAlpha(it) {
  return stripMudColorCodes(it.short_desc || it.name || '').toLocaleLowerCase('it');
}

function getInventorySortMode() {
  const sel = $('inventory-sort');
  if (sel && sel.value) return sel.value;
  try {
    return localStorage.getItem(INVENTORY_SORT_KEY) || 'inventory';
  } catch {
    return 'inventory';
  }
}

function persistInventorySortMode(mode) {
  try {
    localStorage.setItem(INVENTORY_SORT_KEY, mode);
  } catch {
    /* ignore */
  }
}

function sortInventoryItems(items, mode) {
  const arr = [...items];
  const byAlpha = (a, b) =>
    inventorySortKeyAlpha(a).localeCompare(inventorySortKeyAlpha(b), 'it', {
      sensitivity: 'base',
      numeric: true,
    });
  const byType = (a, b) =>
    String(a.item_type || '').localeCompare(String(b.item_type || ''), 'it', {
      sensitivity: 'base',
    }) || byAlpha(a, b);
  const byVnum = (a, b) =>
    Number(a.item_number || 0) - Number(b.item_number || 0) || byAlpha(a, b);
  const byList = (a, b) =>
    Number(a.list_index ?? a.inventory_id ?? 0) -
    Number(b.list_index ?? b.inventory_id ?? 0);

  switch (mode) {
    case 'alpha':
      arr.sort(byAlpha);
      break;
    case 'alpha_desc':
      arr.sort((a, b) => -byAlpha(a, b));
      break;
    case 'editable':
      arr.sort((a, b) => Number(!!b.editable) - Number(!!a.editable) || byAlpha(a, b));
      break;
    case 'not_editable':
      arr.sort((a, b) => Number(!!a.editable) - Number(!!b.editable) || byAlpha(a, b));
      break;
    case 'item_type':
      arr.sort(byType);
      break;
    case 'worn':
      arr.sort(
        (a, b) => Number(!!b.worn) - Number(!!a.worn) || byAlpha(a, b),
      );
      break;
    case 'vnum':
      arr.sort(byVnum);
      break;
    case 'container':
      arr.sort(
        (a, b) => Number(b.depth || 0) - Number(a.depth || 0) || byAlpha(a, b),
      );
      break;
    case 'inventory':
    default:
      arr.sort(byList);
      break;
  }
  return arr;
}

function renderInventoryList(items) {
  const list = $('inventory-list');
  list.innerHTML = '';
  const prevSelected = selectedInventoryId;
  const sorted = sortInventoryItems(items, getInventorySortMode());

  sorted.forEach((it) => {
    const li = document.createElement('li');
    li.className = it.editable ? 'item' : 'item item-disabled';
    const worn = it.worn ? ' · indossato' : '';
    const depth = Number(it.depth) > 0 ? ' · in container' : '';
    const skip = it.skip_reason ? ` — ${it.skip_reason}` : '';
    const type = it.item_type ? ` [${it.item_type}]` : '';
    const meta = ` (vnum ${it.item_number})${worn}${depth}${skip}${type}`;
    li.innerHTML =
      `<span class="item-name">${mudTextToHtml(it.short_desc || it.name)}</span>` +
      `<span class="item-meta">${escapeHtml(meta)}</span>`;
    li.title = it.editable
      ? `inventory_id ${it.inventory_id}`
      : it.skip_reason || 'non editabile';
    if (prevSelected && Number(it.inventory_id) === Number(prevSelected)) {
      li.classList.add('selected');
    }
    if (it.editable) {
      li.onclick = () => selectItem(it.inventory_id, li);
    }
    list.appendChild(li);
  });
  markInventoryQueued();
}

async function loadInventory() {
  targetToonId = getTargetToonId();
  if (!targetToonId) {
    showApiWarn('Personaggio target non selezionato — cerca e seleziona un PG');
    updateInventoryHeading();
    inventoryItemsCache = [];
    return;
  }
  updateInventoryHeading();
  const data = await api(`/api/inventory/${targetToonId}`);
  const list = $('inventory-list');
  list.innerHTML = '';

  if (!data.ok) {
    showApiWarn(data.error || 'Errore caricamento inventario');
    $('inventory-empty').classList.add('hidden');
    inventoryItemsCache = [];
    return;
  }

  if (data.mystErrors && data.mystErrors.length) {
    showApiWarn(`API myst: ${data.mystErrors.join(' · ')}`);
  } else {
    hideApiWarn();
  }

  const warn = $('online-warn');
  if (data.online) {
    warn.textContent = 'Il personaggio target è collegato al mud: gli apply sono bloccati fino al logout in-game.';
    show('online-warn');
  } else {
    hide('online-warn');
  }

  const items = data.items || [];
  inventoryItemsCache = items;
  const editableCount = Number(
    data.editable_count ?? items.filter((i) => i.editable).length,
  );
  const mysqlCount = Number(data.mysql_count ?? 0);
  const emptyEl = $('inventory-empty');
  emptyEl.classList.toggle('hidden', items.length > 0);
  if (!items.length) {
    if (mysqlCount > 0 && data.inventory_source === 'mysql_myst_empty') {
      emptyEl.textContent =
        'Elenco MySQL ha ' +
        mysqlCount +
        ' oggetti ma myst non li ha arricchiti: ricompila/riavvia myst.';
    } else if (mysqlCount > 0 && data.inventory_source === 'myst_filtered') {
      const br = data.myst_hidden_breakdown;
      const parts = [];
      if (br) {
        if (br.raro) parts.push(`${br.raro} RARO`);
        if (br.tan) parts.push(`${br.tan} tan`);
        if (br.category) parts.push(`${br.category} categoria spenta`);
        if (br.other) parts.push(`${br.other} altro`);
      }
      emptyEl.textContent =
        'Myst ha nascosto tutti i pezzi (' +
        (data.myst_loaded_rows ?? '?') +
        ' letti)' +
        (parts.length ? `: ${parts.join(', ')}` : '') +
        '. TAN mai; RARO solo se non in DB edits / senza EDIT+EDNomeToon.';
    } else if (mysqlCount > 0) {
      emptyEl.textContent =
        'Nessun oggetto mostrato, ma MySQL ha ' +
        mysqlCount +
        ' righe inventario. Verifica categorie staff.';
    } else {
      emptyEl.textContent =
        'Nessun oggetto in inventario MySQL per questo PG (logout in-game per salvare).';
    }
  }

  if (items.length && editableCount === 0) {
    showApiWarn(
      'Inventario caricato: nessun oggetto editabile (vedi motivi nella lista). Pezzi indossati sono editabili se rispettano categorie/esclusioni (PG offline).',
    );
  } else if (data.inventory_source === 'myst_filtered') {
    const br = data.myst_hidden_breakdown;
    const parts = [];
    if (br) {
      if (br.raro) parts.push(`${br.raro} RARO`);
      if (br.tan) parts.push(`${br.tan} tan`);
      if (br.category) parts.push(`${br.category} categoria`);
      if (br.other) parts.push(`${br.other} altro`);
    }
    showApiWarn(
      'Inventario filtrato da myst (sola lettura MySQL)' +
        (parts.length ? `: ${parts.join(', ')}` : '') +
        '. TAN mai. RARO: sì se in DB edits (show db) o EDIT+EDNomeToon.',
    );
  } else if (data.inventory_source === 'mysql_fallback') {
    showApiWarn(
      'Elenco da MySQL: myst non disponibile — selezione edit non attiva finché myst non risponde.',
    );
  } else if (data.inventory_source === 'mysql_myst_empty') {
    showApiWarn(
      'Elenco da MySQL: myst non legge character_inventory per questo PG — verifica toon_id e riavvia myst aggiornato.',
    );
  } else if (data.myst_toon_name_ok === false) {
    showApiWarn(
      'Myst non risolve il nome del PG (toon_id): edit oggetti bloccato finché il record toon è leggibile.',
    );
  }

  if (!items.length && !data.mystListOk) {
    list.innerHTML = '<li class="hint">Inventario non disponibile — verifica che myst sia avviato e EDIT_API_SECRET allineato.</li>';
    return;
  }

  renderInventoryList(items);
}

async function selectItem(inventoryId, li, { forceRefresh = false } = {}) {
  document.querySelectorAll('#inventory-list .item').forEach((el) => el.classList.remove('selected'));
  if (li) li.classList.add('selected');

  stashCurrentObjectCart();
  selectedInventoryId = inventoryId;
  restoreObjectCart(inventoryId);
  selectedObjectOptions = null;

  $('object-edits').innerHTML = '';
  if ($('object-massimali')) $('object-massimali').innerHTML = '';
  $('object-affect-slots').innerHTML = '';
  hide('object-affect-slots');
  const textBox = $('object-text-edit');
  if (textBox) textBox.innerHTML = '';
  $('quote-box').textContent = 'Caricamento…';
  setMainColumnSplit(true);
  rebuildGlobalPendingFromCarts();

  const cached = !forceRefresh ? objectOptionsCache.get(Number(inventoryId)) : null;
  let d = cached || null;
  if (!d) {
    const opts = await api('/api/object-edit-options', {
      method: 'POST',
      body: JSON.stringify({ targetToonId, inventoryId }),
    });
    if (!opts.ok) {
      $('quote-box').textContent = opts.error || 'Oggetto non editabile';
      setMainColumnSplit(false);
      return;
    }
    d = opts.data;
    objectOptionsCache.set(Number(inventoryId), d);
  }

  /* Se e' cambiato pezzo mentre aspettavamo, non applicare. */
  if (Number(selectedInventoryId) !== Number(inventoryId)) return;

  selectedObjectOptions = d;
  const quoteEl = $('quote-box');
  const lines = [
    d.owner_name ? `Owner: ${d.owner_name} (${d.owner_classes} classi, x${d.class_mult})` : '',
    d.item_type ? `Tipo: ${d.item_type}` : '',
    `Costo attuale vs prototipo: ${formatMxp(d.diff_xp_mega || 0, d.diff_xp_frac || 0)}`,
    d.diff_rune ? `Rune componente listino: ${d.diff_rune}` : '',
    cached ? 'Opzioni da cache locale (cambio pezzo senza re-fetch)' : '',
  ].filter(Boolean);
  quoteEl.innerHTML =
    `<div class="quote-name">${mudTextToHtml(d.short_desc || '')}</div>` +
    lines.map((l) => `<div>${escapeHtml(l)}</div>`).join('');

  renderObjectAffectSlots(d.affect_slots);
  renderObjectTextEdit(
    d.text_edit || {
      can_edit: true,
      requires_paid_affect: true,
      name: '',
      short_desc: '',
      description: '',
      name_max: 128,
      short_max: 128,
      long_max: 256,
      hint:
        'Gratuiti ma solo insieme al pagamento di un nuovo affect (stesso salvataggio).',
    }
  );
  const savedText = objectTextDraftsByInv.get(Number(inventoryId));
  if (savedText) {
    const nameEl = $('obj-text-name');
    const shortEl = $('obj-text-short');
    const longEl = $('obj-text-long');
    if (nameEl) {
      nameEl.value = savedText.objName || '';
      nameEl.dispatchEvent(new Event('input'));
    }
    if (shortEl) {
      shortEl.value = savedText.shortDesc || '';
      shortEl.dispatchEvent(new Event('input'));
    }
    if (longEl) {
      longEl.value = savedText.description || '';
      longEl.dispatchEvent(new Event('input'));
    }
  }
  renderObjectEdits(
    d.entries || [],
    d.dam_budget,
    d.sp_budget,
    d.sf_budget,
    d.clan_symbol === true,
  );
  rebuildGlobalPendingFromCarts();
}

function renderObjectAffectSlots(affectSlots) {
  const box = $('object-affect-slots');
  if (!affectSlots || !Array.isArray(affectSlots.slots)) {
    box.innerHTML = '';
    hide('object-affect-slots');
    return;
  }

  const maxSlots = Number(affectSlots.max_slots || affectSlots.slots.length);
  const used = Number(affectSlots.used ?? affectSlots.slots.filter((s) => !s.free).length);
  const freeCount = Number(affectSlots.free_count ?? maxSlots - used);

  box.innerHTML = '';
  const title = document.createElement('h3');
  title.textContent = 'Slot affect';
  box.appendChild(title);

  const summary = document.createElement('p');
  summary.className = 'affect-slots-summary';
  summary.textContent = `${used}/${maxSlots} occupati · ${freeCount} liberi`;
  box.appendChild(summary);
  const mergeHint = document.createElement('p');
  mergeHint.className = 'affect-slots-hint';
  mergeHint.textContent =
    'Hit-n-dam / Hit-n-sp compaiono solo se gia\' sul pezzo. Per crearli: porta hit e dam (o sp) allo stesso valore e conferma il popup di accorpamento (irreversibile).';
  box.appendChild(mergeHint);

  const grid = document.createElement('div');
  grid.className = 'affect-slots-grid';
  affectSlots.slots.forEach((slot) => {
    const row = document.createElement('div');
    row.className = slot.free ? 'affect-slot slot-free' : 'affect-slot slot-used';
    const slotNum = Number(slot.slot);
    if (slot.free) {
      row.innerHTML = `
        <span class="slot-num">#${slotNum + 1}</span>
        <span>Libero</span>
      `;
    } else {
      const loc = slot.location_name || `loc ${slot.location}`;
      const label =
        (slot.modifier_label && String(slot.modifier_label).trim()) ||
        (slot.immune_labels && String(slot.immune_labels).trim()) ||
        '';
      const shown = label || String(slot.modifier);
      let detail = `<strong>${loc}</strong> = ${shown}`;
      if (label && Number(slot.modifier) !== 0 && String(slot.modifier) !== label) {
        detail += `<br><span class="slot-hint">bit ${slot.modifier}</span>`;
      }
      row.innerHTML = `
        <span class="slot-num">#${slotNum + 1}</span>
        <span class="slot-detail">${detail}</span>
      `;
    }
    grid.appendChild(row);
  });
  box.appendChild(grid);
  show('object-affect-slots');
}

/** Location APPLY_* combat (allineati a autoenums). */
const APPLY_AC = 17;
const APPLY_HITROLL = 18;
const APPLY_DAMROLL = 19;
const APPLY_HITNDAM = 40;
const APPLY_SPELLPOWER = 65;
const APPLY_HITNSP = 66;

function isCombatAffectEntryId(id) {
  return ['hitroll', 'damroll', 'spellpower', 'hitndam', 'hitnsp'].includes(String(id || ''));
}

function baseCombatTotalsFromCatalog() {
  const entries = selectedObjectOptions?.entries || [];
  const cur = (id) => Number(entries.find((e) => e.id === id)?.current || 0);
  return {
    hr: cur('hitroll'),
    dr: cur('damroll'),
    sp: cur('spellpower'),
    hnd: cur('hitndam'),
    hnsp: cur('hitnsp'),
  };
}

/**
 * Totali assoluti combat sul pezzo (come combat_*_total lato myst):
 * hitroll/damroll/spellpower in catalogo espongono gia' i totali aggregati.
 */
function catalogCombatAbsTotals() {
  const entries = selectedObjectOptions?.entries || [];
  const cur = (id) => Number(entries.find((e) => e.id === id)?.current || 0);
  return {
    hr: cur('hitroll'),
    dam: cur('damroll'),
    sp: cur('spellpower'),
  };
}

/** Applica una voce listino combat ai totali assoluti (switch di apply_listino). */
function applyCombatListinoToAbs(totals, edit) {
  if (!edit || !totals) return totals;
  const id = String(edit.entryId || edit.id || '');
  const loc = Number(edit.location || 0);
  const t = Number(edit.targetModifier || 0);
  const next = { hr: totals.hr, dam: totals.dam, sp: totals.sp };
  const is = (name, applyLoc) => id === name || loc === applyLoc;
  if (edit.clearSlot) {
    if (is('hitroll', APPLY_HITROLL)) next.hr = 0;
    else if (is('damroll', APPLY_DAMROLL)) next.dam = 0;
    else if (is('spellpower', APPLY_SPELLPOWER)) next.sp = 0;
    else if (is('hitndam', APPLY_HITNDAM)) {
      next.hr = 0;
      next.dam = 0;
    } else if (is('hitnsp', APPLY_HITNSP)) {
      next.hr = 0;
      next.sp = 0;
    }
    return next;
  }
  if (is('hitroll', APPLY_HITROLL)) next.hr = t;
  else if (is('damroll', APPLY_DAMROLL)) next.dam = t;
  else if (is('spellpower', APPLY_SPELLPOWER)) next.sp = t;
  else if (is('hitndam', APPLY_HITNDAM)) {
    next.hr = t;
    next.dam = t;
  } else if (is('hitnsp', APPLY_HITNSP)) {
    next.hr = t;
    next.sp = t;
  }
  return next;
}

/** Proietta hr/dam/sp dopo il carrello (+ eventuale voce in aggiunta). */
function projectCombatAbsWithCart(pendingEditItem) {
  let tot = catalogCombatAbsTotals();
  const pendingId = pendingEditItem
    ? String(pendingEditItem.entryId || pendingEditItem.id || '')
    : '';
  for (const it of objectEditCart.values()) {
    if (pendingId && it.entryId === pendingId) continue;
    if (!isCombatAffectEntryId(it.entryId)) continue;
    tot = applyCombatListinoToAbs(tot, it);
  }
  if (pendingEditItem && isCombatAffectEntryId(pendingId)) {
    tot = applyCombatListinoToAbs(tot, pendingEditItem);
  }
  return tot;
}

/**
 * Armor: extra oltre proto in −40…0 (step −10).
 * Budget separato da combat/spellfail: in coda può stare insieme ad altri edit.
 */
function validateArmorForCartEdit(entry, targetModifier, clearSlot) {
  const id = String(entry?.id || '');
  const loc = Number(entry?.location || 0);
  if (id !== 'armor' && loc !== APPLY_AC) return { ok: true };
  if (clearSlot) return { ok: true };
  const proto = Number(entry.proto);
  const target = Number(targetModifier);
  if (!Number.isFinite(proto) || !Number.isFinite(target)) return { ok: true };
  const delta = target - proto;
  const minExtra = -40;
  if (delta > 0 || delta < minExtra) {
    return {
      ok: false,
      error:
        `Armor fuori tetto: extra ${delta} oltre proto ${proto} ` +
        `(consentito ${minExtra}…0; es. proto −10 + edit −40 → totale −50).`,
    };
  }
  if (delta !== 0 && delta % 10 !== 0) {
    return {
      ok: false,
      error: `Armor: step −10 non rispettato (extra ${delta}).`,
    };
  }
  return { ok: true };
}

/**
 * Spellfail: extra oltre proto in −100…0 (step −5); pezzo e personaggio
 * usano la magnitudine editata (proto − current), max 100.
 */
function validateSpellfailForCartEdit(entry, targetModifier, clearSlot) {
  const id = String(entry?.id || '');
  if (id !== 'spellfail') return { ok: true };

  const sfBudget = selectedObjectOptions?.sf_budget || {};
  const proto = Number(
    Number.isFinite(Number(entry.proto))
      ? entry.proto
      : sfBudget.piece_proto ?? 0,
  );
  let pieceDelta = 0;
  if (!clearSlot) {
    const target = Number(targetModifier);
    if (!Number.isFinite(target)) return { ok: true };
    const extra = target - proto;
    const minExtra = -100;
    if (extra > 0 || extra < minExtra) {
      return {
        ok: false,
        error:
          `Spellfail fuori tetto pezzo: extra ${extra} oltre proto ${proto} ` +
          `(consentito ${minExtra}…0, step −5).`,
      };
    }
    if (extra !== 0 && extra % 5 !== 0) {
      return {
        ok: false,
        error: `Spellfail: step −5 non rispettato (extra ${extra}).`,
      };
    }
    pieceDelta = Math.max(0, -extra);
  }

  const pieceMax = Math.abs(Number(sfBudget.piece_max ?? 100));
  if (pieceDelta > pieceMax) {
    return {
      ok: false,
      error: `Tetto pezzo spellfail superato con la coda: +${pieceDelta} (max ${pieceMax}).`,
    };
  }

  const other = Number(sfBudget.other || 0);
  const charMax = Number(sfBudget.char_max || 100);
  const charTotal = other + pieceDelta;
  if (charTotal > charMax) {
    return {
      ok: false,
      error:
        `Tetto personaggio spellfail superato con la coda: ${charTotal}/${charMax} ` +
        `(altri +${other}, questo pezzo +${pieceDelta}).`,
    };
  }
  return { ok: true, pieceDelta, charTotal };
}

/**
 * Tetti combat dopo la coda (allineati a myst). Solo massimali:
 * hit-n-sp + hitroll (o hit-n-dam + dam, ecc.) sono ammessi se il risultato
 * proiettato rispetta i tetti. Nessun blocco per "stesso canale".
 * - pezzo: dam_wiz+sp_wiz <= 2, hr_wiz <= 2 (broker escluso)
 * - personaggio: dam_full+sp_full <= 30, hr_full <= 42
 */
function validateCombatCapsForCartEdit(entry, targetModifier, clearSlot) {
  const id = String(entry?.id || '');
  if (!isCombatAffectEntryId(id)) return { ok: true };

  const damBudget = selectedObjectOptions?.dam_budget || {};
  const spBudget = selectedObjectOptions?.sp_budget || {};
  const hrBudget = selectedObjectOptions?.hr_budget || {};

  const before = catalogCombatAbsTotals();
  const after = projectCombatAbsWithCart({
    entryId: id,
    location: Number(entry.location || 0),
    targetModifier: Number(targetModifier || 0),
    clearSlot: !!clearSlot,
  });
  const dDam = after.dam - before.dam;
  const dSp = after.sp - before.sp;
  const dHr = after.hr - before.hr;

  /* Pezzo: solo quota wiz (i trasferimenti broker non consumano il tetto pezzo). */
  const curDamWiz = Number(
    damBudget.piece_wiz != null ? damBudget.piece_wiz : damBudget.piece || 0,
  );
  const curSpWiz = Number(
    spBudget.piece_wiz != null ? spBudget.piece_wiz : spBudget.piece || 0,
  );
  const curHrWiz = Number(
    hrBudget.piece_wiz != null
      ? hrBudget.piece_wiz
      : Math.max(
          0,
          before.hr -
            Number(
              (selectedObjectOptions?.entries || []).find((e) => e.id === 'hitroll')
                ?.proto || 0,
            ),
        ),
  );
  const damWiz = Math.max(0, curDamWiz + dDam);
  const spWiz = Math.max(0, curSpWiz + dSp);
  const hrWiz = Math.max(0, curHrWiz + dHr);

  /* Personaggio: delta full vs baseline (come enforce_char_*), broker incluso. */
  const curDamFull = Number(damBudget.piece_full ?? damBudget.piece ?? 0);
  const curSpFull = Number(spBudget.piece_full ?? spBudget.piece ?? 0);
  const curHrFull = Number(hrBudget.piece_full ?? hrBudget.piece ?? curHrWiz);
  const damFull = Math.max(0, curDamFull + dDam);
  const spFull = Math.max(0, curSpFull + dSp);
  const hrFull = Math.max(0, curHrFull + dHr);

  const pieceDamSpMax = Number(
    damBudget.piece_dam_sp_max ?? spBudget.piece_dam_sp_max ?? 2,
  );
  const pieceHrMax = Number(damBudget.piece_hr_max ?? hrBudget.piece_max ?? 2);
  const charDamSpMax = Number(
    damBudget.char_dam_sp_max ?? spBudget.char_dam_sp_max ?? 30,
  );
  const charHrMax = Number(hrBudget.char_max ?? 42);
  const otherDam = Number(damBudget.other || 0);
  const otherSp = Number(spBudget.other || 0);
  const otherHr = Number(hrBudget.other || 0);
  const pieceDamSp = damWiz + spWiz;
  const charDamSp = otherDam + otherSp + damFull + spFull;
  const charHr = otherHr + hrFull;

  if (pieceDamSp > pieceDamSpMax) {
    return {
      ok: false,
      error:
        `Tetto pezzo DAM+SP (wiz) superato con la coda: dam +${damWiz} + sp +${spWiz} = ${pieceDamSp} (max ${pieceDamSpMax}). ` +
        `Ok: hit-n-sp 1 + dam 1; non ok: hit-n-sp 2 + dam 2 / hit-n-dam 2 + sp 1.`,
    };
  }
  if (hrWiz > pieceHrMax) {
    return {
      ok: false,
      error: `Tetto pezzo hitroll (wiz) superato con la coda: +${hrWiz} (max ${pieceHrMax}).`,
    };
  }
  if (charDamSp > charDamSpMax) {
    return {
      ok: false,
      error:
        `Tetto personaggio DAM+SP superato con la coda: ${charDamSp}/${charDamSpMax} ` +
        `(altri dam +${otherDam} sp +${otherSp}, questo pezzo dam +${damFull} sp +${spFull}).`,
    };
  }
  if (hrBudget.char_max != null && charHr > charHrMax) {
    return {
      ok: false,
      error:
        `Tetto personaggio hitroll superato con la coda: ${charHr}/${charHrMax} ` +
        `(altri +${otherHr}, questo pezzo +${hrFull}).`,
    };
  }
  return {
    ok: true,
    damWiz,
    spWiz,
    hrWiz,
    damFull,
    spFull,
    hrFull,
    pieceDamSp,
    charDamSp,
  };
}

/** Validazione coda: armor, spellfail, combat — solo massimali. */
function validateCartCapsForEdit(entry, targetModifier, clearSlot) {
  const armor = validateArmorForCartEdit(entry, targetModifier, clearSlot);
  if (!armor.ok) return armor;
  const sf = validateSpellfailForCartEdit(entry, targetModifier, clearSlot);
  if (!sf.ok) return sf;
  return validateCombatCapsForCartEdit(entry, targetModifier, clearSlot);
}

/** Applica un edit combat ai totali previsti (stessa semantica di rewrite_combat_totals). */
function applyCombatEditToTotals(state, edit) {
  if (!edit) return state;
  const id = String(edit.entryId || edit.id || '');
  const loc = Number(edit.location || 0);
  const t = Number(edit.targetModifier || 0);
  const next = { ...state };
  if (edit.clearSlot) {
    if (id === 'hitroll' || loc === APPLY_HITROLL) next.hr = 0;
    else if (id === 'damroll' || loc === APPLY_DAMROLL) next.dr = 0;
    else if (id === 'spellpower' || loc === APPLY_SPELLPOWER) next.sp = 0;
    else if (id === 'hitndam' || loc === APPLY_HITNDAM) {
      next.hr = 0;
      next.dr = 0;
      next.hnd = 0;
    } else if (id === 'hitnsp' || loc === APPLY_HITNSP) {
      next.hr = 0;
      next.sp = 0;
      next.hnsp = 0;
    }
    return next;
  }
  if (id === 'hitroll' || loc === APPLY_HITROLL) next.hr = t;
  else if (id === 'damroll' || loc === APPLY_DAMROLL) next.dr = t;
  else if (id === 'spellpower' || loc === APPLY_SPELLPOWER) next.sp = t;
  else if (id === 'hitndam' || loc === APPLY_HITNDAM) {
    next.hr = t;
    next.dr = t;
    next.hnd = t;
  } else if (id === 'hitnsp' || loc === APPLY_HITNSP) {
    next.hr = t;
    next.sp = t;
    next.hnsp = t;
  }
  return next;
}

/**
 * Se questo edit renderebbe hr==dr o hr==sp con slot ancora separati,
 * restituisce 'hitndam' | 'hitnsp' (da chiedere conferma). Null altrimenti.
 * Hit-n-dam / Hit-n-sp scelti esplicitamente non chiedono (già combinati).
 *
 * Nota: si puo' avere Hit-n-sp + dam (o Hit-n-dam + sp) entro i tetti pezzo;
 * non serve che l'altro asse sia 0 per proporre l'accorpamento.
 */
function combatMergeOfferForEdit(entry, targetModifier, clearSlot) {
  const id = String(entry?.id || '');
  if (!isCombatAffectEntryId(id) || clearSlot) return null;
  if (id === 'hitndam' || id === 'hitnsp') return null;

  let state = baseCombatTotalsFromCatalog();
  for (const it of objectEditCart.values()) {
    if (it.entryId === id) continue;
    if (!isCombatAffectEntryId(it.entryId)) continue;
    state = applyCombatEditToTotals(state, it);
  }
  state = applyCombatEditToTotals(state, {
    entryId: id,
    location: Number(entry.location || 0),
    targetModifier,
    clearSlot: false,
  });

  const canHnd = state.hr > 0 && state.hr === state.dr && state.hnd <= 0;
  const canHnsp = state.hr > 0 && state.hr === state.sp && state.hnsp <= 0;

  /* Solo il lato che stai editando: evita di chiedere Hit-n-dam mentre alzi lo SP. */
  if (id === 'damroll') return canHnd ? 'hitndam' : null;
  if (id === 'spellpower') return canHnsp ? 'hitnsp' : null;
  if (id === 'hitroll') {
    if (canHnd && !canHnsp) return 'hitndam';
    if (canHnsp && !canHnd) return 'hitnsp';
    if (canHnd && canHnsp) {
      /* hr==dam==sp: preferisci il lato che ha gia' lo slot dedicato. */
      if (state.dr > 0 && state.sp <= 0) return 'hitndam';
      if (state.sp > 0 && state.dr <= 0) return 'hitnsp';
      return 'hitndam';
    }
  }
  return null;
}

function confirmCombatMerge(kind) {
  if (kind === 'hitndam') {
    return confirm(
      'Accorpare Hitroll e Damroll in un unico slot Hit-n-dam?\n\n' +
        'L\'accorpamento libera uno slot affect ma NON è reversibile: ' +
        'dopo non potrai più separarli.\n\n' +
        'OK = accorpa (Hit-n-dam)\n' +
        'Annulla = mantieni Hitroll e Damroll su slot distinti'
    );
  }
  if (kind === 'hitnsp') {
    return confirm(
      'Accorpare Hitroll e Spellpower in un unico slot Hit-n-sp?\n\n' +
        'L\'accorpamento libera uno slot affect ma NON è reversibile: ' +
        'dopo non potrai più separarli.\n\n' +
        'OK = accorpa (Hit-n-sp)\n' +
        'Annulla = mantieni Hitroll e Spellpower su slot distinti'
    );
  }
  return false;
}

function objectEntryAffectsDam(entry) {
  const id = String(entry?.id || '');
  return id === 'damroll' || id === 'hitndam';
}

function objectEntryAffectsSpellpower(entry) {
  const id = String(entry?.id || '');
  return id === 'spellpower' || id === 'hitnsp';
}

function objectEditSection(id) {
  if (id === 'artifact' || id.startsWith('flag.')) return 'Artifact';
  if (id.startsWith('reward.')) return 'Bonus nativi Dimensione';
  if (id.startsWith('native.')) return 'Bonus nativi pezzo';
  if (id.startsWith('resist.') || id.startsWith('immune.')) {
    return 'Resistenze';
  }
  if (id.startsWith('immunity.') || id.startsWith('m_immune.')) {
    return 'Immunità';
  }
  if (id.startsWith('spell.')) return 'Spell';
  if (['armor', 'spellfail'].includes(id)) return "Bonus all'Armatura/Cast";
  if (['hitndam', 'hitnsp', 'hitroll', 'damroll', 'spellpower'].includes(id)) {
    return 'Bonus in Combattimento';
  }
  return 'Caratteristiche';
}

/** Ordine sezioni oggetto (listino / UI). */
const OBJECT_EDIT_SECTION_ORDER = [
  'Artifact',
  'Bonus nativi Dimensione',
  'Bonus nativi pezzo',
  "Bonus all'Armatura/Cast",
  'Caratteristiche',
  'Bonus in Combattimento',
  'Immunità',
  'Resistenze',
  'Spell',
];

/**
 * Sezioni temporaneamente nascoste (WIP / non affidabili).
 * Vuoto: hit/dam/spellpower di nuovo disponibili.
 */
const OBJECT_EDIT_SECTIONS_HIDDEN = new Set();

function objectEditSectionRank(name) {
  const i = OBJECT_EDIT_SECTION_ORDER.indexOf(name);
  return i >= 0 ? i : 99;
}

/**
 * Opzioni listino.
 * relative=true: min/max sono extra oltre proto (es. armor −40…0, hit +0…+2);
 * i valori nel select sono totali assoluti (proto + extra).
 * Con un bonus gia' presente non si offrono valori peggiorativi (solo migliorie
 * o «Rimuovi slot»); con un malus si puo' andare a 0 / verso il bonus.
 */
function objectEntryValueFloor(entry) {
  const floor = Number(entry?.value_floor ?? entry?.combat_floor);
  return Number.isFinite(floor) ? floor : null;
}

function objectEntryProtoBase(entry) {
  const pe = Number(entry?.proto_effective);
  if (Number.isFinite(pe)) return pe;
  return Number(entry?.proto || 0);
}

function buildObjectScalarOptions(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const absStep = Math.abs(Number(entry.step)) || 1;
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const opts = [];
  if (entry.relative) {
    /* Proto effettivo (hitndam: max assi proto, non solo slot combinato). */
    const proto = objectEntryProtoBase(entry);
    for (let d = lo; d <= hi; d += absStep) {
      opts.push(proto + d);
    }
  } else {
    for (let v = lo; v <= hi; v += absStep) {
      opts.push(v);
    }
  }
  /* Solo add: niente totali sotto i bonus gia' presenti sul pezzo. */
  const floor = objectEntryValueFloor(entry);
  if (floor != null && !objectScalarLowerIsBetter(entry)) {
    return opts.filter((v) => v >= floor);
  }
  return opts;
}

/** Armor/spellfail: piu' basso = meglio. Altri scalar: piu' alto = meglio. */
function objectScalarLowerIsBetter(entry) {
  const id = String(entry?.id || '');
  return id === 'armor' || id === 'spellfail';
}

function objectScalarIsPositiveBonus(entry, current) {
  const proto = objectEntryProtoBase(entry);
  if (objectScalarLowerIsBetter(entry)) {
    /* AC/spellfail: gia' al proto o meglio → niente dial-up verso il malus. */
    return current <= proto;
  }
  return current > proto;
}

/** Filtra opzioni: niente dial-down di un bonus (serve «Rimuovi slot»). */
function filterObjectScalarOptions(entry, values, current) {
  const floor = objectEntryValueFloor(entry);
  const effectiveCurrent =
    floor != null && floor > Number(current || 0) ? floor : current;
  if (!objectScalarIsPositiveBonus(entry, effectiveCurrent)) {
    return values;
  }
  const lowerBetter = objectScalarLowerIsBetter(entry);
  return values.filter((v) => {
    if (v === current || v === effectiveCurrent) return true;
    return lowerBetter ? v < effectiveCurrent : v > effectiveCurrent;
  });
}

/**
 * Combat: togli dal menu i totali che sforano i tetti pezzo/PG (es. SP +2
 * con hit-n-dam gia' +1 → pezzo dam+sp wiz = 3 > 2).
 */
function filterCombatBudgetOptions(entry, values, current) {
  const id = String(entry?.id || '');
  if (!isCombatAffectEntryId(id)) return values;
  return values.filter((v) => {
    if (v === current) return true;
    return validateCombatCapsForCartEdit(entry, v, false).ok;
  });
}

function formatScalarOptionLabel(entry, absolute, currentForDelta) {
  const cur =
    currentForDelta != null
      ? Number(currentForDelta)
      : Number(entry?.current || 0);
  const floor = objectEntryValueFloor(entry);
  const base =
    floor != null && floor > cur && !objectScalarLowerIsBetter(entry) ? floor : cur;
  if (objectScalarLowerIsBetter(entry)) {
    if (absolute === base) return `${absolute} (attuale)`;
    const d = absolute - base;
    if (d < 0) return `${absolute} (${d})`;
    return String(absolute);
  }
  if (absolute === base) {
    return `${absolute} (attuale)`;
  }
  const d = absolute - base;
  if (d > 0) return `${absolute} (+${d})`;
  return String(absolute);
}

/** Immunità (`m_immune`) e resistenze (`immune`) sono sì/no, non scalari. */
function isYesNoObjectEntry(entry) {
  const kind = entry?.kind || '';
  return (
    kind === 'immune' ||
    kind === 'm_immune' ||
    kind === 'flag' ||
    kind === 'spell'
  );
}

function objectEntryCostHint(entry) {
  if (entry.kind === 'flag' && entry.flag === 'artifact') {
    const mxp = Number(entry.mxp || 0);
    if (Number(entry.current || 0) === 1) {
      return 'Artifact permanente (gia\' attivo)';
    }
    if (mxp > 0) {
      return `Listino Artifact: ${mxp} ${currencyLabel('mxp')} (x class_mult, senza +50%)`;
    }
    return entry.hint || 'Costo listino Artifact';
  }
  const mxp = Number(entry.mxp_per_step || 0);
  const rune = Number(entry.rune_per_step ?? mxp);
  const step = Number(entry.step) || 1;
  if (!mxp) return '';
  if (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell') {
    return `Listino: ${mxp} ${currencyLabel('mxp')} o ${rune} ${currencyLabel('rune')}`;
  }
  if (Math.abs(step) !== 1) {
    return `Listino: ${mxp} ${currencyLabel('mxp')} o ${rune} ${currencyLabel('rune')} / step ${step}`;
  }
  return `Listino: ${mxp} ${currencyLabel('mxp')} o ${rune} ${currencyLabel('rune')} / punto`;
}

/**
 * I valori selezionabili sono già nel menu a tendina: non ripetere range
 * tecnici tipo «extra 0…3 oltre proto». Solo step ≠ 1 se utile.
 */
function objectEntryRangeLabel(entry) {
  if (
    entry.kind === 'immune' ||
    entry.kind === 'm_immune' ||
    entry.kind === 'spell' ||
    entry.kind === 'flag'
  ) {
    return '';
  }
  const step = Number(entry.step) || 1;
  if (Math.abs(step) !== 1) {
    return ` (step ${step})`;
  }
  return '';
}

function objectEntrySlotHint(entry) {
  const slotIdx = Number(entry.occupied_slot);
  if (entry.kind === 'immune' || entry.kind === 'm_immune') {
    const noun = entry.kind === 'm_immune' ? 'immunità' : 'resistenza';
    if (entry.has_affect && slotIdx >= 0) {
      return `slot #${slotIdx + 1} (${noun} presente)`;
    }
    if (entry.can_add) {
      return entry.kind === 'm_immune'
        ? 'nuova immunità (slot APPLY_M_IMMUNE)'
        : 'nuova resistenza (slot APPLY_IMMUNE)';
    }
    return 'nessuno slot libero';
  }
  if (entry.kind === 'spell') {
    if (entry.has_affect && slotIdx >= 0) {
      return `slot #${slotIdx + 1} (spell presente)`;
    }
    if (entry.can_add) return 'nuova spell (usa slot APPLY_SPELL)';
    return 'nessuno slot libero';
  }
  if (entry.has_affect && slotIdx >= 0) {
    return `slot #${slotIdx + 1} occupato`;
  }
  if (entry.can_add) return 'nuovo bonus (usa uno slot libero)';
  return 'nessuno slot libero';
}

function objectAlreadyArtifact() {
  const entries = selectedObjectOptions?.entries;
  if (!Array.isArray(entries)) return false;
  const art = entries.find((e) => e.kind === 'flag' && e.flag === 'artifact');
  return Number(art?.current || 0) === 1;
}

function cartAddsArtifact() {
  return [...objectEditCart.values()].some(
    (it) => it.flag === 'artifact' && Number(it.targetModifier) === 1
  );
}

/**
 * Maggiorazione artifact_mult sugli affect: pezzo gia' Artifact oppure
 * Artifact in coda (la voce flag Artifact ha costo proprio, senza +50%).
 */
function objectPricingUsesArtifact() {
  return objectAlreadyArtifact() || cartAddsArtifact();
}

function clearObjectPending(entryId) {
  objectCartRequoteGen += 1;
  const removed = objectEditCart.get(entryId);
  if (objectEditCart.has(entryId)) {
    objectEditCart.delete(entryId);
  }
  if (selectedInventoryId) {
    if (objectEditCart.size) {
      objectCartsByInv.set(Number(selectedInventoryId), new Map(objectEditCart));
    } else {
      objectCartsByInv.delete(Number(selectedInventoryId));
    }
  }
  if (removed?.flag === 'artifact') {
    requoteObjectCartForArtifact();
    return;
  }
  rebuildObjectPendingFromCart();
}

function clearObjectEditCart({ resetSelectors = false, allPieces = false } = {}) {
  if (allPieces) {
    clearAllObjectCarts({ resetSelectors });
  } else {
    if (resetSelectors) {
      objectEditCart.forEach((it) => {
        if (it.selectEl && it.selectEl.dataset.current != null) {
          it.selectEl.value = it.selectEl.dataset.current;
        }
      });
    }
    objectEditCart.clear();
    if (selectedInventoryId) {
      objectCartsByInv.delete(Number(selectedInventoryId));
      objectTextDraftsByInv.delete(Number(selectedInventoryId));
    }
  }
  rebuildGlobalPendingFromCarts();
}

function rebuildObjectPendingFromCart() {
  syncArtifactLineInCart(objectEditCart);
  if (selectedInventoryId) {
    if (objectEditCart.size) {
      objectCartsByInv.set(Number(selectedInventoryId), new Map(objectEditCart));
    } else {
      objectCartsByInv.delete(Number(selectedInventoryId));
    }
  }
  rebuildGlobalPendingFromCarts();
}

async function requoteObjectCartForArtifact() {
  await ensureListinoSnapshot();
  const gen = ++objectCartRequoteGen;
  const useArt = objectPricingUsesArtifact();
  const entryIds = [...objectEditCart.keys()];
  for (const entryId of entryIds) {
    if (gen !== objectCartRequoteGen) return;
    const it = objectEditCart.get(entryId);
    if (!it || it.flag === 'artifact') continue;
    const payload = {
      targetToonId,
      inventoryId: selectedInventoryId,
      location: Number(it.location || 0),
      targetModifier: it.targetModifier,
      pendingArtifact: useArt,
      current: Number(it.quote?.current ?? it.entry?.current ?? 0),
    };
    if (it.clearSlot) payload.clearSlot = true;
    if (it.allowCombatMerge) payload.allowCombatMerge = true;
    if (it.flag) payload.flag = it.flag;
    const data = await api('/api/quote-object-edit', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (gen !== objectCartRequoteGen) return;
    if (!objectEditCart.has(entryId)) continue;
    if (!data.ok) continue;
    const live = objectEditCart.get(entryId);
    if (!live) continue;
    enrichObjectQuoteMeta(data.data, { pendingArtifact: useArt });
    live.quote = data.data;
    objectEditCart.set(entryId, live);
  }
  if (gen !== objectCartRequoteGen) return;
  syncArtifactLineInCart(objectEditCart);
  rebuildObjectPendingFromCart();
}

function getObjectTextDraft() {
  const nameEl = $('obj-text-name');
  const shortEl = $('obj-text-short');
  const longEl = $('obj-text-long');
  if (!nameEl || !shortEl || !longEl) return null;
  return {
    objName: nameEl.value,
    shortDesc: shortEl.value,
    description: longEl.value,
    nameMax: Number(nameEl.dataset.max || 128),
    shortMax: Number(shortEl.dataset.max || 128),
    longMax: Number(longEl.dataset.max || 256),
  };
}

function objectTextDraftIsDirty(draft) {
  if (!draft || !selectedObjectOptions?.text_edit) return false;
  const t = selectedObjectOptions.text_edit;
  return (
    draft.objName !== String(t.name || '') ||
    draft.shortDesc !== String(t.short_desc || '') ||
    draft.description !== String(t.description || '')
  );
}

function objectCartHasPaidAffect(items) {
  return items.some((it) => {
    if (it.flag === 'artifact') return false;
    const xp = Number(it.quote?.xp_raw || it.quote?.diff_xp_raw || 0);
    const rune = Number(it.quote?.diff_rune || it.quote?.pq || 0);
    return xp > 0 || rune > 0;
  });
}

function renderObjectTextEdit(textEdit) {
  const box = $('object-text-edit');
  if (!box) return;
  box.innerHTML = '';
  if (!textEdit) {
    return;
  }
  /* Ignora can_edit dal myst: i campi sono sempre digitabili (non limited).
   * Il salvataggio avviene solo con un affect pagato nello stesso apply. */
  const canEdit = session.role !== 'limited';
  const nameMax = Number(textEdit.name_max || 128);
  const shortMax = Number(textEdit.short_max || 128);
  const longMax = Number(textEdit.long_max || 256);

  const details = document.createElement('details');
  details.className = 'edit-section';
  details.open = true;
  const summary = document.createElement('summary');
  summary.className = 'edit-section-summary';
  summary.innerHTML = '<span class="edit-section-name">Sezione String</span>';
  details.appendChild(summary);

  const body = document.createElement('div');
  body.className = 'edit-section-body object-text-edit';
  if (!canEdit) {
    const locked = document.createElement('p');
    locked.className = 'hint';
    locked.textContent =
      'Tier limited: name/short/long non modificabili.';
    body.appendChild(locked);
    details.appendChild(body);
    box.appendChild(details);
    return;
  }

  const hint = document.createElement('p');
  hint.className = 'hint';
  hint.textContent =
    textEdit.hint ||
    'Gratuiti ma solo insieme al pagamento di un nuovo affect (stesso salvataggio). Non si salvano da soli.';
  body.appendChild(hint);

  const fields = [
    {
      key: 'name',
      id: 'obj-text-name',
      label: 'Name (keywords)',
      max: nameMax,
      value: textEdit.name || '',
      multiline: false,
    },
    {
      key: 'short',
      id: 'obj-text-short',
      label: 'Short description',
      max: shortMax,
      value: textEdit.short_desc || '',
      multiline: false,
    },
    {
      key: 'long',
      id: 'obj-text-long',
      label: 'Long description',
      max: longMax,
      value: textEdit.description || '',
      multiline: true,
    },
  ];

  fields.forEach((f) => {
    const row = document.createElement('div');
    row.className = 'text-edit-row';
    const lab = document.createElement('label');
    lab.textContent = f.label;
    lab.setAttribute('for', f.id);
    const counter = document.createElement('span');
    counter.className = 'text-len-counter';
    const preview = document.createElement('div');
    preview.className = 'text-preview';
    let input;
    if (f.multiline) {
      input = document.createElement('textarea');
      input.rows = 3;
    } else {
      input = document.createElement('input');
      input.type = 'text';
    }
    input.id = f.id;
    input.value = f.value;
    input.dataset.max = String(f.max);
    const sync = () => {
      const n = input.value.length;
      const max = Number(input.dataset.max);
      counter.textContent = `${n}/${max}`;
      counter.classList.toggle('over', n > max);
      preview.innerHTML = mudTextToHtml(input.value) || '<span class="hint">(vuoto)</span>';
    };
    input.addEventListener('input', sync);
    sync();
    row.appendChild(lab);
    row.appendChild(counter);
    row.appendChild(input);
    row.appendChild(preview);
    body.appendChild(row);
  });

  details.appendChild(body);
  box.appendChild(details);
}

function massimaleUsageClass(total, max) {
  const t = Number(total);
  const m = Number(max);
  if (!(m > 0) || !Number.isFinite(t)) return '';
  const pct = (Math.max(0, t) / m) * 100;
  if (pct <= 30) return 'massimale-usage-low';
  if (pct <= 70) return 'massimale-usage-mid';
  return 'massimale-usage-high';
}

function setMainColumnSplit(active) {
  const col = document.querySelector('.main-column');
  if (!col) return;
  col.classList.toggle('main-column--split', !!active);
}

function renderMassimaliPanel(box, damBudget, spBudget, sfBudget, isClanSymbol) {
  const host = $('object-massimali') || box;
  if (!host) return;
  if (host !== box) host.innerHTML = '';

  const panel = document.createElement('div');
  panel.className = 'massimali-panel';

  const title = document.createElement('h3');
  title.className = 'massimali-title';
  title.textContent = 'Massimali editabili';
  panel.appendChild(title);

  const grid = document.createElement('div');
  grid.className = 'massimali-grid';

  if (damBudget || spBudget) {
    const card = document.createElement('div');
    card.className = 'massimale-card';
    const damTotal = Number(damBudget?.char_total || 0);
    const spTotal = Number(spBudget?.char_total || 0);
    const combined =
      damBudget?.char_dam_sp_total != null
        ? Number(damBudget.char_dam_sp_total)
        : spBudget?.char_dam_sp_total != null
          ? Number(spBudget.char_dam_sp_total)
          : damTotal + spTotal;
    const max = Number(
      damBudget?.char_dam_sp_max ??
        spBudget?.char_dam_sp_max ??
        damBudget?.char_max ??
        spBudget?.char_max ??
        30,
    );
    const remaining =
      damBudget?.char_remaining != null
        ? Number(damBudget.char_remaining)
        : spBudget?.char_remaining != null
          ? Number(spBudget.char_remaining)
          : Math.max(0, max - combined);
    const usage = massimaleUsageClass(combined, max);
    const pieceDamSpMax = Number(
      damBudget?.piece_dam_sp_max ?? spBudget?.piece_dam_sp_max ?? 2,
    );
    const pieceMaxDam = Number(damBudget?.piece_max || 2);
    const pieceMaxSp = Number(spBudget?.piece_max || 2);
    const pcDam = Number(damBudget?.piece_current);
    const ppDam = Number(damBudget?.piece_proto);
    const deltaDam = Number(damBudget?.piece || 0);
    const pcSp = Number(spBudget?.piece_current);
    const deltaSp = Number(spBudget?.piece || 0);
    const details = [];
    details.push(
      `Pool personaggio: Dam ${damTotal} + Spellpower ${spTotal} = ${combined}/${max} (ancora ${remaining})`,
    );
    if (damBudget && Number.isFinite(pcDam) && Number.isFinite(ppDam)) {
      let d = `Dam pezzo: ${pcDam} vs proto ${ppDam} (delta +${deltaDam}) · max canale ${pieceMaxDam}/pezzo`;
      if (damBudget.piece_edit === false) {
        d += ' · non conteggiato (serve EDIT + owner; clan esclusi)';
      }
      details.push(d);
    }
    if (spBudget && Number.isFinite(pcSp)) {
      details.push(
        `Spellpower pezzo: totale ${pcSp} (delta edit +${deltaSp}) · max canale ${pieceMaxSp}/pezzo`,
      );
    }
    details.push(
      `Sul pezzo dam e spellpower possono coesistere: somma delta wiz <= ${pieceDamSpMax} (es. hit-n-sp 1 + dam 1).`,
    );
    const notes = [
      `Tetti: pezzo dam+sp <= ${pieceDamSpMax}; personaggio dam+sp <= ${max}. La coda rispetta gli stessi limiti.`,
    ];
    card.innerHTML = `
      <div class="massimale-label">DAM+SP totale editato</div>
      <div class="massimale-value ${usage}">${combined}<span class="massimale-max"> / ${max}</span></div>
      <div class="massimale-detail">${details.map((t) => escapeHtml(t)).join('<br>')}</div>
      ${notes.map((n) => `<div class="massimale-note">${escapeHtml(n)}</div>`).join('')}
    `;
    grid.appendChild(card);
  }

  if (sfBudget) {
    const card = document.createElement('div');
    card.className = 'massimale-card';
    const total = Number(sfBudget.char_total || 0);
    const max = Number(sfBudget.char_max || 100);
    const pieceMax = Math.abs(Number(sfBudget.piece_max || 40));
    const pc = Number(sfBudget.piece_current);
    const pp = Number(sfBudget.piece_proto);
    const delta = Number(sfBudget.piece || 0);
    const stepMag = Math.abs(Number(sfBudget.step || 5));
    const mxpStep = Number(sfBudget.mxp_per_step || 20);
    const usage = massimaleUsageClass(total, max);
    let detail = `Step −${stepMag}, ${mxpStep} MXP/step · max ${pieceMax} spellfail editato per pezzo`;
    if (Number.isFinite(pc) && Number.isFinite(pp)) {
      detail = `Questo pezzo: ${pc} vs proto ${pp} (delta +${delta}) · step −${stepMag}, ${mxpStep} MXP/step`;
    }
    card.innerHTML = `
      <div class="massimale-label">Spellfail totale editato</div>
      <div class="massimale-value ${usage}">${total}<span class="massimale-max"> / ${max}</span></div>
      <div class="massimale-detail">${escapeHtml(detail)}</div>
    `;
    grid.appendChild(card);
  }

  {
    const card = document.createElement('div');
    card.className = 'massimale-card massimale-clan';
    const yn = isClanSymbol ? 'Y' : 'N';
    card.innerHTML = `
      <div class="massimale-label">Simbolo del clan</div>
      <div class="massimale-value massimale-yn ${isClanSymbol ? 'is-yes' : 'is-no'}">${yn}</div>
      <div class="massimale-detail">${
        isClanSymbol
          ? 'Questo oggetto è un simbolo di clan'
          : 'Questo oggetto non è un simbolo di clan'
      }</div>
    `;
    grid.appendChild(card);
  }

  panel.appendChild(grid);

  const contrib =
    damBudget && Array.isArray(damBudget.contributors)
      ? damBudget.contributors.filter((c) => Number(c.delta) > 0)
      : [];
  if (contrib.length) {
    const wrap = document.createElement('div');
    wrap.className = 'massimali-contributors';
    const sub = document.createElement('div');
    sub.className = 'massimali-contributors-title';
    sub.textContent = 'Contributi dam (pezzi EDIT in possesso)';
    wrap.appendChild(sub);
    const ul = document.createElement('ul');
    contrib.forEach((c) => {
      const li = document.createElement('li');
      li.innerHTML =
        `<span class="effect-name">${mudTextToHtml(c.short_desc || 'oggetto')}</span>` +
        `<span class="massimale-detail">+${Number(c.delta)} (ora ${Number(c.current)}, proto ${Number(c.proto)})</span>`;
      ul.appendChild(li);
    });
    wrap.appendChild(ul);
    panel.appendChild(wrap);
  }

  host.appendChild(panel);
}

function renderObjectEdits(entries, damBudget, spBudget, sfBudget, isClanSymbol) {
  const box = $('object-edits');
  box.innerHTML = '';
  const massHost = $('object-massimali');
  if (massHost) massHost.innerHTML = '';

  if (!entries.length) {
    box.innerHTML = '<p class="hint">Nessun campo editabile su questo oggetto.</p>';
    setMainColumnSplit(!!selectedInventoryId);
    return;
  }
  if (session.role === 'limited') {
    box.innerHTML = '<p class="hint">Tier limited: edit oggetto non consentito.</p>';
    setMainColumnSplit(!!selectedInventoryId);
    return;
  }

  /* Dam/SP massimali legati a «Bonus in Combattimento» (editing armi): nascosti se la sezione e' off. */
  const combatHidden = OBJECT_EDIT_SECTIONS_HIDDEN.has('Bonus in Combattimento');
  renderMassimaliPanel(
    box,
    combatHidden ? null : damBudget,
    combatHidden ? null : spBudget,
    sfBudget,
    !!isClanSymbol,
  );

  const editsWrap = document.createElement('div');
  editsWrap.className = 'object-edit-groups';
  const editsTitle = document.createElement('h3');
  editsTitle.className = 'object-edit-groups-title';
  editsTitle.textContent = 'Opzioni di edit';
  editsWrap.appendChild(editsTitle);

  const filterRow = document.createElement('div');
  filterRow.className = 'object-edit-filter';
  const filterInput = document.createElement('input');
  filterInput.type = 'search';
  filterInput.placeholder = 'Filtra opzioni…';
  filterInput.setAttribute('aria-label', 'Filtra opzioni di edit');
  filterRow.appendChild(filterInput);
  editsWrap.appendChild(filterRow);
  const filterHint = document.createElement('p');
  filterHint.className = 'object-edit-filter-hint';
  filterHint.textContent =
    'Sezioni chiuse di default: aprine una o usa il filtro. Slot affect / String / Massimali restano a sinistra.';
  editsWrap.appendChild(filterHint);

  const hasHitNDam = entries.some(
    (e) =>
      (e.id === 'hitndam' || Number(e.location) === APPLY_HITNDAM) &&
      (e.has_affect || Number(e.current) !== 0)
  );
  const hasHitNSp = entries.some(
    (e) =>
      (e.id === 'hitnsp' || Number(e.location) === APPLY_HITNSP) &&
      (e.has_affect || Number(e.current) !== 0)
  );

  const grouped = new Map();
  entries.forEach((entry) => {
    /* CON non e' nel listino ufficiale — non mostrare anche se myst vecchio lo manda. */
    if (entry.id === 'con' || Number(entry.location) === 5) return;
    const id = String(entry.id || '');
    const loc = Number(entry.location || 0);
    /* Hit-n-dam/sp: solo se gia' sul pezzo (proto o edit). Merge = popup su hr/dam/sp. */
    if (
      (id === 'hitndam' || loc === APPLY_HITNDAM) &&
      !entry.has_affect &&
      Number(entry.current) === 0
    ) {
      return;
    }
    if (
      (id === 'hitnsp' || loc === APPLY_HITNSP) &&
      !entry.has_affect &&
      Number(entry.current) === 0
    ) {
      return;
    }
    if (hasHitNDam && (id === 'hitroll' || id === 'damroll' || loc === APPLY_HITROLL || loc === APPLY_DAMROLL)) {
      return;
    }
    if (hasHitNSp && (id === 'hitroll' || id === 'spellpower' || loc === APPLY_HITROLL || loc === APPLY_SPELLPOWER)) {
      return;
    }
    const section = objectEditSection(entry.id || '');
    if (OBJECT_EDIT_SECTIONS_HIDDEN.has(section)) return;
    if (!grouped.has(section)) grouped.set(section, []);
    grouped.get(section).push(entry);
  });

  const sectionNames = [...grouped.keys()].sort(
    (a, b) => objectEditSectionRank(a) - objectEditSectionRank(b) || a.localeCompare(b, 'it')
  );

  const sectionEls = [];

  sectionNames.forEach((section) => {
    const list = grouped.get(section) || [];
    list.sort((a, b) =>
      String(a.label || a.id || '').localeCompare(String(b.label || b.id || ''), 'it', {
        sensitivity: 'base',
      })
    );

    const details = document.createElement('details');
    details.className = 'edit-section';
    const sectionHasPresent = list.some((e) => e.has_affect || Number(e.current) !== 0);
    details.open = sectionHasPresent;

    const summary = document.createElement('summary');
    summary.className = 'edit-section-summary';
    summary.innerHTML =
      `<span class="edit-section-name">${escapeHtml(section)}</span>` +
      `<span class="edit-section-count">${list.length}</span>`;
    details.appendChild(summary);

    const body = document.createElement('div');
    body.className = 'edit-section-body';

    list.forEach((entry) => {
      const current = Number(entry.current || 0);
      const canEdit = entry.can_edit !== false;
      const row = document.createElement('div');
      row.className = canEdit ? 'edit-row' : 'edit-row edit-row-disabled';
      row.dataset.cartKey = entry.id;
      row.dataset.filterText = `${entry.label || ''} ${entry.id || ''} ${section}`.toLowerCase();
      const select = document.createElement('select');
      select.disabled = !canEdit || session.role === 'limited';
      select.dataset.current = String(current);

      const canClearYesNo =
        (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell') &&
        (entry.can_clear_slot || entry.has_affect) &&
        current === 1 &&
        canEdit &&
        session.role !== 'limited';

      if (isYesNoObjectEntry(entry)) {
        if (canClearYesNo) {
          const keep = document.createElement('option');
          keep.value = '1';
          keep.textContent = 'Sì';
          keep.selected = true;
          select.appendChild(keep);
          const clearOpt = document.createElement('option');
          clearOpt.value = '__clear__';
          clearOpt.textContent = 'No, rimuovi dallo slot';
          select.appendChild(clearOpt);
        } else {
          [
            { v: 0, l: 'No' },
            { v: 1, l: 'Sì' },
          ].forEach(({ v, l }) => {
            const opt = document.createElement('option');
            opt.value = v;
            opt.textContent = l;
            if (v === current) opt.selected = true;
            select.appendChild(opt);
          });
          if (entry.kind === 'flag' && entry.flag === 'artifact' && current === 1) {
            select.disabled = true;
          }
        }
      } else if (entry.clear_only) {
        const keep = document.createElement('option');
        keep.value = String(current);
        keep.textContent = formatScalarOptionLabel(entry, current);
        keep.selected = true;
        select.appendChild(keep);
        if (entry.can_clear_slot && canEdit && session.role !== 'limited') {
          const clearOpt = document.createElement('option');
          clearOpt.value = '__clear__';
          clearOpt.textContent = 'Rimuovi slot (gratis)';
          select.appendChild(clearOpt);
        }
      } else {
        let values = buildObjectScalarOptions(entry);
        const floorKeep = objectEntryValueFloor(entry);
        const canKeepCurrent =
          objectScalarLowerIsBetter(entry) ||
          floorKeep == null ||
          current >= floorKeep;
        if (!values.includes(current) && canKeepCurrent) values.push(current);
        values = filterObjectScalarOptions(entry, values, current);
        if (!objectScalarLowerIsBetter(entry) && floorKeep != null) {
          values = values.filter((v) => v >= floorKeep);
        }
        values = filterCombatBudgetOptions(entry, values, current);
        values.sort((a, b) => a - b);
        if (entry.can_clear_slot && canEdit && session.role !== 'limited') {
          const clearOpt = document.createElement('option');
          clearOpt.value = '__clear__';
          clearOpt.textContent = 'Rimuovi slot (gratis)';
          select.appendChild(clearOpt);
        }
        values.forEach((v) => {
          const opt = document.createElement('option');
          opt.value = v;
          opt.textContent = formatScalarOptionLabel(entry, v, current);
          if (v === current) opt.selected = true;
          select.appendChild(opt);
        });
      }

      if (!canEdit) {
        select.disabled = true;
      }

      const queuedObj = objectEditCart.get(entry.id);
      if (queuedObj && queuedObj.targetModifier != null && !select.disabled) {
        if (queuedObj.clearSlot) {
          select.value = '__clear__';
        } else if (isYesNoObjectEntry(entry)) {
          select.value = Number(queuedObj.targetModifier) ? '1' : '0';
        } else {
          select.value = String(queuedObj.targetModifier);
        }
        queuedObj.selectEl = select;
      }

      select.addEventListener('change', () => {
        if (!canEdit) return;
        if (select.value === '__clear__') {
          if (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell') {
            const bit =
              entry.kind === 'spell'
                ? Number(entry.spell_bit)
                : Number(entry.immune_bit);
            queueObjectQuote(entry, bit, select, { clearSlot: true });
            return;
          }
          queueObjectQuote(entry, 0, select, { clearSlot: true });
          return;
        }
        const newVal = Number(select.value);
        if (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell') {
          if (newVal === current) {
            clearObjectPending(entry.id);
            return;
          }
          const bit =
            entry.kind === 'spell'
              ? Number(entry.spell_bit)
              : Number(entry.immune_bit);
          queueObjectQuote(entry, newVal ? bit : 0, select);
        } else if (entry.kind === 'flag') {
          if (entry.flag === 'artifact' && newVal === 0 && current === 1) {
            select.value = '1';
            return;
          }
          if (newVal === current) {
            clearObjectPending(entry.id);
            return;
          }
          queueObjectQuote(entry, newVal, select);
        } else if (newVal === current) {
          clearObjectPending(entry.id);
        } else {
          queueObjectQuote(entry, newVal, select);
        }
      });

      const yesNoKind = isYesNoObjectEntry(entry);
      const proto = Number(entry.proto);
      const showProto =
        entry.relative && Number.isFinite(proto) && entry.kind === 'scalar';
      const meta = document.createElement('div');
      meta.innerHTML = `
        <label class="effect-name">${escapeHtml(entry.label || entry.id)}${escapeHtml(objectEntryRangeLabel(entry))}</label>
        <div class="current">Attuale: ${
          yesNoKind
            ? current
              ? 'Sì'
              : 'No'
            : entry.relative
              ? formatScalarOptionLabel(entry, current)
              : current
        }${showProto ? ` · proto ${proto}` : ''}</div>
        <div class="slot-hint">${
          entry.kind === 'flag' ? escapeHtml(entry.hint || '') : escapeHtml(objectEntrySlotHint(entry))
        }</div>
        ${
          entry.kind !== 'flag'
            ? `<div class="cost-hint">${escapeHtml(objectEntryCostHint(entry))}</div>`
            : ''
        }
      `;
      row.appendChild(meta);
      row.appendChild(select);
      body.appendChild(row);
    });

    details.appendChild(body);
    editsWrap.appendChild(details);
    sectionEls.push(details);
  });

  filterInput.addEventListener('input', () => {
    const q = filterInput.value.trim().toLowerCase();
    sectionEls.forEach((details) => {
      let visible = 0;
      details.querySelectorAll('.edit-row').forEach((row) => {
        const match = !q || (row.dataset.filterText || '').includes(q);
        row.classList.toggle('hidden', !match);
        if (match) visible += 1;
      });
      details.classList.toggle('hidden', visible === 0);
      if (q && visible > 0) details.open = true;
      const countEl = details.querySelector('.edit-section-count');
      if (countEl) {
        const total = details.querySelectorAll('.edit-row').length;
        countEl.textContent = q ? `${visible}/${total}` : String(total);
      }
    });
  });

  box.appendChild(editsWrap);
  setMainColumnSplit(true);
  updateObjectCartUI();
}

async function queueObjectQuote(entry, targetModifier, selectEl, opts = {}) {
  const clearSlot = !!opts.clearSlot;
  const caps = validateCartCapsForEdit(entry, targetModifier, clearSlot);
  if (!caps.ok) {
    alert(caps.error || 'Tetto / coda non valida');
    if (selectEl) {
      selectEl.value = selectEl.dataset.current || String(Number(entry.current || 0));
    }
    return;
  }
  let allowCombatMerge = !!opts.allowCombatMerge;
  if (opts.allowCombatMerge == null && !clearSlot) {
    const mergeKind = combatMergeOfferForEdit(entry, targetModifier, clearSlot);
    if (mergeKind) {
      allowCombatMerge = confirmCombatMerge(mergeKind);
    }
  }
  const payload = {
    targetToonId,
    inventoryId: selectedInventoryId,
    location: Number(entry.location || 0),
    targetModifier,
    /* Verita' display da opzioni myst: evita current=0 su pezzi solo-proto. */
    current: Number(entry.current || 0),
  };
  if (clearSlot) payload.clearSlot = true;
  if (allowCombatMerge) payload.allowCombatMerge = true;
  if (entry.kind === 'flag' && entry.flag) {
    payload.flag = entry.flag;
  }
  const addingThisArtifact =
    entry.kind === 'flag' &&
    entry.flag === 'artifact' &&
    Number(targetModifier) === 1;
  /* artifact_mult sugli affect se pezzo Artifact o Artifact in coda (non sulla voce flag). */
  if (!addingThisArtifact && (objectAlreadyArtifact() || cartAddsArtifact())) {
    payload.pendingArtifact = true;
  }

  let qd = null;
  if (addingThisArtifact && !clearSlot) {
    await ensureListinoSnapshot();
    qd = localArtifactQuote(selectedObjectOptions, entry);
  }
  if (!qd) {
    const data = await api('/api/quote-object-edit', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (!data.ok) {
      alert(data.error || 'Quote oggetto fallita');
      if (selectEl) {
        selectEl.value = selectEl.dataset.current || String(Number(entry.current || 0));
      }
      clearObjectPending(entry.id);
      return;
    }
    qd = data.data;
  }
  enrichObjectQuoteMeta(qd, {
    pendingArtifact: !!payload.pendingArtifact,
  });
  const yesNo = isYesNoObjectEntry(entry);
  const curLabel = yesNo
    ? qd.current
      ? 'Sì'
      : 'No'
    : entry.relative
      ? formatScalarOptionLabel(entry, Number(qd.current))
      : qd.current;
  const tgtLabel = clearSlot
    ? 'slot libero'
    : yesNo
      ? qd.target
        ? 'Sì'
        : 'No'
      : entry.relative
        ? formatScalarOptionLabel(entry, Number(qd.target))
        : qd.target;
  let label = `${entry.label}: ${curLabel} → ${tgtLabel}`;
  if (qd.malus_split) {
    const mXp = Number(qd.malus_part?.xp_raw || qd.malus_part?.diff_xp_raw || 0);
    const bXp = Number(qd.bonus_part?.xp_raw || qd.bonus_part?.diff_xp_raw || 0);
    label += ` [malus→0 ${formatQuoteCostShort({ xp_raw: mXp })} 2x + bonus ${formatQuoteCostShort({ xp_raw: bXp })}]`;
  }
  if (allowCombatMerge && isCombatAffectEntryId(entry.id)) {
    label += ' (accorpamento combat)';
  }
  ensureObjectCartExclusive();
  const wasAddingArtifact = cartAddsArtifact();
  objectEditCart.set(entry.id, {
    entryId: entry.id,
    location: Number(entry.location || 0),
    targetModifier,
    clearSlot,
    allowCombatMerge,
    flag: entry.kind === 'flag' ? entry.flag : undefined,
    label,
    quote: qd,
    selectEl,
    entry,
    artifactBundled: false,
  });
  const nowAddingArtifact = cartAddsArtifact();
  if (wasAddingArtifact !== nowAddingArtifact || nowAddingArtifact || addingThisArtifact) {
    await requoteObjectCartForArtifact();
  } else {
    syncArtifactLineInCart(objectEditCart);
    rebuildObjectPendingFromCart();
  }
}

/**
 * Costruisce gli step /api/apply-batch da pendingEdit (checkout globale).
 * Artifact per pezzo prima degli altri affect; testo pezzo sul primo affect pagato.
 */
function buildCheckoutBatchSteps(logoutAfter) {
  stashCurrentObjectCart();
  const runePct = Number($('pay-rune-pct').value);
  const mode = syncPayModeFromSlider();
  const items = Array.isArray(pendingEdit.items)
    ? [...pendingEdit.items]
    : pendingEdit.type === 'object' ||
        pendingEdit.type === 'pool' ||
        pendingEdit.type === 'resistance' ||
        pendingEdit.type === 'char-affect'
      ? [pendingEdit]
      : [];
  if (!items.length) return { ok: false, error: 'carrello vuoto' };

  /* Valida bozze testo per ogni pezzo coinvolto. */
  const byInv = new Map();
  for (const item of items) {
    if (item.type === 'pool' || item.type === 'resistance') continue;
    const invId = Number(item.inventoryId || selectedInventoryId);
    if (!byInv.has(invId)) byInv.set(invId, []);
    byInv.get(invId).push(item);
  }
  for (const [invId, invItems] of byInv.entries()) {
    let draft =
      Number(invId) === Number(selectedInventoryId)
        ? getObjectTextDraft()
        : objectTextDraftsByInv.get(Number(invId)) || null;
    if (!draft) continue;
    const opts = objectOptionsCache.get(Number(invId));
    const baseline = opts?.text_edit;
    const dirty =
      Number(invId) === Number(selectedInventoryId)
        ? objectTextDraftIsDirty(draft)
        : baseline
          ? draft.objName !== String(baseline.name || '') ||
            draft.shortDesc !== String(baseline.short_desc || '') ||
            draft.description !== String(baseline.description || '')
          : true;
    if (!dirty) continue;
    const nameMax = Number(draft.nameMax || baseline?.name_max || 128);
    const shortMax = Number(draft.shortMax || baseline?.short_max || 128);
    const longMax = Number(draft.longMax || baseline?.long_max || 256);
    if (
      String(draft.objName || '').length > nameMax ||
      String(draft.shortDesc || '').length > shortMax ||
      String(draft.description || '').length > longMax
    ) {
      return {
        ok: false,
        error: `Name/short/long troppo lunghi su ${inventoryShortLabel(invId)}`,
      };
    }
    if (!objectCartHasPaidAffect(invItems)) {
      return {
        ok: false,
        error: `Name/short/long su ${inventoryShortLabel(
          invId
        )}: serve un affect pagato nello stesso pacchetto (non solo Artifact).`,
      };
    }
  }

  const steps = [];
  const textAttachedForInv = new Set();

  const objectItems = items.filter(
    (it) =>
      it.type === 'object' ||
      (it.type !== 'pool' &&
        it.type !== 'resistance' &&
        it.type !== 'char-affect' &&
        (it.inventoryId != null || it.location != null))
  );
  const charItems = items.filter(
    (it) => it.type === 'pool' || it.type === 'resistance' || it.type === 'char-affect'
  );

  /* Espandi malus→bonus in due step; Artifact prima, poi malus→0, poi resto. */
  const phaseRank = (p) =>
    p === 'artifact' ? 0 : p === 'malus' ? 1 : p === 'bonus' ? 2 : 3;
  const expanded = [];
  for (const item of objectItems) {
    if (item.type === 'pool' || item.type === 'resistance') continue;
    if (item.flag === 'artifact') {
      expanded.push({ item, phase: 'artifact', target: item.targetModifier, quote: item.quote });
    } else if (
      item.quote?.malus_split &&
      item.quote.malus_part &&
      item.quote.bonus_part &&
      !item.clearSlot
    ) {
      expanded.push({
        item,
        phase: 'malus',
        target: 0,
        quote: item.quote.malus_part,
      });
      expanded.push({
        item,
        phase: 'bonus',
        target: item.targetModifier,
        quote: item.quote.bonus_part,
      });
    } else {
      expanded.push({
        item,
        phase: 'normal',
        target: item.targetModifier,
        quote: item.quote,
      });
    }
  }
  expanded.sort((a, b) => {
    const ia = Number(a.item.inventoryId || 0);
    const ib = Number(b.item.inventoryId || 0);
    if (ia !== ib) return ia - ib;
    return phaseRank(a.phase) - phaseRank(b.phase);
  });

  for (const { item, phase, target, quote: partQuote } of expanded) {
    const invId = Number(item.inventoryId || selectedInventoryId);
    const itemPlan = buildPaymentPlan(partQuote || item.quote, mode, runePct);
    const affectBody = {
      target_toon_id: targetToonId,
      inventory_id: invId,
      location: item.location,
      target_modifier: target,
      pay_xp: itemPlan.payXp,
      pay_rune: itemPlan.payRune,
    };
    if (item.clearSlot && phase === 'normal') affectBody.clear_slot = 1;
    if (item.allowCombatMerge) affectBody.allow_combat_merge = 1;
    if (item.flag) affectBody.flag = item.flag;
    if (item.flag === 'artifact' && (item.artifactBundled || item.quote?.artifact_bundled)) {
      /* In pacchetto con affect: flag gratis; il +50% e' sugli affect. */
      affectBody.waive_artifact_fee = 1;
      affectBody.pay_xp = 0;
      affectBody.pay_rune = 0;
    }
    if (item.flag !== 'artifact' && item.usesArtifactPricing) {
      affectBody.pending_artifact = 1;
    }
    const isPaidAffect =
      item.flag !== 'artifact' &&
      (Number(partQuote?.xp_raw || partQuote?.diff_xp_raw || item.quote?.xp_raw || 0) > 0 ||
        Number(partQuote?.diff_rune || partQuote?.pq || item.quote?.diff_rune || 0) > 0);
    if (isPaidAffect && !textAttachedForInv.has(invId)) {
      let draft =
        Number(invId) === Number(selectedInventoryId)
          ? getObjectTextDraft()
          : objectTextDraftsByInv.get(Number(invId)) || null;
      const opts = objectOptionsCache.get(Number(invId));
      const baseline = opts?.text_edit;
      const dirty = draft
        ? Number(invId) === Number(selectedInventoryId)
          ? objectTextDraftIsDirty(draft)
          : baseline
            ? draft.objName !== String(baseline.name || '') ||
              draft.shortDesc !== String(baseline.short_desc || '') ||
              draft.description !== String(baseline.description || '')
            : true
        : false;
      if (dirty && draft) {
        affectBody.obj_name = draft.objName;
        affectBody.short_desc = draft.shortDesc;
        affectBody.description = draft.description;
        textAttachedForInv.add(invId);
      }
    }
    const phaseLabel =
      phase === 'malus'
        ? `${item.label} [malus→0]`
        : phase === 'bonus'
          ? `${item.label} [bonus]`
          : item.label;
    steps.push({
      path: 'affect',
      body: affectBody,
      label: phaseLabel,
    });
  }

  for (const item of charItems) {
    const itemPlan = buildPaymentPlan(item.quote, mode, runePct);
    if (item.type === 'pool') {
      steps.push({
        path: 'pool',
        body: {
          target_toon_id: targetToonId,
          field: item.field,
          new_value: item.newValue,
          pay_xp: itemPlan.payXp,
          pay_rune: itemPlan.payRune,
        },
        label: item.label,
      });
    } else if (item.type === 'resistance') {
      steps.push({
        path: 'resistance',
        body: {
          target_toon_id: targetToonId,
          damage_type: item.damageType,
          value: item.value,
          pay_xp: itemPlan.payXp,
          pay_rune: itemPlan.payRune,
        },
        label: item.label,
      });
    } else if (item.type === 'char-affect') {
      steps.push({
        path: 'char-affect',
        body: {
          target_toon_id: targetToonId,
          location: item.location,
          new_value: item.newValue,
          pay_xp: itemPlan.payXp,
          pay_rune: itemPlan.payRune,
        },
        label: item.label,
      });
    }
  }

  if (!steps.length) return { ok: false, error: 'nessuno step da applicare' };
  return { ok: true, steps, logoutAfter: !!logoutAfter };
}

async function confirmPayEdit(logoutAfter = false) {
  if (!pendingEdit || !pendingEdit.plan) return;

  const targetName = charState?.name || 'personaggio';
  const isStaffOnOther =
    session.role === 'staff' && Number(targetToonId) !== Number(session.sessionToonId);

  const actionLabel = logoutAfter ? 'Applica e logout' : 'Applica tutto';
  const confirmRune =
    Number(pendingEdit.plan.payRune) > 0
      ? ` + ${pendingEdit.plan.payRune} ${currencyLabel('rune')}`
      : '';
  const msg1 = `${actionLabel} — confermi il pagamento per:\n${pendingEdit.label}\n\nTotale: ${pendingEdit.plan.payXp.toLocaleString('it-IT')} XP (MXP)${confirmRune}`;
  if (!confirm(msg1)) return;

  if (isStaffOnOther) {
    const msg2 = `STAFF: stai applicando un edit sul target "${targetName}" (toon ${targetToonId}). Confermi?`;
    if (!confirm(msg2)) return;
  }

  if (pendingEdit.type === 'object-text') {
    alert(
      'Name/short/long non si salvano da soli: metti in coda un affect pagato e conferma il pagamento.'
    );
    return;
  }

  const built = buildCheckoutBatchSteps(logoutAfter);
  if (!built.ok) {
    alert(built.error || 'Pacchetto non valido');
    return;
  }

  const result = await apiApply(
    '/api/apply-batch',
    {
      targetToonId,
      logoutAfter: !!logoutAfter,
      steps: built.steps,
    },
    logoutAfter ? 'Applica e logout' : 'Applica tutto',
  );

  if (result.ok) {
    const n = built.steps.length;
    $('apply-result').textContent = logoutAfter
      ? `Pacchetto applicato (${n} edit) — sessione edit chiusa.`
      : `Pacchetto applicato (${n} edit).`;
    const invId = selectedInventoryId;
    clearAllObjectCarts();
    characterEditCart.clear();
    objectOptionsCache.clear();
    pendingEdit = null;
    updatePaymentUI();

    if (logoutAfter) {
      await api('/api/deselect-toon', { method: 'POST' }).catch(() => {});
      targetToonId = null;
      clearTargetWorkspace('');
      await refreshMe();
      return;
    }

    await ensureToonEditSnapshot(true);
    await loadCharacterState();
    await loadInventory();
    if (invId) {
      const li = document.querySelector('#inventory-list .item.selected');
      await selectItem(invId, li || null, { forceRefresh: true });
    } else {
      renderCharacterEdits();
    }
    if (targetToonId) {
      api(`/api/toon-overview/${targetToonId}`).catch(() => {});
    }
  } else {
    const ver =
      result.portal_api_version != null ? ` [api v${result.portal_api_version}]` : '';
    const msg = (result.error || 'Apply fallito') + ver;
    $('apply-result').textContent = msg;
    alert(msg);
  }
}

$('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('login-error').textContent = '';
  const email = $('login-email').value.trim();
  const password = $('login-password').value;
  const remember = $('login-remember').checked;
  const data = await api('/api/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  if (!data.ok) {
    $('login-error').textContent = data.error || 'login fallito';
    return;
  }
  persistLogin(email, password, remember);
  await refreshMe();
});

$('btn-logout').onclick = async () => {
  stopEditSessionTouch();
  await api('/api/logout', { method: 'POST' });
  targetToonId = null;
  const search = $('target-toon-search');
  if (search) search.value = '';
  const instSearch = $('inst-search');
  if (instSearch) instSearch.value = '';
  const instList = $('inst-list');
  if (instList) instList.innerHTML = '';
  clearTargetWorkspace('');
  await refreshMe();
};

$('btn-change-toon').onclick = async () => {
  stopEditSessionTouch();
  await api('/api/deselect-toon', { method: 'POST' });
  pendingEdit = null;
  targetToonId = null;
  const search = $('target-toon-search');
  if (search) search.value = '';
  clearTargetWorkspace('');
  await refreshMe();
};

$('btn-refresh-inv').onclick = () => {
  objectOptionsCache.clear();
  loadInventory();
};

(function initInventorySort() {
  const sel = $('inventory-sort');
  if (!sel) return;
  try {
    const saved = localStorage.getItem(INVENTORY_SORT_KEY);
    if (saved && [...sel.options].some((o) => o.value === saved)) {
      sel.value = saved;
    }
  } catch {
    /* ignore */
  }
  sel.onchange = () => {
    persistInventorySortMode(sel.value);
    if (inventoryItemsCache.length) {
      renderInventoryList(inventoryItemsCache);
    }
  };
})();

if ($('pay-mode')) $('pay-mode').onchange = updatePaymentUI;
if ($('pay-tender')) $('pay-tender').onchange = updatePaymentUI;
if ($('pay-rune-pct')) $('pay-rune-pct').oninput = updatePaymentUI;
$('btn-pay-edit').onclick = () => confirmPayEdit(false);
const btnPayLogout = $('btn-pay-edit-logout');
if (btnPayLogout) {
  btnPayLogout.onclick = () => confirmPayEdit(true);
}

const btnResetChar = $('btn-reset-char-edits');
if (btnResetChar) {
  btnResetChar.onclick = () => {
    clearCharacterEditCart({ resetSelectors: true });
    if ($('apply-result')) $('apply-result').textContent = '';
  };
}
function resetObjectEditsToSelection() {
  clearObjectEditCart({ resetSelectors: true, allPieces: false });
  const t = selectedObjectOptions?.text_edit;
  if (t) {
    const nameEl = $('obj-text-name');
    const shortEl = $('obj-text-short');
    const longEl = $('obj-text-long');
    if (nameEl) {
      nameEl.value = t.name || '';
      nameEl.dispatchEvent(new Event('input'));
    }
    if (shortEl) {
      shortEl.value = t.short_desc || '';
      shortEl.dispatchEvent(new Event('input'));
    }
    if (longEl) {
      longEl.value = t.description || '';
      longEl.dispatchEvent(new Event('input'));
    }
  }
  if ($('apply-result')) $('apply-result').textContent = '';
}

const btnResetObj = $('btn-reset-object-edits');
if (btnResetObj) {
  btnResetObj.onclick = () => resetObjectEditsToSelection();
}

/** Slug ITEM_* — allineato a edit_system_config.cpp (fallback se myst vecchio). */
const PORTAL_TYPE_DEFS = [
  { slug: 'light', label: 'Light' },
  { slug: 'scroll', label: 'Scroll' },
  { slug: 'wand', label: 'Wand' },
  { slug: 'staff', label: 'Staff' },
  { slug: 'weapon', label: 'Weapon', defaultOn: true },
  { slug: 'fireweapon', label: 'Fire weapon' },
  { slug: 'missile', label: 'Missile' },
  { slug: 'treasure', label: 'Treasure', defaultOn: true },
  { slug: 'armor', label: 'Armor', defaultOn: true },
  { slug: 'potion', label: 'Potion' },
  { slug: 'worn', label: 'Worn (medaglie, amuleti, bracciali)', defaultOn: true },
  { slug: 'other', label: 'Other' },
  { slug: 'trash', label: 'Trash' },
  { slug: 'trap', label: 'Trap' },
  { slug: 'container', label: 'Container' },
  { slug: 'note', label: 'Note' },
  { slug: 'drinkcon', label: 'Drink container' },
  { slug: 'key', label: 'Key' },
  { slug: 'food', label: 'Food' },
  { slug: 'money', label: 'Money' },
  { slug: 'pen', label: 'Pen' },
  { slug: 'boat', label: 'Boat' },
  { slug: 'audio', label: 'Audio' },
  { slug: 'board', label: 'Board' },
  { slug: 'tree', label: 'Tree' },
  { slug: 'rock', label: 'Rock' },
  { slug: 'm_gem', label: 'Mineral gem' },
  { slug: 'm_mineral', label: 'Mineral' },
  { slug: 'bar', label: 'Bar' },
  { slug: 'jewel', label: 'Jewel', defaultOn: true },
  { slug: 'clan_symbol', label: 'Clan symbol' },
];

function portalTypesFromLegacyPortal(portal) {
  const types = { ...(portal.types || {}) };
  if (portal.armor !== undefined) types.armor = portal.armor !== false;
  if (portal.weapon !== undefined) types.weapon = portal.weapon !== false;
  return types;
}

function buildPortalTypeCatalog(portal) {
  const types = portalTypesFromLegacyPortal(portal);
  if (portal.type_catalog && portal.type_catalog.length) {
    return portal.type_catalog;
  }
  return PORTAL_TYPE_DEFS.map((row) => ({
    slug: row.slug,
    label: row.label,
    enabled: types[row.slug] !== undefined ? types[row.slug] : row.defaultOn === true,
  }));
}

async function checkMystPortalVersion() {
  const warnEl = $('myst-version-warn');
  if (!warnEl) return;
  try {
    const res = await fetch(portalUrl('/api/health'));
    const health = await res.json();
    const ver = health?.myst?.portal_api_version;
    const ui = health?.ui_build;
    if (ui != null && $('header-meta') && !session) {
      $('header-meta').textContent = `UI build ${ui}`;
    }
    if (ver === undefined || ver < 3) {
      warnEl.textContent =
        'Myst non aggiornato (portal_api_version ' +
        (ver ?? 'mancante') +
        '). Salva categorie disabilitato finché non esegui: ./scripts/mud-dev.sh rebuild-myst';
      show('myst-version-warn');
    } else {
      hide('myst-version-warn');
    }
  } catch {
    warnEl.textContent = 'Impossibile verificare la versione API myst.';
    show('myst-version-warn');
  }
}

async function loadSystemConfig() {
  await loadEditCapabilities();
  const data = await api('/api/staff/system-config');
  if (!data.ok) {
    $('config-result').textContent = data.error || 'errore';
    return;
  }
  const cfg = data.data?.config || data.data;
  $('system-config-editor').value = JSON.stringify(cfg, null, 2);
  $('config-result').textContent = `path: ${data.data?.path || 'mudroot/lib/edit_system.json'}`;
  applyPortalCategoriesToUI(cfg?.object_portal || {});
  applyCurrenciesToUI(cfg?.currencies || {});
  await checkMystPortalVersion();
}

function applyCurrenciesToUI(currencies) {
  portalCurrencies = normalizeCurrencies(currencies);
  const container = $('portal-currency-toggles');
  if (!container) return;
  container.innerHTML = '';

  const primary = portalCurrencies.filter((c) => c.slug === 'mxp' || c.slug === 'rune');
  const extras = portalCurrencies.filter((c) => c.slug !== 'mxp' && c.slug !== 'rune');

  const renderRow = (row, host) => {
    const wrap = document.createElement('div');
    wrap.className =
      'currency-config-row' + (row.visible ? '' : ' currency-config-row--hidden');
    wrap.dataset.slug = row.slug;

    const title = document.createElement('div');
    title.className = 'currency-config-title';
    const name = document.createElement('strong');
    name.textContent = row.label;
    const slug = document.createElement('code');
    slug.textContent = row.slug;
    title.appendChild(name);
    title.appendChild(document.createTextNode(' '));
    title.appendChild(slug);
    if (!row.visible) {
      const badge = document.createElement('span');
      badge.className = 'currency-badge';
      badge.textContent = 'nascosta ai PG';
      title.appendChild(badge);
    }
    wrap.appendChild(title);

    const labelInput = document.createElement('label');
    labelInput.className = 'field-label';
    labelInput.textContent = 'Etichetta';
    const inputName = document.createElement('input');
    inputName.type = 'text';
    inputName.dataset.field = 'label';
    inputName.value = row.label;
    labelInput.appendChild(inputName);
    wrap.appendChild(labelInput);

    const flags = document.createElement('div');
    flags.className = 'currency-config-flags';
    [
      ['enabled', 'Abilitata'],
      ['visible', 'Visibile ai giocatori'],
      ['pays_listino', 'Paga listino'],
    ].forEach(([field, lab]) => {
      const labEl = document.createElement('label');
      labEl.className = 'checkbox-row';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.dataset.field = field;
      cb.checked = !!row[field];
      const payable = payableTenderSlugs();
      if (field === 'pays_listino') {
        if (!payable.has(row.slug)) {
          cb.checked = false;
          cb.disabled = true;
          labEl.title =
            'Myst non dichiara questo tender in edit-capabilities: non puo pagare il listino.';
        } else {
          cb.checked = true;
          cb.disabled = false;
        }
      }
      labEl.appendChild(cb);
      labEl.appendChild(document.createTextNode(` ${lab}`));
      flags.appendChild(labEl);
    });
    if (!payableTenderSlugs().has(row.slug)) {
      const note = document.createElement('p');
      note.className = 'hint currency-myst-note';
      note.textContent =
        'Solo UI: myst non scala questa valuta. Per abilitare pays_listino serve un tender in edit-capabilities.';
      wrap.appendChild(note);
    }
    wrap.appendChild(flags);
    host.appendChild(wrap);
  };

  primary.forEach((row) => renderRow(row, container));

  const extrasWrap = document.createElement('details');
  extrasWrap.className = 'currency-extras collapse-panel';
  extrasWrap.open = false;
  const sum = document.createElement('summary');
  sum.className = 'collapse-summary';
  sum.innerHTML =
    '<span>Valute aggiuntive (nascoste ai giocatori)</span>' +
    '<span class="collapse-hint">attiva «Visibile ai giocatori» per mostrarle</span>';
  extrasWrap.appendChild(sum);
  const body = document.createElement('div');
  body.className = 'collapse-body';
  const hint = document.createElement('p');
  hint.className = 'hint';
  hint.textContent =
    'Gold / Token / Credito: solo UI finche myst non le espone come tender. Quando arriveranno, il pagamento sara sempre valuta + rune (bilanciamento dedicato).';
  body.appendChild(hint);
  extras.forEach((row) => renderRow(row, body));

  const addForm = document.createElement('div');
  addForm.className = 'currency-add-form';
  const addTitle = document.createElement('h4');
  addTitle.textContent = 'Aggiungi valuta';
  addForm.appendChild(addTitle);

  const addFields = document.createElement('div');
  addFields.className = 'currency-add-fields';

  const slugLab = document.createElement('label');
  slugLab.className = 'field-label';
  slugLab.textContent = 'Slug (a-z, 0-9, _)';
  const slugInput = document.createElement('input');
  slugInput.type = 'text';
  slugInput.autocomplete = 'off';
  slugInput.placeholder = 'es. platinum';
  slugLab.appendChild(slugInput);
  addFields.appendChild(slugLab);

  const newLabelLab = document.createElement('label');
  newLabelLab.className = 'field-label';
  newLabelLab.textContent = 'Etichetta';
  const newLabelInput = document.createElement('input');
  newLabelInput.type = 'text';
  newLabelInput.autocomplete = 'off';
  newLabelInput.placeholder = 'es. Platino';
  newLabelLab.appendChild(newLabelInput);
  addFields.appendChild(newLabelLab);
  addForm.appendChild(addFields);

  const addResult = document.createElement('p');
  addResult.className = 'currency-add-result msg';

  const addBtn = document.createElement('button');
  addBtn.type = 'button';
  addBtn.className = 'btn-secondary';
  addBtn.textContent = 'Aggiungi valuta';
  addBtn.onclick = () => {
    addResult.textContent = '';
    addResult.className = 'currency-add-result msg';
    const slug = slugInput.value.trim().toLowerCase();
    const label = newLabelInput.value.trim();
    if (!/^[a-z0-9_]+$/.test(slug)) {
      addResult.textContent =
        'Slug non valido: usa solo lettere minuscole, cifre e underscore.';
      addResult.classList.add('error');
      return;
    }
    if (slug === 'mxp' || slug === 'rune') {
      addResult.textContent = 'MXP e Rune sono già nella sezione principale.';
      addResult.classList.add('error');
      return;
    }
    if (portalCurrencies.some((c) => c.slug === slug)) {
      addResult.textContent = 'Slug già presente.';
      addResult.classList.add('error');
      return;
    }
    if (!label) {
      addResult.textContent = 'Inserisci un\'etichetta.';
      addResult.classList.add('error');
      return;
    }
    const row = {
      slug,
      label,
      enabled: false,
      visible: false,
      pays_listino: false,
    };
    portalCurrencies.push(row);
    renderRow(row, body);
    extrasWrap.open = true;
    slugInput.value = '';
    newLabelInput.value = '';
    addResult.textContent = `Valuta «${slug}» aggiunta (salva per persistere).`;
    addResult.classList.add('ok');
  };
  addForm.appendChild(addBtn);
  addForm.appendChild(addResult);
  body.appendChild(addForm);

  extrasWrap.appendChild(body);
  container.appendChild(extrasWrap);

  refreshPayModeLabels();
}

function currenciesFromUI() {
  const payable = payableTenderSlugs();
  const catalog = [];
  document.querySelectorAll('#portal-currency-toggles .currency-config-row').forEach((row) => {
    const slug = row.dataset.slug;
    if (!slug) return;
    const labelEl = row.querySelector('input[data-field="label"]');
    const enabledEl = row.querySelector('input[data-field="enabled"]');
    const visibleEl = row.querySelector('input[data-field="visible"]');
    const paysEl = row.querySelector('input[data-field="pays_listino"]');
    catalog.push({
      slug,
      label: (labelEl?.value || slug).trim() || slug,
      enabled: !!enabledEl?.checked,
      visible: !!visibleEl?.checked,
      pays_listino: payable.has(slug) && !!paysEl?.checked,
    });
  });
  return {
    catalog,
    comment:
      'Valute portale. visible=false = nascosta ai player. pays_listino solo se tender in edit-capabilities; mix sempre valuta+rune.',
  };
}

function refreshPayModeLabels() {
  rebuildPayTenderSelect();
  const tenderSel = $('pay-tender');
  const rune = currencyLabel('rune');
  const tenderLab =
    tenderSel?.selectedOptions?.[0]?.textContent || currencyLabel('mxp');
  const pct = Number($('pay-rune-pct')?.value || 0);
  const hint = document.querySelector('.payment-dock-hint');
  if (hint) {
    let payHint;
    if (pct <= 0) {
      payHint = escapeHtml(tenderLab);
    } else if (pct >= 100) {
      payHint = escapeHtml(rune);
    } else {
      payHint = `${escapeHtml(tenderLab)} + ${escapeHtml(rune)} (${pct}% ${escapeHtml(
        rune
      )})`;
    }
    hint.innerHTML = `Costo sul <strong>personaggio target</strong> (${payHint}).`;
  }
  updateCapabilitiesStaffHint();
}

function applyPortalCategoriesToUI(portal) {
  const container = $('portal-category-toggles');
  if (!container) return;
  const types = portalTypesFromLegacyPortal(portal);
  const catalog = buildPortalTypeCatalog(portal);
  container.innerHTML = '';
  if (!catalog.length) {
    container.innerHTML = '<p class="hint">Nessuna categoria — ricarica config.</p>';
    return;
  }
  catalog.forEach((row) => {
    const label = document.createElement('label');
    label.className = 'checkbox-row';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.dataset.slug = row.slug;
    const fromTypes = types[row.slug];
    input.checked =
      fromTypes !== undefined ? fromTypes : row.enabled !== false;
    label.appendChild(input);
    label.appendChild(document.createTextNode(` ${row.label || row.slug}`));
    container.appendChild(label);
  });
}

function portalCategoriesFromUI() {
  const types = {};
  document.querySelectorAll('#portal-category-toggles input[data-slug]').forEach((input) => {
    types[input.dataset.slug] = input.checked;
  });
  return {
    types,
    comment:
      'types: slug ITEM_* — spunta = primo edit. EDIT/DB edits (show db) restano per ri-edit (anche RARO). TAN mai.',
  };
}

$('btn-load-config').onclick = () => loadSystemConfig();

$('btn-save-portal-currencies').onclick = async () => {
  const resultEl = $('portal-currency-result');
  if (resultEl) resultEl.textContent = '';
  let config;
  try {
    config = JSON.parse($('system-config-editor').value);
  } catch {
    try {
      const data = await api('/api/staff/system-config');
      config = data.data?.config || data.data || { version: 1, entries: [] };
    } catch {
      config = { version: 1, entries: [] };
    }
  }
  config.currencies = currenciesFromUI();
  portalCurrencies = normalizeCurrencies(config.currencies);
  $('system-config-editor').value = JSON.stringify(config, null, 2);
  const data = await api('/api/staff/system-config', {
    method: 'POST',
    body: JSON.stringify({ config }),
  });
  if (!data.ok) {
    if (resultEl) resultEl.textContent = data.error || 'salvataggio fallito';
    return;
  }
  refreshPayModeLabels();
  if (resultEl) {
    resultEl.textContent =
      'Valute salvate. Le voci non visibili restano nascoste ai player.';
  }
};

$('btn-save-portal-cats').onclick = async () => {
  $('portal-cat-result').textContent = '';
  let config;
  try {
    config = JSON.parse($('system-config-editor').value);
  } catch {
    try {
      const data = await api('/api/staff/system-config');
      config = data.data?.config || data.data || { version: 1, entries: [] };
    } catch {
      config = { version: 1, entries: [] };
    }
  }
  config.object_portal = portalCategoriesFromUI();
  $('system-config-editor').value = JSON.stringify(config, null, 2);
  const data = await api('/api/staff/system-config', {
    method: 'POST',
    body: JSON.stringify({ config }),
  });
  if (!data.ok) {
    let msg = data.error || 'salvataggio fallito';
    if (/impossibile scrivere|lib\/edit_system/i.test(msg)) {
      msg +=
        ' — myst vecchio o permessi file: ./scripts/mud-dev.sh rebuild-myst oppure chmod u+rw mudroot/lib/edit_system.json';
    }
    $('portal-cat-result').textContent = msg;
    return;
  }
  $('portal-cat-result').textContent =
    'Categorie salvate. Ricarico inventario del personaggio target selezionato…';
  await loadEditCatalog();
  if (getTargetToonId()) {
    await loadInventory();
  } else {
    $('portal-cat-result').textContent =
      'Categorie salvate. Seleziona un personaggio target per vedere l\'inventario filtrato.';
  }
};

$('btn-save-config').onclick = async () => {
  let config;
  try {
    config = JSON.parse($('system-config-editor').value);
  } catch {
    $('config-result').textContent = 'JSON non valido';
    return;
  }
  const data = await api('/api/staff/system-config', {
    method: 'POST',
    body: JSON.stringify({ config }),
  });
  $('config-result').textContent = JSON.stringify(data, null, 2);
  await loadEditCatalog();
  await loadCharacterState();
};

$('btn-inst-search').onclick = async () => {
  const q = $('inst-search').value;
  const data = await api(`/api/staff/instances?q=${encodeURIComponent(q)}`);
  const list = $('inst-list');
  list.innerHTML = '';
  if (!data.ok) return;
  const labOn = !!session?.labEnabled || Number(session?.maxLevel || 0) >= 58;
  data.instances.forEach((i) => {
    const li = document.createElement('li');
    li.className = 'inst-item';
    li.innerHTML =
      `#${escapeHtml(i.id)} base ${escapeHtml(i.base_vnum)} owner ` +
      `<button type="button" class="linkish" data-owner="${escapeHtml(i.owner_name)}">${escapeHtml(i.owner_name)}</button>` +
      ` — ${mudTextToHtml(i.short_desc)}` +
      (labOn
        ? ` <button type="button" class="btn-secondary btn-lab-clone" data-iid="${escapeHtml(i.id)}">Clona sul target</button>`
        : '');
    const btn = li.querySelector('button[data-owner]');
    if (btn) {
      btn.onclick = async () => {
        const owner = btn.dataset.owner || '';
        const search = $('target-toon-search');
        if (search) {
          search.value = owner;
          await searchTargetToons(owner);
          const sel = $('target-toon');
          if (sel) {
            const match = [...sel.options].find(
              (o) => o.textContent.toLowerCase().startsWith(owner.toLowerCase()),
            );
            if (match) {
              sel.value = match.value;
              sel.dispatchEvent(new Event('change'));
            }
          }
        }
      };
    }
    const cloneBtn = li.querySelector('button.btn-lab-clone');
    if (cloneBtn) {
      cloneBtn.onclick = () => labCloneInstance(cloneBtn.dataset.iid);
    }
    list.appendChild(li);
  });
};

const btnLabSetStats = $('btn-lab-set-stats');
if (btnLabSetStats) btnLabSetStats.onclick = () => labSetStats();
const btnLabGive = $('btn-lab-give-vnum');
if (btnLabGive) btnLabGive.onclick = () => labGiveVnum();
['lab-exp', 'lab-rune'].forEach((id) => {
  const el = $(id);
  if (!el) return;
  el.addEventListener('input', updateLabStatPreviews);
  el.addEventListener('change', updateLabStatPreviews);
});
const labObjSearch = $('lab-obj-search');
if (labObjSearch) {
  labObjSearch.addEventListener('input', () => {
    const q = String(labObjSearch.value || '').trim();
    if (labObjSearchTimer) clearTimeout(labObjSearchTimer);
    labObjSearchTimer = setTimeout(() => labSearchObjects(q), 280);
  });
}

const btnToggleTools = $('btn-toggle-tools');
if (btnToggleTools) {
  btnToggleTools.onclick = () => setToolsColumnOpen(!isToolsColumnOpen());
}

restoreSavedLogin();
applyLoginUiMode();
$('header-meta').textContent = `UI build ${EDIT_PORTAL_UI_BUILD}`;
refreshMe();

/* ========== Staff listino admin (prezzi + routing + nuovi valori) ========== */
let listinoAdminState = null;

function listinoAdminEscape(s) {
  return escapeHtml(String(s ?? ''));
}

function renderListinoCapGroupsAdmin(groups) {
  const host = $('listino-cap-groups');
  if (!host) return;
  const rows = (groups || [])
    .map(
      (g, i) => `
    <tr data-idx="${i}">
      <td><input data-f="group_key" type="text" value="${listinoAdminEscape(g.group_key)}" ${g._new ? '' : 'readonly'} /></td>
      <td><input data-f="label" type="text" value="${listinoAdminEscape(g.label)}" /></td>
      <td><input data-f="max_piece" class="narrow" type="number" value="${Number(g.max_piece) || 0}" /></td>
      <td><input data-f="max_character" class="narrow" type="number" value="${Number(g.max_character) || 0}" /></td>
      <td><input data-f="enabled" type="checkbox" ${Number(g.enabled) !== 0 ? 'checked' : ''} /></td>
      <td><button type="button" class="btn-secondary btn-listino-del-cap" data-idx="${i}">Elimina</button></td>
    </tr>`
    )
    .join('');
  host.innerHTML = `
    <table>
      <thead><tr>
        <th>Chiave</th><th>Nome</th><th>Cap pezzo</th><th>Cap PG</th><th>On</th><th></th>
      </tr></thead>
      <tbody>${rows || '<tr><td colspan="6">Nessun gruppo</td></tr>'}</tbody>
    </table>`;
  host.querySelectorAll('.btn-listino-del-cap').forEach((btn) => {
    btn.onclick = () => {
      const idx = Number(btn.dataset.idx);
      const g = listinoAdminState.cap_groups[idx];
      if (!g) return;
      if (!listinoAdminState.delete_cap_group_keys) listinoAdminState.delete_cap_group_keys = [];
      if (!g._new) listinoAdminState.delete_cap_group_keys.push(g.group_key);
      listinoAdminState.cap_groups.splice(idx, 1);
      renderListinoCapGroupsAdmin(listinoAdminState.cap_groups);
      renderListinoAffectAdmin(listinoAdminState.affect, listinoAdminState.routing);
    };
  });
}

function collectCapGroupsFromDom() {
  const host = $('listino-cap-groups');
  if (!host) return [];
  return [...host.querySelectorAll('tbody tr[data-idx]')].map((tr) => {
    const enabled = tr.querySelector('[data-f="enabled"]')?.checked;
    return {
      group_key: tr.querySelector('[data-f="group_key"]')?.value || '',
      label: tr.querySelector('[data-f="label"]')?.value || '',
      max_piece: Number(tr.querySelector('[data-f="max_piece"]')?.value || 0),
      max_character: Number(tr.querySelector('[data-f="max_character"]')?.value || 0),
      enabled: enabled ? 1 : 0,
    };
  });
}

function routingForAffectId(listinoId) {
  const id = `affect.${listinoId}`;
  const r = (listinoAdminState?.routing || []).find((x) => x.id === id);
  return r || { id, kind: 'affect', target: 'object', enabled: true };
}

function renderListinoAffectAdmin(affect, routing) {
  const host = $('listino-affect-admin');
  if (!host) return;
  const groups = collectCapGroupsFromDom().map((g) => g.group_key).filter(Boolean);
  const groupOpts = (selected) =>
    `<option value="">(nessuno)</option>` +
    groups
      .map(
        (k) =>
          `<option value="${listinoAdminEscape(k)}" ${k === selected ? 'selected' : ''}>${listinoAdminEscape(k)}</option>`
      )
      .join('');
  const applyOpts = (loc) =>
    (listinoAdminState.apply_catalog || [])
      .map(
        (a) =>
          `<option value="${a.location}" ${Number(a.location) === Number(loc) ? 'selected' : ''}>${listinoAdminEscape(a.name)} (${a.location})</option>`
      )
      .join('');
  const rows = (affect || [])
    .map((a, i) => {
      const rt = routingForAffectId(a.id);
      return `
    <tr data-idx="${i}" data-id="${listinoAdminEscape(a.id)}">
      <td><input data-f="id" type="text" value="${listinoAdminEscape(a.id)}" ${a._new ? '' : 'readonly'} /></td>
      <td><input data-f="label" type="text" value="${listinoAdminEscape(a.label)}" /></td>
      <td><select data-f="location">${applyOpts(a.location)}</select></td>
      <td><input data-f="step" class="narrow" type="number" value="${Number(a.step) || 1}" /></td>
      <td><input data-f="min_total" class="narrow" type="number" value="${Number(a.min_total) || 0}" /></td>
      <td><input data-f="max_total" class="narrow" type="number" value="${Number(a.max_total) || 0}" /></td>
      <td><input data-f="pos_unit_raw" class="narrow" type="number" value="${Number(a.pos_unit_raw) || 0}" /></td>
      <td><input data-f="neg_unit_raw" class="narrow" type="number" value="${Number(a.neg_unit_raw) || 0}" /></td>
      <td><input data-f="rune_num" class="narrow" type="number" value="${Number(a.rune_num) || 0}" /></td>
      <td><input data-f="rune_den" class="narrow" type="number" value="${Number(a.rune_den) || 1}" /></td>
      <td><select data-f="cap_group">${groupOpts(a.cap_group || '')}</select></td>
      <td><select data-f="target">
        <option value="object" ${rt.target !== 'character' ? 'selected' : ''}>oggetto</option>
        <option value="character" ${rt.target === 'character' ? 'selected' : ''}>toon</option>
      </select></td>
      <td><input data-f="enabled" type="checkbox" ${rt.enabled !== false && Number(a.enabled) !== 0 ? 'checked' : ''} /></td>
      <td><button type="button" class="btn-secondary btn-listino-del-affect" data-idx="${i}">Elimina</button></td>
    </tr>`;
    })
    .join('');
  host.innerHTML = `
    <table>
      <thead><tr>
        <th>id</th><th>Nome</th><th>APPLY</th><th>step</th><th>min</th><th>max</th>
        <th>pos_raw</th><th>neg_raw</th><th>rune_n</th><th>rune_d</th>
        <th>cap gruppo</th><th>Dove</th><th>On</th><th></th>
      </tr></thead>
      <tbody>${rows || '<tr><td colspan="14">Nessun affect</td></tr>'}</tbody>
    </table>`;
  host.querySelectorAll('.btn-listino-del-affect').forEach((btn) => {
    btn.onclick = () => {
      const idx = Number(btn.dataset.idx);
      const a = listinoAdminState.affect[idx];
      if (!a) return;
      if (!listinoAdminState.delete_affect_ids) listinoAdminState.delete_affect_ids = [];
      if (!a._new) listinoAdminState.delete_affect_ids.push(a.id);
      listinoAdminState.affect.splice(idx, 1);
      renderListinoAffectAdmin(listinoAdminState.affect, listinoAdminState.routing);
    };
  });
}

function renderListinoPoolAdmin(pool) {
  const host = $('listino-pool-admin');
  if (!host) return;
  const rows = (pool || [])
    .map((p, i) => {
      const id = `pool.${p.field_key}`;
      const rt =
        (listinoAdminState.routing || []).find((x) => x.id === id) || {
          target: 'character',
          enabled: true,
        };
      return `
    <tr data-idx="${i}">
      <td>${listinoAdminEscape(p.field_key)}</td>
      <td><input data-f="label" type="text" value="${listinoAdminEscape(p.label)}" /></td>
      <td><input data-f="cap" class="narrow" type="number" value="${Number(p.cap) || 0}" /></td>
      <td><input data-f="step" class="narrow" type="number" value="${Number(p.step) || 1}" /></td>
      <td><input data-f="xp_per_unit" class="narrow" type="number" value="${Number(p.xp_per_unit) || 0}" /></td>
      <td><input data-f="rune_num" class="narrow" type="number" value="${Number(p.rune_num) || 0}" /></td>
      <td><input data-f="rune_den" class="narrow" type="number" value="${Number(p.rune_den) || 1}" /></td>
      <td><select data-f="target">
        <option value="character" ${rt.target !== 'object' ? 'selected' : ''}>toon</option>
        <option value="object" ${rt.target === 'object' ? 'selected' : ''}>oggetto</option>
      </select></td>
      <td><input data-f="enabled" type="checkbox" ${rt.enabled !== false && Number(p.enabled) !== 0 ? 'checked' : ''} /></td>
    </tr>`;
    })
    .join('');
  host.innerHTML = `
    <table>
      <thead><tr>
        <th>campo</th><th>Nome</th><th>cap</th><th>step</th><th>xp/u</th><th>rune_n</th><th>rune_d</th><th>Dove</th><th>On</th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function renderListinoParamAdmin(params) {
  const host = $('listino-param-admin');
  if (!host) return;
  const rows = (params || [])
    .map(
      (p, i) => `
    <tr data-idx="${i}">
      <td>${listinoAdminEscape(p.param_key)}</td>
      <td><input data-f="param_value" type="number" step="any" value="${Number(p.param_value)}" /></td>
    </tr>`
    )
    .join('');
  host.innerHTML = `
    <table>
      <thead><tr><th>param</th><th>valore</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function renderListinoAdminAll() {
  if (!listinoAdminState) return;
  renderListinoCapGroupsAdmin(listinoAdminState.cap_groups || []);
  renderListinoAffectAdmin(listinoAdminState.affect || [], listinoAdminState.routing || []);
  renderListinoPoolAdmin(listinoAdminState.pool || []);
  renderListinoParamAdmin(listinoAdminState.params || []);
}

async function loadListinoAdmin() {
  const el = $('listino-admin-result');
  if (el) el.textContent = 'Caricamento…';
  const data = await api('/api/staff/listino-admin');
  if (!data.ok) {
    if (el) el.textContent = data.error || 'Errore caricamento';
    return;
  }
  listinoAdminState = {
    affect: data.affect || [],
    pool: data.pool || [],
    params: data.params || [],
    cap_groups: data.cap_groups || [],
    routing: data.routing || [],
    apply_catalog: data.apply_catalog || [],
    delete_affect_ids: [],
    delete_cap_group_keys: [],
  };
  renderListinoAdminAll();
  if (el) el.textContent = `Caricato (affect=${listinoAdminState.affect.length}).`;
}

function collectListinoAdminPayload() {
  const hostA = $('listino-affect-admin');
  const affect = [...(hostA?.querySelectorAll('tbody tr[data-idx]') || [])].map((tr) => {
    const id = tr.querySelector('[data-f="id"]')?.value || '';
    return {
      id,
      label: tr.querySelector('[data-f="label"]')?.value || id,
      location: Number(tr.querySelector('[data-f="location"]')?.value || 0),
      step: Number(tr.querySelector('[data-f="step"]')?.value || 1),
      min_total: Number(tr.querySelector('[data-f="min_total"]')?.value || 0),
      max_total: Number(tr.querySelector('[data-f="max_total"]')?.value || 0),
      pos_unit_raw: Number(tr.querySelector('[data-f="pos_unit_raw"]')?.value || 0),
      neg_unit_raw: Number(tr.querySelector('[data-f="neg_unit_raw"]')?.value || 0),
      rune_num: Number(tr.querySelector('[data-f="rune_num"]')?.value || 0),
      rune_den: Number(tr.querySelector('[data-f="rune_den"]')?.value || 1),
      cap_group: tr.querySelector('[data-f="cap_group"]')?.value || null,
      enabled: tr.querySelector('[data-f="enabled"]')?.checked ? 1 : 0,
      _target: tr.querySelector('[data-f="target"]')?.value || 'object',
    };
  });
  const hostP = $('listino-pool-admin');
  const pool = [...(hostP?.querySelectorAll('tbody tr[data-idx]') || [])].map((tr, i) => {
    const base = listinoAdminState.pool[i] || {};
    return {
      field_key: base.field_key,
      label: tr.querySelector('[data-f="label"]')?.value || base.field_key,
      cap: Number(tr.querySelector('[data-f="cap"]')?.value || 0),
      step: Number(tr.querySelector('[data-f="step"]')?.value || 1),
      unit_valore: Number(base.unit_valore || 0),
      xp_per_unit: Number(tr.querySelector('[data-f="xp_per_unit"]')?.value || 0),
      rune_num: Number(tr.querySelector('[data-f="rune_num"]')?.value || 0),
      rune_den: Number(tr.querySelector('[data-f="rune_den"]')?.value || 1),
      enabled: tr.querySelector('[data-f="enabled"]')?.checked ? 1 : 0,
      _target: tr.querySelector('[data-f="target"]')?.value || 'character',
    };
  });
  const hostPar = $('listino-param-admin');
  const params = [...(hostPar?.querySelectorAll('tbody tr[data-idx]') || [])].map((tr, i) => {
    const base = listinoAdminState.params[i] || {};
    return {
      param_key: base.param_key,
      param_value: Number(tr.querySelector('[data-f="param_value"]')?.value),
    };
  });
  const cap_groups = collectCapGroupsFromDom();
  const routing = [];
  for (const a of affect) {
    routing.push({
      id: `affect.${a.id}`,
      kind: 'affect',
      location: a.location,
      listino_id: a.id,
      label: a.label,
      target: a._target,
      enabled: !!a.enabled,
    });
  }
  for (const p of pool) {
    routing.push({
      id: `pool.${p.field_key}`,
      kind: 'pool',
      pool_field: p.field_key,
      label: p.label,
      target: p._target,
      enabled: !!p.enabled,
    });
  }
  for (const r of listinoAdminState.routing || []) {
    if (r.kind === 'resistance') routing.push(r);
  }
  return {
    affect,
    pool,
    params,
    cap_groups,
    routing,
    delete_affect_ids: listinoAdminState.delete_affect_ids || [],
    delete_cap_group_keys: listinoAdminState.delete_cap_group_keys || [],
    reason: 'staff-listino-admin',
  };
}

async function saveListinoAdmin() {
  const el = $('listino-admin-result');
  if (!listinoAdminState) {
    if (el) el.textContent = 'Carica prima il listino.';
    return;
  }
  if (el) el.textContent = 'Salvataggio…';
  const body = collectListinoAdminPayload();
  const data = await api('/api/staff/listino-admin', {
    method: 'POST',
    body: JSON.stringify(body),
  });
  if (!data.ok) {
    if (el) el.textContent = data.error || 'Salvataggio fallito';
    return;
  }
  listinoSnapshot = null;
  editCatalog = null;
  await loadListinoAdmin();
  try {
    await ensureListinoSnapshot(true);
    const cat = await api('/api/edit-catalog');
    if (cat.ok) editCatalog = cat.data;
    if (charState && !charState.stats_missing) renderCharacterEdits();
    objectOptionsCache.clear();
  } catch (_) {
    /* refresh best-effort */
  }
  if (el) el.textContent = 'Salvato e ricaricato su myst.';
}

if ($('btn-listino-admin-load')) {
  $('btn-listino-admin-load').onclick = () => loadListinoAdmin();
}
if ($('btn-listino-admin-save')) {
  $('btn-listino-admin-save').onclick = () => saveListinoAdmin();
}
if ($('btn-listino-add-cap-group')) {
  $('btn-listino-add-cap-group').onclick = () => {
    if (!listinoAdminState) return;
    listinoAdminState.cap_groups.push({
      group_key: `gruppo_${Date.now() % 100000}`,
      label: 'Nuovo gruppo',
      max_piece: 2,
      max_character: 0,
      enabled: 1,
      _new: true,
    });
    renderListinoAdminAll();
  };
}
if ($('btn-listino-add-affect')) {
  $('btn-listino-add-affect').onclick = () => {
    if (!listinoAdminState) return;
    const used = new Set((listinoAdminState.affect || []).map((a) => Number(a.location)));
    const pick =
      (listinoAdminState.apply_catalog || []).find((a) => !used.has(Number(a.location))) ||
      { location: 5, label: 'Costituzione', name: 'APPLY_CON' };
    const id = `custom_${pick.location}`;
    listinoAdminState.affect.push({
      id,
      label: pick.label || pick.name,
      location: pick.location,
      step: 1,
      min_total: 0,
      max_total: 3,
      pos_unit_raw: 1500,
      neg_unit_raw: 3000,
      rune_num: 0,
      rune_den: 1,
      cap_group: null,
      enabled: 1,
      _new: true,
    });
    renderListinoAffectAdmin(listinoAdminState.affect, listinoAdminState.routing);
  };
}
