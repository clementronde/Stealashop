--!strict
-- L-203, points 1 et 4 (2026-11-16) : règles des coins et des boutons validées dans Figma, posées sur les écrans
-- du HUD (page 30), de l'index (page 20) et des boutiques (page 10), sans changer un seul nom.
--   - Coins droits partout (aucun UICorner), sauf les boutons pour payer (UICorner 0,12 de la hauteur) et les
--     pastilles rondes « ! » (*Alert), qui restent rondes comme dans Figma.
--   - Boutons : UIGradient vertical 3 tons (haut +22 %, couleur à 45 %, bas −12 %), reflet doux (Shine ou Gloss :
--     blanc 38 % → 0 sur la moitié haute), UIStroke de bord de la couleur foncée de 25 % à 65 % d'opacité, studs
--     teintés à 45 % d'opacité (pas de mode Overlay dans Roblox), aucune ombre (Shadow et CardShadow retirés).
--     La couleur du bouton vient de Figma (BASE) ; sinon, du haut de son ancien dégradé.
--   - Attributs d'animation (lus par le module d'Ironix, a189), seulement là où il n'y en a pas déjà :
--     Root Appear=Pop, Title Appear=Stamp, listes qui défilent Appear=Cascade, boutons Hover=Pop et Press=Squash,
--     cartes (Template, Preview_*) Hover=Pop.
-- Les dégradés, contours et calques gardent leurs noms et leur place : le code en lit certains (Shade, UIGradient).
-- Relançable. Copie de chaque écran avant retouche dans ServerStorage/MapBackups/2026-11-16_L203.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local SCREENS = { "UI_HUD", "UI_Index_v3", "UI_Displayed", "UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2" }
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local STUDS = "rbxassetid://3014551673"

-- Couleur à 45 % des boutons dans Figma (pages 10 et 30).
local BASE: { [string]: string } = {
	RobuxShopButton = "8cf54a",
	IndexButton = "6cc2ff",
	SkillTreeButton = "ff7a6b",
	RebirthButton = "d88bff",
	DisplayedButton = "ffe36b",
	SleepButton = "8a97ff",
	DropButton = "ff5a6e",
	RewardsButton = "ff94d6",
	InviteButton = "6beaff",
	SettingsButton = "d3d8e2",
	CloseButton = "e83136",
	RobuxButton = "b34ce5",
	EquipButton = "6ddf3e",
	BuyButton3 = "ffb21f",
}
-- Boutons du HUD (page 30) : Figma y fonce bien plus le bas que −12 % ; on reprend ses 3 tons exacts.
local HUD_TONES: { [string]: { string } } = {
	RobuxShopButton = { "a5f772", "8cf54a", "2fab1b" },
	IndexButton = { "8ccfff", "6cc2ff", "2862c5" },
	SkillTreeButton = { "ff978c", "ff7a6b", "c52b37" },
	RebirthButton = { "e1a5ff", "d88bff", "7d34c5" },
	DisplayedButton = { "ffe98c", "ffe36b", "d5880b" },
	SleepButton = { "a4aeff", "8a97ff", "34289f" },
	DropButton = { "ff7e8e", "ff5a6e", "bf1c33" },
	RewardsButton = { "ffacdf", "ff94d6", "c53d88" },
	InviteButton = { "8cefff", "6beaff", "1a8dc5" },
	SettingsButton = { "dde1e8", "d3d8e2", "79818f" },
}
local BUY_BY_SCREEN: { [string]: string } = {
	UI_WeaponShop = "6ddf3e",
	UI_AuraShop = "6ddf3e",
	UI_RobuxShop = "4fe03a",
	UI_RobuxShop_v2 = "4fe03a",
}
local PAY_NAMES = { BuyButton = true, BuyButton1 = true, BuyButton2 = true, BuyButton3 = true, RobuxButton = true, SpeedBoostButton = true, SleepButton = true }

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end
local function darken(c: Color3, k: number): Color3
	return c:Lerp(BLACK, k)
