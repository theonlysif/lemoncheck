#!/usr/bin/env bash
# lemoncheck — Tier 3: does every component actually work
# Auto-detect what hardware reports as present, then hand off a guided
# manual checklist for things Terminal can detect-but-not-exercise.
# shellcheck shell=bash disable=SC2155

run_tier3() {
  section "TIER 3 — Component presence (auto)"

  check_memory
  check_ports
  check_wireless
  check_gpu
  check_camera
  check_displays
  check_audio
}

check_memory() {
  local raw total
  raw="$(system_profiler SPMemoryDataType 2>/dev/null)"
  total="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Memory:/{print $2; exit}')"
  finding 3 INFO "Memory (RAM)" "${total:-unknown} reported present" \
    "Compare against the listing. On Apple Silicon RAM is fused to the SoC (can't be swapped), so 'reports 8GB' must equal what you paid for."
  LEMON_RAM="$total"
}

check_ports() {
  local usb tb
  usb="$(system_profiler SPUSBDataType 2>/dev/null | grep -c "Product ID\|BSD Name\|Manufacturer")"
  tb="$(system_profiler SPThunderboltDataType 2>/dev/null | grep -c "Device Name\|Vendor Name")"
  local busses
  busses="$(system_profiler SPThunderboltDataType 2>/dev/null | grep -c "Thunderbolt.*Bus\|Bus:")"
  finding 3 INFO "USB / Thunderbolt busses" \
    "${busses:-?} TB bus(es) enumerated" \
    "Presence ≠ function. Manually test EACH port with a real drive (see guided checklist) — a dead port often means logic-board damage."
}

check_wireless() {
  local air bt_raw wifi_card bt_chip
  air="$(system_profiler SPAirPortDataType 2>/dev/null)"
  bt_raw="$(system_profiler SPBluetoothDataType 2>/dev/null)"

  # Card Type line only exists when a Wi-Fi interface is actually present.
  wifi_card="$(echo "$air" | awk -F': ' '/Card Type/{print $2; exit}')"
  if [[ -n "$wifi_card" ]] || echo "$air" | grep -qiE "Interfaces:|en[0-9]+:"; then
    finding 3 GREEN "Wi-Fi" "chip detected${wifi_card:+ (${wifi_card%% *})}"
  else
    finding 3 AMBER "Wi-Fi" "no Wi-Fi interface reported" \
      "Could not read a Wi-Fi card. This can mean logic-board/antenna damage — confirm by actually joining a network before buying."
  fi

  bt_chip="$(echo "$bt_raw" | awk -F': ' '/Chipset/{print $2; exit}')"
  if [[ -n "$bt_chip" ]] || echo "$bt_raw" | grep -qiE "Bluetooth Controller|Address:"; then
    finding 3 GREEN "Bluetooth" "chip detected${bt_chip:+ ($bt_chip)}"
  else
    finding 3 AMBER "Bluetooth" "not detected" \
      "No Bluetooth radio found. Test by pairing a device."
  fi
}

check_gpu() {
  local gpus
  gpus="$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/{print $2}' | paste -sd', ' -)"
  if [[ -n "$gpus" ]]; then
    finding 3 GREEN "GPU(s)" "$gpus"
  else
    finding 3 AMBER "GPU(s)" "none reported" "Could not read GPU. Check for graphical glitches on screen."
  fi
}

check_camera() {
  # SPCameraDataType is empty on many recent macOS builds, so fall back to ioreg.
  if system_profiler SPCameraDataType 2>/dev/null | grep -qiE "Camera|FaceTime" \
     || ioreg -l 2>/dev/null | grep -qiE "AppleH1[0-9]CamIn|AppleCamIn|FaceTime|VDC-.*Camera"; then
    finding 3 GREEN "Camera" "device present" \
      "Presence only — open Photo Booth to confirm it produces a live image."
  else
    # Absence here is usually a reporting gap, not a missing camera — don't alarm.
    finding 3 MANUAL "Camera" "not reported — verify manually" \
      "macOS didn't expose the camera to system_profiler (common). Open Photo Booth to confirm it produces a live image."
  fi
}

check_displays() {
  local disp count
  disp="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -cE "Resolution|Display Type")"
  count="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -cE "^ +[A-Za-z].*:$" )"
  finding 3 INFO "Displays" "$( [[ "$disp" -gt 0 ]] && echo "$disp display attribute(s) reported" || echo "check manually" )" \
    "Run the guided dead-pixel sweep to check the panel for dead/stuck pixels and backlight bleed."
}

