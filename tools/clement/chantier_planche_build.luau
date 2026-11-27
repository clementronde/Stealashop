--!strict
--[[
Chantier du magasin PNJ casse par un objet geant (idee de Clement du 26/11, paquet-casse-objet-geant.md) : PLANCHE
a montrer avant le reste. Un ouvrier, la pancarte « UNDER CONSTRUCTION » et un troncon de ruban de chantier.
Tout est construit dans ServerStorage/Previews/CHANTIER (rien dans la map, aucun nom au contrat : les noms sont
proposes a Cantin dans le paquet). Aucun script. Rejouable : remplace le dossier CHANTIER.
Methode des agents de la boutique (shop_guards_build.luau) : rig R15 standard de Roblox, couleurs du corps,
accessoires ACC_* en pieces soudees (Accessory, Handle et attache du corps), dossier Animations VIDE pour le chef
animation (noms proposes : Idle, Hammer, Screw, Walk).
  NPC_Worker_01                ouvrier : casque de chantier jaune, gilet orange a bandes, ceinture a outils (tournevis
                               et boite de vis), petit marteau dans la main droite
  ENV_Construction_Sign        pancarte 12 x 3,6 studs, rayures jaune et noir sur le cadre, texte sur un SurfaceGui
  ENV_Construction_Tape        troncon de ruban de 8 studs a rayures jaune et noir (le code le repete ou l'etire en X)
Police de la pancarte : celle des enseignes « YOUR SHOP » (chef UI, 26/11), blanc a contour noir epais.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- valeurs du chef UI (26/11) : celles des enseignes « YOUR SHOP », contour qui suit la taille du texte comme les titres
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local TEXT_COLOR = Color3.fromHex("F5F6F8")
local STROKE_COLOR = Color3.fromHex("0D0D14")
local YELLOW = "F7C51E"
local BLACK = "1A1A1F"

type PartDef = {
	name: string,
	shape: string?,
	size: { number },
	pos: { number },
	rot: { number }?,
	color: string,
	material: string?,
}
type AccDef = { name: string, attach: string, type: string, parts: { PartDef } }

local previews = ServerStorage:FindFirstChild("Previews") or Instance.new("Folder")
previews.Name = "Previews"
previews.Parent = ServerStorage
local oldFolder = previews:FindFirstChild("CHANTIER")
if oldFolder then
	oldFolder:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "CHANTIER"

local report: { string } = {}

-- ===== ouvrier =====
local function angles(r: { number }?): CFrame
	local v = r or { 0, 0, 0 }
	return CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end
local function offset(p: PartDef): CFrame
	return CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * angles(p.rot)
end
local function makePart(p: PartDef, isHandle: boolean): Part
	local part = Instance.new("Part")
	part.Name = if isHandle then "Handle" else p.name
	part.Shape = if p.shape == "Cylinder" then Enum.PartType.Cylinder elseif p.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
	part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
	part.Color = Color3.fromHex(p.color)
	part.Material = (Enum.Material :: any)[p.material or "SmoothPlastic"]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	return part
end
local function poseRest(model: Model, humanoid: Humanoid)
	local found = model:FindFirstChild("HumanoidRootPart")
	assert(found and found:IsA("BasePart"), "HumanoidRootPart absent du rig")
	local root = found :: BasePart
	root.CFrame = CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local a0, a1 = d.Attachment0 :: Attachment, d.Attachment1 :: Attachment
			table.insert(joints, { p0 = a0.Parent, p1 = a1.Parent, c0 = a0.CFrame, c1 = a1.CFrame })
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = d.C0, c1 = d.C1 })
		end
	end
	local placed = { [root] = true }
	local moved = true
	while moved do
		moved = false
		for _, j in joints do
			if placed[j.p0] and not placed[j.p1] then
				(j.p1 :: BasePart).CFrame = (j.p0 :: BasePart).CFrame * j.c0 * j.c1:Inverse()
				placed[j.p1] = true
				moved = true
			end
		end
	end
end
local function bodyAttachment(model: Model, name: string): Attachment?
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local a = child:FindFirstChild(name)
			if a and a:IsA("Attachment") then
				return a
			end
		end
	end
	return nil
end
local function addAccessory(model: Model, acc: AccDef)
	local attach = bodyAttachment(model, acc.attach)
	if attach == nil then
		table.insert(report, acc.name .. " : attache " .. acc.attach .. " absente")
		return
	end
	local bodyPart = attach.Parent :: BasePart
	local accessory = Instance.new("Accessory")
	accessory.Name = acc.name
	accessory.AccessoryType = (Enum.AccessoryType :: any)[acc.type]
	local handleOffset = offset(acc.parts[1])
	local handle: Part? = nil
	for i, p in acc.parts do
		local part = makePart(p, i == 1)
		local o = offset(p)
		part.CFrame = bodyPart.CFrame * o
		if i == 1 then
			handle = part
		else
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryPartWeld"
			weld.Part0 = handle
			weld.Part1 = part
			weld.C0 = handleOffset:Inverse() * o
			weld.Parent = part
		end
		part.Parent = accessory
	end
	local h = handle :: Part
	local handleAttach = Instance.new("Attachment")
	handleAttach.Name = acc.attach
	handleAttach.CFrame = handleOffset:Inverse() * attach.CFrame
	handleAttach.Parent = h
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = h
	weld.Part1 = bodyPart
	weld.C0 = handleAttach.CFrame
	weld.C1 = attach.CFrame
	weld.Parent = h
	accessory.Parent = model
end

local WORKER_ACC: { AccDef } = {
	{
		name = "ACC_Worker_HardHat",
		attach = "HatAttachment",
		type = "Hat",
		parts = {
			{ name = "Dome", size = { 1.3, 0.55, 1.3 }, pos = { 0, 0.4, 0 }, color = YELLOW },
			{ name = "Top", size = { 1.0, 0.2, 1.0 }, pos = { 0, 0.75, 0 }, color = YELLOW },
			{ name = "Ridge", size = { 0.24, 0.16, 1.24 }, pos = { 0, 0.88, 0 }, color = "E0AE12" },
			{ name = "Brim", size = { 1.5, 0.12, 1.66 }, pos = { 0, 0.16, -0.1 }, color = "E0AE12" },
			{ name = "Band", size = { 1.34, 0.12, 1.34 }, pos = { 0, 0.22, 0 }, color = BLACK },
		},
	},
	{
		name = "ACC_Worker_Gilet",
		attach = "BodyFrontAttachment",
		type = "Front",
		parts = {
			{ name = "FrontL", size = { 0.78, 1.5, 0.12 }, pos = { -0.5, -0.05, -0.55 }, color = "FF7A1A" },
			{ name = "FrontR", size = { 0.78, 1.5, 0.12 }, pos = { 0.5, -0.05, -0.55 }, color = "FF7A1A" },
			{ name = "Back", size = { 1.84, 1.5, 0.12 }, pos = { 0, -0.05, 0.55 }, color = "FF7A1A" },
			{ name = "SideL", size = { 0.1, 1.0, 1.1 }, pos = { -0.94, -0.3, 0 }, color = "FF7A1A" },
			{ name = "SideR", size = { 0.1, 1.0, 1.1 }, pos = { 0.94, -0.3, 0 }, color = "FF7A1A" },
			{ name = "StripeFront", size = { 1.86, 0.16, 0.04 }, pos = { 0, -0.35, -0.62 }, color = "DDE3EA", material = "Neon" },
			{ name = "StripeBack", size = { 1.86, 0.16, 0.04 }, pos = { 0, -0.35, 0.62 }, color = "DDE3EA", material = "Neon" },
			{ name = "StripeBack2", size = { 1.86, 0.16, 0.04 }, pos = { 0, 0.15, 0.62 }, color = "DDE3EA", material = "Neon" },
			{ name = "Pocket", size = { 0.34, 0.3, 0.05 }, pos = { -0.5, 0.2, -0.63 }, color = "E2650F" },
			{ name = "Pencil", size = { 0.06, 0.34, 0.06 }, pos = { -0.42, 0.42, -0.64 }, color = YELLOW },
		},
	},
	{
		name = "ACC_Worker_ToolBelt",
		attach = "WaistCenterAttachment",
		type = "Waist",
		parts = {
			{ name = "Belt", size = { 2.04, 0.2, 1.08 }, pos = { 0, 0.1, 0 }, color = "6B4422" },
			{ name = "Buckle", size = { 0.3, 0.22, 0.05 }, pos = { 0, 0.1, -0.56 }, color = "C9CED6", material = "Metal" },
			{ name = "PouchL", size = { 0.4, 0.5, 0.3 }, pos = { -0.8, -0.2, -0.45 }, color = "8A5A2E" },
			{ name = "PouchR", size = { 0.36, 0.44, 0.28 }, pos = { 0.82, -0.18, -0.4 }, color = "8A5A2E" },
			{ name = "ScrewdriverGrip", size = { 0.14, 0.34, 0.14 }, pos = { 0.82, 0.18, -0.42 }, color = "E23B3B" },
			{ name = "ScrewdriverShaft", size = { 0.05, 0.22, 0.05 }, pos = { 0.82, 0.44, -0.42 }, color = "C9CED6", material = "Metal" },
			{ name = "ScrewBox", size = { 0.3, 0.16, 0.22 }, pos = { -0.8, 0.12, -0.45 }, color = "3A7BD5" },
			{ name = "Screw", size = { 0.05, 0.12, 0.05 }, pos = { -0.86, 0.26, -0.45 }, color = "C9CED6", material = "Metal" },
			{ name = "Screw", size = { 0.05, 0.12, 0.05 }, pos = { -0.74, 0.26, -0.45 }, color = "C9CED6", material = "Metal" },
		},
	},
	{
		-- petit marteau dans la main droite (le code ou l'animation le fait taper)
		name = "ACC_Worker_Hammer",
		attach = "RightGripAttachment",
		type = "Unknown",
		parts = {
			{ name = "Grip", size = { 0.16, 0.16, 1.1 }, pos = { 0, -0.15, -0.35 }, color = "8A5A2E" },
			{ name = "Head", size = { 0.24, 0.24, 0.52 }, pos = { 0, -0.15, -0.95 }, rot = { 90, 0, 0 }, color = "5A6270", material = "Metal" },
			{ name = "Claw", size = { 0.16, 0.16, 0.2 }, pos = { 0, 0.07, -0.95 }, color = "5A6270", material = "Metal" },
		},
	},
}

do
	local desc = Instance.new("HumanoidDescription")
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok then
		table.insert(report, "ouvrier : rig impossible (" .. tostring(result) .. ")")
	else
		local model = result :: Model
		model.Name = "NPC_Worker_01"
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then
				d:Destroy()
			end
		end
		local foundHumanoid = model:FindFirstChildOfClass("Humanoid")
		assert(foundHumanoid, "Humanoid absent du rig")
		local humanoid = foundHumanoid :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if humanoid:FindFirstChildOfClass("Animator") == nil then
			Instance.new("Animator").Parent = humanoid
		end
		-- peau, t-shirt bleu jean, pantalon de travail bleu fonce, chaussures de securite marron
		local colors = {
			Head = "D9A066", UpperTorso = "3E6FB0", LowerTorso = "2C3E66",
			LeftUpperArm = "3E6FB0", RightUpperArm = "3E6FB0", LeftLowerArm = "D9A066", RightLowerArm = "D9A066",
			LeftHand = "D9A066", RightHand = "D9A066",
			LeftUpperLeg = "2C3E66", RightUpperLeg = "2C3E66", LeftLowerLeg = "2C3E66", RightLowerLeg = "2C3E66",
			LeftFoot = "5A3A1E", RightFoot = "5A3A1E",
		}
		for partName, hex in colors do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.Color = Color3.fromHex(hex)
			end
		end
		poseRest(model, humanoid)
		for _, acc in WORKER_ACC do
			addAccessory(model, acc)
		end
		local anims = Instance.new("Folder")
		anims.Name = "Animations" -- vide : le chef animation y pose Idle, Hammer, Screw, Walk
		anims.Parent = model
		local root = model.PrimaryPart :: BasePart
		model:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		model.Parent = folder
		table.insert(report, string.format("NPC_Worker_01 : %.2f studs de haut", model:GetExtentsSize().Y))
	end
end

-- ===== pieces de decor (ancrees, sans collision) =====
local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame, hex: string, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(hex)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function rootPart(model: Model, size: Vector3, cf: CFrame)
	local r = decor(model, "Root", size, cf, "FFFFFF")
	r.Transparency = 1
	model.PrimaryPart = r
	return r
end

-- ===== pancarte UNDER CONSTRUCTION =====
do
	local W, H, D, B = 12, 3.6, 0.4, 0.6 -- largeur, hauteur, epaisseur, bord a rayures
	local sign = Instance.new("Model")
	sign.Name = "ENV_Construction_Sign"
	local root = rootPart(sign, Vector3.new(W, 0.2, D), CFrame.new(0, 0.1, 0))
	root.PivotOffset = CFrame.new(0, -0.1, 0) -- pivot en bas au centre, face avant vers -Z
	local face = decor(sign, "Face", Vector3.new(W - 2 * B, H - 2 * B, D), CFrame.new(0, H / 2, 0), YELLOW)
	-- cadre a rayures : blocs alternes jaune / noir
	-- couleur selon la place du bloc (damier le long du cadre), pas selon l'ordre de creation
	local function stripe(x: number, y: number, sx: number, sy: number)
		local k = math.floor((x + W / 2) / B + 0.5) + math.floor(y / B + 0.5)
		decor(sign, "Frame", Vector3.new(sx, sy, D + 0.1), CFrame.new(x, y, 0), if k % 2 == 0 then YELLOW else BLACK)
	end
	local cols = math.floor(W / B + 0.5)
	for i = 0, cols - 1 do
		local x = -W / 2 + B / 2 + i * B
		stripe(x, H - B / 2, B, B)
		stripe(x, B / 2, B, B)
	end
	local rowsN = math.floor((H - 2 * B) / B + 0.5)
	for j = 0, rowsN - 1 do
		local y = B + B / 2 + j * B
		stripe(-W / 2 + B / 2, y, B, B)
		stripe(W / 2 - B / 2, y, B, B)
	end
	-- texte sur la face avant (-Z)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Print"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	label.Text = "UNDER CONSTRUCTION"
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = FONT
	label.TextColor3 = TEXT_COLOR
	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.10
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = face
	-- deux crochets en haut pour l'accrocher au rideau
	for _, x in { -W / 3, W / 3 } do
		decor(sign, "Hook", Vector3.new(0.3, 0.8, 0.3), CFrame.new(x, H + 0.4, 0), "5A6270", Enum.Material.Metal)
	end
	sign:PivotTo(CFrame.new(10, 0, 0))
	sign.Parent = folder
	table.insert(report, string.format("ENV_Construction_Sign : %d pieces, %.1f x %.1f x %.1f", #sign:GetChildren(), W, H + 0.8, D + 0.1))
end

-- ===== ruban de chantier =====
do
	local L, Wd, T, SEG = 8, 0.5, 0.06, 0.5
	local tape = Instance.new("Model")
	tape.Name = "ENV_Construction_Tape"
	local root = rootPart(tape, Vector3.new(L, Wd, T), CFrame.new(0, 0, 0))
	root.PivotOffset = CFrame.new()
	local segs = math.floor(L / SEG + 0.5)
	for i = 0, segs - 1 do
		local x = -L / 2 + SEG / 2 + i * SEG
		decor(tape, "Stripe", Vector3.new(SEG, Wd, T), CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, 0), if i % 2 == 0 then YELLOW else BLACK)
	end
	tape:PivotTo(CFrame.new(20, 3, 0))
	tape.Parent = folder
	table.insert(report, string.format("ENV_Construction_Tape : %d pieces, %.1f x %.1f x %.2f (pivot au centre, s'etire en X)", segs + 1, L, Wd, T))
end

folder.Parent = previews
print("[chantier] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
