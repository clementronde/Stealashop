#!/usr/bin/env bash
# Contrôle « orphelins » de src/ (check-up a417, P4), à rejouer à chaque fusion : remotes sans émetteur ou sans
# écouteur, interrupteurs (Config/Features) jamais lus, clés de Config jamais lues, tags lus par le code mais absents
# de Contract/Tags. Recherche par mots : chaque ligne sortie se vérifie à la main avant de retirer quoi que ce soit.
#   bash tools/ironix/orphelins.sh                    rapport markdown sur la sortie
#   CARTE=tags.txt bash tools/ironix/orphelins.sh     compare aussi une liste des tags posés dans la map (un par ligne,
#                                                     relevée dans Studio) au contrat
#   RACINE=/chemin/du/depot bash tools/ironix/orphelins.sh   un autre dépôt ou worktree (défaut : celui du script)
# Code de sortie : 0 toujours (c'est un rapport) ; 2 si luau ou perl manque.
# Étapes : orphelins/extraire.luau (avec commun/charge.luau, dans un fichier assemblé sous mktemp -d) sort les noms
# des remotes, interrupteurs, clés de Config et tags du contrat ; orphelins/analyse.pl les cherche dans src/.
# Les avertissements de luau-lsp ne sont pas ici : script de typecheck des agents.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${RACINE:-$(cd "$H/../.." && pwd)}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if [ ! -x "$LUAU" ]; then
  echo "luau introuvable ($LUAU) : installer rokit et luau, ou définir LUAU" >&2
  exit 2
fi
command -v perl >/dev/null || { echo "perl introuvable" >&2; exit 2; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/orphelins.luau"
S="$ROOT/src/shared"
emit() { # emit <clé> <fichier> : SOURCES[clé] = contenu du fichier
  awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
  echo "--!nocheck"
  echo "SOURCES = {}"
  echo "OPTIONS = {}"
  for f in "$S"/Config/*.luau; do
    emit "Config/$(basename "$f" .luau)" "$f"
  done
  emit "Format" "$S/Format.luau"
  emit "ItemWeight" "$S/ItemWeight.luau"
  emit "Net/Definitions" "$S/Net/Definitions.luau"
  emit "Contract/Tags" "$S/Contract/Tags.luau"
  tr -d '\r' < "$H/commun/charge.luau"
  tr -d '\r' < "$H/orphelins/extraire.luau"
} > "$OUT"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
"$LUAU" "$(winpath "$OUT")" > "$TMP/extraction.tsv"
perl "$H/orphelins/analyse.pl" "$ROOT" "${CARTE:-}" < "$TMP/extraction.tsv"
