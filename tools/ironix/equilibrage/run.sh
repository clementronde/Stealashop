#!/usr/bin/env bash
# Simulateur d'équilibrage de Steal a Shop (liaison L-108, point 1), hors Studio.
#   bash tools/ironix/equilibrage/run.sh [racine du dépôt]
#   GRAINES=40 bash tools/ironix/equilibrage/run.sh      nombre de parties par profil (défaut 25)
#   HEURES=60 bash tools/ironix/equilibrage/run.sh       durée maximale d'une partie simulée (défaut 40)
#   SORTIE=fichier.md bash tools/ironix/equilibrage/run.sh   écrit aussi le rapport dans ce fichier
#   RAPPORT=v2 bash tools/ironix/equilibrage/run.sh      rapport du rééquilibrage v2 (proposition_v2.luau, rapport_v2.luau)
#   RAPPORT=v2 COURT=1 bash tools/ironix/equilibrage/run.sh   v2 : seulement les temps par zone (pour régler)
#
# Il ne modifie rien : il lit les vraies sources de src/shared/Config (et src/shared/Format.luau),
# les assemble avec les modules de ce dossier en un seul fichier Luau temporaire, et l'exécute avec
# le luau de rokit (comme les bancs). Le rapport sort en Markdown (tableaux).
#   chargeur.luau     faux `script` et `require`, Color3 : charge les modules de Config tels quels
#   proposition.luau  la nouvelle échelle proposée (les valeurs à discuter sont toutes là)
#   modele.luau       les deux économies (actuelle = vraies formules, proposée), le joueur simulé
#   chance.luau       chance de l'ouverture dans le magasin (L-112) : table proposée, crans, témoins
#   caisses.luau      rareté tirée à l'ouverture dans la table de la caisse (L-122) : BoxRarityOdds, LuckBoost
#   rapport.luau      tableaux avant / après et parties simulées (12 : la chance ; 13 : les caisses)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-$(cd "$H/../../.." && pwd)}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if [ ! -x "$LUAU" ]; then
  echo "luau introuvable ($LUAU) : installer rokit et luau, ou définir LUAU" >&2
  exit 2
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/equilibrage.luau"
emit() { # emit <clé> <fichier> : SOURCES[clé] = contenu du fichier
  awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
  echo "--!nocheck"
  echo "SOURCES = {}"
  echo "OPTIONS = { Graines = ${GRAINES:-25}, Heures = ${HEURES:-40}, Rapport = \"${RAPPORT:-v1}\", Court = ${COURT:-0} == 1 }"
  for f in "$ROOT"/src/shared/Config/*.luau; do
    emit "Config/$(basename "$f" .luau)" "$f"
  done
  emit "Format" "$ROOT/src/shared/Format.luau"
  for m in proposition proposition_v2 modele chance caisses rapport rapport_v2; do
    emit "Outil/$m" "$H/$m.luau"
  done
  tr -d '\r' < "$H/chargeur.luau"
} > "$OUT"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
if [ -n "${SORTIE:-}" ]; then
  "$LUAU" "$(winpath "$OUT")" | tee "$SORTIE"
else
  "$LUAU" "$(winpath "$OUT")"
fi
