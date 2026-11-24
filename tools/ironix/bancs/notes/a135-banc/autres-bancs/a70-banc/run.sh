#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : heist/ avec Balance.Heist.Duration à 10 dans le faux arbre ; window/ copié tel quel (faux Roblox d'a44 lu sur place).
# Banc hors Studio d'a70 (2026-11-11, vague 24, retours de Cantin) :
#   heist/  : rideau local qui attend la sortie du vigile et remonte avant son retour (StoreHeistService,
#             attribut ClosedStores, StoreLockController), entrée toujours refusée ; un seul braquage à la
#             fois (2e vitrine refusée avec message, cadence du message, même vitrine permise, fin du
#             braquage) ; faux Roblox du banc a17-heist (copie d'a66) ;
#   window/ : vrai WindowService, AddHitGate (aucun dégât si refusé) ; faux Roblox du banc a16 (copie d'a44).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a70 ; après fusion : /f/StealAShop)
# Avant la fusion d'a70 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a70}"
total=0; failed=0; broken=0
for part in heist window; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a70 (rideau local qui attend le vigile, un seul braquage à la fois) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
