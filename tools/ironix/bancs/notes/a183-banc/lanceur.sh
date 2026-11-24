#!/usr/bin/env bash
# a183 (2026-11-15, vague 56, L-173 : récompenses de renaissance = multiplicateur d'argent et tuiles de l'arbre) :
# lance un banc existant avec les correctifs de a183-banc/patches/<nom>.sed (appliqués au fichier assemblé,
# corrige.sh, après ceux d'a176 quand le lanceur donné est celui d'a176) quand l'arbre a RequiresRebirth dans
# Config/SkillTree ; arbre sans RequiresRebirth (avant la fusion) : le banc tel quel.
#   bash lanceur.sh <nom> <lanceur du banc> <dépôt>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"; ORIG="$2"; shift 2
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "RequiresRebirth" "$REPO/src/shared/Config/SkillTree.luau" 2>/dev/null; then
	exec bash "$ORIG" "$@"
fi
exec bash "$H/corrige.sh" "$NAME" bash "$ORIG" "$@"
