--!nocheck
-- Scénario « a117index » (vague 34, 2026-11-13, L-127 points 2 et 3), lancé par a117-banc/run.sh : vrais
-- IndexService (serveur), IndexController, RailAlertController, RewardsController et Shared/AlertBadge (client),
-- sur la copie a117 du faux UI_Index_v3 (lib67 : ClaimAllButton et pastilles) et un faux UI_HUD / UI_Rewards
-- construits ici (relevé du script tools/clement/alerts_claimall_build.luau). Réclamation de la zone visible et de
-- toutes (le remote part du vrai client et arrive au vrai serveur), refus (View.Deny), réussite (T.33 Success),
-- pas de double versement ; chaque pastille allumée (Visible + Pulse qui bat 1 → 1,15 → 1 en 0,8 s) puis éteinte
-- quand l'action est faite.

advance(1000)
startServer()
moduleScript(CONTROLLERS, "RailAlertController", "client/Controllers/RailAlertController.luau")
moduleScript(CONTROLLERS, "RewardsController", "client/Controllers/RewardsController.luau")
local Format = sharedModule("Format")
local SkillTree = sharedModule("Config/SkillTree")
local InventoryState = sharedModule("InventoryState")

-- Zone 1 complète sauf la Carotte, zone 2 complète.
local data = newProfile()
local n = 0
for _, zone in { 1, 2 } do
	for _, item in Index.ByZone[zone] do
		if item.Id ~= "Z1_Carotte" then
			n += 1
			addItem(data, `a-{n}`, item.Id, nil, zone, 500)
		end
	end
end
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildIndexV3Gui(playerGui)

local function alertIn(parent, name)
	local alert = make("Frame", { Name = name, Visible = false }, parent)
	make("UIScale", { Name = "Pulse", Scale = 1 }, alert)
	return alert
end
local hud = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
local RAIL = { IndexButton = "IndexAlert", InventoryButton = "InventoryAlert", RebirthButton = "RebirthAlert", SkillTreeButton = "SkillTreeAlert" }
for _, railName in { "LeftRail", "LeftRailTouch" } do
	local rail = make("Frame", { Name = railName }, hud)
	for button, alert in RAIL do
		alertIn(make("TextButton", { Name = button, Text = "" }, rail), alert)
	end
end
local social = make("Frame", { Name = "SocialRow" }, hud)
local rewardsButton = make("TextButton", { Name = "RewardsButton", Text = "" }, social)
local rewardsAlert = alertIn(rewardsButton, "RewardsAlert")
hud.Parent = playerGui
local rgui = make("ScreenGui", { Name = "UI_Rewards", Enabled = false, ResetOnSpawn = false })
local rroot = make("Frame", { Name = "Root" }, rgui)
local rtabs = make("Frame", { Name = "Tabs" }, rroot)
local dailyTab = make("TextButton", { Name = "DailyTab", Text = "" }, rtabs)
make("Frame", { Name = "Selected" }, dailyTab)
local dailyAlert = alertIn(dailyTab, "TabAlert")
local playTab = make("TextButton", { Name = "PlaytimeTab", Text = "" }, rtabs)
make("Frame", { Name = "Selected" }, playTab)
local playAlert = alertIn(playTab, "TabAlert")
make("Frame", { Name = "DailyPage" }, rroot)
make("Frame", { Name = "PlaytimePage" }, rroot)
rgui.Parent = playerGui

local sounds = watchPops()
advance(1.5)
startClient(ada)
advance(0.5)
local AlertBadge = sharedModule("AlertBadge", "client")
local Rail = clientModule("RailAlertController")

local window = gui.Root.Window
local list = window.ListPanel.List
local rewards = window.Rewards
local claim = rewards.ClaimButton
local claimAll = window.UnlockedBar.ClaimAllButton
local categories = gui.Root.Categories
local function both(alertName)
	local out = {}
	for _, railName in { "LeftRail", "LeftRailTouch" } do
		for button, alert in RAIL do
			if alert == alertName then
				table.insert(out, hud[railName][button][alert])
			end
		end
	end
	return out
