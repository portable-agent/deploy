#!/bin/sh
# Git keeps this script in LF format because it runs inside Linux containers.
set -eu

: "${KEYCLOAK_DB_USER:?KEYCLOAK_DB_USER is required}"
: "${KEYCLOAK_DB_PASSWORD:?KEYCLOAK_DB_PASSWORD is required}"
: "${TEMPORAL_DB_USER:?TEMPORAL_DB_USER is required}"
: "${TEMPORAL_DB_PASSWORD:?TEMPORAL_DB_PASSWORD is required}"
: "${ACTION_DB_USER:?ACTION_DB_USER is required}"
: "${ACTION_DB_PASSWORD:?ACTION_DB_PASSWORD is required}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=keycloak_user="$KEYCLOAK_DB_USER" \
  --set=keycloak_password="$KEYCLOAK_DB_PASSWORD" \
  --set=temporal_user="$TEMPORAL_DB_USER" \
  --set=temporal_password="$TEMPORAL_DB_PASSWORD" \
  --set=action_user="$ACTION_DB_USER" \
  --set=action_password="$ACTION_DB_PASSWORD" <<-'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'keycloak_user', :'keycloak_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'keycloak_user') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'keycloak_user', :'keycloak_password') \gexec

SELECT format('CREATE DATABASE keycloak OWNER %I', :'keycloak_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak') \gexec

SELECT format('CREATE ROLE %I LOGIN CREATEDB PASSWORD %L', :'temporal_user', :'temporal_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'temporal_user') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN CREATEDB PASSWORD %L', :'temporal_user', :'temporal_password') \gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'action_user', :'action_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'action_user') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'action_user', :'action_password') \gexec

SELECT format('CREATE DATABASE actions OWNER %I', :'action_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'actions') \gexec
SQL
