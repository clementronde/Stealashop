#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : vitesses des vigiles (0,9 × marche + 1 : 20,8, 26,2, 31,5) et message de capture avec la Speed du panneau.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a90-banc/autres-bancs/a12-harness/run.sh" "$@"; fi
# Copie d'a90 (2026-11-12, vague 29, L-106 points 5 et 6) : « Caught! » part en « Alert » (sans UI_Deny) ; « Warning » accepté aussi.
# Copie d'a66 (2026-11-11, poursuite sans fin) de la copie d'a57 : S4 et S5 vérifient que le vigile poursuit encore après 22 s et au-delà de 125 studs (sans GiveUpChaseDuration dans Config/Balance ; sinon les anciens contrôles : bonne avant et après la fusion).
# Copie d'a57 (2026-11-11, L-091 point 1) de la copie d'a45 : BasePart.AssemblyLinearVelocity (Vector3.zero) ajoutée au faux Roblox, lue par la poursuite anticipée de GuardService. S9 : un seul chemin pour une cible immobile, un nouveau quand elle s'éloigne de 6 studs (avant : un toutes les 0,3 s ; sans a57, l'ancien contrôle).

# Copie d'a45 (2026-11-08, L-077 : retour du vigile par un chemin, fondu à la fin) de la copie d'a41 : le vigile qui rentre s'efface en 0,6 s au lieu de disparaître d'un coup (S6 : fin du portage pendant le délai ; S7 : place libérée au plafond, 7 modèles le temps du fondu).
# Copie d'a41 (2026-11-08, L-071) de la copie d'a36 : sans marqueur Impact, une Catch chargée pousse à sa fin (1,2 s dans le scénario S8) et non plus après 0,6 s.
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc d'essai hors Studio de GuardService et ChaseController (a12, DEV-018).
#   bash run.sh [racine src]
# Défaut : /f/StealAShop/agents/a12/src ; après fusion : bash run.sh /f/StealAShop/src
# Joue tous les scénarios deux fois : rig de remplacement de Roblox, puis rig en blocs.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a21/src}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
for mode in roblox blocks; do
  {
    cat "$H/stubs.luau"
    cat "$H/../../../a90-banc/autres-bancs/stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
    printf '\nRIG_MODE = "%s"\n' "$mode"
    (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    cat "$H/tests.luau"
  } > "$OUT"
  "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
done
