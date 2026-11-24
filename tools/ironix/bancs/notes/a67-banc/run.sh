#!/usr/bin/env bash
# Banc hors Studio d'a67 (2026-11-11, vague 23, L-095 points 1 et 2) : IndexController sur UI_Index_v3
# (cartes et silhouettes, fiche Detail au clic, Rewards de la zone visible, ZoneItem, catégories et
# onglets de mutation, repli sur la v2), UI_Index_v3 / UI_Settings / UI_HUD.SettingsButton au contrat
# (vrai ContractChecker), SettingsService et SettingsController (curseurs souris et doigt, bascule des
# effets visuels, son de clic, groupe SFX, sauvegarde et rechargement, valeurs refusées par le serveur).
# Scénarios v3, v3contract, settings et settingsoff (Features.Settings à false) de la copie autres-bancs/a40-banc (qui lance aussi les scénarios
# d'a40 et d'a56). « SAUTÉ » sur un arbre sans UI_Index_v3 dans Contract/UI (avant la fusion).
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
out=$(bash "$H/autres-bancs/a40-banc/run.sh" "$ROOT" v3 v3contract settings settingsoff)
code=$?
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a67 (index v3, réglages)/'
exit $code
