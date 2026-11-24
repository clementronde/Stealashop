#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : le colis porté entre dans l'inventaire dans la zone safe (Part taggée SafeZone), puis se pose au sol de la boutique (PlotFloor et Bounds ajoutés au faux plot ; PlaceBox(boxUid, point) devant l'établi n) et s'ouvre par OpenBox(boxUid) ; invite « Open » et copie du colis sur le FloorBox ; UnboxReveal(boxUid, …) ; l'objet va dans l'inventaire (section K : plus de message, sauf inventaire plein → présentoir) ; faux Roblox d'a13 complété par ../ext51-old.luau.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a46-banc/autres-bancs/a23-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a46-banc/autres-bancs/a23-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : colis posés sur les présentoirs (DisplaySlot_xx à la place des UnboxBench_xx du faux plot), faux DisplayService avec GetSlots, GetSlotStates, PlaceItem, HasRoom ; textes de la sortie « présentoir », StandBox_xx, Reveal.SlotIndex.
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a26-banc/a23-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a26-banc/a23-banc/run.sh" "$@"; fi
# Banc d'essai hors Studio de a23 (DEV-050, DEV-052 : ouverture des colis v2).
# Assemble le faux Roblox (celui de a13, complété par a23), les vraies sources partagées (Config,
# Contract, Net, Types, Format, Anim), UnboxService, UnboxController et ses modules d'aide
# (Controllers/Unbox), puis les scénarios, en un seul fichier Luau exécuté par le luau de rokit.
# DataService, PlotService, CarryService, DisplayService et AnimationController y sont des
# bouchons. Config/Items est remplacé par un faux catalogue v2 (items-v2.luau, forme de l'API
# d'a22) ; si le vrai Config/Items est déjà en v2 (Items.Pick), la section J le contrôle aussi.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a23 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a23}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/UnboxService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau" "$H/../ext51-old.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  # Le vrai catalogue est gardé à part (section J) ; le faux v2 prend sa place.
  printf 'REAL_ITEMS_SOURCE = SOURCES["shared/Config/Items.luau"]\n'
  printf 'SOURCES["shared/Config/Items.luau"] = [==========[\n'
  tr -d '\r' < "$H/items-v2.luau"
  printf '\n]==========]\n'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
