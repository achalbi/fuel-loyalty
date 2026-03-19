#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/app"

cd "$APP_ROOT"

if [ -f tmp/pids/server.pid ]; then
  rm -f tmp/pids/server.pid
fi

wait_for_postgres() {
  local max_attempts=30
  local attempt=1

  if [ -z "${DATABASE_URL:-}" ]; then
    return 0
  fi

  echo "Waiting for PostgreSQL to accept connections..."
  until pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; do
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "PostgreSQL did not become ready in time." >&2
      return 1
    fi

    attempt=$((attempt + 1))
    sleep 1
  done
}

if [ -f Gemfile ]; then
  bundle check >/dev/null 2>&1 || bundle install
fi

if [ "${1:-}" = "bin/rails" ] && [ "${2:-}" = "server" ]; then
  wait_for_postgres
  bundle exec rails db:prepare
fi

exec "$@"
