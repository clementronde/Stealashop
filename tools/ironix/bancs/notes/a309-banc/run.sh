#!/usr/bin/env bash
# Banc a309 (22/11, décision de Cantin : les cadeaux de 15 et 60 min de jeu deviennent un colis de zone, ouvert tout de
# suite par la scène de la caisse exclusive ; « fais la roue de la chance aussi » : BOX et RARE BOX sur les mêmes règles).
# Trois scénarios :
#   sur l'installation du banc a53 (a150-banc/autres-bancs/a53-banc : faux Roblox, vrais RewardService, UnboxService,
#   MonetizationService), copiée dans un dossier passager, avec les correctifs à la volée du banc a53 du lanceur
#   commun (a158, a170, a262) :
#     a309draw   Shared/ZoneBoxOdds et Config/Rewards.ZoneBox : chances exactes et 100 000 tirages par zone de référence
#                (1 à 6) et par palier, comparés aux attendus de la décision ; jamais de Secret à 60 min ; zone + 1
#                plafonnée ; faux ZoneOdds (zone 7 ajoutée, Légendaire retiré de la zone 5, zone vide) : les tirages
#                changent, Config/Rewards non ; Items.Pick a des objets pour chaque rareté de chaque colis
#     a309flow   réclamations : zone de l'objet donné, scène en zone safe sans message, message hors zone safe, plafond
#                zone 6, 200 dons sans Secret, inventaire plein refusé sans rien noter, jour 7 et coffre hebdo inchangés
#   sur le harnais du banc a266 (a268-banc/autres-bancs/a266/run.sh : vrais WheelService, Prize/Grant), scénario « on » :
#     a309wheel  secteurs, poids et repli inchangés (100 000 tirages de WheelService.Draw) ; BOX et RARE BOX : règles
#                BestZone et NextZone, 100 000 tirages par zone, Grant.Give passe par UnboxService.GiveZoneBoxItem ;
#                tour en zone safe : Result vide puis la scène à l'arrêt de la roue ; hors zone safe : le message ;
#                inventaire plein : le repli
# Arbre sans a309 (pas de src/shared/ZoneBoxOdds.luau) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]      VERBOSE=1 : sortie complète (lignes « TIRAGES | … » : le tableau des tirages)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$H/.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
LABEL="banc a309 (colis de zone : paliers 15 et 60 min, roue)"
if [ ! -f "$REPO/src/shared/ZoneBoxOdds.luau" ]; then
	echo "$LABEL : SAUTÉ, pas de src/shared/ZoneBoxOdds.luau (a309 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
total=0
fails=0
# $1 = sortie d'une partie, $2 = motif de sa ligne de compte.
add() {
	local line c f
	line=$(printf '%s\n' "$1" | grep -E "$2" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$1" | tail -20
		echo "  $3 : arrêté avant la fin"
		fails=$((fails + 1))
		return
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c))
	fails=$((fails + f))
}

# a309draw et a309flow : harnais du banc a53.
cp -r "$S/a150-banc/autres-bancs/a53-banc" "$T/a53-banc"
cp "$H/tests.a309draw.luau" "$H/tests.a309flow.luau" "$T/a53-banc/"
sed -i 's/banc a53 (récompenses)/banc a309 cadeaux/' "$T/a53-banc/run-base.sh"
cat > "$T/inner.sh" <<INNER
#!/usr/bin/env bash
exec bash "$S/a170-banc/corrige.sh" a53 bash "$S/a158-banc/corrige.sh" a53 bash "$T/a53-banc/run.sh" "\$@"
INNER
out=$(bash "$S/a262-banc/corrige.sh" a53 "$T/inner.sh" "$REPO" a309draw a309flow 2>&1)
printf '%s\n' "$out" | grep -v "^banc a309 cadeaux : "
add "$out" "^banc a309 cadeaux : [0-9]+ vérification" "cadeaux"

# a309wheel : harnais du banc a266.
mkdir -p "$T/wheel"
cp "$H/tests.a309wheel.luau" "$T/wheel/tests.luau"
sed -e "s|^ME=.*|ME=\"$T/wheel\"|" \
	-e "s|^H=.*|H=\"$S/a266-banc\"|" \
	-e 's/for scenario in on off; do/for scenario in on; do/' \
	-e 's/banc a266 (quêtes et roue)/banc a309 roue/g' \
	"$S/a268-banc/autres-bancs/a266/run.sh" > "$T/wheel/run.sh"
if [ "${VERBOSE:-}" = "1" ]; then
	sed -i 's/grep -E "ÉCHEC|ERREUR|error" | head -20/grep -E "ÉCHEC|ERREUR|error|TIRAGES" | head -40/' "$T/wheel/run.sh"
fi
out=$(bash "$T/wheel/run.sh" "$REPO" 2>&1)
printf '%s\n' "$out" | grep -v "^banc a309 roue : "
add "$out" "^banc a309 roue : [0-9]+ vérification" "roue"
echo "  a309wheel : $(printf '%s\n' "$out" | grep -E '^banc a309 roue : ' | sed -E 's/^banc a309 roue : //')"

echo "$LABEL : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
