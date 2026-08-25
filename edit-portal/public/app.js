'use strict';

let session = null;
let selectedInventoryId = null;
let targetToonId = null;

const $ = (id) => document.getElementById(id);

async function api(path, opts = {}) {
  const res = await fetch(path, {
    ...opts,
    headers: {
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({ ok: false, error: 'JSON invalido' }));
  if (!res.ok && data.ok === undefined) data.ok = false;
  return data;
}

function show(id) {
  $(id).classList.remove('hidden');
}
function hide(id) {
  $(id).classList.add('hidden');
}

async function refreshMe() {
  const me = await api('/api/me');
  if (!me.ok) {
    session = null;
    show('login-panel');
    hide('toon-panel');
    hide('work-panel');
    hide('btn-logout');
    return;
  }
  session = me;
  hide('login-panel');
  show('toon-panel');
  show('btn-logout');
  $('header-meta').textContent = me.email;
  if (me.sessionToonId) {
    await enterWorkMode();
  } else {
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
    btn.textContent = `${t.name} (lv ${t.maxLevel}, ${t.role})`;
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
  await loadTargetToons();
  if (me.role === 'staff') show('staff-panel');
  else hide('staff-panel');
}

async function loadTargetToons() {
  const data = await api('/api/target-toons');
  const sel = $('target-toon');
  sel.innerHTML = '';
  if (!data.ok) return;
  data.toons.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = t.id;
    opt.textContent = `${t.name} (lv ${t.max_level || t.maxLevel || '?'})`;
    sel.appendChild(opt);
  });
  targetToonId = Number(sel.value);
  sel.onchange = () => {
    targetToonId = Number(sel.value);
    loadInventory();
  };
  await loadInventory();
}

async function loadInventory() {
  targetToonId = Number($('target-toon').value);
  const data = await api(`/api/inventory/${targetToonId}`);
  const list = $('inventory-list');
  list.innerHTML = '';
  if (!data.ok) {
    list.textContent = data.error || 'errore inventario';
    return;
  }
  const warn = $('online-warn');
  if (data.online) {
    warn.textContent = 'ATTENZIONE: il toon target è collegato al mud — apply bloccato.';
    show('online-warn');
  } else {
    hide('online-warn');
  }
  (data.items || []).forEach((it) => {
    const li = document.createElement('li');
    li.className = 'item';
    li.textContent = `#${it.inventory_id} ${it.short_desc || it.name} (vnum ${it.item_number}, depth ${it.depth})`;
    li.onclick = () => selectItem(it.inventory_id, li);
    list.appendChild(li);
  });
}

async function selectItem(inventoryId, li) {
  document.querySelectorAll('#inventory-list .item').forEach((el) => el.classList.remove('selected'));
  li.classList.add('selected');
  selectedInventoryId = inventoryId;
  const q = await api('/api/quote', {
    method: 'POST',
    body: JSON.stringify({ targetToonId, inventoryId }),
  });
  $('quote-box').textContent = JSON.stringify(q, null, 2);
  if (session.role !== 'limited') show('apply-form');
}

$('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('login-error').textContent = '';
  const data = await api('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      email: $('login-email').value,
      password: $('login-password').value,
    }),
  });
  if (!data.ok) {
    $('login-error').textContent = data.error || 'login fallito';
    return;
  }
  await refreshMe();
});

$('btn-logout').onclick = async () => {
  await api('/api/logout', { method: 'POST' });
  await refreshMe();
};

$('btn-refresh-inv').onclick = () => loadInventory();

$('apply-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const result = await api('/api/apply-affect', {
    method: 'POST',
    body: JSON.stringify({
      targetToonId,
      inventoryId: selectedInventoryId,
      location: Number($('apply-location').value),
      modifier: Number($('apply-modifier').value),
      payXp: Number($('apply-pay-xp').value),
      payRune: Number($('apply-pay-rune').value),
    }),
  });
  $('apply-result').textContent = JSON.stringify(result, null, 2);
  if (selectedInventoryId) {
    const li = document.querySelector('#inventory-list .selected');
    if (li) selectItem(selectedInventoryId, li);
  }
});

$('pool-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const result = await api('/api/apply-pool', {
    method: 'POST',
    body: JSON.stringify({
      targetToonId,
      field: $('pool-field').value,
      delta: Number($('pool-delta').value),
      payXp: Number($('pool-pay-xp').value),
      payRune: Number($('pool-pay-rune').value),
    }),
  });
  $('apply-result').textContent = JSON.stringify(result, null, 2);
});

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

refreshMe();
