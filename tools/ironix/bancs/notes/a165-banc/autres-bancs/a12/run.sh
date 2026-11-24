#!/usr/bin/env bash
# Copie a165 (2026-11-14, vague 51) : « Caught! » seul quand la vitesse demandée de la zone vaut 0 (zone 1) au lieu de
# « Caught! Recommended speed: 0 ». Lance le lanceur a158 du banc a12 avec un faux luau.exe (HOME passager, comme
# a158-banc/corrige.sh) qui change cette seule attente dans le fichier assemblé, puis appelle le vrai.
# Arbre sans a165 (GuardService sans le « Caught! » seul) : le lanceur a158 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'else "Caught!" -- vague 51' "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a12/run.sh" "$@"
fi
REAL_HOME="$HOME"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.rokit/bin"
{
	echo '#!/usr/bin/env bash'
	echo 'f="$(cygpath -u "$1")"'
	echo "sed -i 's/notify.args\[1\] == \"Caught! Recommended speed: 0\"/notify.args[1] == \"Caught!\"/; s/Notify « Caught! Recommended speed: 0 » (a134 : la Speed du panneau de la zone 1)/Notify « Caught! » seul (a165 : la zone 1 ne demande aucune vitesse)/' \"\$f\""
	echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
} > "$T/.rokit/bin/luau.exe"
chmod +x "$T/.rokit/bin/luau.exe"
HOME="$T" bash "$H/a158-banc/autres-bancs/a12/run.sh" "$@"
