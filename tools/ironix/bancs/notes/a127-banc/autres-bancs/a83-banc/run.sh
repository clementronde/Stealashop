#!/usr/bin/env bash
# Copie a127 (2026-11-14, vague 38, L-137 point 3) : Stage_3/Walls a une copie à part (dossier SkillVisuals) sous le niveau 3 ; B6 compare sans SkillVisuals (copie refaite au retour au niveau 1), B4 accepte la ligne AccentColor déjà écrite au premier passage.
# Banc hors Studio de a83 (2026-11-11, vague 27, L-096 point 1) : la boutique du joueur grandit avec ses
# rayons (ShopStageService, appelé par RayonService avant les rayons) ; panneau des présentoirs sur
# StageUpgradePoint puis StageUpgradePoint_2 (UpgradeController) ; murs Stage_j/Barriers traversables par
# le propriétaire (PlotDoorController). Faux Roblox : celui d'a52 (a52-banc/stubs.luau), plus ext-a83.luau.
# Avant la fusion d'a83 (pas de ShopStageService dans l'arbre) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a83 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a83}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/server/Services/ShopStageService.luau" ]; then
  echo "a83 SAUTÉ : cet arbre n'a pas encore ShopStageService"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau client/Controllers/PlotDoorController.luau"
{
  cat "$H/../../../a52-banc/stubs.luau"
  cat "$H/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
