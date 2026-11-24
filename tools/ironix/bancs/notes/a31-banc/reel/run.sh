#!/usr/bin/env bash
# Banc hors Studio de l'agent a31 (vague 11, liaison L-055 ; MOD-040 côté code) : icônes
# ICON_<ItemId> dans le rouleau de l'ouverture des colis (Unbox/Reel en mode icônes, repli 3D quand
# l'icône manque, préchargement), puis la séquence complète avec Unbox/Screen et Unbox/Sequence
# (silhouettes puis couleurs dans la même image que ReelView, aperçu toujours en 3D, tout remis à
# la fermeture).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a31 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
# Assemble les bouchons (copie de ceux d'a23, complétés par a31), les vraies sources partagées et les
# modules Unbox du client, l'écran UI_Unbox v2 d'a23 (ui.luau) et les scénarios en un seul fichier
# Luau, exécuté par le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a31}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared client/Controllers/Unbox"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/ui.luau"
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
