#!/bin/bash
# Ghost Hunter Simulator checks: type check (strict errors only in our code), unit tests, Rojo build.
#   bash tools/check.sh          # everything
#   bash tools/check.sh --quick  # skip the Rojo build
T="${GH_TOOLS:-/tmp/gh-tools}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] && [ -x "$T/lsp/luau-lsp" ] && [ -x "$T/rojo/rojo" ] || bash tools/setup_env.sh >/dev/null
fail=0
"$T/rojo/rojo" sourcemap default.project.json -o "$T/gh_sourcemap.json" >/dev/null 2>&1
diag=$("$T/lsp/luau-lsp" analyze --definitions="$T/globalTypes.d.luau" --sourcemap="$T/gh_sourcemap.json" src 2>&1 | grep -v "^$")
if [ -z "$diag" ]; then echo "typecheck: ok"; else echo "typecheck: $(echo "$diag" | wc -l) diagnostics"; echo "$diag" | head -40; fail=1; fi
{ echo 'local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }'; echo 'local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }'; grep -v "^--!strict" src/shared/Config.luau; } > tests/_Config.luau
out=$(cd tests && "$T/luau/luau" run.luau 2>&1 | tail -1)
echo "unit tests: $out"; echo "$out" | grep -q " 0 failed" || { (cd tests && "$T/luau/luau" run.luau 2>&1 | grep -E "FAIL|error" | head -20); fail=1; }
ws=$(bash tools/worldsim.sh 2>&1 | tail -1); echo "$ws"; echo "$ws" | grep -q "0 error(s), 0 layout" || fail=1
if [ "${1:-}" != "--quick" ]; then
  if "$T/rojo/rojo" build default.project.json -o build/GhostHunterSimulator.rbxlx >/dev/null 2>&1; then echo "build: ok"; else echo "build: FAILED"; fail=1; fi
fi
exit $fail
