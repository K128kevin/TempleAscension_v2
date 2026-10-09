#!/bin/sh
set -u
# Every test runs even when an earlier one fails; failures are listed at the end.
failed=""
# A test that has not finished in TEST_TIMEOUT seconds (default 600) is
# stopped and counted as failed, so a stalled engine cannot hang the suite.
run() {
  "$@" &
  pid=$!
  (
    trap 'kill "$nap" 2>/dev/null; exit 0' TERM
    sleep "${TEST_TIMEOUT:-600}" & nap=$!
    wait "$nap" && kill "$pid" 2>/dev/null && echo "Timed out: $*" >&2
  ) &
  watchdog=$!
  if wait "$pid"; then status=0; else status=$?; fi
  kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
  if [ "$status" -ne 0 ]; then
    failed="$failed
  $*"
  fi
}
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-.tools/Godot.app/Contents/MacOS/Godot}"
mkdir -p test-results
"$godot_bin" --headless --path . --editor --import --quit
run "$godot_bin" --headless --path . --script tests/progression_regression.gd --log-file "$PWD/test-results/progression-regression.log"
run "$godot_bin" --headless --path . --script tests/classes_runtime.gd --log-file "$PWD/test-results/classes-runtime.log"
run "$godot_bin" --headless --path . --script tests/warrior_skills.gd --log-file "$PWD/test-results/warrior-skills.log"
run "$godot_bin" --headless --path . --script tests/ranger_skills.gd --log-file "$PWD/test-results/ranger-skills.log"
run "$godot_bin" --headless --path . --script tests/wizard_skills.gd --log-file "$PWD/test-results/wizard-skills.log"
run "$godot_bin" --headless --path . --script tests/items.gd --log-file "$PWD/test-results/items.log"
run "$godot_bin" --headless --path . --script tests/overworld.gd --log-file "$PWD/test-results/overworld.log"
run "$godot_bin" --headless --path . --script tests/daylight.gd --log-file "$PWD/test-results/daylight.log"
run "$godot_bin" --headless --path . --script tests/dungeons.gd --log-file "$PWD/test-results/dungeons.log"
run "$godot_bin" --headless --path . --script tests/basement_props.gd --log-file "$PWD/test-results/basement-props.log"
run "$godot_bin" --headless --path . --script tests/rats.gd --log-file "$PWD/test-results/rats.log"
run "$godot_bin" --headless --path . --script tests/procedural_maps.gd --log-file "$PWD/test-results/procedural-maps.log"
run "$godot_bin" --headless --path . --script tests/map_integration.gd --log-file "$PWD/test-results/map-integration.log"
run "$godot_bin" --headless --path . --script tests/scenery_regression.gd --log-file "$PWD/test-results/scenery-regression.log"
run "$godot_bin" --headless --path . --script tests/torch_regression.gd --log-file "$PWD/test-results/torch-regression.log"
run "$godot_bin" --headless --path . --script tests/floor_tiles.gd --log-file "$PWD/test-results/floor-tiles.log"
run "$godot_bin" --headless --path . --script tests/bow_regression.gd --log-file "$PWD/test-results/bow-regression.log"
run "$godot_bin" --headless --path . --script tests/enemy_visuals.gd --log-file "$PWD/test-results/enemy-visuals.log"
run "$godot_bin" --headless --path . --script tests/bandit_visuals.gd --log-file "$PWD/test-results/bandit-visuals.log"
run "$godot_bin" --headless --path . --script tests/shield_regression.gd --log-file "$PWD/test-results/shield-regression.log"
run "$godot_bin" --headless --path . --script tests/enemy_hover.gd --log-file "$PWD/test-results/enemy-hover.log"
run "$godot_bin" --headless --path . --script tests/hide_ui.gd --log-file "$PWD/test-results/hide-ui.log"
run "$godot_bin" --headless --path . --script tests/buff_bar.gd --log-file "$PWD/test-results/buff-bar.log"
run "$godot_bin" --headless --path . --log-file "$PWD/test-results/campaign.log" -- --test
run "$godot_bin" --headless --path . --script tests/combat_timing.gd --log-file "$PWD/test-results/combat-timing.log"
run "$godot_bin" --headless --fixed-fps 60 --path . --script tests/statue_physics.gd --log-file "$PWD/test-results/statue-physics.log"
run "$godot_bin" --headless --fixed-fps 60 --path . --script tests/bandit_ragdoll.gd --log-file "$PWD/test-results/bandit-ragdoll.log"
run "$godot_bin" --headless --fixed-fps 60 --path . --script tests/ragdoll_stability.gd --log-file "$PWD/test-results/ragdoll-stability.log"
run "$godot_bin" --headless --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-normal.log"
run "$godot_bin" --headless --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-regression.log" -- --debug-mode --floor=3 --bow --axe
run "$godot_bin" --headless --path . --script tests/playground.gd --log-file "$PWD/test-results/playground.log" -- --debug-mode
run "$godot_bin" --headless --path . --script tests/animation_regression.gd --log-file "$PWD/test-results/animation-regression.log"
if [ "${RENDER_TEST:-0}" = "1" ]; then
  run "$godot_bin" --path . --script tests/enemy_hover.gd --log-file "$PWD/test-results/enemy-hover-native.log" -- --render-hover
  run "$godot_bin" --path . --script tests/hide_ui.gd --log-file "$PWD/test-results/hide-ui-render.log" -- --render-ui
  run "$godot_bin" --path . --script tests/buff_bar.gd --log-file "$PWD/test-results/buff-bar-render.log" -- --render-buffs
  run "$godot_bin" --path . --script tests/combat_timing.gd --log-file "$PWD/test-results/combat-timing-native.log" -- --live-attacks
  run "$godot_bin" --path . --script tests/enemy_visuals.gd --log-file "$PWD/test-results/enemy-render.log" -- --render-enemies
  run "$godot_bin" --path . --script tests/bandit_visuals.gd --log-file "$PWD/test-results/bandit-render.log" -- --render-bandits
  run "$godot_bin" --fixed-fps 60 --path . --script tests/bandit_ragdoll.gd --log-file "$PWD/test-results/bandit-ragdoll-render.log" -- --render-ragdoll
  run "$godot_bin" --path . --script tests/shield_regression.gd --log-file "$PWD/test-results/shield-render.log" -- --render-shields
  run "$godot_bin" --path . --script tests/classes_runtime.gd --log-file "$PWD/test-results/classes-render.log" -- --render-classes
  run "$godot_bin" --path . --script tests/items.gd --log-file "$PWD/test-results/items-render.log" -- --render-items
  run "$godot_bin" --path . --script tests/bow_regression.gd --log-file "$PWD/test-results/bow-render.log" -- --render-bow
  run "$godot_bin" --path . --script tests/torch_regression.gd --log-file "$PWD/test-results/torch-render.log" -- --render-torches
  run "$godot_bin" --path . --script tests/scenery_regression.gd --log-file "$PWD/test-results/scenery-render.log" -- --render-scenery
  run "$godot_bin" --path . --script tests/overworld.gd --log-file "$PWD/test-results/overworld-render.log" -- --render-world
  run "$godot_bin" --path . --script tests/debug_regression.gd --log-file "$PWD/test-results/debug-render.log" -- --debug-mode --render-debug-test
  run "$godot_bin" --path . --script tests/hud_regression.gd --log-file "$PWD/test-results/hud-regression.log"
  run "$godot_bin" --path . --script tests/attack_preview.gd --log-file "$PWD/test-results/attack-preview.log"
  run "$godot_bin" --path . --script tests/controls_regression.gd --log-file "$PWD/test-results/controls-regression.log"
  run "$godot_bin" --path . --script tests/input_playtest.gd --log-file "$PWD/test-results/input-playtest.log"
fi
if [ -n "$failed" ]; then
  printf "Failed:%b\n" "$failed"
  exit 1
fi
