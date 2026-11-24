#!/usr/bin/env bash
# Banc hors Studio d'a198 (vague 61, Cantin : vitesse réelle × 2, vitrine de la zone 1 à 15 PV).
#   1. tests.config.luau : les vraies tables de src/shared/Config (chargeur du simulateur) : marche à plusieurs Speed,
#      Zones (seuils, marche conseillée, vigiles, PV), Chase, Night, Bot, TruckEvent, AntiCheat, objet volé ;
#      sur l'arbre tel quel (K lu dans Balance) et sur une copie à K = 1 ;
#   2. chase/ : poursuite sur le harnais d'a193 (a198hold : marche du porteur, ruée, 14 studs gardés, anti-triche
#      muet pour un joueur légal ; a198catch : capture sous le minimum), sur l'arbre et sur la copie à K = 1.
# « SAUTÉ » sur un arbre sans Balance.REAL_SPEED_SCALE (avant a198).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
BAL="$ROOT/src/shared/Config/Balance.luau"
if ! grep -q "^local REAL_SPEED_SCALE = " "$BAL" 2>/dev/null; then
	echo "banc a198 (vitesse réelle à l'échelle) : SAUTÉ (arbre sans RealSpeedScale) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
K=$(tr -d '\r' < "$BAL" | sed -nE 's/^local REAL_SPEED_SCALE = ([0-9.]+).*/\1/p')
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/k1"
cp -r "$ROOT/src" "$TMP/k1/src"
cp -r "$ROOT/tools" "$TMP/k1/tools"
sed -i -E 's/^local REAL_SPEED_SCALE = [0-9.]+/local REAL_SPEED_SCALE = 1/' "$TMP/k1/src/shared/Config/Balance.luau"
emit() {
	awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
config() { # <racine> <K attendu> <fichier de sortie>
	local src="$1/src" T="$1/tools/ironix/equilibrage"
	{
		echo "--!nocheck"
		echo "SOURCES = {}"
		echo 'OPTIONS = { Graines = 1, Heures = 1, Rapport = "v2", Court = true }'
		for f in "$src"/shared/Config/*.luau; do emit "Config/$(basename "$f" .luau)" "$f"; done
		emit "Format" "$src/shared/Format.luau"
		emit "Net/Definitions" "$src/shared/Net/Definitions.luau"
		emit "Net/RateLimiter" "$src/shared/Net/RateLimiter.luau"
		for m in proposition_v2 modele; do emit "Outil/$m" "$T/$m.luau"; done
		tr -d '\r' < "$T/chargeur.luau" | grep -v '^charge(if OPTIONS'
		echo "EXPECTED_K = $2"
		tr -d '\r' < "$H/tests.config.luau"
	} > "$3.luau"
	"$LUAU" "$(cygpath -w "$3.luau")" > "$3.txt" 2>&1
}
chase() { # <racine> <fichier de sortie>
	if grep -q "ShelfOpen = true" "$1/src/shared/Config/Features.luau" 2>/dev/null; then
		bash "$H/chase/chase.sh" "$1" > "$2" 2>&1
	else
		bash "$H/../a172-banc/corrige.sh" a168 bash "$H/chase/chase.sh" "$1" > "$2" 2>&1
	fi
}
config "$ROOT" "$K" "$TMP/cfg" &
config "$TMP/k1" 1 "$TMP/cfg1" &
chase "$ROOT" "$TMP/chase.txt" &
chase "$TMP/k1" "$TMP/chase1.txt" &
wait
checks=0
fails=0
tally() { # <fichier> <motif de la ligne de résumé> <titre>
	local line c f
	line=$(grep -E "$2" "$1" | tail -1)
	echo "--- $3"
	grep -E "ÉCHEC|ERREUR|rror|^  mesure|échelle K" "$1" | head -40 || true
	if [ -z "$line" ]; then
		echo "ERREUR : $3 n'a pas fini"
		tail -8 "$1"
		fails=$((fails + 1))
		return
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "$line"
	checks=$((checks + c))
	fails=$((fails + f))
}
tally "$TMP/cfg.txt" "^banc a198 config" "Config, K = $K"
tally "$TMP/cfg1.txt" "^banc a198 config" "Config, K = 1"
tally "$TMP/chase.txt" "^poursuite : [0-9]+ vérification" "poursuite, K = $K"
tally "$TMP/chase1.txt" "^poursuite : [0-9]+ vérification" "poursuite, K = 1"
echo "banc a198 (vitesse réelle à l'échelle, zone 1 à 15 PV) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
