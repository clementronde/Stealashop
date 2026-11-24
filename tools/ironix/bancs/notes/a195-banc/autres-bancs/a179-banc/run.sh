#!/usr/bin/env bash
# Copie a195 (2026-11-15, vague 60, T-086 : un présentoir à la fois) du banc a179. Seuls changent les contrôles des
# socles : un socle et sa plaque sont cachés au-delà du fond OU au-dessus des présentoirs débloqués (G1), et à 11
# présentoirs le 12 est caché (G2). Sur un arbre sans Config/ShopGrowth.HideLockedStands : le banc a179 d'origine.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a195}"
SRC="$ROOT/src"
if ! grep -q "HideLockedStands" "$SRC/shared/Config/ShopGrowth.luau" 2>/dev/null; then
  exec bash "$H/../../../a179-banc/run.sh" "$ROOT"
fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
B="$H/../../.."
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau"
{
  cat "$B/a52-banc/stubs.luau"
  cat "$B/a127-banc/autres-bancs/a83-banc/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
