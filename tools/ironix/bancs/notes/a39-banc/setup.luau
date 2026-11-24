--!nocheck
-- Mise en place commune des scénarios du banc a39 (L-071, points 1 et 2 : boutons Shop, Index et
-- Rebirth du HUD, vitrine de la boutique Robux, écran Rebirth en aperçu, plaques ShopPad des
-- comptoirs du hub, contrat). Faux Roblox : celui d'a38 (stubs.luau d'a36, ext29.luau, ext38.luau avec
-- MarketplaceService), copié ici tel quel. Vrais modules : Shared (Config, Contract, Net, Format,
-- Loader…), Controllers/UI/Motion, HudController, RobuxShopController, WeaponShopController,
-- AuraShopController, RebirthController, ShopPadController, et le ContractChecker (scénario contract).
-- Le serveur n'est pas lancé : seul Net est chargé côté serveur (il crée les remotes que les boutiques
-- attendent). Les attributs que le serveur pose (Cash, Income, Pass…) sont posés par les scénarios.
-- Écrans : copies des arbres relevés dans Studio (wave14-studio.md, bancs a38, a19 et a20).

---------------------------------------------------------------- arbre du jeu
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
SHARED = sharedRoot

local server = folder(ServerScriptService, "Server")
SERVICES = folder(server, "Services")
CHECKER_MODULE = moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")

local clientRoot = folder(folder(StarterPlayer, "StarterPlayerScripts"), "Client")
CONTROLLERS = folder(clientRoot, "Controllers")
CONTROLLER_NAMES = { "HudController", "RobuxShopController", "WeaponShopController", "AuraShopController", "RebirthController", "ShopPadController" }
for _, name in CONTROLLER_NAMES do
	if SOURCES[`client/Controllers/{name}.luau`] then
		moduleScript(CONTROLLERS, name, `client/Controllers/{name}.luau`)
	end
end
moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau")

function sharedModule(path, side)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, side or "client")
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end

ASSETS = folder(ReplicatedStorage, "Assets")
ICONS = folder(ASSETS, "Icons")
NOODLES_ICON = "rbxassetid://5551"
make("Decal", { Name = "ICON_Z1_PotDeNouilles", Texture = NOODLES_ICON }, ICONS)

---------------------------------------------------------------- carte : comptoirs du hub (relevé du 2026-11-08)
MAP = folder(Workspace, "Map")
HUB = folder(MAP, "Hub")
STALLS = folder(HUB, "Stalls")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, -0.5, 0) }, HUB)

-- Un comptoir comme ceux de Clément : un Model taggé, sa pièce principale, du décor, et (facultatif)
-- une plaque ShopPad posée au sol devant le stand, à 6 studs de la pièce principale.
function makeStall(name, tag, pivot, withPad, parent)
	local model = make("Model", { Name = name })
	local counter = make("Part", { Name = "Counter", Anchored = true, CFrame = CFrame.new(pivot), Size = Vector3.new(12, 4, 3) }, model)
	model.PrimaryPart = counter
	make("Part", { Name = "Awning", Anchored = true, CFrame = CFrame.new(pivot + Vector3.new(0, 6, 0)), Size = Vector3.new(14, 1, 6) }, model)
	local vendor = make("Model", { Name = "Vendor_" .. tag }, model)
	make("Part", { Name = "Torso", Anchored = true, CFrame = CFrame.new(pivot + Vector3.new(0, 2, -3)), Size = Vector3.new(2, 2, 1) }, vendor)
	local pad = nil
	if withPad then
		pad = makePad(model, Vector3.new(pivot.X, 0.1, pivot.Z + 6))
	end
	model.Parent = parent or STALLS
	addTag(model, tag)
	return model, counter, pad
end
-- Plaque ShopPad de 8 × 0,2 × 6 studs, posée à plat en `position`.
function makePad(model, position)
	return make("Part", { Name = "ShopPad", Anchored = true, CFrame = CFrame.new(position), Size = Vector3.new(8, 0.2, 6), Color = Color3.fromRGB(255, 200, 0) }, model)
end

WEAPON_PIVOT = Vector3.new(8.6, 3.95, 55)
AURA_PIVOT = Vector3.new(8.6, 3.95, -55)
ROBUX_PIVOT = Vector3.new(8.6, 3.95, 87)
-- Le HumanoidRootPart d'un R15 debout sur la plaque : 3 studs au-dessus du sol.
function onPadSpot(pivot)
	return Vector3.new(pivot.X, 3.1, pivot.Z + 6)
