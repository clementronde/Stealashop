#!/usr/bin/env bash
# Banc hors Studio d'a50 (2026-11-09, vague 18) : L-090 (icône de chaque arme dans UI_WeaponShop, par
# Contract/Icons, repli sur l'image du Template) et L-089 point 4 (un seul écran du groupe ScreenGroup
# ouvert à la fois : Motion.Open ferme les autres, Motion.SetCloser). Faux Roblox : copie de celui
# d'a19 (a46-banc/autres-bancs/a19-banc : stubs.luau, setup.luau) + ext-motion.luau d'a46 + Decal
# (ext-a50.luau). Avant la fusion d'a50 (pas de SetCloser dans Motion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a50 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a50}"
SRC="$ROOT/src"
if ! grep -q "SetCloser" "$SRC/client/Controllers/UI/Motion.luau" 2>/dev/null; then
	echo "banc a50 (icônes d'armes, un écran à la fois) : SAUTÉ, pas de Motion.SetCloser dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	echo "WITH_COSMETIC = true"
	cat "$H/stubs.luau" "$H/ext-motion.luau" "$H/ext-a50.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)" ; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
