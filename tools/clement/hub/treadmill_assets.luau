--!nocheck
--[[
	Range les tapis de course importés par Clément (MOD-016, 2026-11-08). Les FBX viennent de
	StealAShop-Art/Training/Treadmill (scripts Blender build_treadmill.py pour Base et Silver,
	build_treadmill_variant.py pour les variantes texturées Void et Fire) et arrivent dans
	Workspace par l'Importateur 3D, sous le nom du fichier.

	À envoyer d'un bloc à execute_luau, en mode Edit. Relançable : une variante sans import dans
	Workspace garde sa version déjà rangée.

	Résultat : ReplicatedStorage/Assets/Plots/PLOT_Treadmill_<Variante>, pivot en bas au centre à
	l'origine, avant (console ou portique) vers -Z, sans tag. Même repère pour toutes les
	variantes : le code en copie une au pivot de Treadmill, la nomme Treadmill et lui donne le tag.
	Chaque variante contient :
	  - ses maillages, aux couleurs du modèle (Neon pour les lueurs), sans collision ;
	  - Belt, la bande, avec la Texture BeltTexture que le code fait défiler (OffsetStudsV) et
	    l'Attachment UsePoint (place du coureur, tourné vers -Z). Pour Void et Fire, Belt est une
	    Part plate qui reprend l'image de la bande (importée sur le maillage) en BeltTexture ;
	  - UpgradePoint (Attachment au sol en (6,75, 0, 2) depuis le pivot, même point pour toutes les variantes) ;
	  - des boîtes invisibles Collision_* qui portent les collisions.
	La boutique (plot_shop_builder.luau) copie PLOT_Treadmill_Base sous le nom Treadmill.
]]

local RS = game:GetService("ReplicatedStorage")
local rgb = Color3.fromRGB

-- Données des JSON (couleurs sRGB, lueurs, repères) ; colliders : { nom, min, max } en studs.
local VARIANTS = {
	PLOT_Treadmill_Base = {
		parts = {
			Belt = { rgb(35, 36, 39) }, BeltArrows = { rgb(243, 242, 235) }, BeltEnds = { rgb(35, 36, 39) },
			Frame = { rgb(183, 187, 195) }, Trim = { rgb(61, 63, 69) }, ConsoleScreen = { rgb(61, 63, 69) },
			ConsoleButtons = { rgb(162, 168, 177), reflect = 0.15 },
		},
		beltTexture = "rbxassetid://95120777733359", -- ENV_Texture_Stud (L-030), comme l'ancien tapis
		upgrade = Vector3.new(6.75, 0, 2), -- panneau au sol, à droite de la bande (même point pour toutes les variantes)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.26, 0, -4.307), Vector3.new(2.26, 0.834, 4.307) },
			{ "Collision_Hood", Vector3.new(-2.26, 0.834, -4.06), Vector3.new(2.26, 1.24, -2.7) },
			{ "Collision_Console", Vector3.new(-2.26, 1.24, -4.31), Vector3.new(2.26, 4.57, -3.2) },
		},
	},
	PLOT_Treadmill_Silver = {
		parts = {
			Belt = { rgb(35, 36, 39) }, BeltArrows = { rgb(243, 242, 235) }, BeltEnds = { rgb(35, 36, 39) },
			Frame = { rgb(227, 230, 235), reflect = 0.12 }, Trim = { rgb(121, 126, 135) }, ConsoleScreen = { rgb(121, 126, 135) },
			ConsoleButtons = { rgb(246, 247, 249), reflect = 0.3 },
		},
		beltTexture = "rbxassetid://95120777733359",
		upgrade = Vector3.new(6.75, 0, 2), -- panneau au sol, à droite de la bande (même point pour toutes les variantes)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.26, 0, -4.307), Vector3.new(2.26, 0.834, 4.307) },
			{ "Collision_Hood", Vector3.new(-2.26, 0.834, -4.06), Vector3.new(2.26, 1.24, -2.7) },
			{ "Collision_Console", Vector3.new(-2.26, 1.24, -4.31), Vector3.new(2.26, 4.57, -3.2) },
		},
	},
	PLOT_Treadmill_Void = {
		parts = {
			Belt = { rgb(20, 16, 28) }, BeltEnds = { rgb(153, 81, 255) }, VoidCrystal = { rgb(61, 32, 102), reflect = 0.2 },
			VoidCore = { rgb(21, 18, 25) }, VoidGlow = { rgb(196, 139, 255), neon = true }, VoidSteel = { rgb(75, 65, 94), reflect = 0.1 },
			Obsidian = { rgb(40, 33, 51), reflect = 0.15 }, VoidGlowPink = { rgb(255, 139, 223), neon = true },
		},
		flatBelt = true, -- l'image de la bande est sur le maillage importé
		upgrade = Vector3.new(6.75, 0, 2), -- panneau au sol, à droite de la bande (même point pour toutes les variantes)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.52, 0, -2.86), Vector3.new(2.52, 1.014, 4.1) },
			{ "Collision_Front", Vector3.new(-2.8, 1.014, -4.02), Vector3.new(2.817, 7.8, -2.56) },
			{ "Collision_Rear", Vector3.new(-2.48, 1.014, 3.84), Vector3.new(2.48, 2.94, 4.06) },
		},
	},
	PLOT_Treadmill_Fire = {
		parts = {
			Belt = { rgb(30, 14, 8) }, BeltEnds = { rgb(255, 121, 27), neon = true }, DarkCore = { rgb(34, 33, 35) },
			Steel = { rgb(153, 157, 167), reflect = 0.1 }, Gunmetal = { rgb(76, 79, 87) }, GlowAmber = { rgb(255, 193, 61), neon = true },
			ConsoleScreen = { rgb(255, 255, 255) }, EmberGlow = { rgb(255, 90, 23), neon = true },
		},
		flatBelt = true,
		upgrade = Vector3.new(6.75, 0, 2), -- panneau au sol, à droite de la bande (même point pour toutes les variantes)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.512, 0, -2.86), Vector3.new(2.512, 1.014, 4.112) },
			{ "Collision_Front", Vector3.new(-2.48, 1.014, -4.629), Vector3.new(2.48, 5.541, -2.56) },
			{ "Collision_Rear", Vector3.new(-2.48, 1.014, 3.94), Vector3.new(2.48, 1.32, 4.06) },
		},
	},
}

