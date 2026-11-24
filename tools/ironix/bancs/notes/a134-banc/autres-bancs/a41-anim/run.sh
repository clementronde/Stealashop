#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : BenchLift et BenchIdle ne sont plus joués (plus de banc).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a41-banc/anim/run.sh" "$@"; fi
# Banc hors Studio d'a41 (2026-11-08, liaison L-071, points 3 et 4), partie animations :
# AnimationController (Grab puis portage, AfterGrab, BenchLift, TreadmillRun) et CarryController
# (colis caché jusqu'au marqueur Grab), avec les vrais AnimPlayer, MarkerSounds, AnimTest, Contract et
# Config (Balance, Rarities, DeepFreeze). Faux Roblox : fake.luau (copie de celui d'a09, complétée).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a41 ; après fusion : /f/StealAShop)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-/f/StealAShop/agents/a41}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; out="$R1_D/generated.luau"
{
  echo 'SRC = {}'
  for name in Contract/Animations Anim/AnimPlayer Anim/MarkerSounds Anim/AnimTest Config/DeepFreeze Config/Balance Config/Rarities; do
    printf 'SRC["%s"] = [==========[\n' "$name"
    tr -d '\r' < "$root/src/shared/$name.luau"
    printf '\n]==========]\n'
  done
  for name in AnimationController CarryController; do
    printf 'SRC["%s"] = [==========[\n' "$name"
    tr -d '\r' < "$root/src/client/Controllers/$name.luau"
    printf '\n]==========]\n'
  done
  cat "$here/fake.luau"
  cat "$here/tests.luau"
} > "$out"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$out")"
