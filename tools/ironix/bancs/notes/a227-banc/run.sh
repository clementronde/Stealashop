#!/usr/bin/env bash
# Banc a227 (vague 69, L-175) : ContractChecker sur UI_TheftAlert v3 de Clément (éléments dans Banner.Unused) puis sans
# ThiefName, ItemName, Arrow ; le scénario de l'alerte elle-même est dans autres-bancs/a32 (ONLY="a32 a227").
# Arbre sans a227 (ThiefName encore obligatoire) : SAUTÉ. Passe par ../a158-banc/corrige.sh (motifs communs) comme le banc a40,
# avec ShelfOpen coupé dans une copie de l'arbre comme a117-banc/autres-bancs/a40-banc/run.sh.
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'Path = "ThiefName", Optional = true' "$ROOT/src/shared/Contract/UI.luau" 2>/dev/null; then
	echo "banc a227 (alerte de vol en bandeau) : SAUTÉ, a227 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
if grep -q "ShelfOpen = true" "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	cp -r "$ROOT/src" "$TMP/src"
	sed -i 's/ShelfOpen = true,/ShelfOpen = false,/' "$TMP/src/shared/Config/Features.luau"
	ROOT="$TMP"
fi
bash "$H/../a158-banc/corrige.sh" a227 bash "$H/run-base.sh" "$ROOT"
