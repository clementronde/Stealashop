#!/usr/bin/env bash
# Copie a169 (2026-11-15, vague 52, lot C) de la copie a128 du banc a22-core : Tutorial.GuaranteedRarity retiré (lu par personne),
# le contrôle de l objet garanti lit sa rareté « Rare » en dur. Le reste inchangé.
# Arbre sans ProtectShop dans Config/Tutorial (avant a169) : relance la copie a128.
if ! grep -q "ProtectShop" "${1:-/f/StealAShop}/src/shared/Config/Tutorial.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a128-banc/autres-bancs/a22-core/run.sh" "$@"; fi
# Copie d'a128 (vague 39, 2026-11-14, ItemIdleController : BulkMoveTo, objets à l'écran) : faux Camera avec FieldOfView et
# ViewportSize (stubs.luau) et Workspace:BulkMoveTo (ext.luau), ajouts purs ; tests inchangés, bons avant et après la fusion.
# Copie d'a105 (2026-11-12, vague 31, L-112 : ouverture des colis sur le rayon, Features.ShelfOpen) de a53-banc/autres-bancs/a22-core :
# avec ShelfOpen = true, DataService change les colis déjà rangés dans un profil en objets au chargement
# (convertBoxes) ; ce banc teste l'ancien déroulé avec des profils qui ont des colis : il tourne donc sur une
# copie de l'arbre où Features.ShelfOpen = false (l'ancien déroulé exact, exigence 7 de la vague). Tests
# inchangés (run-base.sh = le run.sh d'origine). La conversion elle-même est testée par a105-banc.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
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
