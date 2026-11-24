#!/usr/bin/env bash
# Copie d'a46 (2026-11-08, L-086) : le colis se pose sur un présentoir, l'objet reste sur ce présentoir (faux openBox) ; flèches de l'étape 4 et 5 vers le présentoir (A.slot1) au lieu de l'établi, raison « colis en attente ».
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a41-banc/autres-bancs/a28-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a41-banc/autres-bancs/a28-banc/run.sh" "$@"; fi
# Copie d'a41 (2026-11-08, L-071) : à l'étape 6, la flèche vers le tapis porte l'indice StandOnTreadmill (le tapis n'a plus d'invite) → 4 contrôles adaptés, 2 ajoutés (texte affiché, 8 mots).
# Banc hors Studio de a28 (vague 9, DEV-046) : TutorialService (serveur) et TutorialController
# (client), avec les vrais Config, Contract, Net, Format et Types, et des faux services pilotés par
# les scénarios (DataService, PlotService, StoreHeistService, GuardService, UnboxService,
# WindowService, CarryService, DisplayService, NightCycleService, ToolService). Faux Roblox : celui
# d'a25 (copie de stubs.luau et ext.luau), complété dans ext28.luau.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a28 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a28}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau" "$H/ext.luau" "$H/ext28.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
