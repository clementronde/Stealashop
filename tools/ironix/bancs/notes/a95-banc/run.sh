#!/usr/bin/env bash
# Banc hors Studio d'a95 (2026-11-12, vague 29, DEV-034 ; L-106 point 4, L-107 point 2) : le receleur côté serveur.
# Vrais : PawnShopService, InventoryService, PvPService, DisplayService, PlotService, WindowService, CarryService,
# Net, Config, Contract, Format, Types, Loader. Bouchons, faux Roblox et mise en place : ceux du banc a29 (copie
# d'a36 : stubs.luau, ext29.luau, setup.luau), lus sur place. Ajouts : pre95.luau (modules et stand du receleur).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a95 ; après fusion : /f/StealAShop)
# Avant la fusion d'a95 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop/agents/a95}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/PawnShopService.luau" ]; then
	echo "banc a95 SAUTÉ : cet arbre n'a pas encore PawnShopService"
	echo "banc a95 (receleur, serveur) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/InventoryService.luau server/Services/PawnShopService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
OUT="$OUTDIR/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A29/stubs.luau" "$A29/ext29.luau"
	cat "$A29/../stub-anticheat.luau"
	sources
	cat "$A29/setup.luau"
	cat "$H/pre95.luau"
	cat "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -20
	echo "banc a95 (receleur, serveur) : arrêté avant la fin (erreur ci-dessus), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then
	printf '%s\n' "$out"
else
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a95 (receleur, serveur) : $c vérification(s), $f échec(s)"
exit $((f > 0))
