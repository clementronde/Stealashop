#!/usr/bin/env bash
# Banc hors Studio de a52 (2026-11-09, L-082 point 1) : panneaux d'amélioration plantés UpgradeSign
# (UpgradeController, côté client). Faux Roblox : copie de celui d'a47, complétée (stubs.luau, bloc
# « ajouts a52 »). Avant la fusion d'a52 (UpgradeController sans UpgradeSign) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Copie a83 (2026-11-11, L-096 point 1) : boutique sans StageUpgradePoint (tests.luau, buildPlot et P1).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if ! grep -q "UpgradeSign" "$SRC/client/Controllers/UpgradeController.luau"; then
  echo "a52 SAUTÉ : cet UpgradeController ne pose pas encore les panneaux UpgradeSign"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared client/Controllers/UpgradeController.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
