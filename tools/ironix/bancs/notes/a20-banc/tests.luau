---------------------------------------------------------------- bouchons des voisins
-- ProfileStore : session ouverte après une image (comme un vrai appel DataStore, les autres
-- PlayerAdded passent d'abord), données = modèle + PRESETS[clé] (sauvegarde existante). PROFILES
-- garde chaque profil ouvert, pour simuler un profil pas encore chargé (active = false).
PROFILES = {}
PRESETS = {}
SOURCES["stub/ProfileStore"] = [==[
local ProfileStore = { DataStoreState = "NoInternet", IsClosing = false }
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in t do c[k] = deepCopy(v) end
	return c
end
function ProfileStore.New(_name, template)
	local store = {}
	function store.StartSessionAsync(_self, key, _params)
		task.wait()
		local data = deepCopy(template)
		for k, v in PRESETS[key] or {} do data[k] = deepCopy(v) end
		local profile = { Data = data, Key = key, active = true }
		function profile.IsActive(self) return self.active end
		function profile.Reconcile(_self) end
		function profile.EndSession(self) self.active = false end
		function profile.AddUserId(_self, _id) end
		profile.OnSessionEnd = { Connect = function() return { Disconnect = function() end } end }
		PROFILES[key] = profile
		return profile
	end
	return store
end
return ProfileStore
]==]

---------------------------------------------------------------- montage de la place
local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end

local server = folder(ServerScriptService, "Server")
local services = folder(server, "Services")
moduleScript(folder(server, "Packages"), "ProfileStore", "stub/ProfileStore")
local dataModule = moduleScript(services, "DataService", "server/Services/DataService.luau")
local statsModule = moduleScript(services, "StatsService", "server/Services/StatsService.luau")
local toolModule = moduleScript(services, "ToolService", "server/Services/ToolService.luau")
local cosmeticModule = moduleScript(services, "CosmeticService", "server/Services/CosmeticService.luau")

local controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local cosCtrlModule = moduleScript(controllers, "CosmeticController", "client/Controllers/CosmeticController.luau")
local shopCtrlModule = moduleScript(controllers, "AuraShopController", "client/Controllers/AuraShopController.luau")

---------------------------------------------------------------- aides
local function new(class, props, parent)
	local inst = InstanceAPI.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function logCount(pattern, kind)
	local n = 0
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end

local function hasTag(inst, tag)
	return tagsOf[inst] ~= nil and tagsOf[inst][tag] == true
end

local function makeCharacter(player, position)
	local character = new("Model", { Name = player.Name })
	local root = new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(position.X, position.Y, position.Z) }, character)
	new("Humanoid", { Name = "Humanoid" }, character)
	character.Parent = Workspace
	player.Character = character
	return character, root
end

local function aurasOf(character)
	local out = {}
	for _, child in character:GetChildren() do
		if child.Name == "CosmeticAura" then
			table.insert(out, child)
		end
	end
	return out
end

local function trailsOf(root)
	local n = 0
	for _, child in root:GetChildren() do
		if child.ClassName == "Trail" then
			n += 1
		end
	end
	return n
end

local function scriptsIn(root)
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			return true
		end
	end
	return false
end

local function rowsOf(gui)
	local list = gui:FindFirstChild("List", true)
	local out = {}
	for _, child in list:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Item_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

local function rowOf(gui, id)
	return gui:FindFirstChild("List", true):FindFirstChild("Item_" .. id)
end

local function field(row, name)
	return row:FindFirstChild(name, true)
end

-- Écran gris de Clément tel qu'on l'imagine (UI-003 pas encore livré). grey = version la plus
-- simple : onglets en Frame, EquipButton qui porte son texte ; sinon version habillée : onglets en
-- boutons à label, Price dans BuyButton, EquipButton sans texte avec un TextLabel.
local function makeAuraShop(parent, grey)
	local gui = new("ScreenGui", { Name = "UI_AuraShop", Enabled = true, ResetOnSpawn = true })
	local window = new("Frame", { Name = "Window" }, gui)
	new("TextButton", { Name = "CloseButton", Text = "X" }, window)
	local tabs = new("Frame", { Name = "Tabs" }, window)
	if grey then
		new("Frame", { Name = "AurasTab" }, tabs)
		new("Frame", { Name = "TrailsTab" }, tabs)
	else
		new("TextLabel", { Name = "TabLabel", Text = "AURAS" }, new("TextButton", { Name = "AurasTab", Text = "" }, tabs))
		new("TextLabel", { Name = "TabLabel", Text = "TRAILS" }, new("TextButton", { Name = "TrailsTab", Text = "" }, tabs))
	end
	local list = new("ScrollingFrame", { Name = "List" }, window)
	local template = new("Frame", { Name = "Template", Visible = false }, list)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://9" }, template)
	new("TextLabel", { Name = "ItemName", Text = if grey then "Aura name" else "AURA NAME" }, template)
	new("TextLabel", { Name = "Bonus", Text = "x1 power" }, template)
	if grey then
		new("TextLabel", { Name = "Price", Text = "$0" }, template)
		new("TextButton", { Name = "BuyButton", Text = "Buy" }, template)
		new("TextButton", { Name = "EquipButton", Text = "Equip" }, template)
	else
		new("TextLabel", { Name = "Price", Text = "$0" }, new("TextButton", { Name = "BuyButton", Text = "" }, template))
		new("TextLabel", { Name = "Label", Text = "EQUIP" }, new("TextButton", { Name = "EquipButton", Text = "" }, template))
	end
	gui.Parent = parent
	return gui
end

---------------------------------------------------------------- démarrage
local P1 = new("Player", { Name = "Alice", UserId = 101, DisplayName = "Alice" })
local char1, root1 = makeCharacter(P1, Vector3.new(-14, 3, -20)) -- devant le comptoir de la boutique d'auras
local playerGui = new("PlayerGui", { Name = "PlayerGui" }, P1)
P1.Parent = Players

