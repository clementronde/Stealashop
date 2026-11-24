#!/usr/bin/env bash
# fusion62 (vague 66) : a39 avec les deux corrections, a223 (plaque ShopPad : sortir ferme, rien en poursuite) par-dessus
# la copie a218 (« Soon » permanent). Arbre sans WeaponShopController.Leave : la copie a218 seule (elle-même : sans notForSale, a208).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'function WeaponShopController.Leave' "$REPO/src/client/Controllers/WeaponShopController.luau" 2>/dev/null; then
	exec bash "$H/a218-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a223-banc/corrige.sh" a39 bash "$H/a218-banc/autres-bancs/a39/run.sh" "$@"
