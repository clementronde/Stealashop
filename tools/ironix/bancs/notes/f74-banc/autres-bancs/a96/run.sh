#!/usr/bin/env bash
# f74 (2026-11-19, fusion74, a261, T-084 : groupes de collision BotDefender/BotDoor dans BotService) : banc a96 (bot joueur)
# tel quel ($H/a176-banc/autres-bancs/a96/run.sh), avec PhysicsService ajouté à son faux Roblox (f74-banc/ext-physics.luau,
# inséré dans le fichier assemblé juste après `local games = …` par un faux luau.exe posé dans un HOME passager,
# comme a176-banc/corrige.sh, qu'il enchaîne). Sans RegisterCollisionGroup dans BotService : le lanceur d avant.
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ORIG="$H/a176-banc/autres-bancs/a96/run.sh"
EXT="$H/f74-banc/ext-physics.luau"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "RegisterCollisionGroup" "$REPO/src/server/Services/BotService.luau" 2>/dev/null; then
	exec bash "$ORIG" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo 'if grep -q "^local games = { server = makeGame" "$f"; then'
	echo "	sed -i \"/^local games = { server = makeGame/r $EXT\" \"\$f\""
	echo 'else'
	echo '	echo "ERREUR (f74) : repère « local games = » absent, PhysicsService non ajouté"'
	echo 'fi'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$ORIG" "$@"
