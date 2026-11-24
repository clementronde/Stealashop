--!nocheck
-- G. Panneaux des arches (L-071, point 9) : rien tant que BB_ZoneGate manque ; puis une copie par
-- arche (InfoPoint, sinon au-dessus de SignPart), ZoneName = nom anglais de la zone, Damage et Speed
-- au format et aux couleurs de BB_StoreInfo (Shared/AdvicePanel, commun aux deux), SignLeft et
-- SignRight du greybox éteints chez le joueur seulement quand BB_ZoneGate est là.

local Zones = sharedModule("Config/Zones", "client")
local AdvicePanel = sharedModule("AdvicePanel", "client")

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Stores = clientModule("StoreInfoController")

local function panelOf(zone)
	return alice.PlayerGui:FindFirstChild(`BB_ZoneGate_{zone}`)
end
local function infoOf(zone)
	for _, info in Gates.GetPanels() do
		if info.Zone == zone then
			return info
		end
	end
	return nil
end
local function signsOn(zone)
	local sign = GATES[zone].SignPart
	return sign.SignLeft.Enabled, sign.SignRight.Enabled
end
local GREEN, ORANGE, RED = Color3.fromHex("#91F630"), Color3.fromHex("#FF8C1A"), Color3.fromHex("#E8413C")

section("G. BB_ZoneGate pas encore livré : rien ne change")
advance(0.2)
local count = 0
for _, child in alice.PlayerGui:GetChildren() do
	if string.sub(child.Name, 1, 11) == "BB_ZoneGate" then
		count += 1
	end
end
check(count == 0, "G1 aucun panneau d'arche")
local allOn = true
for zone = 1, 6 do
	local left, right = signsOn(zone)
	allOn = allOn and left and right
