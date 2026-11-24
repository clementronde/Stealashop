#!/usr/bin/env bash
# Banc hors Studio d'a213 (vague 64, Cantin : « les gains de vitesse se déplacent vers lui ») : chaque « +X » du tapis
# jaillit du joueur et vole jusqu'au compteur Speed du HUD (Config/Hud.TrainGainFly, GainController, HudController.HoldSpeed).
#   fly       trajet en 3 temps (taille pleine à 0,08 s, jet de 15 à 18 % de l'écran à 0,33 s, pause jusqu'à 1,03 s,
#             aspiré jusqu'au nombre Speed à 1,18 s en rétrécissant) ; nombre Speed retenu jusqu'à l'arrivée puis monté,
#             pulsation à l'arrivée ; un par seconde sur 3 s, même total ; « ×2 » du trail et base avec le trail ;
#             rien hors du tapis ; GainController.FlyGain (a214)
#   reduced   VISUAL EFFECTS sur OFF (VfxEnabled = false) ou ReducedMotionEnabled : l'ancien « +X » sur place, nombre tout de suite
#   chase     poursuite : le gain du tapis vole quand même (fusion58, Cantin : tapis en zone safe, plus de repli)
#   template  modèle facultatif de Clément UI_HUD.TrainGainFly.Template : copié, couleur de son attribut, modèle intact
#   pieces    ChunksPerSecond = 4 (copie des sources) : 4 morceaux qui volent, même total, nombre qui monte morceau par morceau
# Faux Roblox : celui du banc a60 (copie a134) + quint.sed et setup190.luau de la copie a205 du banc a190, lus sur place.
# Sur un arbre sans Config/Hud.TrainGainFly (avant a213) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-fly reduced chase template pieces}"
B="$(cd "$H/.." && pwd)"
A60="$B/a134-banc/autres-bancs/a60"
A190="$B/a205-banc/autres-bancs/a190"
if ! grep -q "TrainGainFly" "$SRC/shared/Config/Hud.luau" 2>/dev/null; then
	echo "banc a213 (gains du tapis qui volent) : SAUTÉ, a213 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A60/stubs.luau"
		sed -E -f "$A190/patches/quint.sed" "$A60/ext-motion.luau"
		cat "$A60/ext-a60.luau" "$B/a155-banc/ext-tohex.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$A60/setup.luau" "$A60/setup-a60.luau" "$A190/setup190.luau" "$H/setup213.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a213 (gains du tapis qui volent) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
