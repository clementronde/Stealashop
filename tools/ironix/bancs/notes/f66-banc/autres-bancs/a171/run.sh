#!/usr/bin/env bash
# fusion66 : banc a171 avec les deux correctifs, emboîtés.
#   a231 (vague 70) : a231-banc/autres-bancs/a171 (journaux du vigile « objet » ; il enveloppe lui-même le lanceur d a218 et se replie dessus sans followOwner) ;
#   a238 (vague 71, L-213 point 1b) : a238-banc/corrige.sh (patches/a171.sed : Ouvrir maintenant garde son bouton sans colis), posé autour.
# Les deux .sed touchent des lignes différentes ; les corrige.sh s emboîtent (le faux luau.exe de l un appelle celui de l autre).
# Arbre sans NoItemPrice dans RobuxShopController (avant a238) : la copie a231 telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NoItemPrice" "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/a238-banc/corrige.sh" a171 bash "$H/a231-banc/autres-bancs/a171/run.sh" "$ARG"
fi
exec bash "$H/a231-banc/autres-bancs/a171/run.sh" "$ARG"
