#!/usr/bin/env bash
# Grand chef (2026-11-15) : arbre sans a172 (clé ShelfOpen encore dans Config/Features) : « SAUTÉ », comme les autres bancs avant leur fusion.
_A172_R="${1:-/f/StealAShop}"; _A172_R="${_A172_R%/src}"
if grep -qE "^[[:space:]]*ShelfOpen[[:space:]]*=" "$_A172_R/src/shared/Config/Features.luau" 2>/dev/null; then echo "banc a172 (Features.ShelfOpen retiré, reprise en zone safe) : SAUTÉ, a172 pas encore fusionné : 0 vérification(s), 0 échec(s)"; exit 0; fi
# Banc hors Studio d'a172 (2026-11-15, vague 53, lot E) :
#   code   aucun fichier de src/ ne lit plus ShelfOpen de Features (lignes de code, commentaires exclus), et
#          Config/Features n'a plus de clé ShelfOpen ;
#   safe   (tests.safe.luau, mise en place du banc a114 : a66-banc/autres-bancs/a30-banc et a114-banc/autres-bancs/
#          a103-banc/head.luau) un objet lié repris en zone safe ne relance aucune poursuite (GuardService.retarget et
#          onLinkedPickup, point d'a157) ; contrôle : hors zone safe, la reprise relance la poursuite.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok et sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a172 (Features.ShelfOpen retiré, reprise en zone safe)"
total=0; failed=0
# 1. code
c=0; f=0
hits=$(grep -rnE "Features\s*\.\s*ShelfOpen|Features\s*\[\s*\"ShelfOpen\"\s*\]" "$SRC" --include=*.luau | tr -d '\r' | grep -vE "^[^:]+:[0-9]+:\s*--" || true)
c=$((c + 1)); if [ -n "$hits" ]; then f=$((f + 1)); echo "  ÉCHEC C1 lecture de Features.ShelfOpen dans src/ :"; printf '%s\n' "$hits" | head -10 | sed 's/^/    /'; fi
c=$((c + 1)); if grep -qE "^\s*ShelfOpen\s*=" "$SRC/shared/Config/Features.luau"; then f=$((f + 1)); echo "  ÉCHEC C2 clé ShelfOpen encore dans Config/Features"; fi
alias_hits=$(grep -rnE "(SHELF_OPEN|BOX_LABEL_RARITY_ONLY)\b" "$SRC" --include=*.luau | tr -d '\r' | grep -vE "^[^:]+:[0-9]+:\s*--" || true)
c=$((c + 1)); if [ -n "$alias_hits" ]; then f=$((f + 1)); echo "  ÉCHEC C3 copie locale de l'interrupteur (SHELF_OPEN, BOX_LABEL_RARITY_ONLY) :"; printf '%s\n' "$alias_hits" | head -10 | sed 's/^/    /'; fi
echo "  code : $c contrôles, $f raté(s)"
total=$((total + c)); failed=$((failed + f))
# 2. safe
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"
A134="$H/../a134-banc"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.safe.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$BASE/stubs.luau"
	cat "$BASE/../stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A134/levier-force.luau"
	cat "$A134/coups-en-rafale.luau"
	cat "$BASE/setup.luau"
	cat "$HEAD"
	cat "$H/tests.safe.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "  safe : arrêté avant la fin (erreur ci-dessus)"
	failed=$((failed + 1))
else
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  safe : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
fi
echo "$LABEL : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
