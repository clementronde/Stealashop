#!/usr/bin/env bash
# Banc hors Studio d'a82 (vague 26, 2026-11-11, L-093 question 3, L-097 point 2) : TreadmillFxController
# anime les tapis PLOT_Treadmill_<Variante> pendant la course seulement : défilement de BeltTexture,
# effets de la variante (Police, Gold, Candy, LaserVault), changement de modèle suivi, VISUAL EFFECTS OFF
# (bande seule), distance à la caméra, autre joueur, streaming, rien d'animé ni écrit sans coureur.
# Faux Roblox autonome (harness.luau, Vector3/CFrame repris d'a72), vrais modules Config (DeepFreeze,
# Music, Settings, TreadmillFX). « SAUTÉ » sur un arbre sans TreadmillFxController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
CTL="$SRC/client/Controllers/TreadmillFxController.luau"
if [ ! -f "$CTL" ]; then
	echo "banc a82 (tapis animés) : SAUTÉ, pas de TreadmillFxController (a82 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
emit() { # nom fichier
	local c
	c=$(tr -d '\r' < "$2")
	printf '%s = [==========[\n%s\n]==========]\n' "$1" "$c"
}
{
	echo "SOURCES = {}"
	for m in DeepFreeze Music Settings TreadmillFX; do
		emit "SOURCES[\"shared/Config/$m.luau\"]" "$SRC/shared/Config/$m.luau"
	done
	emit "SOURCE" "$CTL"
	cat "$H/harness.luau" "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$HOME/.rokit/bin/luau.exe" "$W" 2>&1) || true
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" || true
if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -40; fi
line=$(printf '%s\n' "$out" | grep -E "^banc a82 \(tapis animés\) : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "banc a82 (tapis animés) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"; exit 1; fi
echo "$line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
