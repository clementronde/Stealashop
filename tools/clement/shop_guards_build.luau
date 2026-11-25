--!strict
-- Constructeur des agents de défense de la boutique (L-311, MAJ 5) : NPC_Bodyguard (tuile Guards, l'agent qui
-- poursuit le voleur dans la boutique) et NPC_DoorGuard (tuile Door Guard, le videur qui repousse à la porte).
-- À lancer dans Studio en mode Edit (barre de commande ou MCP). Relançable : remplace les modèles et garde leur
-- dossier Animations déjà rempli.
--
-- Crée ReplicatedStorage/Assets/Guards/NPC_Bodyguard et NPC_DoorGuard, comme les vigiles (guards_builder.luau) :
-- rig R15 standard de Roblox (CreateHumanoidModelFromDescriptionAsync), Humanoid avec son Animator, couleurs du
-- corps, accessoires ACC_<Agent>_* en pièces (Accessory, Handle et attache du corps), aucun script, puis la taille
-- (Model:ScaleTo). Dossier Animations (contrat Animations.ShopGuard : Idle, Run, Catch avec le marqueur Impact) :
-- à la première construction, copie des objets Animation du vigile Guard_Z1 (animations du groupe déjà publiées).
-- L'agent garde le Catch des vigiles (le plongeon raccourci, Impact à 0,30 s). Le garde de la porte a son propre Catch
-- (catchId) : une poussée à deux mains, sans plongeon, Impact à 0,233 s (brouillon Guard_DoorShove de
-- RBX_ANIMSAVES/Rig_Guard, poses dans StealAShop-Art/Guards/_scripts/anim_defs.py ; publiée au nom du groupe le 24/11).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type PartDef = {
	name: string,
	shape: string?,
	size: { number },
	pos: { number },
	rot: { number }?,
	color: string,
	material: string?,
	reflectance: number?,
	transparency: number?,
}
type AccDef = {
	name: string,
	attach: string,
	type: string,
	parts: { PartDef },
	text: string?,
	textColor: string?,
	textPart: string?,
}
type AgentDef = {
	name: string,
	scale: number,
	catchId: string?, -- AnimationId de son Catch à la première construction (sinon celui du vigile Guard_Z1)
	body: { [string]: string },
	accessories: { AccDef },
}

local function bodyColors(head: string, torso: string, upperArm: string, lowerArm: string, hand: string, leg: string, foot: string): { [string]: string }
	return {
		Head = head,
		UpperTorso = torso,
		LowerTorso = leg,
		RightUpperArm = upperArm,
		LeftUpperArm = upperArm,
		RightLowerArm = lowerArm,
		LeftLowerArm = lowerArm,
		RightHand = hand,
		LeftHand = hand,
		RightUpperLeg = leg,
		LeftUpperLeg = leg,
		RightLowerLeg = leg,
		LeftLowerLeg = leg,
		RightFoot = foot,
		LeftFoot = foot,
	}
end

