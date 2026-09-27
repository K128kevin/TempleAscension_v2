#!/bin/sh
set -eu
cd "$(dirname "$0")"
exec "./Temple Ascension 3D.app/Contents/MacOS/Temple Ascension 3D" -- --debug-mode "$@"
