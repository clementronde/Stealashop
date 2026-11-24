#!/usr/bin/env bash
# Copie d'a94 (2026-11-12, L-108 point 5) : « Strength N » sur BB_StoreInfo, ReqSignPoint dans les faux magasins (tests.luau, en tête). Bonne avant et après la fusion.
# Banc hors Studio de a25 (vague 8, DEV-030, L-044) : panneaux d'approche des magasins PNJ
# (StoreInfoController), noms des magasins dans Config/Zones (StoreIds), contrat BB_StoreInfo et
# InfoPoint (Contract/UI, Contract/Models, ContractChecker : avertissement orange non bloquant).
# Vrais : Config, Contract, Format, StoreInfoController, ContractChecker. Faux Roblox : celui de
# a22-banc/core (copie dans stubs.luau), complété dans ext.luau.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a25 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a25}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared client/Controllers/StoreInfoController.luau server/Services/ContractChecker.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau" "$H/ext.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
