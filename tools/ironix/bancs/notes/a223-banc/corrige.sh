#!/usr/bin/env bash
# a223 (vague 66, L-210 point 7) : même principe que a208-banc/corrige.sh (faux luau.exe qui corrige le fichier
# assemblé avant de lancer le vrai) : patches/<banc>.sed, puis patches/<banc>.post.luau inséré juste avant la
# ligne summary("scénario pads") (tests ajoutés à la fin du scénario pads).
#   bash corrige.sh <banc> <commande…>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
shift
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	if [ -f "$H/patches/$NAME.sed" ]; then
		echo "sed -E -i -f \"$H/patches/$NAME.sed\" \"\$f\""
	fi
	if [ -f "$H/patches/$NAME.post.luau" ]; then
		echo "awk -v post=\"$H/patches/$NAME.post.luau\" '/^summary\(\"scénario pads\"\)/ { while ((getline l < post) > 0) print l; close(post) } { print }' \"\$f\" > \"\$f.a223\" && mv \"\$f.a223\" \"\$f\""
	fi
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" "$@"
