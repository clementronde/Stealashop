--!nocheck
-- G. a237 (vague 71, L-219 point 5) : UI_ZoneBanner rallumé par un autre code au repos (HudMask qui remet sa valeur
-- gardée à la fin d'un masque) est rééteint ; allumé pendant un bandeau, il reste ; chaque passage laisse une ligne
-- dans la sortie de Studio.
buildZoneBannerUi()
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
local gui = copyScreen(alice, StarterGui.UI_ZoneBanner)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Banner = clientModule("ZoneBannerController")
local function go(x)
	moveTo(alice, Vector3.new(x, 3, 0))
	advance(0.2)
end

section("G. Écran rallumé au repos")
advance(0.3)
go(GATE_X[1] + 10)
check(Gates.GetZone() == 1 and gui.Enabled and Banner.GetState().Shown, "G1 passage de l'arche 1 : bandeau allumé")
check(logCount("[ZoneBanner] zone 1 : bandeau") == 1, "G2 une ligne « zone 1 : bandeau » dans la sortie (Studio)")
gui.Enabled = true -- un autre code le rallume pendant le bandeau : rien ne change
check(gui.Enabled and Banner.GetState().Shown, "G3 rallumé pendant le bandeau : il reste")
advance(6)
check(not gui.Enabled and not Banner.GetState().Shown, "G4 fin du fondu : éteint")
gui.Enabled = true -- HudMask remet « allumé » à la fin d'un masque
check(gui.Enabled == false, "G5 rallumé au repos : rééteint tout de suite")
go(GATE_X[2] + 10)
check(gui.Enabled and Banner.GetState().Zone == 2, "G6 passage suivant : le bandeau s'allume normalement")
check(logCount("[ZoneBanner] zone 2 : bandeau") == 1, "G7 une ligne « zone 2 : bandeau »")

summary("scénario guard")
