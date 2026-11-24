#!/usr/bin/env bash
# Copie d'a150 (2026-11-14, vague 43, demande de Cantin : des objets au lieu des colis dans les récompenses) de
# a105-banc/autres-bancs/a53-banc : scénarios daily, playtime et full changés (J2, J4, J7, paliers 15 et 60 min
# donnent un objet par UnboxService.GiveItem ; inventaire d'objets plein ; colis déjà dans le profil gardés ;
# GiveItem : Épique ou mieux, zone, mutation, NoContent, Invalid), setup53.luau complété (itemKeys,
# giftsSince, giftText). Sur un arbre sans UnboxService.GiveItem, relance la copie d'a105 : bonne avant et
# après la fusion.
# 2026-11-14, a150 (2e commit) : scénario upgrade (crans d amélioration de l ouverture en base appliqués à GiveItem, part mesurée sur 4000 tirages par cas).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "function UnboxService.GiveItem" "$ROOT/src/server/Services/UnboxService.luau" 2>/dev/null; then
	exec bash "$H/../../../a105-banc/autres-bancs/a53-banc/run.sh" "$@"
fi
shift || true
if grep -q "ShelfOpen = true" "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	cp -r "$ROOT/src" "$TMP/src"
	cp -r "$ROOT/docs" "$TMP/docs"
	sed -i 's/ShelfOpen = true,/ShelfOpen = false,/' "$TMP/src/shared/Config/Features.luau"
	ROOT="$TMP"
fi
bash "$H/run-base.sh" "$ROOT" "$@"
