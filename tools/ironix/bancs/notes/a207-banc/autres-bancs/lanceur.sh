#!/usr/bin/env bash
# a207 (vague 63, L-201) : lanceur des bancs a67 et a117 (autres-bancs/<nom>/run.sh l'appellent).
# Sans la marque d'a207 dans IndexController (« V3_CLAIMED_TEXT ») : le lanceur d'a201 tel quel.
# Avec : ../corrige.sh (patches/<nom>.sed) autour du même lanceur d'a201 (compteur « 10 / 83 discovered »,
# « CLAIMED », MutationTabs, MutationCaption, SecretsButton et ZoneItem sortis du contrat, éléments facultatifs
# du nouvel écran absents de la copie du banc = lignes orange tolérées).
#   bash lanceur.sh <nom> [racine du dépôt] [scénarios…]
NAME="$1"
shift
H="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "V3_CLAIMED_TEXT" "$REPO/src/client/Controllers/IndexController.luau" 2>/dev/null; then
	exec bash "$H/a201-banc/autres-bancs/$NAME/run.sh" "$@"
fi
exec bash "$H/a207-banc/corrige.sh" "$NAME" bash "$H/a201-banc/autres-bancs/$NAME/run.sh" "$@"
