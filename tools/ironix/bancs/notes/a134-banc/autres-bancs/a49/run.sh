#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : PV du camion = 100 × dégâts de sa zone ; faux arbre : levier-force.luau et coups-en-rafale.luau.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a128-banc/autres-bancs/a49-banc/run.sh" "$@"; fi
# Copie d'a128 (vague 39, 2026-11-14, CarryController suit les descendants arrivés après le tag) : le scénario carry lit le faux Roblox
# de la copie a128 d'a17-carry (DescendantAdded, ajout pur) ; tests inchangés, bonne avant et après la fusion.
# Copie d'a105 (2026-11-12, vague 31, L-112 : ouverture des colis sur le rayon, Features.ShelfOpen) de a53-banc/autres-bancs/a49-banc :
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
