#!/usr/bin/env bash
# usage: shot.sh <vcd> <png> <from_ns> <to_ns> <sigset: ext|int|modes|all> [crop_height]
# Робить скріншот GTKWave (у віртуальному дисплеї Xvfb) і обрізає зайві панелі.
set -euo pipefail
VCD=$1; PNG=$2; export WAVE_FROM=$3; export WAVE_TO=$4; export SIGSET=$5
H=${6:-300}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -u).png"
xvfb-run -a -s "-screen 0 1000x520x24" bash -c "
  gtkwave -4 'initial_window_x 1000' -4 'initial_window_y 520' -4 'splash_disable 1' \
    -S '$DIR/wave.tcl' '$VCD' >/dev/null 2>&1 &
  GP=\$!
  sleep 9
  import -window root '$TMP'
  kill \$GP
"
convert "$TMP" -crop 703x${H}+282+113 +repage "$PNG"
rm -f "$TMP"
