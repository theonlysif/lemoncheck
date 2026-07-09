🍋  LemonCheck — inspect a used Mac before you buy it
=====================================================

WHAT IT DOES
  Runs a quick, all-local scan of THIS Mac and prints a red / amber / green
  report of the silent deal-breakers that turn a "good deal" into a bricked
  purchase — things like:

    • Is it still locked to a company or a previous owner's Apple ID?
    • How worn is the battery and the SSD, really?
    • Any leftover spyware / weird startup items?
    • Do the parts (Wi-Fi, camera, ports…) actually check out?

  Nothing is uploaded. It only reads this machine and saves a report to your
  Desktop that you can keep as evidence.


HOW TO RUN IT  (first time — 10 seconds)
  Because this is a free tool that isn't registered with Apple, macOS will
  block a normal double-click the first time. To get past that:

    1.  RIGHT-CLICK (or Control-click) LemonCheck.app
    2.  Choose "Open"
    3.  In the popup, click "Open" again

  After that first time, a normal double-click works.

  If macOS still refuses ("cannot be opened"):
    • Open  System Settings ▸ Privacy & Security
    • Scroll down and click "Open Anyway" next to LemonCheck.


WHILE SHOPPING
  Run this ON the Mac you're thinking of buying, in front of the seller.
  When it asks for a password, that's this Mac's own admin password — the
  seller can type it. The whole scan takes a few seconds.

  A red verdict = walk away (or renegotiate hard).


Prefer the command line? One paste, no install:
  curl -fsSL https://raw.githubusercontent.com/theonlysif/lemoncheck/main/dist/lemoncheck | bash -s -- --deep --report

More info:  https://github.com/theonlysif/lemoncheck
