#!/bin/bash
# Headless world smoke test: runs the real world builder (src/server/World) and the rigs
# (src/shared/Rigs) under a mock Roblox runtime (tools/worldsim/prelude.luau) and checks the
# layout (ghost areas, Fast Travel points, main route). See tools/worldsim/runner.luau.
#   bash tools/worldsim.sh            # summary
#   bash tools/worldsim.sh --verbose  # list every offending part
#   WORLDSIM_PROBE=my_probe.luau bash tools/worldsim.sh   # also run an ad-hoc script afterwards
#     (it sees SIM.Map, SIM.Parts and SIM.Query(x1, z1, x2, z2) -> parts with AABB X1..Z2)
# Exit code: 0 clean, 1 runtime errors, 2 layout issues only.
T="${GH_TOOLS:-/tmp/gh-tools}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -x "$T/luau/luau" ] || bash tools/setup_env.sh >/dev/null
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
B="$OUT/worldsim_bundle.luau"
DELIM="]==========]"

files=(tools/worldsim/prelude.luau tools/worldsim/runner.luau $(find src/shared src/server/World -name '*.luau' | sort) ${WORLDSIM_EXTRA:-} ${WORLDSIM_PROBE:+"$WORLDSIM_PROBE"})
{
  echo "local FILES = {}"
  for f in "${files[@]}"; do
    if grep -qF "$DELIM" "$f"; then echo "error('$f contains the bundle delimiter')"; fi
    printf 'FILES["%s"] = [==========[\n' "$f"
    cat "$f"
    printf '\n%s\n' "$DELIM"
  done
  [ "${1:-}" = "--verbose" ] && echo "WORLDSIM_VERBOSE = true"
  cat <<'LUA'
local function run(path)
	local fn, err = loadstring(FILES[path], "=" .. path)
	if not fn then
		error(err, 0)
	end
	setfenv(fn, getfenv(1))
	fn()
end
run("tools/worldsim/prelude.luau")
-- mount modules where Rojo puts them (default.project.json)
for path, src in FILES do
	local rel, root
	if string.sub(path, 1, 11) == "src/shared/" then
		rel, root = string.sub(path, 12), { "ReplicatedStorage", "GH" }
	elseif string.sub(path, 1, 11) == "src/server/" then
		rel, root = string.sub(path, 12), { "ServerScriptService", "GHServer" }
	end
	if rel then
		local segs = string.split(rel, "/")
		local file = table.remove(segs) :: string
		local name = string.gsub(file, "%.luau$", "")
		for _, s in segs do
			table.insert(root, s)
		end
		if name == "init" then
			error("init.luau modules are not supported by worldsim: " .. path)
		end
		SIM.Mount(root, name, path, src)
	end
end
run("tools/worldsim/runner.luau")
LUA
  [ -n "${WORLDSIM_PROBE:-}" ] && printf 'print("== probe ==")\nrun("%s")\n' "$WORLDSIM_PROBE"
} > "$B"
"$T/luau/luau" "$B" 2>&1 | tee "$OUT/log.txt"
last=$(grep "^worldsim:" "$OUT/log.txt" | tail -1)
[ -z "$last" ] && { echo "worldsim: runner crashed"; exit 1; }
echo "$last" | grep -q "^worldsim: 0 error" || exit 1
echo "$last" | grep -q " 0 layout issue" || exit 2
exit 0
