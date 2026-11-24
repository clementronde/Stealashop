---------------------------------------------------------------- a319 : SpeedBoostButton vend le gamepass DoubleSpeed (L-303)
-- Faux MarketplaceService côté client : les invites d'achat sont relevées (aucun achat).
PROMPTS = {}
local marketC = {
	PromptGamePassPurchase = function(_, player, id)
		table.insert(PROMPTS, { kind = "GamePass", player = player, id = id })
	end,
	PromptProductPurchase = function(_, player, id)
		table.insert(PROMPTS, { kind = "Product", player = player, id = id })
	end,
}
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "MarketplaceService" then
				return marketC
			end
			return old:GetService(name)
		end,
	}
end
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 1)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
local Zones = requireModule(ZONE_MODULE, "client")
local Notify = requireModule(NOTIFY_MODULE, "client")
local Menu = requireModule(MENU_MODULE, "client")
local V = A319_VARIANT
local hud = makeNewHud()
taskLib.spawn(Menu.Start)
step(0.3)
local speed = el(hud, "SpeedBoostButton")
local sleep = el(hud, "SleepButton")

print(`\n== C1 ({V}). Branchement : prix du gamepass, caché tant que la possession n'est pas connue`)
check(el(speed, "Amount").Text == "149", `C1a Price.Amount = 149 ({el(speed, "Amount").Text})`)
check(el(sleep, "Amount").Text == "79", `C1b zZz garde son prix ({el(sleep, "Amount").Text})`)
check(not speed.Visible, "C1c caché au branchement (pas de réponse de Roblox)")
check(Menu.GetShown().SpeedBoost == nil, "C1d plus de boost SpeedBoost dans Config/Boosts")
click(speed)
check(#PROMPTS == 0, "C1e clic avant la réponse : aucune invite")

print(`\n== C2 ({V}). Réponse de Roblox : pas possédé`)
P1:SetAttribute("PassKnownDoubleSpeed", true)
step(0.1)
if V == "on" then
	check(speed.Visible and Menu.GetShown().DoubleSpeed == true, "C2a connu, pas possédé : montré")
	check(not sleep.Visible, "C2b zZz reste caché au hub (règle du couloir inchangée)")
	P1:SetAttribute("TrainingMachine", "Treadmill")
	step(0.2)
	check(speed.Visible, "C2c sur le tapis : toujours montré")
	P1:SetAttribute("TrainingMachine", nil)
	step(0.2)
	check(speed.Visible, "C2d hors du tapis aussi (plus de règle OnTreadmill)")
	local notes = #Notify.shown
	click(speed)
	check(#PROMPTS == 1 and PROMPTS[1].kind == "GamePass" and PROMPTS[1].id == 9007 and PROMPTS[1].player == P1,
		`C2e clic : invite d'achat du gamepass 9007 ({#PROMPTS})`)
	check(#Notify.shown == notes, "C2f aucun « Soon »")
	speed.Visible = false -- masqué par un autre contrôleur (poursuite)
	step(0.5)
	check(not speed.Visible, "C2g un masquage par un autre contrôleur tient")
	speed.Visible = true
	print(`\n== C3 ({V}). Acheté (le serveur pose PassDoubleSpeed après sa vérification) : caché`)
	P1:SetAttribute("PassDoubleSpeed", true)
	step(1 / 30)
	check(not speed.Visible and Menu.GetShown().DoubleSpeed == false, "C3a possédé : caché tout de suite")
	click(speed)
	check(#PROMPTS == 1, "C3b clic d'un bouton caché : aucune nouvelle invite")
	print(`\n== C4 ({V}). HUD recréé avec le pass déjà possédé : caché`)
	hud:Destroy()
	local hud2 = makeNewHud()
	step(0.2)
	check(not el(hud2, "SpeedBoostButton").Visible, "C4a caché au rebranchement")
	P1:SetAttribute("PassDoubleSpeed", nil)
	step(0.2)
	check(el(hud2, "SpeedBoostButton").Visible, "C4b plus possédé (remboursé) : remontré")
	Zones.zone = 2
	step(0.2)
	check(el(hud2, "SleepButton").Visible, "C4c zZz montré dans le couloir (inchangé)")
else
	check(not speed.Visible and Menu.GetShown().DoubleSpeed == false, `C2a {V} : jamais montré`)
	P1:SetAttribute("TrainingMachine", "Treadmill")
	step(0.2)
	check(not speed.Visible, `C2b {V} : pas même sur le tapis`)
	click(speed)
	check(#PROMPTS == 0, `C2c {V} : clic sans invite d'achat`)
end
check(not logHas("ERREUR"), "C9 aucune erreur")
summary()