end
local function lit(alert)
	return alert.Visible == true and AlertBadge.IsOn(alert)
end
local function allLit(list_, on)
	for _, alert in list_ do
		if lit(alert) ~= on then
			return false
		end
		if not on and alert.Pulse.Scale ~= 1 then
			return false
		end
	end
	return #list_ > 0
end
local function zoneAlert(zone)
	return list[if zone then `Zone{zone}Section` else "SecretsSection"].ZoneArt.ZoneAlert
end
local function cash()
	return dataOf(ada).Cash
end
local function count(list_, value, from)
	local c = 0
	for i = from or 1, #list_ do
		if list_[i] == value then
			c += 1
		end
	end
	return c
end

section("battement de Pulse (1 → 1,15 → 1 en 0,8 s)")
local beating = both("IndexAlert")[1]
local low, high = math.huge, -math.huge
for _ = 1, 20 do
	advance(0.05)
	low = math.min(low, beating.Pulse.Scale)
	high = math.max(high, beating.Pulse.Scale)
end
check(lit(beating) and high > 1.14 and high <= 1.15 + 1e-6 and low >= 1 and low < 1.01, `IndexAlert bat entre {string.format("%.3f", low)} et {string.format("%.3f", high)}`)

section("pastilles de l'Index : zone 2 à réclamer (écran fermé)")
check(gui.Enabled == false, "Index fermé")
check(allLit(both("IndexAlert"), true), "IndexAlert allumée dans LeftRail et LeftRailTouch")
check(lit(window.UnlockedBar.ClaimAllButton.ClaimAllAlert) and lit(categories.NormalButton.CategoryAlert), "ClaimAllAlert et CategoryAlert (NORMAL) allumées")
check(lit(zoneAlert(2)) and not lit(zoneAlert(1)) and not lit(zoneAlert(3)) and not lit(zoneAlert(nil)), "ZoneAlert : zone 2 seule (pas la 1, pas la 3, pas les Secrets)")
check(not lit(categories.SecretsButton.CategoryAlert) and not lit(categories.MutationsButton.CategoryAlert), "SECRETS et MUTATIONS : éteintes")
check(Rail.GetState().Index == true and Rail.GetState().Rebirth == false, "RailAlertController : Index oui, Rebirth non")
check(cash() == 1000 and dataOf(ada).IndexRewards == nil, "rien versé tout seul")

section("ClaimButton : zone visible pas complète → refus")
click(hud.LeftRail.IndexButton)
advance(0.5)
check(gui.Enabled == true, "Index ouvert")
check(not lit(claim.ClaimAlert), "zone 1 visible (pas complète) : ClaimAlert éteinte")
local before = #sounds
click(claim)
advance(0.05)
check(count(sounds, "UI_Deny", before + 1) == 1 and claim.Position ~= V3_CLAIM_POS, "UI_Deny, le bouton tremble")
advance(0.5)
check(claim.Position == V3_CLAIM_POS and cash() == 1000, "retour à sa place, rien versé")

section("ClaimButton : zone 2 visible → réclamée")
for index, name in V3_SECTIONS do
	list[name].AbsolutePosition = Vector2.new(0, 100 + (index - 2) * 400)
