#!/usr/bin/env bash
# Banc hors Studio d'a416 (Cantin, 2026-11-23 : « le vigile attrape de hyper loin le joueur », « surtout dans les zones
# rapides » ; Config/Chase.ClientView, Guard/ClientView), vrai GuardService sur le harnais d'a193/a249/a250/a252/f70c3.
# Réseau simulé : aller simple L (= GetNetworkPing), position du personnage reçue L + 8 images (0,133 s) en retard,
# vigile vu par le client L + 7 images (0,117 s) en retard (tampons de réplication ; leur somme = BaseSeconds, 0,25 s).
# « Vue » = distance entre la vraie position du client et le vigile tel que son écran le montre. Collisions simulées
# d'après les groupes de collision.
# Lancés par défaut (ils tiennent dans les 600 s du lanceur ; verts le 23/11 sur le code du commit) :
#   unite        le module seul : retard, groupes, position estimée (mur), relevé du vigile, arrêt avant la capture,
#                distance gardée sur un voleur à l'arrêt, pas vers le joueur après la capture (48 contrôles)
#   zones        capture en ligne droite aux vitesses réelles des zones 1 à 6 (Speed du panneau, avec l'objet) et au
#                plafond de la marche, ping 67 ms : vue ≤ 4 studs à la décision, à l'annonce et au repos (56)
#   zonesavant   la même mesure avec Chase.ClientView.Enabled = false (règle d'a193) : 3 + vitesse × retard (42)
# À lancer à part (A416_SCENARIOS="…", ≈ 20 s par poursuite sur une machine chargée) :
#   pings        zones 4 et 6 × ping 0, 133 et 200 ms (lancé le 23/11 : 37 contrôles, 1 raté sur une tolérance corrigée
#                depuis, pas relancé) ; pingsavant : la mesure d'avant (31 contrôles, vert le 23/11)
#   tenue        au-dessus du minimum : distance vue 14 ± 1, pas de capture ; tenueavant : la mesure d'avant (lancés
#                le 23/11 avant le calage des retards sur des images entières : 14,2 à 14,6 après, 21,5 à 46,3 avant ;
#                PAS relancés depuis, plafond allongé à 18 s)
#   ecart        tampons réels 0,10 s au-dessus ou au-dessous de BaseSeconds : le vigile est décalé de vitesse × erreur,
#                et la recette de réglage (distance vue − prévue, sur la vitesse) retrouve l'erreur (JAMAIS lancé dans
#                sa forme finale)
#   arret        le voleur s'arrête net (élan du vigile simulé) : attrapé, au repos à portée ; arretavant (JAMAIS lancés)
#   depart       départ arrêté (zone 6) quand le vigile est à 20 studs à l'écran : pas de capture ; departavant :
#                attrapé de loin (JAMAIS lancés)
#   heurte       voleur qui heurte encore les vigiles (groupe inconnu) : la règle d'avant, attrapé au contact (JAMAIS lancé)
# Les scénarios jamais lancés peuvent demander une mise au point de leurs contrôles (pas du code du jeu).
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok ; A416_SCENARIOS="…" : scénarios choisis sous le
#   lanceur ; A416_LOG=<fichier> : toute la sortie de chaque scénario (mise au point)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
B="$(cd "$H/.." && pwd)"
# Par défaut : seulement ce qui tient dans les 600 s du lanceur sur une machine chargée (≈ 20 s par poursuite).
SCENARIOS="${*:-${A416_SCENARIOS:-unite zones zonesavant}}"
if ! [ -f "$SRC/server/Services/Guard/ClientView.luau" ] 2>/dev/null; then
	echo "banc a416 : SAUTÉ, a416 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	bash "$H/assemble.sh" "$SRC" "$H/tests.a416.luau" "$name" > "$OUT"
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	# Comme f70c3-banc/run.sh : prise d'un objet NPCItem par l'aide d'a158 (a172-banc/corrige.sh a168), le colis fermé n'existe plus.
	out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	if [ -n "${A416_LOG:-}" ]; then { echo "=== $name"; printf '%s\n' "$out"; } >> "$A416_LOG"; fi # mise au point : toute la sortie
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
echo "banc a416 (capture vue par le joueur : retard complet, vigile qui traverse, capture sur ce que le joueur voyait) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
