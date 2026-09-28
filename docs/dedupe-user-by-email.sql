-- Merge duplicate user rows that share the same email.
--
-- Keeps the lowest user.id, copies fields from the highest id,
-- reassigns toon.owner_id, deletes duplicate user rows.
--
-- Usage:
--   mysql -h 127.0.0.1 -uroot -psecret nebbie < docs/dedupe-user-by-email.sql
--
-- If you get: Table 'nebbie_mas.user' doesn't exist
--   a trigger on nebbie.user syncs to nebbie_mas (missing on dev VM).
--   See bottom of this file or docs/dedupe-user-troubleshoot.md

USE `nebbie`;

SET @email = 'wizmorgan@gmail.com';
SET @keep_id = (SELECT MIN(id) FROM `user` WHERE email = @email);
SET @dup_id  = (SELECT MAX(id) FROM `user` WHERE email = @email);

SELECT IF(@keep_id IS NULL, 'ERRORE: email non trovata',
       IF(@keep_id = @dup_id, 'OK: nessun duplicato',
          CONCAT('Merge: keep id=', @keep_id, ', remove id=', @dup_id))) AS status;

-- 1) Copy fields from newest duplicate onto lowest id
UPDATE `user` AS u_keep
INNER JOIN `user` AS u_dup ON u_dup.id = @dup_id
SET u_keep.nickname     = u_dup.nickname,
    u_keep.level        = u_dup.level,
    u_keep.password     = u_dup.password,
    u_keep.ptr          = u_dup.ptr,
    u_keep.backup_email = u_dup.backup_email
WHERE u_keep.id = @keep_id
  AND @keep_id < @dup_id;

-- 2) Move PG linked to duplicate account
UPDATE `toon`
SET owner_id = @keep_id
WHERE owner_id = @dup_id
  AND @keep_id < @dup_id;

-- 3) Delete duplicate user rows (same email, higher id)
DELETE u1 FROM `user` AS u1
INNER JOIN `user` AS u2 ON u1.email = u2.email AND u1.id > u2.id
WHERE u1.email = @email;

-- Verify:
SELECT id, email, nickname, level FROM `user` WHERE email = @email;
SELECT name, owner_id FROM `toon` WHERE owner_id = @keep_id ORDER BY name;

-- =============================================================================
-- TRIGGER nebbie_mas (dev VM)
-- =============================================================================
-- List triggers on user:
--   mysql ... -e "SHOW TRIGGERS FROM nebbie WHERE \`Table\` = 'user'\G"
--
-- Typical dev fix (replace TRIGGER_NAME):
--   DROP TRIGGER IF EXISTS nebbie.TRIGGER_NAME;
--   -- re-run this script
--
-- Or create stub DB (only if you cannot drop the trigger):
--   CREATE DATABASE IF NOT EXISTS nebbie_mas;
--   CREATE TABLE IF NOT EXISTS nebbie_mas.`user` LIKE nebbie.`user`;
