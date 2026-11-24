#!/usr/bin/env bash
# Banc hors Studio de a17 (StoreHeistService, HeistController), repris de a10 ; copie adaptée par a22
# au catalogue v2 : plusieurs objets par case, tuto par Tutorial.GuaranteedItemId, répartition du
# tirage (Items.Pick), puis deux passages avec un catalogue modifié pour le repli d'une case vide.
#   bash run.sh [racine src]   (défaut : le worktree a22 ; après fusion : /f/StealAShop/src)
# Assemble les bouchons de a08 (stubs.luau), leurs compléments (ext.luau), les sources et les
# scénarios en un seul fichier Luau, puis l'exécute avec le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a22/src}"
LUAU="$HOME/.rokit/bin/luau.exe"
sources() {
  (cd "$SRC" && find shared server/Services/StoreHeistService.luau client/Controllers/HeistController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
# Mise en place de tests.luau (jusqu'au démarrage du service), commune aux passages du repli.
setup() {
  awk '/^-+ démarrage$/ { exit } { print }' "$H/tests.luau"
}

: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  cat "$H/ext.luau"
  sources
  cat "$H/tests.luau"
} > "$OUT"
"$LUAU" "$(cygpath -w "$OUT")"

for pass in Rare Low; do
  : "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.fallback.$pass.luau"
  {
    cat "$H/stubs.luau"
    cat "$H/ext.luau"
    sources
    printf 'FALLBACK = "%s"\n' "$pass"
    cat "$H/fallback.patch.luau"
    setup
    cat "$H/tests.fallback.luau"
  } > "$OUT"
  "$LUAU" "$(cygpath -w "$OUT")"
done
