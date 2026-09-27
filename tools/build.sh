#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-.tools/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$godot_bin" ]; then
  echo "Set GODOT_BIN to the Godot 4.7.2 executable."
  exit 1
fi
mkdir -p builds/windows builds/macos test-results
"$godot_bin" --headless --path . --editor --import --quit
"$godot_bin" --headless --path . --export-release macOS builds/TempleAscension-macOS.zip
"$godot_bin" --headless --path . --export-release Windows builds/windows/TempleAscension.exe
if command -v ditto >/dev/null 2>&1; then
  ditto -x -k builds/TempleAscension-macOS.zip builds/macos
  cp "tools/Debug Mode.command" "builds/macos/Debug Mode.command"
  chmod +x "builds/macos/Debug Mode.command"
  cp "tools/Debug Mode.bat" "builds/windows/Debug Mode.bat"
  for platform in macos windows; do
    cp README.md "builds/$platform/README.md"
    cp docs/ASSETS.md "builds/$platform/ASSETS.md"
    mkdir -p "builds/$platform/licenses"
    cp -R assets/licenses/. "builds/$platform/licenses/"
    cp assets/models/character/*License.txt "builds/$platform/licenses/"
  done
  ditto -c -k builds/macos builds/TempleAscension-macOS.zip
  ditto -c -k --keepParent builds/windows builds/TempleAscension-Windows.zip
fi
