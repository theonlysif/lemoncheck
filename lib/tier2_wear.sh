#!/usr/bin/env bash
# lemoncheck — Tier 2: wear & true condition
# shellcheck shell=bash disable=SC2155

run_tier2() {
  section "TIER 2 — Wear & true condition"

  check_battery
  check_ssd_smart
  check_kernel_panics
  check_thermal
  check_os_installs
}

# --- Battery: wear % + cycles (more honest than the Normal/Service label) ---
check_battery() {
  local raw design maxcap cycles condition
  raw="$(system_profiler SPPowerDataType 2>/dev/null)"
  if [[ -z "$raw" ]] || ! echo "$raw" | grep -qi "Cycle Count"; then
    finding 2 INFO "Battery" "no battery (desktop Mac?)"
    return
  fi

  cycles="$(echo "$raw" | awk -F': ' '/Cycle Count/{print $2; exit}')"
  condition="$(echo "$raw" | awk -F': ' '/Condition/{print $2; exit}')"

  # Prefer ioreg for exact mAh capacities.
  local ir
  ir="$(ioreg -r -c AppleSmartBattery 2>/dev/null)"
  maxcap="$(echo "$ir"  | awk -F'= ' '/\"AppleRawMaxCapacity\"/{print $2; exit}')"
  design="$(echo "$ir"  | awk -F'= ' '/\"DesignCapacity\"/{print $2; exit}')"

  local wear=""
  if [[ -n "$maxcap" && -n "$design" && "$design" -gt 0 ]] 2>/dev/null; then
    wear="$(awk -v m="$maxcap" -v d="$design" 'BEGIN{printf "%.0f", (m/d)*100}')"
  fi

  local status detail advice
  detail="cycles: ${cycles:-?}"
  [[ -n "$wear" ]] && detail="health: ${wear}%  ·  ${detail}"
  [[ -n "$condition" ]] && detail="$detail  ·  ${condition}"

  if [[ "$condition" == *Service* || "$condition" == *Replace* ]]; then
    status=RED
    advice="macOS itself flags this battery for service. Factor a battery replacement into the price."
  elif [[ -n "$wear" && "$wear" -lt 80 ]] 2>/dev/null; then
    status=AMBER
    advice="Battery health under 80% — noticeably degraded. Expect reduced runtime; budget for replacement."
  elif [[ -n "$cycles" && "$cycles" -gt 1000 ]] 2>/dev/null; then
    status=AMBER
    advice="High cycle count. Battery is deep into its rated life."
  else
    status=GREEN
    advice=""
  fi
  finding 2 "$status" "Battery" "$detail" "$advice"
}

# --- SSD terabytes-written (the sleeper metric) -----------------------------
check_ssd_smart() {
  local sm
  sm="$(command -v smartctl || echo "")"
  if [[ -z "$sm" ]]; then
    finding 2 MANUAL "SSD wear (TBW)" \
      "smartmontools not installed" \
      "Install with 'brew install smartmontools', then re-run. TBW (terabytes written) reveals how hammered the SSD is — a drive with 200TB written is near end-of-life even if it 'works.'"
    return
  fi

  # Internal NVMe on Apple Silicon lives behind the AppleANS controller; smartctl
  # can read it on many machines but not all. Try the common device nodes.
  local dev out=""
  for dev in /dev/disk0 /dev/rdisk0; do
    # Guard with a timeout — smartctl can hang on some Apple NVMe controllers.
    out="$(run_to 12 "$sm" -a "$dev")"
    [[ -n "$out" ]] && echo "$out" | grep -qiE "Data Units Written|Percentage Used|Power_On_Hours" && break
  done

  if [[ -z "$out" ]] || ! echo "$out" | grep -qiE "Data Units Written|Percentage Used|Power On Hours"; then
    if ! is_root; then
      finding 2 MANUAL "SSD wear (TBW)" \
        "needs sudo — re-run with --deep" \
        "Run: sudo smartctl -a /dev/disk0"
    else
      finding 2 MANUAL "SSD wear (TBW)" \
        "SMART not exposed on this controller" \
        "Some Apple SSDs don't expose SMART to smartctl. Watch for slow performance and check kernel panics as a proxy."
    fi
    return
  fi

  local units_written pct_used poh tbw
  # NVMe: "Data Units Written" is in units of 1000 * 512 bytes = 512,000 bytes.
  units_written="$(echo "$out" | awk -F: '/Data Units Written/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
  pct_used="$(echo "$out" | awk -F: '/Percentage Used/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
  poh="$(echo "$out" | awk -F: '/Power On Hours|Power_On_Hours/{gsub(/[^0-9]/,"",$2); print $2; exit}')"

  local detail="" status=GREEN advice=""
  if [[ -n "$units_written" && "$units_written" -gt 0 ]] 2>/dev/null; then
    tbw="$(awk -v u="$units_written" 'BEGIN{printf "%.1f", (u*512000)/1e12}')"
    detail="written: ${tbw} TB"
  fi
  [[ -n "$pct_used" ]] && detail="${detail:+$detail  ·  }life used: ${pct_used}%"
  [[ -n "$poh" ]] && detail="${detail:+$detail  ·  }powered: ${poh}h"

  if [[ -n "$pct_used" && "$pct_used" -ge 80 ]] 2>/dev/null; then
    status=RED; advice="SSD reports ${pct_used}% of rated write life consumed — near end of life. This drive is not user-replaceable on modern Macs."
  elif [[ -n "$pct_used" && "$pct_used" -ge 40 ]] 2>/dev/null; then
    status=AMBER; advice="SSD is meaningfully worn (${pct_used}% life used). Fine for now but factor it in."
  elif [[ -n "$tbw" ]] && awk -v t="$tbw" 'BEGIN{exit !(t>150)}'; then
    status=AMBER; advice="High total bytes written (${tbw} TB). Heavy prior use."
  fi
  [[ -z "$detail" ]] && detail="SMART read but no wear counters"
  finding 2 "$status" "SSD wear (TBW)" "$detail" "$advice"
}

