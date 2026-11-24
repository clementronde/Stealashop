--!nocheck
-- a303 (21/11), scénario « avec RewardDesc et RewardIcon » : Clément ajoute au Template un TextLabel RewardDesc et un
-- ImageLabel RewardIcon, et livre les Decals UI_Icon_Reward_Cash et _Box (pas _Boost : un Decal sans Texture).
-- RewardDesc dit le gain, RewardName garde « Gift at 60 min » ou le texte de la Preview ; RewardIcon montré seulement
-- quand son Decal existe.

advance(1000)
startServer()
days(10)
local ada = join("Ada", newProfile8())
advance(1.5)
buildUi(ada)
make("TextLabel", { Name = "RewardDesc", Text = "Placeholder" }, UI.template)
make("ImageLabel", { Name = "RewardIcon", Image = "rbxassetid://700", Visible = true }, UI.template)
local RS = ReplicatedStorage
local assets = RS:FindFirstChild("Assets") or make("Folder", { Name = "Assets" }, RS)
local icons = make("Folder", { Name = "Icons" }, assets)
make("Decal", { Name = "UI_Icon_Reward_Cash", Texture = "rbxassetid://801" }, icons)
make("Decal", { Name = "UI_Icon_Reward_Box", Texture = "rbxassetid://802" }, assets)
make("Decal", { Name = "UI_Icon_Reward_Boost", Texture = "" }, assets)
startClient(ada)
advance(0.5)

local function descOf(minutes)
	local f = UI.list:FindFirstChild(`Tier_{minutes}`)
	return f and f:FindFirstChild("RewardDesc"), f and f:FindFirstChild("RewardIcon")
end

section("RewardDesc rempli, RewardName gardé")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
ada:SetAttribute("Income", 0)
click(UI.button)
click(UI.playTab)
advance(0.3)
local r5, r15, r30, r60 = rowOf(5), rowOf(15), rowOf(30), rowOf(60)
local d5, i5 = descOf(5)
local d15, i15 = descOf(15)
local d30, i30 = descOf(30)
local d60, i60 = descOf(60)
check(d5 and d15 and d30 and d60, "RewardDesc clonés dans les 4 lignes")
check(d5.Text == "$100 cash", `palier 5 : RewardDesc « {d5.Text} »`)
check(d15.Text == "Item up to Epic", `palier 15 : RewardDesc « {d15.Text} »`)
check(d30.Text == "×2 Cash for 10 min", `palier 30 : RewardDesc « {d30.Text} »`)
check(d60.Text == "Item up to Mythic", `palier 60 : RewardDesc « {d60.Text} »`)
check(r5.name.Text == "Preview gift 1" and r60.name.Text == "Gift at 60 min", `RewardName : « {r5.name.Text} » (Preview_1), « {r60.name.Text} » (Template)`)
ada:SetAttribute("Income", 1234)
advance(0.3)
check(d5.Text == "$148K cash", `revenu 1 234 $/s : 1234 × 120 = 148 080 : « {d5.Text} »`)
ada:SetAttribute("Income", nil)
advance(0.3)
check(d5.Text == "2 min of cash" and r5.name.Text == "Preview gift 1", `revenu absent : « {d5.Text} », RewardName inchangé`)

section("RewardIcon seulement si son Decal existe")
check(i5 and i5.Visible and i5.Image == "rbxassetid://801", `argent : Decal UI_Icon_Reward_Cash (dans Assets/Icons) : {i5 and i5.Image}`)
check(i15 and i15.Visible and i15.Image == "rbxassetid://802" and i60.Visible and i60.Image == "rbxassetid://802", "boîtes : Decal UI_Icon_Reward_Box")
check(i30 and not i30.Visible, "boost : Decal sans Texture, RewardIcon caché")
check(UI.template:FindFirstChild("RewardIcon").Image == "rbxassetid://700", "Template de Clément pas touché")

section("palier réclamé : CLAIMED ne change pas")
ada:SetAttribute("Income", 0)
local played = stateOf(ada).PlaySeconds
advance(300 - played + 0.5)
local cash = dataOf(ada).Cash
click(r5.claimButton)
advance(0.3)
check(dataOf(ada).Cash == cash + 100 and d5.Text == "$100 cash", `réclamé : +{dataOf(ada).Cash - cash} $, RewardDesc « {d5.Text} »`)
check(r5.timer.Text == "CLAIMED" and r5.claimed.Visible and not r5.claimButton.Visible, "réclamé : « CLAIMED », Claimed visible, ClaimButton caché")
check(i5.Visible and r5.name.Text == "Preview gift 1", "réclamé : icône et RewardName inchangés")
summary("scénario a303avec")
