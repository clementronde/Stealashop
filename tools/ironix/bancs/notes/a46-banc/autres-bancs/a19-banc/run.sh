#!/usr/bin/env bash
# Copie d'a46 (2026-11-08, L-086) : plus d'amélioration « Workbenches » ni d'invite « Unlock workbench » : U8, U9 et U15 réécrits (3 invites, BuyItem(UnboxBenches) refusé comme un Id inconnu), U16 à U20 retirés, UnboxService.Refresh contrôlé sur l'achat d'un présentoir ; ext-motion.luau rangé dans a46-banc.
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a37-banc/autres-bancs/a19-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a37-banc/autres-bancs/a19-banc/run.sh" "$@"; fi
# Copie d'a37 (2026-11-08, DEV-052) : le contrôleur testé requiert Controllers/UI/Motion (TweenService) → module UI/Motion ajouté à l'arbre et faux Roblox complété par ../../ext-motion.luau (UIScale, NumberValue, TweenService ; tweens instantanés : vérifications d'origine inchangées).
# Banc d'essai hors Studio de a19 (DEV-031 boutique d'armes, DEV-033 améliorations) :
# ShopService, WeaponShopController, UpgradeController, avec les vrais DataService, ToolService,
# Net, Config, Contract, Format et Types. ProfileStore, PlotService, UnboxService et
# CosmeticService y sont des bouchons (dans tests.luau).
# Deux passes : avec un CosmeticService bouchonné (tests.luau), puis sans CosmeticService
# (tests-sans-cosmetique.luau : avertissement unique, achat d'aura refusé, le reste marche).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a19 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a37}"
SRC="$ROOT/src"
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
status=0
for pass in avec sans; do
  : "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run-$pass.luau"
  {
    if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
    if [ "$pass" = "avec" ]; then echo "WITH_COSMETIC = true"; else echo "WITH_COSMETIC = false"; fi
    cat "$H/stubs.luau"
    cat "$H/../../ext-motion.luau" # a37 (DEV-052)
    (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    cat "$H/setup.luau"
    if [ "$pass" = "avec" ]; then cat "$H/tests.luau"; else cat "$H/tests-sans-cosmetique.luau"; fi
  } > "$OUT"
  echo "######## passe « $pass CosmeticService »"
  out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
  printf '%s\n' "$out"
  if ! printf '%s\n' "$out" | grep -qE " 0 échec\(s\)"; then status=1; fi
done
exit $status
