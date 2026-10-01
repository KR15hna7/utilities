#!/bin/bash
set -e

if [ -z "${AZP_URL}" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

if [ -z "${AZP_TOKEN_FILE}" ] || [ ! -s "${AZP_TOKEN_FILE}" ]; then
  echo 1>&2 "error: AZP_TOKEN_FILE must point to a non-empty file"
  exit 1
fi

# Pod hostname is the StatefulSet pod name (<release>-<ordinal>), so the name is unique and stable.
AZP_AGENT_NAME="${AZP_AGENT_NAME:-${AZP_AGENT_PREFIX:+${AZP_AGENT_PREFIX}-}${HOSTNAME}}"
AZP_POOL="${AZP_POOL:-Default}"
AZP_WORK="${AZP_WORK:-/azp/_work}"

# Keep the token out of the environment that pipeline jobs inherit.
export VSO_AGENT_IGNORE="AZP_TOKEN_FILE"

cd /azp/agent
run_pid=""

cleanup() {
  [ -e ./config.sh ] || return 0
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    ./config.sh remove --unattended --auth PAT --token "$(cat "${AZP_TOKEN_FILE}")" && return 0
    echo "Agent removal attempt ${attempt} failed, retrying in 30s"
    sleep 30
  done
  echo 1>&2 "warning: failed to remove agent registration"
}

shutdown() {
  trap - EXIT TERM INT
  if [ -n "${run_pid}" ]; then
    kill -TERM "${run_pid}" 2>/dev/null || true
    wait "${run_pid}" 2>/dev/null || true
  fi
  cleanup
}

trap shutdown EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

echo "Configuring agent '${AZP_AGENT_NAME}' in pool '${AZP_POOL}'"

./config.sh --unattended \
  --agent "${AZP_AGENT_NAME}" \
  --url "${AZP_URL}" \
  --auth PAT \
  --token "$(cat "${AZP_TOKEN_FILE}")" \
  --pool "${AZP_POOL}" \
  --work "${AZP_WORK}" \
  --replace \
  --acceptTeeEula

./run.sh "$@" &
run_pid=$!
wait "${run_pid}"
