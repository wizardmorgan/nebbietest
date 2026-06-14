-- Remove duplicate user rows that share the same email (keeps lowest id).
-- Run when login crashes with odb::result::one assertion on user email lookup.
--
-- Example:
--   mysql -h 127.0.0.1 -uroot -psecret nebbie < docs/dedupe-user-by-email.sql

DELETE u1 FROM user u1
INNER JOIN user u2 ON u1.email = u2.email AND u1.id > u2.id;
