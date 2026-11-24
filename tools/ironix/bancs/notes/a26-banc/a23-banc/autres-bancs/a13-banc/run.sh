#!/usr/bin/env bash
# Copie à jour par a23 (2026-11-07, ouverture des colis v2) du banc hors Studio de a13 (DEV-019 :
# UnboxService, UnboxController). Changements : bouchons d'a23 (Random, Vector2, sons, écrans…),
# modules d'aide d'UnboxController (Controllers/Unbox) montés, chance du joueur à 0 (les scénarios
# DEV-019 ne tirent pas d'amélioration), UnboxReveal à 7 arguments (E5).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a23 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a23}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services/UnboxService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
