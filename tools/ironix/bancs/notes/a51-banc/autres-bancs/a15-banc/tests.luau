---------------------------------------------------------------- bouchons des voisins
-- ProfileStore : session ouverte tout de suite, données = copie du modèle, rien n'est sauvegardé.
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
		local profile = { Data = deepCopy(template), Key = key, active = true }
		function profile.IsActive(self) return self.active end
		function profile.Reconcile(_self) end
		function profile.EndSession(self) self.active = false end
		function profile.AddUserId(_self, _id) end
		profile.OnSessionEnd = { Connect = function() return { Disconnect = function() end } end }
		return profile
	end
	return store
end
return ProfileStore
]==]

SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {} }
function AnimationController.PlayPlayer(name) table.insert(AnimationController.played, name) return nil end
function AnimationController.StopPlayer() end
return AnimationController
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
local packages = folder(server, "Packages")
moduleScript(packages, "ProfileStore", "stub/ProfileStore")
local dataModule = moduleScript(services, "DataService", "server/Services/DataService.luau")
local toolModule = moduleScript(services, "ToolService", "server/Services/ToolService.luau")

local client = folder(StarterPlayerScripts, "Client")
local controllers = folder(client, "Controllers")
moduleScript(folder(controllers, "UI"), "Motion", "client/Controllers/UI/Motion.luau") -- a37 (DEV-052) : module d'aide des contrôleurs
local hudModule = moduleScript(controllers, "HudController", "client/Controllers/HudController.luau")
local unboxModule = moduleScript(controllers, "UnboxController", "client/Controllers/UnboxController.luau")
local heistModule = moduleScript(controllers, "HeistController", "client/Controllers/HeistController.luau")
local chaseModule = moduleScript(controllers, "ChaseController", "client/Controllers/ChaseController.luau")
moduleScript(controllers, "AnimationController", "stub/AnimationController")
-- Copie a23 : modules d'aide d'UnboxController (ouverture v2, DEV-050).
local unboxHelpers = folder(controllers, "Unbox")
for _, name in { "Reel", "Sequence", "Screen" } do
	moduleScript(unboxHelpers, name, `client/Controllers/Unbox/{name}.luau`)
end

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

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Copie de UI_HUD telle que relevée dans Studio le 2026-11-07 (wave4-studio.md).
local function makeHud(playerGui)
	local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = new("Frame", { Name = "LeftRail" }, hud)
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		local button = new("TextButton", { Name = name, Text = "" }, rail)
		new("Frame", { Name = "Icon" }, button)
		new("TextLabel", { Name = "Label", Text = name }, button)
	end
	local panel = new("Frame", { Name = "StatsPanel" }, hud)
	local row1 = new("Frame", { Name = "StrengthDamageRow" }, panel)
	new("Frame", { Name = "StrengthIcon" }, row1)
	new("TextLabel", { Name = "Strength", Text = "1.4K" }, row1)
	new("Frame", { Name = "DamageIcon" }, row1)
	new("TextLabel", { Name = "Damage", Text = "120" }, row1)
	local row2 = new("Frame", { Name = "SpeedRow" }, panel)
	new("Frame", { Name = "SpeedIcon" }, row2)
	new("TextLabel", { Name = "Speed", Text = "5.2M" }, row2)
	local row3 = new("Frame", { Name = "CashRow" }, panel)
	new("Frame", { Name = "CashIcon" }, row3)
	new("TextLabel", { Name = "Cash", Text = "$11.1B" }, row3)
	new("TextLabel", { Name = "Income", Text = "+$1.2K/s" }, row3)
	new("TextButton", { Name = "ReturnBaseButton", Text = "BASE" }, hud)
	new("TextLabel", { Name = "NightCountdown", Text = "Nuit dans 4m 28s" }, hud)
	new("TextLabel", { Name = "HeistTimer", Text = "VOL : 7 s", Visible = false }, hud)
	local meter = new("Frame", { Name = "GuardMeter", Visible = false }, hud)
	new("Frame", { Name = "Fill", Size = UDim2.new(0.6, 0, 1, 0) }, meter)
	hud.Parent = playerGui
	return hud
end

