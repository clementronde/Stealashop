#!/usr/bin/env bash
# a266 (vague 80) : lance un banc d'avant en corrigeant à la volée son fichier assemblé (même mécanisme que
# a258-banc/corrige.sh : faux luau.exe dans un HOME passager) avec patches/<nom>.pl : listes et comptes que la vague 80
# allonge (remotes ClaimQuest, SpinWheel, WheelResult après ItemSecured ; UI_Quests dans Config/UiMotion.Windows).
# Repli : arbre sans QuestService (avant la fusion d'a266) : le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/server/Services/QuestService.luau" ] || [ ! -f "$H/patches/$NAME.pl" ]; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ]; then perl -0pi \"$H/patches/$NAME.pl\" \"\$f\"; fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
