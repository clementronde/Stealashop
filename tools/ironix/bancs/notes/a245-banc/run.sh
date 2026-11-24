#!/usr/bin/env bash
# Banc a245 (vague 72, L-216 points 3 et 6) : rendez-vous du samedi 16 h à Paris toute l'année (Config/LiveEvents,
# Zone = "Paris", NextWeeklyStart), compte à rebours de la MAJ (Config/Codes.NextUpdateAt) ; contrôle du code source
# de PvPController (OwnerAvatar, BestItem) et du contrat (Contract/UI). « SAUTÉ » sans LiveEvents.NextWeeklyStart.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a245 (rendez-vous et MAJ)"
if ! grep -q "NextWeeklyStart" "$SRC/shared/Config/LiveEvents.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de NextWeeklyStart : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "SOURCES = {}"
	for m in DeepFreeze LiveEvents Codes; do
		printf 'SOURCES["%s"] = [==========[\n' "$m"; tr -d '\r' < "$SRC/shared/Config/$m.luau"; printf '\n]==========]\n'
	done
	cat "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
# Contrôles du code source (client et contrat).
extra=0; bad=0
src() { tr -d '\r' < "$SRC/$1"; }
for pattern in 'AVATAR_FIELD = "OwnerAvatar"' 'BEST_FIELD = "BestItem"' 'GetUserThumbnailAsync' 'refreshExtras(gui, plot, text)' 'label.TextColor3 = rarity.Color'; do
	extra=$((extra + 1)); src client/Controllers/PvPController.luau | grep -qF "$pattern" || { bad=$((bad + 1)); echo "ÉCHEC : PvPController sans « $pattern »"; }
done
for pattern in 'Path = "OwnerAvatar", Class = "ImageLabel", Optional = true' 'Path = "BestItem", Class = "TextLabel", Optional = true'; do
	extra=$((extra + 1)); src shared/Contract/UI.luau | grep -qF "$pattern" || { bad=$((bad + 1)); echo "ÉCHEC : Contract/UI sans « $pattern »"; }
done
printf '%s\n' "$out" | grep -E "ÉCHEC|error|Error" | head -20
line=$(printf '%s\n' "$out" | grep -E "^banc a245 .*vérification" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "$NAME : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME : $((c + extra)) vérification(s), $((f + bad)) échec(s)"
exit $(((f + bad) > 0))
