--!nonstrict
-- ui_crate_tooltip.luau (Clément, 2026-11-24 : « au hover des objets 30 %, etc., faut qu'on voie combien ça gagne
-- par seconde ») : à lancer en Edit.
-- Caisse exclusive de UI_RobuxShop_v2 (Root.Window.List.Content.Crate) : chaque case Odds.Odd_n (un objet de
-- Monetization.Crate.Items, sa chance dans Chance) reçoit une bulle Tooltip, cachée, posée au-dessus de l'objet
-- (Clément : « la bulle va au-dessus, pas en dessous », puis « moins gros, ça doit faire la largeur de la case de
-- l'item ») : juste au-dessus de l'objet, de la largeur de sa case, elle passe sur la chance le temps du survol :
--   Tooltip (Frame : fond sombre, contour noir, petite pointe vers la case)
--     ItemName (TextLabel : le nom de l'objet, « Golden Rocket », couleur de sa rareté écrite par le code)
--     Income   (TextLabel vert : « +$12.5K/s », écrit par le code)
-- Le code la montre au survol de la case (ou au toucher sur téléphone) et la cache en sortant. Noms nouveaux, à
-- ajouter au contrat (facultatifs). Aucun nom existant changé, aucun script.
-- PREVIEW = true : rien ne change ; une copie de la boutique avec la bulle de Odd_3 montrée est posée dans StarterGui
-- (_PREVIEW_CLAUDE_Crate, non archivable, à détruire). PREVIEW = false : la boutique change (sauvegarde
-- ServerStorage/MapBackups/2026-11-24_BulleCaisse).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local DARK = Color3.fromHex("#1B1B24")
local GREEN = Color3.fromHex("#4BE04F")
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

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

local function text(label, value, color, x, y, w, h, z)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = false
	label.TextWrapped = true
	label.TextScaled = true
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(w, h)
	label.ZIndex = z
	local s = child(label, "UIStroke", "UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = 0.12
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
end

local function tooltip(odd, z)
	local tip = child(odd, "Frame", "Tooltip")
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.fromScale(0.5, 0.04)
	tip.Size = UDim2.fromScale(1, 0.5)
	tip.BackgroundColor3 = DARK
	tip.BackgroundTransparency = 0.05
	tip.BorderSizePixel = 0
	tip.Visible = false -- le code la montre au survol
	tip.ZIndex = z + 2 -- l'écran est en ZIndex Global : au-dessus de tout le reste de la boutique
	child(tip, "UICorner", "UICorner").CornerRadius = UDim.new(0.12, 0)
	local stroke = child(tip, "UIStroke", "UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 0.04
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	-- pointe vers la case : un carré tourné de 45°, à moitié caché sous la bulle
	local tail = child(tip, "Frame", "Tail")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.5, 1)
	tail.Size = UDim2.fromScale(0.2, 0.26)
	local ar = child(tail, "UIAspectRatioConstraint", "UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	tail.Rotation = 45
	tail.BackgroundColor3 = DARK
	tail.BorderSizePixel = 0
	tail.ZIndex = z + 1
	text(child(tip, "TextLabel", "ItemName"), "ITEM NAME", Color3.new(1, 1, 1), 0.5, 0.1, 0.9, 0.36, z + 3)
	text(child(tip, "TextLabel", "Income"), "+$0/s", GREEN, 0.5, 0.5, 0.9, 0.4, z + 3)
end

local function apply(gui)
	local odds = gui.Root.Window.List.Content.Crate.Odds
	local z = 0
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") and not d:IsDescendantOf(odds) then
			z = math.max(z, d.ZIndex)
		end
	end
	local n = 0
	for _, odd in odds:GetChildren() do
		if odd:IsA("GuiObject") and odd.Name:match("^Odd_%d+$") then
			tooltip(odd, z)
			n += 1
		end
	end
	return n
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Crate")
	if old then
		old:Destroy()
	end
	local copy = SG.UI_RobuxShop_v2:Clone()
	copy.Name = "_PREVIEW_CLAUDE_Crate"
	copy.Archivable = false
	copy.Enabled = true
	copy.DisplayOrder = 200
	apply(copy)
	local odd = copy.Root.Window.List.Content.Crate.Odds.Odd_6
	odd.Tooltip.Visible = true
	odd.Tooltip.ItemName.Text = "GOLDEN PLANET"
	odd.Tooltip.Income.Text = "+$5M/s"
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : bulle de revenu sur les cases de la caisse exclusive")
local count
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_BulleCaisse")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_BulleCaisse"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_RobuxShop_v2") then
		SG.UI_RobuxShop_v2:Clone().Parent = backups
	end
	count = apply(SG.UI_RobuxShop_v2)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_RobuxShop_v2 : " .. tostring(count) .. " bulles"
