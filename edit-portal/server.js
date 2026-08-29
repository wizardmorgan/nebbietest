'use strict';

const crypto = require('crypto');
const express = require('express');
const session = require('express-session');
const mysql = require('mysql2/promise');
const path = require('path');
const unixpass = require('unixpass');

const fs = require('fs');

const PORT = parseInt(process.env.EDIT_WEB_PORT || '3080', 10);
const SESSION_SECRET = process.env.EDIT_SESSION_SECRET || 'nebbie-edit-session-dev';
const MYST_API_URL = process.env.MYST_EDIT_API_URL || 'http://mudcompiler:8090';
const MYST_API_SECRET = process.env.EDIT_API_SECRET || 'nebbie-edit-dev-secret';

/** Es. "/edit" dietro nginx; vuoto = root (dev locale :3080). */
function normalizeBasePath(raw) {
  if (raw == null || String(raw).trim() === '' || String(raw).trim() === '/') {
    return '';
  }
  let s = String(raw).trim();
  if (!s.startsWith('/')) s = `/${s}`;
  return s.replace(/\/+$/, '');
}
const BASE_PATH = normalizeBasePath(process.env.EDIT_BASE_PATH || '');

/** Shared secret con il mu-plugin WordPress (HMAC-SHA256). */
const WP_SSO_SECRET = String(process.env.EDIT_WP_SSO_SECRET || '').trim();
/**
 * SSO obbligatorio: default ON se c'è il secret WP.
 * Override: EDIT_SSO_REQUIRED=0|1
 * Password login locale: EDIT_ALLOW_PASSWORD_LOGIN=1
 */
const SSO_REQUIRED =
  process.env.EDIT_SSO_REQUIRED === '1' ||
  (process.env.EDIT_SSO_REQUIRED !== '0' && WP_SSO_SECRET.length > 0);
const ALLOW_PASSWORD_LOGIN =
  process.env.EDIT_ALLOW_PASSWORD_LOGIN === '1' || !SSO_REQUIRED;
const WP_SITE_URL = String(process.env.EDIT_WP_SITE_URL || '').replace(/\/+$/, '');
const WP_LOGIN_URL =
  String(process.env.EDIT_WP_LOGIN_URL || '').trim() ||
  (WP_SITE_URL ? `${WP_SITE_URL}/wp-login.php` : '');
/** Entry SSO sul sito WP (mu-plugin: ?nebbie_edit_sso=1). */
const WP_SSO_ENTRY_URL =
  String(process.env.EDIT_WP_SSO_ENTRY_URL || '').trim() ||
  (WP_SITE_URL ? `${WP_SITE_URL}/?nebbie_edit_sso=1` : '');
const COOKIE_SECURE =
  process.env.EDIT_COOKIE_SECURE === '1' ||
  process.env.NODE_ENV === 'production';
const SSO_TOKEN_TTL_SEC = parseInt(process.env.EDIT_WP_SSO_TTL_SEC || '120', 10);

/** Sorgente unica: public/app.js (ignora env stale nei compose). */
function readUiBuildFromAppJs() {
  try {
    const src = fs.readFileSync(path.join(__dirname, 'public', 'app.js'), 'utf8');
    const m = src.match(/EDIT_PORTAL_UI_BUILD\s*=\s*(\d+)/);
    if (m) return parseInt(m[1], 10);
  } catch (_) {
    /* fall through */
  }
  return 0;
}
const UI_BUILD = readUiBuildFromAppJs() || parseInt(process.env.EDIT_PORTAL_UI_BUILD || '10', 10);

const STAFF_LEVEL = parseInt(process.env.EDIT_STAFF_LEVEL || '57', 10);
const LIMITED_LEVEL = parseInt(process.env.EDIT_LIMITED_LEVEL || '51', 10);
const PRINCE_LEVEL = parseInt(process.env.EDIT_PRINCE_LEVEL || '51', 10);
const PQ_PER_MEGA_XP = 1000000;

const TOON_LEVEL_SQL =
  'COALESCE(MAX(cc.level), t.level, 0) AS max_level';

