#!/usr/bin/env bash
# f70c1, partie « hotbar » : harnais du banc a74 (copie a142 : faux Roblox et mise en place des bancs a51, a53, a61,
# a74 et a76, lus sur place), vrai HotbarController + Controllers/UI/HudMask, scénario tests.hotbar.luau.
# Lancé par hotbar.sh à travers a158-banc/corrige.sh (colis porté retiré).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
A74="$N/a142-banc/autres-bancs/a74-banc"
A61="$N/a62-banc/autres-bancs/a61-banc"
A76="$N/a76-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.hotbar.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$H/tests.hotbar.luau"
} > "$OUT"
"$LUAU" "$(cygpath -w "$OUT")" 2>&1
