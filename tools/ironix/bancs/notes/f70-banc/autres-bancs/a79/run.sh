#!/usr/bin/env bash
# fusion70 (vague 73) : banc a79 par son lanceur d'avant (a203-banc/autres-bancs/a79), en corrigeant à la volée le fichier
# assemblé (faux luau.exe dans un HOME passager, enchaîné sur celui d'avant, comme a256-banc/corrige.sh) avec
# f70-banc/a79-announce.sed : le faux arbre du scénario shelf monte Shared/Announce et Config/Announce d'a254, que
# StoreHeistService requiert. Arbre sans Shared/Announce : le lanceur d'avant tel quel.
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
PREV="$H/a203-banc/autres-bancs/a79/run.sh"
if [ ! -f "$ROOT/src/shared/Announce.luau" ]; then
	exec bash "$PREV" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ]; then sed -E -i -f \"$H/f70-banc/a79-announce.sed\" \"\$f\"; fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$PREV" "$@"
