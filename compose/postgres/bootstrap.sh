#!/bin/sh
set -eu

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"

max_attempts="${POSTGRES_BOOTSTRAP_ATTEMPTS:-30}"
attempt=1
until pg_isready --host postgres --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" >/dev/null 2>&1; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "PostgreSQL did not become ready after $max_attempts attempts." >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

exec /scripts/init/01-users.sh
