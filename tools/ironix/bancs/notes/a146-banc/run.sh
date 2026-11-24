#!/usr/bin/env bash
# Banc hors Studio d'a146 (2026-11-14, vague 41, audit de sécurité) : vol, murs et poussée.
#   fly     AntiCheatService : en l'air sans tomber plus de FlyTime s = « Fly » (ligne ; retour au sol avec
#           AntiCheatStrict) ; saut haut, chute, réseau figé en l'air, tour haute : rien ;
#   carrier porteur collé à un complice rapide : sa vitesse ne compte plus (× CarrierPushFactor au plus) ;
#           un vigile le pousse toujours à la sienne ;
#   catch   GuardService : capture d'un joueur perché sur un meuble bas, dans un mur, en l'air juste
#           au-dessus du vigile ; jamais à travers un mur, un plancher, ni à plus de CatchVerticalReach ;
#   bat     BatService : le propriétaire frappe son voleur perché ou dans un mur ; jamais à travers un mur.
# Harnais : celui du banc a36 (copie a146 : a146-banc/autres-bancs/a36), plus overlap-ajout.luau (OverlapParams,
# Workspace:GetPartsInPart). Chaque scénario dans son propre luau (état neuf).
# Sur un arbre sans shared/CatchReach (avant a146) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]      VERBOSE=1 : écrit aussi les lignes ok et la sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
X="$H/autres-bancs/a36"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/shared/CatchReach.luau" ]; then
	echo "banc a146 (vol, murs, poussée) : SAUTÉ, a146 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-fly carrier catch bat}"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$X/stubs.luau" "$H/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
		sources
		cat "$H/../a134-banc/levier-force.luau"
		cat "$H/../a134-banc/coups-en-rafale.luau"
		cat "$H/../a103-banc/ancien-deroule.luau"
		cat "$X/setup.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a146 (vol, murs, poussée) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
