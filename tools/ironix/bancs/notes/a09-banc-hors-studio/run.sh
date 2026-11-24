#!/usr/bin/env bash
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
