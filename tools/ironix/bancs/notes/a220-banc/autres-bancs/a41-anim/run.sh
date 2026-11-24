#!/usr/bin/env bash
# a220 (vague 66) : copie du lanceur a134 du banc a41-anim, Config/Weight monté (CarryController le lit depuis a220) ; tests
# lus à leur place (a134-banc/autres-bancs/a41-anim), faux Roblox copié ici avec une ligne de plus. Corrigé par
# a181-banc/corrige.sh comme le lanceur a181. Arbre sans Weight dans CarryController : le lanceur a181, tel quel.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$here/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
root="${ARG%/src}"
if ! grep -q "WaitForChild(\"Weight\")" "$root/src/client/Controllers/CarryController.luau" 2>/dev/null; then
	exec bash "$N/a181-banc/autres-bancs/a41-anim/run.sh" "$@"
fi
if [ "${A220_INNER:-}" != "1" ]; then
	A220_INNER=1 exec bash "$N/a181-banc/corrige.sh" a41-anim bash "$here/run.sh" "$@"
fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; out="$R1_D/generated.luau"
{
  echo 'SRC = {}'
  for name in Contract/Animations Anim/AnimPlayer Anim/MarkerSounds Anim/AnimTest Config/DeepFreeze Config/Balance Config/Rarities Config/Weight; do
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
  cat "$N/a134-banc/autres-bancs/a41-anim/tests.luau"
} > "$out"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$out")"
