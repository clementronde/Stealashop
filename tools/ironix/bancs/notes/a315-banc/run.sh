#!/usr/bin/env bash
# Banc a315 (23/11, L-291 : l'intrus frappé par le propriétaire dans sa boutique est projeté à travers une vitre) :
#   1. choix de la vitre (Shared/ShopGlass) pour des boutiques tournées de 0°, −74° et −170° : sens du coup, sinon la
#      plus proche ; trou gardé dans la vitre ; fond du niveau 1 exclu (ne donne pas dehors) ;
#   2. vitres par tag ShopGlass et GlassSide, repli par nom Pane_* sans tag, côté par la lettre ou la place ;
#   3. refus (intrus hors de la boutique, frappeur pas propriétaire, interrupteur éteint) : rien n'est fait ;
#   4. projection complète à 0°, −74° et −170° (GlassThrowService + GlassThrowController + GlassThrow/Hole) :
#      groupes de collision (PlotBarrier traversé, map intacte), ragdoll, trou, givre, éclats dehors, relevé dehors,
#      Knockback, secousse, sons et FX de Clément, réparation : la vitre est rendue exactement comme avant ;
#   5. deux projections rapprochées dans la même vitre (trou déjà ouvert, prolongé, une seule réparation) ;
#   6. courses du client (réparation pendant FragmentAsync, second trou pendant le découpage, FragmentAsync en erreur) ;
#   7. effets visuels coupés, joueur qui part en plein vol.
# Vrai : GlassThrowService, GlassThrowController, GlassThrow/Hole et tout shared/. Bouchons : Net (relevé), PlotService
# (GetOwner), AntiCheatService, AnimationController (PlayPlayer), Config/ProductIds (IsDev). Faux Roblox : stubs.luau
# (copie d'a313, + PhysicsService, GeometryService, ragdoll et poussée ; physique minimale dans tests.luau).
#   bash run.sh [racine du dépôt]          défaut : /f/StealAShop
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
if [ ! -f "$SRC/server/Services/GlassThrowService.luau" ]; then
  echo "banc a315 SAUTÉ : arbre d'avant a315 (pas de GlassThrowService)"; echo "0 vérification(s), 0 échec(s)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FILES="server/Services/GlassThrowService.luau client/Controllers/GlassThrowController.luau client/Controllers/GlassThrow/Hole.luau"
OUT="$TMP/run.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && { find shared -name '*.luau'; for f in $FILES; do echo "$f"; done; } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