-- Copie de UI_Unbox (Enabled = false au départ).
local function makeUnbox(playerGui)
	local screen = new("ScreenGui", { Name = "UI_Unbox", Enabled = false, ResetOnSpawn = false })
	local panel = new("Frame", { Name = "RevealPanel" }, screen)
	new("TextLabel", { Name = "Rarity", Text = "LÉGENDAIRE" }, panel)
	new("Frame", { Name = "ItemPreview" }, panel)
	new("TextLabel", { Name = "ItemName", Text = "Ticket à gratter gagnant" }, panel)
	new("TextLabel", { Name = "Income", Text = "+$120/s" }, panel)
	new("TextButton", { Name = "ContinueButton", Text = "Continuer" }, panel)
	screen.Parent = playerGui
	return screen
end

local function el(screen, name)
	return screen:FindFirstChild(name, true)
end

---------------------------------------------------------------- démarrage
local P1 = new("Player", { Name = "Alice", UserId = 101, DisplayName = "Alice" })
local character = new("Model", { Name = "Alice" })
local root = new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 0) }, character)
character.Parent = Workspace
P1.Character = character
local playerGui = new("PlayerGui", { Name = "PlayerGui" }, P1)
P1.Parent = Players
local hud = makeHud(playerGui)
local unbox = makeUnbox(playerGui)

local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Rarities = requireModule(ReplicatedStorage.Shared.Config.Rarities, "server")
local Format = requireModule(ReplicatedStorage.Shared.Format, "server")
-- Copie d'a39 (L-071) : boutons de gauche visibles pendant leur aperçu ; attendu lu dans Config/Features
-- (cachés sur un arbre d'avant L-071, où RobuxShopPreview et RebirthPreview n'existent pas).
local FeaturesF = requireModule(ReplicatedStorage.Shared.Config.Features, "server")
local LEFT_SHOWN = {
	RobuxShopButton = FeaturesF.RobuxShop or FeaturesF.RobuxShopPreview == true,
	IndexButton = FeaturesF.Index == true,
	RebirthButton = FeaturesF.Rebirth or FeaturesF.RebirthPreview == true,
}

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local Heist = requireModule(heistModule, "client")
local Chase = requireModule(chaseModule, "client")
local Hud = requireModule(hudModule, "client")
local Unbox = requireModule(unboxModule, "client")
for _, controller in { Heist, Chase, Hud, Unbox } do
	taskLib.spawn(controller.Start)
end
step(0.1)

local function T(name)
	return el(hud, name).Text
end

print("\n== A. Format court")
check(Format.short(1450) == "1.4K" and Format.short(5.2e6) == "5.2M" and Format.short(11.1e9) == "11.1B", "A1 1.4K, 5.2M, 11.1B")
check(Format.short(120) == "120" and Format.short(1.37) == "1.3" and Format.short(0) == "0", "A2 sous 1 000 : 120, 1.3, 0")
check(Format.short(12400) == "12.4K" and Format.short(124999) == "124K" and Format.short(1000) == "1K", "A3 12.4K, 124K, 1K")
check(Format.money(11.1e9) == "$11.1B" and Format.income(1200) == "+$1.2K/s" and Format.income(15) == "+$15/s", "A4 $11.1B, +$1.2K/s, +$15/s")
check(Format.short(1e33) == "1Dc" and Format.short(0 / 0) == "0" and Format.short(math.huge) == "∞", "A5 palier Dc, NaN, infini")

print("\n== B. HUD avant le profil")
check(T("Cash") == "…" and T("Income") == "…" and T("Speed") == "…" and T("Strength") == "…" and T("Damage") == "…", "B1 valeurs pas encore posées : « … »")
for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
	check(el(hud, name).Visible == LEFT_SHOWN[name], `B2 {name} {if LEFT_SHOWN[name] then "affiché (aperçu, L-071)" else "caché"} (Config/Features)`)
end
-- a21 : NightCycle et ReturnToBase réactivés dans Config/Features (DEV-047, DEV-045).
for _, name in { "NightCountdown", "ReturnBaseButton" } do
	check(el(hud, name).Visible == true, `B2 {name} affiché (Config/Features, a21)`)
