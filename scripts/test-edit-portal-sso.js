#!/usr/bin/env node
'use strict';
/**
 * Test HMAC SSO + path mount senza MySQL/myst.
 * Uso: node scripts/test-edit-portal-sso.js
 */
const { spawn } = require('child_process');
const crypto = require('crypto');
const path = require('path');
const http = require('http');

const PORT = 18080;
const SECRET = 'test-sso-secret-unit';
const BASE = '/edit';
const ROOT = path.join(__dirname, '..');

function b64urlEncode(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function mint(email, secret, ttl = 120) {
  const now = Math.floor(Date.now() / 1000);
  const payload = JSON.stringify({
    email: String(email).trim().toLowerCase(),
    iat: now,
    exp: now + ttl,
  });
  const payloadB64 = b64urlEncode(payload);
  const sig = crypto.createHmac('sha256', secret).update(payloadB64).digest();
  return `${payloadB64}.${b64urlEncode(sig)}`;
}

function req(method, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const r = http.request(
      {
        hostname: '127.0.0.1',
        port: PORT,
        path: urlPath,
        method,
        headers,
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
      },
    );
    r.on('error', reject);
    r.end();
  });
}

async function main() {
  const child = spawn(
    process.execPath,
    [path.join(ROOT, 'edit-portal', 'server.js')],
    {
      cwd: path.join(ROOT, 'edit-portal'),
      env: {
        ...process.env,
        EDIT_WEB_PORT: String(PORT),
        EDIT_BASE_PATH: BASE,
        EDIT_WP_SSO_SECRET: SECRET,
        EDIT_SSO_REQUIRED: '1',
        EDIT_ALLOW_PASSWORD_LOGIN: '0',
        EDIT_WP_SITE_URL: 'https://example.test',
        EDIT_COOKIE_SECURE: '0',
        EDIT_SESSION_SECRET: 'test-session',
        MYSQL_HOST: '127.0.0.1',
        MYSQL_PORT: '1',
        MYST_EDIT_API_URL: 'http://127.0.0.1:1',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );

  let boot = '';
  await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout boot: ' + boot)), 8000);
    child.stdout.on('data', (d) => {
      boot += d.toString();
      if (boot.includes('nebbie-edit-portal on')) {
        clearTimeout(t);
        resolve();
      }
    });
    child.stderr.on('data', (d) => {
      boot += d.toString();
    });
    child.on('exit', (code) => {
      clearTimeout(t);
      reject(new Error(`server exited ${code}: ${boot}`));
    });
  });

  const fails = [];
  const ok = (name, cond, detail) => {
    if (!cond) fails.push(`${name}: ${detail || 'fail'}`);
    else console.log(`OK ${name}`);
  };

  const root = await req('GET', '/');
  ok('root-redirect', root.status === 302 && String(root.headers.location).includes('/edit'), root.status);

  const health = await req('GET', `${BASE}/api/health`);
  const hj = JSON.parse(health.body);
  ok('health-basePath', hj.basePath === '/edit', JSON.stringify(hj));
  ok('health-sso', hj.ssoRequired === true && hj.allowPasswordLogin === false, JSON.stringify(hj));

  const cfg = await req('GET', `${BASE}/config.js`);
  ok('config-js', cfg.body.includes('EDIT_PORTAL_CONFIG') && cfg.body.includes('"/edit"'), cfg.body.slice(0, 120));

  const login = await req('POST', `${BASE}/api/login`);
  // express.json needs body — without body still 403 SSO
  const loginRes = await new Promise((resolve, reject) => {
    const r = http.request(
      {
        hostname: '127.0.0.1',
        port: PORT,
        path: `${BASE}/api/login`,
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': 2 },
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, body }));
      },
    );
    r.on('error', reject);
    r.write('{}');
    r.end();
  });
  ok('password-blocked', loginRes.status === 403 && loginRes.body.includes('SSO'), loginRes.body);

  const badTok = await req('GET', `${BASE}/api/sso/wordpress?token=bad`);
  ok('sso-bad-token', badTok.status === 401, badTok.status + badTok.body.slice(0, 80));

  const token = mint('player@example.com', SECRET);
  const sso = await req('GET', `${BASE}/api/sso/wordpress?token=${encodeURIComponent(token)}`);
  // MySQL down → connection error → 500 or hang; we only need signature path to run.
  // Without DB, establishSessionForEmail throws — catch? Currently uncaught → 500.
  ok(
    'sso-valid-sig-reaches-db',
    sso.status === 403 || sso.status === 503 || sso.status === 302,
    `status=${sso.status} body=${sso.body.slice(0, 120)}`,
  );

  child.kill('SIGTERM');
  await new Promise((r) => child.on('exit', r));

  if (fails.length) {
    console.error('FAILS:\n' + fails.join('\n'));
    process.exit(1);
  }
  console.log('all sso/path checks passed');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