-- Comptoir de la greybox (tools/greybox.luau, buildCounter) : Model AuraShop taggé, PrimaryPart Counter.
local shops = new("Folder", { Name = "Shops" }, Workspace)
local counterModel = new("Model", { Name = "AuraShop" })
local counterPart = new("Part", { Name = "Counter", CFrame = CFrame.new(-14, 2, -24) }, counterModel)
counterModel.PrimaryPart = counterPart
counterModel.Parent = shops
addTag(counterModel, "AuraShop")

local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Cosmetics = requireModule(ReplicatedStorage.Shared.Config.Cosmetics, "server")
local DataService = requireModule(dataModule, "server")
local StatsService = requireModule(statsModule, "server")
local ToolService = requireModule(toolModule, "server")
local CosmeticService = requireModule(cosmeticModule, "server")
-- Ordre du Loader : DataService (1), StatsService (10), puis par nom à 100.
DataService.Init()
StatsService.Init()
CosmeticService.Init()
ToolService.Init()
step(0.1)

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local CAMERA_AT = Vector3.new(-14, 8, -8)
setCamera(CAMERA_AT)
local CosCtrl = requireModule(cosCtrlModule, "client")
local ShopCtrl = requireModule(shopCtrlModule, "client")
taskLib.spawn(CosCtrl.Start)
taskLib.spawn(ShopCtrl.Start)
step(0.1)
local NetC = requireModule(ReplicatedStorage.Shared.Net.Net, "client")

-- Un envoi toutes les 0.3 s : Net n'en accepte que 4 par seconde glissante (Definitions).
local function equipRemote(id)
	NetC.Client.EquipCosmetic:Fire(id)
	step(0.3)
end

local data1 = DataService.Get(P1)
local hum1 = char1.Humanoid

