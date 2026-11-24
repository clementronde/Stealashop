--!nocheck
-- Catalogue v3 : range les 45 objets Meshy riggés (FBX StealAShop-Art/Items/V3_Meshy/FBX_Zones_Rig, un par zone,
-- Importateur 3D) dans ReplicatedStorage/Assets/Items, à la place des versions sans os. À lancer en Edit.
-- L'import d'un FBX à plusieurs squelettes met tous les os sur un seul RootPart (9 « Base » au même endroit) :
-- on recrée donc, pour chaque objet, ses os Base > Body > Top DANS son MeshPart, aux positions de la pose de liaison
-- (Base en bas au centre, Body à 30 % de la hauteur, Top à 62 %, comme rig_items.py). Le FBX arrive en centimètres
-- (100 fois trop grand) : le maillage est réduit, le modèle reste à GetScale() = 1 (DisplayService fait ScaleTo).
-- Chaque objet reçoit : MeshPart ITM_<ItemId> (nom lu par l'animation, ne pas le renommer), Root (PrimaryPart, pivot
-- en bas), AnimationController + Animator, Animations/Boucle (AnimationId à coller après publication), AnimSaves
-- (ObjectValue vers ServerStorage/RBX_ANIMSAVES/ITM_<ItemId>), attribut ItemId.

local H = { -- hauteur en studs (rig_info.json)
	Secret_ToilettesEnOr = 2.245, Z1_BananeScotchee = 2.000, Z1_BoissonSigma = 2.000, Z1_Canette67 = 1.636,
	Z1_ChipsMystere = 1.900, Z1_ChocolatDeDubai = 1.500, Z1_OeufBoudeur = 0.940, Z1_PastequeMewing = 1.800,
	Z1_PouletALunettes = 1.900, Z1_TicketGagnant = 1.600, Z2_BonbonPiquant = 1.600, Z2_BusEnGelatine = 1.500,
	Z2_CanardRoyal = 1.700, Z2_CapybaraOrange = 1.600, Z2_SucetteTourbillon = 2.200, Z2_TheiereDansante = 1.700,
	Z3_ChatQuiTourne = 1.900, Z3_ClavierRgb = 0.258, Z3_ManetteQuiTranspire = 1.300, Z3_MicroDeStreamer = 2.000,
	Z3_PcGamerQuiFume = 2.200, Z3_SushiNinja = 1.600, Z3_TelephonePliant = 1.600, Z4_ChaineDrip = 2.000,
	Z4_ChihuahuaEnDiamants = 2.000, Z4_FauxOnglesEnOr = 2.000, Z4_GrillzEnDiamant = 0.455, Z4_MontreGlacee = 1.700,
	Z4_PerruquePresidentielle = 1.900, Z5_BaguetteEnOr = 0.600, Z5_BeretDeMime = 1.065, Z5_CramponsDores = 0.913,
	Z5_CroissantRequin = 1.037, Z5_GoldenBall = 1.500, Z5_JocondeSelfie = 2.200, Z5_StatueMewing = 2.200,
	Z6_BilletQuiCourt = 2.100, Z6_CarteNoireInfinie = 1.800, Z6_CerveauDore = 1.561, Z6_CoffreADents = 2.000,
	Z6_LiberteEnOr = 2.300, Z6_LingotGeant = 0.611, Z6_PigeonEnOr = 1.754, Z6_TaxiEnOr = 1.219, Z6_ValiseDeBillets = 1.513,
}

local RS = game:GetService("ReplicatedStorage")
local Items = RS.Assets.Items
local saves = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")

local function bone(name, parent, cf)
	local b = Instance.new("Bone")
	b.Name = name
	b.CFrame = cf
	b.Parent = parent
	return b
end

local done, problems = {}, {}
local zones = {}
for _, z in workspace:GetChildren() do
	if z.Name:match("^V3_.+_Objets") then table.insert(zones, z) end
end
for _, z in zones do
	for _, mp in z:GetDescendants() do
		if not (mp:IsA("MeshPart") and mp.Name:match("^ITM_.+_Mesh$")) then continue end
		local itemId = mp.Name:match("^ITM_(.+)_Mesh$")
		local h = H[itemId]
		if not h then table.insert(problems, itemId .. " : hauteur inconnue") continue end
		local name = "ITM_" .. itemId
		-- Pose de liaison : l'Importateur a lié chaque maillage à l'os Base du 1er objet de la zone (RootPart), pas au
		-- sien. On garde donc les os à cette position (BindOffset, dans le repère du maillage) ; l'animation
		-- (items_v3_anim_saves.luau) recentre chaque rotation sur le bas de l'objet. Vérifié sur le pigeon le 24/11.
		local srcBase = z:FindFirstChild("Base", true)
		local k = if mp.Size.Y > h * 10 then 0.01 else 1
		local bindOffset = mp.CFrame:PointToObjectSpace(srcBase.WorldPosition) * k
		-- maillage : nettoyé, réduit si besoin, renommé
		for _, c in mp:GetChildren() do
			if c:IsA("Motor6D") or c:IsA("Bone") then c:Destroy() end
		end
		local cf = mp.CFrame
		if mp.Size.Y > h * 10 then mp.Size = mp.Size * 0.01 end
		mp.CFrame = cf
		mp.Name = name
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.CastShadow = true
		pcall(function() mp.CollisionFidelity = Enum.CollisionFidelity.Box end)
		-- os de la pose de liaison, dans le MeshPart (repère du maillage, axes identiques)
		local base = bone("Base", mp, CFrame.new(bindOffset))
		local body = bone("Body", base, CFrame.new(0, 0.30 * h, 0))
		bone("Top", body, CFrame.new(0, 0.32 * h, 0))
		-- modèle
		local model = Instance.new("Model")
		model.Name = name
		mp.Parent = model
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = mp.Size
		root.CFrame = CFrame.new(mp.Position)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = true
		root.CanTouch = false
		root.Massless = true
		root.CastShadow = false
		root.PivotOffset = CFrame.new(0, -mp.Size.Y / 2, 0)
		root.Parent = model
		model.PrimaryPart = root
		local ac = Instance.new("AnimationController")
		Instance.new("Animator").Parent = ac
		ac.Parent = model
		local anims = Instance.new("Folder")
		anims.Name = "Animations"
		anims.Parent = model
		local loop = Instance.new("Animation")
		loop.Name = "Boucle"
		loop.Parent = anims
		local holder = saves and saves:FindFirstChild(name)
		if holder then
			local link = Instance.new("ObjectValue")
			link.Name = "AnimSaves"
			link.Value = holder
			link.Parent = model
		end
		model:SetAttribute("ItemId", itemId)
		model:SetAttribute("BoucleAnimationId", "")
		model:SetAttribute("BindOffset", bindOffset)
		local old = Items:FindFirstChild(name)
		if old then old:Destroy() end
		model.Parent = Items
		if holder then holder.Value = model end
		local _, size = model:GetBoundingBox()
		table.insert(done, string.format("%s %.2fx%.2fx%.2f", name, size.X, size.Y, size.Z))
	end
end
for _, z in zones do
	local left = 0
	for _, d in z:GetDescendants() do if d:IsA("MeshPart") then left += 1 end end
	if left == 0 then z:Destroy() else table.insert(problems, z.Name .. " : " .. left .. " maillages restés") end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Objets v3 Meshy riggés rangés")
table.sort(done)
return string.format("%d rangés ; problèmes : %s\n%s", #done, table.concat(problems, " ; "), table.concat(done, "\n"))
