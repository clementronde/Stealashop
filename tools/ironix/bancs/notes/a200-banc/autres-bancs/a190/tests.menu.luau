---------------------------------------------------------------- scénario « menu » : menu, RightRail, boutons en situation (L-183)
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 1)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
local Zones = requireModule(ZONE_MODULE, "client")
local Notify = requireModule(NOTIFY_MODULE, "client")
local Menu = requireModule(MENU_MODULE, "client")

print("\n== M1. Ancien HUD (sans menu ni RightRail) : rien ne casse")
local old = makeHud()
local oldSnap = snapshot(old)
taskLib.spawn(Menu.Start)
step(0.3)
local same, why = sameAs(oldSnap, old)
check(same, `M1a ancien HUD inchangé ({why})`)
check(Menu.IsMenuOpen() == false, "M1b pas de menu")
Menu.SetMenuOpen(true)
check(Menu.IsMenuOpen() == false, "M1c SetMenuOpen sans MenuPanel : reste fermé")
P1:SetAttribute("TrainingMachine", "Treadmill")
step(0.2)
check(Menu.GetShown().SpeedBoost == true, "M1d la règle du tapis est vraie, sans bouton à montrer")
P1:SetAttribute("TrainingMachine", nil)
step(0.2)
check(not logHas("ERREUR"), "M1e aucune erreur")
old:Destroy()

print("\n== M2. Nouveau HUD : menu caché, ouvert et fermé")
local hud = makeNewHud()
step(0.1)
local panel = el(hud, "MenuPanel")
local menuButtons = {}
for _, d in hud:GetDescendants() do
	if d.Name == "MenuButton" then
		table.insert(menuButtons, d)
	end
end
check(#menuButtons == 2 and panel.Visible == false, `M2a 2 MenuButton, MenuPanel caché au branchement ({#menuButtons})`)
click(menuButtons[1])
check(panel.Visible and Menu.IsMenuOpen(), "M2b MenuButton (LeftRail) : menu ouvert")
click(menuButtons[1])
check(not panel.Visible, "M2c 2e appui : menu fermé")
click(menuButtons[2])
check(panel.Visible, "M2d MenuButton de LeftRailTouch : ouvert aussi")
click(el(panel, "IndexButton"))
check(not panel.Visible, "M2e choisir IndexButton dans le menu : menu refermé")

print("\n== M3. MenuAlert suit les pastilles du menu")
local alerts = {}
for _, d in hud:GetDescendants() do
	if d.Name == "MenuAlert" then
		table.insert(alerts, d)
	end
end
check(#alerts == 2 and not alerts[1].Visible and not alerts[2].Visible, "M3a éteintes au départ")
el(panel, "IndexAlert").Visible = true
step(1 / 30)
check(alerts[1].Visible and alerts[2].Visible, "M3b IndexAlert allumée : les deux MenuAlert s'allument")
el(panel, "RewardsAlert").Visible = true
el(panel, "IndexAlert").Visible = false
step(1 / 30)
check(alerts[1].Visible, "M3c RewardsAlert seule : toujours allumées")
el(panel, "RewardsAlert").Visible = false
step(1 / 30)
check(not alerts[1].Visible and not alerts[2].Visible, "M3d plus rien dans le menu : éteintes")

print("\n== M4. DisplayedButton ouvre UI_Displayed par DisplayedController (a191)")
clearLog()
click(el(hud, "DisplayedButton"))
check(logHas("DisplayedController", "WARN"), "M4a sans DisplayedController : une ligne, rien d'autre")
local displayedModule = moduleScript(CONTROLLERS, "DisplayedController", "stub/DisplayedController")
local Displayed = requireModule(displayedModule, "client")
click(el(hud, "DisplayedButton"))
check(Displayed.toggles == 1, `M4b DisplayedController.Toggle appelé ({Displayed.toggles})`)

print("\n== M5. « x2 » montré seulement sur un tapis, prix écrit, aucun achat")
local speed = el(hud, "SpeedBoostButton")
local sleep = el(hud, "SleepButton")
check(not speed.Visible and not sleep.Visible, "M5a les deux cachés au branchement (hub, hors tapis)")
check(el(speed, "Amount").Text == "29" and el(sleep, "Amount").Text == "79", `M5b prix de Config/Boosts ({el(speed, "Amount").Text}, {el(sleep, "Amount").Text})`)
P1:SetAttribute("TrainingMachine", "Treadmill")
step(0.2)
check(speed.Visible and not sleep.Visible, "M5c sur le tapis : x2 montré")
local before = #Notify.shown
click(speed)
local last = Notify.shown[#Notify.shown]
check(#Notify.shown == before + 1 and last.message == "Soon", "M5d clic : « Soon » (Ready = false, Features.RobuxShop = false)")
P1:SetAttribute("TrainingMachine", nil)
step(0.2)
check(not speed.Visible, "M5e descendu du tapis : caché")

print("\n== M6. « zZz » montré seulement dans le couloir, avec sa recharge")
Zones.zone = 2
step(0.2)
check(sleep.Visible and not speed.Visible, "M6a zone 2 : zZz montré")
local cooldown = el(sleep, "Cooldown")
check(not cooldown.Visible, "M6b sans recharge : Cooldown caché")
Workspace:SetAttribute("SleepCooldownEndsAt", Workspace:GetServerTimeNow() + 75)
step(0.2)
check(cooldown.Visible and cooldown.Text == "1:15", `M6c recharge : « 1:15 » ({cooldown.Text})`)
click(sleep)
last = Notify.shown[#Notify.shown]
check(string.find(last.message, "Ready in", 1, true) ~= nil, `M6d clic pendant la recharge : « {last.message} »`)
step(75)
check(not cooldown.Visible, "M6e recharge finie : Cooldown caché")
click(sleep)
check(Notify.shown[#Notify.shown].message == "Soon", "M6f puis « Soon »")
sleep.Visible = false -- masqué par un autre contrôleur (poursuite, a192)
step(0.5)
check(not sleep.Visible, "M6g un masquage par un autre contrôleur tient (Visible écrit au changement de règle)")
Zones.zone = 0
step(0.2)
Zones.zone = 1
step(0.2)
check(sleep.Visible, "M6h retour au hub puis zone 1 : remontré")
Zones.zone = 0
step(0.2)
check(not sleep.Visible, "M6i hub : caché")

print("\n== M7. HUD recréé : rebranché, l'ancien ne réagit plus")
local oldPanel = panel
local oldButton = menuButtons[1]
hud:Destroy()
local hud2 = makeNewHud()
step(0.1)
local panel2 = el(hud2, "MenuPanel")
oldButton.Activated:Fire()
step(1 / 30)
check(not oldPanel.Visible and not panel2.Visible, "M7a l'ancien MenuButton n'ouvre plus rien")
click(el(hud2, "MenuButton"))
check(panel2.Visible, "M7b le nouveau marche")
check(not logHas("ERREUR"), "M7c aucune erreur")
summary()