const dbPool = mysql.createPool({
  host: process.env.MYSQL_HOST || 'mysql',
  port: parseInt(process.env.MYSQL_PORT || '33306', 10),
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || 'secret',
  database: process.env.MYSQL_DATABASE || 'nebbie',
  waitForConnections: true,
  connectionLimit: 5,
});

function roleForLevel(maxLevel) {
  if (maxLevel >= STAFF_LEVEL) return 'staff';
  if (maxLevel < LIMITED_LEVEL) return 'limited';
  return 'player';
}

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

function checkAccountPassword(plain, storedHash) {
  const hash = String(storedHash || '');
  if (!plain || !hash) {
    return false;
  }
  // Hash moderni completi (md5/sha/bcrypt)
  if (hash.startsWith('$')) {
    return unixpass.check(plain, hash);
  }
  // Legacy myst: strncpy(crypt(pwd, salt), 10) — confronto come strcmp(crypt(arg, check), check)
  try {
    const computed = unixpass.crypt(plain, hash);
    if (computed === hash) {
      return true;
    }
    // Account con hash troncato a 10 char (CON_PWDNEW in interpreter.cpp)
    return computed.substring(0, hash.length) === hash;
  } catch {
    return false;
  }
}

async function fetchInventoryFromMysql(toonId) {
  const baseSql =
    'SELECT id, list_index, item_number, short_desc, obj_name, wear_pos, depth, ' +
    'parent_inventory_id, instance_id FROM character_inventory WHERE toon_id = ? ' +
    'ORDER BY list_index';
  try {
    const [rows] = await dbPool.query(
      'SELECT id, list_index, item_number, short_desc, obj_name, wear_pos, depth, ' +
        'parent_inventory_id, instance_id, deleted FROM character_inventory WHERE toon_id = ? ' +
        'ORDER BY list_index',
      [toonId],
    );
    return rows.filter((r) => r.deleted === 0 || r.deleted == null);
  } catch {
    const [rows] = await dbPool.query(baseSql, [toonId]);
    return rows;
  }
}

function inventoryRowsToPortalItems(rows, skipReason) {
  return rows.map((r) => {
    const wearPos = Number(r.wear_pos || 0);
    const worn = wearPos > 0;
    const hasInstance = Number(r.instance_id || 0) > 0;
    let reason = skipReason;
    if (worn) {
      reason = hasInstance
        ? 'indossato (dettagli: serve myst aggiornato)'
        : 'indossato (dettagli: serve myst)';
    }
    const item = {
      inventory_id: r.id,
      list_index: r.list_index,
      item_number: r.item_number,
      short_desc: r.short_desc,
      name: r.obj_name,
      wear_pos: wearPos,
      depth: Number(r.depth || 0),
      parent_inventory_id: r.parent_inventory_id,
      instance_id: r.instance_id,
      worn,
      editable: false,
    };
    if (reason) item.skip_reason = reason;
    return item;
  });
}

