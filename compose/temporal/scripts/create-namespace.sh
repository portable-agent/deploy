#!/bin/sh
# Git keeps this script in LF format because it runs inside Linux containers.
set -eu

: "${TEMPORAL_ADDRESS:?TEMPORAL_ADDRESS is required}"
: "${TEMPORAL_NAMESPACE:?TEMPORAL_NAMESPACE is required}"

until temporal operator cluster health --address "$TEMPORAL_ADDRESS"; do sleep 2; done
temporal operator namespace describe --address "$TEMPORAL_ADDRESS" --namespace "$TEMPORAL_NAMESPACE" \
  >/dev/null 2>&1 || temporal operator namespace create --address "$TEMPORAL_ADDRESS" \
  --namespace "$TEMPORAL_NAMESPACE" --retention 24h
