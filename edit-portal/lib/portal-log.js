'use strict';

/**
 * Log operativo del portale (INFO / DEBUG).
 * Non usare per audit di dominio (session/apply): quello resta in
 * edit-portal-audit.log via portal-audit.js.
 *
 * Env:
 *   EDIT_PORTAL_LOG_LEVEL  info|debug  (default info)
 *   EDIT_PORTAL_LOG        path file   (default /app/edit-portal.log)
 *                          vuoto/"-" = solo stdout
 */

const fs = require('fs');
const path = require('path');

const LEVELS = { error: 0, info: 1, debug: 2 };

function parseLevel(raw) {
  const s = String(raw || 'info')
    .trim()
    .toLowerCase();
  if (s === 'debug' || s === 'dbg' || s === '2') return 'debug';
  if (s === 'error' || s === 'err' || s === '0') return 'error';
  return 'info';
}

let currentLevel = parseLevel(process.env.EDIT_PORTAL_LOG_LEVEL);
const LOG_PATH = (() => {
  const raw = process.env.EDIT_PORTAL_LOG;
  if (raw === '' || raw === '-') return null;
  return String(raw || '/app/edit-portal.log').trim() || '/app/edit-portal.log';
})();

/** Solo chiavi sensibili (non "passwordLogin" / "allowPasswordLogin"). */
const SECRET_KEYS = /^(secret|password|passwd|token|authorization|cookie|api[_-]?secret|session[_-]?secret)$/i;

function scrub(value, depth = 0) {
  if (value == null) return value;
  if (depth > 4) return '[…]';
  if (typeof value === 'string') {
    if (value.length > 400) return `${value.slice(0, 400)}…`;
    return value;
  }
  if (typeof value !== 'object') return value;
  if (Array.isArray(value)) {
    return value.slice(0, 20).map((v) => scrub(v, depth + 1));
  }
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SECRET_KEYS.test(k)) {
      out[k] = '[redacted]';
    } else {
      out[k] = scrub(v, depth + 1);
    }
  }
  return out;
}

function shouldLog(levelName) {
  return LEVELS[levelName] <= LEVELS[currentLevel];
}

function writeLine(levelName, message, detail) {
  if (!shouldLog(levelName)) return;
  const ts = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  let line = `${ts} ${levelName.toUpperCase()} ${String(message || '').replace(/[\r\n]+/g, ' ')}`;
  if (detail !== undefined) {
    try {
      const d = scrub(detail);
      let js = typeof d === 'string' ? d : JSON.stringify(d);
      js = String(js).replace(/[\r\n]+/g, ' ');
      if (js.length > 800) js = `${js.slice(0, 800)}…`;
      line += ` ${js}`;
    } catch {
      /* ignore */
    }
  }
  line += '\n';
  try {
    process.stdout.write(line);
  } catch {
    /* ignore */
  }
  if (!LOG_PATH) return;
  try {
    const dir = path.dirname(LOG_PATH);
    if (dir && dir !== '.' && dir !== '/') {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.appendFileSync(LOG_PATH, line, { encoding: 'utf8' });
  } catch (err) {
    try {
      process.stderr.write(`[portal-log] write fail: ${err.message || err}\n`);
    } catch {
      /* ignore */
    }
  }
}

function setLevel(raw) {
  currentLevel = parseLevel(raw);
}

function getLevel() {
  return currentLevel;
}

function info(message, detail) {
  writeLine('info', message, detail);
}

function debug(message, detail) {
  writeLine('debug', message, detail);
}

function error(message, detail) {
  writeLine('error', message, detail);
}

module.exports = {
  info,
  debug,
  error,
  setLevel,
  getLevel,
  getLogPath: () => LOG_PATH,
  scrub,
};
