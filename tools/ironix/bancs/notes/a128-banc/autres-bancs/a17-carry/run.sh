#!/usr/bin/env bash
# Copie d'a128 (vague 39, 2026-11-14, CarryController suit les descendants arrivés après le tag) de la copie a109 : fake.luau
# copié de a22-banc/autres-bancs/a17-carry, complété (DescendantAdded sur les ancêtres, ajout pur) ; tests inchangés.
# Copie a109 (2026-11-13, vague 32, Cantin : sur une caisse, BB_Box ne montre que la rareté avec
# Features.ShelfOpen) du banc a17-carry (copie a22) : tests.luau, 2 contrôles changés (catégorie cachée
# sur le colis porté et sur le colis du rayon ; l'ancien contrôle sur un arbre d'avant la vague 32) ;
# faux Roblox (fake.luau) lu sur place dans la copie a22.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
O="$H" # a128 : fake.luau copié ici (DescendantAdded)
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$O/fake.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
