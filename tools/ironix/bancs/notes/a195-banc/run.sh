#!/usr/bin/env bash
# Banc hors Studio d'a195 (2026-11-15, vague 60, T-086 : un présentoir à la fois). Préambule (arbre, gabarit,
# boutiques) repris de la copie a195 du banc a179 (lignes 1 à 319), puis tests.luau ; deux passes : interrupteur
# Config/ShopGrowth.HideLockedStands à true, puis à false (ancien rendu). Faux Roblox : celui d'a52 + ext-a83.
# Avant la fusion d'a195 (pas de HideLockedStands dans l'arbre) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a195 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a195}"
SRC="$ROOT/src"
B="$H/.."
if ! grep -q "HideLockedStands = true" "$SRC/shared/Config/ShopGrowth.luau" 2>/dev/null; then
  echo "a195 SAUTÉ : cet arbre n'a pas encore Config/ShopGrowth.HideLockedStands"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau"
for pass in on off; do
  : "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run-$pass.luau"
  {
    if [ "$pass" = off ]; then echo "FLAG_OFF = true"; fi
    cat "$B/a52-banc/stubs.luau"
    cat "$B/a127-banc/autres-bancs/a83-banc/ext-a83.luau"
    (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" -v pass="$pass" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); if (pass == "off" && f == "shared/Config/ShopGrowth.luau") gsub(/HideLockedStands = true/, "HideLockedStands = false", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    head -n 319 "$H/autres-bancs/a179-banc/tests.luau"
    cat "$H/tests.luau"
  } > "$OUT"
  echo "== passe $pass"
  "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
done
