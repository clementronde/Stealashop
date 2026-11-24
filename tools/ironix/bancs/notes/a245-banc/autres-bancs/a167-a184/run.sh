#!/usr/bin/env bash
# Copie a245 (vague 72) : rendez-vous à 16:00 heure de Paris (Zone = "Paris") accepté, en plus de 15:00 UTC.
# Copie a184 (2026-11-15, vague 57, Cantin : plus de date fixe) : Admin Abuse chaque samedi 15:00 UTC 30 min (LiveEvents.Weekly, SlotsAt) ; repli sur l ancien planning daté si LiveEvents.SlotsAt manque.
# Banc hors Studio d'a167 (2026-11-15, vague 51, MAJ 0) : événements live du samedi (EventService, Config/LiveEvents,
# StartEvent du panel admin en ligne, bannière). Faux Roblox du banc a98 (copie a134, avec les ajouts purs d'a167 :
# Config/LiveEvents et bouchon EventService). Deux passes :
#   1. admin.luau : vrai AdminService, EventService bouchon : StartEvent d'un événement live permis en ligne pour un
#      admin, refusé à un non-admin, StopLive, Truck toujours refusé en ligne, listes du panel ;
#   2. events.luau : vrai EventService, bouchons DisplayService, MonetizationService, TrainingService, TelemetryService :
#      planning (avant, pendant, après, serveur qui démarre au milieu), un seul à la fois, chaque effet (facteurs et
#      attributs), journal, télémétrie ; lecture des attributs dans StoreHeistService, TruckEventService,
#      PotionService, WindowService (contrôle du code source).
# « SAUTÉ » sans EventService.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A98="$H/../../../a134-banc/autres-bancs/a98"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a167 (événements live)"
if [ ! -f "$SRC/server/Services/EventService.luau" ]; then
	echo "$NAME : SAUTÉ, pas d'EventService : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/AdminService.luau server/Services/EventService.luau shared/AdminLists.luau shared/Format.luau shared/Types/Profile.luau shared/Net/Definitions.luau shared/Net/Validate.luau shared/Config/LiveEvents.luau shared/Contract/UI.luau client/Controllers/EventBannerController.luau"
for s in StoreHeistService TruckEventService PotionService WindowService; do
	FILES="$FILES server/Services/$s.luau"
done
for m in Admin Balance Cosmetics DeepFreeze Features Items Monetization Mutations Potions Rarities SkillTree Telemetry Tools Unbox Upgrades Zones; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
for part in admin events; do
	OUT="$TMP/$part.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
		echo "SOURCES = {}"
		printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		tr -d '\r' < "$A98/harness.luau"
		tr -d '\r' < "$H/$part.luau"
	} > "$OUT"
	W="$OUT"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
	out=$("$LUAU" "$W" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^partie $part : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "partie $part arrêtée avant la fin (erreur ci-dessus)"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
echo "$NAME : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
