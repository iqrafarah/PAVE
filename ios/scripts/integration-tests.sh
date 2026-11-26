#!/bin/sh
# Runs PAVEIntegrationTests against a local Supabase with the production schema (shared/supabase/local), with a fake
# OpenRouter (fake-openrouter.mjs) behind Ayla: no key, no cost, the same answer every time.
#   ios/scripts/integration-tests.sh           run the tests (starts local Supabase if needed)
#   ios/scripts/integration-tests.sh --reset   start from an empty database first
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLI="npx -y supabase@2.58.5"
FAKE_PORT=55399
ENV_FILE="$ROOT/shared/supabase/functions/.env"

docker info >/dev/null 2>&1 || { echo "Start Docker first."; exit 1; }

# The local edge functions talk to the fake OpenRouter. Docker reaches this Mac as host.docker.internal.
RESTART=0
if ! grep -q "host.docker.internal:$FAKE_PORT" "$ENV_FILE" 2>/dev/null; then
  printf '%s\n' \
    "# Local only (git-ignored): Ayla talks to the fake OpenRouter of ios/scripts/integration-tests.sh." \
    "OPENROUTER_API_KEY=fake-key" \
    "OPENROUTER_BASE_URL=http://host.docker.internal:$FAKE_PORT/api/v1" > "$ENV_FILE"
  RESTART=1
fi

node "$ROOT/ios/scripts/fake-openrouter.mjs" &
FAKE_PID=$!
trap 'kill $FAKE_PID 2>/dev/null' EXIT INT TERM

cd "$ROOT/shared"
for arg in "$@"; do
  [ "$arg" = "--reset" ] && RESTART=1 && $CLI stop --no-backup >/dev/null 2>&1 || true
done
if [ "$RESTART" = 1 ]; then $CLI stop >/dev/null 2>&1 || true; fi
$CLI status >/dev/null 2>&1 || $CLI start

cd "$ROOT/ios/PAVECore"
PAVE_INTEGRATION=1 FAKE_OPENROUTER_URL="http://127.0.0.1:$FAKE_PORT" swift test --filter PAVEIntegrationTests