end
FAR_SPOT = Vector3.new(-150, 3, 0)

---------------------------------------------------------------- joueur local
P1 = make("Player", { Name = "Ada", DisplayName = "Ada", UserId = 101 }, nil)
PLAYER_GUI = make("PlayerGui", { Name = "PlayerGui" }, P1)
make("Backpack", { Name = "Backpack" }, P1)
P1.Parent = Players
Players.LocalPlayer = P1
CLIENT_PLAYER = P1
do
	local character = make("Model", { Name = "Ada" })
	ROOT = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(FAR_SPOT), CanCollide = false }, character)
	local humanoid = make("Humanoid", { Name = "Humanoid" }, character)
	humanoid.RootPart = ROOT
	character.PrimaryPart = ROOT
	character.Parent = Workspace
	P1.Character = character
end
function moveTo(position)
	ROOT.CFrame = CFrame.new(position)
end

---------------------------------------------------------------- écrans de Clément
-- UI_HUD (relevé de Studio, a37) : LeftRail avec les 3 boutons en pilule (TextButton, Icon, Label).
function buildHud(parent)
	local gui = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = make("Frame", { Name = "LeftRail" }, gui)
	for name, label in { RobuxShopButton = "SHOP", IndexButton = "INDEX", RebirthButton = "REBIRTH" } do
		local button = make("TextButton", { Name = name, Text = "" }, rail)
		make("ImageLabel", { Name = "Icon" }, button)
		make("TextLabel", { Name = "Label", Text = label }, button)
	end
	local panel = make("Frame", { Name = "StatsPanel" }, gui)
	for _, name in { "Strength", "Damage", "Speed", "Cash", "Income" } do
		make("TextLabel", { Name = name, Text = "0" }, panel)
	end
	local base = make("TextButton", { Name = "ReturnBaseButton", Text = "" }, gui)
	make("TextLabel", { Name = "BaseLabel", Text = "BASE" }, base)
	make("TextLabel", { Name = "Cooldown", Text = "84s" }, base)
	make("TextLabel", { Name = "NightCountdown", Text = "Night in 4:28" }, gui)
	make("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false }, gui)
	local meter = make("Frame", { Name = "GuardMeter", Visible = false }, gui)
	make("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1) }, meter)
	gui.Parent = parent
	return gui
end
function hudButton(hud, name)
	return hud:FindFirstChild(name, true)
end

-- UI_RobuxShop (relevé de Studio, banc a38) : Root/Window/List (Template invisible, 6 cartes d'exemple
-- Preview_1 à _6 avec l'attribut IconAsset sur leur Icon), Root/Tabs (4 onglets), CloseButton.
PREVIEW_ICONS = {
	{ "UI_Icon_GP_x2Cash", "rbxassetid://90748953656553", "×2 CASH", "Doubles all your income", "449" },
	{ "UI_Icon_GP_x2Training", "rbxassetid://106315635775683", "×2 TRAINING", "×2 treadmill and bench gains", "299" },
	{ "UI_Icon_GP_VIP", "rbxassetid://71854395817195", "VIP", "+10% income, aura, chat tag", "249" },
	{ "UI_Icon_GP_AutoCollect", "rbxassetid://140209894817694", "AUTO COLLECT", "Cash collects itself, anywhere", "199" },
	{ "UI_Icon_GP_FastOpen", "rbxassetid://95075762072413", "FAST OPEN", "Boxes open 2× faster", "299" },
	{ "UI_Icon_GP_Displays", "rbxassetid://93766507411897", "+4 DISPLAYS", "4 extra display stands", "349" },
}
function buildRobuxShopGui(parent)
	local gui = make("ScreenGui", { Name = "UI_RobuxShop", Enabled = false, ResetOnSpawn = false })
	local root = make("Frame", { Name = "Root" }, gui)
	local window = make("Frame", { Name = "Window" }, root)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local list = make("ScrollingFrame", { Name = "List" }, window)
	make("UIGridLayout", { Name = "UIGridLayout" }, list)
	local function card(name, spec, visible, owned)
		local frame = make("Frame", { Name = name, Visible = visible }, list)
		make("Frame", { Name = "CardShadow" }, frame)
		local clip = make("Frame", { Name = "Clip" }, frame)
		make("ImageLabel", { Name = "Rays" }, clip)
		local icon = make("ImageLabel", { Name = "Icon", Image = spec[2] }, frame)
		icon:SetAttribute("IconAsset", spec[1])
		make("TextLabel", { Name = "ItemName", Text = spec[3] }, frame)
		make("TextLabel", { Name = "Effect", Text = spec[4] }, frame)
		local row = make("Frame", { Name = "BuyRow", Visible = not owned }, frame)
		local buy = make("TextButton", { Name = "BuyButton", Text = "" }, row)
		make("ImageLabel", { Name = "Studs" }, buy)
		local content = make("Frame", { Name = "Content" }, buy)
		make("ImageLabel", { Name = "RobuxIcon" }, content)
		make("TextLabel", { Name = "Price", Text = spec[5] }, content)
		local ownedFrame = make("Frame", { Name = "Owned", Visible = owned }, frame)
		local ownedContent = make("Frame", { Name = "Content" }, ownedFrame)
		make("ImageLabel", { Name = "CheckIcon" }, ownedContent)
		make("TextLabel", { Name = "OwnedLabel", Text = "OWNED" }, ownedContent)
		return frame
	end
	card("Template", PREVIEW_ICONS[1], false, false)
	for index, spec in PREVIEW_ICONS do
		card(`Preview_{index}`, spec, true, index == 3)
	end
	local tabs = make("Frame", { Name = "Tabs" }, root)
	for _, name in { "OffersTab", "GamepassesTab", "CashTab", "BoostsTab" } do
		local tab = make("TextButton", { Name = name, Text = "" }, tabs)
		make("ImageLabel", { Name = "TabIcon" }, tab)
		make("TextLabel", { Name = "TabLabel", Text = string.upper((string.gsub(name, "Tab$", ""))) }, tab)
	end
	gui.Parent = parent
	return gui
end
function cardsOf(gui)
	local out = {}
	for _, child in gui.Root.Window.List:GetChildren() do
		if string.sub(child.Name, 1, 6) == "Offer_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
function offerKeys(gui)
	local out = {}
	for _, card in cardsOf(gui) do
		table.insert(out, (string.gsub(card.Name, "^Offer_", "")))
	end
	return table.concat(out, ",")
end
function cardNamed(gui, key)
	return gui.Root.Window.List:FindFirstChild("Offer_" .. key)
end
function textOf(root, name)
	local found = root:FindFirstChild(name, true)
	return if found then found.Text else nil
end
function shown(root, name)
	local found = root:FindFirstChild(name, true)
	return found ~= nil and found.Visible == true
end

-- UI_WeaponShop (copie grise au contrat 2.2, banc a19).
function buildWeaponShop(parent)
	local gui = make("ScreenGui", { Name = "UI_WeaponShop", Enabled = false })
	local window = make("Frame", { Name = "Window" }, gui)
	make("TextButton", { Name = "CloseButton", Text = "X" }, window)
	local list = make("ScrollingFrame", { Name = "List" }, window)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local template = make("Frame", { Name = "Template", Visible = false }, list)
	make("ImageLabel", { Name = "Icon" }, template)
	make("TextLabel", { Name = "ItemName", Text = "Tool" }, template)
	make("TextLabel", { Name = "Power", Text = "Power" }, template)
	make("TextLabel", { Name = "Price", Text = "$0" }, template)
	make("TextButton", { Name = "BuyButton", Text = "Buy" }, template)
	make("TextButton", { Name = "EquipButton", Text = "Equip" }, template)
	gui.Parent = parent
	return gui
end

-- UI_AuraShop (version habillée du banc a20 : onglets en boutons, Price dans BuyButton).
function buildAuraShop(parent)
	local gui = make("ScreenGui", { Name = "UI_AuraShop", Enabled = false })
	local window = make("Frame", { Name = "Window" }, gui)
	make("TextButton", { Name = "CloseButton", Text = "X" }, window)
	local tabs = make("Frame", { Name = "Tabs" }, window)
	make("TextLabel", { Name = "TabLabel", Text = "AURAS" }, make("TextButton", { Name = "AurasTab", Text = "" }, tabs))
	make("TextLabel", { Name = "TabLabel", Text = "TRAILS" }, make("TextButton", { Name = "TrailsTab", Text = "" }, tabs))
	local list = make("ScrollingFrame", { Name = "List" }, window)
	local template = make("Frame", { Name = "Template", Visible = false }, list)
	make("ImageLabel", { Name = "Icon", Image = "rbxassetid://9" }, template)
	make("TextLabel", { Name = "ItemName", Text = "AURA NAME" }, template)
	make("TextLabel", { Name = "Bonus", Text = "x1 power" }, template)
	make("TextLabel", { Name = "Price", Text = "$0" }, make("TextButton", { Name = "BuyButton", Text = "" }, template))
	make("TextLabel", { Name = "Label", Text = "EQUIP" }, make("TextButton", { Name = "EquipButton", Text = "" }, template))
	gui.Parent = parent
	return gui
end

-- UI_Rebirth (relevé de Studio du 2026-11-08, wave14-studio.md), avec quelques propriétés de style
-- de Clément pour vérifier qu'aucune ne change.
REBIRTH_RARITY_COLOR = Color3.fromRGB(47, 155, 255)
REBIRTH_ICON = "rbxassetid://777"
function buildRebirth(parent)
	local gui = make("ScreenGui", { Name = "UI_Rebirth", Enabled = false, ResetOnSpawn = false })
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1) }, gui)
	make("Frame", { Name = "WindowShadow" }, root)
	local window = make("Frame", { Name = "Window", Size = UDim2.fromScale(0.6, 0.7) }, root)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "Rebirth" }, header)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local pill = make("Frame", { Name = "LevelPill" }, window)
	make("ImageLabel", { Name = "RebirthIcon" }, pill)
	make("TextLabel", { Name = "Level", Text = "Level 0 → 1", TextColor3 = Color3.fromRGB(255, 255, 255) }, pill)
	local body = make("ScrollingFrame", { Name = "Body" }, window)
	local requirements = make("Frame", { Name = "Inner" }, make("Frame", { Name = "Requirements" }, body))
	local cashReq = make("Frame", { Name = "CashRequirement" }, requirements)
	make("ImageLabel", { Name = "CashIcon" }, cashReq)
	make("TextLabel", { Name = "CashTitle", Text = "CASH NEEDED" }, cashReq)
	make("TextLabel", { Name = "CashAmount", Text = "$10K" }, cashReq)
	local bar = make("Frame", { Name = "CashBar", Size = UDim2.new(1, 0, 0, 18) }, cashReq)
	make("Frame", { Name = "Fill", Size = UDim2.new(0.64, 2, 1, -4), BackgroundColor3 = Color3.fromRGB(47, 224, 143) }, bar)
	make("TextLabel", { Name = "CashLabel", Text = "$6.4K / $10K" }, cashReq)
	local itemReq = make("Frame", { Name = "ItemRequirement" }, requirements)
	make("ImageLabel", { Name = "Icon", Image = REBIRTH_ICON, ImageColor3 = Color3.fromRGB(80, 80, 80) }, itemReq)
	make("ImageLabel", { Name = "Lock", Visible = true }, itemReq)
	make("TextLabel", { Name = "ItemTitle", Text = "ITEM NEEDED" }, itemReq)
	make("TextLabel", { Name = "ItemName", Text = "INSTANT NOODLES" }, itemReq)
	make("TextLabel", { Name = "Rarity", Text = "RARE", TextColor3 = REBIRTH_RARITY_COLOR }, itemReq)
	make("TextLabel", { Name = "Status", Text = "Not owned yet" }, itemReq)
	local columns = make("Frame", { Name = "Inner" }, make("Frame", { Name = "Columns" }, body))
	local function column(name, title, rows, withIcon)
		local col = make("Frame", { Name = name }, columns)
		make("TextLabel", { Name = name .. "Title", Text = title }, make("Frame", { Name = name .. "Header" }, col))
		local list = make("Frame", { Name = name .. "List" }, col)
		for index, text in rows do
			local row = make("Frame", { Name = `Row{index}` }, list)
			if withIcon then
				make("ImageLabel", { Name = "RowIcon" }, row)
			else
				make("Frame", { Name = "Dot" }, row)
			end
			make("TextLabel", { Name = "RowLabel", Text = text }, row)
		end
	end
	column("Lose", "YOU LOSE", { "Cash", "Tools", "Speed & Strength", "Upgrades", "Auras & Trails" }, false)
	column("Keep", "YOU KEEP", { "3 items you pick", "Your Index", "Defenses", "Robux purchases" }, false)
	column("Gain", "YOU GAIN", { "+50% income forever", "Rebirth Aura", '"Rebirth 1" title' }, true)
	local actions = make("Frame", { Name = "Inner" }, make("Frame", { Name = "Actions" }, body))
	make("Frame", { Name = "ButtonShadow" }, actions)
	local confirm = make("TextButton", { Name = "ConfirmButton", Text = "" }, actions)
	for state, visible in { Disabled = true, Ready = false, Confirm = false } do
		local frame = make("Frame", { Name = state, Visible = visible }, confirm)
		make("TextLabel", { Name = "StateLabel", Text = string.upper(state) }, make("Frame", { Name = "Content" }, frame))
	end
	make("TextLabel", { Name = "Hint", Text = "Tap twice to confirm" }, actions)
	gui.Parent = parent
	return gui
