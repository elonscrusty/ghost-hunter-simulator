#!/bin/bash
# Save-compatibility test: runs older-format player saves through the real DataService migration.
cd "$(dirname "$0")/.." || exit 1
WORLDSIM_EXTRA="src/server/Services/DataService.luau" WORLDSIM_PROBE=tools/datacompat/probe.luau bash tools/worldsim.sh 2>&1 | sed -n '/== probe ==/,$p' | grep -v "^== probe" | tee /tmp/datacompat_out.txt
grep -q "datacompat: 0 failed" /tmp/datacompat_out.txt