end
list.CanvasPosition = Vector2.new(0, 400)
advance(0.1)
check(lit(claim.ClaimAlert) and textOf(claim, "ClaimLabel") == "Claim!", "zone 2 visible : ClaimAlert allumée, « Claim! »")
before = #sounds
advance(1.1) -- débit de Net
claim.Activated:Fire() -- (le faux Net répond tout de suite : un 2e clic serait un refus, zone déjà réclamée)
flush()
advance(0.5)
check(cash() == 1000 + Index.ZoneCash(2), `+{Format.money(Index.ZoneCash(2))} versés une fois`)
check(ada:GetAttribute("IndexClaimed") == "2" and textOf(claim, "ClaimLabel") == "Claimed!", "IndexClaimed « 2 », « Claimed! »")
check(count(sounds, "UI_Success", before + 1) == 1 and count(sounds, "UI_Deny", before + 1) == 0, `T.33 Success (UI_Success), pas de refus ({table.concat(sounds, " ", before + 1)})`)
check(not lit(claim.ClaimAlert) and not lit(zoneAlert(2)), "ClaimAlert et ZoneAlert de la zone 2 éteintes")
check(not lit(window.UnlockedBar.ClaimAllButton.ClaimAllAlert) and not lit(categories.NormalButton.CategoryAlert), "ClaimAllAlert et CategoryAlert éteintes")
check(allLit(both("IndexAlert"), false), "IndexAlert éteinte dans les deux colonnes (Pulse remis à 1)")
before = #sounds
advance(5.5)
click(claim)
advance(0.5)
check(count(sounds, "UI_Deny", before + 1) == 1 and cash() == 1000 + Index.ZoneCash(2), "zone déjà réclamée : refus, rien de plus")

section("ClaimAllButton : rien à réclamer → refus")
before = #sounds
local base = claimAll.Position
click(claimAll)
advance(0.05)
check(count(sounds, "UI_Deny", before + 1) == 1 and claimAll.Position ~= base, "UI_Deny, ClaimAllButton tremble")
advance(0.5)
check(claimAll.Position == base, "puis revient")

section("ClaimAllButton : zones 1 et 3 en une demande")
IndexService.Discover(ada, "Z1_Carotte")
for _, item in Index.ByZone[3] do
	IndexService.Discover(ada, item.Id)
end
flush()
advance(0.2)
check(lit(zoneAlert(1)) and lit(zoneAlert(3)) and not lit(zoneAlert(2)), "ZoneAlert : zones 1 et 3")
check(lit(window.UnlockedBar.ClaimAllButton.ClaimAllAlert) and allLit(both("IndexAlert"), true), "ClaimAllAlert et IndexAlert rallumées")
local cash0 = cash()
before = #sounds
click(claimAll)
advance(0.5)
check(cash() == cash0 + Index.ZoneCash(1) + Index.ZoneCash(3), "primes des zones 1 et 3 versées")
check(ada:GetAttribute("IndexClaimed") == "1,2,3", "IndexClaimed « 1,2,3 »")
check(count(sounds, "UI_Success", before + 1) == 1, "T.33 Success")
check(not lit(zoneAlert(1)) and not lit(zoneAlert(3)) and not lit(window.UnlockedBar.ClaimAllButton.ClaimAllAlert) and allLit(both("IndexAlert"), false), "toutes les pastilles de l'Index éteintes")
advance(1.1)
fireAs(ada, "ClaimIndexReward")
fireAs(ada, "ClaimIndexReward", 3)
flush()
check(cash() == cash0 + Index.ZoneCash(1) + Index.ZoneCash(3), "demandes répétées : pas de double versement")

