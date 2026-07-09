#!/usr/bin/env bash
# lemoncheck — summary + HTML/report export
# shellcheck shell=bash disable=SC2155

# Print the traffic-light verdict and tally.
print_summary() {
  local reds=0 ambers=0 greens=0 manuals=0 i
  for i in "${!FND_STATUS[@]}"; do
    case "${FND_STATUS[$i]}" in
      RED)    reds=$((reds+1)) ;;
      AMBER)  ambers=$((ambers+1)) ;;
      GREEN)  greens=$((greens+1)) ;;
      MANUAL) manuals=$((manuals+1)) ;;
    esac
  done

  section "VERDICT"

  # Overall traffic light.
  if [[ "$reds" -gt 0 ]]; then
    printf "  %s%s  ●  DO NOT BUY (yet) — %d deal-breaker(s)  %s\n" \
      "$C_REDBG$C_BOLD" " " "$reds" "$C_RESET"
  elif [[ "$ambers" -gt 0 ]]; then
    printf "  %s%s  ●  PROCEED WITH CAUTION — %d wear/watch item(s)  %s\n" \
      "$C_YELBG$C_BOLD" " " "$ambers" "$C_RESET"
  else
    printf "  %s%s  ●  LOOKS CLEAN — no automated red/amber flags  %s\n" \
      "$C_GREEN$C_BOLD" "" "$C_RESET"
  fi

  printf "\n  %s✖ %d red   ▲ %d amber   ✔ %d green   ☐ %d manual%s\n" \
    "$C_DIM" "$reds" "$ambers" "$greens" "$manuals" "$C_RESET"

  # Repeat the actionable items so the user doesn't scroll.
  if [[ "$reds" -gt 0 || "$ambers" -gt 0 ]]; then
    printf "\n  %sAction items:%s\n" "$C_BOLD" "$C_RESET"
    for i in "${!FND_STATUS[@]}"; do
      case "${FND_STATUS[$i]}" in
        RED)   printf "   %s✖%s %s — %s\n" "$C_RED" "$C_RESET" "${FND_TITLE[$i]}" "${FND_DETAIL[$i]}" ;;
        AMBER) printf "   %s▲%s %s — %s\n" "$C_YELLOW" "$C_RESET" "${FND_TITLE[$i]}" "${FND_DETAIL[$i]}" ;;
      esac
    done
  fi

  if ! is_root; then
    printf "\n  %sSome deep checks were skipped. Re-run with %slemoncheck --deep%s%s for MDM,\n  firmware, and full SSD SMART results.%s\n" \
      "$C_DIM" "$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
  fi
  echo
}

# Escape a string for safe HTML embedding.
_html_escape() {
  local s="$1"
  s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
  printf '%s' "$s"
}

