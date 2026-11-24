#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : BenchLift et BenchIdle sortis du contrat (12 animations du joueur) ; les scénarios de marqueur passent par Place et son marqueur Release.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a41-banc/autres-bancs/a09-banc-hors-studio/run.sh" "$@"; fi
# Copie d'a41 (2026-11-08, L-071) : AnimationController ne relance plus un BenchLift en cours à la hausse de BenchReps → scénario « réapparition » : 0,9 s au lieu de 0,6 entre deux répétitions (tests.luau).
# Banc d'essai a09 : assemble les sources des modules et les scénarios, puis lance luau.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-/f/StealAShop/agents/a09}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; out="$R1_D/generated.luau"
{
  echo 'SRC = {}'
  for name in Contract/Animations Anim/AnimPlayer Anim/MarkerSounds Anim/AnimTest; do
    printf 'SRC["%s"] = [==========[\n' "$name"
    cat "$root/src/shared/$name.luau"
    printf '\n]==========]\n'
  done
  printf 'SRC["AnimationController"] = [==========[\n'
  cat "$root/src/client/Controllers/AnimationController.luau"
  printf '\n]==========]\n'
  cat "$here/fake.luau"
  cat "$here/tests.luau"
} > "$out"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$out")"
