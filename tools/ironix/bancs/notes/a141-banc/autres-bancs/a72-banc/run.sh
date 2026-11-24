#!/usr/bin/env bash
# Copie a141 (2026-11-14, L-142) : identique à la copie a129, mais sur la copie a141 d a14 (../a14-banc : halos aux valeurs de Clément) ; bonne avant et après la fusion.
# Copie d'a129 (vague 39, 2026-11-14) : identique au banc a72, mais les plaques passent par la copie a129 d'a59 (../a59-banc,
# faux Camera avec FieldOfView et ViewportSize lus par DisplayController) ; bonne avant et après la fusion.
# Banc hors Studio d'a72 (vague 24, 2026-11-11, retours du Play de Cantin) :
#   1. bar/ : BenchBarController (client) : barre au milieu de LeftHand et RightHand, dans leur axe, à
#      chaque image, pour tout joueur dont le banc porte BenchUserId ; rendue à sa place exacte à la fin
#      (attribut retiré, banc retiré, autre joueur). Faux Roblox avec vraies rotations (bar/harness.luau).
#   2. Ramassage sur une plaque : scénarios dans la copie a72 d'a14 (autres-bancs/a14-banc, section 3),
#      lancée ici par la copie a72 d'a59.
# Copies d'a72 (entrées de run-all-bancs.sh) : a14 et a59 (Touched compté près de la plaque, un seul
# ramassage par arrivée), a58 (plus de soudure, BenchUserId). Sur un arbre sans BenchBarController : SAUTÉ.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
CTL="$SRC/client/Controllers/BenchBarController.luau"
if [ ! -f "$CTL" ]; then
	echo "banc a72 (barre du banc, plaques) : SAUTÉ, pas de BenchBarController (a72 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/bar/run.luau"; mkdir -p "$R1_D/bar"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	printf 'SOURCE = [==========[\n'
	tr -d '\r' < "$CTL"
	printf '\n]==========]\n'
	cat "$H/bar/harness.luau" "$H/bar/tests.luau"
} > "$OUT"
out1=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
l1=$(printf '%s\n' "$out1" | grep -E "^banc a72 \(barre du banc\) : [0-9]+ vérification" | tail -1)
out2=$(bash "$H/../a59-banc/run.sh" "$ROOT" 2>&1) # a129 : copie a129 d'a59 (avant : ../a91-banc/autres-bancs/a59-banc) # a91 (2026-11-12) : copie a91 d’a59, qui relance la nôtre sans PAD_COOLDOWN
l2=$(printf '%s\n' "$out2" | grep -E "^banc a59 .*: [0-9]+ vérification" | tail -1)
printf '%s\n%s\n' "$out1" "$out2" | grep -E "ÉCHEC|ERREUR|error|attempt" | head -20
if [ -z "$l1" ] || [ -z "$l2" ]; then
	printf '%s\n' "$out1" | tail -10
	echo "banc a72 (barre du banc, plaques) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c1=$(printf '%s' "$l1" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
f1=$(printf '%s' "$l1" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
c2=$(printf '%s' "$l2" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
f2=$(printf '%s' "$l2" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "  barre : $c1 contrôles, $f1 raté(s) ; plaques (copie a59) : $c2 contrôles, $f2 raté(s)"
echo "banc a72 (barre du banc, plaques) : $((c1 + c2)) vérification(s), $((f1 + f2)) échec(s)"
exit $(((f1 + f2) > 0))
