#!/usr/bin/env bash
# Copie d'a121 (vague 36, 2026-11-13, L-085 point 4) du banc a28 (copie active : a59-banc/autres-bancs/a28-banc) : 13 étapes et
# 13 étapes de funnel (vol sur la boutique du bot à la fin) ; étape hors bornes (42) ramenée à 13. Rien d'autre ne change.
# Sur un arbre sans BotShopRadius dans Config/Tutorial (avant a121), relance la copie d'a59 : bonne avant et après la fusion.
if ! grep -q "BotShopRadius" "${1:-/f/StealAShop}/src/shared/Config/Tutorial.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a59-banc/autres-bancs/a28-banc/run.sh" "$@"; fi
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
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
