#!/bin/bash

# --------------------------------------
# Logging utilities (POSIX sh)
# --------------------------------------

if [ -t 1 ]; then
  _COLOR_INFO="$(printf '\033[1;34m')"    # Blue
  _COLOR_SUCCESS="$(printf '\033[1;32m')" # Green
  _COLOR_ERROR="$(printf '\033[1;31m')"   # Red
  _COLOR_DEBUG="$(printf '\033[1;36m')"    # Cyan
  _COLOR_RESET="$(printf '\033[0m')"
else
  _COLOR_INFO=""
  _COLOR_SUCCESS=""
  _COLOR_ERROR=""
  _COLOR_DEBUG=""
  _COLOR_RESET=""
fi

DEBUG_MODE=1

_timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

_timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

_log() {
  level="$1"
  color="$2"
  shift 2
  printf '%s [%s] %s%s%s\n' \
    "$(_timestamp)" \
    "$level" \
    "$color" \
    "$*" \
    "$_COLOR_RESET"
}

log_info() {
  _log "INFO" "$_COLOR_INFO" "$@"
}

log_success() {
  _log "SUCCESS" "$_COLOR_SUCCESS" "$@"
}

log_error() {
  _log "ERROR" "$_COLOR_ERROR" "$@" >&2
}

log_debug() {
  [ "$DEBUG_MODE" -eq 1 ] || return 0
  _log "DEBUG" "$_COLOR_DEBUG" "$@"
}