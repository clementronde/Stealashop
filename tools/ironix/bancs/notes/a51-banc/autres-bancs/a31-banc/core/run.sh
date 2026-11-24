#!/usr/bin/env bash
# Copie d'a40 (DEV-111, 2026-11-08) : profil v2 du test chargé en v4 quand l'arbre testé a Config/Index (index des objets).
# Copie d'a38 (DEV-100, 2026-11-08) : schéma de sauvegarde v3 : le profil v2 du test est chargé en v3 quand l'arbre testé
# a la boutique Robux (Config/Monetization), en v2 sinon (main d'avant la fusion d'a38).
# Banc hors Studio de l'agent a31 (vague 11, liaison L-055 ; côté code de MOD-014, MOD-026, MOD-031) :
# catalogue à 83 objets (les 9 ajouts, la catégorie Mode / Fashion, aucun ItemId d'avant changé,
# profils v2 intacts), contrat (WavePrefix), Contract/Icons, ContractChecker (pièces Wave_, icônes
# ICON_), ItemIdleController (pièces Wave_ sans dérive, retour exact à la pose de départ, pivot des
# pièces Spin_ avec PivotOffset).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a31 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi toute la sortie des modules
# Assemble les bouchons (copie de ceux d'a22, complétés par a31), le lecteur JSON, le JSON du
# catalogue, la liste figée des 74 objets de main d'avant les ajouts, les vraies sources et les
# scénarios en un seul fichier Luau, exécuté par le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a31}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/DataService.luau server/Services/ContractChecker.luau client/Controllers/ItemIdleController.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  cat "$H/ext.luau"
  cat "$H/json.luau"
  cat "$H/main-items.luau"
  printf 'JSON_TEXT = [==========[\n'
  tr -d '\r' < "$ROOT/docs/claude/notes/objets-catalogue-v2.json"
  printf '\n]==========]\n'
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
