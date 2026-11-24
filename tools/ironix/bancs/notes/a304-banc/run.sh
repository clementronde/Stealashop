#!/usr/bin/env bash
# Banc hors Studio d'a304 (21/11, Cantin : bouton Equip de la boutique d'armes ; cases qui poppent dès l'ouverture).
#   - equip : faux Roblox du banc a50 (a186, a189 : tweens simulés, MouseEnter/MouseLeave), tests.equip.luau : style du
#     bouton Equip de Clément gardé (achetable, possédée, équipée, pendant et après le survol) ;
#   - pop : même faux Roblox, tests.pop.luau : cases à 0 dès l'ouverture, pop sans attente, retour exact au repos.
# Arbre sans a304 (Appear.Cascade.From pas à 0 dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/.."
B="$N/a50-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a304 (bouton Equip, pop d'ouverture)"
if ! grep -q "From = 0, -- validé par Cantin, 21/11 (a304)" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de pop immédiat dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"
total=0; fails=0
for part in equip pop; do
	OUT="$R1_D/run.$part.luau"
	{
		echo "WITH_COSMETIC = true"
		cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$N/a186-banc/ext-a186.luau" "$N/a189-banc/ext-a189.luau"
		sources
		cat "$H/prelude.luau" "$B/setup.luau" "$H/tests.$part.luau"
	} > "$OUT"
	out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "$NAME $part : arrêté avant la fin (erreur ci-dessus)"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	echo "$part : $line"
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
echo "$NAME : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