end
check(el(hud, "LeftRail").Visible and el(hud, "StatsPanel").Visible and el(hud, "Cash").Visible, "B3 cadres décoratifs et valeurs toujours visibles")
check(el(hud, "HeistTimer").Visible == false and el(hud, "GuardMeter").Visible == false, "B4 chrono et jauge masqués hors vol")

print("\n== C. Attributs Cash (DataService) et Damage (ToolService)")
local DataService = requireModule(dataModule, "server")
local ToolService = requireModule(toolModule, "server")
DataService.Init()
ToolService.Init()
step(0.1)
local data = DataService.Get(P1)
check(data ~= nil and P1:GetAttribute("Cash") == 0, "C1 Cash = 0 au chargement du profil")
check(P1:GetAttribute("Damage") == 1, "C2 Damage = 1 au chargement (poings, Force 0)")
check(T("Cash") == "$0" and T("Damage") == "1", "C3 HUD : $0 et 1")
check(DataService.AddCash(P1, 11.1e9) == 11.1e9 and P1:GetAttribute("Cash") == 11.1e9 and T("Cash") == "$11.1B", "C4 AddCash : attribut et HUD « $11.1B »")
check(DataService.SpendCash(P1, 0.1e9) and P1:GetAttribute("Cash") == 11e9 and T("Cash") == "$11B", "C5 SpendCash : « $11B »")
check(not DataService.SpendCash(P1, 1e12) and P1:GetAttribute("Cash") == 11e9, "C6 achat refusé : attribut inchangé")
data.Stats.Strength = 1400
P1:SetAttribute("Strength", 1400) -- comme StatsService.AddStrength
check(P1:GetAttribute("Damage") == 15 and T("Strength") == "1.4K" and T("Damage") == "15", "C7 Force 1 400 : Damage 15 (poings), HUD 1.4K et 15")
check(ToolService.Grant(P1, "Hammer") and ToolService.Equip(P1, "Hammer"), "C8 marteau acheté et équipé")
check(P1:GetAttribute("Damage") == 300 and T("Damage") == "300", "C9 Equip : Damage 20 × 15 = 300")
ToolService.GetAuraMultiplier = function()
	return 2
end
ToolService.RefreshDamage(P1)
check(P1:GetAttribute("Damage") == 600 and T("Damage") == "600", "C10 RefreshDamage après une aura × 2 : 600")
-- Décision d'Ironix (2026-11-07) : le HUD affiche la vitesse de marche (attribut WalkSpeed), pas
-- les points d'entraînement (attribut Speed).
P1:SetAttribute("WalkSpeed", 5.2e6)
P1:SetAttribute("Income", 1200)
check(T("Speed") == "5.2M" and T("Income") == "+$1.2K/s", "C11 Speed (WalkSpeed) 5.2M, Income +$1.2K/s")
P1:SetAttribute("Speed", 42)
check(T("Speed") == "5.2M", "C11b les points d'entraînement (attribut Speed) ne changent pas le HUD")
P1:SetAttribute("WalkSpeed", 17.5)
check(T("Speed") == "17.5", "C11c vitesse de marche 17,5 → « 17.5 »")

print("\n== D. Chrono du braquage (vrai HeistController)")
local t0 = Workspace:GetServerTimeNow()
NetS.Server.HeistTimer:Fire(P1, "STORE_Z1_Superette", t0 + 10)
step(0.05)
local timer = el(hud, "HeistTimer")
check(timer.Visible and timer.Text == "HEIST: 10s", "D1 vol : « HEIST: 10s » visible (L-036)")
step(3)
check(timer.Visible and timer.Text == "HEIST: 7s", "D2 3 s plus tard : « HEIST: 7s »")
NetS.Server.HeistTimer:Fire(P1, "STORE_Z1_Kiosque", Workspace:GetServerTimeNow() + 4.5)
step(0.05)
check(timer.Text == "HEIST: 7s", "D3 deux chronos : celui qui finit le plus tard reste affiché")
NetS.Server.HeistTimer:Fire(P1, "STORE_Z1_Superette", 0)
step(0.05)
check(timer.Visible and timer.Text == "HEIST: 5s", "D4 premier masqué (prise) : le second s'affiche")
step(5)
check(timer.Visible == false, "D5 fin du chrono : masqué")
check(logHas("[Heist] STORE_Z1_Superette : chrono de 10 s", "PRINT") and logHas("chrono masqué", "PRINT"), "D6 une ligne de sortie par envoi, en Studio")
check(not logHas("[Heist] STORE_Z1_Superette : 9 s", "PRINT"), "D7 plus de compte à rebours dans la sortie")

