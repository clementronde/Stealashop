#!/usr/bin/env bash
# a255 (vague 73, L-241 point 4 ; décision de Cantin du 18/11) : contrat UI et Config/Displayed. CloseArrowButton sorti
# d UI_Displayed (CloseButton fait la flèche) ; UI_Hotbar.Bar.InventoryButton, sa pastille InventoryAlert et
# UI_Displayed Reserve.ReserveEmpty facultatifs ; ShowReserve et InventoryAlert à true.
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
UI="$ROOT/src/shared/Contract/UI.luau"
CFG="$ROOT/src/shared/Config/Displayed.luau"
checks=0
fails=0
check() {
	checks=$((checks + 1))
	if eval "$1"; then
		[ "${VERBOSE:-}" = "1" ] && echo "  ok : $2"
	else
		fails=$((fails + 1))
		echo "  ÉCHEC : $2"
	fi
}
check '! tr -d "\r" < "$UI" | grep -qE "Path = \"CloseArrowButton\""' "UI_Displayed.CloseArrowButton plus au contrat"
check 'tr -d "\r" < "$UI" | grep -qE "Name = \"UI_Hotbar\","' "écran UI_Hotbar au contrat"
check 'tr -d "\r" < "$UI" | grep -qE "Path = \"Bar\.InventoryButton\", Class = BUTTON, Optional = true"' "UI_Hotbar Bar.InventoryButton facultatif"
check 'tr -d "\r" < "$UI" | grep -qE "Path = \"Bar\.InventoryButton\.InventoryAlert\", Class = \"GuiObject\", Optional = true"' "Bar.InventoryButton.InventoryAlert facultatif"
check 'tr -d "\r" < "$UI" | grep -qE "Path = \"Reserve\.ReserveEmpty\", Class = \"GuiObject\", Optional = true"' "UI_Displayed Reserve.ReserveEmpty facultatif"
check 'tr -d "\r" < "$CFG" | grep -qE "^\s*ShowReserve = true,"' "Config/Displayed.ShowReserve = true"
check 'tr -d "\r" < "$CFG" | grep -qE "^\s*InventoryAlert = true,"' "Config/Displayed.InventoryAlert = true"
echo "contrat a255 : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
