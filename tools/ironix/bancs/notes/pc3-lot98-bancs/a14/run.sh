#!/usr/bin/env bash
# lot98 (petit chef 3) : a14 d'a401 (interrupteurs coupés, a262, a141) avec Model:GetScale et ScaleTo ajoutés au faux
# Roblox (a418 : DisplayService les appelle dès qu'un objet n'est plus à ×1). Un faux luau.exe de plus applique
# insert.pl au fichier lancé, puis appelle celui d'avant.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
H="$(cd "$D/../.." && pwd)"
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'for a in "$@"; do'
	echo '	case "$a" in *.luau)'
	echo '		f="$(cygpath -u "$a")"'
	echo "		if [ -f \"\$f\" ]; then perl \"$D/insert.pl\" \"$D/scale.luau\" \"\$f\" || { echo \"ÉCHEC lot98 : insert.pl pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; }; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$H/a401-banc/autres-bancs/a14/run.sh" "$@"