end
function rebirthEl(gui, path)
	local current = gui
	for segment in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(segment, true)
	end
	return current
end

---------------------------------------------------------------- relevé des propriétés (aucun style touché)
-- Copie des propriétés de chaque descendant de `root` (et de lui-même).
function snapshot(root)
	local snap = {}
	local function take(inst)
		local props = {}
		for k, v in rawget(inst, "_props") do
			props[k] = v
		end
		snap[inst] = props
	end
	take(root)
	for _, d in root:GetDescendants() do
		take(d)
	end
	return snap
end
-- Différences entre le relevé et l'arbre actuel, hors `allowed[inst][propriété]` ; objets ajoutés ou
-- retirés compris. Renvoie la liste des différences en texte.
function diffSnapshot(snap, root, allowed)
	local out = {}
	local seen = {}
	local function compare(inst)
		seen[inst] = true
		local before = snap[inst]
		if before == nil then
			table.insert(out, `ajouté : {inst:GetFullName()} ({inst.ClassName})`)
			return
		end
		local props = rawget(inst, "_props")
		local ok = (allowed or {})[inst] or {}
		for k, v in props do
			if before[k] ~= v and not ok[k] then
				table.insert(out, `{inst:GetFullName()}.{k} : {tostring(before[k])} → {tostring(v)}`)
			end
		end
		for k, v in before do
			if props[k] == nil and not ok[k] then
				table.insert(out, `{inst:GetFullName()}.{k} retiré ({tostring(v)})`)
			end
		end
	end
	compare(root)
	for _, d in root:GetDescendants() do
		compare(d)
	end
	for inst in snap do
		if not seen[inst] and inst ~= root then
			table.insert(out, `retiré : {tostring(inst)}`)
		end
	end
	return out