end

local function isPay(b: GuiButton): boolean
	if PAY_NAMES[b.Name] then
		return true
	end
	return b:FindFirstChild("Price", true) ~= nil or b:FindFirstChild("RobuxPrice", true) ~= nil
end

local function setCorner(o: Instance, scale: number?)
	local c = o:FindFirstChildOfClass("UICorner")
	if scale == nil then
		if c then
			c:Destroy()
		end
		return
	end
	if not c then
		c = Instance.new("UICorner")
		c.Parent = o
	end
	(c :: UICorner).CornerRadius = UDim.new(scale :: number, 0)
end

local stats = { buttons = 0, payButtons = 0, cornersRemoved = 0, shadows = 0, attrs = 0, glossMade = 0, studsMade = 0 }

local function setAttr(o: Instance, name: string, value: string)
	if o:GetAttribute(name) == nil then
		o:SetAttribute(name, value)
		stats.attrs += 1
	end
end

local function styleButton(screen: string, b: GuiButton)
	local fill = b:FindFirstChild("Fill")
	local target: GuiObject = b
	if fill and fill:IsA("GuiObject") and fill:FindFirstChildOfClass("UIGradient") then
		target = fill
	end
	local g = target:FindFirstChildOfClass("UIGradient")
	if not g then
		return -- bouton transparent (onglet à icône, carte d'index) : pas de fond à habiller
	end
	stats.buttons += 1
	local keys = g.Color.Keypoints
	local rainbow = #keys > 2 and BASE[b.Name] == nil and b.Name ~= "BuyButton"
	local hex = BASE[b.Name] or (if b.Name == "BuyButton" then BUY_BY_SCREEN[screen] else nil)
	local base = if hex then Color3.fromHex(hex) else keys[1].Value
	local tones = if screen == "UI_HUD" then HUD_TONES[b.Name] else nil
	if rainbow then
		base = keys[math.ceil(#keys / 2)].Value
	elseif tones then
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex(tones[1])),
			ColorSequenceKeypoint.new(0.45, Color3.fromHex(tones[2])),
			ColorSequenceKeypoint.new(1, Color3.fromHex(tones[3])),
		})
		g.Rotation = 90
		g.Transparency = NumberSequence.new(0)
	else
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, lighten(base, 0.22)),
			ColorSequenceKeypoint.new(0.45, base),
			ColorSequenceKeypoint.new(1, darken(base, 0.12)),
		})
		g.Rotation = 90
		g.Transparency = NumberSequence.new(0)
	end
	target.BackgroundColor3 = WHITE
	target.BackgroundTransparency = 0

	-- contour de bord : couleur foncée de 25 %, 65 % d'opacité
	local stroke: UIStroke? = nil
	local prevOutline = target:FindFirstChild("Outline")
	local strokeHolders: { Instance } = if prevOutline then { prevOutline, target } else { target }
	for _, s in (strokeHolders[1] :: Instance):GetChildren() do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			stroke = s
			break
		end
	end
	for _, s in (if stroke then {} else target:GetChildren()) do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			stroke = s
			break
		end
	end
	if not stroke then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		s.Thickness = 0.06
		s.Parent = target
		stroke = s
	end
	-- Retours de Clément du 2026-11-16 : boutons pour payer et Claim = contour noir ; les autres = contour en
	-- dégradé (chaque ton du bouton foncé de 25 %, à 65 %), dessiné à l'intérieur du bouton comme dans Figma.
	local pay = isPay(b)
	local st = stroke :: UIStroke
	local oldStrokeGradient = st:FindFirstChildOfClass("UIGradient")
	if oldStrokeGradient then
		oldStrokeGradient:Destroy()
	end
	-- coins ronds sur le contour d'un bouton arrondi (pour payer), sinon il garde des angles droits
	st.LineJoinMode = if pay then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter
	if pay then
		-- noir plein, sur un cadre Outline au-dessus du reflet et des studs (qui l'éclaircissaient), coins ronds
		local outline = target:FindFirstChild("Outline")
		if not outline then
			local o = Instance.new("Frame")
			o.Name = "Outline"
			o.BackgroundTransparency = 1
			o.BorderSizePixel = 0
			o.Size = UDim2.fromScale(1, 1)
			local top = target.ZIndex
			for _, d in target:GetDescendants() do
				if d:IsA("GuiObject") then
					top = math.max(top, d.ZIndex)
				end
			end
			o.ZIndex = top + 1
			local oc = Instance.new("UICorner")
			oc.CornerRadius = UDim.new(0.12, 0)
			oc.Parent = o
			o.Parent = target
			outline = o
		end
		st.Parent = outline
		st.Color = BLACK
		st.Transparency = 0
		st.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	elseif string.find(b.Name, "Claim") then
		st.Color = Color3.fromHex("15151d")
		st.Transparency = 0
	else
		st.Color = WHITE
		st.Transparency = 0.35
		st.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		local strokeKeys = {}
		for _, k in g.Color.Keypoints do
			table.insert(strokeKeys, ColorSequenceKeypoint.new(k.Time, darken(k.Value, 0.25)))
		end
		local sg = Instance.new("UIGradient")
		sg.Name = "StrokeGradient"
		sg.Color = ColorSequence.new(strokeKeys)
		sg.Rotation = g.Rotation
		sg.Parent = st
	end

	-- coins : 0,12 pour payer, sinon droits ; les calques qui couvrent tout le bouton suivent
	if pay then
		stats.payButtons += 1
	end
	local r = if pay then 0.12 else nil
	setCorner(b, if target == b then r else nil)
	if target ~= b then
		setCorner(target, r)
	end
	for _, holder in { b, target } do
		for _, c in holder:GetChildren() do
			if c:IsA("GuiObject") and (c.Name == "Shade" or c.Name == "Studs" or c.Name == "Shine" or c.Name == "Gloss") then
				setCorner(c, r)
			end
		end
	end

	-- aucune ombre
	local shadow = b:FindFirstChild("Shadow")
	if shadow and shadow:IsA("Frame") then
		shadow:Destroy()
		stats.shadows += 1
	end

	-- reflet doux sur la moitié haute
	local glossObj = target:FindFirstChild("Shine") or target:FindFirstChild("Gloss") or b:FindFirstChild("Shine") or b:FindFirstChild("Gloss")
	if not (glossObj and glossObj:IsA("Frame")) then
		local f = Instance.new("Frame")
		f.Name = "Gloss"
		f.BorderSizePixel = 0
		f.ZIndex = target.ZIndex
		f.Parent = target
		glossObj = f
		stats.glossMade += 1
		setCorner(f, r)
	end
	local gl = glossObj :: Frame
	gl.AnchorPoint = Vector2.new(0, 0)
	gl.Position = UDim2.new()
	gl.Size = UDim2.fromScale(1, 0.5)
	gl.Rotation = 0
	gl.BackgroundColor3 = WHITE
	gl.BackgroundTransparency = 0
	local gg = gl:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gg.Color = ColorSequence.new(WHITE)
	gg.Rotation = 90
	gg.Offset = Vector2.new()
	gg.Transparency = NumberSequence.new(0.62, 1)
	gg.Parent = gl
	-- reflet de la moitié de la hauteur : rayon doublé, sinon ses coins dépassent du contour en gris
	setCorner(gl, if r then r * 2 else nil)

	-- studs teintés à 45 %
	local studs = target:FindFirstChild("Studs") or b:FindFirstChild("Studs")
	if b.Name == "RobuxButton" or b:FindFirstChild("RobuxIcon", true) then
		-- pas de studs sur les boutons Robux (retour de Clément du 2026-11-16)
		if studs then
			studs:Destroy()
		end
		return
	end
	if not (studs and studs:IsA("ImageLabel")) then
		local s = Instance.new("ImageLabel")
		s.Name = "Studs"
		s.BackgroundTransparency = 1
		s.Image = STUDS
		s.ScaleType = Enum.ScaleType.Tile
		s.TileSize = UDim2.fromOffset(22, 22)
		s.Size = UDim2.fromScale(1, 1)
		s.ZIndex = target.ZIndex
		s.Parent = target
		studs = s
		stats.studsMade += 1
		setCorner(s, r)
	end
	local si = studs :: ImageLabel
	si.Visible = true
	si.ImageColor3 = base
	si.ImageTransparency = 0.75 -- à 0,55 ils ressortaient bien plus fort que l'Overlay de Figma (comparé côte à côte)
end

-- Sauvegarde
local backups = ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = ServerStorage
local folder = backups:FindFirstChild("2026-11-16_L203") or Instance.new("Folder")
folder.Name = "2026-11-16_L203"
folder.Parent = backups

-- Rail de gauche du HUD (Shop, Index, Upgrades) 30 % plus grand (retour de Clément du 2026-11-16), centre gardé.
local hud = StarterGui:FindFirstChild("UI_HUD")
local rail = hud and hud:FindFirstChild("LeftRail", true)
if rail and rail:IsA("GuiObject") then
	rail.Size = UDim2.fromScale(0.149, 0.308)
end

local report = {}
for _, name in SCREENS do
	local gui = StarterGui:FindFirstChild(name)
	if not (gui and gui:IsA("ScreenGui")) then
		table.insert(report, name .. " : absent")
		continue
	end
	local copy = gui:Clone()
	copy.Name = name .. "_avantRegles_" .. os.time()
	copy.Parent = folder

	local payTrees: { Instance } = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiButton") then
			styleButton(name, d)
			if isPay(d) then
				table.insert(payTrees, d)
			end
			if d.Name == "Template" then
				setAttr(d, "Hover", "Pop")
			else
				setAttr(d, "Hover", "Pop")
				setAttr(d, "Press", "Squash")
			end
		elseif d:IsA("Frame") and (d.Name == "CardShadow" or d.Name == "DropShadow") then
			d:Destroy()
			stats.shadows += 1
		end
	end

	-- coins droits hors des boutons pour payer (pastilles « ! » rondes gardées)
	local function inPay(o: Instance): boolean
		for _, p in payTrees do
			if o:IsDescendantOf(p) then
				return true
			end
		end
		return false
	end
	for _, c in gui:GetDescendants() do
		if c:IsA("UICorner") and c.Parent and not inPay(c) then
			local parentName = (c.Parent :: Instance).Name
			if not (string.find(parentName, "Alert$") and c.CornerRadius.Scale >= 0.4) then
				c:Destroy()
				stats.cornersRemoved += 1
			end
		end
	end

	-- attributs d'animation
	local root = gui:FindFirstChild("Root")
	if root and root:IsA("GuiObject") then
		setAttr(root, "Appear", "Pop")
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Title" then
			setAttr(d, "Appear", "Stamp")
		elseif d:IsA("ScrollingFrame") and (d:FindFirstChildOfClass("UIGridLayout") or d:FindFirstChildOfClass("UIListLayout")) then
			setAttr(d, "Appear", "Cascade")
		elseif d:IsA("Frame") and (d.Name == "Template" or string.find(d.Name, "^Preview_")) then
			setAttr(d, "Hover", "Pop")
		end
	end
	table.insert(report, name .. " : ok")
end

local summary = string.format(
	"[ui_l203_regles] %s | boutons habillés %d (pour payer %d), coins retirés %d, ombres retirées %d, reflets créés %d, studs créés %d, attributs posés %d",
	table.concat(report, ", "),
	stats.buttons,
	stats.payButtons,
	stats.cornersRemoved,
	stats.shadows,
	stats.glossMade,
	stats.studsMade,
	stats.attrs
)
print(summary)
return summary
