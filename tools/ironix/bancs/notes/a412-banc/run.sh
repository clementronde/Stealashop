#!/usr/bin/env bash
# Banc a412 (vague GC7, 23/11, textes du jeu, point 1) : messages de la caisse exclusive « Exclusive Crate: you got an Epic
# Disco Ball! » (article a / an, rareté en DisplayName) pour les 6 objets ; serveur seulement (inner.sh, mise en place du
# banc a38 sous a158-banc/corrige.sh, comme a297). Arbre sans a412 (message en DisplayNameUpper) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]     VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
LABEL="banc a412 (caisse exclusive : article et rareté des messages)"
if ! grep -q 'CrateItem = "Exclusive Crate: you got %s %s %s!"' "$ROOT/src/server/Services/MonetizationService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, message de la caisse d'avant a412 dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
out=$(bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -v -E "^banc a412 serveur : " || true
line=$(printf '%s\n' "$out" | grep -E "^banc a412 serveur : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	echo "$LABEL : arrêté avant la fin"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