end
check(allOn, "G2 SignLeft et SignRight du greybox restent allumés sur les 6 arches")
check(logCount("BB_ZoneGate absent de ReplicatedStorage.Assets.UI : les arches gardent leurs panneaux du greybox (L-071)", "PRINT", "client") == 1, "G3 une ligne en Studio, une fois")
check(#Gates.GetPanels() == 6 and infoOf(1).Anchor == nil, "G4 les 6 arches sont suivies, sans panneau")

section("G'. BB_ZoneGate livré en cours de partie")
local template = buildZoneGate()
advance(0.1)
local all = true
for zone = 1, 6 do
	all = all and panelOf(zone) ~= nil
end
check(all, "G5 un panneau par arche, posé à l'arrivée du modèle (sous-dossier Assets/UI/Gates)")
local p3 = panelOf(3)
check(p3:IsA("BillboardGui") and p3.Adornee == GATES[3].SignPart and infoOf(3).Anchor == "SignPart", "G6 sans InfoPoint : accroché à SignPart")
-- Bas du panneau 0,5 stud au-dessus du haut du bandeau (4,5 studs au-dessus de son centre), avancé de 2.
local expected = template.StudsOffset + Vector3.new(0, 4.5 + 0.5 + 0.5 * template.Size.Y.Scale, 2)
check((p3.StudsOffset - expected).Magnitude < 1e-6, `G7 au-dessus du bandeau, vers la caméra (StudsOffset {p3.StudsOffset})`)
check(p3.Size == template.Size and p3.MaxDistance == template.MaxDistance and p3.ResetOnSpawn == false, "G8 taille et portée de Clément gardées")
local off = true
for zone = 1, 6 do
	local left, right = signsOn(zone)
	off = off and not left and not right
end
check(off, "G9 SignLeft et SignRight éteints (Enabled = false) sur les 6 arches")
check(GATES[3].SignPart.SignLeft.Parent == GATES[3].SignPart and GATES[3].SignPart.SignLeft.Label.Text ~= "", "G10 rien n'est retiré de la carte")
check(infoOf(3).SignsOff == 2, "G11 deux SurfaceGui éteints par arche")

section("G''. Textes et couleurs, comme BB_StoreInfo")
for zone = 1, 6 do
	local panel = panelOf(zone)
	local z = Zones[zone]
	check(
		panel.Card.ZoneName.Text == z.Theme and panel.Card.Stats.Damage.Text == AdvicePanel.damageText(z) and panel.Card.Stats.Speed.Text == AdvicePanel.speedText(z),
		`G12.{zone} zone {zone} : « {panel.Card.ZoneName.Text} », « {panel.Card.Stats.Damage.Text} », « {panel.Card.Stats.Speed.Text} »`
	)
end
check(panelOf(3).Card.Stats.Damage.Text == "Damage 80" and panelOf(3).Card.Stats.Speed.Text == "Speed 28" and panelOf(6).Card.Stats.Damage.Text == "Damage 40K", "G13 format du HUD : « Damage 80 », « Speed 28 », « Damage 40K »")
local store3 = alice.PlayerGui:FindFirstChild("BB_StoreInfo_STORE_Z3_Left")
check(store3 ~= nil and (string.gsub(store3.Lines.Damage.Text, "^Strength ", "Damage ")) == panelOf(3).Card.Stats.Damage.Text and store3.Lines.Speed.Text == panelOf(3).Card.Stats.Speed.Text, "G14 mêmes textes que le panneau d'un magasin de la zone")
local function colors(zone)
	local panel = panelOf(zone)
	return panel.Card.Stats.Damage.TextColor3, panel.Card.Stats.Speed.TextColor3
end
local d1, s1 = colors(1)
local _, s2 = colors(2)
local _, s4 = colors(4)
check(d1 == RED and s1 == GREEN and s2 == ORANGE and s4 == RED, "G15 Damage 0, WalkSpeed 16 : zone 1 dégâts rouges et vitesse verte, zone 2 vitesse orange (73 %), zone 4 rouge (47 %)")
alice:SetAttribute("Damage", 40)
flush()
local d2 = colors(2)
local d3 = colors(3)
local d4 = colors(4)
check(d2 == GREEN and d3 == ORANGE and d4 == RED, "G16 Damage 40 : vert en zone 2, orange en zone 3 (50 %), rouge en zone 4 : refait au changement d'attribut")
check(store3.Lines.Damage.TextColor3 == d3 and store3.Lines.Speed.TextColor3 == select(2, colors(3)), "G17 mêmes couleurs que le panneau du magasin de la zone 3")
check(infoOf(3).Damage == "Orange" and infoOf(1).Speed == "Green", "G18 GetPanels : niveaux du joueur")
check(template.Card.ZoneName.Text == "TOKYO" and template.Card.Stats.Speed.Text == "Speed 28" and template.Card.Stats.Speed.TextColor3 == Color3.new(1, 1, 1), "G19 le modèle de Clément n'est pas touché")

section("G'''. InfoPoint, streaming, inbox")
local info = make("Attachment", { Name = "InfoPoint", CFrame = CFrame.new(0, 6, 0) }, GATES[2].SignPart)
advance(0.1)
check(panelOf(2).Adornee == info and infoOf(2).Anchor == "InfoPoint" and panelOf(2).StudsOffset == template.StudsOffset, "G20 InfoPoint ajouté : le panneau s'y accroche, avec les décalages de Clément")
GATES[4].Parent = nil
flush()
local left4, right4 = signsOn(4)
check(panelOf(4) == nil and left4 and right4, "G21 arche sortie du streaming : panneau retiré, ses SurfaceGui rallumés")
GATES[4].Parent = MAP
advance(0.1)
left4, right4 = signsOn(4)
check(panelOf(4) ~= nil and not left4 and not right4, "G22 de retour : panneau refait, SurfaceGui éteints")
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local stray = make("Model", { Name = "ZoneGate_Test" })
make("Part", { Name = "SignPart", Anchored = true, Size = Vector3.new(3, 9, 69), CFrame = CFrame.new(50, 31.5, 0) }, stray)
stray:SetAttribute("Zone", 5)
stray.Parent = inbox
addTag(stray, "ZoneGate")
advance(0.1)
check(#Gates.GetPanels() == 6, "G23 une arche dans _INBOX_CLEMENT est ignorée")
local bare = make("Model", { Name = "ZoneGate_Bare" })
make("Part", { Name = "Arch", Anchored = true, CFrame = CFrame.new(640, 12, 0) }, bare)
bare:SetAttribute("Zone", 6)
bare.Parent = MAP
addTag(bare, "ZoneGate")
advance(0.1)
local bareInfo = nil
for _, entry in Gates.GetPanels() do
	if entry.Gate == "ZoneGate_Bare" then
		bareInfo = entry
	end
end
check(bareInfo ~= nil and bareInfo.Anchor == nil, "G24 arche sans InfoPoint ni SignPart : pas de panneau")
check(logCount("ZoneGate_Bare : ni InfoPoint ni SignPart, pas de panneau sur cette arche", "WARN", "client") == 1, "G25 un avertissement en Studio")
bare:Destroy()

section("G''''. BB_ZoneGate retiré : retour au greybox")
template:Destroy()
advance(0.1)
local none, back = true, true
for zone = 1, 6 do
	none = none and panelOf(zone) == nil
	local left, right = signsOn(zone)
	back = back and left and right
end
check(none, "G26 plus de panneau d'arche")
check(back, "G27 SignLeft et SignRight rallumés")
check(#Stores.GetPanels() == 12, "G28 StoreInfoController suit toujours ses 12 magasins")

summary("scénario arches")
