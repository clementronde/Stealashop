--!nocheck
-- Chassis commun des 25 tapis (chef 3D, 26/11), sur le modele du Gold v3 valide par Clement. A coller EN TETE du script
-- d'un lot (tapis_lot<n>.luau) dans la barre de commande, en Edit. Fournit :
--   chassis(theme, opts) -> m, api   : un modele PLOT_Treadmill_<theme>_v3 dans ServerStorage/Previews/TREADMILLS, avec
--     Belt et BeltEnds copies du Gold du jeu (meme longueur, meme hauteur, BeltTexture qui defile, UsePoint,
--     RunBurstPoint), Frame (socle, porte UpgradePoint (8,4 ; 0 ; -4), PostTop_L, PostTop_R, ArchTop, FloorCenter),
--     longerons, console et ConsoleScreen face au coureur, UseZone copiee du Gold, collisions, attribut WidthScale 1,5,
--     dossier <theme>FX (points d'attache des effets du chef VFX). Aucun script.
--   api.p / api.box / api.cyl / api.ball / api.glow : pieces dans les groupes Trim, Columns, Decor, Glow du modele.
-- opts : { frame, frameMat, frameVar, rail, railVar, trim, trimVar, glow, belt (teinte de BeltTexture), screen }
-- Les matieres « Tapis_* » sont les MaterialVariant de MaterialService/Tapis (base Roblox + nom).
local Plots = game:GetService("ReplicatedStorage").Assets.Plots
local GOLD = Plots:FindFirstChild("PLOT_Treadmill_Gold")
local OUT = game:GetService("ServerStorage").Previews:FindFirstChild("TREADMILLS")
local VARIANT_BASE = {
	Tapis_OrTenons = Enum.Material.Metal, Tapis_OrPlaque = Enum.Material.DiamondPlate, Tapis_MarbreVeine = Enum.Material.Marble,
	Tapis_MarbreStyl = Enum.Material.Marble, Tapis_BoisPlanches = Enum.Material.WoodPlanks, Tapis_MetalBrosse = Enum.Material.Metal,
	Tapis_PierreTaillee = Enum.Material.Slate, Tapis_Carton = Enum.Material.Cardboard, Tapis_Circuit = Enum.Material.Metal,
	Tapis_BandeCaoutchouc = Enum.Material.Rubber,
}
local DECK_Z0, DECK_Z1, PZ0, PZ1 = -3.2, 5.1, -4.7, -3.2

local function chassis(theme, opts)
	local name = "PLOT_Treadmill_" .. theme .. "_v3"
	local old = OUT:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("WidthScale", 1.5)
	m.Parent = OUT
	local groups = {}
	for _, g in { "Trim", "Columns", "Decor", "Glow" } do
		local f = Instance.new("Model")
		f.Name = g
		f.Parent = m
		groups[g] = f
	end
	local fx = Instance.new("Folder")
	fx.Name = theme .. "FX"
	fx.Parent = m
	local function p(parent, pname, size, cf, color, o)
		o = o or {}
		local part = Instance.new("Part")
		part.Name = pname
		if o.shape then part.Shape = o.shape end
		part.Size = size
		part.CFrame = cf
		part.Color = Color3.fromHex(color)
		local var = o.var
		if var and VARIANT_BASE[var] then
			part.Material = VARIANT_BASE[var]
			part.MaterialVariant = var
		elseif o.studs then
			part.Material = Enum.Material.Plastic
			part.MaterialVariant = "Studs"
		else
			part.Material = o.mat or Enum.Material.SmoothPlastic
		end
		if part.Material == Enum.Material.Neon then part.CastShadow = false end
		if o.reflect then part.Reflectance = o.reflect end
		if o.transp then part.Transparency = o.transp end
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = groups[parent] or parent
		return part
	end
	local function box(parent, pname, x0, x1, y0, y1, z0, z1, color, o)
		return p(parent, pname, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, o)
	end
	local function cyl(parent, pname, len, dia, cf, color, o)
		o = o or {}
		o.shape = Enum.PartType.Cylinder
		return p(parent, pname, Vector3.new(len, dia, dia), cf, color, o)
	end
	local function ball(parent, pname, s, cf, color, o)
		o = o or {}
		o.shape = Enum.PartType.Ball
		return p(parent, pname, Vector3.new(s, s, s), cf, color, o)
	end
	local function glow(pname, x0, x1, y0, y1, z0, z1, color)
		return box("Glow", pname, x0, x1, y0, y1, z0, z1, color or opts.glow, { mat = Enum.Material.Neon })
	end
	local function attach(parentPart, aname, pos)
		local a = Instance.new("Attachment")
		a.Name = aname
		a.Parent = parentPart
		a.WorldCFrame = CFrame.new(pos)
		return a
	end
	-- bande (copie du Gold du jeu : meme longueur, meme hauteur, texture qui defile, UsePoint, RunBurstPoint)
	for _, n in { "Belt", "BeltEnds" } do
		GOLD[n]:Clone().Parent = m
	end
	for _, d in m.Belt.RunBurstPoint:GetChildren() do
		if d:IsA("ParticleEmitter") and d.Name ~= "RunBurst" then d:Destroy() end -- les effets du Gold restent au Gold
	end
	if opts.belt then m.Belt.BeltTexture.Color3 = Color3.fromHex(opts.belt) end
	-- socle
	local frame = box(m, "Frame", -3.7, 3.7, 0, 0.62, DECK_Z0, DECK_Z1, opts.frame, { var = opts.frameVar, mat = opts.frameMat })
	attach(frame, "UpgradePoint", Vector3.new(8.4, 0, -4))
	attach(frame, "PostTop_L", Vector3.new(-3.75, 7.6, -3.95))
	attach(frame, "PostTop_R", Vector3.new(3.75, 7.6, -3.95))
	attach(frame, "ArchTop", Vector3.new(0, 9.0, -3.95))
	attach(frame, "FloorCenter", Vector3.new(0, 0, 0.95))
	box("Trim", "DeckLip", -3.85, 3.85, 0, 0.25, DECK_Z0 - 0.15, DECK_Z1 + 0.15, opts.trim, { var = opts.trimVar })
	box("Trim", "RearStep", -3.7, 3.7, 0, 0.4, DECK_Z1, DECK_Z1 + 0.6, opts.trim, { var = opts.trimVar })
	-- longerons
	for side = -1, 1, 2 do
		local x0, x1 = math.min(side * 2.62, side * 3.7), math.max(side * 2.62, side * 3.7)
		box("Trim", "Rail" .. side, x0, x1, 0.62, 1.25, DECK_Z0, DECK_Z1, opts.rail, { var = opts.railVar })
		box("Trim", "RailCap" .. side, x0 - 0.02, x1 + 0.02, 1.25, 1.4, DECK_Z0, DECK_Z1, opts.trim, { var = opts.trimVar })
		glow("RailGlow" .. side, side * 2.68 - 0.07, side * 2.68 + 0.07, 1.4, 1.5, DECK_Z0 + 0.3, DECK_Z1 - 0.3)
	end
	-- console face au coureur
	box("Trim", "ConsolePost", -0.45, 0.45, 0.62, 3.6, -3.75, -3.15, opts.trim, { var = opts.trimVar })
	box("Trim", "ConsoleBox", -2.3, 2.3, 3.6, 4.45, -3.9, -3.0, opts.rail, { var = opts.railVar })
	box(m, "ConsoleScreen", -1.05, 1.05, 3.88, 4.18, -3.0, -2.97, opts.screen or "#23242A")
	for i, x in { -1.7, -1.35, 1.35, 1.7 } do
		cyl("Glow", "Button_" .. i, 0.12, 0.26, CFrame.new(x, 4.03, -2.95) * CFrame.Angles(0, math.rad(90), 0), opts.glow, { mat = Enum.Material.Neon })
	end
	-- zone d'usage et collisions (meme emprise que le Gold)
	GOLD.UseZone:Clone().Parent = m
	local function collider(cname, x0, x1, y0, y1, z0, z1)
		local c = box(m, cname, x0, x1, y0, y1, z0, z1, "#A3A2A5")
		c.Transparency = 1
		c.CanCollide = true
	end
	collider("Collision_Base", -3.85, 3.85, 0, 0.83, DECK_Z0, DECK_Z1 + 0.6)
	collider("Collision_Front", -4.6, 4.6, 0, 7.6, PZ0 - 0.2, -3.0)
	collider("Collision_Rear", -3.85, 3.85, 0.83, 1.25, DECK_Z1 - 0.05, DECK_Z1)
	m.WorldPivot = CFrame.new()
	local api = { p = p, box = box, cyl = cyl, ball = ball, glow = glow, attach = attach, fx = fx, frame = frame,
		DECK_Z0 = DECK_Z0, DECK_Z1 = DECK_Z1, PZ0 = PZ0, PZ1 = PZ1 }
	return m, api
end
local function fxPoint(api, aname, pos)
	return api.attach(api.frame, aname, pos) -- point d'attache d'un effet du theme, rempli par le chef VFX
end
local function summary(models)
	local lines = {}
	for _, m in models do
		local _, s = m:GetBoundingBox()
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then n += 1 end
		end
		table.insert(lines, string.format("%s : %d pieces, %.1f x %.1f x %.1f", m.Name, n, s.X, s.Y, s.Z))
	end
	return table.concat(lines, "\n")
end
