#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-.tools/Godot.app/Contents/MacOS/Godot}"
mkdir -p test-results
"$godot_bin" --headless --path . --editor --import --quit
"$godot_bin" --headless --path . --script tests/progression_regression.gd --log-file "$PWD/test-results/progression-regression.log"
"$godot_bin" --headless --path . --script tests/classes_runtime.gd --log-file "$PWD/test-results/classes-runtime.log"
"$godot_bin" --headless --path . --script tests/procedural_maps.gd --log-file "$PWD/test-results/procedural-maps.log"
"$godot_bin" --headless --path . --script tests/map_integration.gd --log-file "$PWD/test-results/map-integration.log"
"$godot_bin" --headless --path . --script tests/scenery_regression.gd --log-file "$PWD/test-results/scenery-regression.log"
"$godot_bin" --headless --path . --script tests/torch_regression.gd --log-file "$PWD/test-results/torch-regression.log"
"$godot_bin" --headless --path . --script tests/bow_regression.gd --log-file "$PWD/test-results/bow-regression.log"
"$godot_bin" --headless --path . --script tests/enemy_visuals.gd --log-file "$PWD/test-results/enemy-visuals.log"
"$godot_bin" --headless --path . --script tests/shield_regression.gd --log-file "$PWD/test-results/shield-regression.log"
"$godot_bin" --headless --path . --log-file "$PWD/test-results/campaign.log" -- --test
"$godot_bin" --headless --path . --script tests/combat_timing.gd --log-file "$PWD/test-results/combat-timing.log"
"$godot_bin" --headless --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-normal.log"
"$godot_bin" --headless --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-regression.log" -- --debug-mode --floor=3 --bow --axe
if [ "${RENDER_TEST:-0}" = "1" ]; then
  "$godot_bin" --path . --script tests/combat_timing.gd --log-file "$PWD/test-results/combat-timing-native.log" -- --live-attacks
  "$godot_bin" --path . --script tests/enemy_visuals.gd --log-file "$PWD/test-results/enemy-render.log" -- --render-enemies
  "$godot_bin" --path . --script tests/shield_regression.gd --log-file "$PWD/test-results/shield-render.log" -- --render-shields
  "$godot_bin" --path . --script tests/classes_runtime.gd --log-file "$PWD/test-results/classes-render.log" -- --render-classes
  "$godot_bin" --path . --script tests/bow_regression.gd --log-file "$PWD/test-results/bow-render.log" -- --render-bow
  "$godot_bin" --path . --script tests/torch_regression.gd --log-file "$PWD/test-results/torch-render.log" -- --render-torches
  "$godot_bin" --path . --script tests/scenery_regression.gd --log-file "$PWD/test-results/scenery-render.log" -- --render-scenery
  "$godot_bin" --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-render.log" -- --debug-mode --render-debug-test
  "$godot_bin" --path . --script tests/hud_regression.gd --log-file "$PWD/test-results/hud-regression.log"
  "$godot_bin" --path . --script tests/attack_preview.gd --log-file "$PWD/test-results/attack-preview.log"
  "$godot_bin" --path . --script tests/controls_regression.gd --log-file "$PWD/test-results/controls-regression.log"
  "$godot_bin" --path . --script tests/input_playtest.gd --log-file "$PWD/test-results/input-playtest.log"
fi
