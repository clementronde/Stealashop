--[[
	Mise en scène de la casse pour un rendu Blender (MOD-043, miniature 01 « la casse », 2026-11-22), place
	« Steal a Shop [DEV] », en Edit. Clément exporte ensuite en OBJ (« Export Selection ») le dossier
	workspace.CurrentCamera._MINIATURE_TMP et la Bijouterie (Map.Zone_4.STORE_Z4_Bijouterie).

	Avant ce script, deux modèles gratuits du Creator Store sont insérés dans _MINIATURE_TMP (outil insert_asset) et
	vidés de leurs scripts : « R15 Bacon Hair » (4278649430, nommé MINI_BaconHair : le bacon hair classique, avec ses
	cheveux Pal Hair et sa tenue par défaut) et « Balaclava » (130752228296009, nommé MINI_Cagoule).

	Rien n'est enregistré et rien d'existant n'est modifié : tout ce qui est posé est une copie dans _MINIATURE_TMP ;
	la vitre d'origine est seulement masquée (LocalTransparencyModifier, non enregistré).
	icone_casse_nettoyage.luau remet tout comme avant. Ne jamais enregistrer entre les deux.

	Ce qui est montré existe dans le jeu : la Bijouterie (zone 4), sa vitre fracturée (Shard_*), les petits cubes de
	verre de la casse (Shatter.GlassColor), la masse (TOOL_Masse), la Couronne (ITM_Z4_Couronne), la pose de
	l'animation HitWindowHeavy à son marqueur Impact. Le socle sous verre de la Couronne est une mise en scène
	(demande de Clément pour la miniature 01).
]]

local REGLAGES = {
	Store = "Zone_4.STORE_Z4_Bijouterie",
	WindowZ = 54.75, -- plan de la vitre ; la rue est côté z négatif
	ImpactX = 438.5, -- où la masse touche la vitre (x de 433 à 451)
	Facing = Vector3.new(0.05, 0, 1), -- le perso regarde la vitre
	CharPos = Vector3.new(438.0, 0, 51.0), -- position de départ, corrigée par le contact
	CrownScale = 2,
	PedestalPos = Vector3.new(447.5, 0, 58.5), -- socle à l'intérieur, à droite de l'impact
	ShardBurst = 4.0,
	ShardDir = Vector3.new(0, 0, 1),
	ShardKeepRadius = 7,
	ShardSeed = 7,
	Cubes = 90,
	CubeSeed = 11,
}

local RS = game:GetService("ReplicatedStorage")

local function need(parent: Instance, name: string): any
	local child = parent:FindFirstChild(name)
	assert(child, name .. " introuvable dans " .. parent:GetFullName())
	return child
end

local cam = workspace.CurrentCamera
local tmp = need(cam, "_MINIATURE_TMP") :: Folder

-- refaire proprement : on enlève ce qu'un passage précédent a posé (sauf les deux modèles insérés)
for _, c in tmp:GetChildren() do
	if c.Name ~= "MINI_BaconHair" and c.Name ~= "MINI_Cagoule" then
		if c:IsA("ObjectValue") and c.Name == "Hidden" and c.Value then
			(c.Value :: BasePart).LocalTransparencyModifier = c:GetAttribute("Old") or 0
		end
		c:Destroy()
	end
end

local function hide(part: BasePart)
	local ov = Instance.new("ObjectValue")
	ov.Name = "Hidden"
	ov.Value = part
	ov:SetAttribute("Old", part.LocalTransparencyModifier)
	ov.Parent = tmp
	part.LocalTransparencyModifier = 1
end

local function anchorAll(model: Instance)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
end

local store = workspace.Map
for _, n in string.split(REGLAGES.Store, ".") do
	store = need(store, n)
end

-- 1. Perso : le bacon hair inséré, sans scripts ni objets de jeu (sons, remotes, valeurs, caméra)
-- modèles venus du Creator Store : tous leurs scripts sont retirés avant usage (règle du projet)
for _, name in { "MINI_BaconHair", "MINI_Cagoule" } do
	for _, d in need(tmp, name):GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end
-- le personnage est le modèle qui porte le Humanoid, rangé dans le modèle inséré (« R15 Bacon Hair »)
local inserted = need(tmp, "MINI_BaconHair") :: Model
local humInserted = inserted:FindFirstChildWhichIsA("Humanoid", true)
assert(humInserted and humInserted.Parent and humInserted.Parent:IsA("Model"), "pas de personnage dans MINI_BaconHair")
local rig = humInserted.Parent :: Model
for _, d in rig:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("Sound") or d:IsA("ValueBase") or d:IsA("Camera") then
		d:Destroy()
	end
