--!nocheck
-- B. Bandeau d'entrée de zone (L-110) : passage d'une arche, textes, couleurs, fondu.
local Zones = sharedModule("Config/Zones", "client")
local UiMotion = sharedModule("Config/UiMotion", "client")
local GREEN, ORANGE, RED = Color3.fromHex("#91F630"), Color3.fromHex("#FF8C1A"), Color3.fromHex("#E8413C")
local WHITE = Color3.new(1, 1, 1)
local M = UiMotion.ZoneBanner

buildZoneBannerUi()
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
alice:SetAttribute("ShownSpeed", 2200) -- a134 : le bandeau compare la Speed affichée (Vitesse × trail) à SpeedRequired ; 2 200 = 73 % des 3K de la zone 2
local gui = copyScreen(alice, StarterGui.UI_ZoneBanner)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Banner = clientModule("ZoneBannerController")
local changes = {}
Gates.OnZoneChanged(function(zone, previous)
	table.insert(changes, { zone, previous })
end)
local function go(x, z)
	moveTo(alice, Vector3.new(x, 3, z or 0))
	advance(0.2)
end
local function rest(g)
	local b = g.Banner
	return b.Strip.BackgroundTransparency == 0.25
		and b.Strip.UIStroke.Transparency == 0.5
		and b.ZoneName.TextTransparency == 0
		and b.ZoneName.TextStrokeTransparency == 0.4
		and b.Difficulty.TextTransparency == 0.1
		and b.BackgroundTransparency == 1
		and b.Advice.Speed.TextStrokeTransparency == 1
end

section("B. Config")
check(Zones[1].City == nil and Zones[2].City == "LONDON" and Zones[3].City == "TOKYO" and Zones[4].City == "LOS ANGELES" and Zones[5].City == "PARIS" and Zones[6].City == "NEW YORK", "B1 villes de L-110 ; zone 1 sans ville")
check(M.Screen == "UI_ZoneBanner" and M.FadeIn == 0.35 and M.Hold == 3 and M.FadeOut == 0.6, "B2 UiMotion.ZoneBanner : 0,35 s, 3 s, 0,6 s")

