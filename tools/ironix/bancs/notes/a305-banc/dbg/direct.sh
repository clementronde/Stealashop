set -u
H=/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3
REPO="$1"
A265_T=""
if grep -q 'if phase == nil or not HOLD_PHASES\[phase\] then' "${REPO%/src}/src/server/Services/StoreHeistService.luau" 2>/dev/null; then
	A265_T="$(mktemp -d)"
	mkdir -p "$A265_T/.rokit/bin"
	{
		echo '#!/usr/bin/env bash'
		echo 'for a in "$@"; do'
		echo '	case "$a" in *.luau)'
		echo '		f="$(cygpath -u "$a")"'
		echo "		if [ -f \"\$f\" ] && ! perl \"$H/a265-banc/etape.pl\" \"\$f\"; then echo \"ÉCHEC a265 : etape.pl pas appliqué à \$f : 0 vérification(s), 1 échec(s)\"; exit 1; fi ;;"
		echo '	esac'
		echo 'done'
		echo "exec \"$HOME/.rokit/bin/luau.exe\" \"\$@\""
	} > "$A265_T/.rokit/bin/luau.exe"
	chmod +x "$A265_T/.rokit/bin/luau.exe"
	export HOME="$A265_T"
fi
VERBOSE=1 bash /c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a305-banc/dbg/run.sh "$REPO"