local AGENTS: { AgentDef } = {
	{
		-- L'agent de la boutique (DisplayName « Security ») : polo bleu, gilet tactique noir « SECURITY » au dos,
		-- béret noir à écusson doré, oreillette, matraque au ceinturon (les deux mains restent libres pour le
		-- plongeon de Catch). Bleu = le camp du propriétaire (le bleu des caméras de CameraAlertController).
		name = "NPC_Bodyguard",
		scale = 1.1,
		body = bodyColors("C68E62", "2D6CDF", "2D6CDF", "C68E62", "C68E62", "23262E", "111114"),
		accessories = {
			{
				name = "ACC_Bodyguard_Beret",
				attach = "HatAttachment",
				type = "Hat",
				parts = {
					{ name = "Crown", shape = "Cylinder", size = { 0.34, 1.34, 1.34 }, pos = { 0, 0.42, 0.04 }, rot = { 0, 0, 82 }, color = "17181D", material = "Fabric" },
					{ name = "Band", shape = "Cylinder", size = { 0.1, 1.24, 1.24 }, pos = { 0, 0.27, 0 }, rot = { 0, 0, 90 }, color = "0E0F12", material = "Fabric" },
					{ name = "Badge", size = { 0.28, 0.3, 0.05 }, pos = { -0.3, 0.42, -0.62 }, color = "E5B53A", material = "Metal" },
					{ name = "BadgeStar", size = { 0.14, 0.14, 0.04 }, pos = { -0.3, 0.43, -0.65 }, rot = { 0, 0, 45 }, color = "2D6CDF" },
				},
			},
			{
				name = "ACC_Bodyguard_Gilet",
				attach = "BodyFrontAttachment",
				type = "Front",
				text = "SECURITY",
				textColor = "F2F4F8",
				textPart = "BackPlate",
				parts = {
					{ name = "FrontPlate", size = { 1.74, 1.12, 0.16 }, pos = { 0, -0.12, -0.57 }, color = "1B1D22" },
					{ name = "BackPlate", size = { 1.74, 1.12, 0.16 }, pos = { 0, -0.12, 0.57 }, color = "1B1D22" },
					{ name = "SideL", size = { 0.1, 0.55, 1.16 }, pos = { -0.92, -0.32, 0 }, color = "1B1D22" },
					{ name = "SideR", size = { 0.1, 0.55, 1.16 }, pos = { 0.92, -0.32, 0 }, color = "1B1D22" },
					{ name = "StrapL", size = { 0.3, 0.5, 1.16 }, pos = { -0.55, 0.62, 0 }, color = "1B1D22" },
					{ name = "StrapR", size = { 0.3, 0.5, 1.16 }, pos = { 0.55, 0.62, 0 }, color = "1B1D22" },
					{ name = "Stripe", size = { 1.76, 0.1, 0.04 }, pos = { 0, -0.56, -0.66 }, color = "2D6CDF", material = "Neon", transparency = 0.1 },
					{ name = "Stripe", size = { 1.76, 0.1, 0.04 }, pos = { 0, -0.56, 0.66 }, color = "2D6CDF", material = "Neon", transparency = 0.1 },
					{ name = "Badge", size = { 0.28, 0.32, 0.05 }, pos = { 0.45, 0.16, -0.67 }, color = "E5B53A", material = "Metal" },
					{ name = "Radio", size = { 0.2, 0.4, 0.14 }, pos = { -0.45, 0.14, -0.72 }, color = "0E0F12" },
					{ name = "Antenna", size = { 0.05, 0.28, 0.05 }, pos = { -0.5, 0.48, -0.72 }, color = "0A0A0C" },
				},
			},
			{
				name = "ACC_Bodyguard_Oreillette",
				attach = "FaceCenterAttachment",
				type = "Face",
				parts = {
					{ name = "Bud", size = { 0.08, 0.14, 0.14 }, pos = { 0.6, -0.02, 0.04 }, color = "1A1A1A" },
					{ name = "Cord", shape = "Cylinder", size = { 0.62, 0.04, 0.04 }, pos = { 0.57, -0.4, 0.18 }, rot = { 0, 0, 90 }, color = "BFC6CE", transparency = 0.25 },
				},
			},
			{
				name = "ACC_Bodyguard_Ceinturon",
				attach = "WaistCenterAttachment",
				type = "Waist",
				parts = {
					{ name = "Belt", size = { 2.02, 0.16, 1.06 }, pos = { 0, 0.1, 0 }, color = "111113" },
					{ name = "Buckle", size = { 0.28, 0.18, 0.05 }, pos = { 0, 0.1, -0.545 }, color = "C9CED6", material = "Metal" },
					{ name = "Holster", size = { 0.22, 0.3, 0.2 }, pos = { 0.86, -0.02, -0.12 }, color = "1A1A1D" },
					{ name = "Baton", shape = "Cylinder", size = { 1.1, 0.14, 0.14 }, pos = { 0.9, -0.42, -0.12 }, rot = { 0, 0, 90 }, color = "151518" },
					{ name = "BatonTip", shape = "Cylinder", size = { 0.08, 0.15, 0.15 }, pos = { 0.9, -0.97, -0.12 }, rot = { 0, 0, 90 }, color = "2D6CDF", material = "Neon", transparency = 0.1 },
					{ name = "Pouch", size = { 0.26, 0.3, 0.16 }, pos = { -0.75, -0.05, -0.56 }, color = "1A1A1D" },
				},
			},
		},
	},
	{
		-- Le garde de la porte (DisplayName « Door Guard ») : un videur, plus grand que l'agent, t-shirt noir,
		-- bonnet noir, lunettes noires enveloppantes, oreillette, badge jaune « STAFF » au cordon et « SECURITY » au
		-- dos. Debout dehors, à côté de la porte : il se lit de loin.
		name = "NPC_DoorGuard",
		scale = 1.3,
		catchId = "rbxassetid://89786012282710", -- Guard_DoorShove (groupe RoundStone Studio)
		body = bodyColors("7A4A2A", "17171B", "17171B", "7A4A2A", "7A4A2A", "24262C", "0D0D0F"),
		accessories = {
			{
				name = "ACC_DoorGuard_Bonnet",
				attach = "HatAttachment",
				type = "Hat",
				parts = {
					{ name = "Cap", shape = "Cylinder", size = { 0.62, 1.3, 1.3 }, pos = { 0, 0.5, 0 }, rot = { 0, 0, 90 }, color = "141417", material = "Fabric" },
					{ name = "Dome", shape = "Ball", size = { 1.3, 0.7, 1.3 }, pos = { 0, 0.8, 0 }, color = "141417", material = "Fabric" },
					{ name = "Cuff", shape = "Cylinder", size = { 0.26, 1.36, 1.36 }, pos = { 0, 0.26, 0 }, rot = { 0, 0, 90 }, color = "1F1F24", material = "Fabric" },
				},
			},
			{
				name = "ACC_DoorGuard_Lunettes",
				attach = "FaceFrontAttachment",
				type = "Face",
				parts = {
					{ name = "Shades", size = { 1.1, 0.26, 0.07 }, pos = { 0, 0.13, -0.61 }, color = "0A0A0C", reflectance = 0.6 },
					{ name = "TempleL", size = { 0.04, 0.05, 0.62 }, pos = { -0.6, 0.17, -0.3 }, color = "0A0A0C" },
					{ name = "TempleR", size = { 0.04, 0.05, 0.62 }, pos = { 0.6, 0.17, -0.3 }, color = "0A0A0C" },
				},
			},
			{
				name = "ACC_DoorGuard_Oreillette",
				attach = "FaceCenterAttachment",
				type = "Face",
				parts = {
					{ name = "Bud", size = { 0.08, 0.14, 0.14 }, pos = { 0.6, -0.02, 0.04 }, color = "1A1A1A" },
					{ name = "Cord", shape = "Cylinder", size = { 0.62, 0.04, 0.04 }, pos = { 0.57, -0.4, 0.18 }, rot = { 0, 0, 90 }, color = "BFC6CE", transparency = 0.25 },
				},
			},
			{
				name = "ACC_DoorGuard_Tshirt",
				attach = "BodyFrontAttachment",
				type = "Front",
				text = "SECURITY",
				textColor = "F5D33A",
				textPart = "BackPanel",
				parts = {
					{ name = "BackPanel", size = { 1.7, 0.62, 0.04 }, pos = { 0, 0.24, 0.525 }, color = "17171B" },
					{ name = "Lanyard", size = { 0.06, 0.62, 0.04 }, pos = { -0.18, 0.5, -0.52 }, rot = { 0, 0, -20 }, color = "F5D33A" },
					{ name = "Lanyard", size = { 0.06, 0.62, 0.04 }, pos = { 0.18, 0.5, -0.52 }, rot = { 0, 0, 20 }, color = "F5D33A" },
					{ name = "Pass", size = { 0.42, 0.3, 0.05 }, pos = { 0, 0.08, -0.54 }, color = "F5D33A" },
					{ name = "PassBar", size = { 0.34, 0.06, 0.02 }, pos = { 0, 0.04, -0.57 }, color = "17171B" },
				},
			},
		},
	},
}

