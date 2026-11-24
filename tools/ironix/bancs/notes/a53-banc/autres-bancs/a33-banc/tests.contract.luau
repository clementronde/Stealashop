--!nocheck
-- C. Contrat UI (Contract/UI, lu par le vrai ContractChecker) : BB_TruckHP avec les billboards
-- (Fill, Label, comme BB_WindowHP) et UI_HUD.InviteButton (un bouton).

local UI = sharedModule("Contract/UI")
local Checker = serverModule("ContractChecker")

local function spec(list, name)
	for _, screen in list do
		if screen.Name == name then
			return screen
		end
	end
	return nil
end
local function paths(screen)
	local out = {}
	for _, element in screen.Elements do
		out[element.Path] = element.Class or true
	end
	return out
end
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end
local function lineWith(pattern, kind)
	return logHas(pattern, kind, "server")
end

section("C. Contract/UI")
local truck = spec(UI.Billboards, "BB_TruckHP")
check(truck ~= nil and truck.Class == "BillboardGui", "C1 BB_TruckHP est un billboard du contrat (BillboardGui)")
local truckPaths = truck and paths(truck) or {}
local windowPaths = paths(spec(UI.Billboards, "BB_WindowHP"))
check(truckPaths.Fill ~= nil and truckPaths.Label ~= nil and #truck.Elements == 2, "C2 … avec Fill et Label")
check(windowPaths.Fill ~= nil and windowPaths.Label ~= nil, "C3 les mêmes noms que BB_WindowHP")
local hudPaths = paths(spec(UI.Screens, "UI_HUD"))
check(hudPaths.InviteButton == "GuiButton", "C4 UI_HUD.InviteButton au contrat, un bouton")
-- Copie d'a53 (DEV-101) : RewardsButton est lu par RewardsController quand l'arbre a Config/Rewards.
if SOURCES["shared/Config/Rewards.luau"] then
	check(hudPaths.RewardsButton == "GuiButton" and hudPaths["RewardsButton.RewardsAlert"] ~= nil, "C5 RewardsButton au contrat, un bouton, avec RewardsAlert (RewardsController, DEV-101)")
else
	check(hudPaths.RewardsButton == nil, "C5 RewardsButton pas au contrat (pas lu par le code)")
end
for _, name in UI.ReservedNames do
	check(name ~= "InviteButton", `C6 InviteButton n'est pas une propriété Roblox ({name})`)
end

section("C'. ContractChecker : livrés conformes")
rerun()
check(lineWith("[Contrat] Contrat :", nil), "C7 le vérificateur tourne jusqu'au bout")
check(not logHas("Billboards · BB_TruckHP", nil, "server"), "C8 BB_TruckHP conforme : rien à dire")
check(not logHas("UI · UI_HUD.InviteButton", nil, "server"), "C9 UI_HUD.InviteButton conforme : rien à dire")
check(not logHas("ContractChecker.Start", nil, "server"), "C10 sans erreur")

section("C''. ContractChecker : mal livrés, pas livrés")
TRUCK_BAR.Bar.Fill.Name = "Filling"
rerun()
check(lineWith("[Contrat] Billboards · BB_TruckHP.Fill introuvable", "WARN"), "C11 BB_TruckHP sans Fill : problème")
TRUCK_BAR:Destroy()
rerun()
check(lineWith("[Contrat] Billboards · BB_TruckHP absent : billboard pas encore livré", "PRINT"), "C12 BB_TruckHP absent : « pas encore livré » (le code se rabat sur BB_WindowHP)")
local invite = STARTER_HUD:FindFirstChild("InviteButton", true)
local frame = make("Frame", { Name = "InviteButton" }, invite.Parent)
invite:Destroy()
rerun()
check(lineWith("[Contrat] UI · UI_HUD.InviteButton doit être un bouton", "WARN"), "C13 InviteButton qui n'est pas un bouton : problème")
frame:Destroy()
rerun()
check(lineWith("[Contrat] UI · UI_HUD.InviteButton introuvable", "WARN"), "C14 InviteButton absent : problème")

summary("scénario contrat")
