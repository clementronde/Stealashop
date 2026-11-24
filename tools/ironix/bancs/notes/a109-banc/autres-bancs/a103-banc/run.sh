#!/usr/bin/env bash
# Copie a109 (2026-11-13, vague 32, règle de Cantin : rareté de la caisse sur le rayon, contenu tiré à
# l'ouverture selon la caisse et la chance, crans retirés) : scénario upgrade retiré (crans), remplacé par
# le banc a109 ; head.luau : openAndReveal force le tirage de la rareté de l'objet (0 = la plus basse de la
# table de la caisse), boxLabel lit la rareté de la caisse ; tests.open : O5h, O5i (rareté et mutation tirées
# à la sortie, étiquette sans mutation) ; chemins du faux Roblox (a66) depuis le dossier des notes. Sur un
# arbre d'avant la vague 32 (pas de BoxRarityOdds), lance le banc a103 d'origine.
# Banc hors Studio d'a103 (2026-11-12, vague 31, liaison L-112) : ouverture des colis sur le rayon du
# magasin PNJ, côté serveur (StoreHeistService, CarryService ; retouches de GuardService et BatService).
# Vrais : StoreHeistService, CarryService, GuardService, BatService, WindowService, ToolService,
# StatsService, TruckEventService, Loader, Net, Config, Contract, Types. Bouchons : ceux du banc a30
# (copie d'a66), plus WitnessService (head.luau : Raise, Calm, IsCalling, OnCall notés et pilotés).
# Faux Roblox et mise en place : ceux du banc a30 copie a66, lus sur place (stubs.luau, setup.luau).
# Le Random de StoreHeistService est piloté (HEIST_FORCED : prochains NextNumber, head.luau).
# Chaque scénario tourne dans son propre luau : pre.<nom>.luau (s'il existe), setup, head, tests.<nom>.
#   open     tirage de la chance, validations d'OpenShelfBox, attributs du contrat, sortie de l'objet
#   upgrade  crans de rareté (plafond, décroissance, UpgradeTop, case vide), tuto, annonce
#   reserve  réservation de 5 s, prise par GrabItem, portage NPCItem, vigile, magasin fermé pour le voleur
#   witness  Raise au lancement, Calm à la dernière ouverture, refus pendant l'appel, police (OnCall)
#   caught   attrapé : l'objet tombe et se reprend ; batte ; retour sur le rayon ; mort ; nuit
#   close    fin du chrono pendant une ouverture, rideau, objet non pris, remplissage reporté
#   oldflow  Features.ShelfOpen = false : l'ancien déroulé, OpenShelfBox sans effet
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a103 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
# Avant la fusion d'a103 (pas de remote OpenShelfBox) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NOTES="$(cd "$H/../../.." && pwd)"
BASE="$NOTES/a66-banc/autres-bancs/a30-banc"
LABEL="banc a103 copie a109 (ouverture des colis sur le rayon, serveur)"
if ! grep -q '"OpenShelfBox"' "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de remote OpenShelfBox dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
# Arbre d'avant la vague 32 (crans, pas de BoxRarityOdds) : le banc a103 d'origine, tel quel.
if ! grep -q "BoxRarityOdds" "$SRC/shared/Config/ShelfOpen.luau" 2>/dev/null; then
	exec bash "$NOTES/a103-banc/run.sh" "$ROOT" "$@"
fi
SCENARIOS="${*:-open reserve witness caught close oldflow}"
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
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$BASE/setup.luau"
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