section("B'. Arrivée dans le jeu : rien")
advance(0.5)
check(Gates.GetZone() == 0 and #changes == 0 and gui.Enabled == false and not Banner.GetState().Shown, "B3 au hub : zone 0, pas de bandeau")

section("B''. Passage de l'arche 1")
go(GATE_X[1] - 3)
check(Gates.GetZone() == 0 and gui.Enabled == false, "B4 3 studs avant l'arche : rien")
go(GATE_X[1] + 1)
check(Gates.GetZone() == 0 and gui.Enabled == false, "B5 1 stud après (marge de 2) : rien encore")
moveTo(alice, Vector3.new(GATE_X[1] + 5, 3, 12))
advance(0.2)
check(Gates.GetZone() == 1 and #changes == 1 and changes[1][1] == 1 and changes[1][2] == 0, "B6 5 studs après : zone 1, prévenu (1, 0)")
check(gui.Enabled == true and Banner.GetState().Shown and Banner.GetState().Zone == 1, "B7 écran allumé")
check(gui.Banner.ZoneName.Text == "MINI MART", `B8 zone 1 sans ville : Theme en capitales (« {gui.Banner.ZoneName.Text} »)`)
check(gui.Banner.Advice.Speed.Text == "Speed 0" and gui.Banner.Advice.Damage.Text == "Damage 1", `B9 « {gui.Banner.Advice.Speed.Text} », « {gui.Banner.Advice.Damage.Text} » (L-132 : le mot et le chiffre)`)
check(gui.Banner.Advice.Speed.TextColor3 == GREEN and gui.Banner.Advice.Damage.TextColor3 == RED, "B10 vitesse verte (16/16), force rouge (0/1)")
check(gui.Banner.Difficulty.Text == "Hard" and gui.Banner.Difficulty.TextColor3 == RED and Banner.GetState().Difficulty == "Red", "B11 Difficulty « Hard » en rouge (la moins bonne des deux)")
check(gui.Banner.Advice.RecommendedLabel.Text == "Recommended:" and gui.Banner.Advice.RecommendedLabel.TextColor3 == WHITE, "B12 RecommendedLabel pas touché")
local a = Banner.GetState().Alpha
check(a > 0 and a < 0.5 and gui.Banner.ZoneName.TextTransparency > 0.5 and gui.Banner.Strip.BackgroundTransparency > 0.6, `B13 début du fondu (opacité {string.format("%.2f", a)})`)
check(gui.Banner.BackgroundTransparency == 1 and gui.Banner.Advice.Speed.TextStrokeTransparency == 1, "B14 ce qui est transparent chez Clément le reste")
advance(M.FadeIn)
check(Banner.GetState().Alpha == 1 and rest(gui) and gui.Enabled, "B15 après FadeIn : allure de Clément")

section("B'''. Couleurs en direct, fin du bandeau")
alice:SetAttribute("Damage", 1)
flush()
check(gui.Banner.Advice.Damage.TextColor3 == GREEN and gui.Banner.Difficulty.Text == "Easy" and gui.Banner.Difficulty.TextColor3 == GREEN, "B16 Damage 1 : vert, « Easy »")
advance(M.Hold - 0.5)
check(gui.Enabled and Banner.GetState().Alpha == 1, "B17 encore plein avant la fin de Hold")
advance(0.3 + M.FadeOut / 2)
local mid = Banner.GetState().Alpha
check(gui.Enabled and mid > 0.2 and mid < 0.9 and gui.Banner.ZoneName.TextTransparency > 0.1, `B18 fondu de sortie (opacité {string.format("%.2f", mid)})`)
advance(M.FadeOut)
check(gui.Enabled == false and not Banner.GetState().Shown and Banner.GetState().Zone == nil, "B19 écran éteint")
check(rest(gui), "B20 transparences remises comme Clément les a faites")
alice:SetAttribute("Damage", 2)
flush()
check(gui.Enabled == false, "B21 un changement d'attribut n'allume rien")

section("B''''. Autres zones, retour, marge")
go(GATE_X[2] + 10)
check(Gates.GetZone() == 2 and gui.Enabled and gui.Banner.ZoneName.Text == "LONDON", "B22 arche 2 : LONDON")
check(
	gui.Banner.Advice.Speed.Text == "Speed 3K"
		and gui.Banner.Advice.Damage.Text == "Damage 10"
		and gui.Banner.Advice.Speed.TextColor3 == ORANGE
		and gui.Banner.Advice.Damage.TextColor3 == RED
		and gui.Banner.Difficulty.Text == "Hard",
	"B23 zone 2 : vitesse orange (73 %), force rouge (20 %), « Hard »"
)
alice:SetAttribute("Damage", 5)
flush()
check(gui.Banner.Difficulty.Text == "Medium" and gui.Banner.Difficulty.TextColor3 == ORANGE, "B24 orange et orange : « Medium »")
advance(1)
local before = #changes
go(GATE_X[3] + 10)
check(gui.Banner.ZoneName.Text == "TOKYO" and Banner.GetState().Alpha == 1 and #changes == before + 1, "B25 arche 3 pendant le bandeau : TOKYO, resté plein")
advance(M.Hold - 0.5)
check(gui.Enabled and Banner.GetState().Alpha == 1, "B26 la durée est repartie de zéro")
advance(0.5 + M.FadeOut + 0.1)
check(gui.Enabled == false and rest(gui), "B27 puis éteint")
go(GATE_X[3] - 1)
check(Gates.GetZone() == 3 and gui.Enabled == false, "B28 1 stud en arrière de l'arche 3 (marge) : toujours zone 3")
go(GATE_X[3] - 10)
check(Gates.GetZone() == 2 and gui.Enabled and gui.Banner.ZoneName.Text == "LONDON", "B29 retour en zone 2 : LONDON")
advance(M.FadeIn + M.Hold + M.FadeOut + 0.2)
go(GATE_X[6] + 20)
check(Gates.GetZone() == 6 and gui.Banner.ZoneName.Text == "NEW YORK" and gui.Banner.Advice.Damage.Text == "Damage 2M" and gui.Banner.Advice.Speed.Text == "Speed 3B", "B30 saut en zone 6 : NEW YORK, « Damage 40K », « Speed 48 » (L-132)")
advance(1)

section("B'''''. Retour au hub, écran refait")
before = #changes
go(-100)
check(Gates.GetZone() == 0 and #changes == before + 1 and gui.Banner.ZoneName.Text == "NEW YORK", "B31 retour au hub : zone 0 prévenue, pas de bandeau pour le hub")
advance(M.Hold + M.FadeOut + 1)
check(gui.Enabled == false, "B32 le bandeau en cours finit normalement")
go(GATE_X[4] + 10)
advance(0.5)
check(gui.Enabled and gui.Banner.ZoneName.Text == "LOS ANGELES", "B33 zone 4 : LOS ANGELES")
local fresh = copyScreen(alice, StarterGui.UI_ZoneBanner) -- écran refait par Roblox pendant le bandeau
advance(0.2)
check(not Banner.GetState().Shown and fresh.Enabled == false and rest(fresh), "B34 écran refait pendant le bandeau : arrêt propre, la copie neuve reste au repos")
go(GATE_X[5] + 10)
check(fresh.Enabled and fresh.Banner.ZoneName.Text == "PARIS", "B35 passage suivant : la copie neuve s'allume (PARIS)")
advance(M.FadeIn + M.Hold + M.FadeOut + 0.2)
check(fresh.Enabled == false and rest(fresh), "B36 puis s'éteint, au repos")
Banner.Show(3)
advance(0.1)
check(fresh.Enabled and fresh.Banner.ZoneName.Text == "TOKYO", "B37 Show(3) : essai à la main")
Banner.Show(9)
check(fresh.Banner.ZoneName.Text == "TOKYO", "B38 Show(9) : ignoré")
check(StarterGui.UI_ZoneBanner.Enabled == false and StarterGui.UI_ZoneBanner.Banner.ZoneName.Text == "LONDON" and rest(StarterGui.UI_ZoneBanner), "B39 l'écran de StarterGui n'est pas touché")
check(logCount("[ZoneBannerController]", nil, "client") == 0 and logCount("[ZoneGateController]", nil, "client") == 0, "B40 aucune ligne en Studio")

summary("scénario bandeau")
