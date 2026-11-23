--[[
	Passe « matte » de l'icône « La casse » (MOD-043, 2026-11-21), après icone_casse_scene.luau et la capture brute.
	Sur les COPIES seulement (workspace.CurrentCamera._MINIATURE_TMP) : perso et masse en néon vert pur, Couronne en
	néon magenta pur, halo éteint. La capture faite avec le même cadrage donne les masques du contour et du halo
	(tools/clement/miniatures/retouche_icone.py). Ensuite : icone_casse_nettoyage.luau.
]]
local tmp = workspace.CurrentCamera:FindFirstChild("_MINIATURE_TMP")
assert(tmp, "lancer d'abord icone_casse_scene.luau")

local function paint(model: Instance?, color: Color3)
	if not model then
		return 0
	end
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			d.Material = Enum.Material.Neon
			d.Color = color
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
			n += 1
		elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		end
	end
	return n
end

local a = paint(tmp:FindFirstChild("MINI_Player"), Color3.fromRGB(0, 255, 0))
local b = paint(tmp:FindFirstChild("MINI_Masse"), Color3.fromRGB(0, 255, 0))
local c = paint(tmp:FindFirstChild("MINI_Couronne"), Color3.fromRGB(255, 0, 255))
local anchor = tmp:FindFirstChild("MINI_HaloAnchor")
if anchor then
	for _, d in anchor:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("PointLight") then
			d.Enabled = false
		end
	end
end
return ("matte : %d pièces perso, %d masse, %d couronne"):format(a, b, c)
