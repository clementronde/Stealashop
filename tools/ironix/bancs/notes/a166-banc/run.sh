#!/usr/bin/env bash
# Banc a166 (2026-11-15, vague 51, MAJ 1, DEV-101) : coffre hebdomadaire (RewardService.ClaimWeekly, Config/Rewards.Weekly,
# Features.WeeklyChest, RewardsController WeeklyChest). Harnais du banc a53 (copie a150) : faux Roblox, setup51, setup53 ;
# vrais RewardService, RewardsController, DataService, UnboxService.
# Scénario unique : off, quatre, cinq, deux réclamations, semaine suivante, client. « SAUTÉ » sans Rewards.Weekly.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a150-banc/autres-bancs/a53-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "WeeklyChest" "$SRC/shared/Config/Features.luau"; then
	echo "banc a166 (coffre hebdo) : SAUTÉ, pas de Features.WeeklyChest : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau"; then
	cp -r "$SRC" "$TMP/src"; sed -i 's/ShelfOpen = true,/ShelfOpen = false,/' "$TMP/src/shared/Config/Features.luau"; SRC="$TMP/src"
fi
FILES="shared server/Services/RewardService.luau server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RewardsController.luau client/Controllers/UI client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"
OUT="$TMP/run.luau"
{
	cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/ext46.luau" "$B/stub-anticheat.luau" "$B/ext51.luau" "$B/ext53.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/features.luau" "$B/setup51.luau" "$B/setup53.luau" "$H/setup166.luau" "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" | head -20
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "banc a166 (coffre hebdo) : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a166 (coffre hebdo) : $c vérification(s), $f échec(s)"
exit $((f > 0))
