#!/usr/bin/env bash
# r1 (2026-11-20, accord de Cantin) : typecheck.sh plus rapide, même sortie. typecheck.sh n'est pas modifié.
# Compare les erreurs de types (luau-lsp, ancien et nouveau solveur) entre deux racines du dépôt.
#   bash typecheck2.sh <racine de référence A> <racine B>
#   NEW_ONLY=1      : nouveau solveur seul (pendant le travail) ; les deux solveurs restent la règle à la fusion
#   TC_PAR=0        : les deux solveurs l'un après l'autre (par défaut : en même temps, 2 processus)
#   TYPECHECK_DIR=… : dossier de travail gardé (par défaut : un dossier temporaire propre au lancement, supprimé)
#   TC_CACHE=…      : dossier du cache (par défaut : typecheck-cache/ à côté de ce script) ; TC_NOCACHE=1 : sans cache
# Cache : le résultat de la racine A est rangé sous une clé = sha1 du contenu de tout src/ (chemins relatifs compris),
# de la version de luau-lsp, du fichier de définitions, de rojo et du format de ce script ; une référence déjà analysée
# (même contenu, n'importe quel dossier) n'est pas réanalysée. La racine B n'est jamais lue dans le cache.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
LSP=/c/Users/user/.vscode/extensions/johnnymorganz.luau-lsp-1.70.1-win32-x64/bin/server.exe
DEF="$(cygpath -m "$APPDATA/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau")"
ROJO="$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe"
FORMAT="tc2-v1"
if [ -n "${TYPECHECK_DIR:-}" ]; then
	W="$TYPECHECK_DIR"; rm -rf "$W" && mkdir -p "$W"
else
	W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fi
CACHE="${TC_CACHE:-$H/typecheck-cache}"
SOLVERS="old new"
[ "${NEW_ONLY:-}" = "1" ] && SOLVERS="new"
outil_cle() { # version des outils, calculée une fois
	{ echo "$FORMAT"; echo "$LSP"; "$LSP" --version 2>&1; sha1sum "$(cygpath -u "$DEF")"; echo "$ROJO"; } | sha1sum | cut -c1-40
}
contenu_cle() { # $1 racine : sha1 du contenu et des chemins de src/
	(cd "$1" && find src -type f | LC_ALL=C sort | tr '\n' '\0' | xargs -0 sha1sum) | sha1sum | cut -c1-40
}
analyse() { # $1 racine, $2 dossier, $3 solveur
	local flag=""
	if [ "$3" = "new" ]; then flag="--flag:LuauSolverV2=true"; fi
	(cd "$1" && timeout 280 "$LSP" analyze $flag --platform=roblox --sourcemap="$(cygpath -m "$2/sourcemap.json")" --definitions=@roblox="$DEF" $files > "$2/$3.txt" 2>&1); echo $? > "$2/$3.status"
	grep -E "TypeError|SyntaxError" "$2/$3.txt" | tr '\134' '/' | sed -E 's#^.*/src/#src/#; s# \[[^]]*\]##; s#\(([0-9]+),[0-9]+\)#:\1#' | sort -u > "$2/$3.errs"
	sed -E 's#\.luau:[0-9]+:#.luau:#' "$2/$3.errs" | sort | uniq -c | sed 's/^ *//' > "$2/$3.norm"
}
run() { # $1 racine, $2 nom, $3 1 = cache permis
	local R key="" need="" s
	R="$(cygpath -m "$1")"
	mkdir -p "$W/$2"
	if [ "$3" = "1" ] && [ "${TC_NOCACHE:-}" != "1" ]; then
		key="$(outil_cle)-$(contenu_cle "$1")"
		for s in $SOLVERS; do
			if [ -f "$CACHE/$key/$s.errs" ] && [ -f "$CACHE/$key/$s.norm" ]; then
				cp "$CACHE/$key/$s.errs" "$CACHE/$key/$s.norm" "$W/$2/"
			else need="$need $s"; fi
		done
	else need="$SOLVERS"; fi
	if [ -n "$need" ]; then
		printf '{ "name": "S", "tree": { "$className": "DataModel", "ReplicatedStorage": { "Shared": { "$path": "%s/src/shared" } }, "ServerScriptService": { "Server": { "$path": "%s/src/server" } }, "StarterPlayer": { "StarterPlayerScripts": { "Client": { "$path": "%s/src/client" } } } } }' "$R" "$R" "$R" > "$W/$2/default.project.json"
		"$ROJO" sourcemap "$(cygpath -w "$W/$2/default.project.json")" -o "$(cygpath -w "$W/$2/sourcemap.json")" > /dev/null 2>&1
		sed -i 's#//?/##g' "$W/$2/sourcemap.json"
		files=$(cd "$1" && find src -name "*.luau" ! -path "*/Packages/*" | sort)
		if [ "${TC_PAR:-1}" = "1" ]; then
			for s in $need; do analyse "$1" "$W/$2" "$s" & done
			wait
		else
			for s in $need; do analyse "$1" "$W/$2" "$s"; done
		fi
		if [ -n "$key" ]; then # rangé dans un dossier neuf puis renommé : deux agents en même temps ne se gênent pas
			local tmp
			mkdir -p "$CACHE" && tmp="$(mktemp -d "$CACHE/.neuf.XXXXXX")" || tmp=""
			if [ -n "$tmp" ]; then
				[ -d "$CACHE/$key" ] && cp "$CACHE/$key/"* "$tmp/" 2>/dev/null
				for s in $need; do case "$(cat "$W/$2/$s.status" 2>/dev/null)" in 0|1) cp "$W/$2/$s.errs" "$W/$2/$s.norm" "$tmp/" ;; esac; done # analyse coupée ou plantée : pas rangée
				rm -rf "$CACHE/$key.ancien"; [ -d "$CACHE/$key" ] && mv "$CACHE/$key" "$CACHE/$key.ancien" 2>/dev/null
				mv "$tmp" "$CACHE/$key" 2>/dev/null || rm -rf "$tmp"
				rm -rf "$CACHE/$key.ancien"
			fi
		fi
	fi
	if [ "${NEW_ONLY:-}" = "1" ]; then
		echo "$2 : ancien solveur non lancé (NEW_ONLY=1), nouveau $(wc -l < "$W/$2/new.errs") ; require inconnus : $(grep -c 'Unknown require' "$W/$2/new.errs")"
	else
		echo "$2 : ancien solveur $(wc -l < "$W/$2/old.errs") erreurs, nouveau $(wc -l < "$W/$2/new.errs") ; require inconnus : $(grep -c 'Unknown require' "$W/$2/old.errs")"
	fi
}
run "$1" A 1
run "$2" B 0
for solver in $SOLVERS; do
	echo "--- différences, solveur $solver (< A, > B)"
	diff "$W/A/$solver.norm" "$W/B/$solver.norm" | grep "^[<>]" | cut -c1-240
done
echo "--- erreurs du solveur new dans B, avec lignes"
cut -c1-200 "$W/B/new.errs"