print("\n== A. Config/Cosmetics")
do
	local expectA = { { "Spark", 1.5, 500 }, { "Flame", 2, 15000 }, { "Lightning", 3, 400000 }, { "Plasma", 5, 10e6 }, { "Galaxy", 8, 250e6 }, { "Royal", 11, 3e9 } }
	local okA = #Cosmetics.Auras == 6
	for i, e in expectA do
		local a = Cosmetics.Auras[i]
		okA = okA and a.Id == e[1] and a.Multiplier == e[2] and a.Price == e[3] and a.Kind == "Aura" and a.Order == i
	end
	check(okA, "A1 6 auras de 7.4 : Spark ×1.5 $500 … Royal ×11 $3B, dans l'ordre des paliers")
	local expectT = { { "Dust", 1.1, 300 }, { "Wind", 1.25, 10000 }, { "Turbo", 1.4, 300000 }, { "Comet", 1.6, 8e6 }, { "Hyperspace", 1.8, 200e6 } }
	local okT = #Cosmetics.Trails == 5
	for i, e in expectT do
		local t = Cosmetics.Trails[i]
		okT = okT and t.Id == e[1] and t.Multiplier == e[2] and t.Price == e[3] and t.Kind == "Trail" and t.Order == i
	end
	check(okT, "A2 5 trails de 7.4 : Dust ×1.1 $300 … Hyperspace ×1.8 $200M")
	local okC = true
	for id, def in Cosmetics.ById do
		local prefix = if def.Kind == "Aura" then "FX_Aura_" else "FX_Trail_"
		okC = okC and def.Id == id and type(def.Color) == "table" and def.Color.R ~= nil and string.sub(def.Texture, 1, #prefix) == prefix
	end
	check(okC, "A3 chaque objet a sa couleur V0 et un nom de texture FX_Aura_… / FX_Trail_…")
	check(Cosmetics.RemoteParticleCutDistance == 60 and Cosmetics.RemoteParticleCutFactor == 0.5 and Cosmetics.RemoteParticleCheckInterval == 0.5, "A4 5.10 : moitié au-delà de 60 studs, mesure toutes les 0.5 s (V0)")
	check(not pcall(function()
		Cosmetics.Auras[1].Price = 1
	end), "A5 Config gelée")
end

print("\n== B. Possession : Grant et Owns")
do
	check(data1 ~= nil, "B0 profil d'Alice chargé")
	check(P1:GetAttribute("OwnedCosmetics") == "" and P1:GetAttribute("EquippedAura") == nil and P1:GetAttribute("EquippedTrail") == nil, "B1 au chargement : rien de possédé ni d'équipé")
	check(P1:GetAttribute("Damage") == 1 and hum1.WalkSpeed == 16, "B2 Damage 1 et WalkSpeed 16 au chargement (poings, stats à 0, rien d'équipé)")
	check(not CosmeticService.Owns(P1, "Spark"), "B3 Spark pas possédé au départ")
	check(CosmeticService.Grant(P1, "Spark") and CosmeticService.Owns(P1, "Spark"), "B4 Grant(Spark) : possédé")
	check(table.find(data1.Cosmetics.Auras, "Spark") ~= nil and #data1.Cosmetics.Auras == 1, "B5 sauvé dans Cosmetics.Auras")
	check(P1:GetAttribute("OwnedCosmetics") == "Spark", "B6 attribut OwnedCosmetics = « Spark »")
	check(data1.Cosmetics.EquippedAura == nil and P1:GetAttribute("EquippedAura") == nil and P1:GetAttribute("Damage") == 1, "B7 Grant n'équipe pas")
	check(CosmeticService.Grant(P1, "Spark") and #data1.Cosmetics.Auras == 1, "B8 Grant d'un objet déjà possédé : true, sans doublon")
	check(not CosmeticService.Grant(P1, "Unicorn") and not CosmeticService.Grant(P1, 42) and not CosmeticService.Grant(P1, nil), "B9 Id inconnu ou pas une chaîne : false")
	check(CosmeticService.Grant(P1, "Dust") and table.find(data1.Cosmetics.Trails, "Dust") ~= nil and P1:GetAttribute("OwnedCosmetics") == "Spark,Dust", "B10 Grant(Dust) : dans Cosmetics.Trails, attribut « Spark,Dust »")
	check(CosmeticService.Owns(P1, "Dust") and not CosmeticService.Owns(P1, "Flame"), "B11 Owns : Dust oui, Flame non")
	local ghost = new("Player", { Name = "Ghost", UserId = 999 })
	check(not CosmeticService.Grant(ghost, "Spark") and not CosmeticService.Owns(ghost, "Spark") and CosmeticService.GetAuraMultiplier(ghost) == 1 and CosmeticService.GetTrailMultiplier(ghost) == 1, "B12 profil pas chargé : Grant false, Owns false, multiplicateurs 1")
	check(#aurasOf(char1) == 0 and trailsOf(root1) == 0, "B13 aucun effet tant que rien n'est équipé")
end

print("\n== C. EquipCosmetic : équiper, changer, retirer ; multiplicateurs")
do
	clearLog()
	table.clear(REMOTE_LOG)
	equipRemote("Flame")
	local n = remotes("Notify")
	check(#n == 1 and n[1].to == P1 and n[1].args[1] == "You don't own the Flame aura yet: buy it first." and n[1].args[2] == "Warning", "C1 Flame pas possédé : Notify en anglais")
	check(data1.Cosmetics.EquippedAura == nil and P1:GetAttribute("Damage") == 1, "C2 rien d'équipé")
	equipRemote("Spark")
	check(data1.Cosmetics.EquippedAura == "Spark" and P1:GetAttribute("EquippedAura") == "Spark", "C3 Spark équipée : profil et attribut")
	check(near(P1:GetAttribute("Damage"), 1.5) and near(ToolService.GetHitDamage(P1), 1.5), "C4 Damage = 1 × (1 + 0/100) × 1.5 = 1.5 (attribut du HUD et GetHitDamage)")
	local list = aurasOf(char1)
	check(#list == 1 and list[1]:GetAttribute("CosmeticId") == "Spark", "C5 une pièce CosmeticAura (Spark) sur le perso")
	CosmeticService.Grant(P1, "Flame")
	equipRemote("Flame")
	list = aurasOf(char1)
	check(data1.Cosmetics.EquippedAura == "Flame" and P1:GetAttribute("EquippedAura") == "Flame" and near(P1:GetAttribute("Damage"), 2), "C6 Flame remplace Spark : Damage 2")
	check(#list == 1 and list[1]:GetAttribute("CosmeticId") == "Flame", "C7 une seule aura : l'ancienne est retirée")
	equipRemote("Flame")
	check(data1.Cosmetics.EquippedAura == nil and P1:GetAttribute("EquippedAura") == nil and P1:GetAttribute("Damage") == 1 and #aurasOf(char1) == 0, "C8 renvoyer Flame l'enlève : Damage 1, plus d'aura")

	StatsService.AddSpeed(P1, 400)
	check(near(hum1.WalkSpeed, 36) and near(P1:GetAttribute("WalkSpeed"), 36), "C9 Vitesse 400 sans trail : 16 + 0.05 × 400 = 36")
	equipRemote("Dust")
	check(near(hum1.WalkSpeed, 38) and near(P1:GetAttribute("WalkSpeed"), 38) and P1:GetAttribute("EquippedTrail") == "Dust", "C10 Dust ×1.1 : 16 + 0.05 × 400 × 1.1 = 38")
	local trail = root1:FindFirstChild("CosmeticTrail")
	check(trail ~= nil and trail.ClassName == "Trail" and trail:GetAttribute("CosmeticId") == "Dust" and trailsOf(root1) == 1, "C11 trail Dust posé sur le HumanoidRootPart")
	equipRemote("Spark")
	check(#aurasOf(char1) == 1 and trailsOf(root1) == 1 and near(P1:GetAttribute("Damage"), 1.5) and near(hum1.WalkSpeed, 38), "C12 aura et trail indépendants : Spark + Dust")
	CosmeticService.Grant(P1, "Wind")
	equipRemote("Wind")
	check(near(hum1.WalkSpeed, 41) and trailsOf(root1) == 1 and root1.CosmeticTrail:GetAttribute("CosmeticId") == "Wind" and #root1:GetChildren() == 3, "C13 Wind ×1.25 remplace Dust : 41, un seul trail et ses deux Attachments")
	StatsService.SetSpeedModifier(P1, "Carry", 0.9)
	check(near(hum1.WalkSpeed, 36.9) and near(P1:GetAttribute("WalkSpeed"), 41), "C14 colis porté ×0.9 par-dessus : 36.9 (attribut WalkSpeed 41, sans le malus)")
	StatsService.SetSpeedModifier(P1, "Carry", nil)
	equipRemote("Wind")
	check(near(hum1.WalkSpeed, 36) and P1:GetAttribute("EquippedTrail") == nil and data1.Cosmetics.EquippedTrail == nil and trailsOf(root1) == 0 and #root1:GetChildren() == 0, "C15 renvoyer Wind l'enlève : 36, trail et Attachments retirés")

	ToolService.Grant(P1, "Hammer")
	ToolService.Equip(P1, "Hammer")
	StatsService.AddStrength(P1, 100)
	step(0.05)
	equipRemote("Flame")
	check(near(P1:GetAttribute("Damage"), 80) and near(ToolService.GetHitDamage(P1), 80), "C16 exemple 7.1 : Marteau 20 × Force 100 (×2) × Flame ×2 = 80")
	CosmeticService.Grant(P1, "Hyperspace")
	StatsService.AddSpeed(P1, 600)
	equipRemote("Hyperspace")
	check(near(hum1.WalkSpeed, 70) and near(P1:GetAttribute("WalkSpeed"), 70), "C17 Hyperspace ×1.8 et Vitesse 1 000 : 106 plafonné à 70")
	check(CosmeticService.GetEquippedId(P1, "Aura") == "Flame" and CosmeticService.GetEquippedId(P1, "Trail") == "Hyperspace", "C18 GetEquippedId")
	check(CosmeticService.GetAuraMultiplier(P1) == 2 and CosmeticService.GetTrailMultiplier(P1) == 1.8, "C19 GetAuraMultiplier 2, GetTrailMultiplier 1.8")
	clearLog()
	check(CosmeticService.Equip(P1, "Flame") and logCount("équipé", "PRINT") == 0, "C20 Equip (API) de l'objet déjà équipé : true, rien ne change")
	check(CosmeticService.Equip(P1, "Spark") and P1:GetAttribute("EquippedAura") == "Spark" and near(P1:GetAttribute("Damage"), 60), "C21 Equip (API) : Spark, Damage 20 × 2 × 1.5 = 60")
	check(not CosmeticService.Equip(P1, "Royal") and not CosmeticService.Equip(P1, "Nope"), "C22 Equip (API) : pas possédé ou inconnu → false")
	check(CosmeticService.Unequip(P1, "Trail") and P1:GetAttribute("EquippedTrail") == nil and near(hum1.WalkSpeed, 66), "C23 Unequip(Trail) : 16 + 0.05 × 1 000 = 66")
	check(not CosmeticService.Unequip(P1, "Hat") and CosmeticService.Unequip(P1, "Trail"), "C24 Unequip : type inconnu → false ; rien à retirer → true")
	check(logHas("[CosmeticService] Alice : aura Spark équipé(e), ×1.5", "PRINT") and logHas("[CosmeticService] Alice : trail retiré(e)", "PRINT"), "C25 une ligne de sortie par changement, en Studio")
end

print("\n== D. Envois malformés, débit, profil pas chargé")
do
	local raw = ReplicatedStorage.Remotes.EquipCosmetic
	step(1.1)
	clearLog()
	table.clear(REMOTE_LOG)
	for _, args in { { 123 }, { "" }, { string.rep("a", 65) }, {}, { "Spark", "extra" } } do
		raw:FireServer(table.unpack(args))
		step(0.3)
	end
	check(data1.Cosmetics.EquippedAura == "Spark" and #remotes("Notify") == 0, "D1 nombre, chaîne vide, trop longue, sans argument, argument en trop : ignorés, rien ne change")
	check(logCount("EquipCosmetic refusé", "WARN") == 5, "D2 cinq refus de Net écrits dans la sortie (Studio)")
	clearLog()
	raw:FireServer("Unicorn")
	step(0.05)
	check(logCount("« Unicorn » inconnu", "WARN") == 1 and #remotes("Notify") == 0 and data1.Cosmetics.EquippedAura == "Spark", "D3 Id inconnu : une ligne de sortie, pas de Notify, rien ne change")
	step(1.1)
	clearLog()
	for _ = 1, 5 do
		raw:FireServer("Flame")
	end
	step(0.05)
	check(data1.Cosmetics.EquippedAura == nil and logCount("RateLimit", "WARN") == 1, "D4 5 envois d'un coup : 4 traités (Flame, retrait, Flame, retrait), le 5e coupé par le débit de Net")
	step(1.1)
	PROFILES["Player_101"].active = false
	table.clear(REMOTE_LOG)
	equipRemote("Spark")
	local n = remotes("Notify")
	check(#n == 1 and n[1].args[1] == "Your save is still loading. Try again in a moment.", "D5 profil pas chargé : Notify « save is still loading »")
	check(CosmeticService.GetAuraMultiplier(P1) == 1 and not CosmeticService.Equip(P1, "Spark"), "D6 profil pas chargé : multiplicateur 1, Equip false")
	PROFILES["Player_101"].active = true
	equipRemote("Spark")
	check(data1.Cosmetics.EquippedAura == "Spark", "D7 profil revenu : Spark équipée")
end

print("\n== E. Sauvegarde : Id inconnu, mauvais type, pas possédé")
do
	data1.Cosmetics.EquippedAura = "Nebula" -- aura d'une version plus récente du jeu
	table.insert(data1.Cosmetics.Auras, "Nebula")
	check(CosmeticService.GetAuraMultiplier(P1) == 1 and CosmeticService.GetEquippedId(P1, "Aura") == nil, "E1 aura inconnue de Config : multiplicateur 1, rien d'équipé")
	data1.Cosmetics.EquippedAura = "Royal"
	check(CosmeticService.GetAuraMultiplier(P1) == 1, "E2 aura enregistrée mais pas possédée : multiplicateur 1")
	data1.Cosmetics.EquippedAura = "Dust"
	check(CosmeticService.GetAuraMultiplier(P1) == 1 and CosmeticService.GetEquippedId(P1, "Aura") == nil, "E3 trail rangé dans EquippedAura : ignoré")
	table.insert(data1.Cosmetics.Trails, "Plasma")
	check(not CosmeticService.Owns(P1, "Plasma"), "E4 aura rangée dans Cosmetics.Trails : pas possédée")
	table.remove(data1.Cosmetics.Trails, table.find(data1.Cosmetics.Trails, "Plasma"))
	check(CosmeticService.Unequip(P1, "Aura") and data1.Cosmetics.EquippedAura == nil and table.find(data1.Cosmetics.Auras, "Nebula") ~= nil, "E5 Unequip efface l'Id ; Nebula reste possédé (on ne retire jamais un achat)")
	check(P1:GetAttribute("OwnedCosmetics") == "Spark,Flame,Dust,Wind,Hyperspace", "E6 OwnedCosmetics sans l'Id inconnu")
	CosmeticService.Equip(P1, "Spark")
end

print("\n== F. Chargement d'une sauvegarde : Bob avec Galaxy et Comet")
PRESETS["Player_202"] = {
	Stats = { Speed = 200, Strength = 50 },
	Cosmetics = { Auras = { "Spark", "Galaxy", "Nebula" }, Trails = { "Comet" }, EquippedAura = "Galaxy", EquippedTrail = "Comet" },
}
local P2 = new("Player", { Name = "Bob", UserId = 202, DisplayName = "Bob" })
local char2, root2 = makeCharacter(P2, Vector3.new(-14, 3, -100)) -- à 92 studs de la caméra d'Alice
P2.Parent = Players
Players.PlayerAdded:Fire(P2)
step(0.1)
do
	check(P2:GetAttribute("EquippedAura") == "Galaxy" and P2:GetAttribute("EquippedTrail") == "Comet", "F1 attributs posés au chargement")
	check(P2:GetAttribute("OwnedCosmetics") == "Spark,Galaxy,Comet" and table.find(DataService.Get(P2).Cosmetics.Auras, "Nebula") ~= nil, "F2 OwnedCosmetics sans Nebula, qui reste dans la sauvegarde")
	check(near(P2:GetAttribute("Damage"), 12), "F3 Damage au chargement : 1 × (1 + 50/100) × Galaxy 8 = 12")
	check(near(char2.Humanoid.WalkSpeed, 32) and near(P2:GetAttribute("WalkSpeed"), 32), "F4 WalkSpeed au chargement : 16 + 0.05 × 200 × Comet 1.6 = 32")
	local list = aurasOf(char2)
	check(#list == 1 and list[1]:GetAttribute("CosmeticId") == "Galaxy" and trailsOf(root2) == 1 and root2.CosmeticTrail:GetAttribute("CosmeticId") == "Comet", "F5 aura Galaxy et trail Comet posés au chargement")
	check(logHas("[CosmeticService] Bob : aura Galaxy, trail Comet", "PRINT"), "F6 ligne de sortie au chargement d'objets équipés")
end

print("\n== G. Effets : pièce d'aura, paliers, trail, textures")
do
	local aura = aurasOf(char2)[1]
	check(aura.ClassName == "Part" and aura.Transparency == 1 and not aura.CanCollide and not aura.CanQuery and not aura.CanTouch and aura.Massless and not aura.CastShadow and not aura.Anchored, "G1 pièce d'aura invisible, sans collision, contact, requête, masse ni ombre")
	local weld = aura:FindFirstChildOfClass("WeldConstraint")
	check(weld ~= nil and weld.Part0 == root2 and weld.Part1 == aura and near(aura.Position.Y, root2.Position.Y - 0.5), "G2 soudée au HumanoidRootPart, centrée 0.5 stud dessous")
	check(hasTag(aura, "CosmeticAura") and aura.Parent == char2, "G3 dans le personnage, avec le tag de code CosmeticAura")
	local particles, sparks, light = aura:FindFirstChild("AuraParticles"), aura:FindFirstChild("AuraSparks"), aura:FindFirstChild("AuraLight")
	check(particles and particles:GetAttribute("FullRate") == 26 and sparks and sparks:GetAttribute("FullRate") == 12 and light and light.ClassName == "PointLight", "G4 Galaxy : particules 26/s, étincelles 12/s, lumière")
	local galaxy = Cosmetics.ById.Galaxy.Color
	check(sameColor(light.Color, galaxy) and sameColor(particles.Color.Keypoints[1].Value, galaxy) and particles.LockedToPart and particles.LightEmission == 1, "G5 couleur du palier sur la lumière et les particules, particules qui suivent le perso")
	check(particles.Texture == "rbxasset://textures/particles/sparkles_main.dds", "G6 texture V0 tant que FX_Aura_Galaxie manque")
	check(logCount("texture FX_Aura_Galaxie pas encore livrée", "PRINT") == 1, "G7 une seule ligne de sortie par texture manquante")
	local top, bottom, trail = root2:FindFirstChild("CosmeticTrailTop"), root2:FindFirstChild("CosmeticTrailBottom"), root2:FindFirstChild("CosmeticTrail")
	check(top and bottom and trail.Attachment0 == top and trail.Attachment1 == bottom and top.Position.Y > bottom.Position.Y and top.Position.Z > 0 and bottom.Position.Z > 0, "G8 trail entre deux Attachments, dans le dos (+Z)")
	check(trail.Texture == "" and sameColor(trail.Color.Keypoints[1].Value, Cosmetics.ById.Comet.Color) and not trail.FaceCamera, "G9 trail V0 : ruban uni à la couleur du palier")
	check(not scriptsIn(char1) and not scriptsIn(char2), "G10 aucun script dans les personnages")

	-- Tous les paliers, sur une troisième joueuse sans client.
	local P3 = new("Player", { Name = "Cara", UserId = 303 })
	local char3, root3 = makeCharacter(P3, Vector3.new(300, 3, 300))
	P3.Parent = Players
	Players.PlayerAdded:Fire(P3)
	step(0.1)
	local rates, lights, ranges, sizes, sparkRates, single = {}, {}, {}, {}, {}, true
	for _, def in Cosmetics.Auras do
		CosmeticService.Grant(P3, def.Id)
		CosmeticService.Equip(P3, def.Id)
		local list = aurasOf(char3)
		single = single and #list == 1 and list[1]:GetAttribute("CosmeticId") == def.Id
		local part = list[1]
		table.insert(rates, part.AuraParticles:GetAttribute("FullRate"))
		table.insert(lights, part.AuraLight.Brightness)
		table.insert(ranges, part.AuraLight.Range)
		table.insert(sizes, part.AuraParticles.Size.Keypoints[1].Value)
		local s = part:FindFirstChild("AuraSparks")
		table.insert(sparkRates, if s then s:GetAttribute("FullRate") else 0)
	end
	local function increasing(t)
		for i = 2, #t do
			if not (t[i] > t[i - 1]) then
				return false
			end
		end
		return true
	end
	check(single, "G11 chaque palier : une seule aura à la fois")
	check(increasing(rates) and increasing(lights) and increasing(ranges) and increasing(sizes), "G12 plus spectaculaire à chaque palier : débit, taille, éclat et portée de la lumière croissants")
	check(sparkRates[1] == 0 and sparkRates[2] == 0 and sparkRates[3] > 0 and increasing({ table.unpack(sparkRates, 3) }), "G13 étincelles à partir du palier 3 (Lightning), de plus en plus nombreuses")
	local lifetimes, heights, glows = {}, {}, {}
	for _, def in Cosmetics.Trails do
		CosmeticService.Grant(P3, def.Id)
		CosmeticService.Equip(P3, def.Id)
		local t = root3.CosmeticTrail
		table.insert(lifetimes, t.Lifetime)
		table.insert(heights, root3.CosmeticTrailTop.Position.Y - root3.CosmeticTrailBottom.Position.Y)
		table.insert(glows, t.LightEmission)
	end
	check(increasing(lifetimes) and increasing(heights) and increasing(glows) and trailsOf(root3) == 1, "G14 trails : plus longs, plus hauts, plus lumineux à chaque palier ; un seul à la fois")

	-- Textures de Clément (MOD-045) : Decals dans ReplicatedStorage/Assets, sous-dossiers compris.
	local assets = ReplicatedStorage:FindFirstChild("Assets") or new("Folder", { Name = "Assets" }, ReplicatedStorage)
	local fx = new("Folder", { Name = "FX" }, assets)
	new("Decal", { Name = "FX_Aura_Foudre", Texture = "rbxassetid://1001" }, fx)
	new("Decal", { Name = "FX_Trail_Vent", Texture = "rbxassetid://2002" }, new("Folder", { Name = "Trails" }, fx))
	new("Decal", { Name = "FX_Aura_Plasma", Texture = "" }, fx) -- Decal posé sans image
	CosmeticService.Equip(P3, "Lightning")
	CosmeticService.Equip(P3, "Wind")
	local part = aurasOf(char3)[1]
	check(part.AuraParticles.Texture == "rbxassetid://1001" and part.AuraSparks.Texture == "rbxassetid://1001", "G15 texture de Clément (Decal FX_Aura_Foudre dans Assets/FX) sur les particules et les étincelles")
	check(root3.CosmeticTrail.Texture == "rbxassetid://2002", "G16 texture du trail trouvée dans un sous-dossier (FX_Trail_Vent)")
	CosmeticService.Equip(P3, "Plasma")
	check(aurasOf(char3)[1].AuraParticles.Texture == "rbxasset://textures/particles/sparkles_main.dds", "G17 Decal sans image : texture V0")
end

print("\n== H. Mort et réapparition")
do
	-- Alice : Spark et aucun trail ; on lui remet Wind.
	CosmeticService.Equip(P1, "Wind")
	hum1.Health = 0
	hum1.Died:Fire()
	step(0.05)
	check(#aurasOf(char1) == 0 and trailsOf(root1) == 0 and #root1:GetChildren() == 0, "H1 à la mort : aura, trail et Attachments retirés")
	CosmeticService.Equip(P1, "Flame")
	check(#aurasOf(char1) == 0 and data1.Cosmetics.EquippedAura == "Flame", "H2 changement pendant la mort : enregistré, rien sur le corps")
	local newChar, newRoot = makeCharacter(P1, Vector3.new(-14, 3, -20))
	P1.CharacterAdded:Fire(newChar)
	step(0.1)
	local list = aurasOf(newChar)
	check(#list == 1 and list[1]:GetAttribute("CosmeticId") == "Flame" and trailsOf(newRoot) == 1 and newRoot.CosmeticTrail:GetAttribute("CosmeticId") == "Wind", "H3 nouvelle apparition : aura Flame et trail Wind recréés")
	check(near(newChar.Humanoid.WalkSpeed, math.min(70, 16 + 0.05 * 1000 * 1.25)) and near(P1:GetAttribute("Damage"), 80), "H4 nouveau Humanoid : WalkSpeed 70 (plafond), Damage 80")
	-- HumanoidRootPart arrivé en retard (WaitForChild).
	local late = new("Model", { Name = "Alice" })
	new("Humanoid", { Name = "Humanoid" }, late)
	late.Parent = Workspace
	P1.Character = late
	P1.CharacterAdded:Fire(late)
	step(0.5)
	check(#aurasOf(late) == 0, "H5 pas encore de HumanoidRootPart : rien")
	local lateRoot = new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(-14, 3, -20) }, late)
	step(0.1)
	check(#aurasOf(late) == 1 and trailsOf(lateRoot) == 1, "H6 HumanoidRootPart arrivé : effets posés")
	check(#aurasOf(newChar) == 1, "H7 l'ancien perso n'est pas touché (le serveur le détruit)")
	char1, root1, hum1 = late, lateRoot, late.Humanoid
end

print("\n== I. Auras lointaines des autres joueurs (CosmeticController)")
do
	step(0.6)
	local aura = aurasOf(char2)[1]
	local p, s = aura.AuraParticles, aura.AuraSparks
	check(near(p.Rate, 13) and near(s.Rate, 6), "I1 Bob à 92 studs : moitié des particules (26 → 13, 12 → 6)")
	aura.CFrame = CFrame.new(-14, 2.5, -40) -- Bob s'approche (la soudure n'est pas simulée : on déplace l'aura)
	step(0.6)
	check(near(p.Rate, 26) and near(s.Rate, 12), "I2 Bob à 32 studs : débit plein")
	aura.CFrame = CFrame.new(-14, 8, -68)
	step(0.6)
	check(near(p.Rate, 26), "I3 à 60 studs pile : pas de réduction (au-delà seulement)")
	aura.CFrame = CFrame.new(-14, 8, -68.5)
	step(0.6)
	check(near(p.Rate, 13), "I4 à 60.5 studs : réduite")
	setCamera(Vector3.new(500, 8, 500))
	step(0.6)
	local own = aurasOf(char1)[1].AuraParticles
	check(near(own.Rate, own:GetAttribute("FullRate")) and near(p.Rate, 13), "I5 caméra loin : l'aura d'Alice (la sienne) n'est jamais réduite")
	setCamera(CAMERA_AT)
	CosmeticService.Unequip(P2, "Aura")
	step(0.6)
	CosmeticService.Equip(P2, "Spark")
	local fresh = aurasOf(char2)[1]
	fresh.CFrame = CFrame.new(-14, 2.5, -100)
	step(0.6)
	check(near(fresh.AuraParticles.Rate, 4) and fresh.AuraParticles:GetAttribute("FullRate") == 8, "I6 aura retirée puis recréée : suivie, réduite au loin (8 → 4), FullRate intact")
	check(near(root2.CosmeticTrail.Lifetime, 0.6), "I7 le trail n'est pas touché")
end

print("\n== J. Boutique sans écran (UI-003 pas livré)")
local prompt = counterPart:FindFirstChild("AuraShopPrompt")
do
	check(prompt ~= nil and prompt.ClassName == "ProximityPrompt" and prompt.ActionText == "Shop" and prompt.ObjectText == "Aura Shop", "J1 invite « Shop » · « Aura Shop » sur le comptoir taggé AuraShop (PrimaryPart)")
	check(prompt.MaxActivationDistance == 10 and prompt.RequiresLineOfSight == false and prompt.HoldDuration == 0, "J2 portée 10, sans ligne de vue, sans maintien")
	clearLog()
	local fails = FAILS
	prompt.Triggered:Fire(P1)
	step(0.05)
	prompt.Triggered:Fire(P1)
	step(0.05)
	check(logCount("UI_AuraShop absent de PlayerGui", "PRINT") == 1 and FAILS == fails, "J3 deux déclenchements sans écran : une seule ligne dans la sortie, aucune erreur")
end

print("\n== K. Boutique avec un écran habillé")
local shopGui = makeAuraShop(playerGui, false)
step(0.05)
do
	-- Alice : auras Spark, Flame (équipée), Nebula ; trails Dust, Wind (équipé), Hyperspace.
	check(shopGui.Enabled == false, "K1 écran arrivé dans PlayerGui : branché et fermé")
	prompt.Triggered:Fire(P1)
	step(0.05)
	local rows = rowsOf(shopGui)
	check(shopGui.Enabled and #rows == 6, "K2 invite : écran ouvert, 6 lignes d'auras")
	local names, prices, bonuses, orders = {}, {}, {}, {}
	for _, row in rows do
		table.insert(names, field(row, "ItemName").Text)
		table.insert(prices, field(row, "Price").Text)
		table.insert(bonuses, field(row, "Bonus").Text)
		table.insert(orders, row.LayoutOrder)
	end
	check(table.concat(names, ",") == "SPARK,FLAME,LIGHTNING,PLASMA,GALAXY,ROYAL" and table.concat(orders, ",") == "1,2,3,4,5,6", "K3 lignes dans l'ordre des paliers (LayoutOrder 1 à 6), noms anglais en capitales comme le texte d'exemple « AURA NAME »")
	check(table.concat(prices, " ") == "$500 $15K $400K $10M $250M $3B", "K4 Price au format du HUD : $500 $15K $400K $10M $250M $3B")
	check(table.concat(bonuses, " | ") == "×1.5 power | ×2 power | ×3 power | ×5 power | ×8 power | ×11 power", "K5 Bonus : ×1.5 power … ×11 power")
	local template = shopGui:FindFirstChild("Template", true)
	local templates = 0
	for _, d in shopGui:GetDescendants() do
		if d.Name == "Template" then
			templates += 1
		end
	end
	check(templates == 1 and template.Visible == false and field(template, "ItemName").Text == "AURA NAME", "K6 Template intact, invisible et seul de son nom")
	local function state(id)
		local row = rowOf(shopGui, id)
		return field(row, "BuyButton").Visible, field(row, "EquipButton").Visible, field(field(row, "EquipButton"), "Label").Text
	end
	local b1, e1, l1 = state("Spark")
	local b2, e2, l2 = state("Flame")
	local b3, e3 = state("Lightning")
	check(not b1 and e1 and not b2 and e2 and b3 and not e3, "K7 possédés (Spark, Flame) : EquipButton ; les autres : BuyButton")
	check(l1 == "EQUIP" and l2 == "UNEQUIP" and field(rowOf(shopGui, "Flame"), "EquipButton").Text == "", "K8 Flame équipée : « UNEQUIP » dans le label du bouton habillé (exemple « EQUIP »), « EQUIP » ailleurs")
	field(rowOf(shopGui, "Spark"), "EquipButton").Activated:Fire()
	step(0.05)
	local _, _, l1b = state("Spark")
	local _, _, l2b = state("Flame")
	check(P1:GetAttribute("EquippedAura") == "Spark" and l1b == "UNEQUIP" and l2b == "EQUIP" and near(P1:GetAttribute("Damage"), 60), "K9 EquipButton de Spark : EquipCosmetic envoyé, la liste suit")
	field(rowOf(shopGui, "Spark"), "EquipButton").Activated:Fire()
	step(0.05)
	local _, _, l1c = state("Spark")
	check(P1:GetAttribute("EquippedAura") == nil and l1c == "EQUIP", "K10 second clic : retirée, « EQUIP »")

	-- Faux ShopService (a19) : prix lu dans Config, argent dépensé, puis Grant.
	NetS.Server.BuyItem:Connect(function(player, id)
		local def = Cosmetics.ById[id]
		if def and not CosmeticService.Owns(player, id) and DataService.SpendCash(player, def.Price) then
			CosmeticService.Grant(player, id)
		end
	end)
	DataService.AddCash(P1, 500000)
	local sent = FIRE_SERVER.BuyItem or 0
	field(rowOf(shopGui, "Lightning"), "BuyButton").Activated:Fire()
	step(0.05)
	local b3b, e3b, l3b = state("Lightning")
	check((FIRE_SERVER.BuyItem or 0) == sent + 1 and CosmeticService.Owns(P1, "Lightning") and data1.Cash == 100000, "K11 BuyButton : BuyItem(Lightning) envoyé ; payé $400K et accordé par le faux ShopService")
	check(not b3b and e3b and l3b == "EQUIP" and P1:GetAttribute("EquippedAura") == nil, "K12 la liste suit l'achat ; l'achat n'équipe pas")

	shopGui:FindFirstChild("TrailsTab", true).Activated:Fire()
	step(0.05)
	rows = rowsOf(shopGui)
	table.clear(names)
	table.clear(prices)
	table.clear(bonuses)
	for _, row in rows do
		table.insert(names, row.Name)
		table.insert(prices, field(row, "Price").Text)
		table.insert(bonuses, field(row, "Bonus").Text)
	end
	check(table.concat(names, ",") == "Item_Dust,Item_Wind,Item_Turbo,Item_Comet,Item_Hyperspace", "K13 onglet Trails : 5 lignes, celles des auras retirées")
	check(table.concat(bonuses, " | ") == "×1.1 speed | ×1.25 speed | ×1.4 speed | ×1.6 speed | ×1.8 speed", "K14 Bonus : ×1.1 speed … ×1.8 speed")
	check(table.concat(prices, " ") == "$300 $10K $300K $8M $200M", "K15 Price : $300 $10K $300K $8M $200M")
	local _, ew, lw = state("Wind")
	local bt = state("Turbo")
	check(ew and lw == "UNEQUIP" and bt, "K16 Wind équipé : « UNEQUIP » ; Turbo : BuyButton")
	shopGui:FindFirstChild("CloseButton", true).Activated:Fire()
	step(0.05)
	check(not shopGui.Enabled and #rowsOf(shopGui) == 0, "K17 CloseButton : écran fermé, lignes retirées")
	prompt.Triggered:Fire(P1)
	step(0.05)
	check(shopGui.Enabled and #rowsOf(shopGui) == 5, "K18 réouverture : dernier onglet choisi (Trails)")
	root1.CFrame = CFrame.new(-14, 3, 0) -- 24 studs du comptoir
	step(0.05)
	check(not shopGui.Enabled, "K19 Alice à 24 studs du comptoir : écran fermé tout seul")
	root1.CFrame = CFrame.new(-14, 3, -20)

	new("Decal", { Name = "FX_Aura_Etincelle", Texture = "rbxassetid://3003" }, ReplicatedStorage.Assets.FX)
	prompt.Triggered:Fire(P1)
	shopGui:FindFirstChild("AurasTab", true).Activated:Fire()
	step(0.05)
	check(field(rowOf(shopGui, "Spark"), "Icon").Image == "rbxassetid://3003" and field(rowOf(shopGui, "Flame"), "Icon").Image == "rbxassetid://9", "K20 Icon : texture de Clément si livrée, sinon l'image du Template")
end

print("\n== L. Écran recréé, écran gris, comptoir et streaming")
do
	shopGui:Destroy()
	local grey = makeAuraShop(playerGui, true)
	step(0.05)
	check(grey.Enabled == false, "L1 écran recréé (ResetOnSpawn) : rebranché, fermé")
	prompt.Triggered:Fire(P1)
	step(0.05)
	check(grey.Enabled and #rowsOf(grey) == 6 and field(rowOf(grey, "Flame"), "ItemName").Text == "Flame", "L2 écran gris ouvert sur les auras ; exemple « Aura name » : nom écrit tel quel (Flame)")
	check(field(rowOf(grey, "Flame"), "EquipButton").Text == "Equip" and field(rowOf(grey, "Royal"), "BuyButton").Text == "Buy", "L3 bouton gris qui porte son texte : « Equip » écrit sur le bouton ; BuyButton inchangé")
	grey:FindFirstChild("TrailsTab", true).InputBegan:Fire({ UserInputType = "Enum.UserInputType.MouseMovement" })
	step(0.05)
	check(#rowsOf(grey) == 6, "L4 onglet en Frame, souris qui passe : rien")
	grey:FindFirstChild("TrailsTab", true).InputBegan:Fire({ UserInputType = "Enum.UserInputType.Touch" })
	step(0.05)
	check(#rowsOf(grey) == 5 and field(rowOf(grey, "Wind"), "EquipButton").Text == "Unequip", "L5 onglet en Frame touché : trails, « Unequip » sur Wind")
	grey:FindFirstChild("CloseButton", true).Activated:Fire()
	step(0.05)

	counterPart:Destroy()
	counterModel.PrimaryPart = nil -- comme Roblox quand la pièce sort du modèle
	step(0.05)
	check(#counterModel:GetDescendants() == 0, "L6 pièce du comptoir sortie du streaming : plus d'invite")
	local back = new("Part", { Name = "Counter", CFrame = CFrame.new(-14, 2, -24) }, counterModel)
	step(0.05)
	local again = back:FindFirstChild("AuraShopPrompt")
	check(again ~= nil, "L7 pièce revenue : invite recréée")
	CollectionServiceRemoved(counterModel, "AuraShop")
	step(0.05)
	check(back:FindFirstChild("AuraShopPrompt") == nil, "L8 tag retiré (comptoir sorti du streaming) : invite retirée")
	addTag(counterModel, "AuraShop")
	step(0.05)
	check(back:FindFirstChild("AuraShopPrompt") ~= nil, "L9 tag revenu : invite reposée")
	local empty = new("Model", { Name = "AuraShop" }, shops)
	addTag(empty, "AuraShop")
	step(0.05)
	local desk = new("Part", { Name = "Desk", CFrame = CFrame.new(40, 2, -24) }, empty)
	step(0.05)
	check(desk:FindFirstChild("AuraShopPrompt") ~= nil and #desk:GetChildren() == 1, "L10 comptoir chargé pièce par pièce : invite posée à l'arrivée de sa première pièce")
	local inStorage = new("Model", { Name = "AuraShop" }, ReplicatedStorage)
	new("Part", { Name = "Counter" }, inStorage)
	addTag(inStorage, "AuraShop")
	step(0.05)
	check(inStorage.Counter:FindFirstChild("AuraShopPrompt") == nil, "L11 modèle taggé hors du Workspace (ex. dans Assets) : ignoré")
end

print("\n== M. Sortie")
do
	check(logCount("[CosmeticService]", "WARN") == 0, "M1 aucun avertissement de CosmeticService depuis le dernier vidage de la sortie")
	check(logCount("[ToolService] GetAuraMultiplier", "WARN") == 0 and logCount("[StatsService] GetTrailMultiplier", "WARN") == 0, "M2 les points d'accroche ne se sont jamais plaints")
end

summary()
if VERBOSE then
	print("\n---- sortie complète")
	for _, line in FULL_LOG do
		print(`[{line.side} {line.kind}] {line.text}`)
	end
end
