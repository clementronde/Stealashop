#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : section G : le colis rentre dans l'inventaire (zone safe), se pose au sol 8 studs devant l'établi (PlotFloor, Bounds, SafeZone ajoutés au faux plot) et s'ouvre par l'invite « Open » du FloorBox ; sans copie du colis, la fenêtre se place au-dessus du dernier point connu du colis ; Reveal.BoxUid ; faux Roblox complété par ../ext51-old.luau.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a46-banc/autres-bancs/a43-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a46-banc/autres-bancs/a43-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : colis posés sur les présentoirs (DisplaySlot_xx à la place des UnboxBench_xx du faux plot, StandBox_xx, Reveal.SlotIndex ; faux DisplayService avec GetSlots, GetSlotStates, PlaceItem, HasRoom).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a43-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a43-banc/run.sh" "$@"; fi
# Banc d'essai hors Studio de a43 (L-080 : le rouleau tourne au-dessus du colis).
# Même montage que le banc d'a23 (version a26) : faux Roblox (stubs.luau, copie a43 : projection
# réglable, BindToRenderStep, Enum.RenderPriority), vraies sources partagées, UnboxService,
# UnboxController et ses modules d'aide (Controllers/Unbox), faux catalogue v2 (items-v2.luau),
# prélude d'a23 (prelude.luau : bouchons des services voisins, montage, aides), puis les scénarios
# d'a43 (tests.luau).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a43 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a43}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/UnboxService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"
# Arbre d'avant la fusion de L-080 (un autre agent lance run-all-bancs.sh sur son worktree) : rien
# à tester, on le dit et on passe.
if ! grep -q "ReelEdge" "$SRC/shared/Config/Unbox.luau" 2>/dev/null; then
  echo "banc a43 (rouleau au-dessus du colis) : SAUTÉ, pas de ReelEdge dans Config/Unbox de $SRC (L-080 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
  exit 0
fi
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau" "$H/../ext51-old.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  printf 'REAL_ITEMS_SOURCE = SOURCES["shared/Config/Items.luau"]\n'
  printf 'SOURCES["shared/Config/Items.luau"] = [==========[\n'
  tr -d '\r' < "$H/items-v2.luau"
  printf '\n]==========]\n'
  cat "$H/prelude.luau"
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
