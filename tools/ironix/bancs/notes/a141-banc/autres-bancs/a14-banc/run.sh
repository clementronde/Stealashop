#!/usr/bin/env bash
# Copie a141 (2026-11-14, L-142 : halos exposés moins lumineux) : trois tests suivent les valeurs de Clément (Rare : lumière 0,5 et Rate 4 ; Peu commun : Rate 1,5). Sur un arbre sans a141, relance la copie a129 : bonne avant et après la fusion.
if ! grep -q "SPARKLE_EMISSION" "${1:-/f/StealAShop}/src/shared/RarityHalo.luau" 2>/dev/null; then exec bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a129-banc/autres-bancs/a14-banc/run.sh" "$@"; fi
# Copie d'a129 (vague 39, 2026-11-14, optimisation téléphone des halos) : seul le faux Camera change (FieldOfView et
# ViewportSize, lus par DisplayController), les tests sont ceux de la copie d'a91 ; bonne avant et après la fusion.
# Copie d'a91 (vague 29, 2026-11-12, L-106 point 12 et L-107 point 1) : délai d'1 s par plaque (PAD_COOLDOWN), AmountGui caché à $0,
# BillboardGui ou SurfaceGui. Sur un arbre sans PAD_COOLDOWN dans DisplayService, relance la copie d'a72 : bonne avant et après la fusion.
if ! grep -q "PAD_COOLDOWN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a72-banc/autres-bancs/a14-banc/run.sh" "$@"; fi
# Copie d'a72 (vague 24, 2026-11-11, retour de Cantin : ramassage répété sur une plaque) : section 3, Touched compté
# seulement près de la plaque, un seul ramassage par arrivée (marche, saut, Touched répétés), reramassage après
# vraie sortie. Sur un arbre sans PAD_EXIT_MARGIN dans DisplayService, relance la copie d'a59 : bonne avant et après la fusion.
if ! grep -q "PAD_EXIT_MARGIN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a59-banc/autres-bancs/a14-banc/run.sh" "$@"; fi
# Banc d'essai hors Studio de DisplayService et DisplayController (DEV-020, agent a14) ; copie d'a59 (2026-11-10, L-091 :
# plus de CashPad, plaques CollectPad_xx, montant sur la plaque, CashCollect, gerbe) de la copie adaptée
# par a22 au catalogue v2 (objets retirés remplacés, noms anglais, ModelStreamingMode dans le faux Roblox).
# Assemble les bouchons, les sources du dépôt et les scénarios en un seul fichier Luau, puis l'exécute.
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a14 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
# a59 : sur un arbre d'avant a59 (CollectPad_xx absent de Contract/Models), relance la copie d'a22 : bonne avant et après la fusion.
if ! grep -q "CollectPad_%02d" "${1:-/f/StealAShop}/src/shared/Contract/Models.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a22-banc/autres-bancs/a14-banc/run.sh" "$@"; fi
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a22}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services/DisplayService.luau client/Controllers/DisplayController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
