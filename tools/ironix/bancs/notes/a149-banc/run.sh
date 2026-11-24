#!/usr/bin/env bash
# Banc a149 (2026-11-14, vague 42 : petites demandes de Clément, L-146 (2) et (3), L-150 (5) et (6), L-153, L-157 (1) à (4),
# et la règle de Cantin sur la poursuite du bot) : trois volets.
#   bot  : scénario a149bot sur la mise en place du banc a124 (copie a149) : intrus sans vol jamais visé, poursuite et
#          coup dans la boutique sans objet après un vol, valeurs de Config, contrat UpgradeSign.Gain ;
#   hud  : HudController réel sur la mise en place du banc a21-hud (copie a126) : Damage avec la potion de force,
#          « POLICE IN 8s » en rouge puis la couleur de Clément ;
#   sign : UpgradeController réel sur la mise en place du banc a52 (copie a134) : UpgradeSign.Gain « +1/s > +2/s ».
#   + texte de la boutique d'auras (« ×20 Strength », « ×12 Speed ») lu dans AuraShopController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop) ; « SAUTÉ » avant la fusion (pas de BotService.KickCooldown).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "function BotService.KickCooldown" "$SRC/server/Services/BotService.luau" 2>/dev/null; then
	echo "banc a149 SAUTÉ : cet arbre n'a pas encore la vague 42 (a149)"
	echo "banc a149 : 0 vérification(s), 0 échec(s)"
	exit 0
fi
H21="$H/../a126-banc/autres-bancs/a21-hud"
A52="$H/../a134-banc/autres-bancs/a52"
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
checks=0; fails=0
tally() { # $1 nom, $2 sortie
	local line c f
	line=$(printf '%s\n' "$2" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$2" | tail -20; echo "  $1 : arrêté avant la fin"; fails=$((fails + 1)); return; fi
	printf '%s\n' "$2" | grep -E "ÉCHEC|ERREUR" || true
	c=$(printf '%s' "$line" | sed -E 's/.*[^0-9]?([0-9]+) vérification.*/\1/'); c=$(printf '%s' "$line" | grep -oE '[0-9]+ vérification' | grep -oE '[0-9]+')
	f=$(printf '%s' "$line" | grep -oE '[0-9]+ échec' | grep -oE '[0-9]+')
	echo "  $1 : $c contrôles, $f raté(s)"; checks=$((checks + c)); fails=$((fails + f))
}
# bot
out=$(A149_TESTS="$H" bash "$H/autres-bancs/a124/run.sh" "$ROOT" a149bot 2>&1); tally bot "$out"
# hud
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) client/Controllers/HudController.luau client/Controllers/SkyController.luau"
{
	cat "$H21/stubs.luau"
	cat "$H/../a62-banc/autres-bancs/ext-motion.luau"
	sources "$FILES"
	cat "$H/hud-stub.luau"
	sed -n '16,120p' "$H21/tests.luau" | sed 's/new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false }, hud)/new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false, TextColor3 = CLEMENT_TIMER_COLOR }, hud)/'
	cat "$H/hud.luau"
} > "$OUTDIR/hud.luau"
out=$("$LUAU" "$(cygpath -w "$OUTDIR/hud.luau")" 2>&1); tally hud "$out"
# sign
end=$(grep -n "^---------------------------------------------------------------- P3" "$A52/tests.luau" | cut -d: -f1)
{
	cat "$A52/stubs.luau"
	sources "shared client/Controllers/UpgradeController.luau"
	head -n $((end - 1)) "$A52/tests.luau" | sed '/^summary()/d'
	cat "$H/sign.luau"
} > "$OUTDIR/sign.luau"
out=$("$LUAU" "$(cygpath -w "$OUTDIR/sign.luau")" 2>&1); tally sign "$out"
# boutique d'auras (texte)
c=0; f=0
for want in 'then "Strength" else "Speed"'; do
	c=$((c + 1)); if ! grep -qF "$want" "$SRC/client/Controllers/AuraShopController.luau"; then f=$((f + 1)); echo "  ÉCHEC AuraShopController : « $want » absent"; fi
done
c=$((c + 1)); if grep -qE '"power"|"speed"' "$SRC/client/Controllers/AuraShopController.luau"; then f=$((f + 1)); echo "  ÉCHEC AuraShopController : encore « power » ou « speed »"; fi
echo "  aura : $c contrôles, $f raté(s)"; checks=$((checks + c)); fails=$((fails + f))
echo "banc a149 (vague 42, petites demandes de Clément) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
