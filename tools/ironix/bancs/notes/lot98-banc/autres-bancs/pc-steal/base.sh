#!/usr/bin/env bash
# lot98-commun (petit chef 2) : copie de a251-banc/autres-bancs/pc-steal/base.sh ; la liste relue des appels ScaleTo côté client
# gagne « 1 UpgradeController.luau » : popSign d a406 (L-297, ShopBuild.SignPopFrom 0,55 → 1), relu : le panneau revient
# toujours à son échelle d avant (base × 1, aussi quand il est caché pendant le pop) ; son seul ProximityPrompt est
# UpgradePrompt d a419 sur Board (manette), voir le rapport. Ce n est pas a418 (Config seulement).
# a251 (vague 73, L-236) : copie de f56-banc/autres-bancs/pc-steal/base.sh. Reveal/Unbox ajoute un appel Model:ScaleTo
# (copies locales du colis, des silhouettes et de l'objet, rendues inertes : scripts, invites ProximityPrompt et
# billboards retirés avant ; relu), donc la liste relue gagne « 1 Unbox.luau ». Arbre sans Reveal/Unbox : le lanceur
# d'avant (f56) tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/client/Controllers/Reveal/Unbox.luau" ]; then
	exec bash "$H/f56-banc/autres-bancs/pc-steal/base.sh" "$@"
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
sed -e "s|^H=.*|H=\"$H/pc-steal-banc\"|" -e 's/|1 Reel\.luau|1 Screen\.luau|/|/' -e 's/|1 PotionController\.luau|/|1 PotionController.luau|1 RevealController.luau|/' -e 's/|4 ShelfOpenController\.luau|/|4 ShelfOpenController.luau|1 Unbox.luau|/' -e 's/|1 Unbox.luau|1 VfxController.luau"/|1 Unbox.luau|1 UpgradeController.luau|1 VfxController.luau"/' "$H/pc-steal-banc/run.sh" > "$T/run.sh"
bash "$T/run.sh" "$@"
