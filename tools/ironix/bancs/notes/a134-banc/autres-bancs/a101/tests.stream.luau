--!nocheck
-- S. Streaming et écran absent : une seule arche connue (axe par la zone safe), arche qui arrive plus tard
-- (pas de bandeau sans passage), UI_ZoneBanner pas livré, élément manquant.
for zone = 2, 6 do
	GATES[zone].Parent = nil
end
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Banner = clientModule("ZoneBannerController")
local changes = {}
Gates.OnZoneChanged(function(zone, previous)
	table.insert(changes, { zone, previous })
end)
local function go(x)
	moveTo(alice, Vector3.new(x, 3, 0))
	advance(0.2)
end

section("S. Une seule arche connue")
advance(0.3)
check(#Gates.GetGates() == 1 and Gates.GetZone() == 0, "S1 arche 1 seule, joueur au hub : zone 0")
go(GATE_X[1] + 10)
check(Gates.GetZone() == 1 and #changes == 1, "S2 axe zone safe → arche 1 : passage vu")
check(not Banner.GetState().Shown and logCount("UI_ZoneBanner absent du PlayerGui : pas de bandeau d'entrée de zone (L-110)", "WARN", "client") == 1, "S3 écran pas livré : pas de bandeau, une ligne en Studio")
go(GATE_X[1] - 30)
go(GATE_X[1] + 10)
check(#changes == 3 and logCount("UI_ZoneBanner absent", "WARN", "client") == 1, "S4 la ligne n'est dite qu'une fois")

section("S'. Arches qui arrivent par le streaming")
go(GATE_X[3] + 20) -- en vrai dans la zone 3, mais seule l'arche 1 est connue
check(Gates.GetZone() == 1 and #changes == 3, "S5 arches 2 et 3 inconnues : toujours zone 1")
buildZoneBannerUi()
local gui = copyScreen(alice, StarterGui.UI_ZoneBanner)
GATES[2].Parent = MAP
GATES[3].Parent = MAP
advance(0.3)
check(#Gates.GetGates() == 3 and Gates.GetZone() == 3, "S6 arches 2 et 3 arrivées : zone 3 relue")
check(#changes == 3 and gui.Enabled == false, "S7 sans prévenir : pas de bandeau sans passage")
GATES[4].Parent = MAP
advance(0.3)
go(GATE_X[4] + 10)
check(Gates.GetZone() == 4 and #changes == 4 and gui.Enabled and gui.Banner.ZoneName.Text == "LOS ANGELES", "S8 vrai passage de l'arche 4 : bandeau LOS ANGELES")
GATES[1].Parent = nil
GATES[2].Parent = nil
advance(0.3)
go(GATE_X[2] + 10)
check(#Gates.GetGates() == 2 and Gates.GetZone() == 2 and gui.Banner.ZoneName.Text == "LONDON", "S9 arches sorties du streaming : leur point reste connu (retour en zone 2)")
alice.Character:Destroy()
alice.Character = nil
advance(0.5)
check(Gates.GetZone() == 2, "S10 sans personnage : la zone ne bouge pas")

section("S''. Élément manquant")
advance(5)
StarterGui.UI_ZoneBanner.Banner.Difficulty:Destroy()
local fresh = copyScreen(alice, StarterGui.UI_ZoneBanner)
spawnCharacter(alice, Vector3.new(GATE_X[3] + 10, 3, 0))
advance(0.3)
check(fresh.Enabled and fresh.Banner.ZoneName.Text == "TOKYO", "S11 sans Difficulty : le reste du bandeau marche")
check(logCount("UI_ZoneBanner.Difficulty introuvable ou pas un TextLabel : ignoré", "WARN", "client") == 1, "S12 une ligne en Studio")

summary("scénario streaming")