async function mystPost(pathSuffix, body) {
  const payload = { ...(body || {}) };
  if (payload.toon_id !== undefined && payload.toon_id !== null) {
    payload.toon_id = String(payload.toon_id);
  }
  if (payload.target_toon_id !== undefined && payload.target_toon_id !== null) {
    payload.target_toon_id = String(payload.target_toon_id);
  }
  const url = `${MYST_API_URL}${pathSuffix}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-edit-api-secret': MYST_API_SECRET,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(5000),
    });
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      return { ok: false, error: `risposta non JSON da myst: ${text.slice(0, 200)}` };
    }
    if (data.ok === undefined) {
      data.ok = res.ok;
    }
    return data;
  } catch (err) {
    return { ok: false, error: `myst unreachable: ${err.message || err}` };
  }
}

function b64urlEncode(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function b64urlDecodeToString(s) {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const b64 = String(s).replace(/-/g, '+').replace(/_/g, '/') + pad;
  return Buffer.from(b64, 'base64').toString('utf8');
}

function b64urlDecodeToBuffer(s) {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const b64 = String(s).replace(/-/g, '+').replace(/_/g, '/') + pad;
  return Buffer.from(b64, 'base64');
}

/**
 * Token WP: base64url(json).base64url(hmac-sha256)
 * json: { email, iat, exp }
 */
function verifyWordpressSsoToken(token) {
  if (!WP_SSO_SECRET) {
    return { ok: false, error: 'SSO WordPress non configurato (EDIT_WP_SSO_SECRET)' };
  }
  const parts = String(token || '').split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    return { ok: false, error: 'token SSO non valido' };
  }
  const [payloadB64, sigB64] = parts;
  const expected = crypto.createHmac('sha256', WP_SSO_SECRET).update(payloadB64).digest();
  let got;
  try {
    got = b64urlDecodeToBuffer(sigB64);
  } catch {
    return { ok: false, error: 'firma SSO non valida' };
  }
  if (got.length !== expected.length || !crypto.timingSafeEqual(got, expected)) {
    return { ok: false, error: 'firma SSO non valida' };
  }
  let payload;
  try {
    payload = JSON.parse(b64urlDecodeToString(payloadB64));
  } catch {
    return { ok: false, error: 'payload SSO non valido' };
  }
  const email = String(payload.email || '')
    .trim()
    .toLowerCase();
  if (!email || !email.includes('@')) {
    return { ok: false, error: 'email SSO mancante' };
  }
  const now = Math.floor(Date.now() / 1000);
  const exp = Number(payload.exp || 0);
  const iat = Number(payload.iat || 0);
  if (!exp || exp < now) {
    return { ok: false, error: 'token SSO scaduto' };
  }
  if (iat && iat > now + 60) {
    return { ok: false, error: 'token SSO non ancora valido' };
  }
  if (iat && exp - iat > SSO_TOKEN_TTL_SEC + 30) {
    return { ok: false, error: 'token SSO con TTL eccessivo' };
  }
  return { ok: true, email };
}

/** Solo per test/docs: genera token (non esporre in prod senza auth). */
function mintWordpressSsoToken(email, ttlSec = SSO_TOKEN_TTL_SEC) {
  const now = Math.floor(Date.now() / 1000);
  const payload = JSON.stringify({
    email: String(email).trim().toLowerCase(),
    iat: now,
    exp: now + ttlSec,
  });
  const payloadB64 = b64urlEncode(payload);
  const sig = crypto.createHmac('sha256', WP_SSO_SECRET).update(payloadB64).digest();
  return `${payloadB64}.${b64urlEncode(sig)}`;
}

async function establishSessionForEmail(req, email) {
  const [rows] = await dbPool.query(
    'SELECT id, email FROM user WHERE LOWER(email) = ? LIMIT 1',
    [email],
  );
  if (!rows.length) {
    return { ok: false, error: 'account Mud non trovato per questa email' };
  }
  const user = rows[0];
  req.session.userId = user.id;
  req.session.email = user.email;
  req.session.authVia = 'wordpress_sso';
  delete req.session.sessionToonId;
  delete req.session.sessionToonName;
  delete req.session.role;
  delete req.session.maxLevel;
  return { ok: true, email: user.email, userId: user.id };
}

function requireAuth(req, res, next) {
  if (!req.session.userId) {
    return res.status(401).json({ ok: false, error: 'login richiesto' });
  }
  next();
}

function requireSessionToon(req, res, next) {
  if (!req.session.sessionToonId) {
    return res.status(400).json({ ok: false, error: 'seleziona un personaggio' });
  }
  next();
}

const app = express();
app.set('trust proxy', 1);
app.use(express.json());

const router = express.Router();
router.use(
  session({
    name: 'nebbie_edit_sid',
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: COOKIE_SECURE,
      path: BASE_PATH || '/',
    },
  }),
);
router.use(express.static(path.join(__dirname, 'public')));

router.get('/api/auth-config', (_req, res) => {
  res.json({
    ok: true,
    basePath: BASE_PATH,
    ssoRequired: SSO_REQUIRED,
    allowPasswordLogin: ALLOW_PASSWORD_LOGIN,
    wordpressSsoConfigured: WP_SSO_SECRET.length > 0,
    wpSiteUrl: WP_SITE_URL || null,
    wpLoginUrl: WP_LOGIN_URL || null,
    wpSsoEntryUrl: WP_SSO_ENTRY_URL || null,
    ui_build: UI_BUILD,
  });
});

router.get('/config.js', (_req, res) => {
  const cfg = {
    basePath: BASE_PATH,
    ssoRequired: SSO_REQUIRED,
    allowPasswordLogin: ALLOW_PASSWORD_LOGIN,
    wordpressSsoConfigured: WP_SSO_SECRET.length > 0,
    wpSiteUrl: WP_SITE_URL || null,
    wpLoginUrl: WP_LOGIN_URL || null,
    wpSsoEntryUrl: WP_SSO_ENTRY_URL || null,
    ui_build: UI_BUILD,
  };
  res
    .type('application/javascript')
    .send(`window.EDIT_PORTAL_CONFIG=${JSON.stringify(cfg)};`);
});

router.get('/api/sso/wordpress', async (req, res) => {
  const token = String(req.query.token || '');
  const verified = verifyWordpressSsoToken(token);
  if (!verified.ok) {
    return res.status(401).send(
      `<!doctype html><meta charset="utf-8"><title>SSO fallito</title>` +
        `<p>Accesso WordPress fallito: ${escapeHtml(verified.error)}</p>` +
        (WP_LOGIN_URL
          ? `<p><a href="${escapeHtml(WP_LOGIN_URL)}">Torna al login del sito</a></p>`
          : ''),
    );
  }
  try {
    const established = await establishSessionForEmail(req, verified.email);
    if (!established.ok) {
      return res.status(403).send(
        `<!doctype html><meta charset="utf-8"><title>Account assente</title>` +
          `<p>${escapeHtml(established.error)}</p>` +
          `<p>L'email WordPress deve coincidere con un account nella tabella <code>user</code> del Mud.</p>`,
      );
    }
    return res.redirect(`${BASE_PATH}/`);
  } catch (err) {
    console.error('[sso/wordpress]', err);
    return res.status(503).send(
      `<!doctype html><meta charset="utf-8"><title>SSO errore</title>` +
        `<p>Impossibile completare l'accesso (database non disponibile).</p>`,
    );
  }
});

