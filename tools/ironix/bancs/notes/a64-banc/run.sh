#!/usr/bin/env bash
# Banc hors Studio d'a64 (vague 22, L-092 3f : écran UI_Offline, gains hors ligne en attente du Claim).
#   serveur : vrai OfflineService (et DataService, DisplayService, TelemetryService, Net…), monté sur la copie
#             a64 du banc a48 (autres-bancs/a48-banc : faux Roblox, faux ProfileStore, setup, helpers) ;
#             scénario serveur/tests.a64.luau : montant en attente, Claim, double Claim refusé, départ sans
#             Claim = versé une fois au retour, nouveau joueur sans rien, Pending illisible, session
#             reprise, plantage.
#   client  : vrais OfflineController, GainController, HudController, Controllers/UI/Motion et Net (remotes
#             créés par le Net serveur, serveur simulé dans le test), NotifyController bouchonné, monté sur
#             le faux Roblox d'a60 (client/stubs.luau, ext-motion.luau, ext-a60.luau, setup.luau,
#             setup-a60.luau copiés d'a60-banc) ; scénario client/tests.client.luau : écran fermé pour un
#             nouveau joueur, ouverture après OpenDelay, Amount, Claim → remote puis fermeture, case qui part
#             du centre, DoubleButton « Soon », groupe Menu, écran recréé, secours sans écran.
#   bash run.sh [racine du dépôt] [serveur] [client]   (défaut : le worktree a64 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                               écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a64}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-serveur client}"
if ! grep -q "ClaimOffline" "$SRC/server/Services/OfflineService.luau" 2>/dev/null; then
	echo "banc a64 (écran UI_Offline, Claim des gains hors ligne) : SAUTÉ, pas de ClaimOffline dans OfflineService (vague 22 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
H48="$H/autres-bancs/a48-banc"
FILES_SERVEUR="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/OfflineService.luau server/Services/TelemetryService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"
FILES_CLIENT="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/OfflineController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	if [ "$name" = "serveur" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$H48/stubs.luau" "$H48/ext29.luau" "$H48/ext38.luau" "$H48/ext46.luau" "$H48/ext35.luau" "$H48/stub-anticheat.luau"
			sources "$FILES_SERVEUR"
			cat "$H48/features.luau" "$H48/pre.on.luau" "$H48/setup.luau" "$H48/helpers.luau" "$H/serveur/tests.a64.luau"
		} > "$OUT"
		pattern="^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	else
		{
			cat "$H/client/stubs.luau" "$H/client/ext-motion.luau" "$H/client/ext-a60.luau"
			sources "$FILES_CLIENT"
			cat "$H/client/setup.luau" "$H/client/setup-a60.luau" "$H/client/tests.client.luau"
		} > "$OUT"
		pattern="^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR" | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a64 (écran UI_Offline, Claim des gains hors ligne) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
