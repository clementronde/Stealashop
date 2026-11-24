#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : partie heist sur la copie a135 (heist/ : Balance.Heist.Duration à 10 dans le faux arbre) ; partie guard : celle d'a94, copiée telle quelle.
# Copie d'a94 (2026-11-12, L-108 point 2) : G3 (guard/tests.guard.luau) fait courir Jude à Night.ChaseSpeed dès le départ quand le champ existe (vigile de nuit à 80) ; sinon comme a69 : bonne avant et après la fusion.
# Copie d'a69 (2026-11-11, vague 24, interception) : guard/ adapté (G2a : point repris au plus toutes les
# 0,1 s sur un arbre avec interceptPoint, sinon comme a66) ; heist/ : celui d'a66, tel quel.
# Banc hors Studio d'a66 (2026-11-11, vague 23, décisions de Cantin) :
#   guard/ : poursuite sans fin (au-delà de 20 s et de 120 studs, de jour et de nuit), fin en zone safe,
#            trajet le plus court sans anticipation (la cible zigzague, le vigile ne recopie pas chaque
#            zigzag), GuardService.OnGuardGone au départ du vigile ; faux Roblox du banc a12 (copie d'a66) ;
#   heist/ : magasin fermé pour le voleur seulement (StoreHeistService, attribut ClosedStores), rideau local
#            (StoreLockController), un autre joueur peut voler, réouverture pour lui au retour de son
#            vigile, plus de message de ban ; faux Roblox du banc a17-heist (copie d'a66).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a66 ; après fusion : /f/StealAShop)
# Avant la fusion d'a66 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a66}"
total=0; failed=0; broken=0
for part in guard heist; do
	dir="$H/$part"
	true # a135 : heist et guard ici (heist : copie a135 de celui d'a66)
	out=$(timeout 300 bash "$dir/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a66 (poursuite sans fin, magasin fermé pour le voleur) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
