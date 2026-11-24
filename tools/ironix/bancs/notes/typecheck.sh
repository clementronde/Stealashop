#!/usr/bin/env bash
# Compare les erreurs de types (luau-lsp, ancien et nouveau solveur) entre deux racines du dépôt.
#   bash typecheck.sh <racine A> <racine B>
#   TYPECHECK_DIR=<dossier de travail> : un dossier par agent quand plusieurs tournent en même temps
set -u
W="${TYPECHECK_DIR:-$TEMP/lsp_cmp}"
rm -rf "$W" && mkdir -p "$W"
LSP=/c/Users/user/.vscode/extensions/johnnymorganz.luau-lsp-1.70.1-win32-x64/bin/server.exe
DEF="$(cygpath -m "$APPDATA/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau")"
ROJO="$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe"
run() { # $1 racine, $2 nom
	local R
	R="$(cygpath -m "$1")"
	mkdir -p "$W/$2"
	printf '{ "name": "S", "tree": { "$className": "DataModel", "ReplicatedStorage": { "Shared": { "$path": "%s/src/shared" } }, "ServerScriptService": { "Server": { "$path": "%s/src/server" } }, "StarterPlayer": { "StarterPlayerScripts": { "Client": { "$path": "%s/src/client" } } } } }' "$R" "$R" "$R" > "$W/$2/default.project.json"
	"$ROJO" sourcemap "$(cygpath -w "$W/$2/default.project.json")" -o "$(cygpath -w "$W/$2/sourcemap.json")" > /dev/null 2>&1
	sed -i 's#//?/##g' "$W/$2/sourcemap.json"
	local files
	files=$(cd "$1" && find src -name "*.luau" ! -path "*/Packages/*" | sort)
	for solver in old new; do
		local flag=""
		if [ "$solver" = "new" ]; then flag="--flag:LuauSolverV2=true"; fi
		(cd "$1" && timeout 280 "$LSP" analyze $flag --platform=roblox --sourcemap="$(cygpath -m "$W/$2/sourcemap.json")" --definitions=@roblox="$DEF" $files > "$W/$2/$solver.txt" 2>&1)
		grep -E "TypeError|SyntaxError" "$W/$2/$solver.txt" | tr '\134' '/' | sed -E 's#^.*/src/#src/#; s# \[[^]]*\]##; s#\(([0-9]+),[0-9]+\)#:\1#' | sort -u > "$W/$2/$solver.errs"
		sed -E 's#\.luau:[0-9]+:#.luau:#' "$W/$2/$solver.errs" | sort | uniq -c | sed 's/^ *//' > "$W/$2/$solver.norm"
	done
	echo "$2 : ancien solveur $(wc -l < "$W/$2/old.errs") erreurs, nouveau $(wc -l < "$W/$2/new.errs") ; require inconnus : $(grep -c 'Unknown require' "$W/$2/old.errs")"
}
run "$1" A
run "$2" B
for solver in old new; do
	echo "--- différences, solveur $solver (< A, > B)"
	diff "$W/A/$solver.norm" "$W/B/$solver.norm" | grep "^[<>]" | cut -c1-240
done
echo "--- erreurs du solveur new dans B, avec lignes"
cut -c1-200 "$W/B/new.errs"
