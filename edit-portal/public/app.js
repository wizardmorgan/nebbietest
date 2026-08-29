'use strict';

const PQ_PER_MEGA_XP = 1000000;
const PRINCE_LEVEL = 51;
const LOGIN_STORAGE_KEY = 'nebbie-edit-login';
const INVENTORY_SORT_KEY = 'nebbie-edit-inventory-sort';
/** Bump insieme a index.html ?v= e a kEditPortalApiVersion (marker UI deploy). */
const EDIT_PORTAL_UI_BUILD = 32;

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
 * `$$` → `$` letterale. `$` singoli (wrapper tipo `$Forza$` dopo un codice
 * colore) non vengono mostrati — tipico di short_desc editati a mano.
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
      /*
       * `$$` → `$` letterale. Se il secondo `$` inizia `$cXXXX`, consuma solo
       * il primo (es. `$$c0007` → `$` + codice colore).
       */
      if (!open) {
        html += openSpan();
        open = true;
      }
      html += '$';
      i += isColorCodeAt(i + 1) ? 1 : 2;
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
    html += escapeHtml(text[i]);
    i += 1;
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
  if (rune > 0) parts.push(`${rune} Runes`);
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
      ${plan.runeListino ? ` (+ ${plan.runeListino} Runes listino)` : ''}
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
      }${!check.okRune ? ' (Runes)' : ''}.</div>`
    : '';

  $('payment-breakdown').innerHTML = `
    <div class="payment-pay-line">
      Pagherai: <strong>${plan.payXp.toLocaleString('it-IT')} XP</strong>
      + <strong>${plan.payRune} Runes</strong>
    </div>
    <div class="payment-avail-line">
      Disponibili: ${formatMxp(charState.available_mxp || 0, charState.available_mxp_frac || 0)}
      · ${charState.rune || 0} Runes
      · <span class="${check.okXp ? 'ok' : 'bad'}">MXP ${check.okXp ? 'OK' : 'insufficienti'}</span>
      · <span class="${check.okRune ? 'ok' : 'bad'}">Runes ${check.okRune ? 'OK' : 'insufficienti'}</span>
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
  const data = await api('/api/toons');
  const box = $('toon-list');
  box.innerHTML = '';
  if (!data.ok) {
    box.textContent = data.error || 'errore';
    return;
  }
  data.toons.forEach((t) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = `${t.name} — livello ${t.maxLevel}, ruolo ${t.role}`;
    btn.onclick = async () => {
      const sel = await api('/api/select-toon', {
        method: 'POST',
        body: JSON.stringify({ toonId: t.id }),
      });
      if (!sel.ok) {
        alert(sel.error);
        return;
      }
      await refreshMe();
    };
    box.appendChild(btn);
  });
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
    <div class="stat-row"><span>MXP disponibili</span><strong>${formatMxp(s.available_mxp, s.available_mxp_frac)}</strong></div>
    <div class="stat-row"><span>Runes degli Eroi</span><strong>${s.rune}</strong></div>
    ${s.prince_reserve_mxp ? `<div class="stat-row hint">Riserva principi: ${s.prince_reserve_mxp} MXP</div>` : ''}
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
        <label>${entry.label || field}</label>
        <div class="current">Attuale: ${current} / ${cap}</div>
      </div>
    `;
    row.appendChild(select);
    poolBox.appendChild(row);
  });

  const resEntries = catalogEntries('resistance', 'character');
  if (resEntries.length) {
    const title = document.createElement('h3');
    title.textContent = 'Resistenze';
    resBox.appendChild(title);
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
          <label>${entry.label || entry.id}</label>
          <div class="current">Attuale: ${current}</div>
        </div>
      `;
      row.appendChild(select);
      grid.appendChild(row);
    });
    resBox.appendChild(grid);
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
        ' oggetti ma myst non li ha arricchiti: ricompila/riavvia myst (API ≥26).';
    } else if (mysqlCount > 0 && data.inventory_source === 'myst_filtered') {
      emptyEl.textContent =
        'Myst ha filtrato tutto (' +
        (data.myst_loaded_rows ?? '?') +
        ' pezzi letti). Mostrati in sola lettura da MySQL — fai rebuild-myst (API ≥27) per ri-edit (pezzi instance/EDIT/owner sempre in lista).';
    } else if (mysqlCount > 0) {
      emptyEl.textContent =
        'Nessun oggetto mostrato, ma MySQL ha ' +
        mysqlCount +
        ' righe inventario. Verifica categorie staff e rebuild-myst (API ≥26).';
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
    showApiWarn(
      'Inventario filtrato da myst: lista da MySQL in sola lettura. Dopo rebuild-myst (API ≥27) i pezzi già editati/instance/owner tornano selezionabili.',
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
    d.diff_rune ? `Runes componente listino: ${d.diff_rune}` : '',
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
  renderObjectEdits(d.entries || [], d.dam_budget, d.sp_budget);
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
  if (id === 'artifact' || id.startsWith('flag.')) return 'Proprietà';
  if (id.startsWith('resist.') || id.startsWith('immune.')) {
    return 'Resistenze (APPLY_IMMUNE)';
  }
  if (id.startsWith('immunity.') || id.startsWith('m_immune.')) {
    return 'Immunità concesse (APPLY_M_IMMUNE)';
  }
  if (id.startsWith('spell.')) return 'Spell editabili';
  if (['armor', 'spellfail'].includes(id)) return 'Armatura / cast';
  if (['hitndam', 'hitnsp', 'hitroll', 'damroll', 'spellpower'].includes(id)) {
    return 'Combattimento';
  }
  return 'Caratteristiche';
}

/** Ordine alfabetico delle sezioni oggetto. */
const OBJECT_EDIT_SECTION_ORDER = [
  'Armatura / cast',
  'Caratteristiche',
  'Combattimento',
  'Immunità concesse (APPLY_M_IMMUNE)',
  'Proprietà',
  'Resistenze (APPLY_IMMUNE)',
  'Spell editabili',
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
    return `Listino: ${mxp} MXP o ${rune} Runes`;
  }
  if (Math.abs(step) !== 1) {
    return `Listino: ${mxp} MXP o ${rune} Runes / step ${step}`;
  }
  return `Listino: ${mxp} MXP o ${rune} Runes / punto`;
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
  summary.textContent = 'Name / short / long';
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

function renderObjectEdits(entries, damBudget, spBudget) {
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

  const title = document.createElement('h3');
  title.textContent = 'Edit sull\'oggetto';
  box.appendChild(title);

  if (damBudget || spBudget) {
    const hint = document.createElement('p');
    hint.className = 'hint budget-banner';
    const parts = [];
    if (damBudget) {
      let line = `Dam editato (EDIT in possesso) ${Number(damBudget.char_total || 0)}/${Number(damBudget.char_max || 30)} (max ${Number(damBudget.piece_max || 2)}/pezzo)`;
      const pc = Number(damBudget.piece_current);
      const pp = Number(damBudget.piece_proto);
      if (Number.isFinite(pc) && Number.isFinite(pp)) {
        line += ` — questo pezzo ${pc} vs proto ${pp} (delta +${Number(damBudget.piece || 0)})`;
        if (damBudget.piece_edit === false) {
          line += ' [non conteggiato: serve EDIT + owner ED/personal; simboli clan esclusi]';
        }
      }
      parts.push(line);
    }
    if (spBudget) {
      parts.push(
        `Spellpower editato (EDIT in possesso) ${Number(spBudget.char_total || 0)}/${Number(spBudget.char_max || 30)} (max ${Number(spBudget.piece_max || 2)}/pezzo)`
      );
    }
    hint.textContent =
      (parts.length
        ? parts.join(' · ') +
          ' — pezzi in possesso con EDIT e owner del toon (delta vs proto); simboli clan esclusi'
        : '') || '';
    box.appendChild(hint);

    const contrib = damBudget && Array.isArray(damBudget.contributors)
      ? damBudget.contributors.filter((c) => Number(c.delta) > 0)
      : [];
    if (contrib.length) {
      const ul = document.createElement('ul');
      ul.className = 'hint dam-budget-contributors';
      contrib.forEach((c) => {
        const li = document.createElement('li');
        li.textContent = `${c.short_desc || 'oggetto'}: +${Number(c.delta)} (ora ${Number(c.current)}, proto ${Number(c.proto)})`;
        ul.appendChild(li);
      });
      box.appendChild(ul);
    }
  }

  const grouped = new Map();
  entries.forEach((entry) => {
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
    summary.textContent = `${section} (${list.length})`;
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
      row.innerHTML = `
      <div>
        <label>${entry.label || entry.id}${objectEntryRangeLabel(entry)}</label>
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
          entry.kind === 'flag' ? entry.hint || '' : objectEntrySlotHint(entry)
        }</div>
        ${
          entry.kind !== 'flag'
            ? `<div class="slot-hint">${objectEntryCostHint(entry)}</div>`
            : ''
        }
      </div>
    `;
      row.appendChild(select);
      body.appendChild(row);
    });

    details.appendChild(body);
    box.appendChild(details);
  });
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

  const msg1 = `Confermi il pagamento per:\n${pendingEdit.label}\n\nTotale: ${pendingEdit.plan.payXp.toLocaleString('it-IT')} XP (MXP) + ${pendingEdit.plan.payRune} Runes`;
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
  await checkMystPortalVersion();
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
      'types: slug ITEM_* — spunta = visibile e editabile (primo edit). Senza spunta: nascosto; pezzi EDIT/instance/owner restano visibili per ri-edit.',
  };
}

$('btn-load-config').onclick = () => loadSystemConfig();

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
