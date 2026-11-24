#!/usr/bin/env bash
# Banc d'essai hors Studio de la vitre qui se creuse (L-081, agent a44, vague 15) : un creux par coup
# (frappeur au marqueur Impact, autres à l'écho WindowHit), un seul calcul FragmentAsync à la fois
# par vitre, plafond de débris (PC et mobile), plus aucune recherche de WIN_Crack_*, régénération,
# remise à neuf à la casse, à la reconstruction et à la sortie du streaming, casse finale inchangée,
# sons trouvés ou absents sans erreur, FragmentAsync en panne.
# Vrais : WindowService, WindowController, ShatterController, HitController, Config, Contract, Anim,
# Format, Net/Definitions, Net/Validate. Bouchons : ToolService, AnimationController, Net (routage
# local avec latence, repris d'a34). Faux Roblox : stubs.luau (copie de celui d'a34, lignée a16),
# complété par ext-carve.luau (GeometryService:FragmentAsync, UserInputService, Reflectance).
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a44 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
# Le fichier assemblé va dans un dossier temporaire (rien n'est écrit à côté de ce script).
set -eu
# Arbre sans le creux (avant la fusion de la vague 15) : banc sauté.
if ! grep -q "Carve = {" "${1:-/f/StealAShop/agents/a44}/src/shared/Config/Shatter.luau" 2>/dev/null; then echo "banc a44 SAUTÉ : pas de Config.Shatter.Carve dans cet arbre (avant la fusion de la vague 15)"; echo "0 vérification(s), 0 échec(s)"; exit 0; fi
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a44}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  cat "$H/ext-carve.luau"
  (cd "$SRC" && {
    find shared -name '*.luau'
    for f in server/Services/WindowService.luau client/Controllers/WindowController.luau \
      client/Controllers/ShatterController.luau client/Controllers/HitController.luau; do
      echo "$f"
    done
  } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
