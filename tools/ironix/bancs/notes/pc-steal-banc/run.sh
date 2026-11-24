#!/usr/bin/env bash
# Banc hors Studio de pc-steal (2026-11-14) : l'invite « Steal » d'un objet sorti d'un colis s'allumait à
# 37,5 studs. Model:ScaleTo agrandit aussi MaxActivationDistance des invites du modèle : l'objet sort à 0,2
# de sa taille (ShelfOpenController), une invite posée à ce moment (7,5) passait à 7,5 × 5 = 37,5 au retour à 1.
# Vrais HeistController, Config, ShelfOpenState… sur le faux Roblox du banc a104 (copie a116), lu sur place,
# complété par ext.luau (ScaleTo qui agrandit les invites comme le moteur, GetPropertyChangedSignal) ; mise en
# place : début de tests.luau du même banc (arbre, joueur, magasin, rayon). Objets normal, Huge et Colossal.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
#   FORCE=1 : lancer même sur un arbre sans le correctif (montre 37,5).
# Arbre sans le correctif (pas de GetPropertyChangedSignal("MaxActivationDistance") dans HeistController) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc pc-steal"
A104="$H/../a116-banc/autres-bancs/a104-banc"
if [ "${FORCE:-}" != "1" ] && ! grep -q 'GetPropertyChangedSignal("MaxActivationDistance")' "$SRC/client/Controllers/HeistController.luau" 2>/dev/null; then
	echo "$NAME (portée de l'invite de l'objet sorti) : SAUTÉ, pas de correctif pc-steal dans cet arbre : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/HeistController.luau client/Controllers/ShelfOpenController.luau client/Controllers/ShelfOpen/Logic.luau shared/ShelfOpenState.luau shared/Format.luau shared/Contract/Find.luau"
for m in DeepFreeze ShelfOpen Items Rarities Mutations Balance Features; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SHELF_OPEN = true"
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$A104/harness.luau"
	tr -d '\r' < "$H/ext.luau"
	echo "local function __tests()"
	tr -d '\r' < "$A104/tests.luau" | sed -n '1,219p'
	tr -d '\r' < "$H/tests.luau"
	echo "end"
	echo "local ok, err = pcall(__tests)"
	echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
	echo "finish('$NAME')"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$LUAU" "$W" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME (portée de l'invite de l'objet sorti) : arrêté avant la fin (erreur ci-dessus)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
# Garde-fou (suite de pc-steal, 2026-11-14) : appels Model:ScaleTo côté client, relus un par un. Aucun autre ne
# touche un modèle qui porte une invite du code : MutationFx (copies sans invite, cleanCopy ; extras de Clément),
# Potion (popup de ramassage, pas d'invite), ShelfOpen (colis : invite sur l'Attachment du rayon ; objet : corrigé),
# AntiTheftChains (cadenas de Clément), Reel et Screen (copies locales sans invite), Vfx (copies sans invite).
# Les objets exposés (Huge, Colossal) sont mis à l'échelle par le serveur, avant d'arriver chez le client.
# Un appel nouveau ou retiré fait échouer ce contrôle : le relire, puis mettre la liste à jour.
WANT_SCALE="1 AntiTheftChains.luau|2 MutationFxController.luau|1 PotionController.luau|1 Reel.luau|1 Screen.luau|4 ShelfOpenController.luau|1 VfxController.luau"
GOT_SCALE=$(cd "$SRC/client" && grep -rn ":ScaleTo(" . | grep -vE "^[^:]*:[0-9]+:\s*--" | awk -F: '{n = split($1, p, "/"); print p[n]}' | sort | uniq -c | awk '{print $1 " " $2}' | paste -sd'|')
c=$((c + 1))
if [ "$GOT_SCALE" = "$WANT_SCALE" ]; then
	if [ "${VERBOSE:-}" = "1" ]; then echo "  ok garde-fou : appels ScaleTo côté client relus ($GOT_SCALE)"; fi
else
	echo "  ÉCHEC garde-fou : appels ScaleTo côté client changés, à relire (invites ?) : $GOT_SCALE (relus : $WANT_SCALE)"
	f=$((f + 1))
fi
echo "$NAME (portée de l'invite de l'objet sorti) : $c vérification(s), $f échec(s)"
exit $((f > 0))
