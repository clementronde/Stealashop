#!/usr/bin/env bash
# a237 (vague 71) : lanceur du banc a117 (chaîne a226 → a207 → … → a134, inchangée) ; quand ZoneBannerController
# contient « a237 », le faux Roblox de la copie a101 du banc a42 (a101-banc/autres-bancs/a42-banc/stubs.luau) est suivi
# de a237-banc/ext237.luau (GetPropertyChangedSignal, ajout pur) : « cat » exporté qui ajoute ext237 après ce seul
# fichier. Arbre sans a237 : le lanceur d a226 tel quel.
D="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
if grep -q "a237" "${ARG%/src}/src/client/Controllers/ZoneBannerController.luau" 2>/dev/null; then
	export A237_EXT="$D/a237-banc/ext237.luau"
	cat() {
		command cat "$@"
		case "${!#}" in
			*/a101-banc/autres-bancs/a42-banc/stubs.luau) command cat "$A237_EXT" ;;
		esac
	}
	export -f cat
fi
exec bash "$D/a226-banc/autres-bancs/a117/run.sh" "$@"
