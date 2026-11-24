#!/usr/bin/env bash
# a224 (vague 67, gain du tapis « +2 » seul et plus gros, Config/Hud.TrainGainFly.Scale) : lance un banc d'avant la vague 67
# qui attend « +2 Speed/s », « +0.4 Speed », « +32 Speed » et la taille d'avant, en remettant dans son fichier assemblé
# les textes d'avant et Scale = 1 (même mécanisme que a213-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné
# sur le luau.exe du HOME d'avant). Le reste du code de la vague 67 est testé tel quel. Arbre sans TrainGainFly.Scale :
# le lanceur d'avant tel quel.
#   bash corrige.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'Scale = 1.5' "$ROOT/src/shared/Config/Hud.luau" 2>/dev/null; then
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
	echo "	perl -i -pe 's/return \`\+\{Format\.short\(amount\)\}\` -- vague 67/return \`+{Format.short(amount)} Speed\/s\` -- vague 67/; s/Text = \"\+%s\", -- vague 67/Text = \"+%s Speed\", -- vague 67/; s/^(\t\tScale = )1\.5,/\${1}1, -- a224-avant ($NAME)/' \"\$f\""
	echo "fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
