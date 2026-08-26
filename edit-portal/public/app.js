'use strict';

const PQ_PER_MEGA_XP = 2000000;
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

function getTargetToonId() {
  const fromSelect = Number($('target-toon')?.value);
  if (fromSelect > 0) return fromSelect;
  return Number(session?.sessionToonId || targetToonId || 0);
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
    loadSystemConfig();
  } else {
    hide('staff-panel');
    hide('target-toon-wrap');
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

async function loadTargetToons() {
  const data = await api('/api/target-toons');
  const sel = $('target-toon');
  sel.innerHTML = '';
  if (!data.ok) return;
  data.toons.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = t.id;
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
    showApiWarn('Personaggio target non selezionato — ricarica la pagina o cambia personaggio');
    return;
  }
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
      'Elenco da MySQL: myst non ha restituito oggetti — edit dettagliato limitato finché myst non è aggiornato.',
    );
  }

  items.forEach((it) => {
    const li = document.createElement('li');
    li.className = it.editable ? 'item' : 'item item-disabled';
    const worn = it.worn ? ' · indossato' : '';
    const depth = Number(it.depth) > 0 ? ' · in container' : '';
    const skip = it.skip_reason ? ` — ${it.skip_reason}` : '';
    li.textContent = `${it.short_desc || it.name} (vnum ${it.item_number})${worn}${depth}${skip}`;
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
  $('quote-box').textContent = [
    d.short_desc || '',
    d.owner_name ? `Owner: ${d.owner_name} (${d.owner_classes} classi, x${d.class_mult})` : '',
    d.item_type ? `Tipo: ${d.item_type}` : '',
    `Costo attuale vs prototipo: ${formatMxp(d.diff_xp_mega || 0, d.diff_xp_frac || 0)}`,
    d.diff_rune ? `Runes componente listino: ${d.diff_rune}` : '',
  ].filter(Boolean).join('\n');

  renderObjectEdits(d.entries || []);
}

function buildObjectScalarOptions(entry) {
  const min = Number(entry.min);
  const max = Number(entry.max);
  const step = Number(entry.step) || 1;
  const opts = [];
  for (let v = min; v <= max; v += step) {
    opts.push(v);
  }
  return opts;
}

function clearObjectPending(entryId) {
  if (pendingEdit?.type === 'object' && pendingEdit.entryId === entryId) {
    pendingEdit = null;
    updatePaymentUI();
  }
}

function renderObjectEdits(entries) {
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

  entries.forEach((entry) => {
    const current = Number(entry.current || 0);
    const row = document.createElement('div');
    row.className = 'edit-row';
    const select = document.createElement('select');

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

    select.addEventListener('change', () => {
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
        <label>${entry.label || entry.id}</label>
        <div class="current">Attuale: ${entry.kind === 'immune' ? (current ? 'Sì' : 'No') : current}</div>
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

async function loadSystemConfig() {
  const data = await api('/api/staff/system-config');
  if (!data.ok) {
    $('config-result').textContent = data.error || 'errore';
    return;
  }
  const cfg = data.data?.config || data.data;
  $('system-config-editor').value = JSON.stringify(cfg, null, 2);
  $('config-result').textContent = `path: ${data.data?.path || 'lib/edit_system.json'}`;
  applyPortalCategoriesToUI(cfg?.object_portal || {});
}

function applyPortalCategoriesToUI(portal) {
  $('portal-cat-armor').checked = portal.armor !== false;
  $('portal-cat-weapon').checked = portal.weapon !== false;
  $('portal-cat-edited').checked = portal.edited !== false;
}

function portalCategoriesFromUI() {
  return {
    armor: $('portal-cat-armor').checked,
    weapon: $('portal-cat-weapon').checked,
    edited: $('portal-cat-edited').checked,
    comment:
      'Categorie visibili nel portale. Food/potion non mostrati. edited = flag ITEM2_EDIT.',
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
    $('portal-cat-result').textContent = data.error || 'salvataggio fallito';
    return;
  }
  $('portal-cat-result').textContent = 'Categorie salvate. Ricarico inventario…';
  await loadEditCatalog();
  await loadInventory();
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
    li.textContent = `#${i.id} base ${i.base_vnum} owner ${i.owner_name} — ${i.short_desc}`;
    list.appendChild(li);
  });
};

restoreSavedLogin();
refreshMe();
