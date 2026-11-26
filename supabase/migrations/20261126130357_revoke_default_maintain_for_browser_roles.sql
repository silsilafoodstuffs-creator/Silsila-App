-- PostgreSQL 17 adds MAINTAIN as a table privilege. Remove it from
-- future public-schema tables for browser roles; it is not an application CRUD capability.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE MAINTAIN ON TABLES FROM anon, authenticated;
