-- LemonCheck.app — opens Terminal and runs the embedded lemoncheck scan.
-- Double-clickable wrapper around the bundled shell script.

on run
	set appPath to POSIX path of (path to me)
	set scriptPath to appPath & "Contents/Resources/lemoncheck"

	-- Friendly heads-up before we ask for anything.
	display dialog "LemonCheck inspects this Mac for the silent deal-breakers before you buy a used machine." & return & return & "It opens Terminal and runs a full scan. For the MDM / firmware checks you'll be asked for this Mac's password (the seller can type it) — everything runs locally and nothing is uploaded." buttons {"Cancel", "Run scan"} default button "Run scan" with title "LemonCheck" with icon note

	-- Copy the script somewhere writable & un-quarantined so bash will run it
	-- even when the app itself is quarantined on a stranger's Mac.
	set tmpScript to "/tmp/lemoncheck-run"
	do shell script "cp " & quoted form of scriptPath & " " & quoted form of tmpScript & " && chmod +x " & quoted form of tmpScript & " && xattr -c " & quoted form of tmpScript

	set cmd to "clear; bash " & quoted form of tmpScript & " --deep --report; echo; echo '──────────────────────────────────────────'; echo '  Scan complete. An HTML report was saved to your Desktop.'; echo '  You can close this window.'; echo '──────────────────────────────────────────'"

	tell application "Terminal"
		activate
		do script cmd
	end tell
end run