# Write a self-contained HTML report to $1.
write_html_report() {
  local out="$1"
  local host model serial when
  host="$(scutil --get ComputerName 2>/dev/null || hostname)"
  model="${LEMON_MODEL:-$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2; exit}')}"
  serial="${LEMON_SERIAL:-unknown}"
  when="$(date '+%Y-%m-%d %H:%M %Z')"

  local reds=0 ambers=0 greens=0 i
  for i in "${!FND_STATUS[@]}"; do
    case "${FND_STATUS[$i]}" in
      RED) reds=$((reds+1)) ;; AMBER) ambers=$((ambers+1)) ;; GREEN) greens=$((greens+1)) ;;
    esac
  done

  local verdict verdict_class
  if [[ "$reds" -gt 0 ]]; then verdict="DO NOT BUY — $reds deal-breaker(s)"; verdict_class="red"
  elif [[ "$ambers" -gt 0 ]]; then verdict="PROCEED WITH CAUTION — $ambers watch item(s)"; verdict_class="amber"
  else verdict="LOOKS CLEAN"; verdict_class="green"; fi

  {
    cat <<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>lemoncheck report — $(_html_escape "$model")</title>
<style>
  :root{--red:#d64545;--amber:#d99a1c;--green:#2e9e5b;--bg:#f7f7f5;--card:#fff;--ink:#1a1a1a;--muted:#666;--line:#e5e5e0}
  @media (prefers-color-scheme:dark){:root{--bg:#141414;--card:#1e1e1e;--ink:#eee;--muted:#999;--line:#2c2c2c}}
  *{box-sizing:border-box}
  body{margin:0;font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:var(--bg);color:var(--ink)}
  .wrap{max-width:820px;margin:0 auto;padding:32px 20px 64px}
  h1{font-size:22px;margin:0 0 4px;display:flex;align-items:center;gap:10px}
  .sub{color:var(--muted);font-size:13px;margin-bottom:24px}
  .verdict{padding:18px 22px;border-radius:12px;font-weight:700;font-size:18px;color:#fff;margin-bottom:8px}
  .verdict.red{background:var(--red)}.verdict.amber{background:var(--amber)}.verdict.green{background:var(--green)}
  .tally{display:flex;gap:16px;color:var(--muted);font-size:13px;margin:14px 0 28px}
  .tier{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:26px 0 8px;font-weight:700}
  .card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
  .row{display:flex;gap:12px;padding:14px 16px;border-top:1px solid var(--line);align-items:flex-start}
  .row:first-child{border-top:none}
  .dot{flex:none;width:10px;height:10px;border-radius:50%;margin-top:6px}
  .dot.RED{background:var(--red)}.dot.AMBER{background:var(--amber)}.dot.GREEN{background:var(--green)}
  .dot.MANUAL{background:#4a90d6}.dot.INFO{background:#aaa}
  .rc{flex:1;min-width:0}
  .rt{font-weight:600}
  .rd{color:var(--muted);font-size:13px;margin-top:2px;word-break:break-word}
  .ra{font-size:13px;margin-top:6px;padding:8px 10px;background:rgba(127,127,127,.08);border-radius:8px}
  footer{color:var(--muted);font-size:12px;margin-top:36px;text-align:center}
</style></head><body><div class="wrap">
<h1>🍋 lemoncheck report</h1>
<div class="sub">$(_html_escape "$model") &middot; serial $(_html_escape "$serial") &middot; $(_html_escape "$host") &middot; $(_html_escape "$when")</div>
<div class="verdict $verdict_class">$(_html_escape "$verdict")</div>
<div class="tally">✖ $reds red &nbsp; ▲ $ambers amber &nbsp; ✔ $greens green</div>
HTML

    local last_tier=""
    for i in "${!FND_STATUS[@]}"; do
      local tier="${FND_TIER[$i]}" st="${FND_STATUS[$i]}"
      if [[ "$tier" != "$last_tier" ]]; then
        [[ -n "$last_tier" ]] && echo "</div>"
        local label
        case "$tier" in
          1) label="Tier 1 — Deal-breakers" ;;
          2) label="Tier 2 — Wear &amp; condition" ;;
          3) label="Tier 3 — Components" ;;
          4) label="Tier 4 — Extras" ;;
          *) label="Other" ;;
        esac
        echo "<div class=\"tier\">$label</div><div class=\"card\">"
        last_tier="$tier"
      fi
      printf '<div class="row"><span class="dot %s"></span><div class="rc"><div class="rt">%s</div><div class="rd">%s</div>%s</div></div>\n' \
        "$st" \
        "$(_html_escape "${FND_TITLE[$i]}")" \
        "$(_html_escape "${FND_DETAIL[$i]}")" \
        "$( [[ -n "${FND_ADVICE[$i]}" ]] && printf '<div class="ra">%s</div>' "$(_html_escape "${FND_ADVICE[$i]}")" )"
    done
    [[ -n "$last_tier" ]] && echo "</div>"

    cat <<HTML
<footer>Generated by lemoncheck v${LEMONCHECK_VERSION:-0.1.0} — a used-Mac lemon detector.<br>
All checks run locally. This report is evidence you can keep or share with the seller.</footer>
</div></body></html>
HTML
  } > "$out"
}
