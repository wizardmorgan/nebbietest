'use strict';

/**
 * Audit sessioni/eventi portale edit + notifier Telegram (digest + alert).
 *
 * Env:
 *   EDIT_TELEGRAM_BOT_TOKEN  placeholder di default: REPLACE_ME_TELEGRAM_BOT_TOKEN
 *   EDIT_TELEGRAM_CHAT_ID    placeholder di default: REPLACE_ME_TELEGRAM_CHAT_ID
 *   EDIT_TELEGRAM_ENABLED    "1" per inviare davvero (altrimenti solo log DB)
 */

const crypto = require('crypto');

const PLACEHOLDER_TOKEN = 'REPLACE_ME_TELEGRAM_BOT_TOKEN';
const PLACEHOLDER_CHAT = 'REPLACE_ME_TELEGRAM_CHAT_ID';

const TELEGRAM_BOT_TOKEN = String(
  process.env.EDIT_TELEGRAM_BOT_TOKEN || PLACEHOLDER_TOKEN,
).trim();
const TELEGRAM_CHAT_ID = String(
  process.env.EDIT_TELEGRAM_CHAT_ID || PLACEHOLDER_CHAT,
).trim();
const TELEGRAM_ENABLED = process.env.EDIT_TELEGRAM_ENABLED === '1';

function telegramConfigured() {
  if (!TELEGRAM_ENABLED) return false;
  if (!TELEGRAM_BOT_TOKEN || TELEGRAM_BOT_TOKEN === PLACEHOLDER_TOKEN) return false;
  if (!TELEGRAM_CHAT_ID || TELEGRAM_CHAT_ID === PLACEHOLDER_CHAT) return false;
  if (TELEGRAM_BOT_TOKEN.startsWith('REPLACE_ME_')) return false;
  if (TELEGRAM_CHAT_ID.startsWith('REPLACE_ME_')) return false;
  return true;
}

function newSessionKey() {
  return crypto.randomBytes(24).toString('hex');
}

