#!/usr/bin/env bash
# lemoncheck — Tier 1: deal-breakers ("walk away now")
# shellcheck shell=bash disable=SC2155

run_tier1() {
  section "TIER 1 — Deal-breakers"

  check_mdm_enrollment
  check_activation_lock
  check_firmware_lock
  check_serial
  check_persistence
}

# --- MDM / DEP enrollment ---------------------------------------------------
check_mdm_enrollment() {
  if ! is_root; then
    finding 1 MANUAL "MDM / DEP enrollment" \
      "needs sudo — re-run with 'lemoncheck --deep'" \
      "This is the single most important check. Run: sudo profiles show -type enrollment"
    return
  fi

  local enroll status combined
  enroll="$(profiles show -type enrollment 2>/dev/null)"
  status="$(profiles status -type enrollment 2>/dev/null)"
  combined="$enroll"$'\n'"$status"

  if echo "$combined" | grep -qiE "DEP|Device Enrollment|Automated Device Enrollment|Enrolled via DEP"; then
    finding 1 RED "MDM / DEP enrollment" \
      "ENROLLED via DEP / Apple Business Manager" \
      "This Mac is owned by an organization. It will re-enroll into remote management on EVERY wipe and may be remotely locked or erased. WALK AWAY unless the seller can release it from ABM."
  elif echo "$status" | grep -qiE "An enrollment profile is currently installed|MDM enrollment: Yes"; then
    finding 1 AMBER "MDM / DEP enrollment" \
      "MDM profile present (user-approved, non-DEP)" \
      "A management profile is installed but not DEP-locked. Removable via a full erase, but confirm why it's there."
  else
    finding 1 GREEN "MDM / DEP enrollment" "not enrolled / no MDM profile"
  fi
}

# --- Activation Lock / Find My ----------------------------------------------
check_activation_lock() {
  local al=""
  # Apple Silicon surfaces this in SPHardwareDataType on recent macOS.
  if [[ "$HAS_JQ" -eq 1 ]]; then
    al="$(jqr '.SPHardwareDataType[0].activation_lock_status // empty' "$(sp_json SPHardwareDataType)")"
  fi
  if [[ -z "$al" ]]; then
    al="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Activation Lock Status/{print $2; exit}')"
  fi

  case "$al" in
    *[Ee]nabled*)
      finding 1 RED "Activation Lock" \
        "ENABLED — Find My is active" \
        "The seller's Apple ID still owns this Mac. If they don't sign out (System Settings ▸ Apple ID ▸ Sign Out) BEFORE you pay, it becomes an unusable paperweight. Verify it reads Disabled after their sign-out." ;;
    *[Dd]isabled*)
      finding 1 GREEN "Activation Lock" "disabled" ;;
    *)
      finding 1 MANUAL "Activation Lock" \
        "not reported — verify manually" \
        "Confirm in System Settings ▸ General ▸ About (should not show Find My locked), and that Settings ▸ [Name] ▸ Find My ▸ Find My Mac is OFF and the seller is signed out of iCloud." ;;
  esac
}

# --- Firmware password (Intel) / Recovery lock (Apple Silicon) --------------
check_firmware_lock() {
  if [[ "$MAC_ARCH" == "apple_silicon" ]]; then
    if ! is_root; then
      finding 1 MANUAL "Recovery lock (Apple Silicon)" \
        "needs sudo to query securely" \
        "Run 'lemoncheck --deep'. Also confirm you can boot to recoveryOS (hold power at startup) without an unknown password."
      return
    fi
    local out
    if have bputil; then
      out="$(bputil -d 2>/dev/null)"
    fi
    # No public single-line 'recovery lock' flag; fall back to a boot-to-recovery prompt.
    finding 1 MANUAL "Recovery lock (Apple Silicon)" \
      "verify by booting recoveryOS" \
      "Apple Silicon has no firmware password, but a Recovery Lock can block reinstall. Boot to recoveryOS (hold power) and confirm it does NOT demand an unknown password. Security policy: $( [[ -n "$out" ]] && echo "queried" || echo "bputil unavailable" )."
  else
    if ! is_root; then
      finding 1 MANUAL "Firmware password (Intel)" \
        "needs sudo — re-run with --deep" \
        "Run: sudo firmwarepasswd -check"
      return
    fi
    local fw
    fw="$(firmwarepasswd -check 2>/dev/null)"
    if echo "$fw" | grep -qi "Password Enabled: Yes"; then
      finding 1 RED "Firmware password (Intel)" \
        "ENABLED — locks recovery & alt-boot" \
        "A firmware password blocks booting to recovery, USB, or target disk mode. Only the seller (or Apple with proof of purchase) can remove it. Get it cleared before buying."
    else
      finding 1 GREEN "Firmware password (Intel)" "not set"
    fi
  fi
}

