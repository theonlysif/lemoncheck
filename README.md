# 🍋 lemoncheck

**Inspect a used Mac before you buy it.** A single command that surfaces the
*silent deal-breakers* — the stuff that turns a "great deal" into a bricked
purchase and that a casual buyer can't see until after they've paid.

Everyone checks battery cycles. Nobody checks whether the Mac is still
enrolled in a company's device-management program (re-locks on every wipe),
whether Activation Lock is on (instant paperweight), or how many terabytes
have been hammered through the SSD. `lemoncheck` does — and prints a
**traffic-light report** instead of a wall of raw `system_profiler` dump.

```
$ lemoncheck --deep

TIER 1 — Deal-breakers
  ✖ MDM / DEP enrollment      ENROLLED via DEP / Apple Business Manager
  ✔ Activation Lock           disabled
  ✔ Firmware password         not set
  • Serial number             C02X…  (MacBook Pro)
  ▲ Persistence audit         2 third-party launch item(s)

VERDICT
     ●  DO NOT BUY (yet) — 1 deal-breaker(s)
```

---

## Why this exists

The used-Mac buyer is underserved. coconutBattery covers the battery;
manual Terminal spelunking covers nothing reliably. The commands are
commodities — the product is the *curation*: which checks actually predict a
bad purchase, and a plain-English "walk away / proceed with caution / looks
clean" verdict you can act on standing in a stranger's living room.

## What it checks

### Tier 1 — Deal-breakers ("walk away now")
- **MDM / DEP enrollment** — the single most important check. A Mac registered
  to an org's Apple Business Manager re-enrolls into remote management on
  *every* wipe and often can't be removed. `lemoncheck` screams if it finds it.
- **Activation Lock** — Find My still active = the seller's Apple ID owns the
  machine. Must be signed out *before* you pay.
- **Firmware password (Intel) / Recovery lock (Apple Silicon)** — locks you out
  of recovery and reinstall.
- **Serial sanity** — surfaces the serial to cross-check against Apple's
  coverage page; blank/malformed serials flag a possible swapped logic board or
  grey-market/stolen unit.
- **Persistence audit** — leftover launch agents/daemons and config profiles
  (adware, keyloggers, parental spyware, DNS hijacks).

### Tier 2 — Wear & true condition
- **SSD terabytes-written (TBW)** and **% life used** via SMART — the sleeper
  metric. Cycle count tells you about the battery; TBW tells you how hammered
  the drive is (and it's not user-replaceable on modern Macs).
- **Battery health %** — full-charge ÷ design capacity, not just the
  Normal/Service label.
- **Kernel panic history** — a pile of panics = failing hardware a reinstall
  won't fix.
- **Thermal state** — flags active throttling (dried paste, blocked fans,
  prior liquid damage).
- **OS install history** — flags a machine wiped days before sale (conveniently
  erases its own history).

### Tier 3 — Does every component actually work
Auto-detects what hardware *reports* as present (RAM, ports, Wi-Fi/BT, GPU,
camera, displays, audio), then hands you a **guided manual checklist** for the
things Terminal can detect but not exercise — plus a fullscreen **dead-pixel
sweep** (`lemoncheck --pixels`).

### Tier 4 — Extras
- **Listing diff** — paste the eBay/OLX spec, `lemoncheck` diffs it against the
  hardware ("listing says 16GB, machine reports 8GB").
- **Value sanity** — model + chip + storage summary to price against completed
  sales.
- **HTML report** — a self-contained report you (or the seller, to build trust)
  can keep as evidence.

Apple Silicon vs Intel branching (firmware password, `bputil`, T2 vs Secure
Enclave paths) is baked in from day one.

## Install

Pick the path that fits you. Shopping for a used Mac and not a developer? Use
the first one.

### 🛒 Fastest — one paste, no install (great while shopping)

Open **Terminal** on the Mac you're inspecting (⌘-Space, type "Terminal") and
paste:

```sh
curl -fsSL https://raw.githubusercontent.com/theonlysif/lemoncheck/main/dist/lemoncheck | bash -s -- --deep --report
```

Runs in a few seconds, needs no install, and doesn't trip Gatekeeper. Drop
`--deep` if you don't have the admin password. The `| bash` form is convenient;
if you'd rather read it first, open the [`dist/lemoncheck`](dist/lemoncheck)
file — it's the whole program in one file.

### 🍋 Double-click app (for non-developers)

1. Download **LemonCheck.dmg** from the
   [latest release](https://github.com/theonlysif/lemoncheck/releases/latest).
2. Open the DMG, drag **LemonCheck** to Applications (or run it right from the DMG).
3. **First run:** right-click the app ▸ **Open** ▸ **Open** (this one-time step
   gets past macOS's "unidentified developer" block — the app is free and
   unsigned). A `READ ME FIRST.txt` in the DMG spells this out.

The app opens Terminal, runs the full scan, and saves an HTML report to your
Desktop.

### 🍺 Homebrew (for developers)

```sh
brew tap theonlysif/lemoncheck https://github.com/theonlysif/lemoncheck
brew install lemoncheck
```

### From source

```sh
git clone https://github.com/theonlysif/lemoncheck.git
cd lemoncheck && ./install.sh
```

For the full SSD SMART read, install smartmontools: `brew install smartmontools`.
For more precise parsing, install `jq`: `brew install jq`.

> **Why no signed, notarized app?** Apple charges $99/yr for a Developer ID and
> requires notarizing every build. Until that's set up, the app is unsigned —
> hence the one-time right-click ▸ Open. The `curl` one-liner sidesteps
> Gatekeeper entirely, which is why it's the recommended path for shopping.

## Usage

```sh
lemoncheck                      # standard scan (no sudo)
lemoncheck --deep               # + MDM/DEP, firmware, full SSD SMART (uses sudo)
lemoncheck --report             # also write an HTML report to ~/Desktop
lemoncheck --report out.html    # …to a specific path
lemoncheck --listing "16GB 512GB M2 Pro"   # diff a pasted ad against the machine
lemoncheck --pixels             # fullscreen dead-pixel sweep
lemoncheck --manual             # print the guided manual checklist
```

Run it on the machine you're about to buy, in front of the seller. The whole
scan takes a few seconds.

`lemoncheck` exits non-zero when it finds a Tier-1 deal-breaker, so you can
script around it.

## Privacy

Every check runs **locally**. Nothing is uploaded. The serial number is shown
so *you* can look it up on Apple's site — `lemoncheck` doesn't phone home.

> Honesty caveat: Apple's public serial/coverage endpoint has grown flaky
> (captchas, deprecations), so `lemoncheck` surfaces the serial for you to
> check by hand rather than hitting an API that may silently break. Everything
> else is fully local and reliable.

## Requirements

- macOS (Apple Silicon or Intel)
- `--deep` checks require administrator rights (sudo)
- Optional: `smartmontools` (SSD SMART), `jq` (precise parsing)

## Limitations

- Terminal detects *presence*, not *function* — hence the guided manual
  checklist. Always physically test ports, keys, speakers, and the camera.
- Some Apple NVMe controllers don't expose SMART to `smartctl`; when that
  happens `lemoncheck` says so rather than guessing.
- Activation Lock state isn't always reported programmatically; verify in
  System Settings when the tool asks you to.

## License

MIT — see [LICENSE](LICENSE).

---

*Not affiliated with Apple. "Mac" is a trademark of Apple Inc.*
