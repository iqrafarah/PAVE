#!/bin/sh
# Refreshes the local schema from the hosted project after a migration lands there. Needs `supabase login` and
# `supabase link` once. Then: supabase db reset (or stop + start) to load it.
set -e
cd "$(dirname "$0")/../.."
CLI="npx -y supabase@2.58.5"
$CLI db dump --linked --schema public -f supabase/local/public.sql
$CLI db dump --linked --schema storage -f /tmp/pave_storage.sql
{
  sed -n '1,/^-- Storage policies/p' supabase/local/extras.sql
  awk '/^CREATE POLICY .* ON "storage"\."objects"/{p=1} p{print} p&&/;$/{p=0; print ""}' /tmp/pave_storage.sql
} > supabase/local/extras.sql.new
mv supabase/local/extras.sql.new supabase/local/extras.sql
rm -f /tmp/pave_storage.sql
echo "Schema refreshed. Run: $CLI db reset"
