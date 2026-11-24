#!/usr/bin/env bash
# Banc hors Studio d'a420 (Cantin, 2026-11-24 : à l'écran du joueur, le vigile ne traverse jamais le joueur, n'attrape
# jamais de loin, la capture ressemble à un contact, 3 à 5 studs ; Config/Chase.ClientView.Contact). Harnais d'a416
# (a416-banc : vrai GuardService, réseau simulé, collisions d'après les groupes), fichier de tests tests.a420.luau
# (copie de tests.a416.luau + scénarios d'a420). Comme lot98-banc/autres-bancs/a416 : le banc simule des tampons dont
# la somme vaut 0,25 s, il tourne donc sur une copie de src/ remise à BaseSeconds 0,25 (DisplaySeconds 0,12) ; il
# vérifie le mécanisme, la valeur se règle en Play.
# Scénarios par défaut (chacun échoue sur le code d'avant a420, voir « …sans ») :
#   arretnet  défaut 1 : il court 6 s puis s'arrête net (zones 1, 3 et 6) : le serveur l'arrête StandOff studs derrière
#             lui dès qu'il le sait ; au-delà de ce que le retard impose (vitesse × retard − 14), plus de dépassement
#   fixe      défaut 2 : voleur immobile (allée du magasin, devant) : la capture « coincé » attend, elle aussi, que le
#             joueur ait vu le vigile à portée ; écart serveur / écran ≤ 1,5
#   demitour  défaut 3 : revenu vers le vigile en ruée, demi-tour à 25 studs : il ne le traverse pas à l'écran
# « …sans » (arretnetsans, fixesans, demitoursans) : Contact coupé, la mesure d'avant (aucun contrôle a420).
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok ; A420_SCENARIOS="…" : scénarios choisis sous
#   le lanceur ; A420_TRACE=1 : trace image par image ; A420_LOG=<fichier> : toute la sortie de chaque scénario
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
B="$(cd "$H/.." && pwd)"
SCENARIOS="${*:-${A420_SCENARIOS:-arretnet fixe demitour}}"
if ! grep -q "Contact = {" "$ROOT/src/shared/Config/Chase.luau" 2>/dev/null; then
	case " $SCENARIOS " in
	*sans*) ;;
	*)
		echo "banc a420 : SAUTÉ, a420 pas encore fusionné (0 vérification(s), 0 échec(s))"
		exit 0
		;;
	esac
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r "$ROOT/src" "$TMP/src"
perl -pi -e 's/^(\s*)BaseSeconds = 0\.34,/${1}BaseSeconds = 0.25,/' "$TMP/src/shared/Config/Chase.luau"
perl -pi -e 's/^(\s*)DisplaySeconds = 0\.15,/${1}DisplaySeconds = 0.12,/' "$TMP/src/shared/Config/Chase.luau"
SRC="$TMP/src"
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	bash "$H/assemble.sh" "$SRC" "$H/tests.a420.luau" "$name" > "$OUT"
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	# Comme a416-banc/run.sh : prise d'un objet NPCItem par l'aide d'a158 (a172-banc/corrige.sh a168).
	out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	if [ -n "${A420_LOG:-}" ]; then { echo "=== $name"; printf '%s\n' "$out"; } >> "$A420_LOG"; fi
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ|^  mesure|^    " || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a420 (contact à l'écran : arrêt net, voleur immobile, demi-tour) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