print("\n== E. Poursuite : jauge et battements de cœur (vrai ChaseController)")
local active = new("Folder", { Name = "ActiveGuards" }, Workspace)
local function makeGuard(z)
	local guard = new("Model", { Name = "Guard_Fallback" })
	local guardRoot = new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, z) }, guard)
	guard:SetAttribute("TargetUserId", P1.UserId)
	guard.Parent = active
	return guard, guardRoot
end
local function at(part, z)
	part.CFrame = CFrame.new(0, 3, z)
end
local fill = el(hud, "Fill")
local meter = el(hud, "GuardMeter")
local guard, guardRoot = makeGuard(62)
clearLog()
NetS.Server.ChaseState:Fire(P1, true, nil) -- le vigile n'arrive pas avec l'événement (streaming)
step(0.3)
check(meter.Visible, "E1 poursuite : GuardMeter visible")
check(Chase.GetGuard() == guard, "E2 vigile retrouvé par son attribut TargetUserId")
check(near(fill.Size.X.Scale, 0.5) and fill.Size.Y.Scale == 1 and fill.Size.X.Offset == 0 and fill.Size.Y.Offset == 0, "E3 à 62 studs : Fill à moitié, hauteur de Clément gardée")
at(guardRoot, 4)
step(0.05)
check(near(fill.Size.X.Scale, 1), "E4 à 4 studs (capture) : Fill plein")
at(guardRoot, 150)
step(0.05)
check(near(fill.Size.X.Scale, 0), "E5 à 150 studs (au-delà de l'abandon) : Fill vide")
at(guardRoot, 8)
step(0.05)
check(logCount("Chase_Heartbeat", "WARN") == 1, "E6 sous 10 studs, son absent : un seul avertissement, silence")
check(logHas("♥ vigile à moins de 10 studs", "PRINT"), "E7 repère ♥ dans la sortie")
check(not logHas("[Poursuite] vigile à 62", "PRINT"), "E8 plus de distance écrite toutes les 0,5 s")
local soundsFolder = new("Folder", { Name = "Sounds" }, new("Folder", { Name = "Assets" }, ReplicatedStorage))
new("Sound", { Name = "Chase_Heartbeat" }, soundsFolder)
at(guardRoot, 30)
step(0.05)
at(guardRoot, 6)
step(0.05)
local beat = SoundService:FindFirstChild("Chase_Heartbeat")
check(beat ~= nil and beat.Looped and beat.IsPlaying, "E9 son livré : battements en boucle sous 10 studs")
at(guardRoot, 25)
step(0.05)
check(beat.IsPlaying == false, "E10 vigile à 25 studs : silence")
check(logCount("Chase_Heartbeat", "WARN") == 1, "E11 pas de nouvel avertissement")
-- Streaming : le vigile sort du client puis revient (nouvelle instance, même attribut).
guard:Destroy()
step(0.05)
check(Chase.GetDistance() == nil, "E12 vigile parti du client : distance inconnue")
local guard2 = makeGuard(33)
step(0.2)
check(Chase.GetGuard() == guard2 and near(Chase.GetDistance() or -1, 33), "E13 vigile revenu : retrouvé, distance 33")
check(near(fill.Size.X.Scale, (120 - 33) / 116), "E14 jauge à jour")
at(root, 0)
NetS.Server.ChaseState:Fire(P1, false)
step(0.05)
check(meter.Visible == false and beat.IsPlaying == false, "E15 fin de poursuite : jauge masquée, silence")
guard2:Destroy()
clearLog()
NetS.Server.ChaseState:Fire(P1, true, nil)
step(3.5)
check(logCount("vigile introuvable", "WARN") == 1 and meter.Visible, "E16 vigile jamais répliqué : un avertissement après 3 s, jauge affichée")
NetS.Server.ChaseState:Fire(P1, false)
step(0.05)

