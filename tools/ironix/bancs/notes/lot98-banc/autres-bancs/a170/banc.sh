#!/usr/bin/env bash
# lot98-commun (petit chef 2) : copie de a170-banc/run.sh ; DropCarried n est plus attendu dans Net/Definitions (a415), il doit en être absent.
# Banc hors Studio d'a170 (vague 52, 2026-11-15, lot D de la vague 48 : fin du colis porté côté client et contrat).
#   static   : plus aucune référence (hors commentaires) aux remotes retirés BoxReady, UnboxReveal, BoxSecured, ni à
#              HoldIncome, InventoryState Boxes/BoxEntry, Unbox/Screen, Sequence, Reel ; chaque Net.Client.X et
#              Net.Server.X du code existe dans Net/Definitions ; PlaceBox, OpenBox, StealFloorItem, ItemSecured gardés.
#   contract : vrai ContractChecker sur le faux Roblox du banc a39 (copie a95), avec les restes d'un arbre de Studio
#              d'aujourd'hui (UI_Unbox, BB_OpenTimer, animations Unbox et Celebrate, UI_Inventory.Tabs.BoxesTab et
#              BoxesSection) : des notes « peut être retiré », jamais un problème ; contrat OK sans UI_Inventory.
# Sur un arbre qui a encore le remote BoxReady (avant a170) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")/../../../a170-banc" && pwd)" # lot98-commun : copie, les fichiers du banc restent dans a170-banc
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-static contract}"
NAME="banc a170 (fin du colis porté : client et contrat)"
if grep -q 'Name = "BoxReady"' "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, a170 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A39="$H/../a95-banc/autres-bancs/a39-banc"
FILES39="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
# Lignes de code (hors commentaires) de src qui contiennent le motif étendu $1.
code() {
	(cd "$SRC" && grep -rnE "$1" --include=*.luau . | tr -d '\r' | grep -vE ':[0-9]+:[[:space:]]*--')
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	if [ "$name" = "static" ]; then
		c=0
		f=0
		for word in BoxReady UnboxReveal BoxSecured HoldIncome BoxEntry '\.Boxes = #' 'WaitForChild\("Screen"\)' 'WaitForChild\("Sequence"\)' 'WaitForChild\("Reel"\)'; do
			hits=$(code "$word")
			c=$((c + 1))
			if [ -n "$hits" ]; then
				f=$((f + 1))
				echo "  ÉCHEC encore $word : $(printf '%s' "$hits" | head -3 | tr '\n' ' ')"
			elif [ "${VERBOSE:-}" = "1" ]; then
				echo "  ok   plus de $word dans le code"
			fi
		done
		defs=$(tr -d '\r' < "$SRC/shared/Net/Definitions.luau" | awk '/Name = "/{n=$0; getline; if ($0 ~ /Direction/) {gsub(/.*Name = "|".*/,"",n); print n}}')
		for keep in PlaceBox OpenBox StealFloorItem ItemSecured GrabDropped; do # lot98-commun : DropCarried retiré par a415 (contrôlé plus bas)
			c=$((c + 1))
			if ! printf '%s\n' "$defs" | grep -qx "$keep"; then
				f=$((f + 1))
				echo "  ÉCHEC remote $keep retiré"
			fi
		done
		# lot98-commun (a415, demande de Cantin) : le lâcher volontaire est retiré, le remote DropCarried aussi.
		c=$((c + 1))
		if printf "%s\n" "$defs" | grep -qx DropCarried; then
			f=$((f + 1))
			echo "  ÉCHEC remote DropCarried encore là (retiré par a415)"
		fi
		used=$(cd "$SRC" && grep -rhoE "[Nn]et\.(Client|Server)\.[A-Za-z]+" --include=*.luau . | sed -E 's/.*\.//' | sort -u)
		missing=""
		for r in $used; do
			if ! printf '%s\n' "$defs" | grep -qx "$r"; then missing="$missing $r"; fi
		done
		c=$((c + 1))
		if [ -n "$missing" ]; then
			f=$((f + 1))
			echo "  ÉCHEC remotes inconnus de Net/Definitions :$missing"
		fi
		for gone in Screen Sequence Reel; do
			c=$((c + 1))
			if [ -f "$SRC/client/Controllers/Unbox/$gone.luau" ]; then
				f=$((f + 1))
				echo "  ÉCHEC Unbox/$gone.luau encore là"
			fi
		done
		c=$((c + 1))
		if [ ! -f "$SRC/client/Controllers/Unbox/AntiTheftChains.luau" ]; then
			f=$((f + 1))
			echo "  ÉCHEC Unbox/AntiTheftChains.luau retiré"
		fi
		echo "  $name : $c contrôles, $f raté(s)"
		total_checks=$((total_checks + c))
		total_fails=$((total_fails + f))
		continue
	fi
	if [ "$name" != "contract" ]; then
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue
	fi
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A39/stubs.luau" "$A39/ext29.luau" "$A39/ext38.luau"
		sources "$FILES39"
		cat "$A39/setup.luau"
		cat "$H/tests.contract.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^scénario .* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$NAME : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
