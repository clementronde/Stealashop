#!/usr/bin/env bash
# Garde-fou Steal a Shop (liaison, section 3.5) : avant un « git push » lancé par
# Claude, refuse le push si les commits envoyés modifient src/ et que l'auteur
# n'est pas Ironix. Seul Ironix écrit le code synchronisé avec Studio.
#
# Hook PreToolUse de Claude Code : reçoit l'appel d'outil en JSON sur stdin.
# Code de sortie 2 = appel bloqué, le message sur stderr est renvoyé à Claude.

input=$(cat)

# Seuls les appels qui contiennent « git push » nous intéressent.
case "$input" in
  *"git push"*|*"git.exe push"*) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

user=$(git config user.name)
if [ "$user" = "Ironix" ]; then
  exit 0
fi

# Base de comparaison : la branche suivie, sinon origin/main.
base=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || base="origin/main"
git rev-parse --verify --quiet "$base" >/dev/null || exit 0

touched=$(git diff --name-only "$base...HEAD" -- src/ 2>/dev/null)
if [ -z "$touched" ]; then
  exit 0
fi

{
  echo "PUSH REFUSÉ : ces commits modifient src/, le code d'Ironix synchronisé avec Studio."
  echo "Fichiers concernés :"
  echo "$touched" | sed 's/^/  - /'
  echo ""
  echo "Règle : docs/Liaison-Code-Visuel.md, section 3.5. Le Claude de Clément ne modifie jamais src/."
  echo "À faire : annuler ces changements dans src/ (git restore ou nouveau commit qui les retire),"
  echo "puis noter le besoin dans la liaison, section 1, avec « Pour : Ironix »."
} >&2
exit 2