print("\n== F. Écran de révélation UI_Unbox (vrai UnboxController ; séquence v2 sur l'écran gris de DEV-021)")
-- Copie à jour par a23 (DEV-050) : la révélation est maintenant la séquence v2 (crans, rouleau,
-- éclat, textes, boutons ; durées de Config/Unbox). L'écran gris de DEV-021 (Rarity, ItemName,
-- Income, ContinueButton, ItemPreview) reste compatible ; l'écran v2 complet et la séquence en
-- détail sont testés par a23-banc. Les noms affichés viennent du catalogue (v1 ou v2).
local ItemsF = requireModule(ReplicatedStorage.Shared.Config.Items, "server")
local FormulasF = requireModule(ReplicatedStorage.Shared.Config.Formulas, "server")
local function reveal(uid, itemId, zone, tier, startRarity, upgrades)
	local item = ItemsF.ById[itemId]
	NetS.Server.UnboxReveal:Fire(P1, "box-1", uid, itemId, zone or item.Zone or 1, tier or "Premium", startRarity or item.Rarity, upgrades or 0)
	step(0.05)
end
-- Laisse passer la séquence jusqu'aux boutons (version complète : 6,72 s ; courte : 4,37 s).
local function untilButtons(itemId)
	local item = ItemsF.ById[itemId]
	step(if Rarities.ById[item.Rarity].FullReveal then 6.8 else 4.45)
end
local continue = el(unbox, "ContinueButton")
local studioTexts = { el(unbox, "Rarity").Text, el(unbox, "ItemName").Text, el(unbox, "Income").Text }
check(unbox.Enabled == false, "F1 écran fermé au départ")
reveal("uid-1", "Z3_Smartphone", 3, "Premium", "Rare", 0)
check(unbox.Enabled, "F2 UnboxReveal : écran ouvert tout de suite (séquence v2)")
check(el(unbox, "RevealPanel").Visible == false and continue.Visible == false, "F3 pendant le rouleau : textes et bouton cachés")
step(4.9)
check(el(unbox, "RevealPanel").Visible, "F4 éclat à 4,9 s (Rare, version complète)")
step(1)
check(el(unbox, "Rarity").Text == "RARE" and sameColor(el(unbox, "Rarity").TextColor3, Rarities.ById.Rare.Color), "F5 Rarity « RARE » en bleu")
check(el(unbox, "ItemName").Text == ItemsF.ById.Z3_Smartphone.DisplayName, "F6 ItemName du catalogue")
step(1)
check(el(unbox, "Income").Text == "+$300/s" and el(unbox, "Income").Visible, "F7 Income « +$300/s » (zone 3 : 60 × 5)")
check(continue.Visible, "F8 boutons affichés")
check(logHas("[Unbox] colis box-1 : RARE · Smartphone", "PRINT"), "F9 ligne de sortie gardée en Studio (L-089 : « colis <uid> »)")
continue.Activated:Fire()
step(0.05)
check(unbox.Enabled == false, "F10 ContinueButton : écran fermé")
check(el(unbox, "Rarity").Text == studioTexts[1] and el(unbox, "ItemName").Text == studioTexts[2] and el(unbox, "Income").Text == studioTexts[3] and el(unbox, "RevealPanel").Visible and continue.Visible, "F11 fermeture : textes, cadre et bouton remis comme dans Studio")
reveal("uid-2", "Z1_CanetteDeSoda", 1, "Standard")
step(4.45 + 5.8)
check(unbox.Enabled, "F12 encore ouvert 5,8 s après les boutons")
step(0.3)
check(unbox.Enabled == false, "F13 fermé tout seul 6 s après les boutons")
reveal("uid-3", "Z1_CanetteDeSoda", 1, "Standard")
reveal("uid-4", "Z2_FigurineHolographique", 2, "Luxe")
untilButtons("Z1_CanetteDeSoda")
local soda = ItemsF.ById.Z1_CanetteDeSoda
check(el(unbox, "Rarity").Text == Rarities.ById[soda.Rarity].DisplayNameUpper and el(unbox, "Income").Text == Format.income(FormulasF.ItemIncome(1, soda.Rarity)), "F14 deux ouvertures d'affilée : la première d'abord")
continue.Activated:Fire()
step(0.05)
untilButtons("Z2_FigurineHolographique")
check(unbox.Enabled and el(unbox, "Rarity").Text == "MYTHIC" and el(unbox, "Income").Text == Format.income(FormulasF.ItemIncome(2, "Mythic")), "F15 puis la seconde")
continue.Activated:Fire()
step(0.05)
check(unbox.Enabled == false, "F16 file vide : écran fermé")
reveal("uid-5", "Secret_ChatPorteBonheurDore", 5, "Luxe", "Secret", 0)
step(7.5) -- le ralenti du Secret décale les textes de 0,35 s
check(el(unbox, "Rarity").Text == "SECRET" and el(unbox, "Income").Visible and el(unbox, "Income").Text == Format.income(FormulasF.ItemIncome(5, "Secret")), "F17 Secret : revenu calculé avec la zone du colis (UnboxReveal v2)")
continue.Activated:Fire()
step(0.05)
-- Ancienne forme (3 arguments), envoyée sans passer par Net : acceptée, avec des valeurs par défaut.
ReplicatedStorage.Remotes.UnboxReveal:FireClient(P1, "box-1", "uid-6", "Z3_Smartphone")
step(0.05)
untilButtons("Z3_Smartphone")
check(unbox.Enabled and el(unbox, "Rarity").Text == "RARE" and el(unbox, "Income").Text == "+$300/s", "F18 ancienne forme d'UnboxReveal : révélation quand même")
continue.Activated:Fire()
step(0.05)
check(el(unbox, "ItemName").Visible and el(unbox, "Rarity").Visible, "F19 textes de nouveau visibles (état de Studio)")

