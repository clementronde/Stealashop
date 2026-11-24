#!/usr/bin/env bash
# Banc hors Studio d'a276 (vague GC2, 23/11, faille F1 de l'audit a272) : budget « modèles » partagé par plusieurs
# remotes dans Net (champ Budget de Net/Definitions, table Definitions.Budgets). Charge les vrais Net, Definitions,
# RateLimiter et Validate dans un faux Roblox minimal (stubs.luau), horloge os.clock simulée.
# Arbre sans Definitions.Budgets : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if ! grep -q "Budgets = Budgets" "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "banc a276 (budget « modèles » de Net) : SAUTÉ, pas de Definitions.Budgets : 0 vérification(s), 0 échec(s)"
	exit 0
fi
D="$(mktemp -d)"
trap 'rm -rf "$D"' EXIT
OUT="$D/a276.luau"
{
	cat "$H/stubs.luau"
	for m in Net Definitions RateLimiter Validate; do
		awk -v key="$m" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$SRC/shared/Net/$m.luau"
	done
	cat "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|vérification\(s\)"; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
