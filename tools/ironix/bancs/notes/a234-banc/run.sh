#!/usr/bin/env bash
# Banc hors Studio d'a234 (vague 71 ; L-216 point 2, L-217, L-219 point 6, L-220) : courbe poids → taille par points
# (Config/Weight.ScaleCurve, ScaleAt ; Shared/ItemWeight.ScaleFor), plafonds (porté, présentoir, socle), casse du rayon
# et classe de taille avec la nouvelle courbe, réduction FitSize des présentoirs (DisplayService : fitSizeOf, fitFactor,
# trimLights extraits et lancés sur un faux modèle), vraie taille du socle (VfxController, attribut FitScale), contrat.
# Arbre sans Weight.ScaleCurve (avant a234) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "ScaleCurve" "$SRC/shared/Config/Weight.luau" 2>/dev/null; then
	echo "banc a234 (taille selon le poids, FitSize) : SAUTÉ, a234 pas encore fusionné : 0 vérification(s), 0 échec(s)"
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
	emit "ItemWeight" "$SRC/shared/ItemWeight.luau"
	emit "Contract/Attributes" "$SRC/shared/Contract/Attributes.luau"
	emit "Text/DisplayService" "$SRC/server/Services/DisplayService.luau"
	emit "Text/VfxController" "$SRC/client/Controllers/VfxController.luau"
	emit "Text/StoreHeistService" "$SRC/server/Services/StoreHeistService.luau"
	emit "Text/RevealController" "$SRC/client/Controllers/RevealController.luau"
	tr -d '\r' < "$H/tests.a234.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|^banc a234|^  taille" || true; fi
if ! printf '%s\n' "$out" | grep -qE "^banc a234 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"; then
	printf '%s\n' "$out" | tail -15
	echo "banc a234 (taille selon le poids, FitSize) : arrêté avant la fin : 1 vérification(s), 1 échec(s)"
	exit 1
fi
printf '%s\n' "$out" | grep -qE "^banc a234 .*: [0-9]+ vérification\(s\), 0 échec\(s\)$"
