#!/usr/bin/env bash
# Copie d'a91 (vague 29, 2026-11-12, L-106 point 12 et L-107 point 1) : délai d'1 s par plaque (PAD_COOLDOWN), AmountGui caché à $0,
# BillboardGui ou SurfaceGui. Sur un arbre sans PAD_COOLDOWN dans DisplayService, relance la copie d'a72 : bonne avant et après la fusion.
if ! grep -q "PAD_COOLDOWN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a72-banc/autres-bancs/a59-banc/run.sh" "$@"; fi
# Copie d'a72 (vague 24, 2026-11-11) : même banc, partie 1 sur la copie a72 d'a14 (../a14-banc). Sur un arbre sans
# PAD_EXIT_MARGIN dans DisplayService, relance a59-banc/run.sh : bonne avant et après la fusion.
if ! grep -q "PAD_EXIT_MARGIN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a59-banc/run.sh" "$@"; fi
# Banc hors Studio d'a59 (vague 21, 2026-11-10, L-091 points 4 et 5 : plus de CashPad, plaques CollectPad_xx,
# montant écrit sur la plaque, ramassage, gerbe, gains hors ligne versés dans Cash). Deux parties :
#   1. autres-bancs/a14-banc (copie a59 du banc de DisplayService et DisplayController) : montant sur
#      AmountGui/Amount, ramassage par plaque, CashCollect, gerbe Emit(EmitCount), Glow, SinkDepth, OnCollect ;
#   2. tests.a59.luau (même faux Roblox, preamble.luau) : contrat, plaques des rayons posées après coup,
#      présentoir sans plaque, plaque retirée, GetCollectTarget, CashOut, encaissement automatique, hors ligne.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Sur un arbre d'avant a59 (CollectPad_xx absent de Contract/Models) : SAUTÉ.
# Autres copies d'a59 (dans autres-bancs, entrées de run-all-bancs.sh) : a28 (tuto), a35 (télémétrie),
# a48 (gains hors ligne).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if ! grep -q "CollectPad_%02d" "$SRC/shared/Contract/Models.luau" 2>/dev/null; then
	echo "banc a59 (plaques de ramassage) : SAUTÉ, pas de CollectPad_xx au contrat (a59 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A14="$H/../a14-banc"
out1=$(bash "$A14/run.sh" "$ROOT" 2>&1)
l1=$(printf '%s\n' "$out1" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A14/stubs.luau"
	(cd "$SRC" && find shared server/Services/DisplayService.luau client/Controllers/DisplayController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/preamble.luau" "$H/tests.a59.luau"
} > "$OUT"
out2=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
l2=$(printf '%s\n' "$out2" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
printf '%s\n%s\n' "$out1" "$out2" | grep -E "ÉCHEC|ERREUR|error|attempt" | head -20
if [ -z "$l1" ] || [ -z "$l2" ]; then
	printf '%s\n' "$out2" | tail -15
	echo "banc a59 (plaques de ramassage) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c1=$(printf '%s' "$l1" | sed -E 's/^([0-9]+).*/\1/')
f1=$(printf '%s' "$l1" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
c2=$(printf '%s' "$l2" | sed -E 's/^([0-9]+).*/\1/')
f2=$(printf '%s' "$l2" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "  a14 (copie a59) : $c1 contrôles, $f1 raté(s) ; a59 : $c2 contrôles, $f2 raté(s)"
echo "banc a59 (plaques de ramassage) : $((c1 + c2)) vérification(s), $((f1 + f2)) échec(s)"
exit $(((f1 + f2) > 0))
