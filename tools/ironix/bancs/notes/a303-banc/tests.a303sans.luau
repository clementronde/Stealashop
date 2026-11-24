--!nocheck
-- a303 (21/11), scénario « sans RewardDesc » : le Template du relevé de Clément (RewardName, pas de RewardDesc ni de
-- RewardIcon). Le gain de chaque palier va dans RewardName : « 5 min: 2 min of cash » (revenu pas encore répliqué),
-- « $100 cash » (minimum 50 $ par minute), « $72K cash » (revenu répliqué) ; boîte et boost ; le palier réclamé garde
-- son texte, son minuteur passe à « CLAIMED » ; l'argent donné par le serveur = le montant affiché.

advance(1000)
startServer()
days(10)
local ada = join("Ada", newProfile8())
advance(1.5)
buildUi(ada)
startClient(ada)
advance(0.5)

section("lignes construites, revenu pas encore répliqué")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
ada:SetAttribute("Income", nil)
click(UI.button)
click(UI.playTab)
advance(0.3)
local r5, r15, r30, r60 = rowOf(5), rowOf(15), rowOf(30), rowOf(60)
check(r5 and r15 and r30 and r60, "4 lignes Tier_5, Tier_15, Tier_30, Tier_60")
check(r5.name.Text == "5 min: 2 min of cash", `palier 5 : « {r5.name.Text} »`)
check(r15.name.Text == "15 min: Item up to Epic", `palier 15 : « {r15.name.Text} »`)
check(r30.name.Text == "30 min: ×2 Cash for 10 min", `palier 30 : « {r30.name.Text} »`)
check(r60.name.Text == "60 min: Item up to Mythic", `palier 60 : « {r60.name.Text} »`)
check(r5.icon.Image == "rbxassetid://611" and r60.icon.Image == "rbxassetid://600", "Icon : toujours celle de Preview_1, celle du Template sans Preview_4")
check(r5.frame:FindFirstChild("RewardDesc") == nil and r5.frame:FindFirstChild("RewardIcon") == nil, "rien de créé : ni RewardDesc ni RewardIcon")

section("montant en $ d'après l'attribut Income")
ada:SetAttribute("Income", 0)
advance(0.3)
check(r5.name.Text == "5 min: $100 cash", `revenu 0 : minimum 2 × 50 $ : « {r5.name.Text} »`)
ada:SetAttribute("Income", 600)
advance(0.3)
check(r5.name.Text == "5 min: $72K cash", `revenu 600 $/s : 600 × 60 × 2 = 72K : « {r5.name.Text} »`)
ada:SetAttribute("Income", 0.5)
advance(0.3)
check(r5.name.Text == "5 min: $100 cash", `revenu 0,5 $/s : 60 $ < minimum 100 $ : « {r5.name.Text} »`)
ada:SetAttribute("Income", 0 / 0)
advance(0.3)
check(r5.name.Text == "5 min: 2 min of cash", `revenu illisible (NaN) : les minutes : « {r5.name.Text} »`)
check(r15.name.Text == "15 min: Item up to Epic" and r30.name.Text == "30 min: ×2 Cash for 10 min", "boîte et boost : texte fixe")

section("palier réclamé : CLAIMED ne change pas, le montant donné = le montant affiché")
ada:SetAttribute("Income", 0) -- ce que DisplayService répliquerait : aucun objet exposé, revenu 0
local played = stateOf(ada).PlaySeconds
advance(300 - played + 0.5)
check(r5.timer.Text == "Ready!" and r5.claimButton.Visible, "5 min de jeu : « Ready! », ClaimButton visible")
local shown = r5.name.Text
local cash = dataOf(ada).Cash
click(r5.claimButton)
advance(0.3)
check(dataOf(ada).Cash == cash + 100 and shown == "5 min: $100 cash", `réclamé : +{dataOf(ada).Cash - cash} $ donnés, « {shown} » affiché`)
check(r5.timer.Text == "CLAIMED" and r5.claimed.Visible and not r5.claimButton.Visible, "réclamé : « CLAIMED », Claimed visible, ClaimButton caché")
check(r5.name.Text == "5 min: $100 cash", `réclamé : le gain reste écrit : « {r5.name.Text} »`)
summary("scénario a303sans")
