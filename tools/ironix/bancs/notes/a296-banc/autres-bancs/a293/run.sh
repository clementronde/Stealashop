#!/usr/bin/env bash
# a296 : banc a293 (a293-banc/run.sh) sur un arbre à Features.NewTraps = false et NewTrapsDev = true. Copie passagère du
# lanceur (ME = a293-banc, garde « SAUTÉ » lue sur NewTrapsDev), lancée sous ../../corrige.sh avec ../../patches/a293.sed :
# partie pieges-new en jeu DEV (ProductIds Environment = "Dev"), pieges-old, complice et foule inchangées.
# Arbre sans NewTrapsDev : le lanceur d'a293 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'NewTrapsDev = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a293-banc/run.sh" "$@"
fi
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
sed -e "s|^ME=\"\$(cd \"\$(dirname \"\$0\")\" \&\& pwd)\"\$|ME=\"$H/a293-banc\"|" \
	-e 's|grep -q "NewTraps = true"|grep -q "NewTrapsDev = true"|' \
	-e 's|arbre sans Features.NewTraps = true|arbre sans Features.NewTrapsDev = true|' "$H/a293-banc/run.sh" > "$T/run.sh"
grep -q "^ME=\"$H/a293-banc\"$" "$T/run.sh" || { echo "banc a293 (a296) : copie du lanceur ratée"; exit 1; }
bash "$H/a296-banc/corrige.sh" a293 bash "$T/run.sh" "$@"
