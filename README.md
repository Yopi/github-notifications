# NotificationBar

A native macOS menu bar app that mirrors [github.com/pulls/inbox](https://github.com/pulls/inbox).

> ⚠️ This code was written entirely by Claude. No human has read the source code.

- Menu bar icon with a count of PRs that need attention (review requests + unread activity)
- Sections: Needs your review, Your drafts, Waiting for review or checks, Needs action, Ready to merge
- Blue "N new" badges when a PR gets new comments or reviews since you last opened it
- Status icons for failing checks, changes requested, merge conflicts, and running checks
- Click a row to open the PR in the browser (marks it read)
- Refreshes every 60 seconds; light and dark mode

## Requirements

- macOS 14+
- [`gh`](https://cli.github.com) logged in (`gh auth login`), or a `GITHUB_TOKEN` env var with `repo` scope

## Run

```sh
./bundle.sh
open dist/NotificationBar.app
```

The bundle is required for system notifications (macOS only grants notification permission to bundled apps). Running the raw binary (`.build/release/NotificationBar`) also works but falls back to AppleScript notifications.

Notification triggers (review requested, new comments, PR approved, changes requested) are configurable via the gear icon in the popover footer.

## Start at login

```sh
cat > ~/Library/LaunchAgents/com.notificationbar.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.notificationbar</string>
  <key>ProgramArguments</key><array><string>$(pwd)/dist/NotificationBar.app/Contents/MacOS/NotificationBar</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
launchctl load ~/Library/LaunchAgents/com.notificationbar.plist
```

## Notes

- Read state lives in `~/Library/Application Support/NotificationBar/readstate.json` — delete it to reset unread tracking.
- Notification state lives in `notifystate.json` next to `readstate.json`; the first run baselines silently, so notifications only fire for changes after that.
- The app icon is drawn programmatically by `tools/make-icon.swift` (regenerate with `swift tools/make-icon.swift icon.png`, then rebuild `Resources/AppIcon.icns`).
- Debug helpers: `--snapshot out.png` renders the UI to a PNG (`NOTIFBAR_DARK=1` for dark mode); `NOTIFBAR_OPEN=1` auto-opens the popover; `NOTIFBAR_CAPTURE=out.png` captures the live popover; `NOTIFBAR_CAPTURE_SETTINGS=out.png` captures the settings pane.
