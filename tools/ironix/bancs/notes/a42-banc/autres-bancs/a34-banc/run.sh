#!/usr/bin/env bash
# Copie a42 (vague 14) : le son du coup sur le camion s'appelle SFX_TruckHit (nom de Clément, L-071), plus Truck_Hit.
# Banc d'essai hors Studio des retours de frappe (DEV-053, agent a34, vague 12) : chiffres de dégâts
# flottants (DamageNumberController), son du coup qui monte (ShatterController, TruckController),
# fissures aux trois seuils, sur les trois cibles (vitrine PNJ, porte de boutique, camion).
# Vrais : WindowService, WindowController, ShatterController, HitController, TruckController,
# DamageNumberController, Config, Contract, Format, Net/Definitions, Net/Validate. Bouchons :
# ToolService, AnimationController, Net (routage local avec latence, chaque envoi contrôlé par le
# vrai Definitions + Validate). Faux Roblox : stubs.luau (copie de celui d'a16, complétée).
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a34 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
# Le fichier assemblé va dans un dossier temporaire (rien n'est écrit à côté de ce script).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a34}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && {
    find shared -name '*.luau'
    for f in server/Services/WindowService.luau client/Controllers/WindowController.luau \
      client/Controllers/ShatterController.luau client/Controllers/HitController.luau \
      client/Controllers/TruckController.luau client/Controllers/DamageNumberController.luau; do
      echo "$f"
    done
  } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
