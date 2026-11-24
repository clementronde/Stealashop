#!/usr/bin/env bash
# Banc hors Studio de rowcut (2026-11-15, L-190) : gabarit PLOT_Shop découpé par Clément aux plans des fonds ;
# avec l'attribut RowCut = true, ShopStageService garde ou retire chaque pièce sans la raccourcir ; sans lui,
# la coupe d'a179 reste (R1). Harnais et faux Roblox d'a179. Avant la modification (pas de RowCutAttribute
# dans Config/ShopGrowth) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree rowcut)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/rowcut}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/shared/Config/ShopGrowth.luau" ] || ! grep -q "RowCutAttribute" "$SRC/shared/Config/ShopGrowth.luau"; then
  echo "rowcut SAUTÉ : cet arbre n'a pas encore ShopGrowth.RowCutAttribute"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau"
{
  cat "$H/../a52-banc/stubs.luau"
  cat "$H/../a127-banc/autres-bancs/a83-banc/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
