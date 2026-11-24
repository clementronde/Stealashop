#!/usr/bin/env bash
# f70c2 (correctifs de fusion70) : le banc a182 (lanceur d'avant : a221-banc/autres-bancs/a182/run.sh) avec
# f70c2-banc/patches/a182.sed (F1 lit le cap après le freinage et la rotation progressive du témoin). Sans f70c2
# (pas de Witness.Photo.TurnTime) : le lanceur d'avant tel quel.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "TurnTime = " "$ROOT/src/shared/Config/Witness.luau" 2>/dev/null; then
	exec bash "$H/a221-banc/autres-bancs/a182/run.sh" "$ROOT"
fi
exec bash "$H/f70c2-banc/corrige.sh" a182 bash "$H/a221-banc/autres-bancs/a182/run.sh" "$ROOT"
