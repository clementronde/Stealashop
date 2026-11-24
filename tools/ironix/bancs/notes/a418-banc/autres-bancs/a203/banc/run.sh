#!/usr/bin/env bash
# fusion66 : copie du banc a203 qui réunit a231 (migration : Tiny et Big retirées de la mutation, a231-banc/autres-bancs/a203) et a234 (courbe poids → taille, a234-banc/autres-bancs/a203) ; tests.luau = celui d a234 + le bloc de migration d a231, chacun gardé derrière sa condition.
# a234 (vague 71) : copie du banc a220/a203, courbe poids → taille par points (Weight.ScaleCurve) ; sans ScaleCurve : les contrôles d avant.
# a220 (vague 66) : copie du banc a203, objet porté à la taille de son poids (Weight.CarryMaxScale, CarryService.scaleVisual) ; sans Weight.CarryFade : le contrôle d avant.
# Banc hors Studio d'a203 (vague 62, décision de Cantin et Clément, liaison L-198 : le poids des objets).
#   Loi du poids (Config/Weight, Shared/ItemWeight) : 100 000 tirages à ×1, ×4 et ×8, paliers, extrêmes ; taille et
#   revenu à 1, 10, 1 000 et 10 000 kg ; seuils Huge et Colossal ; SizeClassFor ; migration d'un ancien profil sans
#   perte de revenu (idempotente) ; Config/Mutations avec et sans Features.SingleBoxReveal ; plafonds du présentoir,
#   de l'objet tenu et du socle ; RollForSize (Fortune Tower 80/20 gardé) ; ItemOdds ; InventoryState (9e champ) ;
#   Format ; constantes du client (AnimationController) et plafonds posés (HeldItemService, VfxController).
#   Vraies sources de src/shared, faux `script` et `require` (comme tools/ironix/equilibrage/chargeur.luau).
# Arbre sans Shared/ItemWeight (avant a203) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/shared/ItemWeight.luau" ]; then
	echo "banc a203 (poids des objets) : SAUTÉ, a203 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.assemble.luau"
emit() { # emit <clé> <fichier>
	awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
	echo "--!nocheck"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for f in "$SRC"/shared/Config/*.luau; do
		emit "Config/$(basename "$f" .luau)" "$f"
	done
	for m in ItemWeight Format ItemOdds InventoryState; do
		emit "$m" "$SRC/shared/$m.luau"
	done
	emit "Text/AnimationController" "$SRC/client/Controllers/AnimationController.luau"
	emit "Text/HeldItemService" "$SRC/server/Services/HeldItemService.luau"
	emit "Text/VfxController" "$SRC/client/Controllers/VfxController.luau"
	emit "Text/DisplayService" "$SRC/server/Services/DisplayService.luau"
	emit "Text/DataService" "$SRC/server/Services/DataService.luau"
	emit "Text/CarryService" "$SRC/server/Services/CarryService.luau"
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|^banc a203" || true; fi
if ! printf '%s\n' "$out" | grep -qE "^banc a203 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"; then
	printf '%s\n' "$out" | tail -15
	echo "banc a203 (poids des objets) : arrêté avant la fin : 1 vérification(s), 1 échec(s)"
	exit 1
fi
