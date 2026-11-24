#!/usr/bin/env bash
# Copie a226 (vague 68) : panneau de la Banque « Strength 2M ×2 players », couleur comparée à la force de l équipe (2M seul : orange ; 4M : vert ; 1M et 1,9M : rouge).
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : panneaux StoreReqSign : Speed du panneau (0 à 3B) comparée à la Speed affichée (ShownSpeed), Strength v2.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a94-banc/sign/run.sh" "$@"; fi
# Banc hors Studio d'a94 (2026-11-12, vague 29, L-108 points 2 et 5) : panneaux plantés StoreReqSign devant
# les magasins PNJ (StoreReqSignController, côté client ; règle de pose Shared/SignPose, textes et couleurs
# AdvicePanel), contrat (Contract/Models) et Config des vigiles de nuit (Night.ChaseSpeed, GaitSpeedMax).
# Faux Roblox : celui de la copie a83 du banc a52 (lu sur place). Avant la fusion d'a94 : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
STUBS="$H/../../../a83-banc/autres-bancs/a52-banc/stubs.luau"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
if [ ! -f "$SRC/client/Controllers/StoreReqSignController.luau" ]; then
  echo "a94 SAUTÉ : pas encore de StoreReqSignController"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared client/Controllers/StoreInfoController.luau client/Controllers/StoreReqSignController.luau"
{
  cat "$STUBS"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
