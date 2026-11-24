#!/usr/bin/env bash
# a217 (vague 65) : banc a186 avec U20 « écran fermé : cartes gardées » (AuraShopController garde ses lignes écran fermé).
# Le reste : a186-banc tel quel (faux Roblox lus sur place). Sans « assetTextures » dans AuraShopController : a186 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
if ! grep -q "assetTextures" "$ROOT/src/client/Controllers/AuraShopController.luau" 2>/dev/null; then
	exec bash "$H/a186-banc/run.sh" "$ROOT"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
sed -e "s|^H=.*|H=\"$TMP\"|" -e "s|^B=.*|B=\"$H/a50-banc\"|" "$H/a186-banc/run.sh" > "$TMP/run.sh"
cp "$H/a186-banc/ext-a186.luau" "$TMP/ext-a186.luau"
cp "$(dirname "$0")/tests.luau" "$TMP/tests.luau"
bash "$TMP/run.sh" "$ROOT"
