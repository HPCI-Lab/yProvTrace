#!/bin/bash

# ============================================================================
# yProvTrace: Logging Utility Functions
# ============================================================================
# Description:
#   Provides colorized logging functions for consistent output formatting
#   across all yProvTrace scripts. Supports multiple log levels with
#   timestamps and POSIX-compatible color codes.
#
# Log Levels:
#   - INFO    : General information (Blue)
#   - SUCCESS : Successful operations (Green)
#   - ERROR   : Error messages to stderr (Red)
#   - DEBUG   : Debug information when DEBUG_MODE=1 (Cyan)
#
# Features:
#   - ISO 8601 timestamps
#   - Color codes disabled for non-TTY output (pipes, files)
#   - DEBUG mode controlled by DEBUG_MODE variable
#
# Functions:
#   - log_info()    : Informational messages
#   - log_success() : Success confirmations
#   - log_error()   : Error messages (sent to stderr)
#   - log_debug()   : Debug output (only if DEBUG_MODE=1)
# ============================================================================

# Initialize color codes (only if output is to terminal)
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

# Enable debug logging (set to 0 to disable)
DEBUG_MODE=1

# ----------------------------------------------------------------------------
# Helper: Generate Timestamp
# ----------------------------------------------------------------------------
# Description: Returns current timestamp in ISO 8601 format
# Format: YYYY-MM-DDTHH:MM:SS+ZZZZ
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Public Logging Functions
# ----------------------------------------------------------------------------

# Log informational message (blue)
log_info() {
  _log "INFO" "$_COLOR_INFO" "$@"
}

# Log success message (green)
log_success() {
  _log "SUCCESS" "$_COLOR_SUCCESS" "$@"
}

# Log error message to stderr (red)
log_error() {
  _log "ERROR" "$_COLOR_ERROR" "$@" >&2
}

# Log debug message if DEBUG_MODE is enabled (cyan)
log_debug() {
  [ "$DEBUG_MODE" -eq 1 ] || return 0
  _log "DEBUG" "$_COLOR_DEBUG" "$@"
}