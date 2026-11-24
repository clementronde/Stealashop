#!/usr/bin/env bash
# Banc a301 (21/11, demande de Cantin : « espionner » la vitrine d'un autre joueur depuis la rue) : ShopSpyController
# sur un petit faux Roblox (fake.luau) avec les vrais Config/DeepFreeze, Config/Features et Config/ShopSpy du dépôt.
# Scénarios (tests.luau) : loin rien ; rue près de la façade, BB_Item des objets exposés par-dessus (AlwaysOnTop sur la
# copie) ; MaxDistance gardée ; objets au sol et modèles sans tag pas touchés ; ma boutique jamais ; objet posé ou
# repris pendant l'espionnage ; bord de la portée ; côté de la boutique ; dedans comme avant ; sans personnage ; valeur
# d'origine rendue ; boutique devenue la mienne ; tag retiré ; bot ; Features.ShopSpy = false.
# Arbre sans a301 (pas de ShopSpyController) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/client/Controllers/ShopSpyController.luau" ]; then
	echo "banc a301 (espionner la vitrine depuis la rue) : SAUTÉ, pas de ShopSpyController dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.a301.luau"
emit() { # emit <clé> <fichier>
	awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
	echo "--!nocheck"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for n in DeepFreeze Features ShopSpy; do emit "Config/$n" "$SRC/shared/Config/$n.luau"; done
	emit "Client/ShopSpyController" "$SRC/client/Controllers/ShopSpyController.luau"
	tr -d '\r' < "$H/fake.luau"
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -vE "^ok " || true; fi
if ! printf '%s\n' "$out" | grep -qE "^banc a301 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"; then
	echo "banc a301 (espionner la vitrine depuis la rue) : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
printf '%s\n' "$out" | grep -qE "^banc a301 .*: [0-9]+ vérification\(s\), 0 échec\(s\)$"
