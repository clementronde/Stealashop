#!/usr/bin/env bash
# a158, outil de travail : fabrique le lanceur d'un banc (autres-bancs/<nom>/run.sh) d'après origines.txt, le lance sur
# un arbre et montre les échecs.
#   bash lanceur.sh <nom> [arbre]          (défaut : /f/StealAShop/agents/a158)        FULL=1 : toute la sortie
# origines.txt, une ligne par banc : « nom entrée final mode arg [scénarios…] »
#   entrée    : le script que run-all-bancs.sh lançait avant a158 (relatif au dossier des bancs) ;
#   final     : le script du banc lui-même (le même, ou celui que a153-banc/regle-coupee.sh enveloppe) ;
#   mode      : « = » (lancé directement), « src » ou « repo » (il passe par regle-coupee.sh, avec ce mot) ;
#   arg       : « repo » (le runner lui passe la racine du dépôt) ou « +src » (il lui passe src) ;
#   scénarios : facultatif, les seuls scénarios lancés depuis a158 (les autres vérifiaient le colis porté) ;
#               « RETIRE <raison> » : banc entier retiré depuis a158.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
TREE="${2:-/f/StealAShop/agents/a158}"
line="$(grep "^$NAME " "$H/origines.txt")"
if [ -z "$line" ]; then echo "pas d'origine pour $NAME"; exit 2; fi
set -- $line
entry="$2"; final="$3"; mode="$4"; arg="$5"
shift 5
scen="$*"
D="$H/autres-bancs/$NAME"
mkdir -p "$D"
rm -f "$D/inner.sh"
{
	echo '#!/usr/bin/env bash'
	echo "# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc $NAME."
	echo "# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel."
	echo 'H="$(cd "$(dirname "$0")/../../.." && pwd)"'
	echo 'ARG="${1:-/f/StealAShop}"'
	echo 'REPO="${ARG%/src}"'
	echo 'if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then'
	echo "	exec bash \"\$H/$entry\" \"\$@\""
	echo 'fi'
	case "$scen" in
	RETIRE*)
		echo "# Depuis a158 : banc retiré (${scen#RETIRE })."
		echo "echo \"banc $NAME : SAUTÉ depuis a158 (le colis porté n'existe plus ; ${scen#RETIRE }) : 0 vérification(s), 0 échec(s)\""
		echo 'exit 0'
		;;
	*)
		echo "# Depuis a158 : ../../corrige.sh (corrections : patches/commun.sed, patches/$NAME.sed et patches/$NAME.pre.luau s'ils existent)."
		if [ -n "$scen" ]; then echo "# Scénarios gardés : $scen (les autres vérifiaient le colis porté, posé au sol ou ouvert en base)."; fi
		if [ "$mode" = "=" ]; then
			echo "exec bash \"\$H/a158-banc/corrige.sh\" $NAME bash \"\$H/$final\" \"\$ARG\" $scen"
		else
			inner="\$H/$final"
			if [ -n "$scen" ]; then
				printf '#!/usr/bin/env bash\n# a158 : le banc %s avec ses seuls scénarios encore valables (voir run.sh).\nH="$(cd "$(dirname "$0")/../../.." && pwd)"\nexec bash "$H/%s" "$1" %s\n' "$NAME" "$final" "$scen" > "$D/inner.sh"
				inner="\$H/a158-banc/autres-bancs/$NAME/inner.sh"
			fi
			echo "exec bash \"\$H/a158-banc/corrige.sh\" $NAME bash \"\$H/a153-banc/regle-coupee.sh\" \"$inner\" $mode \"\$REPO\""
		fi
		;;
	esac
} > "$D/run.sh"
if [ "${GEN:-}" = "1" ]; then exit 0; fi # GEN=1 : écrit le lanceur sans lancer le banc
a="$TREE"
if [ "$arg" = "+src" ]; then a="$TREE/src"; fi
out="$(bash "$D/run.sh" "$a" 2>&1)"
if [ "${FULL:-}" = "1" ]; then printf '%s\n' "$out"; exit 0; fi
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|luau:[0-9]+|arrêté avant|vérification\(s\)|réussi\(s\)|raté\(s\)|SAUTÉ" | sed -E 's#C:/Users[^ ]*/(run[^/ ]*luau)#\1#' | cut -c1-230 | head -${LINES_MAX:-40}