print("\n== G. ItemPreview : l'objet révélé (ViewportFrame posé par le code)")
local itemsFolder = new("Folder", { Name = "Zone3" }, new("Folder", { Name = "Items" }, ReplicatedStorage.Assets))
local phone = new("Model", { Name = "ITM_Z3_Smartphone" })
local phoneRoot = new("Part", { Name = "Root", Size = Vector3.new(1, 2, 0.3), CFrame = CFrame.new(40, 1, 40) }, phone)
new("Script", { Name = "Spin" }, phoneRoot)
phone.PrimaryPart = phoneRoot
phone.Parent = itemsFolder
reveal("uid-7", "Z3_Smartphone", 3, "Premium", "Rare", 0)
step(5)
local viewport = el(unbox, "ItemPreview"):FindFirstChild("ItemViewport")
local copy = viewport and viewport:FindFirstChild("ITM_Z3_Smartphone", true)
check(viewport ~= nil and viewport.ClassName == "ViewportFrame" and viewport.BackgroundTransparency == 1, "G1 ViewportFrame transparent dans ItemPreview, à l'éclat")
check(copy ~= nil and copy ~= phone and copy:FindFirstChild("Spin", true) == nil, "G2 copie du modèle, script retiré")
local camera = viewport and viewport.CurrentCamera
check(camera ~= nil and camera.Parent == viewport, "G3 caméra fixe de l'aperçu")
check(phone:FindFirstChild("Spin", true) ~= nil and phone.Parent == itemsFolder, "G4 modèle de Clément intact")
step(2)
continue.Activated:Fire()
step(0.05)
check(el(unbox, "ItemPreview"):FindFirstChild("ItemViewport") == nil, "G5 aperçu retiré à la fermeture")
reveal("uid-8", "Z1_PaquetDeChips", 1, "Standard")
step(3.1)
local v0 = el(unbox, "ItemPreview"):FindFirstChild("ItemViewport")
check(v0 ~= nil and v0:FindFirstChild("V0Block", true) ~= nil, "G6 objet pas livré : cube V0 de la couleur de sa rareté (v2)")
step(1.5)
continue.Activated:Fire()
step(0.05)
check(el(unbox, "ItemPreview"):FindFirstChild("ItemViewport") == nil, "G7 cube V0 retiré à la fermeture")

