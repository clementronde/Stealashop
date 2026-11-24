#!/usr/bin/env bash
# Lance les bancs de a21 (night : serveur, hud : client) puis les copies des bancs touchés par a21,
# et résume. Copies dans autres-bancs/, différences avec les originaux :
#   a12-harness (vigile de jour, copie a15) : Shared/Format ajouté à l'arbre (GuardService le lit
#     depuis a18) ; textes du Notify en anglais (« Caught! Recommended speed: 16 » et « 28 »).
#   a15-banc (HUD) : textes anglais de a18 (HEIST: 10s, COMMON, MYTHIC) ; NightCountdown et
#     ReturnBaseButton affichés (Features réactivés par a21) au lieu de cachés.
#   a17-banc/heist : le remplissage V0 automatique n'existe plus (retiré par a21) : on vérifie qu'il
#     ne vient plus tout seul, puis que RefillAll (tombée de la nuit) remplit.
#   a17-banc/carry, a17-banc/shelf : inchangés.
#   a06-tests (parcelles, TeleportHome compris) : panneaux en anglais (« Alice's Shop », a18) ; l'original
#     échoue sur ces 5 textes, sur main comme sur a21.
#   bash run-all.sh [racine du dépôt]   (défaut : worktree a21 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a21}"
A="$H/autres-bancs"
for entry in "night:$H/night/run.sh:$ROOT" "hud:$H/hud/run.sh:$ROOT" \
  "a12-harness:$A/a12-harness/run.sh:$ROOT/src" "a15-banc:$A/a15-banc/run.sh:$ROOT" \
  "a17-heist:$A/a17-banc/heist/run.sh:$ROOT/src" "a17-carry:$A/a17-banc/carry/run.sh:$ROOT" \
  "a17-shelf:$A/a17-banc/shelf/run.sh:$ROOT" "a06-tests:$A/a06-tests/run.sh:$ROOT"; do
  name="${entry%%:*}"; rest="${entry#*:}"; script="${rest%%:*}"; arg="${rest#*:}"
  out=$(bash "$script" "$arg" 2>&1)
  summary=$(printf '%s\n' "$out" | grep -E "vérification\(s\)|réussi\(s\)" | tr '\n' ' ')
  printf '%-12s %s\n' "$name" "${summary:-ERREUR (pas de résumé)}"
  printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" | sed 's/^/    /'
done
