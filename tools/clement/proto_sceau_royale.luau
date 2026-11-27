-- Prototype du « sceau au sol propre à chaque aura » sur l'aura Royale (Clément, 26/11 : « pas compris »)
-- Chef VFX et son. En Edit, sans Play, aucun script laissé. Rien n'est changé dans Assets : tout est dans
-- Workspace/_PROTO_SCEAU, loin de la map, puis retiré.
--   à gauche de face : l'aura Royale actuelle (son sceau est un anneau générique) ;
--   à droite de face : la même aura, avec un sceau gravé dessiné pour elle (anneau d'or, 8 pointes de couronne,
--   24 encoches, 8 losanges) et sa copie sombre dessous, qui tournent lentement.
-- Textures en aperçu local (dossier content de Studio, ce PC seulement) : FX/Aura3D/FX_Aura_Royale_Sceau*.png.
--   _G.SC.build() puis _G.SC.freeze() pour la capture ; _G.SC.clean() pour tout retirer.

local Players = game:GetService("Players")
local SC = {}
_G.SC = SC

local ORIGIN = CFrame.new(-3000, 0, 6600)
local TEX = "rbxasset://textures/StealAShopFX_sceau1/FX_Aura_Royale_Sceau.png"
local TEX_SHADOW = "rbxasset://textures/StealAShopFX_sceau1/FX_Aura_Royale_SceauOmbre.png"

local function dummy(parent: Instance, cf: CFrame): Model
	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	local a = rig:FindFirstChild("Animate")
	if a then a:Destroy() end
	local hum = rig:WaitForChild("Humanoid") :: Humanoid
	local hrp = rig:WaitForChild("HumanoidRootPart") :: BasePart
	rig:PivotTo(cf * CFrame.new(0, hum.HipHeight + hrp.Size.Y / 2, 0))
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			local n = p.Name
			p.Color = if n:match("Torso") or n:match("UpperArm") then Color3.fromRGB(30, 30, 34)
				elseif n:match("Leg") or n:match("Foot") then Color3.fromRGB(46, 92, 52)
				else Color3.fromRGB(234, 190, 150)
		end
	end
	rig.Parent = parent
	return rig
end

-- pose l'aura sur le mannequin : chaque pièce de l'aura va sur la pièce du corps du même nom
local function wear(rig: Model, aura: Model): Model
	local m = aura:Clone()
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local body = rig:FindFirstChild(p.Name)
			if body and body:IsA("BasePart") then
				p.CFrame = body.CFrame
			end
			p.Anchored = true
			p.Transparency = 1
			p.CanCollide = false
		end
	end
	m.Parent = rig
	return m
end

function SC.build(): string
	SC.clean()
	local root = Instance.new("Folder")
	root.Name = "_PROTO_SCEAU"
	local g = Instance.new("Part")
	g.Anchored, g.Size, g.CFrame = true, Vector3.new(60, 1, 40), ORIGIN * CFrame.new(0, -0.5, 0)
	g.Color, g.Material = Color3.fromRGB(150, 150, 150), Enum.Material.Concrete
	g.Parent = root
	root.Parent = workspace
	SC.root = root

	local src = game.ReplicatedStorage.Assets.FX.Auras.FX_Aura_Royale
	local left = dummy(root, ORIGIN * CFrame.new(7, 0, 0))
	local right = dummy(root, ORIGIN * CFrame.new(-7, 0, 0))
	wear(left, src)
	local aura = wear(right, src)

	-- le nouveau sceau : la couche claire (teintée or) et sa copie sombre dessous
	local sceau = aura:FindFirstChild("Sceau", true)
	if sceau and sceau:IsA("ParticleEmitter") then
		sceau.Texture = TEX
		sceau.Color = ColorSequence.new(Color3.fromRGB(255, 214, 92))
		sceau.LightEmission = 0.5
		sceau.LightInfluence = 0
		sceau.Brightness = 1.6
		sceau.RotSpeed = NumberRange.new(12)
		sceau.Rotation = NumberRange.new(0, 360)
		sceau.Size = NumberSequence.new(7)
		sceau.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.05),
			NumberSequenceKeypoint.new(0.85, 0.05), NumberSequenceKeypoint.new(1, 1),
		})
		sceau.ZOffset = 0.02
		local shadow = sceau:Clone()
		shadow.Name = "SceauOmbre"
		shadow.Texture = TEX_SHADOW
		shadow.Color = ColorSequence.new(Color3.new(0, 0, 0))
		shadow.LightEmission = 0
		shadow.Brightness = 1
		shadow.Size = NumberSequence.new(7.2)
		shadow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35),
			NumberSequenceKeypoint.new(0.85, 0.35), NumberSequenceKeypoint.new(1, 1),
		})
		shadow.ZOffset = 0.01
		shadow.Parent = sceau.Parent
	end
	-- l'ancien cœur de sceau (même texture générique) laisse la place au nouveau
	local coeur = aura:FindFirstChild("SceauCoeur", true)
	if coeur and coeur:IsA("ParticleEmitter") then coeur.Enabled = false end

	-- les deux auras tournent un moment pour que tout soit à l'écran
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then d.TimeScale = 1; d:Clear() end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Enabled and d.Rate > 0 and d.Rate < 1 then d:Emit(1) end
	end
	return "posé"
end

function SC.freeze()
	for _, d in SC.root:GetDescendants() do
		if d:IsA("ParticleEmitter") then d.TimeScale = 0 end
	end
end

function SC.clean()
	local old = workspace:FindFirstChild("_PROTO_SCEAU")
	if old then old:Destroy() end
end

return SC
