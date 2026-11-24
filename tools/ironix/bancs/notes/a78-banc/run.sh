#!/usr/bin/env bash
# Banc hors Studio d'a78 (2026-11-11, vague 26, L-097 point 1) : auras et trails = modèles FX_Aura_<Nom> / FX_Trail_<Nom>
# de Clément copiés sur les pièces du perso (Attachments, CFrame relatif, Beams et Trails reliés aux copies),
# retirés au changement, au retrait et à la mort ; repli par texture sans modèle ; VISUAL EFFECTS OFF.
# Reprend le banc a20 (copie d'a37, comme a73-vfx) et ajoute tests.a78.luau avant son summary().
# « SAUTÉ » sur un arbre sans FX_ATTRIBUTE dans CosmeticController.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A20="$H/../a37-banc/autres-bancs/a20-banc"
ROOT="${1:-/f/StealAShop/agents/a78}"
SRC="$ROOT/src"
if ! grep -q "FX_ATTRIBUTE" "$SRC/client/Controllers/CosmeticController.luau" 2>/dev/null; then
	echo "banc a78 : SAUTÉ, pas de FX_ATTRIBUTE dans CosmeticController (a78 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap "rm -rf \"$TMP\"" EXIT; [ -n "${KEEP:-}" ] && trap - EXIT
OUT="$TMP/run.luau"
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
{
  cat "$A20/stubs-a15.luau" "$A20/ext.luau" "$A20/../../ext-motion.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  awk -v extra="$H/tests.a78.luau" '$0 == "summary()" { while ((getline l < extra) > 0) print l; close(extra) } { print }' "$A20/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$HOME/.rokit/bin/luau.exe" "$W" 2>&1) || true
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -30; fi
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "banc a78 : arrêté avant la fin : 0 vérification(s), 1 échec(s)"; exit 1; fi
echo "banc a78 (effets FX_ de Clément sur le perso) : $line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
