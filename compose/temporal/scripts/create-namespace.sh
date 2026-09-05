#!/bin/sh
# Git keeps this script in LF format because it runs inside Linux containers.
set -eu

: "${TEMPORAL_ADDRESS:?TEMPORAL_ADDRESS is required}"
: "${TEMPORAL_NAMESPACE:?TEMPORAL_NAMESPACE is required}"

max_attempts="${TEMPORAL_START_ATTEMPTS:-30}"
attempt=1
until temporal operator cluster health --address "$TEMPORAL_ADDRESS"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Temporal did not become ready after $max_attempts attempts: $TEMPORAL_ADDRESS" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done
temporal operator namespace describe --address "$TEMPORAL_ADDRESS" --namespace "$TEMPORAL_NAMESPACE" \
  >/dev/null 2>&1 || temporal operator namespace create --address "$TEMPORAL_ADDRESS" \
  --namespace "$TEMPORAL_NAMESPACE" --retention 24h
