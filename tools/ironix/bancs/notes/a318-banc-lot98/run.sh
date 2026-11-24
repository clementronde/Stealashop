#!/usr/bin/env bash
# Copie lot98 (petit chef 3) : fake.luau avec Players.PlayerAdded et PlayerRemoving (la partie reveal n'avait jamais tourné).
# Banc a318 (2026-11-23, L-300 : charger moins loin, StreamingTargetRadius baissé, magasins et boutiques en Atomic) :
# un modèle tagué sort du streaming (Parent = nil, le même objet revient) puis revient, plusieurs fois, en gardant ou
# en perdant les changements locaux. Faux Roblox à part (fake.luau : CollectionService qui annonce sortie et retour,
# signaux qui comptent leurs connexions), vrais modules du dépôt (shared/ et client/Controllers/ en entier, Net bouchonné).
# Parties :
#   plotdoor   PlotDoorController : une seule écoute du propriétaire par boutique, murs et porte traversables au retour.
#   trap       TrapController : une seule écoute par piège, effets de Armed revenus au réarmement après un retour.
#   sky        SkyController : lampadaire sorti allumé puis revenu de jour = éteint ; revenu de nuit = allumé.
#   storelock  StoreLockController : vrai rideau recaché au retour même s'il a perdu son LocalTransparencyModifier.
#   reveal     RevealController : une seule écoute de CeilingBroken par magasin, plafond recaché au retour.
#   display    DisplayController : une seule écoute du propriétaire par boutique, caisse relue au retour.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a318)
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a318}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
inline() {
	(cd "$SRC" && find shared client/Controllers -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
inline > "$TMP/sources.luau"
total=0; fails=0
for part in ${PARTS:-plotdoor trap sky storelock reveal display}; do
	cat "$ME/fake.luau" "$TMP/sources.luau" "$ME/prelude.luau" "$ME/tests-$part.luau" > "$TMP/$part.luau"
	out=$("$LUAU" "$(cygpath -w "$TMP/$part.luau")" 2>&1)
	if [ -n "${DETAIL:-}" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|Error" | head -20; fi
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "partie $part : arrêtée avant la fin"; fails=$((fails + 1)); continue; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
echo "banc a318 (streaming : sortie et retour des modèles tagués) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