function escapeHtml(s) {
  return String(s || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

router.post('/api/login', async (req, res) => {
  if (!ALLOW_PASSWORD_LOGIN) {
    return res.status(403).json({
      ok: false,
      error: 'Login password disabilitato: accedi dal sito WordPress (SSO)',
      ssoRequired: true,
    });
  }
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  if (!email || !password) {
    return res.status(400).json({ ok: false, error: 'email e password richieste' });
  }
  const [rows] = await dbPool.query(
    'SELECT id, email, password FROM user WHERE LOWER(email) = ? LIMIT 1',
    [email],
  );
  if (!rows.length) {
    return res.status(401).json({ ok: false, error: 'credenziali non valide' });
  }
  const user = rows[0];
  const hash = String(user.password || '');
  if (!checkAccountPassword(password, hash)) {
    return res.status(401).json({ ok: false, error: 'credenziali non valide' });
  }
  req.session.userId = user.id;
  req.session.email = user.email;
  req.session.authVia = 'password';
  delete req.session.sessionToonId;
  res.json({ ok: true, email: user.email });
});

router.post('/api/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

router.get('/api/me', requireAuth, (req, res) => {
  res.json({
    ok: true,
    email: req.session.email,
    sessionToonId: req.session.sessionToonId || null,
    sessionToonName: req.session.sessionToonName || null,
    role: req.session.role || null,
    maxLevel: req.session.maxLevel || 0,
    authVia: req.session.authVia || null,
    basePath: BASE_PATH,
  });
});

router.get('/api/toons', requireAuth, async (req, res) => {
  const [rows] = await dbPool.query(
    `SELECT t.id, t.name, t.title, ${TOON_LEVEL_SQL}
     FROM toon t
     LEFT JOIN character_classes cc ON cc.toon_id = t.id
     WHERE t.owner_id = ?
     GROUP BY t.id, t.name, t.title, t.level
     ORDER BY t.name`,
    [req.session.userId],
  );
  const toons = rows.map((r) => ({
    id: r.id,
    name: r.name,
    title: r.title,
    maxLevel: r.max_level,
    role: roleForLevel(r.max_level),
  }));
  res.json({ ok: true, toons });
});

router.post('/api/select-toon', requireAuth, async (req, res) => {
  const toonId = parseToonId(req.body.toonId);
  if (!toonId) {
    return res.status(400).json({ ok: false, error: 'toonId richiesto' });
  }
  const [rows] = await dbPool.query(
    `SELECT t.id, t.name, ${TOON_LEVEL_SQL}
     FROM toon t
     LEFT JOIN character_classes cc ON cc.toon_id = t.id
     WHERE t.id = ? AND t.owner_id = ?
     GROUP BY t.id, t.name, t.level`,
    [toonId, req.session.userId],
  );
  if (!rows.length) {
    return res.status(403).json({ ok: false, error: 'personaggio non trovato su questo account' });
  }
  const t = rows[0];
  req.session.sessionToonId = t.id;
  req.session.sessionToonName = t.name;
  req.session.maxLevel = t.max_level;
  req.session.role = roleForLevel(t.max_level);
  res.json({
    ok: true,
    toon: { id: t.id, name: t.name, maxLevel: t.max_level, role: req.session.role },
  });
});

router.post('/api/deselect-toon', requireAuth, (req, res) => {
  delete req.session.sessionToonId;
  delete req.session.sessionToonName;
  delete req.session.role;
  delete req.session.maxLevel;
  res.json({ ok: true });
});

router.get('/api/target-toons', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    const [rows] = await dbPool.query(
      `SELECT t.id, t.name, ${TOON_LEVEL_SQL}
       FROM toon t
       LEFT JOIN character_classes cc ON cc.toon_id = t.id
       WHERE t.id = ?
       GROUP BY t.id, t.name, t.level`,
      [req.session.sessionToonId],
    );
    return res.json({ ok: true, toons: rows });
  }
  const q = String(req.query.q || '').trim();
  // Staff: senza ricerca non scaricare i primi 100 alfabeticamente (sembrano "solo quelli con A").
  if (!q || q.length < 2) {
    return res.json({
      ok: true,
      toons: [],
      hint: 'Digita almeno 2 lettere del nome del personaggio',
    });
  }
  let sql =
    `SELECT t.id, t.name, ${TOON_LEVEL_SQL} FROM toon t LEFT JOIN character_classes cc ON cc.toon_id = t.id`;
  const params = [];
  sql += ' WHERE t.name LIKE ?';
  params.push(`%${q}%`);
  sql += ' GROUP BY t.id, t.name, t.level ORDER BY t.name LIMIT 80';
  const [rows] = await dbPool.query(sql, params);
  res.json({ ok: true, toons: rows });
});

router.get('/api/edit-catalog', requireAuth, requireSessionToon, async (_req, res) => {
  const result = await mystPost('/internal/get-edit-catalog', {});
  res.status(result.ok ? 200 : 400).json(result);
});

router.get('/api/character-state/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.params.toonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/get-character-state', { toon_id: targetToonId });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/quote-pool', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/quote-pool', {
    toon_id: targetToonId,
    field: String(req.body.field || ''),
    new_value: req.body.newValue !== undefined ? Number(req.body.newValue) : undefined,
    delta: req.body.delta !== undefined ? Number(req.body.delta) : undefined,
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/quote-resistance', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/quote-resistance', {
    toon_id: targetToonId,
    damage_type: Number(req.body.damageType),
    value: Number(req.body.value),
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.get('/api/inventory/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.params.toonId);
  if (!targetToonId) {
    return res.status(400).json({ ok: false, error: 'toonId non valido' });
  }
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const online = await mystPost('/internal/is-online', { toon_id: targetToonId });
  const list = await mystPost('/internal/list-inventory', { toon_id: targetToonId });
  const mysqlRows = await fetchInventoryFromMysql(targetToonId);
  const mystLoadedRows = list.ok ? Number(list.data?.loaded_rows ?? -1) : -1;
  let items = list.ok ? list.data.items || [] : [];
  let total = list.ok ? Number(list.data.total ?? items.length) : 0;
  let editableCount = list.ok ? Number(list.data.editable_count ?? 0) : 0;
  let inventorySource = list.ok ? 'myst' : null;

  if (!list.ok && mysqlRows.length) {
    items = inventoryRowsToPortalItems(mysqlRows, 'dettagli edit non disponibili (myst)');
    total = items.length;
    editableCount = 0;
    inventorySource = 'mysql_fallback';
  } else if (
    list.ok &&
    items.length === 0 &&
    mysqlRows.length > 0 &&
    mystLoadedRows === 0
  ) {
    items = inventoryRowsToPortalItems(
      mysqlRows,
      'myst non legge character_inventory per questo toon_id',
    );
    total = items.length;
    editableCount = 0;
    inventorySource = 'mysql_myst_empty';
  } else if (list.ok && items.length === 0 && mysqlRows.length > 0 && mystLoadedRows > 0) {
    /* Myst ha letto le righe ma le ha nascoste (categorie / esclusioni vecchie).
     * Mostra comunque le righe MySQL cosi' il tester non vede "lista vuota". */
    items = inventoryRowsToPortalItems(
      mysqlRows,
      'nascosto da myst (categorie/filtri) — serve rebuild-myst API ≥27',
    );
    total = items.length;
    editableCount = 0;
    inventorySource = 'myst_filtered';
  }

  res.json({
    ok: true,
    online: online.ok ? online.data.online : false,
    items,
    total,
    editable_count: editableCount,
    mysql_count: mysqlRows.length,
    myst_loaded_rows: mystLoadedRows,
    myst_toon_name: list.ok ? list.data?.toon_name ?? null : null,
    myst_toon_name_ok: list.ok ? list.data?.toon_name_ok ?? null : null,
    inventory_source: inventorySource,
    mystErrors: [online.ok ? null : online.error, list.ok ? null : list.error].filter(Boolean),
    mystOnlineOk: online.ok,
    mystListOk: list.ok,
  });
});

router.post('/api/quote', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  const inventoryId = Number(req.body.inventoryId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/quote-item', {
    toon_id: targetToonId,
    inventory_id: inventoryId,
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/object-edit-options', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  const inventoryId = Number(req.body.inventoryId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/get-object-edit-options', {
    toon_id: targetToonId,
    inventory_id: inventoryId,
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/quote-object-edit', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  const inventoryId = Number(req.body.inventoryId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/quote-object-edit', {
    toon_id: targetToonId,
    inventory_id: inventoryId,
    location: Number(req.body.location),
    target_modifier: Number(req.body.targetModifier),
    flag: req.body.flag || '',
    pending_artifact: req.body.pendingArtifact ? 1 : 0,
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/quote-object-text', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  const inventoryId = Number(req.body.inventoryId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/quote-object-text', {
    toon_id: targetToonId,
    target_toon_id: targetToonId,
    inventory_id: inventoryId,
    obj_name: String(req.body.objName ?? req.body.name ?? ''),
    short_desc: String(req.body.shortDesc ?? ''),
    description: String(req.body.description ?? ''),
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/apply-affect', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  if (req.session.role === 'limited') {
    return res.status(403).json({ ok: false, error: 'tier limited: apply non consentito' });
  }
  const result = await mystPost('/internal/apply-affect', {
    target_toon_id: targetToonId,
    inventory_id: Number(req.body.inventoryId),
    location: Number(req.body.location),
    target_modifier: Number(req.body.targetModifier ?? req.body.modifier),
    pay_xp: Number(req.body.payXp || 0),
    pay_rune: Number(req.body.payRune || 0),
    flag: req.body.flag || '',
    obj_name: req.body.objName != null ? String(req.body.objName) : undefined,
    short_desc: req.body.shortDesc != null ? String(req.body.shortDesc) : undefined,
    description:
      req.body.description != null ? String(req.body.description) : undefined,
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/apply-object-text', requireAuth, requireSessionToon, async (req, res) => {
  return res.status(400).json({
    ok: false,
    error:
      'name/short/long non si salvano da soli: includili nel pagamento di un nuovo affect',
  });
});

router.post('/api/apply-pool', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  if (req.session.role === 'limited') {
    return res.status(403).json({ ok: false, error: 'tier limited: apply non consentito' });
  }
  const result = await mystPost('/internal/apply-pool', {
    target_toon_id: targetToonId,
    field: String(req.body.field || ''),
    new_value: req.body.newValue !== undefined ? Number(req.body.newValue) : undefined,
    delta: req.body.delta !== undefined ? Number(req.body.delta) : undefined,
    pay_xp: Number(req.body.payXp || 0),
    pay_rune: Number(req.body.payRune || 0),
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/apply-resistance', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.body.targetToonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  if (req.session.role === 'limited') {
    return res.status(403).json({ ok: false, error: 'tier limited: apply non consentito' });
  }
  const result = await mystPost('/internal/apply-resistance', {
    target_toon_id: targetToonId,
    damage_type: Number(req.body.damageType),
    value: Number(req.body.value),
    pay_xp: Number(req.body.payXp || 0),
    pay_rune: Number(req.body.payRune || 0),
  });
  res.status(result.ok ? 200 : 400).json(result);
});

router.get('/api/resistances/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = parseToonId(req.params.toonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/list-resistances', { toon_id: targetToonId });
  res.status(result.ok ? 200 : 400).json(result);
});

router.get('/api/staff/system-config', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    return res.status(403).json({ ok: false, error: 'solo staff' });
  }
  const result = await mystPost('/internal/get-system-config', {});
  res.status(result.ok ? 200 : 400).json(result);
});

router.post('/api/staff/system-config', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    return res.status(403).json({ ok: false, error: 'solo staff' });
  }
  let config = req.body.config;
  if (typeof config === 'string') {
    try {
      config = JSON.parse(config);
    } catch {
      return res.status(400).json({ ok: false, error: 'config JSON non valido' });
    }
  }
  const result = await mystPost('/internal/set-system-config', { config });
  res.status(result.ok ? 200 : 400).json(result);
});

