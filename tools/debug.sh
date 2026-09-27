#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-.tools/Godot.app/Contents/MacOS/Godot}"
exec "$godot_bin" --path . -- --debug-mode "$@"
