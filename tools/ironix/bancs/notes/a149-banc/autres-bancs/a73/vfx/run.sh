#!/usr/bin/env bash
# Copie a149 (vague 42) : scénarios d'a20 pris dans la copie a149, tests.vfx.luau lu dans la copie a134.
# Banc hors Studio d'a73 (2026-11-11, vague 24, retour de Cantin : VISUAL EFFECTS sur OFF change trop peu).
# Reprend tel quel le banc a20 (copie d'a37 : faux Roblox, vrais CosmeticService et CosmeticController) et
# ajoute, juste avant son summary(), tests.vfx.luau : à OFF, auras à débit nul et leur lumière, trails,
# halos de rareté (HaloPoint de CarryService, RarityHalo de DisplayService) éteints ; contour Highlight et
# autres émetteurs gardés ; remis à leur état d'origine à ON. « SAUTÉ » sur un arbre sans CutCount.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A20="$H/../../a20" # copie a149 (a149-banc/autres-bancs/a20)
A20_OLD="$H/../../../../a37-banc/autres-bancs/a20-banc"
ROOT="${1:-/f/StealAShop/agents/a73}"
SRC="$ROOT/src"
if ! grep -q "CutCount" "$SRC/client/Controllers/CosmeticController.luau" 2>/dev/null; then
	echo "banc a73-vfx : SAUTÉ, pas de CosmeticController.CutCount (a73 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap "rm -rf \"$TMP\"" EXIT; [ -n "${KEEP:-}" ] && trap - EXIT
OUT="$TMP/run.luau"
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
{
  cat "$A20/stubs-a15.luau" "$A20/ext.luau" "$A20_OLD/../../ext-motion.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  awk -v extra="$H/../../../../a134-banc/autres-bancs/a73/vfx/tests.vfx.luau" '$0 == "summary()" { while ((getline l < extra) > 0) print l; close(extra) } { print }' "$A20/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$HOME/.rokit/bin/luau.exe" "$W" 2>&1) || true
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -30; fi
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "banc a73-vfx : arrêté avant la fin : 0 vérification(s), 1 échec(s)"; exit 1; fi
echo "banc a73-vfx (VISUAL EFFECTS OFF) : $line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
