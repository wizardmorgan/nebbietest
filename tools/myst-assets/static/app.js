const state = {
  tab: "objects",
  page: 0,
  pageSize: 100,
  total: 0,
  meta: null,
  selected: null,
};

const TAB_CONFIG = {
  objects: {
    endpoint: "/api/objects",
    columns: [
      ["rnum", "R#"],
      ["vnum", "V#"],
      ["short_desc", "Nome"],
      ["type_name", "Tipo"],
      ["weight", "Peso"],
      ["cost", "Valore"],
      ["flags_text", "Extra"],
      ["wear_text", "Wear"],
    ],
    detailEndpoint: (row) => `/api/objects/${row.rnum}`,
    filters: [
      { id: "q", label: "Ricerca testo (FTS)", type: "text", placeholder: "spada, elmo, corona..." },
      { id: "rnum_min", label: "R# min", type: "number" },
      { id: "rnum_max", label: "R# max", type: "number" },
      { id: "vnum_min", label: "V# min (prototipo file)", type: "number" },
      { id: "vnum_max", label: "V# max (prototipo file)", type: "number" },
      { id: "zone_index", label: "Zona", type: "zone" },
      { id: "type_flag", label: "Tipo oggetto", type: "item_type" },
      { id: "flags", label: "Extra flags", type: "flag_checkboxes", enumKey: "extra_flags" },
      { id: "wear", label: "Wear flags", type: "flag_checkboxes", enumKey: "wear_flags" },
    ],
  },
  mobiles: {
    endpoint: "/api/mobiles",
    columns: [
      ["vnum", "VNUM"],
      ["short_desc", "Nome"],
      ["level", "Liv"],
      ["race_name", "Razza"],
      ["mobtype", "Tipo"],
      ["dam_dice", "Danni"],
      ["exp", "EXP"],
      ["act_text", "ACT"],
    ],
    detailEndpoint: (vnum) => `/api/mobiles/${vnum}`,
    filters: [
      { id: "q", label: "Ricerca testo (FTS)", type: "text" },
      { id: "vnum_min", label: "VNUM min", type: "number" },
      { id: "vnum_max", label: "VNUM max", type: "number" },
      { id: "zone_index", label: "Zona", type: "zone" },
      { id: "level_min", label: "Livello min", type: "number" },
      { id: "level_max", label: "Livello max", type: "number" },
      { id: "race", label: "Razza", type: "race" },
      { id: "mobtype", label: "Tipo mob", type: "text", placeholder: "S, A, L..." },
      { id: "act_flag", label: "ACT flag (bit)", type: "number" },
      { id: "aff_flag", label: "AFF flag (bit)", type: "number" },
    ],
  },
  rooms: {
    endpoint: "/api/rooms",
    columns: [
      ["vnum", "VNUM"],
      ["name", "Nome"],
      ["sector_name", "Settore"],
      ["flags_text", "Flag"],
      ["moblim", "Mob lim"],
    ],
    detailEndpoint: (vnum) => `/api/rooms/${vnum}`,
    filters: [
      { id: "q", label: "Ricerca testo (FTS)", type: "text" },
      { id: "vnum_min", label: "VNUM min", type: "number" },
      { id: "vnum_max", label: "VNUM max", type: "number" },
      { id: "zone_index", label: "Zona", type: "zone" },
      { id: "sector_type", label: "Settore", type: "sector" },
      { id: "room_flag", label: "Room flag (bit)", type: "number" },
    ],
  },
  zones: {
    endpoint: "/api/zones",
    columns: [
      ["zone_num", "Num"],
      ["name", "Nome"],
      ["bottom", "Da"],
      ["top", "A"],
      ["lifespan", "Life"],
      ["reset_mode", "Reset"],
    ],
    filters: [
      { id: "q", label: "Nome zona", type: "text" },
      { id: "zone_num", label: "Numero zona", type: "number" },
    ],
  },
  resets: {
    endpoint: "/api/resets",
    columns: [
      ["zone_num", "Zona"],
      ["command", "Cmd"],
      ["arg1", "Arg1"],
      ["arg2", "Arg2"],
      ["arg3", "Arg3"],
      ["raw_line", "Riga"],
    ],
    filters: [
      { id: "command", label: "Comando", type: "text", placeholder: "M,O,G,E,P,D" },
      { id: "arg_vnum", label: "VNUM mob/obj/stanza", type: "number" },
      { id: "zone_index", label: "Zona", type: "zone" },
      { id: "q", label: "Testo riga", type: "text" },
    ],
  },
  shops: {
    endpoint: "/api/shops",
    columns: [
      ["vnum", "Shop"],
      ["keeper", "Keeper"],
      ["in_room", "Stanza"],
      ["profit_buy", "Buy"],
      ["profit_sell", "Sell"],
    ],
    filters: [
      { id: "q", label: "Ricerca", type: "text" },
      { id: "keeper", label: "Keeper mob vnum", type: "number" },
      { id: "in_room", label: "Stanza vnum", type: "number" },
    ],
  },
  specials: {
    endpoint: "/api/specials",
    columns: [
      ["kind", "Tipo"],
      ["vnum", "VNUM"],
      ["proc_name", "Proc"],
      ["args", "Argomenti"],
    ],
    filters: [
      { id: "q", label: "Ricerca", type: "text" },
      { id: "kind", label: "Tipo", type: "text", placeholder: "M,O,R" },
      { id: "vnum", label: "VNUM", type: "number" },
      { id: "proc_name", label: "Nome proc", type: "text" },
    ],
  },
};

