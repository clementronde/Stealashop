#!/usr/bin/env bash
# Banc hors Studio d'a188 (2026-11-15, vague 58, L-170 Q7) : la pluie d'objets, événement live du samedi
# (ItemRainService, Config/ItemRain, format ItemRain de Config/LiveEvents, CarryService.PlaceItemDrop,
# StoreHeistService.DrawForZone).
# Faux Roblox et mise en place : ceux du banc a109 copie a134 (base a30 copie a66 : vrais BatService, CarryService,
# GuardService, StoreHeistService, WindowService, Net ; carte avec hub en zone safe et magasins face à face), puis
# head.luau d'ici (vrai ItemRainService, bouchon TelemetryService, rues « Street », relevé des objets tombés).
# L'événement est lancé en posant les attributs LiveEvent et LiveEventEndsAt du Workspace (ce que fait EventService,
# vérifié par le banc a167).
#   draw   format et valeurs (aucune date), DrawForZone (zone 1 : caisse Commune ; zone 2 ; tirages libres),
#          PlaceItemDrop (refus, attributs, durée au sol)
#   rain   rien sans événement ; début (annonce, premier objet, chute) ; nuit ; fin (annonce, plus rien ne tombe,
#          disparition au bout de Lifetime) ; rythme et plafond ; lieu (rue, marges, jamais en zone safe ni sous une
#          arche, espacement, zone du magasin le plus proche) ; tirage de la bonne zone ; ramassage (GrabDropped),
#          port sans vigile, télémétrie, lâcher, objet perdu
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)   VERBOSE=1 : sortie complète
# « SAUTÉ » sans ItemRainService.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a188 (pluie d'objets)"
if [ ! -f "$SRC/server/Services/ItemRainService.luau" ]; then
	echo "$LABEL : SAUTÉ, pas d'ItemRainService : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-draw rain}"
BASE="$N/a66-banc/autres-bancs/a30-banc"
A109="$N/a134-banc/autres-bancs/a109"
HEAD103="$N/a135-banc/autres-bancs/a109-banc/autres-bancs/a103-banc/head.luau"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau server/Services/ItemRainService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	if [ ! -f "$H/tests.$name.luau" ]; then
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue
	fi
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$BASE/stubs.luau"
		cat "$BASE/../stub-anticheat.luau"
		sources
		cat "$N/a134-banc/levier-force.luau" "$N/a134-banc/coups-en-rafale.luau" "$N/a135-banc/autres-bancs/heist-13s.luau"
		cat "$BASE/setup.luau"
		cat "$HEAD103"
		cat "$A109/head.luau"
		cat "$H/head.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	# Les aides copiées portaient encore des colis fermés : même correction que les bancs repris par a158.
	sed -E -i -f "$N/a158-banc/patches/commun.sed" "$OUT"
	W="$OUT"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
	out=$("$LUAU" "$W" 2>&1)
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
