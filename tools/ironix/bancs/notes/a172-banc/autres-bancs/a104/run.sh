#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : copie de lanceur d'a154-banc/autres-bancs/a104 (harness.luau et tests.luau lus là-bas) : le passage
# Features.ShelfOpen = false (ancien comportement) n'a plus d'objet, l'interrupteur est parti ; seul le passage « true » reste.
# Arbre avec Features.ShelfOpen : le banc tel quel.
if grep -q "ShelfOpen = true" "${1:-/f/StealAShop}/src/shared/Config/Features.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a154-banc/autres-bancs/a104/run.sh" "$@"; fi
# Copie a154 (2026-11-14, vague 46) : faux UiFeelController dans Controllers ; 3 contrôles de plus : RevealFlash à la sortie chez l ouvreur (B sans objet, A avec), jamais chez les autres (D). Sans RevealFlash dans UiFeelController, lance la copie pc-steal.
# Copie pc-steal (2026-11-14) : harness.luau = celui de la copie a116 + GetPropertyChangedSignal (pc-steal-banc/ext-signal.luau), que HeistController utilise pour la portée de l'invite de l'objet sorti. Tests inchangés.
# Copie a116 (2026-11-13, Cantin : ouvrir un colis en RESTANT APPUYÉ) : HeistController, invite « Open » avec
# HoldDuration = GrabTime du type, OpenShelfBox au début (PromptButtonHoldBegan) puis à la fin (Triggered).
# Banc hors Studio d'a104 (vague 31, 2026-11-12, liaison L-112 : ouverture des colis dans le magasin, côté client).
# Vrais HeistController, ShelfOpenController, ShelfOpen/Logic, Shared/ShelfOpenState, Config (ShelfOpen, Items,
# Rarities, Mutations, Balance, Features), Format, Contract/Find, sur un faux Roblox autonome (harness.luau :
# CFrame à rotation complète, modèles, ScaleTo, CollectionService, temps simulé) ; bouchons : Net, MarkerSounds,
# ShelfBoxController.Reserve. Deux passages : Features.ShelfOpen vrai (logique : compteur, tics, échelle,
# rabats ou Lid, mutation, voile, réservation ; invites « Open » et prise de l'objet sorti ; ouverture
# complète : rabats, lumière, compteur, police, sortie, BB_Item, nettoyage, annulation) puis faux (ancien
# comportement exact). « SAUTÉ » sans ShelfOpenController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")/../../../a154-banc/autres-bancs/a104" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a104"
if ! grep -q "RevealFlash" "$SRC/client/Controllers/UiFeelController.luau" 2>/dev/null; then
	exec bash "$H/../../../pc-steal-banc/autres-bancs/a104-banc/run.sh" "$ROOT"
fi
if [ ! -f "$SRC/client/Controllers/ShelfOpenController.luau" ]; then
	echo "$NAME (ouverture sur le rayon) : SAUTÉ, pas de ShelfOpenController (a104 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/HeistController.luau client/Controllers/ShelfOpenController.luau client/Controllers/ShelfOpen/Logic.luau shared/ShelfOpenState.luau shared/Format.luau shared/Contract/Find.luau"
for m in DeepFreeze ShelfOpen Items Rarities Mutations Balance Features; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; failed=0
for pass in true; do
	OUT="$TMP/run.$pass.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
		echo "SHELF_OPEN = $pass"
		echo "SOURCES = {}"
		printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		tr -d '\r' < "$H/harness.luau"
		echo "local function __tests()"
		tr -d '\r' < "$H/tests.luau"
		echo "end"
		echo "local ok, err = pcall(__tests)"
		echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
		echo "finish('$NAME ShelfOpen=$pass')"
	} > "$OUT"
	W="$OUT"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
	out=$("$LUAU" "$W" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^$NAME ShelfOpen=$pass : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		failed=$((failed + 1)); continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  ShelfOpen=$pass : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
echo "$NAME (ouverture sur le rayon) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
