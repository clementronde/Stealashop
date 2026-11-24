#!/usr/bin/env bash
# a283 (vague GC3, 2026-11-23, audit a271 point 5 : pièces d aura figées hors de l écran) : même chaîne que
# a262-banc/autres-bancs-cantin/a210 (avant-cantin.sh, a226-banc/avant.sh, lanceur a218), avec ext283.luau (ViewportSize
# de la caméra factice, ajout pur) et tests.a210.luau d ici (X16b, X16c : caméra tournée, pièces figées puis reparties).
# Arbre sans PieceMotion.MaxDistanceLow (avant a283) : le lanceur d avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
if ! grep -q "MaxDistanceLow" "${1:-/f/StealAShop}/src/shared/Config/Cosmetics.luau" 2>/dev/null; then exec bash "$H/a262-banc/autres-bancs-cantin/a210/run.sh" "$@"; fi
exec bash "$H/a262-banc/avant-cantin.sh" "$(cd "$(dirname "$0")" && pwd)/chain.sh" "$1"
