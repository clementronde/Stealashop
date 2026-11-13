-- Antivol dans l'UI : chaînes en X et cadenas sur la carte d'un objet sous antivol (Clément, 2026-11-13).
-- À lancer en Edit. Annulable avec Ctrl+Z. Aucun script. Relançable.
--
-- Modèle : ReplicatedStorage/Assets/UI/AntiTheftOverlay (Frame). Copies cachées, nommées `AntiTheft` :
--   UI_Inventory …ItemsSection.Cards.Template.AntiTheft  (sur l'icône, avec LockLabel « LOCKED »)
--   UI_Hotbar.Bar.Template.AntiTheft                     (sur l'icône, LockLabel caché : trop petit)
-- Contenu : Dim (voile sombre), ChainA et ChainB (maillons Link_01..11), Padlock (Shackle, Body,
-- Keyhole, KeySlot), LockLabel. Le code ne touche qu'à Visible et à LockLabel.Text.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local STEEL = Color3.fromRGB(201, 208, 217)
local DARK = Color3.fromRGB(30, 32, 40)

local recording = ChangeHistoryService:TryBeginRecording("AntiTheft UI")

local function need(parent: Instance, path: string): any
	local current: Instance = parent
	for segment in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(segment)
		assert(child, segment .. " introuvable dans " .. current:GetFullName())
		current = child
	end
	return current
end

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, r: number)
	new("UICorner", { CornerRadius = UDim.new(r, 0) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	new("UIStroke", {
		Color = color,
		Thickness = thickness,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

local function buildChain(name: string, rotation: number, parent: Instance)
	local chain = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.05, 0.13),
		Rotation = rotation,
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	}, chain)
	for i = 1, 11 do
		local isRing = i % 2 == 1
		local link = new("Frame", {
			Name = string.format("Link_%02d", i),
			LayoutOrder = i,
			Size = if isRing then UDim2.fromScale(0.1, 1) else UDim2.fromScale(0.075, 0.38),
			BackgroundColor3 = STEEL,
			BackgroundTransparency = if isRing then 1 else 0,
			ZIndex = 15,
		}, chain)
		corner(link, 0.5)
		stroke(link, if isRing then STEEL else DARK, if isRing then 0.22 else 0.18)
	end
end

-- Modèle
local uiAssets = need(ReplicatedStorage, "Assets.UI")
local old = uiAssets:FindFirstChild("AntiTheftOverlay")
if old then
	old:Destroy()
end
local overlay = new("Frame", {
	Name = "AntiTheftOverlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 14,
})
local dim = new("Frame", {
	Name = "Dim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(12, 14, 26),
	BackgroundTransparency = 0.45,
	ZIndex = 14,
}, overlay)
corner(dim, 0.08)
buildChain("ChainA", 30, overlay)
buildChain("ChainB", -30, overlay)

local padlock = new("Frame", {
	Name = "Padlock",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.5, 0.62),
	BackgroundTransparency = 1,
	ZIndex = 17,
}, overlay)
new("UIAspectRatioConstraint", { AspectRatio = 0.9 }, padlock)
local shackle = new("Frame", {
	Name = "Shackle",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.02),
	Size = UDim2.fromScale(0.6, 0.66),
	BackgroundTransparency = 1,
	ZIndex = 17,
}, padlock)
corner(shackle, 0.5)
stroke(shackle, STEEL, 0.17)
local body = new("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromScale(1, 0.62),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 18,
}, padlock)
corner(body, 0.2)
stroke(body, Color3.new(0, 0, 0), 0.07)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(255, 214, 82), Color3.fromRGB(226, 150, 20)),
}, body)
local keyhole = new("Frame", {
	Name = "Keyhole",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromScale(0.24, 0.36),
	BackgroundColor3 = DARK,
	ZIndex = 19,
}, body)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, keyhole)
corner(keyhole, 0.5)
new("Frame", {
	Name = "KeySlot",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.09, 0.32),
	BackgroundColor3 = DARK,
	BorderSizePixel = 0,
	ZIndex = 19,
}, body)

local lockLabel = new("TextLabel", {
	Name = "LockLabel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.99),
	Size = UDim2.fromScale(0.8, 0.17),
	BackgroundTransparency = 1,
	FontFace = FONT,
	Text = "LOCKED",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextWrapped = true,
	ZIndex = 19,
}, overlay)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 0.12, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize }, lockLabel)
overlay.Parent = uiAssets

-- Copies dans les cartes
-- zIndex : UI_Inventory est en ZIndexBehavior Global (le voile passe sous HoverOutline 20 et
-- CardAlert 21) ; UI_Hotbar est en Sibling (le voile passe entre Icon 5 et Equipped 7).
local function place(card: Instance, size: UDim2, showLabel: boolean, zIndex: number?)
	local existing = card:FindFirstChild("AntiTheft")
	if existing then
		existing:Destroy()
	end
	local copy = overlay:Clone()
	copy.Name = "AntiTheft"
	copy.Size = size
	copy.Position = UDim2.fromScale(0, 0)
	need(copy, "LockLabel").Visible = showLabel
	if zIndex then
		copy.ZIndex = zIndex
	end
	copy.Parent = card
end

place(need(StarterGui, "UI_Inventory.Root.Window.List.ItemsSection.Cards.Template"), UDim2.fromScale(1, 0.47), true)
place(need(StarterGui, "UI_Hotbar.Bar.Template"), UDim2.fromScale(1, 0.76), false, 6)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("AntiTheftOverlay construit et posé (caché) dans UI_Inventory et UI_Hotbar")
