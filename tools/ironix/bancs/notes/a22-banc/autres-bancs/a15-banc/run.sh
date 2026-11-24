#!/usr/bin/env bash
# Banc d'essai hors Studio de a15 (DEV-021 : HUD, écran de révélation, attributs Cash et Damage) ;
# copie (de celle d'a21) adaptée par a22 au catalogue v2 : Hot-dog en or retiré, noms anglais.
# Assemble le faux Roblox (celui de a13, complété : écrans, boutons, sons), les vraies sources
# partagées (Config, Contract, Net, Types, Format, Anim) et les fichiers testés, puis les scénarios,
# en un seul fichier Luau exécuté par le luau de rokit. ProfileStore et AnimationController y sont
# des bouchons ; DataService, ToolService, HeistController et ChaseController sont les vrais.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a15 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a22}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared client/Controllers/HudController.luau client/Controllers/UnboxController.luau client/Controllers/HeistController.luau client/Controllers/ChaseController.luau server/Services/DataService.luau server/Services/ToolService.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
