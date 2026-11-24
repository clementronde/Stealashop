#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : profil v7 (colis rangés par uid dans l'inventaire, plus de BoxQueue) → version attendue v7 quand l'arbre a InventoryService ; les 6 colis du profil v1 retrouvés par leur ItemId.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a48-banc/autres-bancs/a22-core) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a48-banc/autres-bancs/a22-core/run.sh" "$@"; fi
# Copie d'a48 (2026-11-08, DEV-102) : profil v6 (Offline, gains hors ligne) → version attendue v6 quand Types/Profile a « Offline: Offline ».
# a48 : sur un arbre sans Offline dans Types/Profile, relance la copie précédente (a46-banc/autres-bancs/a22-core) : bonne avant et après la fusion.
if ! grep -q "Offline: Offline" "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a46-banc/autres-bancs/a22-core/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : version attendue v5 quand Types/Profile a BoxQueue (colis sur les présentoirs).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a40-banc/autres-bancs/a22-core) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a40-banc/autres-bancs/a22-core/run.sh" "$@"; fi
# Copie d'a40 (DEV-111, 2026-11-08) : schéma de sauvegarde v4 (index des objets) quand l'arbre testé a Config/Index : version attendue v4,
# et la ligne de migration v4 (objets déjà possédés découverts) vérifiée, avec le contenu de l'Index du profil v1.
# Copie d'a38 (DEV-100, 2026-11-08) : schéma de sauvegarde v3 (boutique Robux). La version attendue suit l'arbre testé
# (v3 avec Config/Monetization, sinon v2 : main d'avant la fusion d'a38) ; le profil « plus récent » est V + 1 ;
# en v3, la migration de Purchases (true → 0) est vérifiée en plus.
# Banc hors Studio de l'agent a22 (catalogue d'objets v2, L-045 ; DEV-020) : Config/Items comparé
# au JSON source, Items.Pick, Tutorial, anciens ItemId, contrat (Models, Attributes, ContractChecker
# sur une fausse place), migration v1 → v2 (vrai DataService, faux ProfileStore), ItemIdleController.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a22 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
# Assemble le faux Roblox (celui d'a14, complété), le lecteur JSON, le JSON du catalogue, les vraies
# sources et les scénarios en un seul fichier Luau, exécuté par le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a22}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/DataService.luau server/Services/ContractChecker.luau client/Controllers/ItemIdleController.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  cat "$H/ext.luau"
  cat "$H/json.luau"
  printf 'JSON_TEXT = [==========[\n'
  tr -d '\r' < "$ROOT/docs/claude/notes/objets-catalogue-v2.json"
  printf '\n]==========]\n'
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
