#!/usr/bin/env bash
# Spins up a throw-away PostgreSQL cluster, applies the Supabase stub + all
# migrations, then runs every tests/*_test.sql file. Any failed assertion
# aborts with a non-zero exit code.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT_TEST:-55432}"
cleanup() { "$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

if [ "$(id -u)" = "0" ]; then
  RUN=(su postgres -s /bin/bash -c); chown -R postgres "$WORK"
else
  RUN=(bash -c)
fi
"${RUN[@]}" "$PGBIN/initdb -D $WORK/data -A trust -U postgres >/dev/null"
"${RUN[@]}" "$PGBIN/pg_ctl -D $WORK/data -o '-p $PORT -k $WORK -c listen_addresses=' -l $WORK/log start -w >/dev/null"

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -f "$HERE/00_supabase_stub.sql"
for m in "$HERE"/../migrations/*.sql; do
  echo "Applying $(basename "$m")"
  "${PSQL[@]}" -f "$m"
done
echo "Applying seed.sql (twice, to check idempotency)"
"${PSQL[@]}" -f "$HERE/../seed.sql"
"${PSQL[@]}" -f "$HERE/../seed.sql"
"${PSQL[@]}" -c "truncate public.areas, public.services cascade"
status=0
for t in "$HERE"/*_test.sql; do
  echo "Running $(basename "$t")"
  if ! "${PSQL[@]}" -f "$t"; then status=1; fi
done
[ $status -eq 0 ] && echo "All database tests passed." || echo "Database tests FAILED."
exit $status
