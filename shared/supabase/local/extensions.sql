-- Local stack only: extensions the public schema needs, loaded before public.sql.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