local function box(parent, name, lo, hi)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = hi - lo
	p.CFrame = CFrame.new((lo + hi) / 2)
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function attachment(name, part, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	return a
end

local function prepare(import, name)
	local spec = VARIANTS[name]
	-- l'Importateur range les maillages dans un sous-modèle du même nom : on les remonte
	local m = Instance.new("Model")
	m.Name = name
	local pivot = import:GetPivot()
	for _, d in import:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Parent = m
		end
	end
	m.WorldPivot = pivot
	m:PivotTo(CFrame.identity)
	m.WorldPivot = CFrame.identity
	for _, p in m:GetChildren() do
		local look = spec.parts[p.Name]
		assert(look, name .. " : pièce inattendue " .. p.Name)
		p.Anchored = true
		p.Color = look[1]
		p.Material = look.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.Reflectance = look.reflect or 0
		p.CollisionFidelity = Enum.CollisionFidelity.Box
		p.CanCollide = p.Name == "Belt"
		p.CanTouch = false
		p.CanQuery = p.Name == "Belt"
		p.CastShadow = not look.neon and p.Name ~= "BeltArrows"
	end
	local belt = m.Belt
	local image = spec.beltTexture
	if spec.flatBelt then
		-- la bande devient une Part plate qui porte l'image en Texture (le code la fait défiler)
		-- l'Importateur 3D pose l'image dans un SurfaceAppearance (ColorMap), sinon dans TextureID
		local sa = belt:FindFirstChildOfClass("SurfaceAppearance")
		image = (sa and sa.ColorMap ~= "") and sa.ColorMap or belt.TextureID
		assert(image ~= "", name .. " : la bande importée n'a pas d'image")
		local flat = Instance.new("Part")
		flat.Name = "Belt"
		flat.Size = Vector3.new(belt.Size.X, 0.05, belt.Size.Z)
		flat.CFrame = CFrame.new(belt.Position.X, belt.Position.Y + belt.Size.Y / 2 - 0.025, belt.Position.Z)
		flat.Anchored = true
		flat.Color = spec.parts.Belt[1]
		flat.Material = Enum.Material.SmoothPlastic
		flat.TopSurface = Enum.SurfaceType.Smooth
		flat.BottomSurface = Enum.SurfaceType.Smooth
		flat.CanCollide = true
		flat.CanTouch = false
		flat.CanQuery = true
		flat.Parent = m
		belt:Destroy()
		belt = flat
	end
	local beltTop = belt.Position.Y + belt.Size.Y / 2
	local tex = Instance.new("Texture")
	tex.Name = "BeltTexture"
	tex.Face = Enum.NormalId.Top
	tex.Texture = image
	if spec.flatBelt then
		-- l'image couvre la bande une fois : U en travers, V dans la longueur
		tex.StudsPerTileU = belt.Size.X
		tex.StudsPerTileV = belt.Size.Z
	else
		tex.StudsPerTileU = 1
		tex.StudsPerTileV = 1
		tex.Color3 = rgb(70, 70, 80)
		tex.Transparency = 0.3
	end
	tex.Parent = belt
	-- coureur au milieu de la bande, un peu vers l'avant, tourné vers la console
	attachment("UsePoint", belt, Vector3.new(0, beltTop, belt.Position.Z - 0.5))
	local front = m:FindFirstChild("Frame") or belt
	attachment("UpgradePoint", front, spec.upgrade)
	for _, c in spec.colliders do
		box(m, c[1], c[2], c[3])
	end
	import:Destroy()
	return m
end

local plots = RS.Assets.Plots
local report = {}
for name in VARIANTS do
	local import = workspace:FindFirstChild(name)
	if import then
		local old = plots:FindFirstChild(name)
		if old then old:Destroy() end
		local m = prepare(import, name)
		m.Parent = plots
		local b = m.Belt
		local up = b.UsePoint.WorldPosition
		table.insert(report, string.format("%s rangé : bande y %.3f, z %.2f..%.2f, UsePoint (%.2f, %.3f, %.2f), image %s",
			name, b.Position.Y + b.Size.Y / 2, b.Position.Z - b.Size.Z / 2, b.Position.Z + b.Size.Z / 2, up.X, up.Y, up.Z, b.BeltTexture.Texture))
	else
		table.insert(report, name .. " : pas d'import dans Workspace, " .. (plots:FindFirstChild(name) and "version rangée gardée" or "ABSENT"))
	end
end
table.sort(report)
return table.concat(report, "\n")
