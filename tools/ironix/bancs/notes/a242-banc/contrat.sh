#!/usr/bin/env bash
# a242 (vague 72) : lecture du contrat UI (src/shared/Contract/UI.luau) : ClaimAllButton sorti des éléments lus (gardé dans
# UI.Retired seulement), CloseArrowButton facultatif dans UI_Displayed, interrupteur ShowReserve dans Config/Displayed.
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
check '! tr -d "\r" < "$UI" | grep -qE "Path = \"UnlockedBar\.ClaimAllButton"' "aucun élément UnlockedBar.ClaimAllButton lu par le code"
check 'tr -d "\r" < "$UI" | grep -qE "\[\"UI_Index_v3\.UnlockedBar\.ClaimAllButton\"\] = "' "ClaimAllButton dans UI.Retired (note, jamais rouge)"
check 'tr -d "\r" < "$UI" | grep -qE "\{ Path = \"Rewards\.ClaimButton\.ClaimAlert\" \}"' "les autres pastilles de l index restent"
check 'tr -d "\r" < "$UI" | grep -qE "\{ Path = \"CloseArrowButton\", Class = BUTTON, Optional = true"' "UI_Displayed.CloseArrowButton facultatif"
check 'tr -d "\r" < "$CFG" | grep -qE "^\s*ShowReserve = false,"' "Config/Displayed.ShowReserve = false"
echo "contrat a242 : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
