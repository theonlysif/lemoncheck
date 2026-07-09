#!/usr/bin/env bash
# lemoncheck — Tier 4: nice-to-haves
# shellcheck shell=bash disable=SC2155

run_tier4() {
  section "TIER 4 — Extras"

  check_listing_diff
  check_value_sanity
}

# --- Listing diff: compare detected config against what the seller claims ----
# Usage: set LEMON_LISTING to a free-text spec (from --listing). We grep numbers.
check_listing_diff() {
  if [[ -z "${LEMON_LISTING:-}" ]]; then
    finding 4 INFO "Listing diff" \
      "no listing provided" \
      "Re-run with --listing \"16GB 512GB M2 Pro\" to auto-diff the ad against the machine."
    return
  fi

  local claimed_ram claimed_ssd
  claimed_ram="$(echo "$LEMON_LISTING" | grep -oiE '[0-9]+ ?GB' | head -1 | grep -oiE '[0-9]+')"
  # crude: a second GB/TB number is likely storage
  claimed_ssd="$(echo "$LEMON_LISTING" | grep -oiE '[0-9]+ ?(TB|GB)' | sed -n '2p')"

  local actual_ram_gb
  actual_ram_gb="$(echo "${LEMON_RAM:-}" | grep -oiE '[0-9]+')"

  local mismatch=""
  if [[ -n "$claimed_ram" && -n "$actual_ram_gb" && "$claimed_ram" != "$actual_ram_gb" ]]; then
    mismatch="RAM: listing says ${claimed_ram}GB, machine reports ${actual_ram_gb}GB. "
  fi

  if [[ -n "$mismatch" ]]; then
    finding 4 RED "Listing diff" "$mismatch" \
      "The advertised specs don't match the hardware. Classic bait-and-switch or a wrong/relisted unit."
  else
    finding 4 GREEN "Listing diff" "no obvious mismatch vs \"$LEMON_LISTING\""
  fi
}

# --- Rough value / resale sanity --------------------------------------------
check_value_sanity() {
  local model="${LEMON_MODEL:-$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2; exit}')}"
  local chip
  chip="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip:|Processor Name/{print $2; exit}')"
  finding 4 INFO "Value sanity" \
    "${model:-Mac} · ${chip:-?} · RAM ${LEMON_RAM:-?}" \
    "Cross-reference this exact model + chip + storage against completed sales on eBay/Swappa. If the asking price is far below market, ask WHY — it usually correlates with a Tier-1 red flag above."
}
