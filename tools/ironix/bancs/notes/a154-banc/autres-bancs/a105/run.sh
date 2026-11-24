#!/usr/bin/env bash
# Copie a154 (2026-11-14, vague 46 : objet ramené en zone safe = remote ItemSecured(itemId) au lieu de BoxSecured) : tests.arrive.luau, ligne 45 ; faite sur la copie a146, avec place et client de la copie a152 quand a152 est fusionné (TakeDisplayItem). Sans ItemSecured dans Net/Definitions, lance la copie a152.
# Copie a146 (2026-11-14, vague 41, audit de sécurité : contrôle du dépôt plafonné à 24 studs/s) : dans tests.steal.luau, le
# banc attend 20 s au lieu de 4 avant de poser Bob d'un coup sur son dépôt (sinon le contrôle du dépôt rend l'objet). Sans
# CarrierPushFactor dans Config/AntiCheat, lance le banc d'a105.
# Banc hors Studio d'a105 (vague 31, 2026-11-12, L-112 : base de l'ouverture des colis sur le rayon,
# Features.ShelfOpen) : l'objet porté (payload NPCItem) entre dans l'inventaire sous antivol à l'entrée de la
# zone safe ; posé au sol de sa boutique (PlaceBox), son antivol démarre (Config/ShelfOpen.AntiTheft) ; il est
# volable pendant l'antivol (vrai PvPService, StealFloorItem) et refusé par les présentoirs ; fini, il se reprend
# (OpenBox) et va sur un présentoir ; conversion des colis des profils (DataService) ; Fast Open et Ouvrir
# maintenant sur l'antivol (MonetizationService, décision de Cantin du 2026-11-12) ; BB_AntiTheft et invites
# (UnboxController), pose depuis l'inventaire (InventoryController) ; interrupteur coupé.
# Faux Roblox et mise en place d'a51 (stubs, ext29, ext38, ext46, ext51, setup), complétés par ext105.luau
# (CarryService.StartCarry, WindowService du banc, vrai PvPService, DepositZone, aides).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-arrive place steal convert robux norobux client off}"
if ! grep -q "\"ItemSecured\"" "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	exec bash "$H/../../../a152-banc/autres-bancs/a105/run.sh" "$ROOT" "$@"
fi
if ! grep -q "CarrierPushFactor" "$SRC/shared/Config/AntiCheat.luau" 2>/dev/null; then
	exec bash "$H/../../../a105-banc/run.sh" "$ROOT" "$@"
fi
if [ ! -f "$SRC/shared/Config/ShelfOpen.luau" ] || ! grep -q "StealFloorItem" "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "banc a105 (antivol en base) : SAUTÉ, vague 31 (a105) pas encore fusionnée : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

# Copie a154 : avec a152 fusionné (TakeDisplayItem), place et client sont ceux de la copie a152 (seul arrive change ici).
testsFor() {
	if { [ "$1" = "place" ] || [ "$1" = "client" ]; } && grep -q "TakeDisplayItem" "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
		echo "$H/../../../a152-banc/autres-bancs/a105/tests.$1.luau"
	else
		echo "$H/tests.$1.luau"
	fi
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/ext46.luau" "$H/stub-anticheat.luau" "$H/ext51.luau"
		sources
		cat "$H/features.luau" "$H/pre.on.luau"
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau" "$H/ext105.luau" "$(testsFor "$name")"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
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
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a105 (antivol en base) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
