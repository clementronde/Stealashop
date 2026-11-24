#!/usr/bin/env bash
# a244 (vague 72, Features.Rebirth = true) : lance un banc d avant sur une copie de l arbre où la ligne
# « Rebirth = true, » de Config/Features est remise à false. Ces bancs vérifient la renaissance coupée (aperçu,
# off, studio) et allument eux-mêmes l interrupteur quand il le faut ; la renaissance allumée par défaut est
# vérifiée par a244-banc. Arbre sans « Rebirth = true, » : le banc tel quel.
#   bash flag-off.sh <lanceur d avant> [racine du dépôt] [arguments…]
set -u
SCRIPT="$1"
shift
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
if ! grep -q "^	Rebirth = true," "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$ROOT" "$@"
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cp -r "$ROOT/src" "$T/src"
perl -pi -e 's/^\tRebirth = true,/\tRebirth = false,/' "$T/src/shared/Config/Features.luau"
bash "$SCRIPT" "$T" "$@"
