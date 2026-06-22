-- Merge duplicate user rows that share the same email.
-- Typical cause: login after dev --boost when myst used Sql::update(..., upsert=true)
-- on account sync (con_pwdok): UPDATE failed → INSERT second row (nickname = PG name).
--
-- This script:
--   1) copies nickname/level/password from the newest duplicate onto the lowest id
--   2) moves toon.owner_id to the kept account
--   3) deletes extra user rows
--
-- Example:
--   mysql -h 127.0.0.1 -uroot -psecret nebbie < docs/dedupe-user-by-email.sql
--
-- For a single email, run the block below manually (safer than blind delete).

-- === wizmorgan@gmail.com: keep id=4, merge data from id=165 ===
UPDATE user u_keep
INNER JOIN (
	SELECT email, MAX(id) AS dup_id
	FROM user
	WHERE email = 'wizmorgan@gmail.com'
	GROUP BY email
	HAVING COUNT(*) > 1
) d ON d.email = u_keep.email
INNER JOIN user u_dup ON u_dup.id = d.dup_id
SET u_keep.nickname = u_dup.nickname,
    u_keep.level = u_dup.level,
    u_keep.password = u_dup.password,
    u_keep.ptr = u_dup.ptr,
    u_keep.backup_email = u_dup.backup_email
WHERE u_keep.id = (
	SELECT MIN(id) FROM user u2 WHERE u2.email = u_keep.email
);

UPDATE toon t
INNER JOIN user u_dup ON u_dup.email = 'wizmorgan@gmail.com'
INNER JOIN (
	SELECT MAX(id) AS dup_id FROM user WHERE email = 'wizmorgan@gmail.com'
) x ON u_dup.id = x.dup_id
SET t.owner_id = (SELECT MIN(id) FROM user WHERE email = 'wizmorgan@gmail.com')
WHERE t.owner_id = u_dup.id;

DELETE u1 FROM user u1
INNER JOIN user u2 ON u1.email = u2.email AND u1.id > u2.id
WHERE u1.email = 'wizmorgan@gmail.com';

-- Verify:
-- SELECT id, email, nickname, level FROM user WHERE email = 'wizmorgan@gmail.com';
-- SELECT name, owner_id FROM toon WHERE owner_id IN (SELECT id FROM user WHERE email = 'wizmorgan@gmail.com');
