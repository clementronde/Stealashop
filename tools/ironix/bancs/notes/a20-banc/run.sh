#!/usr/bin/env bash
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
ROOT="${1:-/f/StealAShop/agents/a20}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
FILES="shared server/Services/DataService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/CosmeticService.luau client/Controllers/CosmeticController.luau client/Controllers/AuraShopController.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs-a15.luau"
  cat "$H/ext.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
