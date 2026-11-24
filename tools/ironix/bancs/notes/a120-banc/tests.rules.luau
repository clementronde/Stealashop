--!nocheck
-- R. Bandeau de zone qui cède (a120, Cantin 2026-11-13) : RUN!, alerte de vol, chrono HEIST.
local UiMotion = sharedModule("Config/UiMotion", "client")
local M = UiMotion.ZoneBanner
local FULL = M.FadeIn + M.Hold + M.FadeOut + 0.3

-- Bouchons des trois contrôleurs voisins (lus par ZoneBannerController.Start).
SOURCES["stub/a120Chase"] = "local C = { chased = false } function C.IsChased() return C.chased end return C"
SOURCES["stub/a120Hud"] = "local C = { heist = false } function C.IsHeistTimerShown() return C.heist end return C"
SOURCES["stub/a120Alert"] = "local C = { shown = false } function C.IsShown() return C.shown end return C"
moduleScript(CONTROLLERS, "ChaseController", "stub/a120Chase")
moduleScript(CONTROLLERS, "HudController", "stub/a120Hud")
moduleScript(CONTROLLERS, "TheftAlertController", "stub/a120Alert")

buildZoneBannerUi()
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
local gui = copyScreen(alice, StarterGui.UI_ZoneBanner)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Banner = clientModule("ZoneBannerController")
local Chase = clientModule("ChaseController")
local Hud = clientModule("HudController")
local Alert = clientModule("TheftAlertController")
local function go(x)
	moveTo(alice, Vector3.new(x, 3, 0))
	advance(0.2)
end
local function off()
	local s = Banner.GetState()
	return gui.Enabled == false and not s.Shown and s.Zone == nil and s.Pending == nil
end
local function alphaStr()
	return string.format("%.2f", Banner.GetState().Alpha)
end

section("R0. Source")
check(string.find(SOURCES["client/Controllers/TheftAlertController.luau"], "function TheftAlertController.IsShown(): boolean\n\treturn shown\nend", 1, true) ~= nil, "R0 TheftAlertController.IsShown rend `shown`")

section("R1. RUN! : rien, ni pendant ni après")
Chase.chased = true
go(GATE_X[1] + 10)
check(Gates.GetZone() == 1 and off(), "R1 arche 1 pendant RUN! : aucun bandeau, rien en attente")
advance(2)
Chase.chased = false
advance(FULL)
check(off(), "R2 fin de RUN! : toujours rien (pas de mise en attente)")

section("R2. Bandeau allumé quand RUN! arrive")
go(GATE_X[2] + 10)
advance(M.FadeIn + 0.5)
check(gui.Enabled and Banner.GetState().Alpha == 1 and gui.Banner.ZoneName.Text == "LONDON", "R3 arche 2 : LONDON, plein")
Chase.chased = true
advance(0.1)
local a = Banner.GetState().Alpha
check(gui.Enabled and a < 1 and a > 0.5, `R4 RUN! : fondu de sortie aussitôt (opacité {alphaStr()})`)
advance(M.FadeOut)
check(off(), "R5 éteint en FadeOut au plus, pas d'attente")
Chase.chased = false
advance(FULL)
check(off(), "R6 fin de RUN! : il ne revient pas")

section("R3. Alerte de vol")
Alert.shown = true
go(GATE_X[3] + 10)
check(Gates.GetZone() == 3 and off(), "R7 arche 3 pendant l'alerte : rien")
Alert.shown = false
advance(FULL)
check(off(), "R8 fin de l'alerte : toujours rien")
go(GATE_X[4] + 10)
advance(0.1)
local early = Banner.GetState().Alpha
check(gui.Enabled and early > 0 and early < 1, `R9 arche 4 : fondu d'entrée en cours (opacité {alphaStr()})`)
Alert.shown = true
advance(0.05)
local b = Banner.GetState().Alpha
check(gui.Enabled and b <= early + 1e-6 and b > 0, `R10 l'alerte arrive pendant l'entrée : il repart vers 0 depuis l'opacité en cours ({alphaStr()})`)
advance(M.FadeOut)
check(off(), "R11 éteint")
Alert.shown = false
advance(FULL)
check(off(), "R12 il ne revient pas")