end
local hrp = need(rig, "HumanoidRootPart") :: BasePart
local humFound = rig:FindFirstChildOfClass("Humanoid")
assert(humFound, "MINI_BaconHair n'a pas de Humanoid")
local hum = humFound :: Humanoid
for _, p in rig:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = (p == hrp)
	end
end
-- placé face à la vitre, puis posé sur la rue par sa boîte englobante (ce vieux modèle n'a pas de HipHeight réglée)
local base = REGLAGES.CharPos + Vector3.new(0, 3, 0)
rig:PivotTo(CFrame.lookAt(base, base + REGLAGES.Facing.Unit))
local rcf, rsize = rig:GetBoundingBox()
rig:PivotTo(rig:GetPivot() + Vector3.new(0, REGLAGES.CharPos.Y - (rcf.Position.Y - rsize.Y / 2), 0))

-- 2. Pose : HitWindowHeavy au marqueur Impact, figée dans les C0 des Motor6D (copie seulement)
local animObj = need(RS.Assets.Animations.Player, "HitWindowHeavy") :: Animation
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = hum
end
local impactTime: number? = nil
local animLength = 0
local okKfs, kfs = pcall(function()
	return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(animObj.AnimationId)
end)
if okKfs and kfs then
	for _, kf in kfs:GetChildren() do
		if kf:IsA("Keyframe") then
			animLength = math.max(animLength, kf.Time)
			for _, m in kf:GetChildren() do
				if m:IsA("KeyframeMarker") and m.Name == "Impact" and impactTime == nil then
					impactTime = kf.Time
				end
			end
		end
	end
end
local t = impactTime or animLength * 0.45
local track = (animator :: Animator):LoadAnimation(animObj)
track:Play(0, 1, 0)
track.TimePosition = t
;(animator :: Animator):StepAnimations(0)
task.wait()
;(animator :: Animator):StepAnimations(0)
for _, m in rig:GetDescendants() do
	if m:IsA("Motor6D") then
		m.C0 = m.C0 * m.Transform
	end
end
track:Stop(0)
;(animator :: Animator):StepAnimations(0)
anchorAll(rig)

-- 3. Cagoule sur la tête (la pièce de maillage du modèle inséré), puis le reste de ce modèle retiré
local head = need(rig, "Head") :: BasePart
local cagouleModel = need(tmp, "MINI_Cagoule")
local cagouleFound = cagouleModel:FindFirstChildWhichIsA("MeshPart", true)
assert(cagouleFound, "pas de MeshPart dans MINI_Cagoule")
local cagoule = cagouleFound :: MeshPart
for _, w in cagoule:GetChildren() do
	if w:IsA("JointInstance") or w:IsA("WeldConstraint") then
		w:Destroy()
	end
end
cagoule.Name = "MINI_Cagoule_Tete"
cagoule.Anchored = true
cagoule.CanCollide = false
cagoule.Parent = rig
cagoule.CFrame = head.CFrame * CFrame.new(0, 0.05, 0)
cagouleModel:Destroy()

-- 4. Masse dans la main droite (Handle sur RightGripAttachment), puis contact avec la vitre
local masse = RS.Assets.Tools.TOOL_Masse:Clone()
masse.Name = "MINI_Masse"
masse.Parent = tmp
local handle = need(masse, "Handle") :: BasePart
-- ce vieux modèle R15 n'a pas de point de prise : on copie celui d'un rig de travail R15 (ServerStorage), sinon
-- la valeur standard de Roblox
local rightHand = need(rig, "RightHand") :: BasePart
local gripFound = rightHand:FindFirstChild("RightGripAttachment")
if not gripFound then
	local refCFrame = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	for _, d in game:GetService("ServerStorage"):GetDescendants() do
		if d:IsA("Attachment") and d.Name == "RightGripAttachment" and d.Parent and d.Parent.Name == "RightHand" then
			refCFrame = d.CFrame
			break
		end
	end
	local copy = Instance.new("Attachment")
	copy.Name = "RightGripAttachment"
	copy.CFrame = refCFrame
	copy.Parent = rightHand
	gripFound = copy
end
local grip = gripFound :: Attachment
local offset = handle.CFrame:Inverse() * masse:GetPivot()
anchorAll(masse)
masse:PivotTo(grip.WorldCFrame * offset)
local hit = (need(handle, "HitPoint") :: Attachment).WorldPosition
local delta = Vector3.new(REGLAGES.ImpactX - hit.X, 0, (REGLAGES.WindowZ - 0.35) - hit.Z)
rig:PivotTo(rig:GetPivot() + delta)
masse:PivotTo(masse:GetPivot() + delta)
local impact = hit + delta

-- 5. Vitre : l'originale masquée ; ses éclats copiés et projetés vers l'intérieur depuis l'impact
hide(need(store, "Window") :: BasePart)
local fractured = (need(store, "WindowFractured") :: Model):Clone()
fractured.Name = "MINI_Eclats"
fractured.Parent = tmp
local rnd = Random.new(REGLAGES.ShardSeed)
for _, s in fractured:GetDescendants() do
	if s:IsA("BasePart") then
		s.Anchored = true
		s.CanCollide = false
		local away = s.Position - impact
		local dist = away.Magnitude
		local dir = (away.Unit * 0.55 + REGLAGES.ShardDir + Vector3.new(0, 0.12, 0)).Unit
		local k = math.clamp(1 - dist / 9, 0.08, 1)
		local fly = REGLAGES.ShardBurst * k * rnd:NextNumber(0.6, 1.25)
		local spin = CFrame.Angles(rnd:NextNumber(-1, 1) * k * 1.4, rnd:NextNumber(-1, 1) * k * 1.4, rnd:NextNumber(-1, 1) * k * 1.4)
		s.CFrame = (s.CFrame + dir * fly) * spin
		if (s.Position - impact).Magnitude > REGLAGES.ShardKeepRadius then
			s:Destroy() -- les éclats loin de l'impact sont tombés : pas exportés
		end
	end
end

-- 6. Petits cubes de verre de la casse
local cubes = Instance.new("Model")
cubes.Name = "MINI_CubesVerre"
local crnd = Random.new(REGLAGES.CubeSeed)
for i = 1, REGLAGES.Cubes do
	local dir = Vector3.new(crnd:NextNumber(-1, 1), crnd:NextNumber(-0.6, 1), crnd:NextNumber(0.25, 1.2)).Unit
	local dist = crnd:NextNumber(0.4, 4.5)
	local c = Instance.new("Part")
	c.Name = "Cube_" .. i
	local sz = crnd:NextNumber(0.14, 0.5) * (1 - dist / 6)
	c.Size = Vector3.new(sz, sz, sz)
	c.Material = Enum.Material.Glass
	c.Color = Color3.fromRGB(191, 230, 255) -- Config/Shatter.GlassColor
	c.Anchored = true
	c.CanCollide = false
	c.CFrame = CFrame.new(impact + dir * dist) * CFrame.Angles(crnd:NextNumber(0, 6.3), crnd:NextNumber(0, 6.3), crnd:NextNumber(0, 6.3))
	c.Parent = cubes
end
cubes.Parent = tmp

-- 7. Socle sous verre à l'intérieur, et la Couronne dessus
local socle = Instance.new("Model")
socle.Name = "MINI_Socle"
local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.Parent = socle
	return p
end
local ped = REGLAGES.PedestalPos
piece("Socle_Pied", Vector3.new(3.2, 3.0, 3.2), CFrame.new(ped + Vector3.new(0, 1.5, 0)), Color3.fromRGB(58, 60, 66), Enum.Material.SmoothPlastic)
piece("Socle_Plateau", Vector3.new(3.6, 0.35, 3.6), CFrame.new(ped + Vector3.new(0, 3.17, 0)), Color3.fromRGB(212, 175, 55), Enum.Material.SmoothPlastic)
piece("Socle_Coussin", Vector3.new(2.8, 0.45, 2.8), CFrame.new(ped + Vector3.new(0, 3.57, 0)), Color3.fromRGB(176, 22, 38), Enum.Material.Fabric)
piece("Socle_Vitre", Vector3.new(3.4, 3.6, 3.4), CFrame.new(ped + Vector3.new(0, 3.35 + 1.8, 0)), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
socle.Parent = tmp
local crown = RS.Assets.Items.ITM_Z4_Couronne:Clone()
crown.Name = "MINI_Couronne"
crown.Parent = tmp
crown:ScaleTo(REGLAGES.CrownScale)
anchorAll(crown)
for _, d in crown:GetDescendants() do
	if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light") then
		d:Destroy() -- les effets ne s'exportent pas ; le halo est refait dans Blender
	end
end
local bcf, bsize = crown:GetBoundingBox()
local floorY = ped.Y + 3.8
crown:PivotTo(crown:GetPivot() + Vector3.new(ped.X - bcf.Position.X, floorY + bsize.Y / 2 - bcf.Position.Y, ped.Z - bcf.Position.Z))

return ("ok : impact en %s (pose %.2f s sur %.2f s) ; tête en %s ; couronne en %s"):format(tostring(impact), t, animLength, tostring(head.Position), tostring((crown:GetBoundingBox()).Position))