async function ensureTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS edit_portal_session (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      session_key VARCHAR(64) NOT NULL,
      opened_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      closed_at TIMESTAMP NULL DEFAULT NULL,
      actor_account_id BIGINT UNSIGNED NULL,
      actor_email VARCHAR(255) NULL,
      actor_toon_id BIGINT UNSIGNED NULL,
      actor_toon_name VARCHAR(32) NULL,
      actor_role VARCHAR(16) NULL,
      actor_max_level INT NULL,
      client_ip VARCHAR(64) NULL,
      auth_via VARCHAR(32) NULL,
      status VARCHAR(16) NOT NULL DEFAULT 'open',
      summary_json MEDIUMTEXT NULL,
      PRIMARY KEY (id),
      UNIQUE KEY uq_edit_portal_session_key (session_key),
      KEY idx_edit_portal_session_actor (actor_toon_id),
      KEY idx_edit_portal_session_opened (opened_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS edit_portal_event (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      session_id BIGINT UNSIGNED NULL,
      session_key VARCHAR(64) NULL,
      kind VARCHAR(48) NOT NULL,
      severity VARCHAR(8) NOT NULL DEFAULT 'info',
      actor_toon_id BIGINT UNSIGNED NULL,
      actor_name VARCHAR(32) NULL,
      target_toon_id BIGINT UNSIGNED NULL,
      target_name VARCHAR(32) NULL,
      inventory_id BIGINT UNSIGNED NULL,
      instance_id BIGINT UNSIGNED NULL,
      detail_json MEDIUMTEXT NULL,
      message VARCHAR(512) NULL,
      telegram_sent TINYINT NOT NULL DEFAULT 0,
      PRIMARY KEY (id),
      KEY idx_edit_portal_event_session_at (session_key, at),
      KEY idx_edit_portal_event_kind_at (kind, at),
      KEY idx_edit_portal_event_telegram (telegram_sent, severity, at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
}

async function logEvent(pool, {
  sessionKey = null,
  sessionId = null,
  kind,
  severity = 'info',
  actorToonId = null,
  actorName = null,
  targetToonId = null,
  targetName = null,
  inventoryId = null,
  instanceId = null,
  detail = null,
  message = null,
  notifyTelegram = false,
} = {}) {
  if (!kind) return null;
  const detailJson =
    detail == null ? null : typeof detail === 'string' ? detail : JSON.stringify(detail);
  const msg = message == null ? null : String(message).slice(0, 512);
  const [result] = await pool.query(
    `INSERT INTO edit_portal_event
      (session_id, session_key, kind, severity, actor_toon_id, actor_name,
       target_toon_id, target_name, inventory_id, instance_id, detail_json, message, telegram_sent)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
    [
      sessionId || null,
      sessionKey || null,
      String(kind).slice(0, 48),
      String(severity || 'info').slice(0, 8),
      actorToonId || null,
      actorName ? String(actorName).slice(0, 32) : null,
      targetToonId || null,
      targetName ? String(targetName).slice(0, 32) : null,
      inventoryId || null,
      instanceId || null,
      detailJson,
      msg,
    ],
  );
  const eventId = result.insertId;
  if (notifyTelegram && (severity === 'warn' || severity === 'crit')) {
    const text = formatAlertText({
      kind,
      severity,
      message: msg,
      actorName,
      targetName,
      sessionKey,
      detail,
    });
    const sent = await sendTelegram(text);
    if (sent && eventId) {
      await pool.query('UPDATE edit_portal_event SET telegram_sent = 1 WHERE id = ?', [
        eventId,
      ]);
    }
  }
  return eventId;
}

async function openSession(pool, meta = {}) {
  const sessionKey = newSessionKey();
  const [result] = await pool.query(
    `INSERT INTO edit_portal_session
      (session_key, actor_account_id, actor_email, actor_toon_id, actor_toon_name,
       actor_role, actor_max_level, client_ip, auth_via, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'open')`,
    [
      sessionKey,
      meta.actorAccountId || null,
      meta.actorEmail ? String(meta.actorEmail).slice(0, 255) : null,
      meta.actorToonId || null,
      meta.actorToonName ? String(meta.actorToonName).slice(0, 32) : null,
      meta.actorRole ? String(meta.actorRole).slice(0, 16) : null,
      meta.actorMaxLevel != null ? Number(meta.actorMaxLevel) : null,
      meta.clientIp ? String(meta.clientIp).slice(0, 64) : null,
      meta.authVia ? String(meta.authVia).slice(0, 32) : null,
    ],
  );
  const sessionId = result.insertId;
  await logEvent(pool, {
    sessionKey,
    sessionId,
    kind: 'session.start',
    severity: 'info',
    actorToonId: meta.actorToonId || null,
    actorName: meta.actorToonName || null,
    message: `sessione aperta: ${meta.actorToonName || '?'} (${meta.actorRole || '?'})`,
    detail: {
      email: meta.actorEmail || null,
      authVia: meta.authVia || null,
      clientIp: meta.clientIp || null,
    },
  });
  return { sessionKey, sessionId };
}

async function buildSessionDigest(pool, sessionKey) {
  const [rows] = await pool.query(
    `SELECT kind, severity, message, actor_name, target_name, at
     FROM edit_portal_event
     WHERE session_key = ?
     ORDER BY id ASC
     LIMIT 500`,
    [sessionKey],
  );
  const counts = {};
  for (const r of rows) {
    const k = r.kind || 'unknown';
    counts[k] = (counts[k] || 0) + 1;
  }
  const applies = rows.filter((r) => String(r.kind || '').startsWith('apply.'));
  const fails = rows.filter(
    (r) => r.severity === 'warn' || r.severity === 'crit' || String(r.kind || '').includes('fail'),
  );
  return {
    eventCount: rows.length,
    counts,
    applyCount: applies.length,
    failCount: fails.length,
    highlights: fails.slice(0, 12).map((r) => ({
      kind: r.kind,
      severity: r.severity,
      message: r.message,
      target: r.target_name,
      at: r.at,
    })),
  };
}

async function closeSession(pool, sessionKey, { reason = 'closed' } = {}) {
  if (!sessionKey) return null;
  const [sessions] = await pool.query(
    `SELECT id, actor_toon_name, actor_email, actor_role, status
     FROM edit_portal_session WHERE session_key = ? LIMIT 1`,
    [sessionKey],
  );
  if (!sessions.length) return null;
  const sess = sessions[0];
  if (sess.status !== 'open') return sess;

  const digest = await buildSessionDigest(pool, sessionKey);
  const summary = { reason, ...digest, closedAt: new Date().toISOString() };
  await pool.query(
    `UPDATE edit_portal_session
     SET status = 'closed', closed_at = CURRENT_TIMESTAMP, summary_json = ?
     WHERE session_key = ? AND status = 'open'`,
    [JSON.stringify(summary), sessionKey],
  );
  await logEvent(pool, {
    sessionKey,
    sessionId: sess.id,
    kind: 'session.end',
    severity: digest.failCount > 0 ? 'warn' : 'info',
    actorName: sess.actor_toon_name || null,
    message: `sessione chiusa (${reason}): ${digest.eventCount} eventi, ${digest.applyCount} apply, ${digest.failCount} fail`,
    detail: summary,
  });

  if (telegramConfigured()) {
    const lines = [
      `Edit portal — digest sessione`,
      `Actor: ${sess.actor_toon_name || '?'} (${sess.actor_role || '?'})`,
      `Email: ${sess.actor_email || '?'}`,
      `Motivo chiusura: ${reason}`,
      `Eventi: ${digest.eventCount} | apply: ${digest.applyCount} | fail: ${digest.failCount}`,
    ];
    for (const [k, n] of Object.entries(digest.counts || {})) {
      lines.push(`  ${k}: ${n}`);
    }
    for (const h of digest.highlights || []) {
      lines.push(`! [${h.severity}] ${h.kind}: ${h.message || ''}`);
    }
    const sent = await sendTelegram(lines.join('\n'));
    if (sent) {
      await pool.query(
        `UPDATE edit_portal_event SET telegram_sent = 1
         WHERE session_key = ? AND kind IN ('session.end') AND telegram_sent = 0`,
        [sessionKey],
      );
    }
  }
  return { ...sess, summary };
}

async function sendTelegram(text) {
  if (!telegramConfigured()) {
    return false;
  }
  const body = {
    chat_id: TELEGRAM_CHAT_ID,
    text: String(text || '').slice(0, 3500),
    disable_web_page_preview: true,
  };
  try {
    const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) {
      const t = await res.text().catch(() => '');
      console.warn('[portal-audit] telegram HTTP', res.status, t.slice(0, 200));
      return false;
    }
    return true;
  } catch (err) {
    console.warn('[portal-audit] telegram error:', err.message || err);
    return false;
  }
}

function formatAlertText({ kind, severity, message, actorName, targetName, sessionKey, detail }) {
  const lines = [
    `Edit portal — ${severity || 'info'}`,
    `Kind: ${kind || '?'}`,
    `Actor: ${actorName || '?'}`,
    `Target: ${targetName || '?'}`,
    `Msg: ${message || ''}`,
  ];
  if (sessionKey) lines.push(`Session: ${String(sessionKey).slice(0, 16)}…`);
  if (detail && typeof detail === 'object') {
    try {
      lines.push(`Detail: ${JSON.stringify(detail).slice(0, 400)}`);
    } catch {
      /* ignore */
    }
  }
  return lines.join('\n');
}

/**
 * Invia alert per eventi myst (warn/crit) ancora non notificati.
 */
async function flushPendingTelegram(pool, { limit = 20 } = {}) {
  if (!telegramConfigured()) return 0;
  const [rows] = await pool.query(
    `SELECT id, kind, severity, message, actor_name, target_name, session_key, detail_json
     FROM edit_portal_event
     WHERE telegram_sent = 0 AND severity IN ('warn', 'crit')
     ORDER BY id ASC
     LIMIT ?`,
    [limit],
  );
  let sent = 0;
  for (const r of rows) {
    let detail = null;
    if (r.detail_json) {
      try {
        detail = JSON.parse(r.detail_json);
      } catch {
        detail = r.detail_json;
      }
    }
    const ok = await sendTelegram(
      formatAlertText({
        kind: r.kind,
        severity: r.severity,
        message: r.message,
        actorName: r.actor_name,
        targetName: r.target_name,
        sessionKey: r.session_key,
        detail,
      }),
    );
    if (ok) {
      await pool.query('UPDATE edit_portal_event SET telegram_sent = 1 WHERE id = ?', [r.id]);
      sent += 1;
    }
  }
  return sent;
}

function clientIpFromReq(req) {
  const xf = req.headers && req.headers['x-forwarded-for'];
  if (xf) {
    const first = String(xf).split(',')[0].trim();
    if (first) return first;
  }
  return req.ip || null;
}

module.exports = {
  PLACEHOLDER_TOKEN,
  PLACEHOLDER_CHAT,
  TELEGRAM_BOT_TOKEN,
  TELEGRAM_CHAT_ID,
  TELEGRAM_ENABLED,
  telegramConfigured,
  ensureTables,
  openSession,
  closeSession,
  logEvent,
  sendTelegram,
  flushPendingTelegram,
  clientIpFromReq,
  newSessionKey,
};