-- Animations à copier depuis ce vigile à la première construction (contrat Animations.ShopGuard).
local SOURCE_GUARD = "Guard_Z1"
local ANIMATION_NAMES = { "Idle", "Run", "Catch" }

local function angles(r: { number }?): CFrame
	local v = r or { 0, 0, 0 }
	return CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end

local function offset(p: PartDef): CFrame
	return CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * angles(p.rot)
end

-- Pose de repos : chaque pièce placée par son articulation depuis le HumanoidRootPart.
local function poseRest(model: Model, humanoid: Humanoid)
	local found = model:FindFirstChild("HumanoidRootPart")
	assert(found and found:IsA("BasePart"), `{model.Name} : HumanoidRootPart absent`)
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
				j.p1.CFrame = j.p0.CFrame * j.c0 * j.c1:Inverse()
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

local function makePart(p: PartDef, isHandle: boolean): Part
	local part = Instance.new("Part")
	part.Name = if isHandle then "Handle" else p.name
	part.Shape = if p.shape == "Ball"
		then Enum.PartType.Ball
		elseif p.shape == "Cylinder" then Enum.PartType.Cylinder
		else Enum.PartType.Block
	part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
	part.Color = Color3.fromHex(p.color)
	part.Material = (Enum.Material :: any)[p.material or "SmoothPlastic"]
	part.Reflectance = p.reflectance or 0
	part.Transparency = p.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	return part
