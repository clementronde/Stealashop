#!/usr/bin/env bash
# Copie d'a126 (vague 38, 2026-11-14, L-135 point 3 : « le bouton BASE n'existe plus ») de la copie a62 du banc a21-hud :
# H1, H3 et H4 vérifient que HudController ne lit plus ReturnBaseButton (laissé tel quel s'il est encore dans l'écran,
# clic sans remote, recharge jamais écrite, aucun avertissement). ext-motion.luau lu sur place (a62-banc/autres-bancs).
# Sur un arbre où HudController lit encore ReturnBaseButton (avant a126), relance la copie d'a62.
if grep -q '"ReturnBaseButton"' "${1:-/f/StealAShop}/src/client/Controllers/HudController.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a62-banc/autres-bancs/a21-hud/run.sh" "$@"; fi
# Copie d'a62 (2026-11-11, vague 22, L-092 3g) : stubs.luau ajoute les signaux InputBegan et InputEnded
# (Motion.Button suit la fin du toucher). Tests inchangés.
# Copie d'a39 (2026-11-08, L-071) : les boutons Shop, Index et Rebirth du HUD sont visibles dès maintenant (Features.RobuxShopPreview, Index, RebirthPreview) → leur visibilité attendue se lit dans Config/Features (cachés sur un arbre d'avant L-071, visibles après : le banc passe sur les deux) ; ext-motion.luau d'a37 rangé dans ../ (autres-bancs).
# Copie d'a37 (2026-11-08, DEV-052) : le contrôleur testé requiert Controllers/UI/Motion (TweenService) → module UI/Motion ajouté à l'arbre et faux Roblox complété par ../../ext-motion.luau (UIScale, NumberValue, TweenService ; tweens instantanés : vérifications d'origine inchangées).
# Banc hors Studio de a21, côté client : HudController (NightCountdown, ReturnBaseButton) et
# SkyController (ciel, lumière, lampadaires). Faux Roblox : celui de a15 (écrans, boutons), complété
# (Color3.Lerp, Lighting, lumières). HeistController et ChaseController : bouchons.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a21 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a39}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) client/Controllers/HudController.luau client/Controllers/SkyController.luau"
{
  cat "$H/stubs.luau"
  cat "$H/../../../a62-banc/autres-bancs/ext-motion.luau" # a37 (DEV-052) ; copie d'a39 : ext-motion.luau rangé à côté (autres-bancs)
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