function $(sel) { return document.querySelector(sel); }

function showNetBanner(message) {
  const el = $("#netBanner");
  if (!el) return;
  el.hidden = false;
  el.innerHTML = message;
}

function checkProtocol() {
  if (location.protocol === "https:") {
    const httpUrl = `http://${location.host}${location.pathname}`;
    showNetBanner(
      `Stai usando <strong>HTTPS</strong> su una porta senza TLS. Il browser va in timeout. ` +
      `Apri <a href="${httpUrl}"><code>${httpUrl}</code></a> (con <strong>http://</strong>).`
    );
    return false;
  }
  return true;
}

async function api(path, timeoutMs = 20000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(path, { signal: ctrl.signal, cache: "no-store" });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} su ${path}`);
    }
    return res.json();
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error(`Timeout (${timeoutMs / 1000}s) su ${path} — server irraggiungibile o bloccato`);
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

function renderStats() {
  const counts = state.meta?.counts || {};
  const pills = Object.entries(counts).map(([k, v]) =>
    `<span class="stat-pill"><strong>${v}</strong> ${k}</span>`
  );
  if (state.meta?.lib_dir) {
    const when = state.meta.imported_at ? ` · ${state.meta.imported_at}` : "";
    pills.push(`<span class="stat-pill" title="Directory myst.obj usata all'ultimo import">sorgente: ${escapeHtml(state.meta.lib_dir)}${escapeHtml(when)}</span>`);
  }
  $("#stats").innerHTML = pills.join("");
}

function optionList(items, emptyLabel = "Tutti") {
  const opts = [`<option value="">${emptyLabel}</option>`];
  for (const [name, value] of items || []) {
    opts.push(`<option value="${value}">${name} (${value})</option>`);
  }
  return opts.join("");
}

function renderFilters() {
  const cfg = TAB_CONFIG[state.tab];
  const enums = state.meta?.enums || {};
  const zones = state.meta?.zones || [];
  const zoneOptions = [`<option value="">Tutte</option>`]
    .concat(zones.map(z => `<option value="${z.zone_index}">#${z.zone_num} ${z.name} [${z.bottom}-${z.top}]</option>`))
    .join("");

  const scalarFields = [];
  const panelFields = [];

  for (const f of cfg.filters) {
    if (f.type === "zone") {
      scalarFields.push(`<label>${f.label}<select data-filter="${f.id}">${zoneOptions}</select></label>`);
      continue;
    }
    if (f.type === "item_type") {
      scalarFields.push(`<label>${f.label}<select data-filter="${f.id}">${optionList(enums.item_types)}</select></label>`);
      continue;
    }
    if (f.type === "race") {
      scalarFields.push(`<label>${f.label}<select data-filter="${f.id}">${optionList(enums.races)}</select></label>`);
      continue;
    }
    if (f.type === "sector") {
      scalarFields.push(`<label>${f.label}<select data-filter="${f.id}">${optionList(enums.sectors)}</select></label>`);
      continue;
    }
    if (f.type === "flag_checkboxes") {
      const names = enums[f.enumKey] || [];
      const chips = names.map((name) =>
        `<label class="flag-chip"><input type="checkbox" data-filter="${f.id}" value="${name}"><span>${escapeHtml(name)}</span></label>`
      ).join("");
      panelFields.push(
        `<details class="flag-panel" open>` +
        `<summary>${escapeHtml(f.label)} <span class="flag-hint">— tutti quelli spuntati</span></summary>` +
        `<div class="flag-grid">${chips}</div></details>`
      );
      continue;
    }
    scalarFields.push(
      `<label>${f.label}<input data-filter="${f.id}" type="${f.type}" placeholder="${f.placeholder || ""}"></label>`
    );
  }

  $("#filters").innerHTML = `
    <div class="filter-row">${scalarFields.join("")}</div>
    ${panelFields.join("")}
    <div class="filter-actions">
      <button id="searchBtn" type="button">Cerca</button>
      <button id="resetBtn" class="ghost" type="button">Reset</button>
    </div>`;

  $("#searchBtn").onclick = () => { state.page = 0; loadResults(); };
  $("#resetBtn").onclick = () => {
    $("#filters").querySelectorAll("[data-filter]").forEach((el) => {
      if (el.type === "checkbox") {
        el.checked = false;
      } else {
        el.value = "";
      }
    });
    state.page = 0;
    loadResults();
  };

  $("#filters").querySelectorAll("input[data-filter]:not([type=checkbox]), select[data-filter]").forEach((el) => {
    el.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        state.page = 0;
        loadResults();
      }
    });
  });
}

