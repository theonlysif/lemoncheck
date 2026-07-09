#!/usr/bin/env bash
# lemoncheck — shared utilities, colors, and finding registry
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Colors / formatting
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_GREY=$'\033[90m'
  C_REDBG=$'\033[41m'; C_YELBG=$'\033[43m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_CYAN=""; C_GREY=""; C_REDBG=""; C_YELBG=""
fi

# ---------------------------------------------------------------------------
# Finding registry
#
# Every check appends one record to these parallel arrays. The report layer
# renders them as a traffic-light summary and (optionally) an HTML report.
#
# Status values: RED (deal-breaker) | AMBER (wear/watch) | GREEN (ok)
#                INFO (neutral fact) | MANUAL (needs human action)
# ---------------------------------------------------------------------------
FND_TIER=();  FND_STATUS=(); FND_TITLE=(); FND_DETAIL=(); FND_ADVICE=()

# add_finding <tier> <status> <title> <detail> [advice]
add_finding() {
  FND_TIER+=("$1"); FND_STATUS+=("$2"); FND_TITLE+=("$3")
  FND_DETAIL+=("$4"); FND_ADVICE+=("${5:-}")
}

# Live line printed as each check runs (so a slow run still feels responsive).
print_line() {
  local status="$1" title="$2" detail="$3"
  local icon color
  case "$status" in
    RED)    icon="✖"; color="$C_RED" ;;
    AMBER)  icon="▲"; color="$C_YELLOW" ;;
    GREEN)  icon="✔"; color="$C_GREEN" ;;
    MANUAL) icon="☐"; color="$C_CYAN" ;;
    *)      icon="•"; color="$C_GREY" ;;
  esac
  printf "  %s%s%s %s%-34s%s %s\n" \
    "$color" "$icon" "$C_RESET" "$C_BOLD" "$title" "$C_RESET" "${C_DIM}${detail}${C_RESET}"
}

# report + register in one shot
finding() {
  local tier="$1" status="$2" title="$3" detail="$4" advice="${5:-}"
  add_finding "$tier" "$status" "$title" "$detail" "$advice"
  print_line "$status" "$title" "$detail"
}

section() {
  printf "\n%s%s%s\n" "$C_BOLD$C_BLUE" "$1" "$C_RESET"
  printf "%s%s%s\n" "$C_GREY" "$(printf '─%.0s' $(seq 1 60))" "$C_RESET"
}

banner() {
  printf "%s\n" "$C_BOLD$C_YELLOW"
  cat <<'EOF'
   _                                _               _
  | | ___ _ __ ___   ___  _ __   ___| |__   ___  ___| | __
  | |/ _ \ '_ ` _ \ / _ \| '_ \ / __| '_ \ / _ \/ __| |/ /
  | |  __/ | | | | | (_) | | | | (__| | | |  __/ (__|   <
  |_|\___|_| |_| |_|\___/|_| |_|\___|_| |_|\___|\___|_|\_\
EOF
  printf "%s" "$C_RESET"
  printf "  %sused-mac lemon detector%s  ·  %sv%s%s\n\n" \
    "$C_DIM" "$C_RESET" "$C_GREY" "${LEMONCHECK_VERSION:-0.1.0}" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# Portable timeout: run_to <seconds> <cmd...>. macOS has no coreutils `timeout`,
# so we background the command and kill it if it overruns. Returns the command's
# stdout; exit 124 on timeout.
run_to() {
  local secs="$1"; shift
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/lc-to.XXXXXX")"
  ( "$@" >"$tmp" 2>/dev/null ) &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$waited" -ge "$secs" ]]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      cat "$tmp"; rm -f "$tmp"; return 124
    fi
    sleep 1; waited=$((waited+1))
  done
  wait "$pid" 2>/dev/null
  cat "$tmp"; rm -f "$tmp"
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Detect Apple Silicon vs Intel once.
detect_arch() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    MAC_ARCH="apple_silicon"
  else
    MAC_ARCH="intel"
  fi
}

# Cache a system_profiler datatype as JSON once, reuse across checks.
SP_CACHE_DIR=""
sp_json() {
  local datatype="$1"
  [[ -n "$SP_CACHE_DIR" ]] || SP_CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lemoncheck.XXXXXX")"
  local f="$SP_CACHE_DIR/$datatype.json"
  if [[ ! -f "$f" ]]; then
    system_profiler -json "$datatype" >"$f" 2>/dev/null || echo '{}' >"$f"
  fi
  cat "$f"
}

cleanup_tmp() { [[ -n "$SP_CACHE_DIR" && -d "$SP_CACHE_DIR" ]] && rm -rf "$SP_CACHE_DIR"; }

# jq wrapper that degrades gracefully if jq is missing.
HAS_JQ=0
jqr() { # jqr <filter> <json>
  if [[ "$HAS_JQ" -eq 1 ]]; then
    printf '%s' "$2" | jq -r "$1" 2>/dev/null
  fi
}

# Round a float to an int (portable).
round_int() { printf '%.0f' "$1" 2>/dev/null || echo 0; }
