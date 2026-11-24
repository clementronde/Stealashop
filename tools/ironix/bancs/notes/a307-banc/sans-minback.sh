#!/usr/bin/env bash
# a307 (22/11, L-285) : lance un ancien banc sur une copie de l'arbre à Config/ShopGrowth.MinBack = nil (fond
# minimum coupé : l'ancien fond de la boutique, que ce banc attend). Sans MinBack dans l'arbre : le banc tel quel.
#   bash sans-minback.sh <lanceur du banc> <racine du dépôt ou son src>
set -eu
SCRIPT="$1"; ARG="$2"
case "$ARG" in */src) ROOT="${ARG%/src}"; TAIL="/src" ;; *) ROOT="$ARG"; TAIL="" ;; esac
CFG="$ROOT/src/shared/Config/ShopGrowth.luau"
if ! grep -qE '^\s*MinBack = [-0-9.]+ :: number\?,' "$CFG" 2>/dev/null; then
  exec bash "$SCRIPT" "$ARG"
fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"
T="$R1_D/a307-sans-minback"
rm -rf "$T"; mkdir -p "$T"
cp -r "$ROOT/src" "$T/src"
for f in default.project.json aftman.toml rokit.toml; do [ -f "$ROOT/$f" ] && cp "$ROOT/$f" "$T/" || true; done
perl -pi -e 's/^(\s*)MinBack = [-0-9.]+ :: number\?,/${1}MinBack = nil :: number?,/' "$T/src/shared/Config/ShopGrowth.luau"
grep -q "MinBack = nil" "$T/src/shared/Config/ShopGrowth.luau" || { echo "a307 : copie à MinBack = nil ratée : 0 vérification(s), 1 échec(s)"; exit 1; }
exec bash "$SCRIPT" "$T$TAIL"