# --- Serial number sanity ---------------------------------------------------
check_serial() {
  local serial model
  if [[ "$HAS_JQ" -eq 1 ]]; then
    local hw; hw="$(sp_json SPHardwareDataType)"
    serial="$(jqr '.SPHardwareDataType[0].serial_number // empty' "$hw")"
    model="$(jqr '.SPHardwareDataType[0].machine_name // .SPHardwareDataType[0].machine_model // empty' "$hw")"
  fi
  [[ -n "$serial" ]] || serial="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/{print $2; exit}')"

  if [[ -z "$serial" || "$serial" == "Not Available" ]]; then
    finding 1 AMBER "Serial number" \
      "MISSING / blanked" \
      "A blank or unavailable serial is a red flag for a replaced logic board or tampered device. Investigate before buying."
    return
  fi

  # Basic shape check: modern serials are 10-12 alphanumerics.
  if [[ ${#serial} -lt 8 ]]; then
    finding 1 AMBER "Serial number" \
      "unusual: $serial" \
      "Serial looks malformed. Cross-check against Apple's coverage page."
  else
    finding 1 INFO "Serial number" \
      "$serial ${model:+($model)}" \
      "Cross-check on Apple's coverage page — it must resolve to the SAME model you're looking at. A mismatch or 'not found' can mean a swapped board, grey-market, or stolen unit."
  fi
  LEMON_SERIAL="$serial"
  LEMON_MODEL="$model"
}

# --- Persistence audit (leftover launch items / profiles) -------------------
check_persistence() {
  local dirs=(
    "/Library/LaunchDaemons"
    "/Library/LaunchAgents"
    "$HOME/Library/LaunchAgents"
  )
  local suspicious=0 total=0 details=""
  local d f base
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      base="$(basename "$f")"
      total=$((total+1))
      # Apple's own items live under com.apple.* — flag third-party ones.
      if [[ "$base" != com.apple.* ]]; then
        suspicious=$((suspicious+1))
        details+="${base} "
      fi
    done < <(find "$d" -maxdepth 1 -type f \( -name '*.plist' \) 2>/dev/null)
  done

  if [[ "$suspicious" -gt 0 ]]; then
    finding 1 AMBER "Persistence audit" \
      "$suspicious third-party launch item(s)" \
      "Left-behind launch agents/daemons can be adware, keyloggers, or parental spyware. Review each before trusting the machine (a clean install removes them): ${details}"
  else
    finding 1 GREEN "Persistence audit" "no third-party launch items"
  fi

  # Config profiles
  local prof
  if is_root; then
    prof="$(profiles list 2>/dev/null)"
  else
    prof="$(profiles -P 2>/dev/null || profiles list 2>/dev/null)"
  fi
  if echo "$prof" | grep -qiE "profileIdentifier|_computerlevel|There are.*profiles installed"; then
    if echo "$prof" | grep -qi "There are no configuration profiles"; then
      finding 1 GREEN "Configuration profiles" "none installed"
    else
      local n; n="$(echo "$prof" | grep -ciE "profileIdentifier|attribute: profileIdentifier")"
      finding 1 AMBER "Configuration profiles" \
        "${n:-some} profile(s) installed" \
        "Config profiles can silently redirect DNS, install root certs, or restrict the machine. Review: sudo profiles list -verbose"
    fi
  else
    finding 1 GREEN "Configuration profiles" "none detected"
  fi
}
