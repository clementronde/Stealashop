#!/usr/bin/env bash
# Banc hors Studio de a45 (2026-11-08, liaison L-077 point 1) : le retour du vigile de jour au
# magasin dans GuardService. Chemin (jamais droit dans un mur), fin a) « Door » et b) « Reserve »,
# rideau baissé ou vitrine reconstruite (arrêt devant la porte), fondu au lieu d'une disparition
# d'un coup, réouverture pendant le retour, échec du chemin, rideau jamais retenu longtemps par un
# vigile qui rentre, plafond du serveur, vigiles de nuit inchangés.
# Vrais : GuardService, Shared (Config, Contract, Net, Anim, Format). Bouchons : CarryService,
# StatsService, AntiCheatService. Faux Roblox : celui du banc a24 (copie d'a36 : stubs.luau,
# stubs.a24.luau), complété dans stubs.a45.luau (Decal, chercheur de chemin sur graphe).
# Joue les scénarios trois fois : Balance.Guard.ReturnEnd = "Reserve" (V0), "Door", puis une
# valeur fausse (« Bogus », traitée comme "Reserve").
#   bash run.sh [racine du dépôt]   (défaut : le worktree a45 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a45}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/GuardService.luau"
for mode in Reserve Door Bogus; do
  {
    cat "$H/stubs.luau" "$H/stubs.a24.luau" "$H/stubs.a45.luau"
    cat "$H/stub-anticheat.luau"
    printf '\nRETURN_END = "%s"\n' "$mode"
    (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    cat "$H/tests.luau"
  } > "$OUT"
  "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
done
