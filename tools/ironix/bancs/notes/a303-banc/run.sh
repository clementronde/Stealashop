#!/usr/bin/env bash
# Banc a303 (21/11, demande de Cantin : dire ce qu'on gagne à chaque palier de temps de jeu, UI_Rewards PlaytimePage) :
# deux scénarios (tests.a303sans.luau : gain dans RewardName ; tests.a303avec.luau : RewardDesc, RewardIcon et Decals)
# sur l'installation du banc a53 (a150-banc/autres-bancs/a53-banc : faux Roblox, vrai serveur et vrai RewardsController),
# copiée dans un dossier passager, avec les mêmes correctifs à la volée que le banc a53 du lanceur commun (a158, a170,
# a262). Arbre sans a303 (pas de RewardDesc dans RewardsController) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$H/.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "RewardDesc" "$REPO/src/client/Controllers/RewardsController.luau" 2>/dev/null; then
	echo "banc a303 (gain des paliers) : SAUTÉ, pas de RewardDesc dans RewardsController (a303 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cp -r "$S/a150-banc/autres-bancs/a53-banc" "$T/a53-banc"
cp "$H/tests.a303sans.luau" "$H/tests.a303avec.luau" "$T/a53-banc/"
sed -i 's/banc a53 (récompenses)/banc a303 (gain des paliers)/' "$T/a53-banc/run-base.sh"
cat > "$T/inner.sh" <<INNER
#!/usr/bin/env bash
exec bash "$S/a170-banc/corrige.sh" a53 bash "$S/a158-banc/corrige.sh" a53 bash "$T/a53-banc/run.sh" "\$@"
INNER
bash "$S/a262-banc/corrige.sh" a53 "$T/inner.sh" "$REPO" a303sans a303avec
