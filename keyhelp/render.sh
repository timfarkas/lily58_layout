#!/usr/bin/env bash
# config/lily58.keymap -> keyhelp/keymap.png (transparent, 3x). rerun after every keymap change.
# lily58_compact.json = QMK lily58 layout with the right half pulled 1.5u inward (less dead space mid-overlay).
set -euo pipefail
cd "$(dirname "$0")"
command -v rsvg-convert >/dev/null || { echo "need rsvg-convert: brew install librsvg" >&2; exit 1; }
uvx --from keymap-drawer keymap -c keymap_drawer.yaml parse -z ../config/lily58.keymap 2>/dev/null > keymap.yaml
uvx --from keymap-drawer keymap -c keymap_drawer.yaml draw -j lily58_compact.json keymap.yaml 2>/dev/null > keymap.svg
rsvg-convert -z 3 keymap.svg -o keymap.png
echo "rendered $(pwd)/keymap.png"
