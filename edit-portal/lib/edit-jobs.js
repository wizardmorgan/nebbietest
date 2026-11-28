'use strict';

/**
 * Coda apply asincrona sul medesimo MySQL di gioco (niente DB parallelo).
 *
 * Job kind supportati dal worker:
 *   - tx_probe: misura TX (SELECT toon FOR UPDATE) senza mutare pezzi
 *   - read_snapshot: legge character_inventory e salva in result_json
 *   - apply_draft: commit bozza edit_portal_draft in TX (version check)
 *   - myst_apply: proxy apply verso myst (path+body), fuori dal pulse di gioco
 *   - myst_apply_batch: N apply in un solo job (un click "Applica tutto")
 *
 * Env:
 *   EDIT_JOB_WORKER_MS   intervallo poll worker (default 400)
 *   EDIT_ASYNC_JOBS      "1" abilita worker all'avvio server
 */

async function ensureJobTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS edit_portal_job (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      session_key VARCHAR(64) NOT NULL,
      toon_id BIGINT UNSIGNED NOT NULL,
      kind VARCHAR(48) NOT NULL,
      status VARCHAR(16) NOT NULL DEFAULT 'pending',
      payload_json MEDIUMTEXT NULL,
      result_json MEDIUMTEXT NULL,
      error_message VARCHAR(512) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      started_at TIMESTAMP NULL DEFAULT NULL,
      finished_at TIMESTAMP NULL DEFAULT NULL,
      PRIMARY KEY (id),
      KEY idx_edit_portal_job_status (status, id),
      KEY idx_edit_portal_job_toon_status (toon_id, status),
      KEY idx_edit_portal_job_session (session_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS edit_portal_draft (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      session_key VARCHAR(64) NOT NULL,
      toon_id BIGINT UNSIGNED NOT NULL,
      base_version VARCHAR(64) NULL,
      draft_json MEDIUMTEXT NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_edit_portal_draft_session (session_key),
      KEY idx_edit_portal_draft_toon (toon_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
}

async function countOpenJobs(pool, { sessionKey = null, toonId = null } = {}) {
  if (!sessionKey && !toonId) return 0;
  const clauses = [`status IN ('pending', 'running')`];
  const params = [];
  if (sessionKey) {
    clauses.push('session_key = ?');
    params.push(String(sessionKey).slice(0, 64));
  }
  if (toonId) {
    clauses.push('toon_id = ?');
    params.push(Number(toonId));
  }
  const [rows] = await pool.query(
    `SELECT COUNT(*) AS c FROM edit_portal_job WHERE ${clauses.join(' AND ')}`,
    params,
  );
  return Number(rows[0]?.c || 0);
}

async function enqueueJob(pool, { sessionKey, toonId, kind, payload = null }) {
  if (!sessionKey || !toonId || !kind) {
    throw new Error('sessionKey, toonId e kind obbligatori');
  }
  const [openJobs] = await pool.query(
    `SELECT id FROM edit_portal_job
     WHERE toon_id = ? AND status IN ('pending', 'running')
     LIMIT 1`,
    [toonId],
  );
  if (openJobs.length) {
    const err = new Error('job gia in coda o in esecuzione per questo personaggio');
    err.code = 'JOB_BUSY';
    throw err;
  }
  const payloadJson =
    payload == null ? null : typeof payload === 'string' ? payload : JSON.stringify(payload);
  const [result] = await pool.query(
    `INSERT INTO edit_portal_job (session_key, toon_id, kind, status, payload_json)
     VALUES (?, ?, ?, 'pending', ?)`,
    [String(sessionKey).slice(0, 64), Number(toonId), String(kind).slice(0, 48), payloadJson],
  );
  return { jobId: result.insertId };
}

async function getJob(pool, jobId) {
  const [rows] = await pool.query(
    `SELECT id, session_key, toon_id, kind, status, payload_json, result_json,
            error_message, created_at, started_at, finished_at
     FROM edit_portal_job WHERE id = ? LIMIT 1`,
    [jobId],
  );
  return rows[0] || null;
}

async function claimNextJob(conn) {
  const [rows] = await conn.query(
    `SELECT id FROM edit_portal_job WHERE status = 'pending' ORDER BY id ASC LIMIT 1 FOR UPDATE`,
  );
  if (!rows.length) return null;
  const id = rows[0].id;
  await conn.query(
    `UPDATE edit_portal_job SET status = 'running', started_at = CURRENT_TIMESTAMP WHERE id = ?`,
    [id],
  );
  const [full] = await conn.query(
    `SELECT id, session_key, toon_id, kind, status, payload_json
     FROM edit_portal_job WHERE id = ? LIMIT 1`,
    [id],
  );
  return full[0] || null;
}

async function finishJob(connOrPool, jobId, { ok, result = null, error = null }) {
  await connOrPool.query(
    `UPDATE edit_portal_job
     SET status = ?, result_json = ?, error_message = ?, finished_at = CURRENT_TIMESTAMP
     WHERE id = ?`,
    [
      ok ? 'done' : 'failed',
      result == null ? null : typeof result === 'string' ? result : JSON.stringify(result),
      error ? String(error).slice(0, 512) : null,
      jobId,
    ],
  );
}

/**
 * Verifica che la sessione audit sia ancora open e non scaduta.
 * job.toon_id e' il personaggio *target* dell'edit (Lab / staff su altro PG),
 * non l'attore: non confrontarlo con actor_toon_id.
 */
async function assertSessionOpen(conn, sessionKey, _jobToonId = null) {
  const [rows] = await conn.query(
    `SELECT id, status, expires_at, summary_json, actor_toon_id, actor_toon_name,
            (expires_at IS NOT NULL AND expires_at > NOW()) AS not_expired
     FROM edit_portal_session
     WHERE session_key = ?
     LIMIT 1`,
    [sessionKey],
  );
  if (!rows.length) {
    const err = new Error(
      'Sessione edit non trovata: riseleziona il personaggio di sessione (il login web non apre da solo la sessione edit).',
    );
    err.code = 'SESSION_MISSING';
    throw err;
  }
  const row = rows[0];
  let reason = '';
  try {
    const summary = row.summary_json ? JSON.parse(row.summary_json) : {};
    reason = summary.reason ? String(summary.reason) : '';
  } catch {
    reason = '';
  }
  if (row.status !== 'open') {
    const why =
      reason === 'ttl_expired'
        ? 'scaduta per inattivita'
        : reason
          ? `chiusa (${reason})`
          : 'non piu aperta';
    const err = new Error(
      `Sessione edit ${why}. Login web ancora valido: riseleziona il personaggio di sessione e riprova Lab/apply.`,
    );
    err.code = 'SESSION_CLOSED';
    throw err;
  }
  if (!Number(row.not_expired)) {
    const err = new Error(
      `Sessione edit scaduta (expires_at=${row.expires_at || 'null'}). Riseleziona il personaggio di sessione e riprova.`,
    );
    err.code = 'SESSION_EXPIRED';
    throw err;
  }
  return row;
}

function parsePayload(job) {
  if (!job.payload_json) return {};
  try {
    return typeof job.payload_json === 'string'
      ? JSON.parse(job.payload_json)
      : job.payload_json;
  } catch {
    return {};
  }
}

async function maybeCloseSessionAfterJobs(pool, sessionKey, closeSessionFn) {
  if (!sessionKey || typeof closeSessionFn !== 'function') return;
  const [sessRows] = await pool.query(
    `SELECT id, status, summary_json FROM edit_portal_session
     WHERE session_key = ? LIMIT 1`,
    [sessionKey],
  );
  if (!sessRows.length || sessRows[0].status !== 'open') return;
  let summary = {};
  try {
    summary = sessRows[0].summary_json ? JSON.parse(sessRows[0].summary_json) : {};
  } catch {
    summary = {};
  }
  if (!summary.close_after_jobs) return;
  const open = await countOpenJobs(pool, { sessionKey });
  if (open > 0) return;
  await closeSessionFn(pool, sessionKey, {
    reason: summary.close_reason || 'drain_after_jobs',
  });
}

async function processJobTx(pool, job, { mystApplyFn = null, closeSessionFn = null } = {}) {
  const t0 = process.hrtime.bigint();

  if (job.kind === 'myst_apply' || job.kind === 'myst_apply_batch') {
    const payload = parsePayload(job);
    if (typeof mystApplyFn !== 'function') {
      await finishJob(pool, job.id, { ok: false, error: 'mystApplyFn non configurato' });
      await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
      return { ok: false, jobId: job.id, error: 'mystApplyFn non configurato' };
    }
    try {
      const conn = await pool.getConnection();
      try {
        await assertSessionOpen(conn, job.session_key, job.toon_id);
      } finally {
        conn.release();
      }

      const steps =
        job.kind === 'myst_apply_batch'
          ? Array.isArray(payload.steps)
            ? payload.steps
            : []
          : [
              {
                path: String(payload.path || ''),
                body: payload.body && typeof payload.body === 'object' ? payload.body : {},
                label: payload.label || payload.path || 'apply',
              },
            ];
      if (!steps.length) {
        await finishJob(pool, job.id, { ok: false, error: 'nessuno step apply nel batch' });
        await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
        return { ok: false, jobId: job.id, error: 'nessuno step apply nel batch' };
      }

      const stepResults = [];
      let allOk = true;
      let failError = null;
      for (let i = 0; i < steps.length; i += 1) {
        const step = steps[i] || {};
        const path = String(step.path || '');
        const body = step.body && typeof step.body === 'object' ? step.body : {};
        if (!path.startsWith('/internal/')) {
          allOk = false;
          failError = `step ${i + 1}: path non valido`;
          stepResults.push({ ok: false, error: failError, label: step.label || path });
          break;
        }
        const myst = await mystApplyFn(path, body, {
          sessionKey: job.session_key,
          toonId: job.toon_id,
        });
        const ok = !!myst && myst.ok !== false;
        stepResults.push({
          ok,
          label: step.label || path,
          path,
          myst,
          error: ok ? null : (myst && (myst.error || myst.message)) || 'apply fallito',
        });
        if (!ok) {
          allOk = false;
          failError = `step ${i + 1}/${steps.length}: ${stepResults[i].error}`;
          break;
        }
      }

      const elapsedMs = Number(process.hrtime.bigint() - t0) / 1e6;
      const logoutAfter = !!payload.logoutAfter;
      /* myst_apply singolo: espone il payload myst reale (exp/rune/created/…).
       * myst_apply_batch: resta il wrapper con steps (UI batch usa solo ok). */
      let mystPayload;
      if (allOk) {
        if (
          job.kind === 'myst_apply' &&
          stepResults[0] &&
          stepResults[0].myst &&
          typeof stepResults[0].myst === 'object'
        ) {
          mystPayload = stepResults[0].myst;
        } else {
          mystPayload = { ok: true, data: { steps: stepResults } };
        }
      } else if (
        stepResults.length &&
        stepResults[stepResults.length - 1].myst &&
        typeof stepResults[stepResults.length - 1].myst === 'object'
      ) {
        mystPayload = stepResults[stepResults.length - 1].myst;
      }
      await finishJob(pool, job.id, {
        ok: allOk,
        result: {
          kind: job.kind,
          steps: stepResults,
          applied: stepResults.filter((s) => s.ok).length,
          total: steps.length,
          logoutAfter,
          elapsedMs: Math.round(elapsedMs * 1000) / 1000,
          myst: mystPayload,
        },
        error: allOk ? null : failError || 'batch fallito',
      });

      if (allOk && logoutAfter && typeof closeSessionFn === 'function') {
        await closeSessionFn(pool, job.session_key, {
          reason: 'apply_and_logout',
          force: true,
        });
      } else {
        await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
      }

      return allOk
        ? {
            ok: true,
            jobId: job.id,
            result: {
              kind: job.kind,
              steps: stepResults,
              logoutAfter,
              elapsedMs,
            },
            logoutAfter,
          }
        : {
            ok: false,
            jobId: job.id,
            error: failError || 'batch fallito',
            steps: stepResults,
          };
    } catch (err) {
      await finishJob(pool, job.id, { ok: false, error: err.message || String(err) });
      await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
      return { ok: false, jobId: job.id, error: err.message || String(err) };
    }
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await assertSessionOpen(conn, job.session_key, job.toon_id);

    let result = { kind: job.kind };
    if (job.kind === 'tx_probe') {
      const [toonRows] = await conn.query(
        `SELECT id, name FROM toon WHERE id = ? LIMIT 1 FOR UPDATE`,
        [job.toon_id],
      );
      if (!toonRows.length) throw new Error('toon non trovato');
      result.toon = { id: toonRows[0].id, name: toonRows[0].name };
    } else if (job.kind === 'read_snapshot') {
      const [inv] = await conn.query(
        `SELECT id, list_index, item_number, short_desc, obj_name, wear_pos, instance_id
         FROM character_inventory WHERE toon_id = ? ORDER BY list_index LIMIT 500`,
        [job.toon_id],
      );
      result.inventoryCount = inv.length;
      result.inventorySample = inv.slice(0, 20);
    } else if (job.kind === 'apply_draft') {
      const [drafts] = await conn.query(
        `SELECT id, base_version, draft_json FROM edit_portal_draft
         WHERE session_key = ? AND toon_id = ? LIMIT 1 FOR UPDATE`,
        [job.session_key, job.toon_id],
      );
      if (!drafts.length) throw new Error('bozza assente');
      const payload = parsePayload(job);
      if (payload.expectBaseVersion && drafts[0].base_version !== payload.expectBaseVersion) {
        throw new Error('versione canonica cambiata: riapri la sessione');
      }
      const [toonRows] = await conn.query(
        `SELECT id FROM toon WHERE id = ? LIMIT 1 FOR UPDATE`,
        [job.toon_id],
      );
      if (!toonRows.length) throw new Error('toon non trovato');
      const newVersion = `v${Date.now()}`;
      await conn.query(
        `UPDATE edit_portal_draft SET base_version = ?, draft_json = ? WHERE id = ?`,
        [
          newVersion,
          typeof payload.draft === 'string'
            ? payload.draft
            : JSON.stringify(payload.draft || JSON.parse(drafts[0].draft_json || '{}')),
          drafts[0].id,
        ],
      );
      result.appliedVersion = newVersion;
      result.note =
        'apply_draft aggiorna la bozza in TX; mutate pezzi canoniche complete restano nel path listino dedicato';
    } else {
      throw new Error(`kind job non supportato: ${job.kind}`);
    }

    const elapsedMs = Number(process.hrtime.bigint() - t0) / 1e6;
    result.elapsedMs = Math.round(elapsedMs * 1000) / 1000;
    await finishJob(conn, job.id, { ok: true, result });
    await conn.commit();
    await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
    return { ok: true, jobId: job.id, result };
  } catch (err) {
    try {
      await finishJob(conn, job.id, { ok: false, error: err.message || String(err) });
      await conn.commit();
    } catch (e2) {
      await conn.rollback();
      throw e2;
    }
    await maybeCloseSessionAfterJobs(pool, job.session_key, closeSessionFn);
    return { ok: false, jobId: job.id, error: err.message || String(err) };
  } finally {
    conn.release();
  }
}

async function runOneJob(pool, opts = {}) {
  const conn = await pool.getConnection();
  let job = null;
  try {
    await conn.beginTransaction();
    job = await claimNextJob(conn);
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
  if (!job) return null;
  return processJobTx(pool, job, opts);
}

function startWorker(pool, { intervalMs = 400, onResult = null, mystApplyFn = null, closeSessionFn = null } = {}) {
  let stopped = false;
  let busy = false;
  const timer = setInterval(async () => {
    if (stopped || busy) return;
    busy = true;
    try {
      const out = await runOneJob(pool, { mystApplyFn, closeSessionFn });
      if (out && typeof onResult === 'function') onResult(out);
    } catch (err) {
      console.warn('[edit-jobs] worker:', err.message || err);
    } finally {
      busy = false;
    }
  }, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  return {
    stop() {
      stopped = true;
      clearInterval(timer);
    },
  };
}

async function upsertDraft(pool, { sessionKey, toonId, baseVersion = null, draft }) {
  const draftJson = typeof draft === 'string' ? draft : JSON.stringify(draft || {});
  await pool.query(
    `INSERT INTO edit_portal_draft (session_key, toon_id, base_version, draft_json)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE base_version = VALUES(base_version), draft_json = VALUES(draft_json)`,
    [sessionKey, toonId, baseVersion, draftJson],
  );
}

module.exports = {
  ensureJobTables,
  enqueueJob,
  getJob,
  countOpenJobs,
  runOneJob,
  startWorker,
  upsertDraft,
};