router.get('/api/staff/instances', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    return res.status(403).json({ ok: false, error: 'solo staff' });
  }
  const q = String(req.query.q || '').trim();
  let sql =
    'SELECT id, base_vnum, owner_name, short_desc, cost FROM object_instance WHERE deleted = 0';
  const params = [];
  if (q) {
    sql +=
      ' AND (owner_name LIKE ? OR short_desc LIKE ? OR obj_name LIKE ? OR id = ? OR base_vnum = ? OR CAST(base_vnum AS CHAR) LIKE ?)';
    const asNum = Number(q);
    const num = Number.isFinite(asNum) ? asNum : 0;
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, num, num, `%${q}%`);
  }
  sql += ' ORDER BY id DESC LIMIT 100';
  const [rows] = await dbPool.query(sql, params);
  res.json({ ok: true, instances: rows });
});

router.get('/api/health', async (_req, res) => {
  const myst = await mystPost('/internal/ping', {});
  res.json({
    ok: true,
    web: 'up',
    ui_build: UI_BUILD,
    basePath: BASE_PATH,
    ssoRequired: SSO_REQUIRED,
    allowPasswordLogin: ALLOW_PASSWORD_LOGIN,
    wordpressSsoConfigured: WP_SSO_SECRET.length > 0,
    myst: myst.ok ? myst.data : null,
    mystError: myst.ok ? null : myst.error,
  });
});

/**
 * Solo locale/dev: mint token SSO (mai in prod: richiede SSO_REQUIRED).
 * Abilita con EDIT_DEV_MINT_SSO=1 e password login attivo.
 */
router.post('/api/dev/mint-sso', (req, res) => {
  if (SSO_REQUIRED || process.env.EDIT_DEV_MINT_SSO !== '1' || !WP_SSO_SECRET) {
    return res.status(404).json({ ok: false, error: 'not found' });
  }
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!email.includes('@')) {
    return res.status(400).json({ ok: false, error: 'email richiesta' });
  }
  const token = mintWordpressSsoToken(email);
  res.json({
    ok: true,
    token,
    redirect: `${BASE_PATH}/api/sso/wordpress?token=${encodeURIComponent(token)}`,
  });
});

app.use(BASE_PATH || '/', router);

if (BASE_PATH) {
  app.get('/', (_req, res) => res.redirect(`${BASE_PATH}/`));
}

app.listen(PORT, () => {
  console.log(
    `nebbie-edit-portal on http://0.0.0.0:${PORT}${BASE_PATH || ''} ` +
      `(ssoRequired=${SSO_REQUIRED}, passwordLogin=${ALLOW_PASSWORD_LOGIN})`,
  );
});
