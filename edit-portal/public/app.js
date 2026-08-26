'use strict';

const PQ_PER_MEGA_XP = 1000000;
const PRINCE_LEVEL = 51;
const LOGIN_STORAGE_KEY = 'nebbie-edit-login';

let session = null;
let targetToonId = null;
let charState = null;
let editCatalog = null;
let selectedInventoryId = null;
let selectedObjectOptions = null;
let pendingEdit = null;

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
 */
function mudTextToHtml(raw) {
  const text = String(raw ?? '');
  if (!text) return '';
  if (!/\$[cC]\d{4}/.test(text)) {
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
  while (i < text.length) {
    if (
      (text[i + 1] === 'c' || text[i + 1] === 'C') &&
      text[i] === '$' &&
      /^\d{4}/.test(text.slice(i + 2, i + 6))
    ) {
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
  const res = await fetch(path, {
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

function validatePayment(plan) {
  if (!charState) return { ok: false, reason: 'Stato PG non caricato' };
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
    return;
  }
  show('payment-panel');

  const mode = $('pay-mode').value;
  const runePct = Number($('pay-rune-pct').value);
  $('pay-rune-pct-label').textContent = `${runePct}%`;
  $('rune-pct-wrap').classList.toggle('hidden', mode !== 'mix');

  const plan = buildPaymentPlan(pendingEdit.quote, mode, runePct);
  const check = validatePayment(plan);

  $('payment-summary').innerHTML = `
    <strong>${pendingEdit.label}</strong><br>
    Costo listino: <strong>${plan.displayMxp}</strong>
    ${plan.runeListino ? ` (+ ${plan.runeListino} Runes componente listino)` : ''}
  `;

  $('payment-breakdown').innerHTML = `
    Pagherai: <strong>${plan.payXp.toLocaleString('it-IT')} XP</strong> raw (MXP)
    e <strong>${plan.payRune} Runes</strong><br>
    Disponibili: ${formatMxp(charState.available_mxp || 0, charState.available_mxp_frac || 0)}
    · ${charState.rune || 0} Runes<br>
  <span class="${check.okXp ? 'ok' : 'bad'}">MXP ${check.okXp ? 'OK' : 'insufficienti'}</span>
  · <span class="${check.okRune ? 'ok' : 'bad'}">Runes ${check.okRune ? 'OK' : 'insufficienti'}</span>
  `;

  $('btn-pay-edit').disabled = !check.ok;
  pendingEdit.plan = plan;
}

async function refreshMe() {
  const me = await api('/api/me');
  if (!me.ok) {
    session = null;
    show('login-panel');
    hide('toon-panel');
    hide('work-panel');
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
  $('header-meta').textContent = `${me.email} — ${me.sessionToonName} (${me.role}, lv ${me.maxLevel})`;

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

async function searchTargetToons(q) {
  const sel = $('target-toon');
  if (!sel) return;
  const query = String(q || '').trim();
  sel.innerHTML = '';
  if (query.length < 2) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = '— digita almeno 2 lettere —';
    sel.appendChild(opt);
    return;
  }
  const data = await api(`/api/target-toons?q=${encodeURIComponent(query)}`);
  if (!data.ok) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = data.error || 'errore ricerca';
    sel.appendChild(opt);
    return;
  }
  if (!data.toons?.length) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = 'Nessun personaggio trovato';
    sel.appendChild(opt);
    return;
  }
  data.toons.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = String(t.id);
    opt.textContent = `${t.name} (lv ${t.max_level ?? '?'})`;
    sel.appendChild(opt);
  });
}

async function loadTargetToons() {
  const sel = $('target-toon');
  if (!sel) return;

  if (session.role === 'staff') {
    targetToonId = null;
    sel.innerHTML = '';
    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = '— cerca un nome sopra —';
    sel.appendChild(placeholder);

    const search = $('target-toon-search');
    if (search && !search.dataset.bound) {
      search.dataset.bound = '1';
      search.addEventListener('input', () => {
        clearTimeout(targetSearchTimer);
        targetSearchTimer = setTimeout(() => searchTargetToons(search.value), 250);
      });
    }
    sel.onchange = async () => {
      targetToonId = getTargetToonId();
      pendingEdit = null;
      selectedInventoryId = null;
      updatePaymentUI();
      updateInventoryHeading();
      if (!targetToonId) {
        $('char-stats').textContent = 'Seleziona un personaggio dalla lista.';
        $('inventory-list').innerHTML = '';
        $('object-edits').innerHTML = '';
        $('quote-box').textContent =
          'Seleziona un personaggio target, poi un oggetto editabile.';
        return;
      }
      await loadCharacterState();
      await loadInventory();
    };
    updateInventoryHeading();
    $('char-stats').textContent = 'Cerca e seleziona un personaggio target.';
    $('inventory-list').innerHTML = '';
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
    pendingEdit = null;
    updatePaymentUI();
    await loadCharacterState();
    await loadInventory();
  };
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

async function loadCharacterState() {
  hideApiWarn();
  targetToonId = getTargetToonId();
  if (!targetToonId) {
    $('char-stats').textContent = 'Personaggio non selezionato';
    return;
  }
  const data = await api(`/api/character-state/${targetToonId}`);
  if (!data.ok) {
    charState = null;
    $('char-stats').textContent = data.error || 'Impossibile caricare stato PG (myst attivo?)';
    showApiWarn(`Stato personaggio: ${data.error}`);
    return;
  }
  charState = data.data;
  renderCharStats();
  renderCharacterEdits();
  updateInventoryHeading();
}

function renderCharStats() {
  const s = charState;
  $('char-stats').innerHTML = `
    <div class="stat-row"><span>Nome</span><strong>${s.name}</strong></div>
    <div class="stat-row"><span>Livello</span><strong>${s.max_level}</strong></div>
    <div class="stat-row"><span>MXP disponibili</span><strong>${formatMxp(s.available_mxp, s.available_mxp_frac)}</strong></div>
    <div class="stat-row"><span>Runes degli Eroi</span><strong>${s.rune}</strong></div>
    ${s.prince_reserve_mxp ? `<div class="stat-row hint">Riserva principi: ${s.prince_reserve_mxp} MXP</div>` : ''}
  `;
}

function catalogEntries(kind, target) {
  if (!editCatalog || !editCatalog.entries) return [];
  return editCatalog.entries.filter((e) => e.kind === kind && e.target === target && e.enabled);
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

  if (!charState || session.role === 'limited') {
    poolBox.innerHTML = '<p class="hint">Tier limited: edit non consentito.</p>';
    return;
  }

  const poolEntries = catalogEntries('pool', 'character');
  poolEntries.forEach((entry) => {
    const field = entry.pool_field;
    const cap = Number(entry.cap || charState.pool?.caps?.[field] || 0);
    const step = Number(entry.step || 10);
    const current = Number(charState.pool?.[field] || 0);
    const row = document.createElement('div');
    row.className = 'edit-row';
    const select = document.createElement('select');
    buildStepOptions(cap, step, current).forEach((v) => {
      const opt = document.createElement('option');
      opt.value = v;
      opt.textContent = v;
      if (v === current) opt.selected = true;
      select.appendChild(opt);
    });
    select.addEventListener('change', () => {
      if (Number(select.value) === current) {
        if (pendingEdit?.type === 'pool' && pendingEdit.field === field) {
          pendingEdit = null;
          updatePaymentUI();
        }
        return;
      }
      queuePoolQuote(field, Number(select.value), entry.label || field, select);
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
      const currentRow = (charState.resistances || []).find((r) => Number(r.damage_type) === dt);
      const current = currentRow ? Number(currentRow.value) : 0;
      const min = Number(entry.min ?? -100);
      const max = Number(entry.max ?? 100);
      const step = Number(entry.step ?? 25);
      const row = document.createElement('div');
      row.className = 'edit-row';
      const select = document.createElement('select');
      resistanceValueOptions(min, max, step).forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        if (v === current) opt.selected = true;
        select.appendChild(opt);
      });
      select.addEventListener('change', () => {
        if (Number(select.value) === current) {
          if (pendingEdit?.type === 'resistance' && pendingEdit.damageType === dt) {
            pendingEdit = null;
            updatePaymentUI();
          }
          return;
        }
        queueResistanceQuote(dt, Number(select.value), entry.label || entry.id, select);
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
}

async function queuePoolQuote(field, newValue, label, selectEl) {
  const data = await api('/api/quote-pool', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, field, newValue }),
  });
  if (!data.ok) {
    alert(data.error || 'Quote pool fallita');
    selectEl.value = String(data.data?.current ?? selectEl.dataset.prev ?? selectEl.value);
    return;
  }
  pendingEdit = {
    type: 'pool',
    field,
    newValue,
    label: `${label}: ${data.data.current} → ${data.data.target}`,
    quote: data.data,
    selectEl,
  };
  updatePaymentUI();
}

async function queueResistanceQuote(damageType, value, label, selectEl) {
  const data = await api('/api/quote-resistance', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, damageType, value }),
  });
  if (!data.ok) {
    alert(data.error || 'Quote resistenza fallita');
    return;
  }
  pendingEdit = {
    type: 'resistance',
    damageType,
    value,
    label: `${label}: ${data.data.current} → ${data.data.target}`,
    quote: data.data,
    selectEl,
  };
  updatePaymentUI();
}

async function loadInventory() {
  targetToonId = getTargetToonId();
  const prevSelected = selectedInventoryId;
  if (!targetToonId) {
    showApiWarn('Personaggio target non selezionato — cerca e seleziona un PG');
    updateInventoryHeading();
    return;
  }
  updateInventoryHeading();
  const data = await api(`/api/inventory/${targetToonId}`);
  const list = $('inventory-list');
  list.innerHTML = '';

  if (!data.ok) {
    showApiWarn(data.error || 'Errore caricamento inventario');
    $('inventory-empty').classList.add('hidden');
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
  const editableCount = Number(
    data.editable_count ?? items.filter((i) => i.editable).length,
  );
  const mysqlCount = Number(data.mysql_count ?? 0);
  const emptyEl = $('inventory-empty');
  emptyEl.classList.toggle('hidden', items.length > 0);
  if (!items.length) {
    if (mysqlCount > 0 && data.inventory_source === 'mysql_myst_empty') {
      emptyEl.textContent =
        'Elenco da MySQL (' +
        mysqlCount +
        ' oggetti). Myst non ha arricchito la lista: ricompila e riavvia myst (./scripts/mud-dev.sh stop-mud && deploy-edit).';
      emptyEl.classList.remove('hidden');
    } else {
      emptyEl.textContent =
        'Nessun oggetto in inventario MySQL per questo PG (logout in-game per salvare).';
    }
  }

  if (items.length && editableCount === 0) {
    showApiWarn('Inventario caricato: nessun oggetto editabile (vedi motivi nella lista).');
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

  items.forEach((it) => {
    const li = document.createElement('li');
    li.className = it.editable ? 'item' : 'item item-disabled';
    const worn = it.worn
      ? it.editable
        ? ' · indossato (ri-edit OK)'
        : ' · indossato'
      : '';
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

  if (!items.length && !data.mystListOk) {
    list.innerHTML = '<li class="hint">Inventario non disponibile — verifica che myst sia avviato e EDIT_API_SECRET allineato.</li>';
  }
}

async function selectItem(inventoryId, li) {
  document.querySelectorAll('#inventory-list .item').forEach((el) => el.classList.remove('selected'));
  if (li) li.classList.add('selected');
  selectedInventoryId = inventoryId;
  pendingEdit = null;
  selectedObjectOptions = null;
  updatePaymentUI();
  $('object-edits').innerHTML = '';
  $('object-affect-slots').innerHTML = '';
  hide('object-affect-slots');

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
  renderObjectEdits(d.entries || [], d.dam_budget);
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
      let detail = `<strong>${loc}</strong> = ${slot.modifier}`;
      if (slot.immune_labels) {
        detail += `<br><span class="slot-hint">${slot.immune_labels}</span>`;
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
  if (id.startsWith('immune.')) return 'Resistenze / immunità';
  if (['armor'].includes(id)) return 'Armatura';
  if (['hitndam', 'hitroll', 'damroll'].includes(id)) {
    return 'Combattimento';
  }
  return 'Caratteristiche';
}

/** Opzioni listino: min/max inclusivi, step in valore assoluto (AC step −10 → −40…0). */
function buildObjectScalarOptions(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const absStep = Math.abs(Number(entry.step)) || 1;
  const lo = Math.min(min, max);
  const hi = Math.max(min, max);
  const opts = [];
  for (let v = lo; v <= hi; v += absStep) {
    opts.push(v);
  }
  return opts;
}

function objectEntryCostHint(entry) {
  const mxp = Number(entry.mxp_per_step || 0);
  const rune = Number(entry.rune_per_step ?? mxp);
  if (!mxp) return '';
  return `Listino: ${mxp} MXP o ${rune} Runes / punto`;
}

function objectEntryRangeLabel(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const step = Number(entry.step) || 1;
  if (entry.kind === 'immune') return '';
  return ` (${min}…${max}, step ${step})`;
}

function objectEntrySlotHint(entry) {
  const slotIdx = Number(entry.occupied_slot);
  if (entry.kind === 'immune') {
    if (entry.has_affect && slotIdx >= 0) {
      return `slot #${slotIdx + 1} (immunità presente)`;
    }
    if (entry.can_add) return 'nuova immunità (usa slot RESISTANCE)';
    return 'nessuno slot libero';
  }
  if (entry.has_affect && slotIdx >= 0) {
    return `slot #${slotIdx + 1} occupato`;
  }
  if (entry.can_add) return 'nuovo bonus (usa uno slot libero)';
  return 'nessuno slot libero';
}

function clearObjectPending(entryId) {
  if (pendingEdit?.type === 'object' && pendingEdit.entryId === entryId) {
    pendingEdit = null;
    updatePaymentUI();
  }
}

function renderObjectEdits(entries, damBudget) {
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

  if (damBudget) {
    const hint = document.createElement('p');
    hint.className = 'hint';
    const charTotal = Number(damBudget.char_total || 0);
    const charMax = Number(damBudget.char_max || 30);
    const pieceMax = Number(damBudget.piece_max || 2);
    hint.textContent =
      `Dam editabile: ${charTotal}/${charMax} sul personaggio · max ${pieceMax} per pezzo (listino ufficiale).`;
    box.appendChild(hint);
  }

  let lastSection = '';
  entries.forEach((entry) => {
    const section = objectEditSection(entry.id || '');
    if (section !== lastSection) {
      const secTitle = document.createElement('div');
      secTitle.className = 'edit-section-title';
      secTitle.textContent = section;
      box.appendChild(secTitle);
      lastSection = section;
    }

    const current = Number(entry.current || 0);
    const canEdit = entry.can_edit !== false;
    const row = document.createElement('div');
    row.className = canEdit ? 'edit-row' : 'edit-row edit-row-disabled';
    const select = document.createElement('select');
    select.disabled = !canEdit || session.role === 'limited';

    if (entry.kind === 'immune') {
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
      if (current === 1) select.disabled = true;
    } else {
      const values = buildObjectScalarOptions(entry);
      if (!values.includes(current)) values.push(current);
      values.sort((a, b) => a - b);
      values.forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        if (v === current) opt.selected = true;
        select.appendChild(opt);
      });
    }

    if (!canEdit) {
      select.disabled = true;
    }

    select.addEventListener('change', () => {
      if (!canEdit) return;
      const newVal = Number(select.value);
      if (entry.kind === 'immune') {
        if (newVal === 0 && current === 1) {
          select.value = '1';
          return;
        }
        if (newVal === current) {
          clearObjectPending(entry.id);
          return;
        }
        queueObjectQuote(entry, newVal ? Number(entry.immune_bit) : 0, select);
      } else if (newVal === current) {
        clearObjectPending(entry.id);
      } else {
        queueObjectQuote(entry, newVal, select);
      }
    });

    row.innerHTML = `
      <div>
        <label>${entry.label || entry.id}${objectEntryRangeLabel(entry)}</label>
        <div class="current">Attuale: ${entry.kind === 'immune' ? (current ? 'Sì' : 'No') : current}</div>
        <div class="slot-hint">${objectEntrySlotHint(entry)}</div>
        ${entry.kind !== 'immune' ? `<div class="slot-hint">${objectEntryCostHint(entry)}</div>` : ''}
      </div>
    `;
    row.appendChild(select);
    box.appendChild(row);
  });
}

async function queueObjectQuote(entry, targetModifier, selectEl) {
  const data = await api('/api/quote-object-edit', {
    method: 'POST',
    body: JSON.stringify({
      targetToonId,
      inventoryId: selectedInventoryId,
      location: Number(entry.location),
      targetModifier,
    }),
  });
  if (!data.ok) {
    alert(data.error || 'Quote oggetto fallita');
    if (selectEl) {
      const cur = Number(entry.current || 0);
      selectEl.value = String(cur);
    }
    clearObjectPending(entry.id);
    return;
  }
  const qd = data.data;
  const curLabel = entry.kind === 'immune' ? (qd.current ? 'Sì' : 'No') : qd.current;
  const tgtLabel = entry.kind === 'immune' ? (qd.target ? 'Sì' : 'No') : qd.target;
  pendingEdit = {
    type: 'object',
    entryId: entry.id,
    location: Number(entry.location),
    targetModifier,
    label: `${entry.label}: ${curLabel} → ${tgtLabel}`,
    quote: qd,
    selectEl,
  };
  updatePaymentUI();
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

  let result;
  if (pendingEdit.type === 'pool') {
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
  } else if (pendingEdit.type === 'object') {
    result = await api('/api/apply-affect', {
      method: 'POST',
      body: JSON.stringify({
        ...body,
        inventoryId: selectedInventoryId,
        location: pendingEdit.location,
        targetModifier: pendingEdit.targetModifier,
      }),
    });
  } else {
    return;
  }

  if (result.ok) {
    $('apply-result').textContent = 'Edit applicato con successo.';
    const wasObject = pendingEdit.type === 'object';
    const invId = selectedInventoryId;
    pendingEdit = null;
    updatePaymentUI();
    await loadCharacterState();
    if (wasObject && invId) {
      await loadInventory();
      const li = document.querySelector('#inventory-list .item.selected');
      if (li) await selectItem(invId, li);
    }
  } else {
    $('apply-result').textContent = result.error || 'Apply fallito';
    alert(result.error || 'Apply fallito');
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
  await refreshMe();
};

$('btn-change-toon').onclick = async () => {
  await api('/api/deselect-toon', { method: 'POST' });
  pendingEdit = null;
  await refreshMe();
};

$('btn-refresh-inv').onclick = () => loadInventory();

$('pay-mode').onchange = updatePaymentUI;
$('pay-rune-pct').oninput = updatePaymentUI;
$('btn-pay-edit').onclick = () => confirmPayEdit();

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
    const res = await fetch('/api/health');
    const health = await res.json();
    const ver = health?.myst?.portal_api_version;
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
      'types: slug ITEM_* — spunta = visibile e editabile. Flag EDIT del PG = sempre incluso.',
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
refreshMe();