print("\n== H. Écrans recréés ou absents")
hud:Destroy()
step(0.1)
check(true, "H1 HUD détruit : aucune erreur")
local hud2 = makeHud(playerGui)
step(0.05)
check(hud2:FindFirstChild("Cash", true).Text == "$11B" and hud2:FindFirstChild("Damage", true).Text == "600", "H2 HUD recréé : rebranché et rempli")
check(hud2:FindFirstChild("RobuxShopButton", true).Visible == LEFT_SHOWN.RobuxShopButton and hud2:FindFirstChild("NightCountdown", true).Visible == true, "H3 éléments réglés de nouveau selon Config/Features (NightCountdown affiché depuis a21 ; bouton Shop selon L-071)")
DataService.AddCash(P1, 1e9)
check(hud2:FindFirstChild("Cash", true).Text == "$12B", "H4 nouvel écran tenu à jour")
unbox:Destroy()
clearLog()
reveal("uid-9", "Z3_Smartphone", 3)
check(logCount("UI_Unbox absent", "WARN") == 1, "H5 UI_Unbox absent : un avertissement, révélation dans la sortie")
reveal("uid-10", "Z3_Smartphone", 3)
check(logCount("UI_Unbox absent", "WARN") == 1, "H6 pas de répétition de l'avertissement")
local unbox2 = makeUnbox(playerGui)
reveal("uid-11", "Z2_PelucheGeante", 2, "Luxe")
untilButtons("Z2_PelucheGeante")
check(unbox2.Enabled and unbox2:FindFirstChild("ItemName", true).Text == ItemsF.ById.Z2_PelucheGeante.DisplayName, "H7 écran revenu : révélation affichée")
unbox2:FindFirstChild("ContinueButton", true).Activated:Fire()
step(0.05)
check(unbox2.Enabled == false, "H8 son ContinueButton est rebranché")

