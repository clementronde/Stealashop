--!nocheck
-- Scénario « client » (a99) : vrais PvPService et PvPController, faux Roblox du banc a29 (copie a36). Bob meurt
-- dans la boutique d'Ada : son panneau de repérage affiche l'attente (« ROB AGAIN IN 60s ») au lieu de l'ancienne
-- protection, l'invite de vol reste coupée, puis tout revient après 60 s. Ada, elle, ne voit rien de tel.

startServer()
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3)
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
startClient(bob)
advance(1.2)
local adaShop = shopOf(ada)
local S = SHOPS[1].S
local NAME = "RobCooldown_" .. tostring(adaShop:GetAttribute("PlotIndex"))

section("avant")
moveTo(bob, S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local panel = PvPController.GetPanelText(adaShop)
check(panel and panel.Status == nil, `panneau sans statut, porte intacte (trouvé {panel and panel.Status})`)

section("mort dans la boutique d'Ada")
check(breakDoor(bob, adaShop), "Bob casse la porte d'Ada")
standBy(bob, adaShop, 1)
advance(0.2)
kill(bob)
flush()
check(type(bob:GetAttribute(NAME)) == "number", `attribut {NAME} posé sur Bob`)
spawnCharacter(bob, S.outside + Vector3.new(0, 0, -6))
advance(0.3) -- PlotService le pose chez lui à l'apparition
moveTo(bob, S.outside + Vector3.new(0, 0, -6))
advance(0.5)
panel = PvPController.GetPanelText(adaShop)
check(panel and (panel.Status == "ROB AGAIN IN 60s" or panel.Status == "ROB AGAIN IN 59s"), `panneau : « ROB AGAIN IN 59s » (trouvé {panel and panel.Status})`)
check(panel and string.find(panel.Status or "", "PROTECTED", 1, true) == nil, "plus aucun « PROTECTED »")
standBy(bob, adaShop, 2)
advance(0.25)
local prompt = PvPController.GetPrompt(displayModel(adaShop, 2))
check(prompt == nil or not prompt.Enabled, "invite de vol coupée pendant l'attente")
moveTo(bob, S.outside + Vector3.new(0, 0, -6))
advance(10)
panel = PvPController.GetPanelText(adaShop)
local shown = panel and panel.Status and tonumber(string.match(panel.Status, "^ROB AGAIN IN (%d+)s$"))
check(shown ~= nil and shown >= 47 and shown <= 50, `le compte à rebours descend : 10 s plus tard, 47 à 50 s (trouvé {panel and panel.Status})`)

section("après 60 s")
advance(51, 0.5)
check(bob:GetAttribute(NAME) == nil, `attribut {NAME} retiré`)
panel = PvPController.GetPanelText(adaShop)
check(panel and (panel.Status == nil or string.find(panel.Status, "ROB AGAIN", 1, true) == nil), `panneau sans attente (trouvé {panel and panel.Status})`)
check(breakDoor(bob, adaShop), "Bob recasse la porte")
standBy(bob, adaShop, 2)
advance(0.5)
prompt = PvPController.GetPrompt(displayModel(adaShop, 2))
check(prompt ~= nil and prompt.Enabled, "invite de vol de nouveau active")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("[PvPController]", "WARN"), "aucune erreur dans PvPController")
if VERBOSE then
	dumpLog()
end
summary("scénario client")
