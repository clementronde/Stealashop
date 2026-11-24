---------------------------------------------------------------- scénario « client » d'a64 (vague 22, L-092 3f)
-- Vrais OfflineController, GainController, HudController, Motion et Net (remotes créés par le Net serveur) ;
-- NotifyController bouchonné (relève Show) ; le serveur est simulé ici : il compte les ClaimOffline et
-- verse quand le test le dit (Cash, CashCollected puis OfflinePending = 0, dans l'ordre d'OfflineService).

SOURCES["stub/NotifyController"] = [==[
local N = { shown = {} }
function N.Show(message, kind)
	table.insert(N.shown, { message = message, kind = kind })
end
return N
]==]
local NOTIFY_MODULE = moduleScript(CONTROLLERS, "NotifyController", "stub/NotifyController")
local OFFLINE_MODULE = moduleScript(CONTROLLERS, "OfflineController", "client/Controllers/OfflineController.luau")
local OfflineCfg = requireModule(ReplicatedStorage.Shared.Config.Offline, "client")
local FLY = UiMotionC.CashFly
local FLY_TOTAL = FLY.PopTime + FLY.Hold + FLY.Time
local CLOSE_TIME = UiMotionC.Close.Time + 0.1

-- Net serveur : crée ReplicatedStorage/Remotes ; serveur simulé.
local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local claimsReceived = 0
NetS.Server.ClaimOffline:Connect(function(player)
	if player == P1 then
		claimsReceived += 1
	end
end)
-- Ce que fait OfflineService.Claim, vu du client : Cash, CashCollected, puis OfflinePending = 0.
local function serverPays()
	local amount = P1:GetAttribute("OfflinePending") or 0
	P1:SetAttribute("Cash", (P1:GetAttribute("Cash") or 0) + amount)
	P1:SetAttribute("CashCollected", (P1:GetAttribute("CashCollected") or 0) + amount)
	P1:SetAttribute("OfflinePending", 0)
end

P1:SetAttribute("Cash", 1000)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
P1:SetAttribute("OfflinePending", 0) -- nouveau joueur : rien en attente
local hud = makeHud()

-- UI_Offline comme celui de Clément (relevé du 2026-11-11), arrivé allumé de StarterGui.
local function makeOffline()
	local gui = new("ScreenGui", { Name = "UI_Offline", Enabled = true, ResetOnSpawn = true })
	gui:SetAttribute("ScreenGroup", "Menu")
	local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, gui)
	new("Frame", { Name = "WindowShadow" }, root)
	local window = new("Frame", { Name = "Window" }, root)
	local claimButton = new("TextButton", { Name = "ClaimButton", Text = "" }, window)
	new("Frame", { Name = "Studs" }, claimButton)
	local content = new("Frame", { Name = "Content" }, claimButton)
	new("UIListLayout", {}, content)
	new("TextLabel", { Name = "ClaimLabel", Text = "CLAIM" }, content)
	new("Frame", { Name = "Shade", BackgroundTransparency = 1 }, claimButton)
	local doubleButton = new("TextButton", { Name = "DoubleButton", Text = "" }, window)
	new("Frame", { Name = "Studs" }, doubleButton)
	local content2 = new("Frame", { Name = "Content" }, doubleButton)
	new("UIListLayout", {}, content2)
	new("ImageLabel", { Name = "RobuxIcon" }, content2)
	new("TextLabel", { Name = "PriceLabel", Text = "???" }, content2)
	new("TextLabel", { Name = "TwoXTag", Text = "2x" }, doubleButton)
	new("Frame", { Name = "Shade", BackgroundTransparency = 1 }, doubleButton)
	new("Frame", { Name = "Studs" }, window)
	local header = new("Frame", { Name = "Header" }, window)
	new("TextLabel", { Name = "Title", Text = "Offline Cash" }, header)
	new("TextLabel", { Name = "EarnedLabel", Text = "You earned:" }, window)
	new("TextLabel", { Name = "Amount", Text = "$0" }, window)
	new("ImageLabel", { Name = "CashIcon" }, window)
	local flyer = new("Frame", { Name = "Flyer", Visible = false }, gui)
	new("ImageLabel", { Name = "Icon" }, flyer)
	new("TextLabel", { Name = "FlyerAmount", Text = "$0" }, flyer)
	gui.Parent = PLAYER_GUI
	return gui