# --- Kernel panic history ---------------------------------------------------
check_kernel_panics() {
  local dir="/Library/Logs/DiagnosticReports"
  local count recent
  count=0; recent=0
  if [[ -d "$dir" ]]; then
    count="$(find "$dir" -maxdepth 1 -name '*.panic' 2>/dev/null | wc -l | tr -d ' ')"
    recent="$(find "$dir" -maxdepth 1 -name '*.panic' -mtime -30 2>/dev/null | wc -l | tr -d ' ')"
  fi

  if [[ "$count" -eq 0 ]]; then
    finding 2 GREEN "Kernel panics" "none on record"
  elif [[ "$recent" -gt 0 ]]; then
    finding 2 RED "Kernel panics" \
      "$count total, $recent in last 30 days" \
      "Recent kernel panics point at failing hardware (RAM, SSD, GPU, logic board) that a reinstall won't fix. Inspect the .panic files in $dir."
  else
    finding 2 AMBER "Kernel panics" \
      "$count total (none recent)" \
      "Older panics — could be resolved or dormant hardware trouble. Worth asking the seller about."
  fi
}

# --- Thermal state ----------------------------------------------------------
# NOTE: use only the one-shot `pmset -g therm`. `pmset -g thermlog` STREAMS
# thermal events forever and never returns — it must never be called here.
check_thermal() {
  local therm
  therm="$(pmset -g therm 2>/dev/null)"

  # CPU scheduler / speed limit < 100 means the CPU is being throttled now.
  local level
  level="$(echo "$therm" | awk -F= '/CPU_Scheduler_Limit|CPU_Speed_Limit/{gsub(/[^0-9]/,"",$2); print $2; exit}')"

  if echo "$therm" | grep -qiE "thermal warning level.*[1-9]|CPU power.*[1-9]"; then
    finding 2 AMBER "Thermal state" \
      "warning level recorded" \
      "The system has logged a thermal warning — possible dried paste, blocked fans, or prior liquid damage. Stress-test and listen to the fans."
  elif [[ -n "$level" && "$level" -lt 100 ]] 2>/dev/null; then
    finding 2 AMBER "Thermal state" \
      "CPU currently limited to ${level}%" \
      "The CPU is being thermally limited right now. Let it cool and re-check; if persistent, cooling is compromised."
  else
    finding 2 GREEN "Thermal state" "no active throttling"
  fi
}

# --- OS install / restore count & dates -------------------------------------
check_os_installs() {
  # Root filesystem creation time is the most reliable proxy for the last clean
  # install/erase. (InstallHistory counts every delta update too, so it wildly
  # overstates "installs" — we report it only as informational context.)
  local created
  created="$(stat -f '%SB' -t '%Y-%m-%d' / 2>/dev/null)"

  local detail="root fs created: ${created:-unknown}"

  # Flag a *very recently* wiped machine — a fresh erase right before sale can be
  # legitimate, but it also conveniently hides history. Worth a gentle note.
  local created_epoch now_epoch age_days
  created_epoch="$(stat -f '%B' / 2>/dev/null)"
  now_epoch="$(date +%s 2>/dev/null)"
  if [[ -n "$created_epoch" && -n "$now_epoch" ]]; then
    age_days=$(( (now_epoch - created_epoch) / 86400 ))
    detail="$detail  (~${age_days}d ago)"
    if [[ "$age_days" -lt 7 ]]; then
      finding 2 AMBER "OS install history" "$detail" \
        "The system volume was created in the last week — a fresh wipe right before sale. Usually fine, but it erases the machine's history (panics, logs), so lean harder on the hardware checks."
      return
    fi
  fi
  finding 2 INFO "OS install history" "$detail"
}
