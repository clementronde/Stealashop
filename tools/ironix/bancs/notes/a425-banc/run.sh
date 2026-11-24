#!/usr/bin/env bash
# Banc a425 (lot100, 24/11 : L-318, L-324, L-325) : écart entre le camion et le fourgon blindé (règles pures et horaire
# du vrai ArmoredVanService sur un faux monde), colis tombés (écarts), valeurs de Config/ArmoredVan.
# « SAUTÉ » sans ArmoredVanService.HoldsTruck (avant a425).
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a425 (camion et fourgon blindé)"
if ! grep -q "function ArmoredVanService.HoldsTruck" "$SRC/server/Services/ArmoredVanService.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, 0 vérification(s), 0 échec(s)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
src() { printf 'local %s = [==========[\n' "$1"; tr -d '\r' < "$SRC/$2"; printf '\n]==========]\n'; }
OUT="$TMP/a425.luau"
{
	src AV_SOURCE server/Services/ArmoredVanService.luau
	src AVCFG_SOURCE shared/Config/ArmoredVan.luau
	src TRUCK_SOURCE shared/Config/TruckEvent.luau
	src FREEZE_SOURCE shared/Config/DeepFreeze.luau
	src TRUCKSVC_SOURCE server/Services/TruckEventService.luau
	cat "$H/tests.luau"
} > "$OUT"
out="$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror" || true
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -20
	echo "$NAME : arrêté avant la fin, 0 vérification(s), 1 échec(s)"; exit 1
fi
echo "$NAME : $line"
case "$line" in *", 0 échec(s)") exit 0 ;; *) exit 1 ;; esac
