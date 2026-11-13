-- Badges « ! » et bouton Claim All de l'Index (demande de Clément, 2026-11-13).
-- À lancer en Edit. Annulable avec Ctrl+Z. Aucun script dans l'UI. Relançable : il remplace ce
-- qu'il a déjà posé.
--
-- Badge : copie du style de UI_HUD.SocialRow.RewardsButton.RewardsAlert (pastille rouge, « ! » blanc
-- à contour noir), caché (Visible = false). Le code l'affiche quand le joueur a quelque chose à faire.
-- Modèle à cloner pour un futur bouton : ReplicatedStorage/Assets/UI/AlertBadge.
-- Chaque badge a un UIScale `Pulse` (Scale = 1) que le code peut animer.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local recording = ChangeHistoryService:TryBeginRecording("Badges ! et Claim All")

local function need(parent: Instance, path: string): any
	local current: Instance = parent
	for segment in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(segment)
		assert(child, segment .. " introuvable dans " .. current:GetFullName())
		current = child
	end
	return current
end

local function replace(parent: Instance, name: string)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- 1. Modèle du badge
local source = need(StarterGui, "UI_HUD.SocialRow.RewardsButton.RewardsAlert") :: Frame
if not source:FindFirstChild("Pulse") then
	local pulse = Instance.new("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = source
end
local uiAssets = need(ReplicatedStorage, "Assets.UI")
replace(uiAssets, "AlertBadge")
local master = source:Clone()
master.Name = "AlertBadge"
master.Visible = false
master.Parent = uiAssets

-- Pose un badge caché dans `parent`. `size` = côté du carré en part de la hauteur du parent
-- (la contrainte 1:1 le garde carré), `pos` = son centre.
local function badge(parent: Instance, name: string, pos: UDim2, size: number, z: number)
	replace(parent, name)
	local b = master:Clone()
	b.Name = name
	b.Visible = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = pos
	b.Size = UDim2.fromScale(1, size)
	b.ZIndex = z
	need(b, "AlertLabel").ZIndex = z + 1
	b.Parent = parent
	return b
end

-- 2. HUD : boutons de gauche (PC et téléphone)
local hud = need(StarterGui, "UI_HUD")
local railBadges = {
	IndexButton = "IndexAlert",
	InventoryButton = "InventoryAlert",
	RebirthButton = "RebirthAlert",
	SkillTreeButton = "SkillTreeAlert",
}
for buttonName, alertName in railBadges do
	badge(need(hud, "LeftRail." .. buttonName), alertName, UDim2.fromScale(0.975, 0.1), 0.62, 9)
	local touch = need(hud, "LeftRailTouch." .. buttonName)
	local b = badge(touch, alertName, UDim2.fromScale(0.86, 0.1), 0.36, 9)
	b.Size = UDim2.fromScale(0.36, 0.36)
end

-- 3. Index : Claim All dans la barre du compteur, et badges
local window = need(StarterGui, "UI_Index_v3.Root.Window")
local bar = need(window, "UnlockedBar")
local counter = need(bar, "Counter") :: TextLabel
counter.AnchorPoint = Vector2.new(0, 0.5)
counter.Position = UDim2.fromScale(0.19, 0.5)
counter.Size = UDim2.fromScale(0.43, 0.58)

replace(bar, "ClaimAllButton")
local claimAll = need(StarterGui, "UI_Offline.Root.Window.ClaimButton"):Clone() :: TextButton
claimAll.Name = "ClaimAllButton"
for _, d in claimAll:GetDescendants() do
	if d:IsA("UISizeConstraint") then
		d:Destroy()
	end
end
claimAll.AnchorPoint = Vector2.new(1, 0.5)
claimAll.Position = UDim2.fromScale(0.985, 0.5)
claimAll.Size = UDim2.fromScale(0.35, 1.04) -- 46 px de haut sur téléphone
claimAll.ZIndex = 4
local claimAllLabel = need(claimAll, "Content.ClaimLabel") :: TextLabel
claimAllLabel.Name = "ClaimAllLabel"
claimAllLabel.Text = "CLAIM ALL"
claimAllLabel.Size = UDim2.fromScale(0.84, 0.6)
for _, d in claimAll:GetDescendants() do
	if d:IsA("GuiObject") then
		d.ZIndex = 5
	end
end
need(claimAll, "Shade").ZIndex = 6
claimAll.Parent = bar
badge(claimAll, "ClaimAllAlert", UDim2.fromScale(0.97, 0.08), 0.62, 12)

badge(need(window, "Rewards.ClaimButton"), "ClaimAlert", UDim2.fromScale(0.97, 0.08), 0.75, 9)
for _, categoryName in { "NormalButton", "SecretsButton", "MutationsButton" } do
	badge(need(window.Parent :: Instance, "Categories." .. categoryName), "CategoryAlert", UDim2.fromScale(0.96, 0.12), 0.62, 9)
end
local list = need(window, "ListPanel.List")
for _, section in list:GetChildren() do
	local art = section:FindFirstChild("ZoneArt")
	if art then
		local b = badge(art, "ZoneAlert", UDim2.fromScale(0.86, 0.06), 0.36, 9)
		b.Size = UDim2.fromScale(0.36, 0.36)
	end
end

-- 4. Récompenses : onglets Daily et Playtime
for _, tabName in { "DailyTab", "PlaytimeTab" } do
	badge(need(StarterGui, "UI_Rewards.Root.Tabs." .. tabName), "TabAlert", UDim2.fromScale(0.95, 0.12), 0.55, 9)
end

-- 5. Cartes : barre du bas et inventaire (objet prêt à exposer, nouvel objet…)
local slot = need(StarterGui, "UI_Hotbar.Bar.Template")
local slotBadge = badge(slot, "SlotAlert", UDim2.fromScale(0.88, 0.12), 0.32, 9)
slotBadge.Size = UDim2.fromScale(0.32, 0.32)
for _, sectionName in { "ItemsSection", "BoxesSection" } do
	local card = need(StarterGui, "UI_Inventory.Root.Window.List." .. sectionName .. ".Cards.Template")
	-- dans la carte : la liste qui défile coupe ce qui dépasse
	local b = badge(card, "CardAlert", UDim2.fromScale(0.86, 0.1), 0.2, 21)
	b.Size = UDim2.fromScale(0.2, 0.2)
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("Badges ! posés (cachés) et ClaimAllButton ajouté à UI_Index_v3")
