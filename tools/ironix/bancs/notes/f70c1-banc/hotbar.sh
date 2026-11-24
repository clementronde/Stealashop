#!/usr/bin/env bash
# f70c1, partie « hotbar » (correctif f70, B2 : HotbarController ne rallume plus UI_Hotbar masquée par HudMask).
# Arbre sans HudMask.IsMasked (avant f70c1) : « SAUTÉ ».   bash hotbar.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "function HudMask.IsMasked" "$ROOT/src/client/Controllers/UI/HudMask.luau" 2>/dev/null && [ "${FORCE:-}" != "1" ]; then
	echo "f70c1 hotbar : SAUTÉ, pas de HudMask.IsMasked : 0 vérification(s), 0 échec(s)"
	exit 0
fi
out=$(bash "$N/a158-banc/corrige.sh" f70c1 bash "$H/hotbar-run.sh" "$ROOT" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "f70c1 hotbar : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s\n' "$line" | grep -qE ", 0 échec\(s\)$"
