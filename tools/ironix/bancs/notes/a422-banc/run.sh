#!/usr/bin/env bash
# Copie a422 (24/11, Cantin : le son de la plaque part au contact) : 3e partie « contact » ajoutée (tests.contact.luau) :
#   la config du JEU (pas de rallume.pl : Config/CashFlash allumé, CollectFeel coupé), mêmes sources et même faux Roblox
#   que la 1re partie ; un seul son par plaque, à l'image du contact, avec ou sans Cash_Pad ; gains hors ligne ouverts et
#   encaissement automatique : Cash_Collect comme avant. Les parties 1 et 2 sont celles du lot98, inchangées.
# Copie lot98 (petit chef 3) : attentes A1d, A1n, A5a mises à L-299 (TickSemitones = 0, Glow = "") ; rallume.pl : CollectFeel rallumé et CashFlash coupé dans son arbre (a401 coupé dans le jeu, L-299 fait par a317).
# Banc hors Studio d'a401 (vague GC4, 23/11 : encaissement de la vidéo de Cantin), deux parties :
#   1. CollectFeelController (chiffre retenu jusqu'à la 1re arrivée de billet, pop de CashRow, Cash_Collect, tics de plus
#      en plus aigus, vignette CollectGlow, sons facultatifs, secours sans billets, deux plaques à la suite), billets en
#      fontaine de VfxController (sortie un par un, arrivées signalées dans l'ordre), entrée et sortie du « +$X » de
#      GainController. Faux Roblox : celui du banc a80 (copie d’a62 du banc a60 + ext-a75.luau + ext-a80.luau)
#      + ext-a401.luau (courbe Sine) ; pre-a401.luau : la case qui vole reste coupée, comme dans le jeu (setup.luau
#      du banc a60 la rallume).
#   2. la plaque au ramassage (vrai DisplayController, Config/Vfx.CollectPad) : flash, Glow en fondu, enfoncement animé,
#      retour exact, pas d'empilement. Faux Roblox du banc a14 (copie a141) + TweenService d'ext-plaque.luau (plaque-pre.luau
#      et une ligne ajoutée à la liste des services), décor du banc a59 (preamble.luau), tests.plaque.luau.
# « SAUTÉ » sur un arbre sans CollectFeelController.
#   bash run.sh [racine du dépôt]      VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../a62-banc/autres-bancs/a60-banc"
A75="$H/../a75-banc"
A80="$H/../a80-banc"
A14="$H/../a141-banc/autres-bancs/a14-banc"
A59="$H/../a141-banc/autres-bancs/a59-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/client/Controllers/CollectFeelController.luau" ]; then
	echo "banc a401 (encaissement de la vidéo) : SAUTÉ, pas de CollectFeelController (a401 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
sources() {
	(cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
head1() {
	cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau" "$A80/ext-a80.luau" "$H/ext-a401.luau"
	sources shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau client/Controllers/VfxController.luau client/Controllers/CollectFeelController.luau
	cat "$H/pre-a401.luau" "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau"
}
OUT1="$TMP/run.a401.luau"
{
	head1
	cat "$H/tests.a401.luau"
} > "$OUT1"
perl -i "$H/rallume.pl" "$OUT1" # lot98 : a401 rallumé, CashFlash coupé (copie du banc seulement)
OUT2="$TMP/run.plaque.luau"
{
	cat "$H/plaque-pre.luau"
	perl -pe 's/^(\s*)CollectionService = CollectionServiceStub,\r?\n/$&$1TweenService = A401_TWEEN_PROXY, -- a401 (plaque-pre.luau)\n/' "$A14/stubs.luau"
	cat "$H/ext-plaque.luau"
	sources shared server/Services/DisplayService.luau client/Controllers/DisplayController.luau
	cat "$A59/preamble.luau" "$H/tests.plaque.luau"
} > "$OUT2"
OUT3="$TMP/run.contact.luau" # a422 : config du jeu, sans rallume.pl
{
	head1
	cat "$H/tests.contact.luau"
} > "$OUT3"
out1=$("$LUAU" "$(cygpath -w "$OUT1")" 2>&1)
out2=$("$LUAU" "$(cygpath -w "$OUT2")" 2>&1)
out3=$("$LUAU" "$(cygpath -w "$OUT3")" 2>&1)
out="$(printf '%s\n%s\n%s\n' "$out1" "$out2" "$out3")"
if [ -n "${A401_LOG:-}" ]; then printf '%s\n' "$out" > "$A401_LOG"; fi # sortie entière, pour déboguer
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
l1=$(printf '%s\n' "$out1" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
l2=$(printf '%s\n' "$out2" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
l3=$(printf '%s\n' "$out3" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$l1" ] || [ -z "$l2" ] || [ -z "$l3" ]; then
	if [ -z "$l1" ]; then printf '%s\n' "$out1" | tail -25; fi
	if [ -z "$l2" ]; then printf '%s\n' "$out2" | tail -25; fi
	if [ -z "$l3" ]; then printf '%s\n' "$out3" | tail -25; fi
	echo "banc a401 (encaissement de la vidéo) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c1=${l1%% *}; f1=$(printf '%s' "$l1" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
c2=${l2%% *}; f2=$(printf '%s' "$l2" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
c3=${l3%% *}; f3=$(printf '%s' "$l3" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "  encaissement : $c1 contrôle(s), $f1 raté(s) ; plaque : $c2 contrôle(s), $f2 raté(s) ; contact (a422) : $c3 contrôle(s), $f3 raté(s)"
echo "banc a401 (encaissement de la vidéo) : $((c1 + c2 + c3)) vérification(s), $((f1 + f2 + f3)) échec(s)"
exit $(((f1 + f2 + f3) > 0))