section("R4. Chrono HEIST : attente")
Hud.heist = true
go(GATE_X[5] + 10)
check(gui.Enabled == false and Banner.GetState().Pending == 5 and not Banner.GetState().Shown, "R13 arche 5 pendant le chrono : rien, zone 5 en attente")
advance(8)
check(gui.Enabled == false and Banner.GetState().Pending == 5, "R14 toujours en attente pendant le chrono")
Hud.heist = false
advance(0.1)
check(gui.Enabled and Banner.GetState().Zone == 5 and gui.Banner.ZoneName.Text == "PARIS" and Banner.GetState().Pending == nil, "R15 fin du chrono : PARIS s'affiche")
advance(FULL)
check(off(), "R16 puis s'éteint normalement")

Hud.heist = true
go(GATE_X[6] + 10)
check(Banner.GetState().Pending == 6, "R17 arche 6 pendant le chrono : zone 6 en attente")
go(GATE_X[6] - 10)
check(Gates.GetZone() == 5 and Banner.GetState().Pending == 5 and gui.Enabled == false, "R18 retour en zone 5 pendant l'attente : la zone 5 remplace la 6")
Hud.heist = false
advance(0.1)
check(gui.Enabled and gui.Banner.ZoneName.Text == "PARIS", "R19 fin du chrono : PARIS (la dernière zone attendue)")
advance(FULL)

Hud.heist = true
go(GATE_X[6] + 10)
go(-100)
check(Gates.GetZone() == 0 and Banner.GetState().Pending == 6, "R20 retour au hub pendant l'attente : zone 6 encore notée")
Hud.heist = false
advance(0.2)
check(off(), "R21 fin du chrono hors de la zone attendue : rien")

section("R5. Attente puis RUN! ou alerte")
Hud.heist = true
go(GATE_X[2] + 10)
check(Banner.GetState().Pending == 2, "R22 arche 2 pendant le chrono : en attente")
Chase.chased = true
Hud.heist = false
advance(0.2)
check(off(), "R23 fin du chrono pendant RUN! : abandonné")
Chase.chased = false
advance(FULL)
check(off(), "R24 et il ne revient pas après RUN!")

Hud.heist = true
go(GATE_X[3] + 10)
Chase.chased = true
advance(1)
Chase.chased = false
advance(1)
Hud.heist = false
advance(0.1)
check(gui.Enabled and gui.Banner.ZoneName.Text == "TOKYO", "R25 RUN! pendant l'attente mais fini avant le chrono : TOKYO s'affiche à la fin du chrono")
advance(FULL)

Hud.heist = true
go(GATE_X[4] + 10)
check(Banner.GetState().Pending == 4, "R26 arche 4 pendant le chrono : en attente")
Alert.shown = true
go(GATE_X[3] + 10)
check(Banner.GetState().Pending == nil and gui.Enabled == false, "R27 passage pendant l'alerte : l'attente est annulée")
Alert.shown = false
Hud.heist = false
advance(FULL)
check(off(), "R28 rien à la fin du chrono")

section("R6. Bandeau allumé quand le chrono arrive")
go(GATE_X[4] + 10)
advance(M.FadeIn + 0.5)
check(gui.Enabled and Banner.GetState().Alpha == 1 and gui.Banner.ZoneName.Text == "LOS ANGELES", "R29 arche 4 : LOS ANGELES, plein")
Hud.heist = true
advance(0.1)
check(gui.Enabled and Banner.GetState().Alpha < 1, `R30 le chrono arrive : fondu de sortie aussitôt ({alphaStr()})`)
advance(M.FadeOut)
check(off(), "R31 éteint, rien en attente")
Hud.heist = false
advance(FULL)
check(off(), "R32 fin du chrono : il ne revient pas")

section("R7. Sans gêne : comme avant")
go(GATE_X[5] + 10)
check(gui.Enabled and gui.Banner.ZoneName.Text == "PARIS" and Banner.GetState().Pending == nil, "R33 arche 5 sans RUN!, alerte ni chrono : PARIS tout de suite")
advance(M.FadeIn + M.Hold - 0.3)
check(gui.Enabled and Banner.GetState().Alpha == 1, "R34 durée normale")
advance(0.3 + M.FadeOut + 0.1)
check(off(), "R35 éteint à la fin")
Hud.heist = true
Banner.Show(5)
check(Banner.GetState().Pending == 5 and gui.Enabled == false, "R36 Show(5) pendant le chrono : en attente aussi")
Hud.heist = false
advance(0.1)
check(gui.Enabled and gui.Banner.ZoneName.Text == "PARIS", "R37 puis affiché (joueur en zone 5)")
check(logCount("[ZoneBannerController]", nil, "client") == 0, "R38 aucune ligne en Studio")

summary("scénario règles")
