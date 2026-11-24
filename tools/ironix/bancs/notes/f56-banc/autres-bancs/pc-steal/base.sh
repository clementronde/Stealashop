#!/usr/bin/env bash
# fusion56 (vague 62) : copie de a170-banc/autres-bancs/pc-steal/run.sh. a204 ajoute un appel Model:ScaleTo dans
# RevealController (copie locale du modèle d'objet, sans invite : relu à la fusion), donc la liste relue gagne
# « 1 RevealController.luau ». Arbre sans RevealController : le lanceur d a170 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/client/Controllers/RevealController.luau" ]; then
	exec bash "$H/a170-banc/autres-bancs/pc-steal/run.sh" "$@"
fi
if grep -q 'Name = "BoxReady"' "$REPO/src/shared/Net/Definitions.luau" 2>/dev/null; then
	exec bash "$H/pc-steal-banc/run.sh" "$@"
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
sed -e "s|^H=.*|H=\"$H/pc-steal-banc\"|" -e 's/|1 Reel\.luau|1 Screen\.luau|/|/' -e 's/|1 PotionController\.luau|/|1 PotionController.luau|1 RevealController.luau|/' "$H/pc-steal-banc/run.sh" > "$T/run.sh"
bash "$T/run.sh" "$@"
