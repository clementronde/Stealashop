-- Copie d'a94 (2026-11-12, vague 29, L-108 point 5) : « Strength N » au lieu de « Damage N » sur BB_StoreInfo
-- quand AdvicePanel a strengthText ; ReqSignPoint posé dans chaque magasin quand Contract/Models le connaît
-- (sinon 12 avertissements de plus). Sur un arbre d'avant a94 : les anciens contrôles.
local A94_STRENGTH = string.find(SOURCES["shared/AdvicePanel.luau"] or "", "strengthText", 1, true) ~= nil
local A94_REQPOINT = string.find(SOURCES["shared/Contract/Models.luau"] or "", "ReqSignPoint", 1, true) ~= nil
local A94_DMG = if A94_STRENGTH then "Strength" else "Damage"
--!nocheck
-- Banc a25 (vague 8, DEV-030, L-044) : panneaux d'approche des magasins PNJ (StoreInfoController),
-- noms des magasins dans Config/Zones (StoreIds), contrat BB_StoreInfo et InfoPoint (ContractChecker).
-- Fausse place : les 12 magasins du relevé Studio du 2026-11-07 (vitres de 18 × 10,5 centrées en
-- (x, 6.15, ±30.75), InfoPoint des zones 2 à 6 aux positions relevées, aucun en zone 1), enseignes
-- SignPart à la géométrie du constructeur de Clément (×1.5) ; modèles BB_StoreInfo (relevé §1) et
-- BB_WindowHP (StudsOffset 5,45 relevé ; taille 9 × 2,4 studs et SizeOffset (0, 0.5) supposés ici).

