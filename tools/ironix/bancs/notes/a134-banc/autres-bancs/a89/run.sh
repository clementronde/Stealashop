#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : potion Speed retirée : la potion d'essai devient Invisibility.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a89-banc/run.sh" "$@"; fi
# Banc hors Studio d'a89 (vague 28, 2026-11-11, L-085 point 2, L-097 point 4) : PotionController, les potions
# côté client : apparition et retrait de la copie locale (posée au sol, sans collision, SpinBob par
# ItemIdleController.ModelMotion), modèle absent (une ligne en Studio), contact envoyé une seule fois puis renvoi
# après un délai, petit effet au ramassage (UI_Success), lignes d'effets actifs (V0 près de l'argent, ou
# UI_HUD.PotionBar de Clément) et leur fin, invisibilité d'un autre joueur et retour, voile chez soi,
# VISUAL EFFECTS OFF. Faux Roblox autonome (harness.luau + roblox.luau), serveur simulé (faux Net), vrais
# modules Config (DeepFreeze, Music, Settings, Potions) et Contract/Find. « SAUTÉ » sans PotionController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
CTL="$SRC/client/Controllers/PotionController.luau"
NAME="banc a89 (potions client)"
if [ ! -f "$CTL" ]; then
	echo "$NAME : SAUTÉ, pas de PotionController (a89 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
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
	for m in DeepFreeze Music Settings Potions; do
		emit "SOURCES[\"shared/Config/$m.luau\"]" "$SRC/shared/Config/$m.luau"
	done
	emit "SOURCES[\"shared/Contract/Find.luau\"]" "$SRC/shared/Contract/Find.luau"
	emit "SOURCE" "$CTL"
	cat "$H/harness.luau" "$H/roblox.luau" "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$HOME/.rokit/bin/luau.exe" "$W" 2>&1) || true
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" || true
if [ "${VERBOSE:-}" = 1 ]; then printf '%s\n' "$out" | tail -40; fi
line=$(printf '%s\n' "$out" | grep -F "$NAME : " | grep -E "[0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "$NAME : arrêté avant la fin : 0 vérification(s), 1 échec(s)"; exit 1; fi
echo "$line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
