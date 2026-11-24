--!nonstrict
-- ui_achat_jaillit.luau (Clément, 2026-11-24 : « quand on appuie sur des boutons de buy, comme sur les boutons index,
-- upgrade et shop […], qu'il y ait plein de Robux qui partent du bouton ») : à lancer en Edit.
-- Gabarits cachés, dans UI_HUD.CashFly (à côté de CounterPop, le « +$X » vert des gains), que le code clone quand un
-- achat réussit :
--   SpendPop  TextLabel rouge « −$0 » : la somme dépensée, près du compteur d'argent (comme CounterPop, en rouge)
--   SpendBit  ImageLabel : l'icône d'argent du HUD (CashRow.CashIcon), petite, qui jaillit du bouton d'achat
--   RobuxBit  ImageLabel : l'icône Robux dorée, pour les achats en Robux (plus tard : pas de Robux au lancement)
-- Aucun nom existant changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-24_AchatJaillit.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local RED = Color3.fromHex("#FF4A4A")
local GOLD = Color3.fromHex("#FFD12E")

local function child(parent, class, name)
	local c = parent:FindFirstChild(name)
	if c and not c:IsA(class) then
		c:Destroy()
		c = nil
	end
	if not c then
		c = Instance.new(class)
		c.Name = name
		c.Parent = parent
	end
	return c
end

local function bit(parent, name, image, color)
	local b = child(parent, "ImageLabel", name)
	b.Image = image
	b.ImageColor3 = color or Color3.new(1, 1, 1)
	b.BackgroundTransparency = 1
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(34, 34) -- le code peut la grandir ou la réduire
	b.Visible = false
	b.ZIndex = 32
	local ar = child(b, "UIAspectRatioConstraint", "UIAspectRatioConstraint")
	ar.AspectRatio = 1
	return b
end

local function apply(hud)
	local fly = hud.CashFly
	local counter = fly.CounterPop
	local spend = fly:FindFirstChild("SpendPop") or counter:Clone()
	spend.Name = "SpendPop"
	spend.Text = "−$0"
	spend.TextColor3 = RED
	spend.Visible = false
	spend.Parent = fly
	local cashIcon = hud.BottomLeft.StatsPanel.CashRow.CashIcon.IconImage.Image
	bit(fly, "SpendBit", cashIcon)
	local robux = bit(fly, "RobuxBit", hud.RightRail.SpeedBoostButton.Price.RobuxIcon.Image, GOLD)
	-- bord sombre de l'icône Robux, comme le prix des boutons du HUD (L-303)
	local edge = child(robux, "ImageLabel", "Edge")
	edge.Image = robux.Image
	edge.ImageColor3 = Color3.fromHex("#2A1A05")
	edge.BackgroundTransparency = 1
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Position = UDim2.fromScale(0.5, 0.5)
	edge.Size = UDim2.fromScale(1.22, 1.22)
	edge.ZIndex = 31
end

local rec = CHS:TryBeginRecording("UI : gabarits des achats (SpendPop, SpendBit, RobuxBit)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_AchatJaillit")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_AchatJaillit"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_HUD") then
		SG.UI_HUD:Clone().Parent = backups
	end
	apply(SG.UI_HUD)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD.CashFly : SpendPop, SpendBit, RobuxBit"
