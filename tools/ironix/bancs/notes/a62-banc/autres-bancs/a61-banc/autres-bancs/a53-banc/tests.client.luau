--!nocheck
-- Scénario « client » (DEV-101) : le vrai RewardsController sur les écrans du relevé de Clément, avec le vrai
-- serveur. Bouton du HUD (ouvre et ferme), CloseButton, onglets (Selected, pages), Today et Claimed des
-- jours, DailyClaimButton (CLAIM / CLAIMED, ClaimDaily), lignes des paliers clonées depuis Template
-- (Preview_* retirées, texte et icône repris), minuteurs (« 4:50 », « Ready! », « CLAIMED »), ClaimPlaytime,
-- pastille RewardsAlert, un seul écran du groupe Menu à la fois (Motion.SetCloser), jour suivant.

advance(1000)
startServer()
days(10)
local ada = join("Ada", newProfile8())
advance(1.5)
buildUi(ada)
startClient(ada)
advance(0.5)
local Controller = clientModule("RewardsController")
local Motion = requireModule(CONTROLLERS:FindFirstChild("UI"):FindFirstChild("Motion"), "client")

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not UI.screen.Enabled, "UI_Rewards fermé")
check(UI.alert.Visible, "pastille visible : J1 pas réclamé")
local previews = 0
for _, child in UI.list:GetChildren() do
	if string.sub(child.Name, 1, 8) == "Preview_" then
		previews += 1
	end
end
check(previews == 0, "lignes d'exemple Preview_* retirées")
check(not UI.template.Visible, "Template caché")
local r5, r15, r30, r60 = rowOf(5), rowOf(15), rowOf(30), rowOf(60)
check(r5 and r15 and r30 and r60, "4 lignes Tier_5, Tier_15, Tier_30, Tier_60")
check(r5 and r5.frame.Visible and r5.frame.LayoutOrder == 1 and r60.frame.LayoutOrder == 4, "lignes visibles, dans l'ordre")
check(r5 and r5.name.Text == "Preview gift 1" and r5.icon.Image == "rbxassetid://611", "palier 1 : texte et icône de Preview_1")
check(r60 and r60.name.Text == "Gift at 60 min" and r60.icon.Image == "rbxassetid://600", "palier 4 (sans Preview_4) : « Gift at 60 min », icône du Template")
check(UI.days[2].frame:FindFirstChild("RewardName").Text == "Standard Box" and UI.days[3].frame:FindFirstChild("DayLabel").Text == "Day 3", "textes des jours de Clément inchangés")

section("ouverture : onglet Daily")
click(UI.button)
check(UI.screen.Enabled and Controller.GetState().Open, "RewardsButton : écran ouvert")
check(UI.dailyPage.Visible and not UI.playPage.Visible, "DailyPage visible, PlaytimePage cachée")
check(UI.dailySelected.Visible and not UI.playSelected.Visible, "Selected sur DailyTab seulement")
local todays, claims = 0, 0
for d = 1, 7 do
	if UI.days[d].today.Visible then
		todays += 1
	end
	if UI.days[d].claimed.Visible then
		claims += 1
	end
end
check(todays == 1 and UI.days[1].today.Visible and claims == 0, "Today sur Day1 seulement, aucun Claimed")
check(UI.claimLabel.Text == "CLAIM", "ClaimLabel « CLAIM »")

