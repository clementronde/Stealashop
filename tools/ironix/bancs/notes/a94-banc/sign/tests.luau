--!nocheck
-- Scénarios a94 (2026-11-12, L-108 points 2 et 5).
--   R1 pose : un panneau par magasin qui a ReqSignPoint, bas au point, face de Board comme le point ;
--      rien sans point ni dans _INBOX_CLEMENT ; aperçus _PREVIEW_StoreReqSigns retirés ; modèle intact
--   R2 textes : StoreName, « Speed N », « Strength N » (AdvisedDamage), ReqCaption intact
--   R3 couleurs : règle d'AdvicePanel, refaites quand Damage ou WalkSpeed changent
--   R4 streaming : point posé puis retiré ; magasin qui part
--   R5 GetSigns, R6 contrat, R7 Config des vigiles de nuit

SOURCES["shared/Net/Net.luau"] = [[ return { Client = {} } ]]
-- Faux Roblox (copie a83 du banc a52) : TextColor3 manque aux TextLabel, ajouté ici.
PROPS.TextLabel.TextColor3 = Color3.new(1, 1, 1)

local Shared = folder(ReplicatedStorage, "Shared")
do
	local keys = {}
	for key in SOURCES do
		if string.sub(key, 1, 7) == "shared/" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local parts = string.split(string.sub(key, 8), "/")
		local parent = Shared
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		moduleScript(parent, string.gsub(parts[#parts], "%.luau$", ""), key)
	end
end
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
moduleScript(Controllers, "StoreInfoController", "client/Controllers/StoreInfoController.luau")
local SignModule = moduleScript(Controllers, "StoreReqSignController", "client/Controllers/StoreReqSignController.luau")
local Config = Shared:FindFirstChild("Config")
local AdvicePanel = requireModule(Shared:FindFirstChild("AdvicePanel"), "client")
local Night = requireModule(Config:FindFirstChild("Night"), "client")
local Balance = requireModule(Config:FindFirstChild("Balance"), "client")
local Models = requireModule(Shared:FindFirstChild("Contract"):FindFirstChild("Models"), "client")
local Find = requireModule(Shared:FindFirstChild("Contract"):FindFirstChild("Find"), "client")

local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function part(name, parent, cframe, size)
	local p = new("Part", name, parent)
	p.CFrame = cframe
	if size then
		p.Size = size
	end
	return p
end
local function close(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end

-- Modèle StoreReqSign de Clément (relevé de wave29-studio.md), loin de l'origine, bas à y = 10.
local AssetsUI = folder(folder(ReplicatedStorage, "Assets"), "UI")
local template = new("Model", "StoreReqSign", nil)
template.WorldPivot = CFrame.new(100, 10, 0)
part("Foot", template, CFrame.new(100, 10.9, 0), Vector3.new(1.3, 0.6, 1.3))
part("FootBase", template, CFrame.new(100, 10.1, 0), Vector3.new(2.2, 0.2, 1.8))
local tBoard = part("Board", template, CFrame.new(100, 13.45, 0), Vector3.new(7, 4.5, 0.4))
local tGui = new("SurfaceGui", "SignGui", tBoard)
new("Frame", "Panel", tGui)
new("TextLabel", "StoreName", tGui).Text = "Mini Mart"
local speedRow = new("Frame", "SpeedRow", tGui)
new("ImageLabel", "SpeedIcon", speedRow)
new("TextLabel", "SpeedReq", speedRow).Text = "Speed 16"
local strengthRow = new("Frame", "StrengthRow", tGui)
new("ImageLabel", "StrengthIcon", strengthRow)
new("TextLabel", "StrengthReq", strengthRow).Text = "Strength 1"
new("TextLabel", "ReqCaption", tGui).Text = "REQUIRED TO BREAK IN"
template.Parent = AssetsUI

-- Magasins : Bounds avec ReqSignPoint (LookVector = +X : la rue).
local STREET = CFrame.Angles(0, -math.pi / 2, 0)
local Map = folder(Workspace, "Map")
local function store(name, zone, x, withPoint, parent)
	local model = new("Model", name, nil)
	local bounds = part("Bounds", model, CFrame.new(x, 7, 0), Vector3.new(20, 14, 20))
	if withPoint then
		new("Attachment", "ReqSignPoint", bounds).CFrame = CFrame.new(12, -7, 2) * STREET
	end
	model:SetAttribute("Zone", zone)
	model.Parent = parent or Map
	addTag(model, "NPCStore")
	return model
end
local preview = folder(Workspace, "_PREVIEW_StoreReqSigns")
local s1 = store("STORE_Z1_Superette", 1, 0, true)
local s6 = store("STORE_Z6_Banque", 6, 200, true)
local s3 = store("STORE_Z3_Electronique", 3, 400, false)
local inbox = folder(Workspace, "_INBOX_CLEMENT")
store("STORE_Z2_Confiserie", 2, 600, true, inbox)

local alice = new("Player", "Alice", Players)
new("PlayerGui", "PlayerGui", alice)
alice:SetAttribute("Damage", 1)
alice:SetAttribute("WalkSpeed", 16)
rawget(Players, "_props").LocalPlayer = alice
CLIENT_PLAYER = alice

local Signs = requireModule(SignModule, "client")
taskLib.spawn(Signs.Start)
advance(0.1)

local function signFolder()
	return Workspace:FindFirstChild("StoreReqSigns")
end
local function allSigns()
	local f = signFolder()
	return if f then f:GetChildren() else {}
end
local function signOf(storeModel)
	local f = signFolder()
	return f and f:FindFirstChild(`StoreReqSign_{storeModel.Name}`)
end
local function text(sign, name)
	local found = sign and Find.path(sign, name)
	return found and found.Text
end
local function color(sign, name)
	local found = sign and Find.path(sign, name)
	return found and found.TextColor3
end
local C = AdvicePanel.Colors

---------------------------------------------------------------- R1
print("== R1 pose")
check(#allSigns() == 2 and signOf(s1) and signOf(s6), `2 panneaux (Supérette, Banque), {#allSigns()} posés`)
check(signOf(s3) == nil, "magasin sans ReqSignPoint : pas de panneau")
check(preview.Parent == nil, "_PREVIEW_StoreReqSigns retiré en jeu")
do
	local sign = signOf(s1)
	local point = Find.path(s1, "ReqSignPoint")
	local box, size = sign:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	check(close(bottom, point.WorldCFrame.Position), "bas du panneau au point")
	local look = sign:FindFirstChild("Board").CFrame.LookVector
	check(close(Vector3.new(look.X, 0, look.Z).Unit, Vector3.new(1, 0, 0)), "face de Board tournée comme le point (vers la rue, +X)")
	local anchored = true
	for _, d in sign:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			anchored = false
		end
	end
	check(anchored, "pièces ancrées")
end
check(template.Parent == AssetsUI and text(template, "StoreName") == "Mini Mart" and text(template, "StrengthReq") == "Strength 1", "modèle de Clément intact")
check(logHas("[StoreReqSignController] 2 panneau(x) StoreReqSign posé(s)", "PRINT"), "ligne de démarrage en Studio")

---------------------------------------------------------------- R2
print("== R2 textes")
check(text(signOf(s1), "StoreName") == "Mini Mart" and text(signOf(s1), "SpeedReq") == "Speed 16" and text(signOf(s1), "StrengthReq") == "Strength 1",
	`Supérette : {text(signOf(s1), "StoreName")} · {text(signOf(s1), "SpeedReq")} · {text(signOf(s1), "StrengthReq")}`)
check(text(signOf(s6), "StoreName") == "Bank" and text(signOf(s6), "SpeedReq") == "Speed 48" and text(signOf(s6), "StrengthReq") == "Strength 40K",
	`Banque : {text(signOf(s6), "StoreName")} · {text(signOf(s6), "SpeedReq")} · {text(signOf(s6), "StrengthReq")}`)
check(text(signOf(s1), "ReqCaption") == "REQUIRED TO BREAK IN", "ReqCaption intact")

---------------------------------------------------------------- R3
print("== R3 couleurs")
check(color(signOf(s1), "SpeedReq") == C.Green and color(signOf(s1), "StrengthReq") == C.Green, "zone 1 : vert / vert (Speed 16, Damage 1)")
check(color(signOf(s6), "SpeedReq") == C.Red and color(signOf(s6), "StrengthReq") == C.Red, "zone 6 : rouge / rouge")
alice:SetAttribute("Damage", 20000)
alice:SetAttribute("WalkSpeed", 48)
advance(0.1)
check(color(signOf(s6), "SpeedReq") == C.Green and color(signOf(s6), "StrengthReq") == C.Orange, "Damage 20K (50 %) et WalkSpeed 48 : vert / orange")
alice:SetAttribute("Damage", 19000)
advance(0.1)
check(color(signOf(s6), "StrengthReq") == C.Red, "Damage 19K (47 %) : rouge")
check(text(signOf(s6), "StrengthReq") == "Strength 40K", "textes inchangés")

---------------------------------------------------------------- R4
print("== R4 streaming")
local point3 = new("Attachment", "ReqSignPoint", s3:FindFirstChild("Bounds"))
point3.CFrame = CFrame.new(12, -7, 0) * STREET
advance(0.1)
check(signOf(s3) and text(signOf(s3), "StoreName") == "Electronics" and text(signOf(s3), "SpeedReq") == "Speed 28", "point posé : panneau Electronics")
point3:Destroy()
advance(0.1)
check(signOf(s3) == nil and #allSigns() == 2, "point retiré : panneau retiré")
CollectionServiceRemoved(s6, "NPCStore")
advance(0.1)
check(signOf(s6) == nil and #allSigns() == 1, "magasin sorti : panneau retiré")
addTag(s6, "NPCStore")
advance(0.1)
check(signOf(s6) and #allSigns() == 2, "magasin revenu : panneau reposé")
local late = folder(Workspace, "_PREVIEW_StoreReqSigns")
advance(0.1)
check(late.Parent == nil, "aperçus arrivés plus tard : retirés aussi")

---------------------------------------------------------------- R5
print("== R5 GetSigns")
do
	local list = Signs.GetSigns()
	check(#list == 2 and list[1].Store == "STORE_Z1_Superette" and list[2].Store == "STORE_Z6_Banque" and list[2].Zone == 6
		and list[2].Speed == "Green" and list[2].Strength == "Red", "GetSigns : 2 panneaux triés, niveaux")
end

---------------------------------------------------------------- R6
print("== R6 contrat")
do
	local found
	for _, spec in Models.List do
		if spec.Key == "StoreReqSign" then
			found = spec
		end
	end
	check(found ~= nil and found.PrimaryPart == "Foot" and found.Expected == nil, "StoreReqSign au contrat, PrimaryPart Foot, facultatif")
	local point
	for _, p in Models.Store.Parts do
		if p.Name == "ReqSignPoint" then
			point = p
		end
	end
	check(point ~= nil and point.Optional == true and point.Class == "Attachment", "ReqSignPoint facultatif dans les magasins PNJ")
end

---------------------------------------------------------------- R7
print("== R7 vigiles de nuit")
check(Night.ChaseSpeed > Balance.Stats.MaxWalkSpeed, `Night.ChaseSpeed {Night.ChaseSpeed} > vitesse max d'un joueur {Balance.Stats.MaxWalkSpeed}`)
check(Night.ChaseSpeed < 2 * Balance.Stats.MaxWalkSpeed, "sous potion Speed (jusqu'à 140), on peut encore le semer")
check(Night.GaitSpeedMax >= Night.ChaseSpeed / 20 - 1e-9, "Run assez rapide pour ses pieds à l'échelle 1 (ChaseSpeed / 20)")

summary()
