#!/usr/bin/env bash
# Modifiée par a87 (2026-11-11, demande de Cantin) : le fond devient une playlist de 6 morceaux (Music.AmbientTracks) → setup livre les 6 Sound sans boucle (Volume 0,2) en plus des anciens, signal Ended ajouté au faux Roblox, tests.music et tests.missing réécrits ; avant a87 (Music.AmbientTrack seul) : tests.<nom>.a86.luau, les tests d'a86.
# Copie d'a86 (2026-11-11, demande de Cantin) : musique de fond unique MUS_Ambient partout (plus de musique par zone), repli MUS_Hub → setup (MUS_Ambient livrée), tests.music et tests.missing réécrits.
# Copie d'a53 (2026-11-09, DEV-101) : RewardsButton est lu par RewardsController → C5 attend RewardsButton et RewardsAlert au contrat quand l'arbre a Config/Rewards, absent sinon (contract) ; bonne avant et après la fusion.
# Banc hors Studio d'a33 (vague 11) : sons de pas de Roblox retirés (FootstepController, L-056),
# musique par zone (MusicController, Config/Music, L-056), barre BB_TruckHP du camion
# (TruckController, L-052), bouton Invite (InviteController, L-057), contrat UI (Contract/UI lu par
# le vrai ContractChecker).
# Vrais : Config, Contract, Format, Loader, les 4 contrôleurs, ContractChecker. Bouchon : Net (côté
# client). Faux Roblox : stubs.luau (copie de celui d'a27, complétée).
# Chaque scénario tourne dans son propre luau (état neuf) : pre.<nom>.luau s'il existe, setup.luau,
# puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a33 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a33}"
# Avant la fusion d'a86 (pas de Music.AmbientTrack) : le banc d'origine, pour rester bon avant et après.
if ! grep -q AmbientTrack "$ROOT/src/shared/Config/Music.luau" 2>/dev/null; then exec bash "$H/../../../a53-banc/autres-bancs/a33-banc/run.sh" "$@"; fi
shift || true
# Avant a87 (pas de Music.AmbientTracks) : les tests d'a86 (fond MUS_Ambient).
OLD=""
if ! grep -q AmbientTracks "$ROOT/src/shared/Config/Music.luau" 2>/dev/null; then OLD=1; fi
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-footsteps music missing truck invite contract}"
FILES="shared client/Controllers/FootstepController.luau client/Controllers/MusicController.luau client/Controllers/InviteController.luau client/Controllers/TruckController.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		if [ -n "$OLD" ] && [ -f "$H/tests.$name.a86.luau" ]; then cat "$H/tests.$name.a86.luau"; else cat "$H/tests.$name.luau"; fi
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a33 (sons, musique, camion, invite) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
