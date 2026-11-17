--!strict
-- HeldIncomeController (vague 70, a230 ; liaison L-189, demande de Clément du 2026-11-15 ; client) : le revenu par
-- seconde de l'objet tenu en main, au-dessus de lui. Les cases de la barre du bas ne le montrent plus (texte de
-- Clément transparent).
--
--   - Objet en main = Tool du personnage local avec l'attribut HeldItemUid (HeldItemService, Config/HeldItem).
--     Une copie de ReplicatedStorage/Assets/UI/BB_HeldIncome de Clément (Config/Hud.HeldIncome ; absente : un
--     billboard de repli aux mêmes noms) va dans le Tool : Adornee = sa poignée Handle, StudsOffsetWorldSpace = haut
--     de l'objet au-dessus de la poignée (« moitié de sa hauteur », la poignée est en son centre) + HeldIncome.Above ;
--     le StudsOffset de Clément (0,6) s'y ajoute. Le halo de rareté (RarityHalo) ne compte pas dans la hauteur.
--   - Texte d'Income = celui des cases de la barre (« $1.2K/s » : $/s de l'objet, mutation comprise, calculé par le
--     serveur ; état d'InventoryController), réécrit à chaque changement de l'inventaire. Objet absent de
--     l'inventaire : billboard éteint (Enabled).
--   - Objet rangé (Tool sorti du personnage) : la copie est détruite. Elle part aussi avec le Tool.
-- Le joueur local seulement (L-189 : à voir avec Clément si les autres joueurs le voient aussi). Rien n'est envoyé
-- au serveur ; seuls la copie, son Adornee, son StudsOffsetWorldSpace, son Enabled et le texte d'Income sont touchés.
--
-- API (client ; Play, bancs) :
--   HeldIncomeController.GetState() -> { Shown: boolean, Uid: string?, Text: string?, Offset: number? }

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
type View = { tool: Tool, uid: string, gui: BillboardGui, label: TextLabel?, offset: number }

local CONF = HudConfig.HeldIncome
local HANDLE = "Handle" -- HeldItemService
local IS_STUDIO = RunService:IsStudio()

local HeldIncomeController = {}

local localPlayer = Players.LocalPlayer
local inventory: InventoryApi? = nil
local current: View? = nil
local characterConnections: { RBXScriptConnection } = {}
local toolConnection: RBXScriptConnection? = nil
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

local function incomeOf(uid: string): number?
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

local function write()
	local view = current
	if view == nil then
		return
	end
	local income = incomeOf(view.uid)
	local label = view.label
	if label and income ~= nil then
		local text = string.format(CONF.Text, Format.money(income))
		if label.Text ~= text then
			label.Text = text
		end
	end
	view.gui.Enabled = income ~= nil
end

local function place(view: View, handle: BasePart)
	view.offset = topAbove(view.tool, handle)
	view.gui.StudsOffsetWorldSpace = Vector3.new(0, view.offset + CONF.Above, 0)
end

local function detach()
	local view = current
	current = nil
	if toolConnection then
		toolConnection:Disconnect()
		toolConnection = nil
	end
	if view then
		view.gui:Destroy()
	end
end

local function attach(tool: Tool)
	local uid = tool:GetAttribute(HeldItem.ToolAttribute)
	local handle = tool:FindFirstChild(HANDLE)
	if type(uid) ~= "string" or handle == nil or not handle:IsA("BasePart") then
		return
	end
	detach()
	local gui = billboard()
	gui.Name = CONF.Name
	gui.Adornee = handle
	local found = Find.path(gui, CONF.Label)
	local view: View = {
		tool = tool,
		uid = uid,
		gui = gui,
		label = if found and found:IsA("TextLabel") then found :: TextLabel else nil,
		offset = 0,
	}
	current = view
	place(view, handle :: BasePart)
	-- Pièces de l'objet arrivées après le Tool : la hauteur est recalculée.
	toolConnection = tool.DescendantAdded:Connect(function(inst: Instance)
		if current == view and inst:IsA("BasePart") then
			place(view, handle :: BasePart)
		end
	end)
	write()
	gui.Parent = tool
end

local function isHeld(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute(HeldItem.ToolAttribute) ~= nil
end

local function watchCharacter(character: Model)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	detach()
	table.insert(
		characterConnections,
		character.ChildAdded:Connect(function(child: Instance)
			if isHeld(child) then
				attach(child :: Tool)
			end
		end)
	)
	table.insert(
		characterConnections,
		character.ChildRemoved:Connect(function(child: Instance)
			local view = current
			if view and view.tool == child then
				detach()
			end
		end)
	)
	for _, child in character:GetChildren() do
		if isHeld(child) then
			attach(child :: Tool)
		end
	end
end

function HeldIncomeController.GetState(): { Shown: boolean, Uid: string?, Text: string?, Offset: number? }
	local view = current
	if view == nil then
		return { Shown = false }
	end
	local label = view.label
	return {
		Shown = view.gui.Enabled and view.gui.Parent ~= nil,
		Uid = view.uid,
		Text = if label then label.Text else nil,
		Offset = view.offset,
	}
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
		api.OnChanged(write)
	elseif IS_STUDIO then
		warn("[HeldIncomeController] InventoryController absent : pas de revenu au-dessus de l'objet en main")
	end
	localPlayer.CharacterAdded:Connect(watchCharacter)
	local character = localPlayer.Character
	if character then
		watchCharacter(character)
	end
end

return HeldIncomeController