end

local function addText(part: BasePart, text: string, hex: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BackPrint"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Name = "Print"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.5)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromHex(hex)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.Parent = gui
	gui.Parent = part
end

local function addAccessory(model: Model, acc: AccDef): string?
	local attach = bodyAttachment(model, acc.attach)
	if attach == nil then
		return `{acc.name} : attache {acc.attach} absente du rig`
	end
	local bodyPart = attach.Parent :: BasePart
	local accessory = Instance.new("Accessory")
	accessory.Name = acc.name
	accessory.AccessoryType = (Enum.AccessoryType :: any)[acc.type]
	local handleOffset = offset(acc.parts[1])
	local handle: Part? = nil
	local byName: { [string]: Part } = {}
	for i, p in acc.parts do
		local part = makePart(p, i == 1)
		local o = offset(p)
		part.CFrame = bodyPart.CFrame * o
		if byName[p.name] == nil then
			byName[p.name] = part
		end
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
	if acc.text then
		addText(if acc.textPart then byName[acc.textPart] else h, acc.text, acc.textColor or "F2F4F8")
	end
	accessory.Parent = model
	return nil
end

local function animationsFolder(folder: Folder, g: AgentDef, report: { string }): Folder
	local old = folder:FindFirstChild(g.name)
	local kept = old and old:FindFirstChild("Animations")
	if kept and kept:IsA("Folder") then
		return kept
	end
	local f = Instance.new("Folder")
	f.Name = "Animations"
	local source = folder:FindFirstChild(SOURCE_GUARD)
	local sourceAnims = source and source:FindFirstChild("Animations")
	for _, animName in ANIMATION_NAMES do
		local a = sourceAnims and sourceAnims:FindFirstChild(animName)
		if animName == "Catch" and g.catchId then
			local catch = Instance.new("Animation")
			catch.Name = "Catch"
			catch.AnimationId = g.catchId
			catch.Parent = f
		elseif a and a:IsA("Animation") and a.AnimationId ~= "" then
			a:Clone().Parent = f
		else
			table.insert(report, `{g.name} : animation {animName} introuvable chez {SOURCE_GUARD}`)
		end
	end
	return f
end

local function buildAgent(g: AgentDef, folder: Folder, report: { string }): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromHex(g.body.Head)
	desc.TorsoColor = Color3.fromHex(g.body.UpperTorso)
	desc.LeftArmColor = Color3.fromHex(g.body.LeftUpperArm)
	desc.RightArmColor = Color3.fromHex(g.body.RightUpperArm)
	desc.LeftLegColor = Color3.fromHex(g.body.LeftUpperLeg)
	desc.RightLegColor = Color3.fromHex(g.body.RightUpperLeg)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok then
		table.insert(report, `{g.name} : rig impossible ({result})`)
		return nil
	end
	local model = result :: Model
	model.Name = g.name
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local foundHumanoid = model:FindFirstChildOfClass("Humanoid")
	if foundHumanoid == nil then
		table.insert(report, `{g.name} : Humanoid absent du rig`)
		model:Destroy()
		return nil
	end
	local humanoid = foundHumanoid :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	if humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	for partName, hex in g.body do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = Color3.fromHex(hex)
		end
	end
	poseRest(model, humanoid)
	for _, acc in g.accessories do
		local err = addAccessory(model, acc)
		if err then
			table.insert(report, err)
		end
	end
	animationsFolder(folder, g, report).Parent = model
	model:ScaleTo(g.scale)
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	local old = folder:FindFirstChild(g.name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	return model
end

local assets = ReplicatedStorage:FindFirstChild("Assets")
local folder = assets and assets:FindFirstChild("Guards")
assert(folder and folder:IsA("Folder"), "ReplicatedStorage/Assets/Guards absent")

local report: { string } = {}
for _, g in AGENTS do
	local model = buildAgent(g, folder :: Folder, report)
	if model then
		local size = model:GetExtentsSize()
		local anims = {}
		local animFolder = model:FindFirstChild("Animations")
		if animFolder then
			for _, a in animFolder:GetChildren() do
				table.insert(anims, a.Name)
			end
		end
		table.insert(report, string.format("%s : %.2f studs de haut, animations %s", g.name, size.Y, table.concat(anims, ", ")))
	end
end
print(table.concat(report, "\n"))
return table.concat(report, "\n")