function currentFilterParams() {
  const params = new URLSearchParams();
  const checkboxGroups = {};

  $("#filters").querySelectorAll("[data-filter]").forEach((el) => {
    if (el.type === "checkbox") {
      if (el.checked) {
        const id = el.dataset.filter;
        if (!checkboxGroups[id]) checkboxGroups[id] = [];
        checkboxGroups[id].push(el.value);
      }
      return;
    }
    if (el.value !== "") params.set(el.dataset.filter, el.value);
  });

  for (const [id, values] of Object.entries(checkboxGroups)) {
    if (values.length) params.set(id, values.join(","));
  }

  params.set("limit", state.pageSize);
  params.set("offset", state.page * state.pageSize);
  return params;
}

function renderTable(items) {
  const cfg = TAB_CONFIG[state.tab];
  const thead = $("#resultsTable thead");
  const tbody = $("#resultsTable tbody");
  thead.innerHTML = `<tr>${cfg.columns.map(([, label]) => `<th>${label}</th>`).join("")}</tr>`;
  tbody.innerHTML = items.map((row, idx) => {
    const cells = cfg.columns.map(([key]) => `<td>${escapeHtml(String(row[key] ?? ""))}</td>`).join("");
    return `<tr data-idx="${idx}">${cells}</tr>`;
  }).join("");

  tbody.querySelectorAll("tr").forEach((tr) => {
    tr.onclick = () => {
      tbody.querySelectorAll("tr").forEach(r => r.classList.remove("selected"));
      tr.classList.add("selected");
      const row = items[Number(tr.dataset.idx)];
      state.selected = row;
      renderDetail(row);
    };
  });
}

function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function renderDetail(row) {
  const cfg = TAB_CONFIG[state.tab];
  const body = $("#detailBody");
  const id = row.rnum != null ? row.rnum : row.vnum;

  if (cfg.detailEndpoint && id != null) {
    body.innerHTML = `<div class="muted">Caricamento identify…</div>`;
    api(cfg.detailEndpoint(row))
      .then((data) => {
        if (data.error) {
          body.innerHTML =
            `<div class="muted">${escapeHtml(data.error)}` +
            (data.error === "not found"
              ? "<br><br>Prova <strong>Reimporta da lib</strong> se hai aggiornato myst.obj."
              : "") +
            `</div>`;
          return;
        }
        if (!data.characteristics?.summary_lines?.length) {
          body.innerHTML = `<div class="muted">Dettaglio senza blocco identify. Reimporta il database.</div>`;
          return;
        }
        body.innerHTML = renderDetailObject(data);
      })
      .catch((err) => {
        body.innerHTML = `<div class="muted">Errore dettaglio: ${escapeHtml(err.message)}</div>`;
      });
    return;
  }

  body.innerHTML = renderDetailObject(row);
}

function renderObjectCharacteristics(data) {
  const ch = data.characteristics;
  if (!ch) return "";

  const parts = [`<div class="obj-identify">`];
  for (const line of ch.summary_lines || []) {
    if (line === "Caratteristiche:") {
      parts.push(`<div class="obj-identify-heading">${escapeHtml(line)}</div>`);
    } else if (line.startsWith("    ")) {
      parts.push(`<div class="obj-identify-aff">${escapeHtml(line.trim())}</div>`);
    } else {
      parts.push(`<div class="obj-identify-line">${escapeHtml(line)}</div>`);
    }
  }
  parts.push("</div>");
  return parts.join("");
}

