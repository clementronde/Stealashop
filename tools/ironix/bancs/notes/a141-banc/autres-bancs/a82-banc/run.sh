#!/usr/bin/env bash
# Copie a141 (2026-11-14, L-142) : flash Police à 2 au lieu de 6, WingLight du Gold à 1,2 (Max 2,2 → 1,2 de Clément) ; le reste tel quel.
# Copie d'a90 (2026-11-12, vague 29, L-106 points 7 et 11) : tapis au repos (bande à IdleBeltSpeed sans
# coureur) et variante Void (RunBurst allumé en course). Passe 1 : les tests d'a82 tels quels, avec
# IdleBeltSpeed mis à 0 dans la copie de Config/TreadmillFX (l'ancien « rien d'écrit sans coureur ») ;
# passe 2 : tests.a90.luau avec la vraie Config. Faux Roblox d'a82 complété (FindFirstChild récursif,
# GetDescendants). Sur un arbre sans IdleBeltSpeed : passe 1 seule (bonne avant et après la fusion).
# Banc hors Studio d'a82 (vague 26, 2026-11-11, L-093 question 3, L-097 point 2) : TreadmillFxController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
# Arbre sans les valeurs L-142 (avant a141) : la copie a90 d origine, telle quelle (bonne avant et après la fusion).
if ! grep -q "LightOn = 2," "$SRC/shared/Config/TreadmillFX.luau" 2>/dev/null; then exec bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a90-banc/autres-bancs/a82-banc/run.sh" "$ROOT"; fi
CTL="$SRC/client/Controllers/TreadmillFxController.luau"
if [ ! -f "$CTL" ]; then
	echo "banc a82 (tapis animés) : SAUTÉ, pas de TreadmillFxController (a82 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
emit() { # nom fichier
	local c
	c=$(tr -d '\r' < "$2")
	printf '%s = [==========[\n%s\n]==========]\n' "$1" "$c"
}
build() { # sortie, dossier de config, fichier de tests
	{
		echo "SOURCES = {}"
		for m in DeepFreeze Music Settings TreadmillFX; do
			emit "SOURCES[\"shared/Config/$m.luau\"]" "$2/$m.luau"
		done
		emit "SOURCE" "$CTL"
		cat "$H/harness.luau" "$3"
	} > "$1"
}
mkdir -p "$TMP/cfg0"
cp "$SRC/shared/Config/DeepFreeze.luau" "$SRC/shared/Config/Music.luau" "$SRC/shared/Config/Settings.luau" "$TMP/cfg0/"
sed -E 's/IdleBeltSpeed = [0-9.]+/IdleBeltSpeed = 0/' "$SRC/shared/Config/TreadmillFX.luau" > "$TMP/cfg0/TreadmillFX.luau"
run() { # fichier luau -> sortie
	local W="$1"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$1")"; fi
	"$HOME/.rokit/bin/luau.exe" "$W" 2>&1 || true
}
build "$TMP/run1.luau" "$TMP/cfg0" "$H/tests.luau"
out=$(run "$TMP/run1.luau")
if grep -q "IdleBeltSpeed" "$SRC/shared/Config/TreadmillFX.luau"; then
	build "$TMP/run2.luau" "$SRC/shared/Config" "$H/tests.a90.luau"
	out="$out
$(run "$TMP/run2.luau")"
fi
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" || true
if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -40; fi
lines=$(printf '%s\n' "$out" | grep -E "^banc a(82|90) \([^)]*\) : [0-9]+ vérification")
n1=$(printf '%s\n' "$lines" | grep -c "^banc a82")
if [ "$n1" -lt 1 ]; then printf '%s\n' "$out" | tail -20; echo "banc a82 (tapis animés) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"; exit 1; fi
if grep -q "IdleBeltSpeed" "$SRC/shared/Config/TreadmillFX.luau" && ! printf '%s\n' "$lines" | grep -q "^banc a90"; then
	printf '%s\n' "$out" | tail -20; echo "banc a82 (tapis animés) : passe a90 arrêtée avant la fin : 0 vérification(s), 1 échec(s)"; exit 1
fi
checks=$(printf '%s\n' "$lines" | sed -E 's/.* : ([0-9]+) vérification.*/\1/' | awk '{ s += $1 } END { print s + 0 }')
fails=$(printf '%s\n' "$lines" | sed -E 's/.*, ([0-9]+) échec.*/\1/' | awk '{ s += $1 } END { print s + 0 }')
line="banc a82 (tapis animés, repos et Void d'a90) : $checks vérification(s), $fails échec(s)"
echo "$line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
