#!/usr/bin/env bash
# Banc hors Studio a307 (2026-11-22, L-285) : fond minimum Config/ShopGrowth.MinBack appliqué par ShopStageService
# (fond = max(fond calculé, MinBack), StageDepth compris). Deux passes : l'arbre tel quel (MinBack = 8) et une
# copie à MinBack = nil (ancien comportement). Harnais et faux Roblox du banc rowcut (a179, a83, a52).
# Avant a307 (pas de MinBack dans ShopGrowth) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a307)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a307}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"
if [ ! -f "$SRC/shared/Config/ShopGrowth.luau" ] || ! grep -q "MinBack" "$SRC/shared/Config/ShopGrowth.luau"; then
  echo "a307 SAUTÉ : cet arbre n'a pas encore ShopGrowth.MinBack"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
MIN="$(grep -oE '^[[:space:]]*MinBack = [-0-9.]+' "$SRC/shared/Config/ShopGrowth.luau" | grep -oE '[-0-9.]+$')"
NIL="$R1_D/nil"
mkdir -p "$NIL"
cp -r "$SRC" "$NIL/src"
perl -pi -e 's/^(\s*)MinBack = [-0-9.]+ :: number\?,/${1}MinBack = nil :: number?,/' "$NIL/src/shared/Config/ShopGrowth.luau"
grep -q "MinBack = nil" "$NIL/src/shared/Config/ShopGrowth.luau" || { echo "a307 : copie à MinBack = nil ratée : 0 vérification(s), 1 échec(s)"; exit 1; }
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau"
pass() { # $1 = racine src, $2 = valeur attendue, $3 = nom
  local out="$R1_D/run.$3.luau"
  {
    echo "EXPECT_MIN_BACK = $2"
    cat "$H/../a52-banc/stubs.luau"
    cat "$H/../a127-banc/autres-bancs/a83-banc/ext-a83.luau"
    (cd "$1" && find $FILES -name '*.luau' | sort) | awk -v root="$1" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    cat "$H/tests.luau"
  } > "$out"
  echo "== passe $3 (MinBack = $2)"
  "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$out")"
}
st=0
pass "$SRC" "$MIN" minback || st=1
pass "$NIL/src" nil sans || st=1
exit $st
