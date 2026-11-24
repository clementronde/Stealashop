#!/usr/bin/env bash
# Lance le banc a15 puis les copies corrigées des bancs a08 et a10 à a14 (dossier autres-bancs) sur
# une racine de dépôt, et résume. Les copies diffèrent des originaux par :
#   a08 : Color3.fromHex ajouté au faux Roblox (Config/Rarities l'utilise depuis L-018) ;
#   a13 : CFrame:ToObjectSpace ajouté au faux Roblox ; vérification « BB_OpenTimer accroché au
#         dessus de l'établi » ;
#   a11 : LabelPoint dans le BOX_Luxe simulé ; vérifications « BB_Carry accroché au LabelPoint livré » ;
#   a14 : vérification « BB_Item accroché au pied de l'objet » ; « retour en Studio du revenu »
#         remplacé (le revenu est dans UI_HUD.Income) ;
#   a10 : « chrono écrit dans la sortie » remplacé (une ligne par envoi, le compte à rebours est au HUD) ;
#   a12 : « distance écrite dans la sortie » remplacé (la jauge GuardMeter la montre).
#   bash run-all.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a15 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a15}"
status=0
for entry in "a15-banc:$H/run.sh:$ROOT" "a08-harness:$H/autres-bancs/a08-harness/run.sh:$ROOT/src" \
  "a10-banc:$H/autres-bancs/a10-banc/run.sh:$ROOT/src" "a11-carry-bench:$H/autres-bancs/a11-carry-bench/run.sh:$ROOT" \
  "a12-harness:$H/autres-bancs/a12-harness/run.sh:$ROOT/src" "a13-banc:$H/autres-bancs/a13-banc/run.sh:$ROOT" \
  "a14-banc:$H/autres-bancs/a14-banc/run.sh:$ROOT"; do
  name="${entry%%:*}"; rest="${entry#*:}"; script="${rest%%:*}"; arg="${rest#*:}"
  out=$(bash "$script" "$arg" 2>&1)
  summary=$(printf '%s\n' "$out" | grep -E "vérification\(s\)" | tr '\n' ' ')
  printf '%-16s %s\n' "$name" "${summary:-ERREUR (pas de résumé)}"
  printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" | sed 's/^/    /'
  if printf '%s\n' "$summary" | grep -qvE " 0 échec\(s\)" || [ -z "$summary" ]; then status=1; fi
done
exit $status
