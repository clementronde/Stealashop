#!/usr/bin/env bash
# Banc a319 (23/11, L-303, décision de Cantin) : « x2 SPEED » = gamepass permanent DoubleSpeed (149 R$), plus de boost
# SpeedBoost de 10 min. Pas de faux Roblox à lui : il reprend ceux des bancs a38 (serveur, MonetizationService,
# TrainingService, DataService, ProcessReceipt ; lanceur a274) et a190 (client, HudMenuController ; lanceur a224),
# avec leurs corrections, et remplace leurs scénarios par les siens juste avant l'exécution (transforme.pl, par un
# faux luau.exe posé dans un HOME passager, comme a274-banc/corrige.sh).
#   server on    pass possédé à l'arrivée : PassDoubleSpeed, PassKnownDoubleSpeed, gain du tapis × 2, × 4 avec ×2 Training ;
#                pas possédé : connu, pas d'effet ; achat en jeu confirmé par Roblox (a274) ; signal seul : rien ;
#                Roblox muet : PassKnown absent ; vieux reçu (produit 0 ou inconnu) rejoué : NotProcessedYet, rien donné ;
#                vieux profil avec un temps de boost SpeedBoost : chargé sans erreur, sans effet, ×2 argent intact
#   server zero  Id 0 : jamais lu, ni Pass ni PassKnown, aucun effet (même boutique ouverte)
#   client on    boutique ouverte, Id 9007 : prix 149, caché tant que pas connu, montré partout (hors tapis aussi), clic →
#                PromptGamePassPurchase(9007), caché une fois possédé, SleepButton inchangé
#   client zero  Id 0 : jamais montré, clic sans invite ni erreur   client off  boutique coupée : pareil
# Arbre sans DoubleSpeed dans Config/Monetization (avant a319) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'Key = "DoubleSpeed"' "$REPO/src/shared/Config/Monetization.luau" 2>/dev/null; then
	echo "banc a319 (x2 SPEED gamepass) : SAUTÉ, a319 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "perl \"$H/transforme.pl\" \"\$f\" || exit 1"
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
export A319_DIR="$(cygpath -m "$H")"
checks=0
fails=0
count() { # $1 = sortie d'un lancement
	local c f
	c=$(printf '%s\n' "$1" | grep -oE "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$c" ]; then
		fails=$((fails + 1))
		return
	fi
	checks=$((checks + $(printf '%s' "$c" | sed -E 's/^([0-9]+) .*/\1/')))
	fails=$((fails + $(printf '%s' "$c" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
}
out=$(HOME="$T" A319_PART=server bash "$N/a274-banc/autres-bancs/a38/run.sh" "$REPO" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté|transformation" | head -20
s1=$(printf '%s\n' "$out" | grep -E "^  (passes|receipts) :")
echo "serveur : $(printf '%s' "$s1" | tr '\n' ' ')"
count "$out"
for v in on zero off; do
	out=$(HOME="$T" A319_PART=client A319_V=$v bash "$N/a224-banc/autres-bancs/a190/run.sh" "$REPO" menu 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté|transformation" | head -20
	echo "client $v : $(printf '%s\n' "$out" | grep -E '^  menu :')"
	count "$out"
done
echo "banc a319 (x2 SPEED gamepass) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
