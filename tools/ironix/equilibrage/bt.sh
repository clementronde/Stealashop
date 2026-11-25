#!/usr/bin/env bash
# Économie « B/T » (a479, 25/11) : lanceur rapide du rapport bt (même assemblage que run.sh, en un seul awk).
#   bash tools/ironix/equilibrage/bt.sh [racine du dépôt]
#   GRAINES=40 bash tools/ironix/equilibrage/bt.sh     parties par profil tiré au hasard (défaut 25)
#   COURT=1 bash tools/ironix/equilibrage/bt.sh        seulement les temps par zone (pour régler)
#   SORTIE=fichier.md bash tools/ironix/equilibrage/bt.sh
#   ESSAI=tapis RATIO=0.65 bash tools/ironix/equilibrage/bt.sh   cherche les prix du tapis qui valent une absence complète du
#       joueur moyen (RATIO : centile de ses retours ; ABSENCE : heures comptées ; SPEED6 : Speed de la zone 6 ;
#       LIBRE : premier niveau ajusté ; PASSES : nombre de passes ; NIVEAUX : nombre de niveaux du tapis ; FIXE5=1 : les
#       zones 2 à 5 gardent leur Speed)
#   ANCIEN=1 bash tools/ironix/equilibrage/bt.sh       ressort aussi les tableaux des passes 1 à 3 (chance d'aujourd'hui, cran adouci)
# Équivalent, plus lent : RAPPORT=bt bash tools/ironix/equilibrage/run.sh
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-$(cd "$H/../../.." && pwd)}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
[ -x "$LUAU" ] || { echo "luau introuvable ($LUAU)" >&2; exit 2; }
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT
OUT="$TMP/equilibrage.luau"
{
  echo "--!nocheck"
  echo "SOURCES = {}"
  echo "OPTIONS = { Graines = ${GRAINES:-25}, Heures = ${HEURES:-40}, Rapport = \"bt\", Court = ${COURT:-0} == 1, Essai = \"${ESSAI:-}\", Rapport2 = \"${RATIO:-1}\", Speed6 = ${SPEED6:-0}, Passes = ${PASSES:-10}, Absence = ${ABSENCE:-0}, Libre = ${LIBRE:-9}, Niveaux = ${NIVEAUX:-20}, Fixe5 = ${FIXE5:-0}, Ancien = ${ANCIEN:-0} == 1 }"
  awk '
    function flush() { if (key != "") printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines; lines = "" }
    FNR == 1 {
      flush()
      n = split(FILENAME, parts, "/"); name = parts[n]; sub(/\.luau$/, "", name)
      if (parts[n - 1] == "Config") key = "Config/" name
      else if (parts[n - 1] == "equilibrage") key = "Outil/" name
      else key = name
    }
    { sub(/\r$/, ""); lines = lines $0 "\n" }
    END { flush() }
  ' "$ROOT"/src/shared/Config/*.luau "$ROOT/src/shared/Format.luau" "$ROOT/src/shared/ItemWeight.luau" \
    "$H/valeurs_bt.luau" "$H/economie_bt.luau" "$H/simulateur_bt.luau" "$H/rapport_bt.luau"
  tr -d '\r' < "$H/chargeur.luau"
} > "$OUT"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
if [ -n "${SORTIE:-}" ]; then
  "$LUAU" "$(winpath "$OUT")" | tee "$SORTIE"
else
  "$LUAU" "$(winpath "$OUT")"
fi
