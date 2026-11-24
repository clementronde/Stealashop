#!/usr/bin/env bash
# Copie a152 (2026-11-14, vague 44, Cantin : « oui en main », Config/HeldItem.DepositToHand = true) : les tests de ce banc
# attendent l'ancien dépôt (objet volé posé sur un présentoir libre du voleur), gardé derrière DepositToHand = false.
# Ce lanceur copie l'arbre src, y met DepositToHand = false, puis lance le banc d'origine dessus (a146-banc/autres-bancs/a29-banc) ;
# le nouveau dépôt (true) est contrôlé par le banc a152 (deposit). Sans DepositToHand : le banc d'origine tel quel.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
ORIG="$H/../../../a146-banc/autres-bancs/a29-banc/run.sh"
if ! grep -q "DepositToHand = true," "$ROOT/src/shared/Config/HeldItem.luau" 2>/dev/null; then
	exec bash "$ORIG" "$ROOT" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r "$ROOT/src" "$TMP/src"
sed -i 's/DepositToHand = true,/DepositToHand = false,/' "$TMP/src/shared/Config/HeldItem.luau"
bash "$ORIG" "$TMP" "$@"
