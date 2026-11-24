#!/usr/bin/env bash
# Banc a300 (21/11, demande de Cantin) : barre de PV des boutiques de joueurs (PlayerPlot) accrochée à un point
# fixe (HealthBarPoint de Clément, sinon un Attachment à nous dans Terrain au centre de la façade), plus à la
# vitre qui coulisse ; magasins PNJ inchangés ; streaming (pièces en retard) ; sortie du streaming.
# Vrai : WindowController et tout shared/. Bouchon : Net (signaux client seuls). Faux Roblox : stubs.luau (copie
# de celui d'a44, a134-banc/autres-bancs/a44).
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
if ! grep -q "HealthBarPoint" "$SRC/client/Controllers/WindowController.luau" 2>/dev/null; then echo "banc a300 SAUTÉ : WindowController sans HealthBarPoint (avant a300)"; echo "0 vérification(s), 0 échec(s)"; exit 0; fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && { find shared -name '*.luau'; echo client/Controllers/WindowController.luau; } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"
