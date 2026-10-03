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

attempt=1
until search_attributes="$(temporal operator search-attribute list --address "$TEMPORAL_ADDRESS" \
  --namespace "$TEMPORAL_NAMESPACE" 2>/dev/null)"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Temporal search attributes did not become ready after $max_attempts attempts" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 1
done

for attribute in ActionKind ActionConnector ActionTenantId ActionActorId ActionStatus; do
  if printf '%s\n' "$search_attributes" \
    | grep -Eq "^[[:space:]]*$attribute[[:space:]]+Keyword([[:space:]]|$)"; then
    continue
  fi
  if printf '%s\n' "$search_attributes" \
    | grep -Eq "^[[:space:]]*$attribute[[:space:]]+"; then
    echo "Temporal search attribute $attribute exists with a non-Keyword type" >&2
    exit 1
  fi
  temporal operator search-attribute create --address "$TEMPORAL_ADDRESS" \
    --namespace "$TEMPORAL_NAMESPACE" --name "$attribute" --type Keyword
done
