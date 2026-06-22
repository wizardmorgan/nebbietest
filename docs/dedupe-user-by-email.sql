-- Merge duplicate user rows that share the same email.
-- Typical cause: login after dev --boost when myst used Sql::update(..., upsert=true)
-- on account sync (con_pwdok): UPDATE failed → INSERT second row (nickname = PG name).
--
-- Keeps the lowest user.id, copies fields from the highest id, reassigns toon.owner_id, deletes dupes.
--
-- Example:
--   mysql -h 127.0.0.1 -uroot -psecret nebbie < docs/dedupe-user-by-email.sql
--
-- To merge another email, change @email below.

SET @email = 'wizmorgan@gmail.com';
SET @keep_id = (SELECT MIN(id) FROM user WHERE email = @email);
SET @dup_id  = (SELECT MAX(id) FROM user WHERE email = @email);

-- Nothing to do if zero or one row
SELECT IF(@keep_id IS NULL, 'ERRORE: email non trovata',
       IF(@keep_id = @dup_id, 'OK: nessun duplicato',
          CONCAT('Merge: keep id=', @keep_id, ', remove id=', @dup_id))) AS status;

-- 1) Copy nickname/level/password from newest duplicate onto lowest id
UPDATE user u_keep
INNER JOIN user u_dup ON u_dup.id = @dup_id
SET u_keep.nickname      = u_dup.nickname,
    u_keep.level         = u_dup.level,
    u_keep.password      = u_dup.password,
    u_keep.ptr           = u_dup.ptr,
    u_keep.backup_email  = u_dup.backup_email
WHERE u_keep.id = @keep_id
  AND @keep_id < @dup_id;

-- 2) Move PG linked to duplicate account onto kept account
UPDATE toon
SET owner_id = @keep_id
WHERE owner_id = @dup_id
  AND @keep_id < @dup_id;

-- 3) Remove duplicate user row(s) with same email (all ids > keep_id)
DELETE u1 FROM user u1
INNER JOIN user u2 ON u1.email = u2.email AND u1.id > u2.id
WHERE u1.email = @email;

-- Verify (uncomment to run manually):
-- SELECT id, email, nickname, level FROM user WHERE email = @email;
-- SELECT name, owner_id FROM toon WHERE owner_id = @keep_id ORDER BY name;