local GREEN, ORANGE, RED = Color3.fromHex("#91F630"), Color3.fromHex("#FF8C1A"), Color3.fromHex("#E8413C")
local CLEMENT_GREEN, HP_RED, WHITE = Color3.fromRGB(145, 246, 48), Color3.fromRGB(255, 106, 106), Color3.new(1, 1, 1)
local PANEL_PREFIX = "BB_StoreInfo_"

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
for key in SOURCES do
	local rel = string.match(key, "^shared/(.+)%.luau$")
	if rel then
		local parent = Shared
		local segments = string.split(rel, "/")
		for i = 1, #segments - 1 do
			parent = parent:FindFirstChild(segments[i]) or folder(parent, segments[i])
		end
		moduleScript(parent, segments[#segments], key)
	end
end
local ControllerModule = moduleScript(folder(folder(StarterPlayerScripts, "Client"), "Controllers"), "StoreInfoController", "client/Controllers/StoreInfoController.luau")
local CheckerModule = moduleScript(folder(folder(ServerScriptService, "Server"), "Services"), "ContractChecker", "server/Services/ContractChecker.luau")
local Zones = requireModule(Shared.Config.Zones, "client")

local Assets = folder(ReplicatedStorage, "Assets")
local AssetsUI = folder(Assets, "UI")

-- BB_StoreInfo de Clément (relevé §1).
local function makeStoreInfo()
	local bb = new("BillboardGui", {
		Name = "BB_StoreInfo",
		Size = UDim2.new(8, 220, 2.6, 70),
		StudsOffset = Vector3.new(0, 0, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 0, 0),
		SizeOffset = Vector2.new(0, 0.5),
		MaxDistance = 80,
		AlwaysOnTop = false,
		LightInfluence = 0,
	})
	local panel = new("Frame", { Name = "Panel", Size = UDim2.new(1, 0, 1, 0) }, bb)
	new("UICorner", {}, panel)
	new("UIStroke", {}, panel)
	local storeName = new("TextLabel", { Name = "StoreName", Size = UDim2.new(0.9, 0, 0.42, 0), Position = UDim2.new(0.5, 0, 0.08, 0), Text = "Mini Mart", TextColor3 = WHITE }, bb)
	new("UIStroke", {}, storeName)
	local stats = new("Frame", { Name = "Stats", Size = UDim2.new(0.92, 0, 0.34, 0), Position = UDim2.new(0.5, 0, 0.56, 0) }, bb)
	new("UIListLayout", {}, stats)
	new("TextLabel", { Name = "HP", Size = UDim2.new(0.3, 0, 1, 0), Text = "HP 35", TextColor3 = HP_RED }, stats)
	new("TextLabel", { Name = "Damage", Size = UDim2.new(0.34, 0, 1, 0), Text = "Damage 1", TextColor3 = CLEMENT_GREEN }, stats)
	new("TextLabel", { Name = "Speed", Size = UDim2.new(0.3, 0, 1, 0), Text = "Speed 16", TextColor3 = CLEMENT_GREEN }, stats)
	bb.Parent = AssetsUI
	return bb
end
local StoreInfoTemplate = makeStoreInfo()
local HPTemplate = new("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(9, 0, 2.4, 0), StudsOffset = Vector3.new(0, 5.45, 0), SizeOffset = Vector2.new(0, 0.5), MaxDistance = 60 })
new("Frame", { Name = "Fill" }, new("Frame", { Name = "Bar" }, HPTemplate))
new("TextLabel", { Name = "Label" }, HPTemplate)
HPTemplate.Parent = AssetsUI

-- Magasin complet au contrat 10.4. spec : name, zone, x, side (1 nord, -1 sud), sign = { bas, haut,
-- largeur }, info (hauteur de l'InfoPoint, nil = absent), infoZ, parent.
local Map = folder(Workspace, "Map")
local ZoneFolders = {}
for zone = 1, 6 do
	ZoneFolders[zone] = folder(Map, `Zone_{zone}`)
end
local function makeStore(spec)
	local s = spec.side
	local model = new("Model", { Name = spec.name })
	new("MeshPart", { Name = "Window", Size = Vector3.new(18, 10.5, 0.3), CFrame = CFrame.new(spec.x, 6.15, s * 30.75), Anchored = true }, model)
	local fractured = new("Model", { Name = "WindowFractured" }, model)
	for i = 1, 36 do
		new("Part", { Name = string.format("Shard_%02d", i), Size = Vector3.new(1, 1, 0.3), CFrame = CFrame.new(spec.x, 6.15, s * 30.75), Transparency = 1 }, fractured)
	end
	new("Model", { Name = "Shutter" }, model)
	new("Model", { Name = "Door" }, model)
	local bounds = new("Part", { Name = "Bounds", Size = Vector3.new(57, 14.4, 69), CFrame = CFrame.new(spec.x, 7.65, s * 66), Transparency = 1, CanQuery = false }, model)
	for i = 1, 10 do
		new("Attachment", { Name = string.format("ShelfSlot_%02d", i), CFrame = CFrame.new(-22 + 4 * i, -3, 0) }, bounds)
	end
	new("Attachment", { Name = "GuardSpawn", CFrame = CFrame.new(-22, -7, 27 * s) }, bounds)
	if A94_REQPOINT then
		new("Attachment", { Name = "ReqSignPoint", CFrame = CFrame.new(0, -7, 31 * s) }, bounds)
	end
	local sign = spec.sign
	new("Part", { Name = "SignPart", Size = Vector3.new(sign[3], sign[2] - sign[1], 0.6), CFrame = CFrame.new(spec.x, (sign[1] + sign[2]) / 2, s * 28.8), Anchored = true }, model)
	if spec.info then
		local info = new("Attachment", { Name = "InfoPoint" }, bounds)
		info.WorldPosition = Vector3.new(spec.x, spec.info, s * (spec.infoZ or 27.70))
	end
	model:SetAttribute("Zone", spec.zone)
	addTag(model, "NPCStore")
	model.Parent = spec.parent or ZoneFolders[spec.zone]
	return model
end

local SIGN_Z1 = { 15, 20.1, 30 } -- enseigne par défaut du constructeur { -10, 10, 10, 13.4 } × 1,5
local SIGN_Z24 = { 13.425, 16.125, 48 } -- zones 2 et 4 : { -16, 16, 8.95, 10.75 } × 1,5
local SIGN_Z3 = { 17.1, 20.325, 39 } -- zone 3 : { -13, 13, 11.4, 13.55 } × 1,5
local SIGN_Z5 = { 13.6, 16.27, 48 } -- zone 5 : supposée (InfoPoint à 16,67)
local SIGN_BANK = { 15.5, 18.3, 40 } -- Banque : supposée (InfoPoint à 18,70)
local SIGN_VAULT = { 24, 27.5, 40 } -- Salle des coffres : enseigne « très haute » (L-044), supposée
local STORES = {
	{ name = "STORE_Z1_Superette", zone = 1, x = 65, side = 1, sign = SIGN_Z1 },
	{ name = "STORE_Z1_Kiosque", zone = 1, x = 65, side = -1, sign = SIGN_Z1 },
	{ name = "STORE_Z2_MagasinDeJouets", zone = 2, x = 140, side = 1, sign = SIGN_Z24, info = 16.52 },
	{ name = "STORE_Z2_Confiserie", zone = 2, x = 140, side = -1, sign = SIGN_Z24, info = 16.52 },
	{ name = "STORE_Z3_Electronique", zone = 3, x = 240, side = 1, sign = SIGN_Z3, info = 20.73 },
	{ name = "STORE_Z3_JeuxVideo", zone = 3, x = 240, side = -1, sign = SIGN_Z3, info = 20.73 },
	{ name = "STORE_Z4_Bijouterie", zone = 4, x = 360, side = 1, sign = SIGN_Z24, info = 16.52 },
	{ name = "STORE_Z4_Horlogerie", zone = 4, x = 360, side = -1, sign = SIGN_Z24, info = 16.52 },
	{ name = "STORE_Z5_GalerieDArt", zone = 5, x = 500, side = 1, sign = SIGN_Z5, info = 16.67 },
	{ name = "STORE_Z5_Antiquaire", zone = 5, x = 500, side = -1, sign = SIGN_Z5, info = 16.67 },
	{ name = "STORE_Z6_Banque", zone = 6, x = 660, side = 1, sign = SIGN_BANK, info = 18.70 },
	{ name = "STORE_Z6_SalleDesCoffres", zone = 6, x = 660, side = -1, sign = SIGN_VAULT, info = 14.00, infoZ = 27.65 },
}
local Store = {} -- nom → modèle
for _, spec in STORES do
	Store[spec.name] = makeStore(spec)
end
-- Hors de la map ou hors contrat : jamais de panneau.
local Inbox = folder(Workspace, "_INBOX_CLEMENT")
local inboxStore = makeStore({ name = "STORE_Z1_Superette_V2", zone = 1, x = 0, side = 1, sign = SIGN_Z1, info = 20.9, parent = Inbox })
local badZone = makeStore({ name = "STORE_Z7_Test", zone = 7, x = 800, side = 1, sign = SIGN_Z1, info = 20.9, parent = Map })
local notModel = folder(Map, "STORE_Folder")
addTag(notModel, "NPCStore")
local assetCopy = makeStore({ name = "STORE_Z2_Confiserie", zone = 2, x = 0, side = 1, sign = SIGN_Z24, info = 16.52, parent = Assets })

-- Joueur local, attributs posés par ToolService (Damage) et StatsService (WalkSpeed) au chargement.
local player = new("Player", { Name = "Alice", UserId = 1 }, Players)
local PlayerGui = new("PlayerGui", { Name = "PlayerGui" }, player)
Players.LocalPlayer = player
player:SetAttribute("Damage", 1)
player:SetAttribute("WalkSpeed", 16)
player:SetAttribute("ShownSpeed", 0) -- copie a134 : les panneaux comparent la Speed affichée (Vitesse × trail) à SpeedRequired

local function panelOf(storeName)
	return PlayerGui:FindFirstChild(PANEL_PREFIX .. storeName)
end
local function panelCount()
	local n = 0
	for _, child in PlayerGui:GetChildren() do
		if string.sub(child.Name, 1, #PANEL_PREFIX) == PANEL_PREFIX then
			n += 1
		end
	end
	return n
end
local function labelOf(gui, name)
	return gui and gui:FindFirstChild(name, true)
end
local function v3near(a, b)
	return a ~= nil and near(a.X, b.X) and near(a.Y, b.Y) and near(a.Z, b.Z)
end
local function isDestroyed(inst)
	return rawget(inst, "_destroyed") == true
end
local function colorName(color)
	if color == GREEN then
		return "vert"
	elseif color == ORANGE then
		return "orange"
	elseif color == RED then
		return "rouge"
	end
	return tostring(color)
end
-- Couleurs (Damage, Speed) du panneau d'un magasin, en mots.
local function colors(storeName)
	local gui = panelOf(storeName)
	if gui == nil then
		return "pas de panneau"
	end
	return `{colorName(labelOf(gui, "Damage").TextColor3)}/{colorName(labelOf(gui, "Speed").TextColor3)}`
end

---------------------------------------------------------------- A. Config/Zones
print("== A. Config/Zones : valeurs de la section 4 et noms des magasins (StoreIds)")
do
	-- Tableau de la section 4 : PV vitre, dégâts conseillés, vitesse conseillée, vigile, retour, revenu. Retours ×1,25 (zones rallongées par Clément, 2026-11-08, L-071).
	local DOC = {
		-- Copie a134 (rééquilibrage v2, passe 3) : PV = 27,197 × dégâts (zone 6 : 54,393 ×), dégâts = arme × aura
		-- du kit, marche que donne la Speed du panneau (0, 3K, 100K, 3M, 100M, 3B), vigile = 0,9 × marche + 1.
		{ 27, 1, 16, 13.4, 75, 1 },
		{ 272, 10, 16 + 4 * math.log10(1 + 3e3 / 100), 20.8, 175, 8 },
		{ 3264, 120, 16 + 4 * math.log10(1 + 100e3 / 100), 26.2, 300, 60 },
		{ 40795, 1500, 16 + 4 * math.log10(1 + 3e6 / 100), 31.5, 450, 450 },
		{ 543933, 20000, 16 + 4 * math.log10(1 + 100e6 / 100), 37, 625, 3500 },
		{ 108786611, 2000000, 16 + 4 * math.log10(1 + 3e9 / 100), 42.3, 825, 25000 },
	}
	local ok = #Zones == 6
	for zone, row in DOC do
		local z = Zones[zone]
		local got = { z.WindowHP, z.AdvisedDamage, z.AdvisedSpeed, z.GuardSpeed, z.ReturnDistance, z.BaseIncome }
		for i = 1, 6 do
			if got[i] ~= row[i] then
				ok = false
				print(`    zone {zone}, colonne {i} : {got[i]} au lieu de {row[i]}`)
			end
		end
	end
	check(ok, "les 6 zones ont toutes les valeurs du rééquilibrage v2 (a134)")
	local namesOk = true
	for _, spec in STORES do
		local z = Zones[spec.zone]
		local index = if spec.side == 1 then 1 else 2
		if `STORE_Z{spec.zone}_{z.StoreIds[index]}` ~= spec.name then
			namesOk = false
			print(`    {spec.name} : StoreIds donne STORE_Z{spec.zone}_{z.StoreIds[index]}`)
		end
	end
	check(namesOk, "StoreIds = les 12 noms de modèles de la place (relevé §2), dans l'ordre de Stores")
	local shapeOk = true
	for _, z in Zones do
		shapeOk = shapeOk and #z.Stores == 2 and #z.StoreIds == 2 and table.isfrozen(z.StoreIds)
	end
	check(shapeOk, "2 noms affichés et 2 noms de modèles par zone, gelés comme le reste de Config")
	check(Zones[1].Stores[1] == "Mini Mart" and Zones[4].Stores[2] == "Watches & Clocks" and Zones[6].Stores[2] == "Vault", "noms affichés inchangés (Mini Mart, Watches & Clocks, Vault)")
end

---------------------------------------------------------------- B. démarrage
print("== B. Démarrage : un panneau par magasin de la map")
local Controller = requireModule(ControllerModule, "client")
clearLog()
Controller.Start()
flush()
check(panelCount() == 12, `12 panneaux dans le PlayerGui ({panelCount()})`)
local allThere = true
for _, spec in STORES do
	allThere = allThere and panelOf(spec.name) ~= nil
end
check(allThere, "un panneau BB_StoreInfo_<magasin> pour chacun des 12 magasins")
check(panelOf("STORE_Z1_Superette_V2") == nil, "magasin de _INBOX_CLEMENT : pas de panneau")
check(panelOf("STORE_Z7_Test") == nil and logHas("STORE_Z7_Test : attribut Zone invalide (7), pas de panneau", "WARN", "client"), "Zone = 7 : pas de panneau, une ligne en Studio")
check(panelOf("STORE_Folder") == nil, "un Folder taggé NPCStore : ignoré")
check(#PlayerGui:GetChildren() == 12, "rien d'autre dans le PlayerGui (copie de Assets ignorée)")
check(logHas("[StoreInfoController] 12 panneau(x) de magasin, dont 2 sans InfoPoint (au-dessus de la vitre)", "PRINT", "client"), "ligne de démarrage en Studio")
check(logHas("STORE_Z1_Superette : pas d'InfoPoint, panneau posé au-dessus de la vitre (L-044)", "PRINT", "client") and logHas("STORE_Z1_Kiosque : pas d'InfoPoint", "PRINT", "client"), "repli signalé une fois pour la Supérette et le Kiosque")
check(logCount("pas d'InfoPoint", "PRINT", "client") == 2, "aucun autre magasin en repli")

---------------------------------------------------------------- C. textes
print("== C. Textes en anglais et nombres au format du HUD")
do
	local EXPECTED = {
		STORE_Z1_Superette = { "Mini Mart", "HP 27", `{A94_DMG} 1`, "Speed 0" },
		STORE_Z1_Kiosque = { "Kiosk", "HP 27", `{A94_DMG} 1`, "Speed 0" },
		STORE_Z2_MagasinDeJouets = { "Toy Shop", "HP 272", `{A94_DMG} 10`, "Speed 3K" },
		STORE_Z2_Confiserie = { "Sweet Shop", "HP 272", `{A94_DMG} 10`, "Speed 3K" },
		STORE_Z3_Electronique = { "Electronics", "HP 3264", `{A94_DMG} 120`, "Speed 100K" },
		STORE_Z3_JeuxVideo = { "Video Games", "HP 3264", `{A94_DMG} 120`, "Speed 100K" },
		STORE_Z4_Bijouterie = { "Jewelry", "HP 40.7K", `{A94_DMG} 1.5K`, "Speed 3M" },
		STORE_Z4_Horlogerie = { "Watches & Clocks", "HP 40.7K", `{A94_DMG} 1.5K`, "Speed 3M" },
		STORE_Z5_GalerieDArt = { "Art Gallery", "HP 543K", `{A94_DMG} 20K`, "Speed 100M" },
		STORE_Z5_Antiquaire = { "Antiques", "HP 543K", `{A94_DMG} 20K`, "Speed 100M" },
		STORE_Z6_Banque = { "Bank", "HP 108M", `{A94_DMG} 2M`, "Speed 3B" },
		STORE_Z6_SalleDesCoffres = { "Vault", "HP 108M", `{A94_DMG} 2M`, "Speed 3B" },
	}
	for name, want in EXPECTED do
		local gui = panelOf(name)
		local got = {}
		for i, element in { "StoreName", "HP", "Damage", "Speed" } do
			local l = labelOf(gui, element)
			got[i] = if l then l.Text else "?"
		end
		check(table.concat(got, " · ") == table.concat(want, " · "), `{name} : {table.concat(got, " · ")}`)
	end
end

---------------------------------------------------------------- D. accroche
print("== D. Accroche : InfoPoint, sinon au-dessus de la vitre")
do
	local infoOk = true
	for _, spec in STORES do
		if spec.info then
			local gui = panelOf(spec.name)
			local info = Store[spec.name]:FindFirstChild("InfoPoint", true)
			if gui.Adornee ~= info or not v3near(gui.StudsOffset, Vector3.zero) then
				infoOk = false
				print(`    {spec.name} : accroché à {tostring(gui.Adornee)}, StudsOffset {tostring(gui.StudsOffset)}`)
			end
		end
	end
	check(infoOk, "zones 2 à 6 : accrochés à leur InfoPoint, décalage du modèle (0, 0, 0) gardé")
	for _, name in { "STORE_Z1_Superette", "STORE_Z1_Kiosque" } do
		local gui = panelOf(name)
		check(gui.Adornee == Store[name].Window, `{name} : accroché à la vitre Window (pièce de la barre de PV)`)
		-- Haut de la barre : 5,45 + (0,5 + 0,5) × 2,4 = 7,85 ; + 0,4 = 8,25, mais l'enseigne (15 à 20,1,
		-- soit 8,85 à 13,95 au-dessus du centre de la vitre) serait recouverte : 13,95 + 0,4 = 14,35.
		check(v3near(gui.StudsOffset, Vector3.new(0, 14.35, 3.05)), `{name} : au-dessus de l'enseigne et devant la façade, StudsOffset {tostring(gui.StudsOffset)} = (0, 14.35, 3.05)`)
	end
	local gui = panelOf("STORE_Z1_Superette")
	check(gui.ResetOnSpawn == false and gui.Parent == PlayerGui, "copie dans le PlayerGui, ResetOnSpawn = false (survit à la réapparition)")
end

---------------------------------------------------------------- E. visuel de Clément intact
print("== E. Le visuel de Clément n'est pas touché")
do
	local ROOT_ALLOWED = { Name = true, ResetOnSpawn = true, Adornee = true, StudsOffset = true }
	local function changes(template, clone)
		local out = {}
		local function compare(a, b, path, allowed)
			local pa, pb = rawget(a, "_props"), rawget(b, "_props")
			for k, v in pa do
				if not allowed[k] and pb[k] ~= v then
					table.insert(out, `{path}.{k}`)
				end
			end
			for k in pb do
				if pa[k] == nil and not allowed[k] then
					table.insert(out, `{path}.{k} (ajoutée)`)
				end
			end
		end
		compare(template, clone, "BB_StoreInfo", ROOT_ALLOWED)
		local ta, tb = template:GetDescendants(), clone:GetDescendants()
		if #ta ~= #tb then
			table.insert(out, "nombre d'éléments")
			return out
		end
		for i, d in ta do
			local allowed = {}
			if d.Name == "StoreName" or d.Name == "HP" then
				allowed = { Text = true }
			elseif d.Name == "Damage" or d.Name == "Speed" then
				allowed = { Text = true, TextColor3 = true }
			end
			compare(d, tb[i], d.Name, allowed)
		end
		return out
	end
	local all = {}
	for _, spec in STORES do
		for _, change in changes(StoreInfoTemplate, panelOf(spec.name)) do
			table.insert(all, `{spec.name} : {change}`)
		end
	end
	check(#all == 0, "copies identiques au modèle (tailles, positions, SizeOffset, MaxDistance, styles), sauf textes, couleur de Damage et Speed, accroche, StudsOffset du repli")
	for i = 1, math.min(#all, 6) do
		print("    " .. all[i])
	end
	local gui = panelOf("STORE_Z3_Electronique")
	check(labelOf(gui, "HP").TextColor3 == HP_RED and labelOf(gui, "StoreName").TextColor3 == WHITE, "HP et StoreName gardent la couleur de Clément")
	local t = StoreInfoTemplate
	check(labelOf(t, "Damage").TextColor3 == CLEMENT_GREEN and labelOf(t, "Damage").Text == "Damage 1" and labelOf(t, "StoreName").Text == "Mini Mart" and t.Adornee == nil and t.Parent == AssetsUI, "le modèle BB_StoreInfo de ReplicatedStorage reste tel quel")
	check(HPTemplate.StudsOffset == Vector3.new(0, 5.45, 0) and HPTemplate.Parent == AssetsUI, "le modèle BB_WindowHP n'est pas touché")
end

---------------------------------------------------------------- F. couleurs au départ
print("== F. Couleurs au départ (Damage 1, WalkSpeed 16)")
do
	local WANT = {
		[1] = "vert/vert", -- 1/1, Speed du panneau 0 : toujours vert
		[2] = "rouge/rouge", -- 1/10 = 10 %, Speed 0/3K
		[3] = "rouge/rouge",
		[4] = "rouge/rouge",
		[5] = "rouge/rouge",
		[6] = "rouge/rouge",
	}
	for _, spec in STORES do
		check(colors(spec.name) == WANT[spec.zone], `{spec.name} : {colors(spec.name)} (attendu {WANT[spec.zone]})`)
	end
end

---------------------------------------------------------------- G. seuils
print("== G. Seuils : vert à 100 %, orange de 50 à 99 %, rouge en dessous (zone 2 : 10 dégâts, vitesse 22)")
do
	local name = "STORE_Z2_MagasinDeJouets"
	local cases = {
		{ "Damage", 10, "vert", "100 %" },
		{ "Damage", 9.9, "orange", "99 %" },
		{ "Damage", 5, "orange", "50 %" },
		{ "Damage", 4.9, "rouge", "49 %" },
		{ "Damage", 10 * (1 - 1e-12), "vert", "100 % à une erreur d'arrondi près" },
		{ "Damage", 10 * (1 - 1e-6), "orange", "99,9999 %" },
		{ "Damage", 12, "vert", "120 %" },
		{ "Damage", 0, "rouge", "0" },
		{ "ShownSpeed", 3000, "vert", "100 %" },
		{ "ShownSpeed", 2970, "orange", "99 %" },
		{ "ShownSpeed", 1500, "orange", "50 %" },
		{ "ShownSpeed", 1470, "rouge", "49 %" },
		{ "ShownSpeed", 1e12, "vert", "très au-dessus" },
	}
	for _, case in cases do
		local attribute, value, want, label = case[1], case[2], case[3], case[4]
		player:SetAttribute(attribute, value)
		local element = if attribute == "Damage" then "Damage" else "Speed"
		local got = colorName(labelOf(panelOf(name), element).TextColor3)
		check(got == want, `{element} à {label} ({value}) : {got}`)
	end
	player:SetAttribute("Damage", 1)
	player:SetAttribute("ShownSpeed", 0)
end

---------------------------------------------------------------- H. mise à jour
print("== H. Mise à jour dès que Damage ou WalkSpeed change, sur tous les panneaux")
do
	player:SetAttribute("Damage", 1500) -- outil plus fort, aura
	player:SetAttribute("ShownSpeed", 1.5e9) -- tapis, trail
	local WANT = { [1] = "vert/vert", [2] = "vert/vert", [3] = "vert/vert", [4] = "vert/vert", [5] = "rouge/vert", [6] = "rouge/orange" }
	local ok = true
	for _, spec in STORES do
		if colors(spec.name) ~= WANT[spec.zone] then
			ok = false
			print(`    {spec.name} : {colors(spec.name)} au lieu de {WANT[spec.zone]}`)
		end
	end
	check(ok, "Damage 1.5K et Speed 1.5B : zones 1 à 4 vertes, zone 5 rouge/vert, zone 6 rouge/orange")
	player:SetAttribute("Damage", 10000)
	check(colors("STORE_Z5_GalerieDArt") == "orange/vert" and colors("STORE_Z5_Antiquaire") == "orange/vert", "Damage 10K = 50 % de 20K : orange en zone 5")
	player:SetAttribute("Damage", 9800)
	check(colors("STORE_Z5_GalerieDArt") == "rouge/vert", "Damage 9.8K = 49 % : rouge")
	local gui = panelOf("STORE_Z5_GalerieDArt")
	check(labelOf(gui, "Damage").Text == `{A94_DMG} 20K` and labelOf(gui, "Speed").Text == "Speed 100M", "les textes ne changent pas avec les couleurs")
	-- La vitesse comparée est le WalkSpeed (section 4), pas la stat Speed entraînée au tapis.
	-- a134 : la vitesse comparée est la Speed affichée (attribut ShownSpeed), ni la stat Speed ni le WalkSpeed.
	player:SetAttribute("ShownSpeed", 0)
	player:SetAttribute("Speed", 5e9)
	player:SetAttribute("WalkSpeed", 70)
	check(colors("STORE_Z6_Banque") == "rouge/rouge" and colors("STORE_Z1_Superette") == "vert/vert", "stat Speed à 5B et WalkSpeed 70 mais ShownSpeed 0 : Speed rouge en zone 6, vert en zone 1")
	player:SetAttribute("Speed", 0)
	player:SetAttribute("WalkSpeed", 16)
	player:SetAttribute("ShownSpeed", 3e9)
	check(colors("STORE_Z6_Banque") == "rouge/vert", "stat Speed à 0 mais ShownSpeed 3B : Speed vert en zone 6")
	player:SetAttribute("Speed", nil)
end

---------------------------------------------------------------- I. attribut absent
print("== I. Attribut absent (profil pas encore chargé) : 0, donc rouge")
do
	player:SetAttribute("Damage", nil)
	player:SetAttribute("ShownSpeed", nil)
	local ok = true
	for _, spec in STORES do
		-- a134 : en zone 1, la Speed du panneau est 0 : verte même sans attribut.
		ok = ok and colors(spec.name) == (if spec.zone == 1 then "rouge/vert" else "rouge/rouge")
	end
	check(ok, "sans Damage ni ShownSpeed : tout en rouge (sauf la Speed de la zone 1, toujours verte)")
	player:SetAttribute("Damage", 1)
	player:SetAttribute("ShownSpeed", 0)
	check(colors("STORE_Z1_Superette") == "vert/vert", "profil chargé : Supérette en vert")
end

---------------------------------------------------------------- J. InfoPoint qui arrive puis repart
print("== J. Repli, puis InfoPoint posé, puis retiré")
do
	local superette = Store.STORE_Z1_Superette
	local before = panelOf("STORE_Z1_Superette")
	local info = new("Attachment", { Name = "InfoPoint" }, superette.Bounds)
	info.WorldPosition = Vector3.new(65, 20.9, 27.70)
	check(panelOf("STORE_Z1_Superette").Adornee == superette.Window, "avant le tour suivant : rien ne change encore (task.defer)")
	flush()
	local gui = panelOf("STORE_Z1_Superette")
	check(gui == before, "même copie : pas de panneau en double ni refait")
	check(gui.Adornee == info and v3near(gui.StudsOffset, Vector3.zero), "InfoPoint arrivé : accroché à lui, StudsOffset du modèle (0, 0, 0)")
	check(panelCount() == 12, "toujours 12 panneaux")
	info:Destroy()
	flush()
	gui = panelOf("STORE_Z1_Superette")
	check(gui == before and gui.Adornee == superette.Window and v3near(gui.StudsOffset, Vector3.new(0, 14.35, 3.05)), "InfoPoint retiré : de nouveau au-dessus de la vitre")
	local misnamed = new("Part", { Name = "InfoPoint", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(65, 21, 27.7) }, superette)
	flush()
	check(panelOf("STORE_Z1_Superette").Adornee == superette.Window, "un InfoPoint qui n'est pas un Attachment n'est pas pris (repli)")
	misnamed:Destroy()
	flush()
end

---------------------------------------------------------------- K. repli : enseigne et barre de PV
print("== K. Repli : enseigne haute, enseigne tournée, sans modèle BB_WindowHP, SizeOffset du modèle")
do
	local kiosque = Store.STORE_Z1_Kiosque
	local sign = kiosque.SignPart
	local function offset()
		return panelOf("STORE_Z1_Kiosque").StudsOffset
	end
	sign.Parent = nil
	flush()
	check(v3near(offset(), Vector3.new(0, 8.25, 3.05)), `sans enseigne : 0,4 stud au-dessus de la barre de PV (7,85 + 0,4), {tostring(offset())}`)
	sign.CFrame = CFrame.new(65, 26.5, -28.8) -- 23,95 à 29,05 : loin au-dessus de la vitre
	sign.Parent = kiosque
	flush()
	check(v3near(offset(), Vector3.new(0, 8.25, 3.05)), `enseigne très haute (comme la Salle des coffres) : sous elle, au-dessus de la barre, {tostring(offset())}`)
	sign.Parent = nil
	sign.Size = Vector3.new(30, 2, 0.6)
	-- Tournée de 90° autour de Z : ses 30 studs de long sont à la verticale, de 15 à 45.
	sign.CFrame = cframeWithRotation(Vector3.new(65, 30, -28.8), { 0, -1, 0, 1, 0, 0, 0, 0, 1 })
	sign.Parent = kiosque
	flush()
	check(v3near(offset(), Vector3.new(0, 45 - 6.15 + 0.4, 3.05)), `enseigne tournée (boîte orientée) : au-dessus de son haut réel (45), {tostring(offset())}`)
	sign.Parent = nil
	sign.Size = Vector3.new(30, 5.1, 0.6)
	sign.CFrame = CFrame.new(65, 17.55, -28.8)
	sign.Parent = kiosque
	flush()
	check(v3near(offset(), Vector3.new(0, 14.35, 3.05)), "enseigne remise : de nouveau au-dessus d'elle")

	-- Sans modèle BB_WindowHP : le haut de la vitre (5,25) sert de barre ; 5,65 + 2,6 tient sous l'enseigne (8,85).
	HPTemplate.Parent = nil
	sign.Parent = nil
	sign.Parent = kiosque
	flush()
	check(v3near(offset(), Vector3.new(0, 5.65, 3.05)), `sans BB_WindowHP : 0,4 stud au-dessus du haut de la vitre, sous l'enseigne, {tostring(offset())}`)
	HPTemplate.Parent = AssetsUI

	-- SizeOffset du modèle à (0, 0) : le centre est au point, le panneau monte de la moitié de ses 2,6 studs.
	StoreInfoTemplate.SizeOffset = Vector2.new(0, 0)
	kiosque.Parent = nil
	kiosque.Parent = ZoneFolders[1]
	flush()
	check(v3near(offset(), Vector3.new(0, 14.35 + 1.3, 3.05)) and panelOf("STORE_Z1_Kiosque").SizeOffset == Vector2.new(0, 0), `SizeOffset (0, 0) : bas du panneau toujours à 14,35, {tostring(offset())}`)
	StoreInfoTemplate.SizeOffset = Vector2.new(0, 0.5)
	kiosque.Parent = nil
	kiosque.Parent = ZoneFolders[1]
	flush()
	check(v3near(offset(), Vector3.new(0, 14.35, 3.05)), "modèle remis : (0, 14.35, 3.05)")
end

---------------------------------------------------------------- L. streaming
print("== L. Streaming : magasins qui partent et reviennent")
do
	local superette = Store.STORE_Z1_Superette
	local old = panelOf("STORE_Z1_Superette")
	superette.Parent = nil
	check(panelOf("STORE_Z1_Superette") == nil and isDestroyed(old), "magasin sorti du streaming : son panneau est détruit")
	check(panelCount() == 11 and #Controller.GetPanels() == 11, "11 panneaux, GetPanels en liste 11")
	player:SetAttribute("ShownSpeed", 70)
	player:SetAttribute("Damage", 0.5)
	superette.Parent = ZoneFolders[1]
	flush()
	local gui = panelOf("STORE_Z1_Superette")
	check(gui ~= nil and gui ~= old and gui.Adornee == superette.Window, "magasin revenu : un nouveau panneau, au-dessus de la vitre")
	check(labelOf(gui, "StoreName").Text == "Mini Mart" and labelOf(gui, "HP").Text == "HP 27", "textes refaits")
	check(colors("STORE_Z1_Superette") == "orange/vert", "couleurs à jour des stats changées pendant son absence (Damage 0,5 = 50 %, WalkSpeed 70)")
	player:SetAttribute("Damage", 1)
	player:SetAttribute("ShownSpeed", 0)

	-- Arrivée en morceaux : le modèle d'abord, vide, puis ses pièces.
	local conf = Store.STORE_Z2_Confiserie
	conf.Parent = nil
	local children = conf:GetChildren()
	for _, child in children do
		child.Parent = nil
	end
	conf.Parent = ZoneFolders[2]
	flush()
	check(panelOf("STORE_Z2_Confiserie") == nil, "magasin arrivé vide : pas encore de panneau")
	local entry
	for _, info in Controller.GetPanels() do
		if info.Store == "STORE_Z2_Confiserie" then
			entry = info
		end
	end
	check(entry ~= nil and entry.Anchor == nil and entry.Damage == nil, "GetPanels : connu, sans accroche ni couleur")
	for _, child in children do
		child.Parent = conf
	end
	check(panelOf("STORE_Z2_Confiserie") == nil, "pièces arrivées : panneau fait au tour suivant (task.defer)")
	flush()
	gui = panelOf("STORE_Z2_Confiserie")
	check(gui ~= nil and gui.Adornee == conf:FindFirstChild("InfoPoint", true), "pièces arrivées : panneau accroché à l'InfoPoint")
	check(panelCount() == 12, "12 panneaux de nouveau")

	-- La vitre seule part (pas d'InfoPoint dans la Supérette) puis revient.
	local window = superette.Window
	window.Parent = nil
	flush()
	check(panelOf("STORE_Z1_Superette") == nil and panelCount() == 11, "vitre sortie et pas d'InfoPoint : plus d'accroche, panneau retiré")
	window.Parent = superette
	flush()
	check(panelOf("STORE_Z1_Superette") ~= nil and panelOf("STORE_Z1_Superette").Adornee == window, "vitre revenue : panneau refait au-dessus d'elle")
	check(panelCount() == 12, "12 panneaux")
end

---------------------------------------------------------------- M. noms
print("== M. Noms de magasins : variante, nom inconnu")
local arcade, night
do
	clearLog()
	night = makeStore({ name = "STORE_Z2_Confiserie_Night", zone = 2, x = 150, side = -1, sign = SIGN_Z24, info = 16.52 })
	arcade = makeStore({ name = "STORE_Z3_Arcade", zone = 3, x = 250, side = 1, sign = SIGN_Z3, info = 20.73 })
	flush()
	check(labelOf(panelOf("STORE_Z2_Confiserie_Night"), "StoreName").Text == "Sweet Shop", "variante STORE_Z2_Confiserie_Night : « Sweet Shop »")
	check(labelOf(panelOf("STORE_Z3_Arcade"), "StoreName").Text == "Electronics", "nom absent de Config/Zones : nom de la zone 3 (« Electronics »)")
	check(logHas("STORE_Z3_Arcade : nom absent de Config/Zones (zone 3 : STORE_Z3_Electronique ou STORE_Z3_JeuxVideo), le panneau affiche le nom de la zone « Electronics »", "WARN", "client"), "nom inconnu : une ligne en Studio, avec les noms attendus")
	check(logCount("[StoreInfoController]", "WARN", "client") == 1, "et c'est la seule")
end

---------------------------------------------------------------- N. modèle BB_StoreInfo absent
print("== N. Modèle BB_StoreInfo absent puis livré")
do
	clearLog()
	StoreInfoTemplate.Parent = nil
	arcade.Parent = nil
	arcade.Parent = ZoneFolders[3]
	flush()
	check(panelOf("STORE_Z3_Arcade") == nil, "sans modèle : pas de panneau")
	check(logCount("BB_StoreInfo absent de ReplicatedStorage.Assets.UI : pas de panneau d'approche (L-044)", "PRINT", "client") == 1, "une ligne en Studio")
	night.Parent = nil
	night.Parent = ZoneFolders[2]
	flush()
	check(logCount("BB_StoreInfo absent", "PRINT", "client") == 1, "une seule fois")
	local sub = folder(AssetsUI, "Stores") -- rangé dans un sous-dossier (permis par 2.2)
	StoreInfoTemplate.Parent = sub
	arcade.Parent = nil
	arcade.Parent = ZoneFolders[3]
	flush()
	check(panelOf("STORE_Z3_Arcade") ~= nil, "modèle livré (dans un sous-dossier d'Assets/UI) : panneau au retour du magasin")
	StoreInfoTemplate.Parent = AssetsUI
	sub:Destroy()
end

---------------------------------------------------------------- O. GetPanels
print("== O. GetPanels")
do
	night:Destroy()
	arcade:Destroy()
	flush()
	local list = Controller.GetPanels()
	check(#list == 12, `12 magasins ({#list})`)
	local sorted = true
	for i = 2, #list do
		sorted = sorted and list[i - 1].Store < list[i].Store
	end
	check(sorted, "triés par nom de magasin")
	local byName = {}
	for _, info in list do
		byName[info.Store] = info
	end
	local s, v = byName.STORE_Z1_Superette, byName.STORE_Z6_SalleDesCoffres
	check(s and s.Zone == 1 and s.Anchor == "Window" and s.Damage == "Green" and s.Speed == "Green", "Supérette : zone 1, Window, Green/Green")
	check(v and v.Zone == 6 and v.Anchor == "InfoPoint" and v.Damage == "Red" and v.Speed == "Red", "Salle des coffres : zone 6, InfoPoint, Red/Red")
	check(byName.STORE_Z2_Confiserie and byName.STORE_Z2_Confiserie.Speed == "Red", "Confiserie : Speed Red (a134 : Speed affichée 0 pour 3K)")
	check(panelCount() == 12 and #PlayerGui:GetChildren() == 12, "magasins détruits : leurs panneaux aussi")
	check(logCount("[StoreInfoController]", "WARN", "client") == 0, "aucun avertissement du contrôleur depuis la section N")
end

---------------------------------------------------------------- P. ContractChecker
print("== P. ContractChecker : BB_StoreInfo et InfoPoint facultatif")
do
	badZone:Destroy()
	notModel:Destroy()
	assetCopy:Destroy()
	local Checker = requireModule(CheckerModule, "server")
	local function run()
		clearLog()
		Checker.Start()
	end
	local function summary()
		for _, line in LOG do
			if line.side == "server" and string.find(line.text, "[Contrat] Contrat :", 1, true) then
				return line.text, line.kind
			end
		end
		return "?", "?"
	end
	local function shout()
		for _, line in LOG do
			if line.side == "server" and line.kind == "WARN" then
				print("    " .. line.text)
			end
		end
	end

	run()
	local text, kind = summary()
	local warnLine = "[Contrat] Magasins PNJ · Workspace.Map.Zone_1.STORE_Z1_Superette.InfoPoint introuvable (facultatif : sans lui, le panneau BB_StoreInfo se pose au-dessus de Window, L-044)"
	check(logHas(warnLine, "WARN", "server"), "InfoPoint absent de la Supérette : avertissement en orange (warn)")
	check(logHas("STORE_Z1_Kiosque.InfoPoint introuvable (facultatif", "WARN", "server"), "et du Kiosque")
	check(logCount("InfoPoint", nil, "server") == 2, "les 10 autres magasins et celui de l'inbox ont leur InfoPoint : rien à dire")
	check(kind == "PRINT" and string.find(text, "[Contrat] Contrat : OK · 2 avertissement(s) · ", 1, true) == 1, `pas un problème : « {text} »`)
	check(logCount("Billboards · BB_StoreInfo", nil, "server") == 0, "BB_StoreInfo conforme (StoreName, HP, Damage, Speed en TextLabel) : rien à dire")
	if not (kind == "PRINT" and string.find(text, "Contrat : OK", 1, true)) then
		shout()
	end

	-- InfoPoint mal écrit, ou qui n'est pas un Attachment : des problèmes, comme pour les autres éléments.
	local typo = new("Attachment", { Name = "Infopoint" }, Store.STORE_Z1_Superette.Bounds)
	local part = new("Part", { Name = "InfoPoint", Size = Vector3.new(1, 1, 1) }, Store.STORE_Z1_Kiosque)
	run()
	text, kind = summary()
	check(logHas("STORE_Z1_Superette.InfoPoint introuvable (« Infopoint » trouvé : le renommer en InfoPoint) (facultatif", "WARN", "server"), "« Infopoint » : problème, avec le nom exact")
	check(logHas("STORE_Z1_Kiosque.InfoPoint doit être un Attachment (trouvé : Part)", "WARN", "server"), "InfoPoint en Part : problème")
	check(kind == "WARN" and string.find(text, "[Contrat] Contrat : 2 problème(s) · ", 1, true) == 1 and not string.find(text, "avertissement", 1, true), `2 problèmes, plus d'avertissement : « {text} »`)
	typo:Destroy()
	part:Destroy()

	-- BB_StoreInfo incomplet.
	local t = StoreInfoTemplate
	local speed = labelOf(t, "Speed")
	speed.Name = "Speed2"
	local hp = labelOf(t, "HP")
	hp.Parent = nil
	local fakeHP = new("Frame", { Name = "HP" }, labelOf(t, "Stats"))
	run()
	text, kind = summary()
	check(logHas("[Contrat] Billboards · BB_StoreInfo.Speed introuvable", "WARN", "server"), "BB_StoreInfo sans Speed : problème")
	check(logHas("BB_StoreInfo.HP doit être un TextLabel (trouvé : Frame)", "WARN", "server"), "HP en Frame : problème (TextLabel, L-044)")
	check(kind == "WARN" and string.find(text, "Contrat : 2 problème(s) · 2 avertissement(s)", 1, true) ~= nil, `« {text} »`)
	fakeHP:Destroy()
	hp.Parent = labelOf(t, "Stats")
	speed.Name = "Speed"

	-- BB_StoreInfo absent : pas encore livré.
	t.Parent = nil
	run()
	text, kind = summary()
	check(logHas("[Contrat] Billboards · BB_StoreInfo absent : billboard pas encore livré", "PRINT", "server"), "BB_StoreInfo absent : « pas encore livré »")
	check(kind == "PRINT" and string.find(text, "Contrat : OK · 2 avertissement(s)", 1, true) ~= nil, `toujours OK : « {text} »`)
	t.Parent = AssetsUI
end

---------------------------------------------------------------- bilan
summary()
