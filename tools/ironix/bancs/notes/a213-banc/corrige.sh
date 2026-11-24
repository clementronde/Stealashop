#!/usr/bin/env bash
# a213 (vague 64, gains du tapis qui volent jusqu'au compteur Speed, Config/Hud.TrainGainFly) : lance un banc d'avant la
# vague 64 qui attend l'ancien « +X » sur place (BB_Gain, compteur tout de suite) en coupant le vol dans son fichier
# assemblé (TrainGainFly.Enabled = false ; même mécanisme que f57-banc/corrige.sh : faux luau.exe dans un HOME passager,
# enchaîné sur le luau.exe du HOME d'avant, donc sur les correctifs des lanceurs d'avant). Le vol coupé est le chemin
# des animations réduites : le code d'avant tel quel. Arbre sans TrainGainFly : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'TrainGainFly' "$ROOT/src/shared/Config/Hud.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ]; then"
	echo "	perl -0777 -i -pe 's/(TrainGainFly = \{\n\t\tEnabled = )true,/\${1}false, -- a213-vol-coupé ($NAME)/g' \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
