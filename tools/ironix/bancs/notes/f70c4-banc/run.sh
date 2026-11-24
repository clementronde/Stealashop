#!/usr/bin/env bash
# Banc hors Studio de f70c4 (Cantin, 18/11 : « retour au jeu fluide car fin anim trop brusque ») : RevealController et
# Reveal/Unbox, mise en place des bancs a204 et a251 (scénario client), avec un faux BindToRenderStep par priorité et une
# fausse caméra du jeu (priorité Camera) : retour en douceur à Land, mur, fin par RevealEnded, mort, nouvelle scène,
# fin en fondu de la dernière action. Arbre sans f70c4 (pas de Config/Reveal.Return) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc f70c4 (retour au jeu après l'ouverture du colis)"
if ! grep -q '^	Return = {' "$SRC/shared/Config/Reveal.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, f70c4 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
A68="$N/a71-banc/autres-bancs/a68-banc"
A204="$N/a246-banc/autres-bancs/a204"
OUT="$TMP/run.retour.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A68/stubs.luau"
	cat "$H/rendu.luau"
	sources "shared client/Controllers/UI client/Controllers/Reveal client/Controllers/RevealController.luau"
	cat "$A204/pre.client.luau"
	cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
	cat "$A68/common.luau"
	cat "$A204/head.client.luau"
	cat "$N/a251-banc/head.client.luau"
	sed '/^section("U\./,$d' "$N/a251-banc/tests.client.luau"
	cat "$H/tests.return.luau"
} > "$OUT"
sed -E -i -f "$H/patches/rendu.sed" "$OUT"
grep -q 'BENCH_BIND(name' "$OUT" || { echo "$LABEL : faux BindToRenderStep non posé (stubs changés ?) : 0 vérification(s), 1 échec(s)"; exit 1; }
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$LABEL : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
