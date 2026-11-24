#!/usr/bin/env bash
# Banc hors Studio de f70c1 (correctif f70, B2 et B5) : UI_Displayed garde UI_Hotbar (Config/UiMotion.HudHide.Keep),
# HotbarController ne rallume plus la barre masquée par HudMask (HudMask.IsMasked), HelpInvite.Night = true.
# Deux parties : motion.sh (harnais a256) et hotbar.sh (harnais a74). Arbre d'avant f70c1 : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
total_checks=0
total_fails=0
part() {
	local label="$1"
	shift
	local out line c f
	out=$("$@" 2>&1)
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|SAUTÉ" || true; fi
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "  $label : pas de résumé"
		total_fails=$((total_fails + 1))
		return
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $label : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
}
part "motion" bash "$H/motion.sh" "$ROOT"
part "hotbar" bash "$H/hotbar.sh" "$ROOT"
echo "banc f70c1 (Hotbar sous UI_Displayed, HelpInvite de nuit) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
