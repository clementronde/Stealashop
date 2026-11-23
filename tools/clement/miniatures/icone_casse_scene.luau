--[[
	Mise en scène de l'icône « La casse » et de la miniature 01 « SMASH & GRAB! » (MOD-043, piste A, 2026-11-21),
	place « Steal a Shop [DEV] », en Edit. C'est la scène capturée le 2026-11-21 (docs/claude/miniatures/2026-11-21_icone).

	Rien n'est enregistré et rien d'existant n'est modifié :
	  - tout ce qui est posé va dans workspace.CurrentCamera._MINIATURE_TMP (copies seulement) ;
	  - la vitre d'origine est masquée par LocalTransparencyModifier (propriété locale, non enregistrée) ;
	  - StarterGui.ShowDevelopmentGui passe à false le temps des captures (accord de Clément du 2026-11-21 : le HUD
	    s'affiche sinon dans les captures d'Edit) ; sa valeur d'avant est notée sur le dossier.
	  icone_casse_nettoyage.luau remet tout comme avant. Ne jamais enregistrer entre les deux.

	Ce qui est montré existe dans le jeu : la Bijouterie (zone 4), sa vitre fracturée (Shard_*), les petits cubes de
	verre de la casse (couleur Shatter.GlassColor), la masse (TOOL_Masse), la Couronne (ITM_Z4_Couronne, Épique) en
	taille Colossal (×3, Config/Mutations), le halo du jeu (Shared/RarityHalo.AddCarried), un perso R15 (copie de
	Rig_Player, couleurs d'avatar et visage de base de Roblox) posé par l'animation HitWindowHeavy du jeu, à son
	marqueur Impact.

	Cadrage : de l'intérieur de la boutique, derrière la Couronne, vers le perso qui frappe la vitre depuis la rue.
	Capture (screen_capture) : camera_position = CAM, look_at_position = LOOK ; puis icone_casse_matte.luau et
	une 2e capture identique ; puis icone_casse_nettoyage.luau.
]]

local CAM = Vector3.new(446.6, 5.9, 62.6)
local LOOK = Vector3.new(441.6, 4.3, 52.5)

local REGLAGES = {
	Store = "Zone_4.STORE_Z4_Bijouterie",
	WindowZ = 54.75, -- plan de la vitre ; la rue est côté z négatif
	ImpactX = 440.5, -- où la masse touche la vitre (x de 433 à 451)
	Facing = Vector3.new(0.05, 0, 1), -- le perso regarde la vitre (et la caméra, de l'autre côté)
	CharPos = Vector3.new(440.0, 0, 51.0), -- position de départ, corrigée par le contact
	AnimTime = nil :: number?, -- nil = temps du marqueur Impact de HitWindowHeavy (0,23 s sur 0,70 s)
	Skin = Color3.fromRGB(234, 184, 146),
	Hoodie = Color3.fromRGB(255, 106, 42),
	Pants = Color3.fromRGB(38, 46, 78),
	CrownScale = 3, -- Colossal (Config/Mutations : Scale = 3)
	CrownPos = Vector3.new(446.7, 3.4, 56.4), -- derrière la vitre, en bas à droite de l'image
	CrownYaw = 35,
	ShardBurst = 4.0, -- studs : vol des éclats vers l'intérieur (vers la caméra)
	ShardDir = Vector3.new(0, 0, 1),
	ShardKeepRadius = 6, -- éclats gardés autour de l'impact ; les autres sont tombés (cachés)
	ShardSeed = 7,
	Cubes = 70, -- petits cubes de verre de la casse
	CubeSeed = 11,
}

local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

-- enfant obligatoire : arrête le script avec un message clair s'il manque
local function need(parent: Instance, name: string): any
	local child = parent:FindFirstChild(name)
	assert(child, name .. " introuvable dans " .. parent:GetFullName())
	return child
end

local cam = workspace.CurrentCamera
local old = cam:FindFirstChild("_MINIATURE_TMP")
if old then
	for _, v in old:GetDescendants() do
		if v:IsA("ObjectValue") and v.Name == "Hidden" and v.Value then
			(v.Value :: BasePart).LocalTransparencyModifier = v:GetAttribute("Old") or 0
		end
	end
	local before = old:GetAttribute("ShowDevGuiAvant")
	if before ~= nil then
		SG.ShowDevelopmentGui = before
	end
	old:Destroy()
end

local tmp = Instance.new("Folder")
tmp.Name = "_MINIATURE_TMP"
tmp:SetAttribute("ShowDevGuiAvant", SG.ShowDevelopmentGui)
tmp.Parent = cam

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

local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (a + ab * t - p).Magnitude
end

local store = workspace.Map
for _, n in string.split(REGLAGES.Store, ".") do
	store = need(store, n)
end

-- 1. Perso : copie de Rig_Player, couleurs d'avatar, posé par HitWindowHeavy au marqueur Impact
local rig = (need(workspace, "Rig_Player") :: Model):Clone()
rig.Name = "MINI_Player"
for _, d in rig:GetDescendants() do
	if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
		d:Destroy()
	end
end
local bc = rig:FindFirstChildOfClass("BodyColors")
if bc then
	bc:Destroy()
end
for _, p in rig:GetDescendants() do
	if p:IsA("BasePart") then
		local n = p.Name
		if n == "Head" or n:find("Hand") then
			p.Color = REGLAGES.Skin
		elseif n:find("Torso") or n:find("Arm") then
			p.Color = REGLAGES.Hoodie
		elseif n:find("Leg") or n:find("Foot") then
			p.Color = REGLAGES.Pants
		end
	end
end
local face = Instance.new("Decal")
face.Name = "face"
face.Texture = "rbxasset://textures/face.png" -- visage de base livré avec Roblox
face.Face = Enum.NormalId.Front
face.Parent = need(rig, "Head")
rig.Parent = tmp

local hrp = need(rig, "HumanoidRootPart") :: BasePart
local humFound = rig:FindFirstChildOfClass("Humanoid")
assert(humFound, "Rig_Player n'a pas de Humanoid")
local hum = humFound :: Humanoid
local hipToFloor = hum.HipHeight + hrp.Size.Y / 2
local base = REGLAGES.CharPos + Vector3.new(0, hipToFloor, 0)
rig:PivotTo(CFrame.lookAt(base, base + REGLAGES.Facing.Unit))
for _, p in rig:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = (p == hrp)
	end
end

local animObj = need(RS.Assets.Animations.Player, "HitWindowHeavy") :: Animation
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = hum
end
local impactTime = REGLAGES.AnimTime
local okKfs, kfs = pcall(function()
	return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(animObj.AnimationId)
end)
local animLength = 0
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
impactTime = impactTime or animLength * 0.45
local track = animator:LoadAnimation(animObj)
track:Play(0, 1, 0)
track.TimePosition = impactTime
animator:StepAnimations(0)
task.wait()
animator:StepAnimations(0)
-- figer la pose : la transformation de chaque Motor6D passe dans son C0 (sur la copie seulement)
for _, m in rig:GetDescendants() do
	if m:IsA("Motor6D") then
		m.C0 = m.C0 * m.Transform
	end
end
track:Stop(0)
animator:StepAnimations(0)
anchorAll(rig)

-- 2. Masse dans la main droite, Grip neutre (comme un Tool du jeu : Handle posé sur RightGripAttachment)
local masse = RS.Assets.Tools.TOOL_Masse:Clone()
masse.Name = "MINI_Masse"
masse.Parent = tmp
local handle = need(masse, "Handle") :: BasePart
local grip = need(need(rig, "RightHand"), "RightGripAttachment") :: Attachment
local offset = handle.CFrame:Inverse() * masse:GetPivot()
anchorAll(masse)
masse:PivotTo(grip.WorldCFrame * offset)

-- 3. Contact : perso et masse déplacés à plat pour que HitPoint touche la vitre en ImpactX
local hit = (need(handle, "HitPoint") :: Attachment).WorldPosition
local delta = Vector3.new(REGLAGES.ImpactX - hit.X, 0, (REGLAGES.WindowZ - 0.35) - hit.Z)
rig:PivotTo(rig:GetPivot() + delta)
masse:PivotTo(masse:GetPivot() + delta)
local impact = hit + delta
local head = need(rig, "Head") :: BasePart
local torso = need(rig, "UpperTorso") :: BasePart
local function hidesHero(p: Vector3): boolean
	return math.min(segDist(p, CAM, head.Position), segDist(p, CAM, torso.Position)) < 1.1
end

-- 4. Vitre : l'originale masquée ; ses éclats copiés, projetés depuis l'impact vers l'intérieur ;
--    seuls ceux de l'explosion restent visibles (les autres sont tombés), jamais devant le visage ou le torse
local window = need(store, "Window") :: BasePart
hide(window)
local fractured = (need(store, "WindowFractured") :: Model):Clone()
fractured.Parent = tmp
local rnd = Random.new(REGLAGES.ShardSeed)
for _, s in fractured:GetDescendants() do
	if s:IsA("BasePart") then
		s.Anchored = true
		s.CanCollide = false
		s.CastShadow = false
		local away = s.Position - impact
		local dist = away.Magnitude
		local dir = (away.Unit * 0.55 + REGLAGES.ShardDir + Vector3.new(0, 0.12, 0)).Unit
		local k = math.clamp(1 - dist / 9, 0.08, 1)
		local fly = REGLAGES.ShardBurst * k * rnd:NextNumber(0.6, 1.25)
		local spin = CFrame.Angles(rnd:NextNumber(-1, 1) * k * 1.4, rnd:NextNumber(-1, 1) * k * 1.4, rnd:NextNumber(-1, 1) * k * 1.4)
		s.CFrame = (s.CFrame + dir * fly) * spin
		local keep = (s.Position - impact).Magnitude <= REGLAGES.ShardKeepRadius and s.Position.X > 438 and not hidesHero(s.Position)
		s.Transparency = if keep then 0.4 else 1
	end
end

-- 5. Petits cubes de verre de la casse, projetés depuis l'impact vers l'intérieur
local cubes = Instance.new("Folder")
cubes.Name = "MINI_GlassCubes"
local crnd = Random.new(REGLAGES.CubeSeed)
for _ = 1, REGLAGES.Cubes do
	local dir = Vector3.new(crnd:NextNumber(-1, 1), crnd:NextNumber(-0.6, 1), crnd:NextNumber(0.25, 1.2)).Unit
	local dist = crnd:NextNumber(0.4, 4.2)
	local p = impact + dir * dist
	if not hidesHero(p) and (p - CAM).Magnitude > 3 then
		local c = Instance.new("Part")
		local sz = crnd:NextNumber(0.14, 0.5) * (1 - dist / 6)
		c.Size = Vector3.new(sz, sz, sz)
		c.Material = Enum.Material.Glass
		c.Color = Color3.fromRGB(191, 230, 255) -- Config/Shatter.GlassColor
		c.Transparency = 0.15
		c.Anchored = true
		c.CanCollide = false
		c.CastShadow = false
		c.CFrame = CFrame.new(p) * CFrame.Angles(crnd:NextNumber(0, 6.3), crnd:NextNumber(0, 6.3), crnd:NextNumber(0, 6.3))
		c.Parent = cubes
	end
end
cubes.Parent = tmp

-- 6. Couronne Colossal derrière la vitre, avec le vrai halo du jeu (Épique)
local crown = RS.Assets.Items.ITM_Z4_Couronne:Clone()
crown.Name = "MINI_Couronne"
crown.Parent = tmp
crown:ScaleTo(REGLAGES.CrownScale)
anchorAll(crown)
crown:PivotTo(CFrame.new(REGLAGES.CrownPos) * CFrame.Angles(0, math.rad(REGLAGES.CrownYaw), 0))
local ccf = crown:GetBoundingBox()
crown:PivotTo(crown:GetPivot() + (REGLAGES.CrownPos - ccf.Position)) -- centre de la couronne sur CrownPos
local anchor = Instance.new("Part")
anchor.Name = "MINI_HaloAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.Transparency = 1
anchor.Size = Vector3.new(0.2, 0.2, 0.2)
anchor.CFrame = CFrame.new(REGLAGES.CrownPos)
anchor.Parent = tmp
local Rarities = require(RS.Shared.Config.Rarities)
local RarityHalo = require(RS.Shared.RarityHalo)
RarityHalo.AddCarried(anchor, CFrame.new(), Rarities.ById.Epic, RarityHalo.OwnEffects(crown))

-- 7. HUD masqué le temps des captures (remis par icone_casse_nettoyage.luau)
SG.ShowDevelopmentGui = false

return ("ok : impact %.2f s / %.2f s en %s ; capturer de %s vers %s"):format(impactTime, animLength, tostring(impact), tostring(CAM), tostring(LOOK))
