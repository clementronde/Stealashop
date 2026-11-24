#!/usr/bin/env bash
H="$(cd "$(dirname "$0")/../../.." && pwd)"
# lot98 (petit chef 3) : a129 avec Model:GetScale et ScaleTo dans le faux Roblox d'a14 (insert.pl de l'enveloppe a14, a418).
# Sur l arbre aux interrupteurs d a401 coupés (a401-coupe.sh, comme a14, a59, a60, a62 : le faux Roblox d a14 n a pas TweenService).
D="$H/pc3-lot98-bancs/a14"
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'for a in "$@"; do'
	echo '	case "$a" in *.luau)'
	echo '		f="$(cygpath -u "$a")"'
	echo "		if [ -f \"\$f\" ] && grep -q 'function Methods.GetPlayers(self)' \"\$f\"; then perl \"$D/insert.pl\" \"$D/scale.luau\" \"\$f\"; fi ;;"
	echo '	esac'
	echo 'done'
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$H/a401-banc/a401-coupe.sh" "$H/a262-banc/autres-bancs/a129/run.sh" "$@"
