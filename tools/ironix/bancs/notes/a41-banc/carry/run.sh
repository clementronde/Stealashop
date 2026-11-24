#!/usr/bin/env bash
# Banc hors Studio d'a41 (2026-11-08, liaison L-071, point 4), partie portage : vrais CarryService et
# CarryController (bouchons : StatsService, AnimationController). Deux passes : la hauteur du colis de
# Config/Balance (Carry.HeadGap), puis une autre (0,9) pour prouver qu'elle est lue.
# Faux Roblox : fake.luau (copie de celui d'a17, complétée par a41).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a41 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a41}"
SRC="$ROOT/src"
status=0
for pass in config 0.9; do
  : "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run-$pass.luau"
  {
    cat "$H/fake.luau"
    (cd "$SRC" && find shared server/Services/CarryService.luau client/Controllers/CarryController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    if [ "$pass" != "config" ]; then echo "HEAD_GAP_OVERRIDE = \"$pass\""; fi
    cat "$H/tests.luau"
  } > "$OUT"
  echo "######## passe HeadGap = $pass"
  out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
  printf '%s\n' "$out"
  if ! printf '%s\n' "$out" | grep -qE " 0 échec\(s\)"; then status=1; fi
done
exit $status
