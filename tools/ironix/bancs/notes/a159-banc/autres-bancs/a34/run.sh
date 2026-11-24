#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a134 : porte de Plot_1 à 40 coups, un coup sur une porte de boutique = 1 (WindowHit avec 1, chiffre « -1 »). stubs.luau lu dans la copie a134. Arbre sans PvP.DoorHits : lance la copie a134.
_A159_R="${1:-/f/StealAShop}"; if ! grep -q "DoorHits = " "$_A159_R/src/shared/Config/PvP.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a134-banc/autres-bancs/a34/run.sh" "$@"; fi
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : PV des vitrines des zones 1 et 2 (27 et 272).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a93-banc/autres-bancs/a34-banc/run.sh" "$@"; fi
# Copie a93 (2026-11-12, vague 29, L-106 point 3) : porte de Plot_1 à 50 PV (base du niveau de boutique 1) au lieu de 50 × les dégâts du propriétaire.
# Copie a44 (vague 15, L-081) : la vitre se creuse au lieu des étoiles de fissure → faux GeometryService et UserInputService (../../ext-carve.luau), section « fissures aux trois seuils » remplacée par « le creux grandit avec les PV » ; le reste est inchangé.
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
# a93 : arbre sans la nouvelle formule des PV de porte (avant la fusion d'a93) → la copie a44 tourne telle quelle.
if ! grep -q "function Formulas.PlayerWindowHP(stageLevel" "${1:-/f/StealAShop/agents/a34}/src/shared/Config/Formulas.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a44-banc/autres-bancs/a34-banc/run.sh" "$@"; fi
# a44 : arbre sans le creux (avant la fusion de la vague 15) → la copie précédente (a42) tourne telle quelle.
if ! grep -q "Carve = {" "${1:-/f/StealAShop/agents/a34}/src/shared/Config/Shatter.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a42-banc/autres-bancs/a34-banc/run.sh" "$@"; fi
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a34}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/../../../a134-banc/autres-bancs/a34/stubs.luau"
  cat "$H/../../../a93-banc/../a44-banc/ext-carve.luau" # a44 : GeometryService, UserInputService, Reflectance
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
