#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : scénarios DEV-019 réécrits pour L-089 : colis rangé dans l'inventaire à l'entrée de la zone safe (SafeZone, couloir), posé au sol de sa boutique (PlotFloor et Bounds ajoutés au faux plot ; PlaceBox(boxUid, point)), invite « Open » sur le FloorBox, OpenBox(boxUid), objet dans l'inventaire ; refus de la pose au sol ; GetOpenDelay ; hors ligne ; inventaire plein ; modèles de Clément ; colis sauvegardés illisibles ; anti-triche au rangement. Faux Roblox complété par ../ext51-old.luau.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a46-banc/autres-bancs/a13-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a46-banc/autres-bancs/a13-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : colis posés sur les présentoirs (DisplaySlot_xx à la place des UnboxBench_xx du faux plot ; faux DisplayService avec GetSlots, GetSlotStates qui garde la règle des anciens établis, PlaceItem, HasRoom), textes de la sortie « présentoir », StandBox_xx.
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a26-banc/a23-banc/autres-bancs/a13-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a26-banc/a23-banc/autres-bancs/a13-banc/run.sh" "$@"; fi
# Copie à jour par a23 (2026-11-07, ouverture des colis v2) du banc hors Studio de a13 (DEV-019 :
# UnboxService, UnboxController). Changements : bouchons d'a23 (Random, Vector2, sons, écrans…),
# modules d'aide d'UnboxController (Controllers/Unbox) montés, chance du joueur à 0 (les scénarios
# DEV-019 ne tirent pas d'amélioration), UnboxReveal à 7 arguments (E5).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a23 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a23}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau" "$H/../ext51-old.luau"
  (cd "$SRC" && find shared server/Services/UnboxService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