section("InventoryAlert")
check(allLit(both("InventoryAlert"), false), "rien à poser : éteinte")
ada:SetAttribute(InventoryState.Attribute, InventoryState.Encode({ Items = { { Uid = "u-1", ItemId = "Z1_Donut", Income = 1, AntiTheft = true } }, Boxes = {} }))
advance(0.1)
check(allLit(both("InventoryAlert"), true), "objet sous antivol à poser : allumée (deux colonnes)")
ada:SetAttribute(InventoryState.Attribute, InventoryState.Encode({ Items = { { Uid = "u-1", ItemId = "Z1_Donut", Income = 1 } }, Boxes = {} }))
advance(0.1)
check(allLit(both("InventoryAlert"), false), "posé (plus d'antivol dans l'inventaire) : éteinte")
local floor = make("Model", { Name = "FloorItem" }, Workspace)
floor:SetAttribute("OwnerUserId", ada.UserId)
floor:SetAttribute("UnlockAt", Workspace:GetServerTimeNow() + 2)
CollectionService:AddTag(floor, "FloorItem")
local other = make("Model", { Name = "FloorItem" }, Workspace)
other:SetAttribute("OwnerUserId", ada.UserId + 999)
other:SetAttribute("UnlockAt", 0)
CollectionService:AddTag(other, "FloorItem")
advance(0.1)
check(allLit(both("InventoryAlert"), false), "objet au sol sous antivol (et objet débloqué d'un autre joueur) : éteinte")
advance(2.5)
check(allLit(both("InventoryAlert"), true), "antivol fini (UNLOCKED!) : allumée")
CollectionService:RemoveTag(floor, "FloorItem")
floor:Destroy()
advance(0.1)
check(allLit(both("InventoryAlert"), false), "repris (plus au sol) : éteinte")
ada:SetAttribute(InventoryState.Attribute, InventoryState.Encode({ Items = {}, Boxes = { { Uid = "b-1", Tier = "Standard", Rarity = "Common", Placed = false } } }))
advance(0.1)
check(allLit(both("InventoryAlert"), true), "colis à poser : allumée")
ada:SetAttribute(InventoryState.Attribute, InventoryState.Encode({ Items = {}, Boxes = {} }))
advance(0.1)
check(allLit(both("InventoryAlert"), false), "plus rien : éteinte")

section("SkillTreeAlert et RebirthAlert")
local cheapest = math.huge
for _, skill in SkillTree.List do
	if skill.OpensWhen == nil and skill.Coded >= 1 and skill.Prices[1] then
		cheapest = math.min(cheapest, skill.Prices[1])
	end
end
check(cheapest < math.huge, `une compétence ouverte et codée coûte {cheapest} $`)
ada:SetAttribute("Cash", cheapest - 1)
advance(0.1)
check(allLit(both("SkillTreeAlert"), false), "argent insuffisant : éteinte")
ada:SetAttribute("Cash", cheapest)
advance(0.1)
check(allLit(both("SkillTreeAlert"), true), "assez d'argent : allumée")
for _, skill in SkillTree.List do
	ada:SetAttribute(SkillTree.AttributePrefix .. skill.Id, skill.MaxLevel)
end
advance(0.1)
check(allLit(both("SkillTreeAlert"), false), "tout au maximum : éteinte")
check(allLit(both("RebirthAlert"), false), "RebirthAlert éteinte (renaissance pas codée)")

section("récompenses : RewardsAlert et TabAlert")
local A = sharedModule("Config/Rewards").Attributes
ada:SetAttribute(A.Day, 1)
ada:SetAttribute(A.PlayStart, Workspace:GetServerTimeNow())
ada:SetAttribute(A.PlayClaimed, "")
ada:SetAttribute(A.DailyClaimed, false)
advance(0.5)
check(lit(rewardsAlert) and lit(dailyAlert) and not lit(playAlert), "jour à réclamer : RewardsAlert et DailyTab.TabAlert allumées, PlaytimeTab éteinte")
ada:SetAttribute(A.DailyClaimed, true)
advance(0.5)
check(not lit(rewardsAlert) and not lit(dailyAlert) and rewardsAlert.Pulse.Scale == 1, "jour réclamé : éteintes")
ada:SetAttribute(A.PlayStart, Workspace:GetServerTimeNow() - 5 * 60 - 1)
advance(0.5)
check(lit(rewardsAlert) and lit(playAlert) and not lit(dailyAlert), "palier de 5 min atteint : RewardsAlert et PlaytimeTab.TabAlert allumées")
ada:SetAttribute(A.PlayClaimed, "5")
advance(0.5)
check(not lit(rewardsAlert) and not lit(playAlert), "palier réclamé : éteintes")

check(not logHas("[Loader Client]", "WARN"), "aucun contrôleur en échec")
summary("scénario a117index")
