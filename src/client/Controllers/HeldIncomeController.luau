--!strict
-- HeldIncomeController (vague 70, a230 ; liaison L-189, demande de Clément du 2026-11-15 ; client) : le revenu par
-- seconde de l'objet tenu en main, au-dessus de lui. Les cases de la barre du bas ne le montrent plus (texte de
-- Clément transparent).
--
--   - Objet en main = Tool d'un personnage avec l'attribut HeldItemUid (HeldItemService, Config/HeldItem).
--     Une copie de ReplicatedStorage/Assets/UI/BB_HeldIncome de Clément (Config/Hud.HeldIncome ; absente : un
--     billboard de repli aux mêmes noms) va dans le Tool : Adornee = sa poignée Handle, StudsOffsetWorldSpace = haut
--     de l'objet au-dessus de la poignée (« moitié de sa hauteur », la poignée est en son centre) + HeldIncome.Above ;
--     le StudsOffset de Clément (0,6) s'y ajoute. Le halo de rareté (RarityHalo) ne compte pas dans la hauteur.
--   - Texte d'Income (« $1.2K/s ») : pour le joueur local, celui des cases de la barre ($/s calculé par le serveur ;
--     état d'InventoryController), réécrit à chaque changement de l'inventaire ; objet absent de l'inventaire :
--     billboard éteint (Enabled).
--   - a469 (Cantin, 25/11 ; Config/HeldItem.IncomeForAll, Features.HeldIncomeAll / HeldIncomeAllDev) : allumé, le
--     même billboard va aussi sur l'objet tenu par CHAQUE autre joueur ; son texte vient de l'attribut
--     HeldItem.IncomeAttribute que le serveur pose sur le Tool (HeldItemService ; rien ne vient d'un client),
--     réécrit quand l'attribut change ; attribut absent ou faux : billboard éteint. Coupé : le joueur local seul,
--     comme avant.
--   - Coût : un billboard par objet tenu au plus, rien par image ; la hauteur est recalculée une fois par image au
--     plus quand des pièces arrivent (task.defer).
--   - Nettoyage : objet rangé, posé, volé, lâché (Tool sorti du personnage ou détruit par le serveur), nouveau
--     personnage (mort), joueur parti : la copie est détruite et ses connexions coupées. Elle part aussi avec le Tool.
-- Rien n'est envoyé au serveur ; seuls la copie, son Adornee, son StudsOffsetWorldSpace, son Enabled et le texte
-- d'Income sont touchés.
--
-- API (client ; Play, bancs) :
--   HeldIncomeController.GetState() -> { Shown: boolean, Uid: string?, Text: string?, Offset: number? }  (joueur local)
--   HeldIncomeController.GetViews() -> { { Player: string, Uid: string, Shown: boolean, Text: string? } }  (a469 : tous)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local HeldItem = require(Config:WaitForChild("HeldItem"))
local HudConfig = require(Config:WaitForChild("Hud"))
local Format = require(Shared:WaitForChild("Format"))
local RarityHalo = require(Shared:WaitForChild("RarityHalo"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))

type InventoryApi = {
	GetInventory: () -> { Items: { { Uid: string, Income: number } } },
	OnChanged: (listener: () -> ()) -> () -> (),
}
type View = {
	player: Player,
	tool: Tool,
	uid: string,
	gui: BillboardGui,
	label: TextLabel?,
	offset: number,
	pending: boolean,
	connections: { RBXScriptConnection },
}

local CONF = HudConfig.HeldIncome
local HANDLE = "Handle" -- HeldItemService
local IS_STUDIO = RunService:IsStudio()
local FOR_ALL = HeldItem.IncomeForAll == true

local HeldIncomeController = {}

local localPlayer = Players.LocalPlayer
local inventory: InventoryApi? = nil
local views: { [Tool]: View } = {}
local characterConnections: { [Player]: { RBXScriptConnection } } = {}
local fallbackSaid = false

-- Copie du billboard de Clément, sinon un repli aux mêmes noms (V0 : taille et place de son billboard).
local function billboard(): BillboardGui
	local folder: Instance? = ReplicatedStorage
	for _, name in UI.BillboardFolder do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	local template = if folder then folder:FindFirstChild(CONF.Billboard) else nil
	if template and template:IsA("BillboardGui") then
		return template:Clone() :: BillboardGui
	end
	if IS_STUDIO and not fallbackSaid then
		fallbackSaid = true
		print(`[HeldIncomeController] {CONF.Billboard} absent : billboard de repli au-dessus de l'objet en main`)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(2.4, 30, 0.6, 10)
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = CONF.Label
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = Color3.fromRGB(47, 203, 31)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = gui
	return gui
end

-- Haut de l'objet au-dessus du centre de la poignée, dans le repère de la poignée (studs ; halo exclu).
local function topAbove(tool: Tool, handle: BasePart): number
	local model = tool:FindFirstChild(HeldItem.ModelName)
	local top: number? = nil
	for _, descendant in (if model then model else tool):GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle and descendant.Name ~= RarityHalo.DisplayPart then
			local part = descendant :: BasePart
			local relative = handle.CFrame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			local reach = math.abs(relative.RightVector.Y) * half.X
				+ math.abs(relative.UpVector.Y) * half.Y
				+ math.abs(relative.LookVector.Y) * half.Z
			local y = relative.Position.Y + reach
			if top == nil or y > top then
				top = y
			end
		end
	end
	return if top then math.max(top, 0) else 0
end

local function inventoryIncome(uid: string): number?
	local api = inventory
	if api == nil then
		return nil
	end
	for _, item in api.GetInventory().Items do
		if item.Uid == uid then
			return item.Income
		end
	end
	return nil
end

-- a469 : $/s posé par le serveur sur le Tool d'un autre joueur ; nil s'il manque ou n'est pas un nombre positif fini.
local function attributeIncome(tool: Tool): number?
	local value = tool:GetAttribute(HeldItem.IncomeAttribute)
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return value
end

local function write(view: View)
	local income = if view.player == localPlayer then inventoryIncome(view.uid) else attributeIncome(view.tool)
	local label = view.label
	if label and income ~= nil then
		local text = string.format(CONF.Text, Format.money(income))
		if label.Text ~= text then
			label.Text = text
		end
	end
	view.gui.Enabled = income ~= nil
end

local function writeLocal()
	for _, view in views do
		if view.player == localPlayer then
			write(view)
		end
	end
end

local function place(view: View, handle: BasePart)
	view.offset = topAbove(view.tool, handle)
	view.gui.StudsOffsetWorldSpace = Vector3.new(0, view.offset + CONF.Above, 0)
end

local function detach(tool: Tool)
	local view = views[tool]
	if view == nil then
		return
	end
	views[tool] = nil
	for _, connection in view.connections do
		connection:Disconnect()
	end
	table.clear(view.connections)
	view.gui:Destroy()
end

-- Tous les billboards d'un joueur (nouvel objet en main, nouveau personnage, départ).
local function detachPlayer(player: Player)
	local tools = {}
	for tool, view in views do
		if view.player == player then
			table.insert(tools, tool)
		end
	end
	for _, tool in tools do
		detach(tool)
	end
end

local function attach(player: Player, tool: Tool)
	local uid = tool:GetAttribute(HeldItem.ToolAttribute)
	local handle = tool:FindFirstChild(HANDLE)
	if type(uid) ~= "string" or handle == nil or not handle:IsA("BasePart") then
		return
	end
	detachPlayer(player) -- un seul objet en main par joueur : un seul billboard
	local gui = billboard()
	gui.Name = CONF.Name
	gui.Adornee = handle
	local found = Find.path(gui, CONF.Label)
	local view: View = {
		player = player,
		tool = tool,
		uid = uid,
		gui = gui,
		label = if found and found:IsA("TextLabel") then found :: TextLabel else nil,
		offset = 0,
		pending = false,
		connections = {},
	}
	views[tool] = view
	place(view, handle :: BasePart)
	-- Pièces de l'objet arrivées après le Tool (réplication) : la hauteur est recalculée, une fois par image au plus.
	table.insert(
		view.connections,
		tool.DescendantAdded:Connect(function(inst: Instance)
			if views[tool] ~= view or view.pending or not inst:IsA("BasePart") then
				return
			end
			view.pending = true
			task.defer(function()
				view.pending = false
				if views[tool] == view then
					place(view, handle :: BasePart)
				end
			end)
		end)
	)
	if player ~= localPlayer then
		table.insert(
			view.connections,
			tool:GetAttributeChangedSignal(HeldItem.IncomeAttribute):Connect(function()
				if views[tool] == view then
					write(view)
				end
			end)
		)
	end
	write(view)
	gui.Parent = tool
end

local function isHeld(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute(HeldItem.ToolAttribute) ~= nil
end

local function watchCharacter(player: Player, character: Model)
	local connections = characterConnections[player]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	else
		connections = {}
		characterConnections[player] = connections
	end
	local list = connections :: { RBXScriptConnection }
	detachPlayer(player)
	table.insert(
		list,
		character.ChildAdded:Connect(function(child: Instance)
			if isHeld(child) then
				attach(player, child :: Tool)
			end
		end)
	)
	table.insert(
		list,
		character.ChildRemoved:Connect(function(child: Instance)
			if child:IsA("Tool") then
				detach(child :: Tool)
			end
		end)
	)
	for _, child in character:GetChildren() do
		if isHeld(child) then
			attach(player, child :: Tool)
		end
	end
end

-- a469 : joueur parti : ses connexions et ses billboards.
local function forget(player: Player)
	local connections = characterConnections[player]
	characterConnections[player] = nil
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	detachPlayer(player)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character)
	end
end

function HeldIncomeController.GetState(): { Shown: boolean, Uid: string?, Text: string?, Offset: number? }
	for _, view in views do
		if view.player == localPlayer then
			local label = view.label
			return {
				Shown = view.gui.Enabled and view.gui.Parent ~= nil,
				Uid = view.uid,
				Text = if label then label.Text else nil,
				Offset = view.offset,
			}
		end
	end
	return { Shown = false }
end

-- a469 : un billboard par objet tenu, chez tous les joueurs suivis (le joueur local seul si IncomeForAll est coupé).
function HeldIncomeController.GetViews(): { { Player: string, Uid: string, Shown: boolean, Text: string? } }
	local out = {}
	for _, view in views do
		local label = view.label
		table.insert(out, {
			Player = view.player.Name,
			Uid = view.uid,
			Shown = view.gui.Enabled and view.gui.Parent ~= nil,
			Text = if label then label.Text else nil,
		})
	end
	return out
end

function HeldIncomeController.Start()
	local module = script.Parent:FindFirstChild("InventoryController")
	if module and module:IsA("ModuleScript") then
		local ok, api = pcall(require, module)
		if ok and type(api) == "table" then
			inventory = api :: any
		end
	end
	local api = inventory
	if api then
		api.OnChanged(writeLocal)
	elseif IS_STUDIO then
		warn("[HeldIncomeController] InventoryController absent : pas de revenu au-dessus de l'objet en main")
	end
	if FOR_ALL then
		Players.PlayerAdded:Connect(watchPlayer)
		Players.PlayerRemoving:Connect(forget)
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
	else
		watchPlayer(localPlayer)
	end
end

return HeldIncomeController
