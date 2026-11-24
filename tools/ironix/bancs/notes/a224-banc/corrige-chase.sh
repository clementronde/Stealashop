#!/usr/bin/env bash
# a224 (vague 67, poursuite qui ralentit en arrivant, Config/Chase.ApproachBrake) : lance un banc d'avant la vague 67
# qui attend les temps et distances de la règle d'avant (fin de ruée à 14 ± 0,5 à 15 images/s, capture de nuit vers
# 1,39 s…) avec Chase.ApproachBrake = 0 dans son fichier assemblé (le plafond a224 coupé : la règle d'avant, code
# tel quel ; même mécanisme que corrige.sh). Les nouveaux temps sont mesurés et testés par le banc a224 (still, run).
# Arbre sans ApproachBrake : le lanceur d'avant tel quel.
#   bash corrige-chase.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'ApproachBrake = ' "$ROOT/src/shared/Config/Chase.luau" 2>/dev/null; then
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
	echo "	perl -i -pe 's/^(\tApproachBrake = )[0-9.]+,/\${1}0, -- a224-avant ($NAME)/' \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
