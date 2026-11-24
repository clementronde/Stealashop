#!/usr/bin/env bash
# Copie a147 (2026-11-14, vague 41) du runner de la copie a94 du banc a21-night : mêmes fichiers (lus dans a94-banc/autres-bancs/a21-night),
# plus le faux arbre a147-banc/retour-base-actif.luau après les sources (Features.ReturnToBase passe à false dans le jeu ; ce banc
# vérifie toujours ReturnBaseService, qui reste dans le code : l interrupteur est remis à true dans le faux arbre).
# Arbre où ReturnToBase est encore à true (avant a147) : la copie a94 tourne telle quelle.
if grep -q "ReturnToBase = true" "${1:-/f/StealAShop}/src/shared/Config/Features.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a94-banc/autres-bancs/a21-night/run.sh" "$@"; fi
# Copie d'a94 (2026-11-12, L-108 point 2), partie de celle d'a90 : scenarios.luau attend la poursuite de nuit à Night.ChaseSpeed (80) si le champ existe, sinon vitesse conseillée + 4 : bonne avant et après la fusion.
# Copie d'a90 (2026-11-12, vague 29, L-106 points 5 et 6) : l'annonce de la nuit part en « Alert » (sans UI_Deny) ; « Warning » accepté aussi.
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio de a21 (DEV-047 nuit, DEV-045 Retour base) : NightCycleService, vigiles de nuit
# (GuardService), ReturnBaseService, avec les vrais Net, Config, Contract, Format, AnimPlayer,
# MarkerSounds et ChaseController. Faux Roblox : celui de a12 (copie de a15), complété (groupes de
# collision, heure serveur, DescendantAdded, Lighting, côté « prod » hors Studio).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a21 ; après fusion : /f/StealAShop)
set -eu
ME="$(cd "$(dirname "$0")" && pwd)"
H="$ME/../../../a94-banc/autres-bancs/a21-night"
ROOT="${1:-/f/StealAShop/agents/a21}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/GuardService.luau server/Services/NightCycleService.luau server/Services/ReturnBaseService.luau client/Controllers/ChaseController.luau"
{
  cat "$H/stubs.luau"
  cat "$H/../stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
  printf '\nRIG_MODE = "roblox"\n'
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$ME/../../retour-base-actif.luau" # a147 : Features.ReturnToBase à true dans le faux arbre
  cat "$H/tests.head.luau" "$H/scenarios.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
