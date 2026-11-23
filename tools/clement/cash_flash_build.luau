--[[
	cash_flash_build.luau (Clément, 2026-11-23) : le « jus » de l'encaissement sur une plaque CollectPad_xx.
	Relançable dans Studio (Edit, barre de commande ou execute_luau). Aucun script posé.

	Construit :
	1. StarterGui/UI_CashFlash : le voile vert sur les bords de l'écran, même recette que le bord rouge
	   de UI_TheftAlert (bandes en dégradé, aucune image à importer).
	     EdgeGlow (Frame plein écran, transparent : un simple conteneur)
	       Top, Bottom, Left, Right (Frame vert + UIGradient : opaque au bord, transparent vers le centre)
	   Les BackgroundTransparency posées ici sont le voile à son plus fort : le code part de là et va
	   jusqu'à 1. L'écran reste Enabled = false au repos. DisplayOrder -1 : sous UI_HUD (comme UI_Chase),
	   le compteur reste net par-dessus.
	2. ReplicatedStorage/Assets/Sounds/Cash/Cash_Pad : le « kaching » de chaque plaque vidée, joué à
	   l'arrivée du premier billet au compteur. Choix de Clément (2026-11-23) : le son de la vidéo
	   « Roblox Money - Sound Effect », un seul son, sans note qui monte (la première version, une note
	   qui monte et des billets comptés, était trop agressive). Cash_Collect (déjà là, autres gains)
	   n'est pas touché. Les anciens Cash_Combo et Cash_BillsIn de ce script sont retirés.
]]

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BUILT_BY = "cash_flash_build"
local GREEN = Color3.fromHex("5CFF4A") -- vert « Cash » du jeu (Config/UiMotion.FloatGain.Colors.Cash)
local PEAK = 0.25 -- transparence des bandes au plus fort du voile
local DEPTH_Y = 0.16 -- hauteur des bandes du haut et du bas (part de l'écran)
local DEPTH_X = 0.1 -- largeur des bandes de gauche et de droite

local report = {}

-- 1. UI_CashFlash ------------------------------------------------------------------------------
local old = StarterGui:FindFirstChild("UI_CashFlash")
if old and old:GetAttribute("BuiltBy") ~= BUILT_BY then
	error("UI_CashFlash existe déjà et n'a pas été fait par ce script : rien n'est remplacé")
end
if old then
	old:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = "UI_CashFlash"
screen.IgnoreGuiInset = true
screen.ScreenInsets = Enum.ScreenInsets.None
screen.DisplayOrder = -1
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Enabled = false
screen:SetAttribute("BuiltBy", BUILT_BY)

local glow = Instance.new("Frame")
glow.Name = "EdgeGlow"
glow.Size = UDim2.fromScale(1, 1)
glow.BackgroundTransparency = 1
glow.BorderSizePixel = 0
glow.Active = false
glow.Parent = screen

-- Dégradé d'une bande : opaque au bord de l'écran (Time 0), transparent vers le centre (Time 1).
local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.3, 0.35),
	NumberSequenceKeypoint.new(0.65, 0.8),
	NumberSequenceKeypoint.new(1, 1),
})

local function band(name: string, anchor: Vector2, position: UDim2, size: UDim2, rotation: number)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = GREEN
	f.BackgroundTransparency = PEAK
	f.BorderSizePixel = 0
	f.Active = false
	local g = Instance.new("UIGradient")
	g.Rotation = rotation -- 0 : gauche → droite ; 90 : haut → bas ; 180 : droite → gauche ; -90 : bas → haut
	g.Transparency = FADE
	g.Parent = f
	f.Parent = glow
end

band("Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, DEPTH_Y), 90)
band("Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, DEPTH_Y), -90)
band("Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(DEPTH_X, 1), 0)
band("Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(DEPTH_X, 1), 180)

screen.Parent = StarterGui
table.insert(report, "StarterGui/UI_CashFlash (EdgeGlow : Top, Bottom, Left, Right)")

-- 2. Sons -------------------------------------------------------------------------------------
local cashFolder = ReplicatedStorage.Assets.Sounds:FindFirstChild("Cash")
if not cashFolder then
	error("ReplicatedStorage/Assets/Sounds/Cash introuvable")
end

-- Anciens sons de ce script (première version, jugée trop agressive) : retirés.
for _, name in { "Cash_Combo", "Cash_BillsIn" } do
	local old = cashFolder:FindFirstChild(name)
	if old and old:GetAttribute("BuiltBy") == BUILT_BY then
		old:Destroy()
	end
end

local SOUNDS = {
	{
		Name = "Cash_Pad",
		Id = 111773238101465, -- « Cash Register Sound », kaching court (1 s) ; même sonnette (2,1 kHz) que la vidéo
		Volume = 0.5,
		Title = "Cash Register Sound (kaching court, 1 s), mis en ligne par WengerLylia_35",
		Role = "plaque CollectPad_xx vidée : à l'arrivée du premier billet au compteur",
	},
}

for _, spec in SOUNDS do
	local s = cashFolder:FindFirstChild(spec.Name)
	if s and not s:IsA("Sound") then
		error(spec.Name .. " existe mais n'est pas un Sound")
	end
	if not s then
		s = Instance.new("Sound")
		s.Name = spec.Name
		s.Parent = cashFolder
	end
	s.SoundId = "rbxassetid://" .. spec.Id
	s.Volume = spec.Volume
	s.PlaybackSpeed = spec.Speed or 1 -- le code multiplie cette valeur (comme ShatterController)
	s.Looped = false
	s:SetAttribute("Titre", spec.Title)
	s:SetAttribute("Role", spec.Role)
	s:SetAttribute("BuiltBy", BUILT_BY)
	table.insert(report, "Sounds/Cash/" .. spec.Name .. " = " .. s.SoundId)
end

return table.concat(report, "\n")