print("\n== J. Revenu du HUD retenu jusqu'à la révélation (copie a26, vague 8)")
-- Le serveur expose l'objet (attribut Income) juste après UnboxReveal : le HUD garde l'ancien revenu
-- jusqu'à ce que l'écran ait compté celui de l'objet (CountEnd), puis se met à jour.
do
	local UnboxCfg = requireModule(ReplicatedStorage.Shared.Config.Unbox, "server")
	local function inc()
		return hud2:FindFirstChild("Income", true).Text
	end
	local fullCountEnd = 4.9 + UnboxCfg.TextsAt + UnboxCfg.ItemNameAfter + UnboxCfg.IncomeAfter + UnboxCfg.IncomeCount.Full
	local shortCountEnd = 3.0 + UnboxCfg.TextsAt + UnboxCfg.ItemNameAfter + UnboxCfg.IncomeAfter + UnboxCfg.IncomeCount.Short
	check(near(fullCountEnd, 6.37, 1e-9) and near(shortCountEnd, 4.02, 1e-9), `revenu compté à 6,37 s (complète) et 4,02 s (courte) : {fullCountEnd}, {shortCountEnd}`)
	P1:SetAttribute("Income", 1200)
	step(0.05)
	check(inc() == Format.income(1200), "J1 HUD avant l'ouverture : +$1.2K/s")
	reveal("uid-20", "Z3_Smartphone", 3, "Premium", "Rare", 0)
	P1:SetAttribute("Income", 1500) -- le serveur expose l'objet
	step(0.05)
	check(unbox2.Enabled and inc() == Format.income(1200), "J2 écran d'ouverture en cours : le HUD garde +$1.2K/s")
	step(4.9) -- T ≈ 5,0 s : éclat passé (4,9 s), revenu pas encore affiché (5,47 s)
	check(el(unbox2, "RevealPanel").Visible and inc() == Format.income(1200), "J3 objet révélé (éclat) : toujours l'ancien revenu")
	step(fullCountEnd - 5.0 - 0.05)
	check(inc() == Format.income(1200), "J4 pendant le comptage du revenu à l'écran : toujours l'ancien")
	step(0.1)
	check(el(unbox2, "Income").Text == "+$300/s" and inc() == Format.income(1500), "J5 l'écran a fini de compter +$300/s : HUD à jour (+$1.5K/s)")
	step(0.4) -- boutons à 6,72 s
	unbox2:FindFirstChild("ContinueButton", true).Activated:Fire()
	step(0.05)
	check(unbox2.Enabled == false, "J5b écran fermé")

	-- Deux ouvertures d'affilée : chacune montre la hausse de son objet.
	reveal("uid-21", "Z1_CanetteDeSoda", 1, "Standard")
	P1:SetAttribute("Income", 2000)
	reveal("uid-22", "Z3_Smartphone", 3, "Premium", "Rare", 0)
	P1:SetAttribute("Income", 2600)
	step(shortCountEnd - 0.2)
	check(inc() == Format.income(1500), "J6 deux ouvertures : rien avant la première révélation")
	step(0.3)
	check(inc() == Format.income(2000), "J7 première comptée : sa hausse seulement (+$2K/s)")
	step(0.5)
	unbox2:FindFirstChild("ContinueButton", true).Activated:Fire()
	step(0.05)
	check(inc() == Format.income(2000), "J8 seconde à l'écran : sa hausse attend")
	step(fullCountEnd + 0.1)
	check(inc() == Format.income(2600), "J9 seconde comptée : +$2.6K/s")
	unbox2:FindFirstChild("ContinueButton", true).Activated:Fire()
	step(0.05)

	-- Écran retiré pendant la séquence (réapparition) : le HUD n'attend plus.
	reveal("uid-23", "Z3_Smartphone", 3, "Premium", "Rare", 0)
	P1:SetAttribute("Income", 2900)
	step(1)
	check(inc() == Format.income(2600), "J10 séquence en cours : retenu")
	unbox2.Parent = nil
	step(0.1)
	check(inc() == Format.income(2900), "J11 écran retiré avant la révélation : HUD à jour tout de suite")
	unbox2.Parent = playerGui
	unbox2.Enabled = false

	-- Sans UI_Unbox : à jour tout de suite.
	unbox2.Parent = nil
	clearLog()
	reveal("uid-24", "Z3_Smartphone", 3, "Premium", "Rare", 0)
	P1:SetAttribute("Income", 3200)
	step(0.05)
	check(inc() == Format.income(3200), "J12 écran d'ouverture absent : HUD à jour tout de suite")

	-- SkipButton après le rouleau : tout s'affiche d'un coup, revenu du HUD compris.
	local unbox3 = makeUnbox(playerGui)
	new("TextButton", { Name = "SkipButton", Visible = false, Text = "" }, unbox3)
	reveal("uid-25", "Z3_Smartphone", 3, "Premium", "Rare", 0)
	P1:SetAttribute("Income", 3500)
	step(4.5) -- rouleau fini (4,35 s), objet pas encore révélé (4,9 s)
	check(unbox3.Enabled and inc() == Format.income(3200), "J13 après le rouleau, avant l'éclat : retenu")
	tapSkip() -- 2026-11-08 : appui n'importe où, plus le bouton
	check(el(unbox3, "Income").Text == "+$300/s" and inc() == Format.income(3500), "J14 SkipButton : revenu de l'objet à l'écran et HUD à jour aussitôt")
	step(0.05)
	unbox3:FindFirstChild("ContinueButton", true).Activated:Fire()
	step(0.05)
	check(unbox3.Enabled == false, "J15 écran fermé")
	unbox3:Destroy()
	unbox2.Parent = playerGui
end

print("\n== I. Sortie")
local errors = 0
for _, line in FULL_LOG do
	if line.kind == "WARN" and (string.find(line.text, "[Net]", 1, true) or string.find(line.text, "[HUD]", 1, true)) then
		if not string.find(line.text, "Chase_Heartbeat", 1, true) then
			errors += 1
			print("  avertissement inattendu : " .. line.text)
		end
	end
end
check(errors == 0, "I1 aucun envoi mal formé (Net) ni élément du HUD introuvable")

if VERBOSE then
	print("\n-- sortie des modules")
	for _, line in FULL_LOG do
		print(`[{line.side} {line.kind}] {line.text}`)
	end
end
summary()