end
-- Un autre écran du groupe Menu (les récompenses), fermé.
local rewardsGui = new("ScreenGui", { Name = "UI_Rewards", Enabled = false })
rewardsGui:SetAttribute("ScreenGroup", "Menu")
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, rewardsGui)
rewardsGui.Parent = PLAYER_GUI

local offlineGui = makeOffline()
local Motion = requireModule(MOTION_MODULE, "client")
local Hud = requireModule(HUD_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
local Notify = requireModule(NOTIFY_MODULE, "client")
local Offline = requireModule(OFFLINE_MODULE, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
taskLib.spawn(Offline.Start)
step(0.1)
local cash = el(hud, "Cash")
local function flyers()
	local out = {}
	for _, child in hud:GetChildren() do
		if child.Name == "Template" then
			table.insert(out, child)
		end
	end
	return out
end
local function gainsAbove()
	local n = 0
	for _, child in PLAYER_GUI:GetChildren() do
		if child.Name == "BB_Gain" then
			n += 1
		end
	end
	return n
end
local function soonCount()
	local n = 0
	for _, e in Notify.shown do
		if e.message == "Soon" then
			n += 1
		end
	end
	return n
end

print("\n== C1. Nouveau joueur : rien en attente, l'écran reste fermé")
check(offlineGui.Enabled == false, "C1a l'écran arrivé allumé est fermé au branchement")
step(OfflineCfg.OpenDelay + 2)
check(offlineGui.Enabled == false and claimsReceived == 0, "C1b après OpenDelay : toujours fermé, aucun Claim")
check(Offline.GetState().Open == false and Offline.GetState().Pending == 0, "C1c GetState : fermé, 0 $")
check(#Notify.shown == 0, "C1d aucun message")

print("\n== C2. Gains en attente : l'écran s'ouvre avec le montant")
P1:SetAttribute("OfflinePending", 30000)
step(0.6)
check(offlineGui.Enabled == true and Motion.GetState(offlineGui) ~= nil, "C2a ouvert par Motion")
check(el(offlineGui, "Amount").Text == "$30K", `C2b Amount = « $30K » ({el(offlineGui, "Amount").Text})`)
check(Offline.GetState().Open == true and Offline.GetState().Pending == 30000, "C2c GetState : ouvert, 30 000 $")
P1:SetAttribute("OfflinePending", 31500)
step(1 / 30)
check(el(offlineGui, "Amount").Text == "$31.5K", `C2d le montant suit l'attribut ({el(offlineGui, "Amount").Text})`)
P1:SetAttribute("OfflinePending", 30000)
step(0.5)

print("\n== C3. DoubleButton (boutique Robux coupée) : « Soon », rien d'autre")
el(offlineGui, "DoubleButton").Activated:Fire()
step(0.1)
check(soonCount() == 1 and Notify.shown[1].kind == "Info", "C3a Notify « Soon » (Info)")
check(claimsReceived == 0 and offlineGui.Enabled == true, "C3b aucun remote, l'écran reste ouvert")
check(el(offlineGui, "PriceLabel").Text == "???" and el(offlineGui, "TwoXTag").Text == "2x", "C3c PriceLabel et TwoXTag gardent le texte de Clément")

print("\n== C4. Un autre écran du groupe Menu s'ouvre : on se ferme, puis on revient")
Motion.Open(rewardsGui)
step(CLOSE_TIME)
check(offlineGui.Enabled == false and rewardsGui.Enabled == true, "C4a UI_Offline fermé par UI_Rewards")
step(2)
check(offlineGui.Enabled == false, "C4b il ne revient pas tant que UI_Rewards est ouvert")
check(claimsReceived == 0 and P1:GetAttribute("OfflinePending") == 30000, "C4c rien de réclamé, rien de perdu")
Motion.Close(rewardsGui)
step(CLOSE_TIME + 0.6)
check(rewardsGui.Enabled == false and offlineGui.Enabled == true, "C4d UI_Rewards fermé : UI_Offline se rouvre")

print("\n== C5. Claim : un remote, l'écran se ferme, l'argent vole du centre de l'écran")
local claimButton = el(offlineGui, "ClaimButton")
claimButton.Activated:Fire()
claimButton.Activated:Fire() -- double clic
step(0.05)
check(claimsReceived == 1 and FIRE_SERVER["ClaimOffline"] == 1, `C5a un seul ClaimOffline envoyé ({claimsReceived})`)
step(CLOSE_TIME)
check(offlineGui.Enabled == false, "C5b l'écran se ferme")
check(Offline.GetState().Open == true, "C5c GetState().Open reste vrai jusqu'au versement")
step(0.6)
check(offlineGui.Enabled == false, "C5d il ne se rouvre pas pendant le Claim")
serverPays()
step(1 / 30)
local list = flyers()
check(#list == 1 and sameUDim2(list[1].Position, UDim2.fromScale(FLY.From.X, FLY.From.Y)), "C5e une case part du centre de l'écran")
check(gainsAbove() == 0, "C5f pas de « +$ » au-dessus du joueur (ce n'est pas un ramassage)")
check(cash.Text == "$1K", `C5g l'argent est retenu jusqu'à l'arrivée ({cash.Text})`)
check(Offline.GetState().Open == false, "C5h versé : GetState().Open repasse à faux")
step(FLY_TOTAL + UiMotionC.Roll.Time + 0.2)
check(#flyers() == 0 and cash.Text == "$31K", `C5i arrivée : « $31K » ({cash.Text})`)
step(2)
check(offlineGui.Enabled == false and claimsReceived == 1, "C5j plus rien en attente : l'écran reste fermé")

print("\n== C6. Claim sans réponse du serveur : l'écran revient après le délai")
P1:SetAttribute("OfflinePending", 500)
step(0.6)
check(offlineGui.Enabled == true and el(offlineGui, "Amount").Text == "$500", "C6a ouvert : « $500 »")
claimButton.Activated:Fire()
step(1)
check(claimsReceived == 2 and offlineGui.Enabled == false, "C6b Claim envoyé, écran fermé")
step(5)
check(offlineGui.Enabled == true, "C6c pas de versement au bout de 5 s : l'écran se rouvre")
claimButton.Activated:Fire()
step(0.1)
check(claimsReceived == 3, "C6d le Claim peut repartir")
serverPays()
step(FLY_TOTAL + 1)

print("\n== C7. Écran recréé (ResetOnSpawn) : rebranché fermé, puis rouvert s'il y a de l'argent en attente")
P1:SetAttribute("OfflinePending", 700)
step(0.6)
check(offlineGui.Enabled == true, "C7a ouvert")
offlineGui:Destroy()
local copy = makeOffline()
step(0.05)
check(copy.Enabled == false, "C7b la nouvelle copie est fermée au branchement")
step(0.6)
check(copy.Enabled == true and el(copy, "Amount").Text == "$700", "C7c puis rouverte, « $700 »")
el(copy, "ClaimButton").Activated:Fire()
step(0.1)
check(claimsReceived == 4, "C7d son ClaimButton marche")
serverPays()
step(FLY_TOTAL + 1)

print("\n== C8. Secours : UI_Offline absent (HUD là) → réclamé tout seul, avec un message")
copy:Destroy()
step(0.1)
local before = #Notify.shown
P1:SetAttribute("OfflinePending", 1200)
step(0.6)
check(claimsReceived == 5, "C8a ClaimOffline envoyé sans écran")
local last = Notify.shown[#Notify.shown]
check(#Notify.shown == before + 1 and last.message == "Your shop earned $1.2K while you were away!", `C8b message « {last and last.message} »`)
check(logHas("écran UI_Offline absent", "WARN", "client"), "C8c ligne orange en Studio")
serverPays()
step(2)
check(claimsReceived == 5, "C8d une seule fois")

print("\n== C9. Rien n'est laissé")
step(5)
check(#flyers() == 0 and gainsAbove() == 0, "C9a aucune case ni gain qui traîne")
check(not logHas("retenu plus de"), "C9b aucune retenue de l'argent oubliée")

summary()
