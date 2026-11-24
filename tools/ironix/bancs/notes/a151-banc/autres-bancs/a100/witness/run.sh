#!/usr/bin/env bash
# Copie a151 (vague 43) : tests.luau revu (scénarios 5, 6 et 10 : un policier par frappeur) ; harnais et lancement inchangés.
# Banc hors Studio d'a100 (vague 30, 2026-11-12, liaison L-111) : témoins et police. Vrais WitnessService,
# Shared/WitnessGauge, Config/Witness, Config/Zones, Contract (Animations, Find, Models, UI) ; bouchons pour
# AnimPlayer, MarkerSounds, Net, GuardService (StartDriverChase noté) et WindowService (OnHit, OnBroken).
# Scénarios : contrat et calcul de la jauge, démarrage (témoins de la map, inbox ignorée, avertissements),
# balade sur le circuit WitnessPaths (ordre, sens, boucle, pause, blocage), premier coup (regard, pente,
# aucune écriture aux coups suivants), vitrine cassée à temps, appel au « ? » plein (premier marqueur Call,
# son, policier, messages, OnCall), sans marqueur, un policier par magasin, choix du suspect, API de L-112
# (Raise, Pause, Calm, GetFill, IsCalling), zone sans circuit, NPC_Police absent, témoin retiré.
# « SAUTÉ » sans WitnessService.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok et la sortie du service
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a100"
if [ ! -f "$SRC/server/Services/WitnessService.luau" ]; then
	echo "$NAME (témoins et police) : SAUTÉ, pas de WitnessService (a100 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/WitnessService.luau shared/WitnessGauge.luau"
for m in Balance Cosmetics DeepFreeze Features Items Rarities Tools Witness Zones; do # a210 (vague 63) : Features ajouté (Config/Cosmetics le requiert) # a134 : Balance, Cosmetics et Tools ajoutés (Config/Zones les requiert)
	FILES="$FILES shared/Config/$m.luau"
done
for m in Animations Find Models UI; do
	FILES="$FILES shared/Contract/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$H/harness.luau"
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$LUAU" "$W" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
