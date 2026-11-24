#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19 : raretés par zone, colis du rayon sans type, revenus par rareté, zone et rang) : lance un banc
# d'avant la vague 76 en corrigeant à la volée son fichier assemblé (même mécanisme que a203-banc/corrige.sh : faux
# luau.exe dans un faux HOME). Correction commune (patch.pl) : un colis du rayon n'a plus d'attribut Tier, chaque
# GetAttribute("Tier") lu par le banc rend le type d'avant au même temps de prise (Commun, Peu commun : Standard 0,3 s ;
# Rare, Épique : Premium 0,6 s ; au-dessus : Luxe 1 s), d'après BoxRarity ; puis patches/<nom>.pl s'il existe (valeurs
# attendues de la vague 76). Arbre sans la vague 76 (pas de Rarities.GrabTime) : le banc tel quel.
#   bash corrige.sh <nom> <lanceur du banc> <racine du dépôt> [arguments…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
SCRIPT="$2"
shift 2
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "GrabTime = function" "$ROOT/src/shared/Config/Rarities.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "if [ -f \"\$f\" ] && ! A262_ROOT=\"$ROOT\" perl \"$H/patch.pl\" \"$H/patches/$NAME.pl\" \"\$f\"; then echo \"ÉCHEC a262 : correctif du banc $NAME pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; fi"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$SCRIPT" "$@"
