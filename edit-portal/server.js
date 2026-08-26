'use strict';

const express = require('express');
const session = require('express-session');
const mysql = require('mysql2/promise');
const path = require('path');
const unixpass = require('unixpass');

const PORT = parseInt(process.env.EDIT_WEB_PORT || '3080', 10);
const SESSION_SECRET = process.env.EDIT_SESSION_SECRET || 'nebbie-edit-session-dev';
const MYST_API_URL = process.env.MYST_EDIT_API_URL || 'http://mudcompiler:8090';
const MYST_API_SECRET = process.env.EDIT_API_SECRET || 'nebbie-edit-dev-secret';

const STAFF_LEVEL = parseInt(process.env.EDIT_STAFF_LEVEL || '57', 10);
const LIMITED_LEVEL = parseInt(process.env.EDIT_LIMITED_LEVEL || '51', 10);
const PRINCE_LEVEL = parseInt(process.env.EDIT_PRINCE_LEVEL || '51', 10);
const PQ_PER_MEGA_XP = 2000000;
const SESSION_PQ_FEE = 1;

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

async function mystPost(pathSuffix, body) {
  const url = `${MYST_API_URL}${pathSuffix}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Edit-Api-Secret': MYST_API_SECRET,
    },
    body: JSON.stringify(body || {}),
  });
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return { ok: false, error: `risposta non JSON da myst: ${text.slice(0, 200)}` };
  }
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
app.use(express.json());
app.use(
  session({
    name: 'nebbie_edit_sid',
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: { httpOnly: true, sameSite: 'lax' },
  }),
);
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/login', async (req, res) => {
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
  delete req.session.sessionToonId;
  res.json({ ok: true, email: user.email });
});

app.post('/api/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

app.get('/api/me', requireAuth, (req, res) => {
  res.json({
    ok: true,
    email: req.session.email,
    sessionToonId: req.session.sessionToonId || null,
    sessionToonName: req.session.sessionToonName || null,
    role: req.session.role || null,
    maxLevel: req.session.maxLevel || 0,
  });
});

app.get('/api/toons', requireAuth, async (req, res) => {
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

app.post('/api/select-toon', requireAuth, async (req, res) => {
  const toonId = Number(req.body.toonId);
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

app.post('/api/deselect-toon', requireAuth, (req, res) => {
  delete req.session.sessionToonId;
  delete req.session.sessionToonName;
  delete req.session.role;
  delete req.session.maxLevel;
  res.json({ ok: true });
});

app.get('/api/target-toons', requireAuth, requireSessionToon, async (req, res) => {
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
  let sql =
    `SELECT t.id, t.name, ${TOON_LEVEL_SQL} FROM toon t LEFT JOIN character_classes cc ON cc.toon_id = t.id`;
  const params = [];
  if (q) {
    sql += ' WHERE t.name LIKE ?';
    params.push(`%${q}%`);
  }
  sql += ' GROUP BY t.id, t.name, t.level ORDER BY t.name LIMIT 100';
  const [rows] = await dbPool.query(sql, params);
  res.json({ ok: true, toons: rows });
});

app.get('/api/edit-catalog', requireAuth, requireSessionToon, async (_req, res) => {
  const result = await mystPost('/internal/get-edit-catalog', {});
  res.status(result.ok ? 200 : 400).json(result);
});

app.get('/api/character-state/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.params.toonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/get-character-state', { toon_id: targetToonId });
  res.status(result.ok ? 200 : 400).json(result);
});

app.post('/api/quote-pool', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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

app.post('/api/quote-resistance', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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

app.get('/api/inventory/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.params.toonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const online = await mystPost('/internal/is-online', { toon_id: targetToonId });
  const list = await mystPost('/internal/list-inventory', { toon_id: targetToonId });
  res.json({
    ok: true,
    online: online.ok ? online.data.online : false,
    items: list.ok ? list.data.items : [],
    mystErrors: [online.ok ? null : online.error, list.ok ? null : list.error].filter(Boolean),
    mystOnlineOk: online.ok,
    mystListOk: list.ok,
  });
});

app.post('/api/quote', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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

app.post('/api/apply-affect', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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
    modifier: Number(req.body.modifier),
    pay_xp: Number(req.body.payXp || 0),
    pay_rune: Number(req.body.payRune || 0),
  });
  res.status(result.ok ? 200 : 400).json(result);
});

app.post('/api/apply-pool', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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

app.post('/api/apply-resistance', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.body.targetToonId);
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

app.get('/api/resistances/:toonId', requireAuth, requireSessionToon, async (req, res) => {
  const targetToonId = Number(req.params.toonId);
  if (req.session.role !== 'staff' && targetToonId !== req.session.sessionToonId) {
    return res.status(403).json({ ok: false, error: 'accesso negato' });
  }
  const result = await mystPost('/internal/list-resistances', { toon_id: targetToonId });
  res.status(result.ok ? 200 : 400).json(result);
});

app.get('/api/staff/system-config', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    return res.status(403).json({ ok: false, error: 'solo staff' });
  }
  const result = await mystPost('/internal/get-system-config', {});
  res.status(result.ok ? 200 : 400).json(result);
});

app.post('/api/staff/system-config', requireAuth, requireSessionToon, async (req, res) => {
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

app.get('/api/staff/instances', requireAuth, requireSessionToon, async (req, res) => {
  if (req.session.role !== 'staff') {
    return res.status(403).json({ ok: false, error: 'solo staff' });
  }
  const q = String(req.query.q || '').trim();
  let sql =
    'SELECT id, base_vnum, owner_name, short_desc, cost FROM object_instance WHERE deleted = 0';
  const params = [];
  if (q) {
    sql += ' AND (owner_name LIKE ? OR short_desc LIKE ? OR obj_name LIKE ? OR id = ?)';
    const asNum = Number(q);
    params.push(`%${q}%`, `%${q}%`, `%${q}%`, Number.isFinite(asNum) ? asNum : 0);
  }
  sql += ' ORDER BY id DESC LIMIT 100';
  const [rows] = await dbPool.query(sql, params);
  res.json({ ok: true, instances: rows });
});

app.get('/api/health', async (_req, res) => {
  const myst = await mystPost('/internal/ping', {});
  res.json({
    ok: true,
    web: 'up',
    myst: myst.ok ? myst.data : null,
    mystError: myst.ok ? null : myst.error,
  });
});

app.listen(PORT, () => {
  console.log(`nebbie-edit-portal on http://0.0.0.0:${PORT}`);
});
