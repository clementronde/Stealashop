#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : ../heist-13s.luau remet Balance.Heist.Duration à 13 dans le faux arbre (openSlot de head.luau compte sur un magasin ouvert 10 s ; avec 6 s, une ouverture était parfois refusée). Le reste : copie a116, telle quelle.
# Copie a116 (2026-11-13) : NOTES trois dossiers au-dessus ; autres-bancs/a103-banc/head.luau : fireOpen en deux
# appels (début, fin du maintien), comme la copie a116 du banc a103.
# Banc hors Studio d'a109 (2026-11-13, vague 32, règle de Cantin) : rareté de la CAISSE tirée à la mise en
# rayon (BoxRarity, BOX_<Rareté>, BB_Box à la rareté seule), contenu tiré à l'ouverture dans
# Config/ShelfOpen.BoxRarityOdds[caisse] avec la chance (LuckBoost "AboveBox" ou "AboveLowest", puis
# normalisation), objet de la zone la plus proche, Secret toutes zones, mutation tirée à la sortie, tuto
# inchangé, ancien déroulé (Features.ShelfOpen = false) exact.
# Faux Roblox et mise en place : ceux du banc a30 copie a66 ; outils : head.luau de la copie a109 du banc
# a103 (autres-bancs/a103-banc), puis head.luau d'ici. Random de StoreHeistService piloté (HEIST_FORCED).
#   draw     tirage selon la caisse, effet de la chance (AboveBox), normalisation, repli de zone, Secret,
#            mutation à la sortie, étiquettes et attributs des caisses (rayon et portée), log
#   lowest   LuckBoost = "AboveLowest" (pre.lowest.luau)
#   divine   rareté sans aucun objet au catalogue (Divine) : la plus proche en dessous (pre.divine.luau)
#   tuto     SetContentOverride et SetLuckOverride : contenu imposé sans tirage, drawn = caisse
#   oldflow  Features.ShelfOpen = false : contenu et mutation tirés à la mise en rayon, BB_Box complet
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la vague 32 (pas de BoxRarityOdds) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NOTES="$(cd "$H/../../.." && pwd)"
BASE="$NOTES/a66-banc/autres-bancs/a30-banc"
HEAD103="$H/autres-bancs/a103-banc/head.luau"
LABEL="banc a109 (rareté tirée à l'ouverture selon la caisse et la chance)"
if ! grep -q "BoxRarityOdds" "$SRC/shared/Config/ShelfOpen.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de BoxRarityOdds dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-draw lowest divine tuto oldflow}"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$BASE/stubs.luau"
		cat "$BASE/../stub-anticheat.luau"
		sources
		cat "$NOTES/a135-banc/autres-bancs/heist-13s.luau" # a135 : chrono HEIST de 13 s dans le faux arbre (voir ce fichier)
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$BASE/setup.luau"
		cat "$HEAD103"
		cat "$H/head.luau"
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
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