check_audio() {
  local out in
  out="$(system_profiler SPAudioDataType 2>/dev/null | grep -c "Output\|Speaker")"
  in="$(system_profiler SPAudioDataType 2>/dev/null | grep -c "Input\|Microphone")"
  if [[ "$out" -gt 0 || "$in" -gt 0 ]]; then
    finding 3 GREEN "Audio devices" "output & input present" \
      "Presence only — use the guided speaker L/R and mic record-playback tests."
  else
    finding 3 AMBER "Audio devices" "none reported" "No audio devices detected."
  fi
}

# ---------------------------------------------------------------------------
# Guided manual checklist — printed at the end, optionally interactive.
# ---------------------------------------------------------------------------
run_manual_checklist() {
  section "TIER 3 — Guided manual checklist"
  cat <<EOF
  ${C_DIM}Terminal can see hardware is present, but only YOU can confirm it works.
  Walk these with the machine in front of you:${C_RESET}

  ${C_BOLD}Display${C_RESET}
    ☐ Dead-pixel sweep — fill the screen with solid red, green, blue, white,
      black. Look for stuck dots, dark patches, backlight bleed.
      ${C_CYAN}lemoncheck --pixels${C_RESET} throws these up fullscreen for you.
    ☐ Tilt the lid through its full range — flicker = failing display cable.

  ${C_BOLD}Input${C_RESET}
    ☐ Keyboard — press every key (open a text field or a key-test site).
    ☐ Trackpad — click all four corners; test force-click / haptics.
    ☐ Sticky/mushy keys, especially on butterfly-keyboard-era MacBooks.

  ${C_BOLD}Audio${C_RESET}
    ☐ Speakers — play stereo audio, confirm BOTH left and right, no rattle.
    ☐ Microphone — record a memo and play it back.
    ☐ Headphone jack (if present) — plug in and listen.

  ${C_BOLD}Ports${C_RESET}
    ☐ Every USB-C / Thunderbolt / USB-A port with a REAL drive — data + charge.
    ☐ HDMI / SD / MagSafe where present.

  ${C_BOLD}Other${C_RESET}
    ☐ Camera — live image in Photo Booth.
    ☐ Wi-Fi — actually join a network and load a page.
    ☐ Bluetooth — pair a device.
    ☐ Fans — push CPU load, listen for grinding/rattle, feel for airflow.
    ☐ Touch ID / power button — enroll a fingerprint.
    ☐ Every physical hinge, foot, and port for cracks or prior-repair marks.
EOF
}

# Fullscreen solid-color sweep for the dead-pixel test.
#
# Paints the whole terminal a solid color. For a true edge-to-edge test, put the
# terminal in fullscreen first (View ▸ Enter Full Screen, or ⌃⌘F). Cheap,
# dependency-free, and works over SSH-less local sessions on any macOS version.
run_pixel_test() {
  echo "Dead-pixel sweep — the terminal will fill with solid colors."
  echo "Tip: put this window in FULL SCREEN (⌃⌘F) first for edge-to-edge coverage."
  echo "Look for dots stuck the wrong color, dark patches, or backlight bleed."
  echo
  read -r -p "Press Return to begin... " _ </dev/tty

  local colors=("RED:41" "GREEN:42" "BLUE:44" "WHITE:107" "BLACK:40" "GREY:100")
  local c name code
  for c in "${colors[@]}"; do
    name="${c%%:*}"; code="${c##*:}"
    _pixel_fill "$name" "$code"
  done
  clear
  echo "Pixel sweep complete. Any pixel that never matched the field is dead/stuck."
}

# Paint the terminal one solid color until the user presses Return.
_pixel_fill() {
  local name="$1" code="$2"
  local cols lines y
  cols="$(tput cols 2>/dev/null || echo 80)"
  lines="$(tput lines 2>/dev/null || echo 24)"
  clear
  printf '\033[%sm' "$code"
  for ((y=0; y<lines; y++)); do printf '%*s\n' "$cols" ''; done
  printf '\033[0m'
  # Re-position cursor to top so the prompt is readable on light fields.
  tput cup 0 0 2>/dev/null || true
  read -r -p "  [$name] Return for next color " _ </dev/tty
}
