#!/usr/bin/env bash
# Copie a149 (2026-11-14, vague 42, L-157 point 3 : « ×20 Strength » et « ×12 Speed » dans la boutique d'auras) : K5 et K14 attendent les nouveaux mots (tests.luau d'ici) ; faux Roblox copié de la copie a134.
# Arbre d'avant a149 (AuraShopController écrit encore « power ») : la copie a134 tourne telle quelle.
if ! grep -qF 'then "Strength" else "Speed"' "${1:-/f/StealAShop}/src/client/Controllers/AuraShopController.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a134-banc/autres-bancs/a20/run.sh" "$@"; fi
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : auras et trails v2 (×2 à ×20, ×2 à ×12, nouveaux prix), dégâts = arme × aura, marche en log de la Speed affichée, plus de Force.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a37-banc/autres-bancs/a20-banc/run.sh" "$@"; fi
# Copie d'a37 (2026-11-08, DEV-052) : le contrôleur testé requiert Controllers/UI/Motion (TweenService) → module UI/Motion ajouté à l'arbre et faux Roblox complété par ../../ext-motion.luau (UIScale, NumberValue, TweenService ; tweens instantanés : vérifications d'origine inchangées).
# Banc d'essai hors Studio de a20 (DEV-032 : CosmeticService, CosmeticController, AuraShopController).
# Assemble le faux Roblox (celui de a15, copié tel quel dans stubs-a15.luau, plus ext.luau), les
# vraies sources partagées (Config, Contract, Net, Types, Format…) et les fichiers testés, puis les
# scénarios, en un seul fichier Luau exécuté par le luau de rokit. ProfileStore y est un bouchon ;
# DataService, StatsService, ToolService et CosmeticService sont les vrais, côté serveur, et
# CosmeticController et AuraShopController les vrais, côté client.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a20 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
# Le fichier assemblé va dans un dossier temporaire (rien n'est écrit à côté de ce script).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a37}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs-a15.luau"
  cat "$H/ext.luau"
  cat "$H/../../../a37-banc/ext-motion.luau" # a37 (DEV-052)
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
