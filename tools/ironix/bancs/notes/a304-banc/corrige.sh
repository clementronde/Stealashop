#!/usr/bin/env bash
# a304 (cases à l'échelle 0 dès l'ouverture, pop sans attente : UiMotion.OpenStagger et Appear.Cascade From = 0,
# Start = 0) : lance un banc d'avant en corrigeant à la volée son fichier assemblé (même mécanisme que a299-banc/corrige.sh :
# faux luau.exe dans un HOME passager, enchaîné sur celui d'avant) avec patches/ancien-pop.sed : la Config/UiMotion du
# fichier assemblé reprend From = 0,2 et Start = 0,23 s. Les bancs a212 et a216 lisent en dur ces valeurs (cartes qui
# attendent à 0,2, entrée à +230 ms) : ils prouvent que le mécanisme de cascade est inchangé ; le banc a304 vérifie le
# pop immédiat.
# Repli : arbre sans le pop immédiat d'a304 dans Config/UiMotion : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'From = 0, -- validé par Cantin, 21/11 (a304)' "$ROOT/src/shared/Config/UiMotion.luau" 2>/dev/null; then
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
	echo "	sed -E -i -f \"$H/patches/ancien-pop.sed\" \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