function renderDetailObject(data) {
  if (data.characteristics) {
    return renderObjectCharacteristics(data);
  }

  const skip = new Set([
    "affects_json", "extra_json", "exits_json", "producing_json", "trade_types_json",
    "messages_json", "search_text", "characteristics",
  ]);
  const parts = ["<dl class='kv'>"];
  for (const [key, value] of Object.entries(data)) {
    if (skip.has(key)) continue;
    if (value === null || value === "" || value === 0) continue;
    if (Array.isArray(value)) {
      parts.push(`<dt>${key}</dt><dd>${value.map(v => typeof v === "object" ? `<pre>${escapeHtml(JSON.stringify(v, null, 2))}</pre>` : escapeHtml(String(v))).join("<br>")}</dd>`);
      continue;
    }
    if (typeof value === "object") {
      parts.push(`<dt>${key}</dt><dd><pre>${escapeHtml(JSON.stringify(value, null, 2))}</pre></dd>`);
      continue;
    }
    parts.push(`<dt>${key}</dt><dd>${escapeHtml(String(value))}</dd>`);
  }
  parts.push("</dl>");
  return parts.join("");
}

async function loadResults() {
  const cfg = TAB_CONFIG[state.tab];
  const params = currentFilterParams();
  const data = await api(`${cfg.endpoint}?${params}`);
  state.total = data.total;
  renderTable(data.items || []);
  let countLabel = `${data.total} risultati`;
  const unknown = [
    ...(data.unknown_flags || []),
    ...(data.unknown_wear_flags || []),
  ];
  if (unknown.length) {
    countLabel += ` — flag sconosciuti: ${unknown.join(", ")}`;
  }
  $("#resultCount").textContent = countLabel;
  const pages = Math.max(1, Math.ceil(data.total / state.pageSize));
  $("#pageInfo").textContent = `${state.page + 1} / ${pages}`;
  $("#prevPage").disabled = state.page <= 0;
  $("#nextPage").disabled = state.page + 1 >= pages;
  $("#detailBody").innerHTML = `<div class="muted">Seleziona una riga per vedere il dettaglio completo.</div>`;
}

function switchTab(tab) {
  state.tab = tab;
  state.page = 0;
  state.selected = null;
  document.querySelectorAll(".tabs button").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });
  renderFilters();
  loadResults();
}

async function init() {
  if (!checkProtocol()) {
    $("#detailBody").innerHTML = `<div class="muted">Correggi l'URL (usa http://) e ricarica.</div>`;
    return;
  }

  const loading = document.createElement("div");
  loading.className = "loading-banner";
  loading.id = "loadingBanner";
  loading.textContent = "Connessione al server…";
  document.body.prepend(loading);

  try {
    state.meta = await api("/api/meta");
  } catch (err) {
    loading.remove();
    const origin = location.origin;
    showNetBanner(
      `Impossibile contattare l'API: <code>${escapeHtml(err.message)}</code>. ` +
      `Verifica <a href="${origin}/health"><code>${origin}/health</code></a> nel browser ` +
      `e che l'URL sia <code>http://</code> (non https).`
    );
    $("#detailBody").innerHTML = `<div class="muted">${escapeHtml(err.message)}</div>`;
    return;
  }

  loading.remove();
  renderStats();
  renderFilters();
  await loadResults();

  document.querySelectorAll(".tabs button").forEach((btn) => {
    btn.onclick = () => switchTab(btn.dataset.tab);
  });
  $("#prevPage").onclick = () => { if (state.page > 0) { state.page -= 1; loadResults(); } };
  $("#nextPage").onclick = () => { state.page += 1; loadResults(); };
  $("#reimportBtn").onclick = async () => {
    $("#reimportBtn").disabled = true;
    const res = await fetch("/api/reimport", { method: "POST" });
    const data = await res.json();
    state.meta = await api("/api/meta");
    renderStats();
    await loadResults();
    $("#reimportBtn").disabled = false;
    const src = data.lib_dir || state.meta?.lib_dir || "?";
    alert(`Reimport completato da:\n${src}\n\n${JSON.stringify(data.counts)}`);
  };
}

init().catch((err) => {
  $("#detailBody").innerHTML = `<div class="muted">Errore avvio: ${escapeHtml(err.message)}</div>`;
});
