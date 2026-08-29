'use strict';

const PQ_PER_MEGA_XP = 1000000;
const PRINCE_LEVEL = 51;
const LOGIN_STORAGE_KEY = 'nebbie-edit-login';
const INVENTORY_SORT_KEY = 'nebbie-edit-inventory-sort';
/** Bump insieme a index.html ?v= e a kEditPortalApiVersion (marker UI deploy). */
const EDIT_PORTAL_UI_BUILD = 44;
const PRINCE_SORT_KEY = 'nebbie-edit-prince-sort';

/** Catalogo valute (staff). Solo visible+enabled compaiono in pagamento. */
let portalCurrencies = null;

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
/** Coda edit oggetto: più campi insieme (stesso pezzo) → somma costi listino. */
let objectEditCart = new Map();
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
  const res = await fetch(portalUrl(path), {
    ...opts,
    headers: {
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({ ok: false, error: 'Risposta non valida dal server' }));
  if (!res.ok && data.ok === undefined) data.ok = false;
  return data;
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
  const runePerMega = Number(editCatalog?.pq_per_mega_xp || PQ_PER_MEGA_XP);
  const { mega, frac, raw } = quoteMxpFromRaw(xpRaw);

  let payXp = 0;
  let payRune = 0;

  if (mode === 'mxp') {
    payXp = raw;
    payRune = runeListino;
  } else if (mode === 'runes') {
    const runesFromMxp = raw > 0 ? Math.ceil(raw / runePerMega) : 0;
    payXp = 0;
    payRune = runesFromMxp + runeListino;
  } else {
    const runeMega = (mega * runePct) / 100;
    const runeFrac = (frac * runePct) / 100;
    const runeMegaTotal = runeMega + runeFrac / 100;
    const runesFromMxp = Math.ceil(runeMegaTotal);
    const xpCovered = runesFromMxp * runePerMega;
    payXp = Math.max(0, raw - xpCovered);
    payRune = runeListino + runesFromMxp;
  }

  return {
    payXp,
    payRune,
    displayMxp: formatMxp(mega, frac),
    xpRaw,
    runeListino,
  };
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

function isObjectPendingType(type) {
  return type === 'object' || type === 'object-batch' || type === 'object-text';
}

function isCharacterPendingType(type) {
  return type === 'pool' || type === 'resistance' || type === 'character-batch';
}

function sumQuotes(items) {
  let xpRaw = 0;
  let rune = 0;
  items.forEach((it) => {
    xpRaw += Number(it.quote?.xp_raw || it.quote?.diff_xp_raw || 0);
    rune += Number(it.quote?.diff_rune || it.quote?.pq || 0);
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
    .map(
      (it) =>
        `<div class="edit-cart-line"><span class="edit-cart-label">${escapeHtml(
          it.label
        )}</span><span class="edit-cart-cost">${escapeHtml(
          formatQuoteCostShort(it.quote)
        )}</span></div>`
    )
    .join('');
  const totals = sumQuotes(items);
  el.innerHTML = `
    <div class="edit-cart-title">In coda (${items.length})</div>
    ${rows}
    <div class="edit-cart-total">Totale listino: <strong>${escapeHtml(
      formatQuoteCostShort(totals)
    )}</strong></div>
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
  document.querySelectorAll('#pool-edits .edit-row, #resistance-edits .edit-row').forEach((row) => {
    const key = row.dataset.cartKey;
    row.classList.toggle('edit-row--dirty', key && characterEditCart.has(key));
  });
}

function updateObjectCartUI() {
  const items = [...objectEditCart.values()];
  renderEditCartBox(
    $('object-edit-cart'),
    items,
    'Costi aggiornati a ogni selettore. Paga dal pannello in basso.'
  );
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
  if (isCharacterPendingType(pendingEdit?.type)) {
    pendingEdit = null;
  }
  updateCharacterCartUI();
  updatePaymentUI();
}

function rebuildCharacterPendingFromCart() {
  if (!characterEditCart.size) {
    if (isCharacterPendingType(pendingEdit?.type)) {
      pendingEdit = null;
    }
    updateCharacterCartUI();
    updatePaymentUI();
    return;
  }
  const items = [...characterEditCart.values()];
  const totals = sumQuotes(items);
  const labels = items.map((it) => it.label);
  pendingEdit = {
    type: 'character-batch',
    entryId: 'character-batch',
    label: labels.join('\n'),
    quote: {
      ...totals,
      note:
        items.length > 1
          ? `${items.length} edit personaggio in coda (costi sommati)`
          : undefined,
    },
    items,
  };
  updateCharacterCartUI();
  updatePaymentUI();
}

function ensureCharacterCartExclusive() {
  if (objectEditCart.size || isObjectPendingType(pendingEdit?.type)) {
    clearObjectEditCart({ resetSelectors: true });
  }
}

function ensureObjectCartExclusive() {
  if (characterEditCart.size || isCharacterPendingType(pendingEdit?.type)) {
    clearCharacterEditCart({ resetSelectors: true });
  }
}

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
    return;
  }
  show('payment-panel');
  document.body.classList.add('payment-dock-open');

  const mode = $('pay-mode').value;
  const runePct = Number($('pay-rune-pct').value);
  $('pay-rune-pct-label').textContent = `${runePct}%`;
  $('rune-pct-wrap').classList.toggle('hidden', mode !== 'mix');

  const plan = buildPaymentPlan(pendingEdit.quote, mode, runePct);
  const check = validatePayment(plan);
  document.body.classList.toggle('payment-insufficient', !check.ok);
  panel.classList.toggle('payment-dock--insufficient', !check.ok);

  const cartItems = Array.isArray(pendingEdit.items) ? pendingEdit.items : null;
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
        .map(
          (it) =>
            `<div class="payment-cart-line"><span>${escapeHtml(
              it.label
            )}</span><span class="payment-cart-cost">${escapeHtml(
              formatQuoteCostShort(it.quote)
            )}</span></div>`
        )
        .join('')
    : lines.map((line) => escapeHtml(line)).join('<br>');

  $('payment-summary').innerHTML = `
    <div class="payment-queue-list">${labelHtml}</div>
    <div class="payment-cost-line">
      Costo listino: <strong>${plan.displayMxp}</strong>
      ${plan.runeListino ? ` (+ ${plan.runeListino} ${currencyLabel('rune')} listino)` : ''}
    </div>
    ${
      pendingEdit.quote?.note
        ? `<div class="slot-hint">${escapeHtml(pendingEdit.quote.note)}</div>`
        : ''
    }
  `;

  const insuffHint = !check.ok
    ? `<div class="payment-insufficient-msg">Fondi insufficienti sul personaggio target${
        !check.okXp ? ' (XP/MXP)' : ''
      }${!check.okRune ? ` (${currencyLabel('rune')})` : ''}.</div>`
    : '';

  $('payment-breakdown').innerHTML = `
    <div class="payment-pay-line">
      Pagherai: <strong>${plan.payXp.toLocaleString('it-IT')} XP</strong>
      + <strong>${plan.payRune} ${currencyLabel('rune')}</strong>
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
  pendingEdit.plan = plan;
}

async function refreshMe() {
  const me = await api('/api/me');
  if (!me.ok) {
    session = null;
    pendingEdit = null;
    clearObjectEditCart();
    clearCharacterEditCart();
    document.body.classList.remove('payment-dock-open');
    document.body.classList.remove('payment-insufficient');
    applyLoginUiMode();
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

function meterLine(label, used, cap, remaining) {
  const u = Number(used) || 0;
  const c = Number(cap) || 0;
  const r = remaining != null ? Number(remaining) : Math.max(0, c - u);
  return `<div class="ov-meter"><span class="ov-meter-label">${escapeHtml(label)}</span>` +
    `<strong>${u}/${c}</strong><span class="ov-remain">ancora ${r}</span></div>`;
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

  const head = document.createElement('div');
  head.className = 'toon-overview-head toon-overview-head-stack';
  head.innerHTML =
    `<div><strong class="toon-overview-name">${escapeHtml(t.name)}</strong>` +
    `<span class="toon-overview-meta">lv ${t.maxLevel}` +
    (title ? ` · ${mudTextToHtml(title)}` : '') +
    (grade ? ` · ${escapeHtml(grade)}` : '') +
    ` · ${escapeHtml(formatMxp(mxp, mxpFrac))} disponibili</span>` +
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
  const poolWarn = pool.residual_on_objects
    ? `<p class="ov-warn">${escapeHtml(
        pool.warning ||
          'Pool migrato sul PG ma restano delta sugli oggetti EDIT (stato misto).',
      )}</p>`
    : '';
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
        ${meterLine('Dam editato', main.dam?.used, main.dam?.cap, main.dam?.remaining)}
        ${meterLine('Spellpower', main.spellpower?.used, main.spellpower?.cap, main.spellpower?.remaining)}
        ${meterLine('Hitroll editato', main.hitroll?.used, main.hitroll?.cap, main.hitroll?.remaining)}
      </div>
    </details>
    <details class="ov-collapse">
      <summary>Residuo pool <span class="ov-source">(${
        pool.source === 'character' ? 'sul PG' : 'sugli oggetti'
      })</span></summary>
      <div class="ov-collapse-body">
        ${poolWarn}
        ${(pool.fields || [])
          .map((f) =>
            meterLine(
              ({
                hit: 'Hit',
                mana: 'Mana',
                move: 'Move',
                hit_regen: 'Hit regen',
                mana_regen: 'Mana regen',
                move_regen: 'Move regen',
              })[f.key] || f.key,
              f.used,
              f.cap,
              f.remaining,
            ),
          )
          .join('')}
      </div>
    </details>
    <div class="ov-block ov-clan">
      <h4>Simbolo del clan</h4>
      <p>${
        clan.present
          ? '<span class="ov-yes">Sì</span> (origine principe/toon: da definire)'
          : '<span class="ov-no">No</span>'
      }</p>
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
  await refreshMe();
}

async function enterWorkMode() {
  hide('toon-panel');
  show('work-panel');
  const me = await api('/api/me');
  $('header-meta').textContent =
    `${me.email} — ${me.sessionToonName} (${me.role}, lv ${me.maxLevel}) · UI ${EDIT_PORTAL_UI_BUILD}`;

  const payMode = $('pay-mode');
  if (canPayMxp()) {
    payMode.value = 'mxp';
    payMode.querySelector('option[value="mxp"]').disabled = false;
    payMode.querySelector('option[value="mix"]').disabled = false;
    payMode.querySelector('option[value="runes"]').disabled = false;
  } else {
    payMode.value = 'runes';
    payMode.querySelector('option[value="mxp"]').disabled = true;
    payMode.querySelector('option[value="mix"]').disabled = true;
  }
  refreshPayModeLabels();

  if (me.role === 'staff') {
    show('staff-panel');
    show('target-toon-wrap');
    const hint = $('session-role-hint');
    if (hint) {
      hint.textContent =
        `Sessione: ${me.sessionToonName} (staff). Cerca sotto il personaggio su cui vuoi lavorare.`;
    }
    loadSystemConfig();
  } else {
    hide('staff-panel');
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
    await loadCharacterState();
    await loadInventory();
  };
  clearTargetWorkspace('Caricamento personaggio…');
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
  clearObjectEditCart();
  clearCharacterEditCart();
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
  const opts = [];
  for (let v = 0; v <= cap; v += step) {
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
      opt.textContent = v;
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

async function selectItem(inventoryId, li) {
  document.querySelectorAll('#inventory-list .item').forEach((el) => el.classList.remove('selected'));
  if (li) li.classList.add('selected');
  selectedInventoryId = inventoryId;
  clearObjectEditCart();
  selectedObjectOptions = null;
  if (characterEditCart.size) {
    rebuildCharacterPendingFromCart();
  } else {
    pendingEdit = null;
    updatePaymentUI();
  }
  updatePaymentUI();
  $('object-edits').innerHTML = '';
  $('object-affect-slots').innerHTML = '';
  hide('object-affect-slots');
  const textBox = $('object-text-edit');
  if (textBox) textBox.innerHTML = '';
  $('quote-box').textContent = 'Caricamento…';

  const opts = await api('/api/object-edit-options', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, inventoryId }),
  });

  if (!opts.ok) {
    $('quote-box').textContent = opts.error || 'Oggetto non editabile';
    return;
  }

  selectedObjectOptions = opts.data;
  const d = opts.data;
  const quoteEl = $('quote-box');
  const lines = [
    d.owner_name ? `Owner: ${d.owner_name} (${d.owner_classes} classi, x${d.class_mult})` : '',
    d.item_type ? `Tipo: ${d.item_type}` : '',
    `Costo attuale vs prototipo: ${formatMxp(d.diff_xp_mega || 0, d.diff_xp_frac || 0)}`,
    d.diff_rune ? `Rune componente listino: ${d.diff_rune}` : '',
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
  renderObjectEdits(
    d.entries || [],
    d.dam_budget,
    d.sp_budget,
    d.clan_symbol === true,
  );
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
  title.textContent = 'Slot effetti (affect)';
  box.appendChild(title);

  const summary = document.createElement('p');
  summary.className = 'affect-slots-summary';
  summary.textContent =
    `${used}/${maxSlots} occupati · ${freeCount} liberi — bonus combat uguali si accorpano (hitroll+damroll → hit-n-dam).`;
  box.appendChild(summary);

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

function objectEditSection(id) {
  if (id === 'artifact' || id.startsWith('flag.')) return 'Artifact';
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
  "Bonus all'Armatura/Cast",
  'Caratteristiche',
  'Bonus in Combattimento',
  'Immunità',
  'Resistenze',
  'Spell',
];

function objectEditSectionRank(name) {
  const i = OBJECT_EDIT_SECTION_ORDER.indexOf(name);
  return i >= 0 ? i : 99;
}

/**
 * Opzioni listino.
 * relative=true: min/max sono extra oltre proto (es. armor −40…0, hit +0…+2);
 * i valori nel select sono totali assoluti (proto + extra).
 */
function buildObjectScalarOptions(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const absStep = Math.abs(Number(entry.step)) || 1;
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const opts = [];
  if (entry.relative) {
    const proto = Number(entry.proto || 0);
    for (let d = lo; d <= hi; d += absStep) {
      opts.push(proto + d);
    }
    return opts;
  }
  for (let v = lo; v <= hi; v += absStep) {
    opts.push(v);
  }
  return opts;
}

function formatScalarOptionLabel(entry, absolute) {
  /* Solo valore numerico (es. 0, -10, 2) — niente "nessuno (proto …)". */
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

function objectEntryRangeLabel(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const step = Number(entry.step) || 1;
  if (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell' || entry.kind === 'flag') {
    return '';
  }
  if (entry.relative) {
    const proto = Number(entry.proto || 0);
    return ` (extra ${min}…${max} oltre proto ${proto}, step ${step})`;
  }
  return ` (${min}…${max}, step ${step})`;
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

/** Listino: +50% se Artifact gia' sul pezzo o in coda nello stesso pacchetto. */
function objectPricingUsesArtifact() {
  return objectAlreadyArtifact() || cartAddsArtifact();
}

function clearObjectPending(entryId) {
  const removed = objectEditCart.get(entryId);
  if (objectEditCart.has(entryId)) {
    objectEditCart.delete(entryId);
  }
  if (removed?.flag === 'artifact') {
    requoteObjectCartForArtifact();
    return;
  }
  rebuildObjectPendingFromCart();
}

function clearObjectEditCart({ resetSelectors = false } = {}) {
  if (resetSelectors) {
    objectEditCart.forEach((it) => {
      if (it.selectEl && it.selectEl.dataset.current != null) {
        it.selectEl.value = it.selectEl.dataset.current;
      }
    });
  }
  objectEditCart.clear();
  if (isObjectPendingType(pendingEdit?.type)) {
    pendingEdit = null;
  }
  updateObjectCartUI();
  updatePaymentUI();
}

function rebuildObjectPendingFromCart() {
  if (!objectEditCart.size) {
    if (isObjectPendingType(pendingEdit?.type)) {
      pendingEdit = null;
    }
    updateObjectCartUI();
    updatePaymentUI();
    return;
  }
  const items = [...objectEditCart.values()];
  const totals = sumQuotes(items);
  const labels = [];
  const notes = [];
  items.forEach((it) => {
    labels.push(it.label);
    if (it.quote?.note) notes.push(it.quote.note);
  });
  const artNote = objectPricingUsesArtifact()
    ? 'Include maggiorazione Artifact +50% (listino)'
    : undefined;
  pendingEdit = {
    type: 'object-batch',
    entryId: 'object-batch',
    label: labels.join('\n'),
    quote: {
      ...totals,
      note:
        notes.find((n) => /Artifact/i.test(String(n))) ||
        artNote ||
        notes[0] ||
        (items.length > 1
          ? `${items.length} edit in coda (costo sommato vs stato attuale del pezzo)`
          : undefined),
    },
    items,
  };
  updateObjectCartUI();
  updatePaymentUI();
}

async function requoteObjectCartForArtifact() {
  const useArt = objectPricingUsesArtifact();
  const items = [...objectEditCart.values()];
  for (const it of items) {
    if (it.flag === 'artifact') continue;
    const payload = {
      targetToonId,
      inventoryId: selectedInventoryId,
      location: Number(it.location || 0),
      targetModifier: it.targetModifier,
      pendingArtifact: useArt,
    };
    if (it.flag) payload.flag = it.flag;
    const data = await api('/api/quote-object-edit', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (!data.ok) continue;
    it.quote = data.data;
    objectEditCart.set(it.entryId, it);
  }
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
  summary.innerHTML = '<span class="edit-section-name">Name / short / long</span>';
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

function renderMassimaliPanel(box, damBudget, spBudget, isClanSymbol) {
  const panel = document.createElement('div');
  panel.className = 'massimali-panel';

  const title = document.createElement('h3');
  title.className = 'massimali-title';
  title.textContent = 'Massimali editabili';
  panel.appendChild(title);

  const grid = document.createElement('div');
  grid.className = 'massimali-grid';

  if (damBudget) {
    const card = document.createElement('div');
    card.className = 'massimale-card';
    const total = Number(damBudget.char_total || 0);
    const max = Number(damBudget.char_max || 30);
    const pieceMax = Number(damBudget.piece_max || 2);
    const pc = Number(damBudget.piece_current);
    const pp = Number(damBudget.piece_proto);
    const delta = Number(damBudget.piece || 0);
    let detail = `Max ${pieceMax} dam editati per pezzo`;
    if (Number.isFinite(pc) && Number.isFinite(pp)) {
      detail = `Questo pezzo: ${pc} vs proto ${pp} (delta +${delta}) · max ${pieceMax}/pezzo`;
      if (damBudget.piece_edit === false) {
        detail += ' · non conteggiato (serve EDIT + owner; clan esclusi)';
      }
    }
    card.innerHTML = `
      <div class="massimale-label">Dam totale editato</div>
      <div class="massimale-value">${total}<span class="massimale-max"> / ${max}</span></div>
      <div class="massimale-detail">${escapeHtml(detail)}</div>
    `;
    grid.appendChild(card);
  }

  if (spBudget) {
    const card = document.createElement('div');
    card.className = 'massimale-card';
    const total = Number(spBudget.char_total || 0);
    const max = Number(spBudget.char_max || 30);
    const pieceMax = Number(spBudget.piece_max || 2);
    const pc = Number(spBudget.piece_current);
    const delta = Number(spBudget.piece || 0);
    let detail = `Max ${pieceMax} spellpower editati per pezzo`;
    if (Number.isFinite(pc)) {
      detail = `Questo pezzo: totale ${pc} (delta edit +${delta}) · max ${pieceMax}/pezzo`;
    }
    card.innerHTML = `
      <div class="massimale-label">Spellpower totale editato</div>
      <div class="massimale-value">${total}<span class="massimale-max"> / ${max}</span></div>
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

  box.appendChild(panel);
}

function renderObjectEdits(entries, damBudget, spBudget, isClanSymbol) {
  const box = $('object-edits');
  box.innerHTML = '';

  if (!entries.length) {
    box.innerHTML = '<p class="hint">Nessun campo editabile su questo oggetto.</p>';
    return;
  }
  if (session.role === 'limited') {
    box.innerHTML = '<p class="hint">Tier limited: edit oggetto non consentito.</p>';
    return;
  }

  renderMassimaliPanel(box, damBudget, spBudget, !!isClanSymbol);

  const editsWrap = document.createElement('div');
  editsWrap.className = 'object-edit-groups';
  const editsTitle = document.createElement('h3');
  editsTitle.className = 'object-edit-groups-title';
  editsTitle.textContent = 'Opzioni di edit';
  editsWrap.appendChild(editsTitle);

  const grouped = new Map();
  entries.forEach((entry) => {
    /* CON non e' nel listino ufficiale — non mostrare anche se myst vecchio lo manda. */
    if (entry.id === 'con' || Number(entry.location) === 5) return;
    const section = objectEditSection(entry.id || '');
    if (!grouped.has(section)) grouped.set(section, []);
    grouped.get(section).push(entry);
  });

  const sectionNames = [...grouped.keys()].sort(
    (a, b) => objectEditSectionRank(a) - objectEditSectionRank(b) || a.localeCompare(b, 'it')
  );

  sectionNames.forEach((section) => {
    const list = grouped.get(section) || [];
    list.sort((a, b) =>
      String(a.label || a.id || '').localeCompare(String(b.label || b.id || ''), 'it', {
        sensitivity: 'base',
      })
    );

    const details = document.createElement('details');
    details.className = 'edit-section';
    details.open = true;

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
      const select = document.createElement('select');
      select.disabled = !canEdit || session.role === 'limited';
      select.dataset.current = String(current);

      if (isYesNoObjectEntry(entry)) {
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
        if (
          (entry.kind === 'immune' || entry.kind === 'm_immune') &&
          current === 1
        ) {
          select.disabled = true;
        }
        if (entry.kind === 'spell' && current === 1) select.disabled = true;
        if (entry.kind === 'flag' && entry.flag === 'artifact' && current === 1) {
          select.disabled = true;
        }
      } else {
        const values = buildObjectScalarOptions(entry);
        if (!values.includes(current)) values.push(current);
        values.sort((a, b) => a - b);
        values.forEach((v) => {
          const opt = document.createElement('option');
          opt.value = v;
          opt.textContent = formatScalarOptionLabel(entry, v);
          if (v === current) opt.selected = true;
          select.appendChild(opt);
        });
      }

      if (!canEdit) {
        select.disabled = true;
      }

      const queuedObj = objectEditCart.get(entry.id);
      if (queuedObj && queuedObj.targetModifier != null && !select.disabled) {
        if (isYesNoObjectEntry(entry)) {
          select.value = Number(queuedObj.targetModifier) ? '1' : '0';
        } else {
          select.value = String(queuedObj.targetModifier);
        }
        queuedObj.selectEl = select;
      }

      select.addEventListener('change', () => {
        if (!canEdit) return;
        const newVal = Number(select.value);
        if (entry.kind === 'immune' || entry.kind === 'm_immune' || entry.kind === 'spell') {
          if (newVal === 0 && current === 1) {
            select.value = '1';
            return;
          }
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
        }</div>
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
  });

  box.appendChild(editsWrap);
  updateObjectCartUI();
}

async function queueObjectQuote(entry, targetModifier, selectEl) {
  const payload = {
    targetToonId,
    inventoryId: selectedInventoryId,
    location: Number(entry.location || 0),
    targetModifier,
  };
  if (entry.kind === 'flag' && entry.flag) {
    payload.flag = entry.flag;
  }
  const addingThisArtifact =
    entry.kind === 'flag' &&
    entry.flag === 'artifact' &&
    Number(targetModifier) === 1;
  /* +50% se pezzo gia' Artifact o Artifact gia' in coda (non sulla voce flag). */
  if (!addingThisArtifact && (objectAlreadyArtifact() || cartAddsArtifact())) {
    payload.pendingArtifact = true;
  }

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
  const qd = data.data;
  const yesNo = isYesNoObjectEntry(entry);
  const curLabel = yesNo
    ? qd.current
      ? 'Sì'
      : 'No'
    : entry.relative
      ? formatScalarOptionLabel(entry, Number(qd.current))
      : qd.current;
  const tgtLabel = yesNo
    ? qd.target
      ? 'Sì'
      : 'No'
    : entry.relative
      ? formatScalarOptionLabel(entry, Number(qd.target))
      : qd.target;
  ensureObjectCartExclusive();
  const wasAddingArtifact = cartAddsArtifact();
  objectEditCart.set(entry.id, {
    entryId: entry.id,
    location: Number(entry.location || 0),
    targetModifier,
    flag: entry.kind === 'flag' ? entry.flag : undefined,
    label: `${entry.label}: ${curLabel} → ${tgtLabel}`,
    quote: qd,
    selectEl,
    entry,
  });
  const nowAddingArtifact = cartAddsArtifact();
  if (wasAddingArtifact !== nowAddingArtifact || nowAddingArtifact) {
    await requoteObjectCartForArtifact();
  } else {
    rebuildObjectPendingFromCart();
  }
}

async function confirmPayEdit() {
  if (!pendingEdit || !pendingEdit.plan) return;

  const targetName = charState?.name || 'personaggio';
  const isStaffOnOther =
    session.role === 'staff' && Number(targetToonId) !== Number(session.sessionToonId);

  const msg1 = `Confermi il pagamento per:\n${pendingEdit.label}\n\nTotale: ${pendingEdit.plan.payXp.toLocaleString('it-IT')} XP (MXP) + ${pendingEdit.plan.payRune} ${currencyLabel('rune')}`;
  if (!confirm(msg1)) return;

  if (isStaffOnOther) {
    const msg2 = `STAFF: stai applicando un edit sul target "${targetName}" (toon ${targetToonId}). Confermi?`;
    if (!confirm(msg2)) return;
  }

  const body = {
    targetToonId,
    payXp: pendingEdit.plan.payXp,
    payRune: pendingEdit.plan.payRune,
  };

  const mode = $('pay-mode').value;
  const runePct = Number($('pay-rune-pct').value);

  let result;
  if (pendingEdit.type === 'character-batch') {
    const items = [...pendingEdit.items];
    result = { ok: true };
    for (const item of items) {
      const itemPlan = buildPaymentPlan(item.quote, mode, runePct);
      if (item.type === 'pool') {
        result = await api('/api/apply-pool', {
          method: 'POST',
          body: JSON.stringify({
            targetToonId,
            field: item.field,
            newValue: item.newValue,
            payXp: itemPlan.payXp,
            payRune: itemPlan.payRune,
          }),
        });
      } else if (item.type === 'resistance') {
        result = await api('/api/apply-resistance', {
          method: 'POST',
          body: JSON.stringify({
            targetToonId,
            damageType: item.damageType,
            value: item.value,
            payXp: itemPlan.payXp,
            payRune: itemPlan.payRune,
          }),
        });
      } else {
        result = { ok: false, error: 'Voce carrello personaggio non valida' };
      }
      if (!result.ok) break;
    }
  } else if (pendingEdit.type === 'pool') {
    result = await api('/api/apply-pool', {
      method: 'POST',
      body: JSON.stringify({
        ...body,
        field: pendingEdit.field,
        newValue: pendingEdit.newValue,
      }),
    });
  } else if (pendingEdit.type === 'resistance') {
    result = await api('/api/apply-resistance', {
      method: 'POST',
      body: JSON.stringify({
        ...body,
        damageType: pendingEdit.damageType,
        value: pendingEdit.value,
      }),
    });
  } else if (pendingEdit.type === 'object-batch' || pendingEdit.type === 'object') {
    /*
     * Applica Artifact per primo (flag gratis), poi le voci pagate:
     * cosi' AnalyzeObjEdit applica gia' il +50% listino sul pezzo.
     * Name/short/long: solo insieme al primo affect pagato (stesso apply).
     */
    const items =
      pendingEdit.type === 'object-batch'
        ? [...pendingEdit.items]
        : [pendingEdit];
    items.sort((a, b) => {
      const aa = a.flag === 'artifact' ? 1 : 0;
      const bb = b.flag === 'artifact' ? 1 : 0;
      return bb - aa;
    });

    const textDraft = getObjectTextDraft();
    const textDirty = objectTextDraftIsDirty(textDraft);
    if (textDirty) {
      if (
        textDraft.objName.length > textDraft.nameMax ||
        textDraft.shortDesc.length > textDraft.shortMax ||
        textDraft.description.length > textDraft.longMax
      ) {
        alert('Name/short/long troppo lunghi: correggi prima di pagare.');
        return;
      }
      if (!objectCartHasPaidAffect(items)) {
        alert(
          'Name/short/long si salvano solo insieme al pagamento di un nuovo affect (non da soli, non con solo Artifact).'
        );
        return;
      }
    }

    result = { ok: true };
    let textAttached = false;
    for (const item of items) {
      const itemPlan = buildPaymentPlan(item.quote, mode, runePct);
      const affectBody = {
        targetToonId,
        inventoryId: selectedInventoryId,
        location: item.location,
        targetModifier: item.targetModifier,
        payXp: itemPlan.payXp,
        payRune: itemPlan.payRune,
      };
      if (item.flag) {
        affectBody.flag = item.flag;
      }
      const isPaidAffect =
        item.flag !== 'artifact' &&
        (Number(item.quote?.xp_raw || item.quote?.diff_xp_raw || 0) > 0 ||
          Number(item.quote?.diff_rune || item.quote?.pq || 0) > 0);
      if (textDirty && !textAttached && isPaidAffect) {
        affectBody.objName = textDraft.objName;
        affectBody.shortDesc = textDraft.shortDesc;
        affectBody.description = textDraft.description;
        textAttached = true;
      }
      result = await api('/api/apply-affect', {
        method: 'POST',
        body: JSON.stringify(affectBody),
      });
      if (!result.ok) {
        break;
      }
    }
  } else if (pendingEdit.type === 'object-text') {
    alert(
      'Name/short/long non si salvano da soli: metti in coda un affect pagato e conferma il pagamento.'
    );
    return;
  } else {
    return;
  }

  if (result.ok) {
    $('apply-result').textContent = 'Edit applicato con successo.';
    const wasObject =
      pendingEdit.type === 'object' ||
      pendingEdit.type === 'object-batch' ||
      pendingEdit.type === 'object-text';
    const wasCharacter = isCharacterPendingType(pendingEdit.type);
    const invId = selectedInventoryId;
    clearObjectEditCart();
    clearCharacterEditCart();
    pendingEdit = null;
    updatePaymentUI();
    await loadCharacterState();
    if (wasObject && invId) {
      await loadInventory();
      const li = document.querySelector('#inventory-list .item.selected');
      if (li) await selectItem(invId, li);
    } else if (wasCharacter) {
      renderCharacterEdits();
    }
    /* Ricalcola riepilogo login per il PG appena editato (prossimo «Cambia personaggio»). */
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
  await api('/api/deselect-toon', { method: 'POST' });
  pendingEdit = null;
  targetToonId = null;
  const search = $('target-toon-search');
  if (search) search.value = '';
  clearTargetWorkspace('');
  await refreshMe();
};

$('btn-refresh-inv').onclick = () => loadInventory();

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

$('pay-mode').onchange = updatePaymentUI;
$('pay-rune-pct').oninput = updatePaymentUI;
$('btn-pay-edit').onclick = () => confirmPayEdit();

const btnResetChar = $('btn-reset-char-edits');
if (btnResetChar) {
  btnResetChar.onclick = () => {
    clearCharacterEditCart({ resetSelectors: true });
    if ($('apply-result')) $('apply-result').textContent = '';
  };
}
const btnResetObj = $('btn-reset-object-edits');
if (btnResetObj) {
  btnResetObj.onclick = () => {
    clearObjectEditCart({ resetSelectors: true });
    if ($('apply-result')) $('apply-result').textContent = '';
  };
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
      if ((row.slug === 'mxp' || row.slug === 'rune') && field === 'pays_listino') {
        cb.checked = true;
      }
      labEl.appendChild(cb);
      labEl.appendChild(document.createTextNode(` ${lab}`));
      flags.appendChild(labEl);
    });
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
    'Gold / Token / Credito edit: predisposte per il futuro. Restano invisibili ai PG finché non le segni visibili e abilitate.';
  body.appendChild(hint);
  extras.forEach((row) => renderRow(row, body));
  extrasWrap.appendChild(body);
  container.appendChild(extrasWrap);

  refreshPayModeLabels();
}

function currenciesFromUI() {
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
      pays_listino: !!paysEl?.checked,
    });
  });
  return {
    catalog,
    comment:
      'Valute portale. visible=false = nascosta ai player. pays_listino riservato a MXP/Rune per ora.',
  };
}

function refreshPayModeLabels() {
  const payMode = $('pay-mode');
  if (!payMode) return;
  const mxp = currencyLabel('mxp');
  const rune = currencyLabel('rune');
  const optMxp = payMode.querySelector('option[value="mxp"]');
  const optRune = payMode.querySelector('option[value="runes"]');
  const optMix = payMode.querySelector('option[value="mix"]');
  if (optMxp) optMxp.textContent = `Solo ${mxp} (exp)`;
  if (optRune) optRune.textContent = `Solo ${rune}`;
  if (optMix) optMix.textContent = `Misto ${mxp} + ${rune}`;
  const runePct = $('rune-pct-wrap');
  if (runePct) {
    const lab = runePct.querySelector('label, .field-label') || runePct;
    /* Keep structure: first text node before input — update via data attribute on wrap. */
  }
  const hint = document.querySelector('.payment-dock-hint');
  if (hint) {
    hint.innerHTML = `Costo sul <strong>personaggio target</strong> (${mxp} / ${rune}).`;
  }
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
  data.instances.forEach((i) => {
    const li = document.createElement('li');
    li.className = 'inst-item';
    li.innerHTML =
      `#${escapeHtml(i.id)} base ${escapeHtml(i.base_vnum)} owner ` +
      `<button type="button" class="linkish" data-owner="${escapeHtml(i.owner_name)}">${escapeHtml(i.owner_name)}</button>` +
      ` — ${mudTextToHtml(i.short_desc)}`;
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
    list.appendChild(li);
  });
};

restoreSavedLogin();
applyLoginUiMode();
$('header-meta').textContent = `UI build ${EDIT_PORTAL_UI_BUILD}`;
refreshMe();