end

---------------------------------------------------------------- actions
function click(button)
	button.Activated:Fire()
	flush()
end
function serverTime()
	return Workspace:GetServerTimeNow()
end

---------------------------------------------------------------- démarrage
-- Net côté serveur (les remotes), puis les contrôleurs du client par le vrai Loader.
function startClient()
	requireModule(SHARED.Net.Net, "server")
	Features = sharedModule("Config/Features")
	Monetization = sharedModule("Config/Monetization")
	Rebirths = sharedModule("Config/Rebirths")
	Items = sharedModule("Config/Items")
	Format = sharedModule("Format")
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
	advance(0.2)
end

-- Ids du banc (pre.live.luau) : gamepasses 9001 à 9006, produits 8001 à 8008, paliers d'Ouvrir
-- maintenant 8101 à 8104 ; HydraulicGloves et Cash300 restent à 0.
PASS_IDS = { DoubleCash = 9001, DoubleTraining = 9002, VIP = 9003, AutoCollect = 9004, FastOpen = 9005, ExtraStands = 9006, HydraulicGloves = 0 }
PRODUCT_IDS = { StarterPack = 8001, Cash10 = 8002, Cash60 = 8003, Cash300 = 0, Revenge = 8005, InstantShutter = 8006, Luck3 = 8007, Shield30 = 8008 }
TIER_IDS = { 8101, 8102, 8103, 8104 }
