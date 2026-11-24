#!/usr/bin/env bash
# Copie d'a128 (vague 39, 2026-11-14) : faux Roblox lu dans la copie a128 d'a17-carry (DescendantAdded, ajout pur) ; tests inchangés.
# Scénario carry du banc a49 (DEV-131) : faux Roblox et scénarios du banc a17-carry (copie d'a22,
# ../../a22-banc/autres-bancs/a17-carry, sans son bilan), puis tests.carry.luau. Vrai CarryService.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../../../../a22-banc/autres-bancs/a17-carry"
ROOT="${1:-/f/StealAShop/agents/a49}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.carry.luau"
{
	cat "$H/../../a17-carry/fake.luau" # a128 (vague 39) : faux Roblox avec DescendantAdded
	(cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	awk '/^-+ bilan$/ { exit } { print }' "$A/tests.luau"
	cat "$H/tests.carry.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1
