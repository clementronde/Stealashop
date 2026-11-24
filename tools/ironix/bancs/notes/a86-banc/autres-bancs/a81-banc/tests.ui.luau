--!nocheck
-- a81 (vague 26) : UI_Open et UI_Close sur les fenêtres (Motion.Open / Close), pas sur les alertes, pas de
-- UI_Close pour une fenêtre fermée par l'ouverture d'une autre du groupe ; UI_Deny avec un Notify « Warning ».
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
startClient(alice)
local UiMotion = sharedModule("Config/UiMotion", "client")
local Motion = requireModule(CONTROLLERS.UI.Motion, "client")
local played = {}
Motion.SetSoundPlayer(function(name) table.insert(played, name) end)
local function count(name)
	local n = 0
	for _, p in played do if p == name then n += 1 end end
	return n
end
local function screen(name, group)
	local gui = make("ScreenGui", { Name = name, Enabled = false }, alice.PlayerGui)
	make("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, gui)
	if group then gui:SetAttribute("ScreenGroup", group) end
	return gui
end
check(UiMotion.Sounds.Open == "UI_Open" and UiMotion.Sounds.Close == "UI_Close" and UiMotion.Sounds.Deny == "UI_Deny", "U1 noms de Clément")

section("U. Fenêtres")
local a = screen("UI_A", "Menu")
local b = screen("UI_B", "Menu")
Motion.Open(a)
advance(0.5)
check(count("UI_Open") == 1, "U2 UI_Open à l'ouverture")
Motion.Open(a)
advance(0.5)
check(count("UI_Open") == 1, "U3 déjà ouvert : pas de son")
Motion.Open(b)
advance(0.5)
check(count("UI_Open") == 2 and count("UI_Close") == 0 and a.Enabled == false, "U4 B s'ouvre, A fermée sans UI_Close")
Motion.Close(b)
advance(0.5)
check(count("UI_Close") == 1 and b.Enabled == false, "U5 UI_Close à la fermeture")
Motion.Close(b)
advance(0.5)
check(count("UI_Close") == 1, "U6 déjà fermé : pas de son")
local c = screen("UI_C")
Motion.SetCloser(c, function() Motion.Close(c) end)
Motion.Open(c)
advance(0.5)
Motion.Close(c)
advance(0.5)
check(count("UI_Open") == 3 and count("UI_Close") == 2, "U7 fenêtre avec SetCloser, sans groupe : sons")

section("U'. Alertes")
local alert = screen("UI_Alert")
Motion.Open(alert)
advance(0.5)
Motion.Close(alert)
advance(0.5)
check(count("UI_Open") == 3 and count("UI_Close") == 2, "U8 écran d'alerte (ni groupe ni SetCloser) : muet")

section("U''. Refus")
serverFire("Notify", alice, "Not enough cash!", "Warning")
check(count("UI_Deny") == 1, "U9 Notify Warning : UI_Deny")
serverFire("Notify", alice, "Saved.", "Info")
check(count("UI_Deny") == 1, "U10 Notify Info : rien")
summary("scénario a81 ui")
