#!/usr/bin/env bash
# Copie a177 (2026-11-15, vague 55, Cantin : le bot frappe celui qui casse sa porte) du banc a124, par-dessus la copie
# a175 (lancée telle quelle) : chaque scénario lu par elle (door, grab, flee, gentle ; même choix de fichier qu'elle :
# a175 si l'arbre a exitStep, sinon a169, sinon a124) passe par A149_TESTS précédé de prelude.luau : pendant breakDoor
# sur la porte du bot, le frappeur compte comme en tuto, le bot ne le dérange pas (comme avant la vague 55). Le
# scénario tuto ne change pas. Arbre sans WindowService.IsBreaking (avant a177) : la copie a175 tourne telle quelle.
#   bash run.sh [racine du dépôt] [scénarios…]
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/../../.."
UP="$N/a175-banc/autres-bancs/a124/run.sh"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "function WindowService.IsBreaking" "$ROOT/src/server/Services/WindowService.luau" 2>/dev/null; then exec bash "$UP" "$@"; fi
shift || true
SCENARIOS="${*:-door grab flee gentle tuto}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for s in $SCENARIOS; do
	[ "$s" = "tuto" ] && continue
	T="$N/a124-banc/tests.$s.luau"
	[ -f "$N/a169-banc/autres-bancs/a124/tests.$s.luau" ] && T="$N/a169-banc/autres-bancs/a124/tests.$s.luau"
	if grep -q "local function exitStep" "$ROOT/src/server/Services/BotService.luau" 2>/dev/null && [ -f "$N/a175-banc/autres-bancs/a124/tests.$s.luau" ]; then
		T="$N/a175-banc/autres-bancs/a124/tests.$s.luau"
	fi
	[ -f "$T" ] && cat "$H/prelude.luau" "$T" > "$TMP/tests.$s.luau"
done
A149_TESTS="$TMP" bash "$UP" "$ROOT" $SCENARIOS
