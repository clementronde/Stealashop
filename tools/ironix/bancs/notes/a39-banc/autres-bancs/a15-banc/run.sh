#!/usr/bin/env bash
# Copie d'a39 (2026-11-08, L-071) : les boutons Shop, Index et Rebirth du HUD sont visibles dès maintenant (Features.RobuxShopPreview, Index, RebirthPreview) → leur visibilité attendue se lit dans Config/Features (cachés sur un arbre d'avant L-071, visibles après : le banc passe sur les deux) ; ext-motion.luau d'a37 rangé dans ../ (autres-bancs).
# Copie d'a37 (2026-11-08, DEV-052) : le contrôleur testé requiert Controllers/UI/Motion (TweenService) → module UI/Motion ajouté à l'arbre et faux Roblox complété par ../../ext-motion.luau (UIScale, NumberValue, TweenService ; tweens instantanés : vérifications d'origine inchangées).
# Copie à jour par a23 (2026-11-07, ouverture des colis v2) du banc hors Studio de a15 (DEV-021 : HUD, écran de révélation, attributs Cash et Damage).
# Assemble le faux Roblox (celui de a13, complété : écrans, boutons, sons), les vraies sources
# partagées (Config, Contract, Net, Types, Format, Anim) et les fichiers testés, puis les scénarios,
# en un seul fichier Luau exécuté par le luau de rokit. ProfileStore et AnimationController y sont
# des bouchons ; DataService, ToolService, HeistController et ChaseController sont les vrais.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a23 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a39}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) client/Controllers/HudController.luau client/Controllers/UnboxController.luau client/Controllers/Unbox client/Controllers/HeistController.luau client/Controllers/ChaseController.luau server/Services/DataService.luau server/Services/ToolService.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  cat "$H/../ext-motion.luau" # a37 (DEV-052) ; copie d'a39 : ext-motion.luau rangé à côté (autres-bancs)
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
