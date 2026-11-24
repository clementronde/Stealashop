#!/usr/bin/env bash
# Tableaux de valeurs à coller dans le doc partagé (check-up a417, P3), lus dans les vraies sources :
# zones, outils, auras, traînées, raretés (et chances par zone), remotes, interrupteurs, tags.
#   bash tools/ironix/tableaux.sh                     tous les tableaux, en markdown sur la sortie
#   bash tools/ironix/tableaux.sh zones,outils        seulement ceux-là (zones, outils, auras, trainees,
#                                                     raretes, remotes, interrupteurs, tags)
#   RACINE=/chemin/du/depot bash tools/ironix/tableaux.sh   un autre dépôt ou worktree (défaut : celui du script)
# Il ne modifie rien : il assemble src/shared/Config, Format, ItemWeight, Net/Definitions et Contract/Tags avec commun/charge.luau et
# tableaux/tableaux.luau en un fichier Luau temporaire (mktemp -d), et l'exécute avec le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${RACINE:-$(cd "$H/../.." && pwd)}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if [ ! -x "$LUAU" ]; then
  echo "luau introuvable ($LUAU) : installer rokit et luau, ou définir LUAU" >&2
  exit 2
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/tableaux.luau"
S="$ROOT/src/shared"
BASE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "?")"
emit() { # emit <clé> <fichier> : SOURCES[clé] = contenu du fichier
  awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
  echo "--!nocheck"
  echo "SOURCES = {}"
  echo "OPTIONS = { Tableaux = \"${1:-}\", Base = \"$BASE\" }"
  for f in "$S"/Config/*.luau; do
    emit "Config/$(basename "$f" .luau)" "$f"
  done
  emit "Format" "$S/Format.luau"
  emit "ItemWeight" "$S/ItemWeight.luau"
  emit "Net/Definitions" "$S/Net/Definitions.luau"
  emit "Contract/Tags" "$S/Contract/Tags.luau"
  tr -d '\r' < "$H/commun/charge.luau"
  tr -d '\r' < "$H/tableaux/tableaux.luau"
} > "$OUT"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
"$LUAU" "$(winpath "$OUT")"
