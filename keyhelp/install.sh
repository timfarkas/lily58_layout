#!/usr/bin/env bash
# build keyhelp + (re)install it as a login LaunchAgent. usage: ./install.sh [hotkey, default F19]
# uninstall: launchctl bootout gui/$(id -u)/local.keyhelp && rm ~/Library/LaunchAgents/local.keyhelp.plist
set -euo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"; HOTKEY="${1:-F19}"; LABEL=local.keyhelp
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
[ -f keymap.png ] || ./render.sh
swiftc -O keyhelp.swift -o keyhelp
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$DIR/keyhelp</string><string>$DIR/keymap.png</string><string>$HOTKEY</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>StandardErrorPath</key><string>/tmp/keyhelp.log</string>
  <key>StandardOutPath</key><string>/tmp/keyhelp.log</string>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed: hold $HOTKEY (lily: raise+space). log: /tmp/keyhelp.log"
