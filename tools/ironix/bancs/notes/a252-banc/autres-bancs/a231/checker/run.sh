#!/usr/bin/env bash
# Banc a231, partie checker (vague 70, L-223) : le vrai ContractChecker sur 12 faux NPC_Crowd (run-base.sh, faux Roblox du
# banc a40) ; passe par ../../a158-banc/corrige.sh (motifs communs) comme le banc a227. Arbre sans Animations.Crowd : SAUTÉ.
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "^Animations.Crowd = {" "$ROOT/src/shared/Contract/Animations.luau" 2>/dev/null; then
	echo "banc a231 (foule au contrat d animations) : SAUTÉ, a231 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a158-banc/corrige.sh" a231 bash "$H/run-base.sh" "$ROOT"