section("réclamer le jour")
local calls = #serverCalls("ClaimDaily")
local cash = dataOf(ada).Cash
click(UI.claimButton)
advance(0.3)
check(#serverCalls("ClaimDaily") == calls + 1 and dataOf(ada).Cash == cash + 250, "DailyClaimButton : ClaimDaily, +250 $")
check(UI.days[1].claimed.Visible and UI.days[1].today.Visible, "Day1 : Claimed visible, Today reste")
check(UI.claimLabel.Text == "CLAIMED", "ClaimLabel « CLAIMED »")
check(not UI.alert.Visible, "pastille cachée : plus rien à réclamer")
click(UI.claimButton)
check(#serverCalls("ClaimDaily") == calls + 1, "clic sur CLAIMED : rien n'est envoyé")

section("onglet Playtime : minuteurs")
click(UI.playTab)
check(UI.playPage.Visible and not UI.dailyPage.Visible, "PlaytimePage visible, DailyPage cachée")
check(UI.playSelected.Visible and not UI.dailySelected.Visible, "Selected sur PlaytimeTab seulement")
advance(0.3)
local played = stateOf(ada).PlaySeconds
check(string.match(r5.timer.Text, "^%d:%d%d$") ~= nil and not r5.claimButton.Visible and not r5.claimed.Visible, `palier 5 : minuteur « {r5.timer.Text} », ClaimButton et Claimed cachés`)
check(r60.timer.Text == string.format("%d:%02d", (3600 - math.ceil(played)) // 60, (3600 - math.ceil(played)) % 60) or string.match(r60.timer.Text, "^59:%d%d$") ~= nil, `palier 60 : « {r60.timer.Text} »`)
advance(300 - played + 0.5)
check(r5.timer.Text == "Ready!" and r5.claimButton.Visible and not r5.claimed.Visible, "5 min de jeu : « Ready! », ClaimButton visible")
check(UI.alert.Visible, "pastille visible : un palier attend")
local pcalls = #serverCalls("ClaimPlaytime")
click(r5.claimButton)
advance(0.3)
check(#serverCalls("ClaimPlaytime") == pcalls + 1 and serverCalls("ClaimPlaytime")[pcalls + 1].args[1] == 5, "ClaimButton : ClaimPlaytime(5)")
check(r5.timer.Text == "CLAIMED" and r5.claimed.Visible and not r5.claimButton.Visible, "réclamé : « CLAIMED », Claimed visible, ClaimButton caché")
check(not UI.alert.Visible, "pastille cachée")
click(r15.claimButton)
check(#serverCalls("ClaimPlaytime") == pcalls + 1, "palier 15 pas atteint : rien n'est envoyé")
check((string.match(r15.timer.Text, "^9:%d%d$") ~= nil or r15.timer.Text == "10:00"), `palier 15 : « {r15.timer.Text} »`)

section("fermeture et réouverture")
click(UI.close)
check(not UI.screen.Enabled and not Controller.GetState().Open, "CloseButton : écran fermé")
click(UI.button)
check(UI.screen.Enabled and UI.playPage.Visible and Controller.GetState().Tab == "Playtime", "réouvert sur le dernier onglet (Playtime)")
click(UI.button)
check(not UI.screen.Enabled, "2e appui sur RewardsButton : fermé")

section("un seul écran du groupe Menu")
click(UI.button)
local other = make("ScreenGui", { Name = "UI_Other", Enabled = false }, ada:FindFirstChild("PlayerGui"))
other:SetAttribute("ScreenGroup", "Menu")
make("Frame", { Name = "Root" }, other)
Motion.Open(other)
flush()
check(other.Enabled and not UI.screen.Enabled and not Controller.GetState().Open, "un autre écran Menu s'ouvre : UI_Rewards fermé par son contrôleur")
click(UI.button)
check(UI.screen.Enabled and not other.Enabled, "UI_Rewards rouvert : l'autre écran se ferme")

section("le lendemain")
days(1)
advance(0.5)
click(UI.dailyTab)
check(UI.days[1].claimed.Visible and not UI.days[1].today.Visible and UI.days[2].today.Visible and not UI.days[2].claimed.Visible, "Day1 Claimed, Today sur Day2")
check(UI.claimLabel.Text == "CLAIM" and UI.alert.Visible, "CLAIM de nouveau, pastille visible")
check(r5.timer.Text ~= "CLAIMED" and not r5.claimed.Visible, "paliers remis à zéro")

section("écran recréé (ResetOnSpawn)")
local oldScreen = UI.screen
oldScreen.Parent = nil
local fresh = buildUi(ada)
advance(0.5)
check(not fresh.screen.Enabled and #(function()
	local n = {}
	for _, c in fresh.list:GetChildren() do
		if string.sub(c.Name, 1, 5) == "Tier_" then
			table.insert(n, c)
		end
	end
	return n
end)() == 4, "nouvel écran : rebranché, fermé, 4 lignes")
summary("scénario client")
