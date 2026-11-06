#!/usr/bin/env bash
# Contrôle rapide du code de Steal a Shop, à lancer avant chaque commit et
# après chaque fusion :
#   bash tools/check.sh            (contrôle src/ du dossier courant du dépôt)
#   bash tools/check.sh <racine>   (contrôle <racine>/src, par exemple un worktree d'agent)
#
# Vérifie pour chaque fichier .luau de src/ :
#   - la syntaxe Luau (compilation par le luau de rokit, sans rien exécuter) ;
#   - la première ligne `--!strict` ;
#   - un nom de fichier compris par Script Sync (.luau, .legacy.luau, .local.luau).
# Ne remplace pas un test en Play dans Studio : il ne voit ni les erreurs de
# type ni les erreurs d'exécution.

set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
LUAU="${LUAU:-$HOME/.rokit/bin/luau.exe}"
if [ ! -x "$LUAU" ]; then
  echo "luau introuvable ($LUAU) : installer rokit et luau, ou définir LUAU" >&2
  exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
count=0

winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

while IFS= read -r -d '' f; do
  count=$((count + 1))
  rel="${f#"$root"/}"

  case "$f" in
    *.server.luau|*.client.luau)
      echo "NOM     $rel : Script Sync attend .legacy.luau (Script) ou .local.luau (LocalScript)"; fail=1 ;;
  esac

  if ! head -1 "$f" | tr -d '\r' | grep -q '^--!strict'; then
    echo "STRICT  $rel : la première ligne doit être --!strict"; fail=1
  fi

  {
    printf 'local src = [==========[\n'
    cat "$f"
    printf '\n]==========]\nlocal fn, err = loadstring(src, "%s")\nif not fn then print("SYNTAXE " .. tostring(err)) end\n' "$rel"
  } > "$tmp/check.luau"
  out=$("$LUAU" "$(winpath "$tmp/check.luau")" 2>&1)
  if [ -n "$out" ]; then
    echo "$out"; fail=1
  fi
done < <(find "$root/src" -name '*.luau' -print0 | sort -z)

if [ "$fail" -eq 0 ]; then
  echo "OK : $count fichier(s) contrôlé(s)"
else
  echo "ÉCHEC : voir les lignes ci-dessus ($count fichier(s) contrôlé(s))"
fi
exit "$fail"
