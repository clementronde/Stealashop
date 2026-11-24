#!/usr/bin/env bash
# Assemble les sources de PlotService, Find et Models avec le faux Roblox et les tests,
# puis lance le tout avec le luau de rokit.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
repo="${1:-/f/StealAShop/agents/a06}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; out="$R1_D/run_all.luau"
{
	printf 'local SRC_PLOT = [==========[\n'
	cat "$repo/src/server/Services/PlotService.luau"
	printf '\n]==========]\n'
	printf 'local SRC_FIND = [==========[\n'
	cat "$repo/src/shared/Contract/Find.luau"
	printf '\n]==========]\n'
	printf 'local SRC_MODELS = [==========[\n'
	cat "$repo/src/shared/Contract/Models.luau"
	printf '\n]==========]\n'
	printf 'local function newWorld()\n'
	cat "$here/fake.luau"
	printf '\nend\n'
	cat "$here/tests.luau"
} > "$out"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$out")"
