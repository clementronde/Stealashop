#!/usr/bin/env bash
# a275 (vague GC2, 2026-11-23, audit a272 lot E) : nouveau banc, deux parties posées sur des bancs existants sans les
# recopier (même mécanisme que a158-banc/corrige.sh : faux luau.exe dans un HOME passager, enchaîné sur celui d'avant) :
#   - admin.luau ajouté à la fin du fichier assemblé du banc a98 (lanceur commun) : rang relu (GroupService), seuil 255 ;
#   - bulles.luau ajouté à la fin de celui du banc a214 : âge minimal d'une bulle (« TooSoon »).
# Chaque partie remet CHECKS et FAILS à zéro et imprime sa ligne ; le banc les additionne.
# Arbre sans a275 (pas de ClaimMinAge dans Config/Bubbles) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
LABEL="banc a275"
if ! grep -q "ClaimMinAge" "$ROOT/src/shared/Config/Bubbles.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a275 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
REAL_HOME="$HOME"
part() { # <nom> <fichier ajouté> <lanceur du banc de base>
	local T
	T="$(mktemp -d)"
	mkdir -p "$T/.rokit/bin"
	{
		echo '#!/usr/bin/env bash'
		echo 'f="$(cygpath -u "$1")"'
		echo "if [ -f \"\$f\" ]; then tr -d '\r' < \"$2\" >> \"\$f\"; fi"
		echo "exec \"$REAL_HOME/.rokit/bin/luau.exe\" \"\$@\""
	} > "$T/.rokit/bin/luau.exe"
	chmod +x "$T/.rokit/bin/luau.exe"
	HOME="$T" VERBOSE=1 bash "$3" "$ROOT" 2>&1
	rm -rf "$T"
}
total=0
fails=0
for spec in "admin:$H/admin.luau:$N/f57-banc/autres-bancs/a98/run.sh" "bulles:$H/bulles.luau:$N/a214-banc/run.sh"; do
	name="${spec%%:*}"; rest="${spec#*:}"; file="${rest%%:*}"; base="${rest#*:}"
	out="$(part "$name" "$file" "$base")"
	mine="$(printf '%s\n' "$out" | sed -n '/^--- a275$/,$p')"
	line="$(printf '%s\n' "$mine" | grep -E "^banc a275-$name : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)"
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "$LABEL ($name) : arrêté avant la fin"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$mine"; else printf '%s\n' "$mine" | grep -E "ÉCHEC|ERREUR" || true; fi
	c="$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')"
	e="$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')"
	total=$((total + c)); fails=$((fails + e))
done
echo "$LABEL : $total vérification(s), $fails échec(s)"
[ "$fails" -eq 0 ]
