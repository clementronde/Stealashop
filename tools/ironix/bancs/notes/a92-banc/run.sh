#!/usr/bin/env bash
# Banc hors Studio de l'agent a92 (2026-11-12, vague 29, L-106 point 1 : rareté Divine, #FFE9A8, au-dessus
# de Secret) : Config/Rarities (8 raretés, valeurs V0, chances de tirage à 0 sans objet), Config/Items
# (Divines, AllZones, Pick), Formulas, ShelfBoxes, Index, Unbox, Contract/Models ; puis un catalogue modifié
# (un objet Divine ajouté dans la source) pour vérifier Pick et l'Index le jour où Clément en livre un.
# Faux Roblox : stubs.luau et ext.luau de la copie a53 du banc a22-core, lus sur place.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Sur un arbre sans la rareté Divine dans Config/Rarities : « SAUTÉ » (bon avant et après la fusion).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if ! grep -q '"Divine"' "$SRC/shared/Config/Rarities.luau" 2>/dev/null; then
  echo "a92 : rareté Divine absente de Config/Rarities, banc SAUTÉ"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
BASE="$H/../a53-banc/autres-bancs/a22-core"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$BASE/stubs.luau"
  cat "$BASE/ext.luau"
  (cd "$SRC" && find shared -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  printf 'CONFIG_NAMES = {'
  (cd "$SRC/shared/Config" && ls *.luau | sed 's/\.luau$//' | awk '{ printf "\"%s\", ", $0 }')
  printf '}\n'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
