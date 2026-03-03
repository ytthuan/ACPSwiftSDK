#!/usr/bin/env bash
set -euo pipefail

script_file="${BASH_SOURCE[0]:-$0}"
script_dir="$(cd "$(dirname "${script_file}")" && pwd)"
log_dir="${script_dir}/log"
log_file="${log_dir}/telegram-hook.log"
mkdir -p "${log_dir}"

log_trace() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"${log_file}" &
}

log_trace "hook start"

if ! command -v jq >/dev/null 2>&1; then
  log_trace "missing dependency error: jq is required"
  echo "jq is required" >&2
  exit 1
fi

payload="$(cat || true)"
if [ -z "${payload}" ]; then
  payload='{}'
fi

event="${HOOK_EVENT:-unknown}"
chat_id="${TELEGRAM_CHAT_ID:-}"

get_first() {
  local expr="$1"
  jq -r "(${expr}) // empty" <<<"${payload}" | head -n 1
}

trim_text() {
  local text="$1"
  local max_len="$2"
  if [ "${#text}" -gt "${max_len}" ]; then
    printf '%s…' "${text:0:max_len}"
  else
    printf '%s' "${text}"
  fi
}

load_bot_token_from_shell_profiles() {
  local profile line token
  for profile in "${HOME}/.zshrc" "${HOME}/.bash_profile"; do
    [ -r "${profile}" ] || continue
    line="$(grep -E '^[[:space:]]*export[[:space:]]+TELEGRAM_BOT_TOKEN=' "${profile}" | tail -n 1 || true)"
    [ -n "${line}" ] || continue
    token="${line#*=}"
    token="$(printf '%s' "${token}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    token="${token%%[[:space:]]#*}"
    case "${token}" in
    \"*\") token="${token#\"}"; token="${token%\"}" ;;
    \'*\') token="${token#\'}"; token="${token%\'}" ;;
    esac
    if [ -n "${token}" ]; then
      TELEGRAM_BOT_TOKEN="${token}"
      export TELEGRAM_BOT_TOKEN
      return 0
    fi
  done
  return 1
}

agent_name="$(get_first '.agentDisplayName')"
cwd="$(get_first '.cwd')"
# model_name="$(get_first '.agent.model // .subagent.model // .model // .run.model // .metadata.model')"
status="$(get_first '.stopReason')"

error_name="$(get_first '.error.name // .name')"
error_message="$(get_first '.error.message // .message // .error')"

[ -n "${agent_name}" ] || agent_name="MainAgent"
# [ -n "${model_name}" ] || model_name="unknown-model"
[ -n "${status}" ] || status="Session Stopped"
[ -n "${error_name}" ] || error_name="UnknownError"
[ -n "${error_message}" ] || error_message="No error message provided"
log_trace "parsed event=${event} agent=${agent_name} status=${status} raw_data=${payload}"

case "${event}" in
userpromptsubmit)
  prompt_text="$(get_first '.prompt')"
  [ -n "${prompt_text}" ] || prompt_text="(empty prompt)"
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${prompt_text}" >>"${log_dir}/prompts.log" &
  log_trace "prompt ${payload} logged to prompts.log"
  wait
  exit 0
  ;;
subagentstart | subagentstop | stop | error | agentstop | precompact) ;;
*)
  log_trace "unsupported event=${event}"
  exit 0
  ;;
esac

if [ "${event}" = "error" ]; then
  message=$'🚨 Remo - Error - \n'
  message+="event: ${event}"$'\n'
  message+="agent: ${agent_name}"$'\n'
  message+="cwd: ${cwd}"$'\n'
  message+="error: ${error_name}"$'\n'
  message+="message: ${error_message}"
else
  message=$'✅ Remo - Notification - \n'
  message+="event: ${event}"$'\n'
  message+="agent: ${agent_name}"$'\n'
  message+="cwd: ${cwd}"$'\n'
  message+="status: ${status}"
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  log_trace "dry_run path"
  jq -n --arg chat_id "${chat_id}" --arg text "${message}" '{chat_id:$chat_id,text:$text}'
  exit 0
fi

if [ -z "${chat_id}" ]; then
  log_trace "missing env error: TELEGRAM_CHAT_ID is required"
  echo "TELEGRAM_CHAT_ID is required" >&2
  exit 1
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  load_bot_token_from_shell_profiles || true
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  log_trace "missing env error: TELEGRAM_BOT_TOKEN is required"
  echo "TELEGRAM_BOT_TOKEN is required" >&2
  exit 1
fi

if curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${chat_id}" \
  --data-urlencode "text=${message}" \
  --data-urlencode "disable_web_page_preview=true" \
  >/dev/null; then
  log_trace "send success"
else
  log_trace "send failure"
  exit 1
fi
