#!/usr/bin/env bash
# Scénario heist du banc a49 (DEV-131) : faux Roblox et mise en place du banc a17-heist (copie d'a49,
# ../autres-bancs/a17-heist : stubs, ext, bouchon d'AntiCheatService, tests.luau jusqu'au démarrage),
# puis tests.heist.luau. Vrai StoreHeistService.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../autres-bancs/a17-heist"
ROOT="${1:-/f/StealAShop/agents/a49}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
sources() {
	(cd "$SRC" && find shared server/Services/StoreHeistService.luau client/Controllers/HeistController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.heist.luau"
{
	cat "$A/stubs.luau" "$A/ext.luau" "$A/../stub-anticheat.luau"
	sources
	awk '/^-+ démarrage$/ { exit } { print }' "$A/tests.luau"
	cat "$H/tests.heist.luau"
} > "$OUT"
"$LUAU" "$(cygpath -w "$OUT")" 2>&1
