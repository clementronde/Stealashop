--!nocheck
-- Socle commun des 24 tapis v4 (chef 3D, 27/11), apres le retour de Clement du 26/11 (« ils se ressemblent trop ») et le
-- tableau des 25 valide (StealAShop-Art/Training/Treadmill/2026-11-26_tableau_25_tapis.md). A coller EN TETE du script
-- d'un lot, en Edit. Seuls sont communs : la bande (Belt, BeltEnds copies du Gold du jeu : meme longueur, meme hauteur,
-- BeltTexture qui defile, UsePoint, RunBurstPoint), UseZone (12,75 x 8 x 13,1) et les points du contrat sur Frame
-- (UpgradePoint (8,4 ; 0 ; -4), PostTop_L/R, ArchTop, FloorCenter). La silhouette, elle, est propre a chaque tapis.
--   socle(theme, opts) -> m, api   : modele PLOT_Treadmill_<theme>_v4 dans ServerStorage/Previews/TREADMILLS ;
--     opts.deck = { x0, x1, z0, z1, color, var, mat } (le Frame sous la bande), opts.belt = teinte de BeltTexture
--   api.p / box / cyl / ball / glow / seg / label / attach / collider / moving
--   api.moving(name, pivotPos, attrs) : Model dans le groupe Moving, pivot = centre du mouvement, avec les attributs
--     FxMotion (« Spin », « Swing », « Bob », « Slide », ou plusieurs separes par une virgule), FxAxis (Vector3, axe
--     monde), FxSpeed (degres/s), FxAmplitude (studs, ou degres pour Swing), FxPeriod (s), FxOnRun (seulement en course).
--     C'est le code de Cantin qui fera bouger ces modeles (regle generale FxMotion) : aucun script ici.
-- Points d'effet du chef VFX : Attachments Fx_<Element>, poses sur l'element qui bouge.
local Plots = game:GetService("ReplicatedStorage").Assets.Plots
local GOLD = Plots:FindFirstChild("PLOT_Treadmill_Gold")
local OUT = game:GetService("ServerStorage").Previews:FindFirstChild("TREADMILLS")
local VARIANT_BASE = {
	Tapis_OrTenons = Enum.Material.Metal, Tapis_OrPlaque = Enum.Material.DiamondPlate, Tapis_MarbreVeine = Enum.Material.Marble,
	Tapis_MarbreStyl = Enum.Material.Marble, Tapis_BoisPlanches = Enum.Material.WoodPlanks, Tapis_MetalBrosse = Enum.Material.Metal,
	Tapis_PierreTaillee = Enum.Material.Slate, Tapis_Carton = Enum.Material.Cardboard, Tapis_Circuit = Enum.Material.Metal,
	Tapis_BandeCaoutchouc = Enum.Material.Rubber,
}
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre vertical
local FACE = CFrame.Angles(0, math.rad(90), 0) -- cylindre dans l'axe Z

local function socle(theme, opts)
	local name = "PLOT_Treadmill_" .. theme .. "_v4"
	local old = OUT:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("WidthScale", 1.5)
	m:SetAttribute("Theme", theme)
	m.Parent = OUT
	local groups = {}
	for _, g in { "Body", "Decor", "Glow", "Moving" } do
		local f = Instance.new("Model")
		f.Name = g
		f.Parent = m
		groups[g] = f
	end
	local function p(parent, pname, size, cf, color, o)
		o = o or {}
		local part = Instance.new(if o.wedge then "WedgePart" else "Part")
		part.Name = pname
		if o.shape then part.Shape = o.shape end
		part.Size = size
		part.CFrame = cf
		part.Color = Color3.fromHex(color)
		local var = o.var
		if var and VARIANT_BASE[var] then
			part.Material = VARIANT_BASE[var]
			part.MaterialVariant = var
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
		return p(parent, pname, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
			CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, o)
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
	local function glow(parent, pname, x0, x1, y0, y1, z0, z1, color)
		return box(parent, pname, x0, x1, y0, y1, z0, z1, color, { mat = Enum.Material.Neon })
	end
	-- piece droite d'un point a un autre : section w (largeur, axe « right ») x h (axe « up »), up = indication d'orientation
	local function seg(parent, pname, a, b, w, h, color, up, o)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		return p(parent, pname, Vector3.new(w, h, len), CFrame.lookAt(mid, b, up or Vector3.yAxis), color, o)
	end
	-- texte sur une face (SurfaceGui, aucun script)
	local function label(part, face, txt, color, o)
		o = o or {}
		local sg = Instance.new("SurfaceGui")
		sg.Name = o.name or "Label"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = o.pps or 60
		sg.LightInfluence = o.light or 1
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = o.font or Enum.Font.FredokaOne
		t.Text = txt
		t.TextScaled = true
		t.TextWrapped = true
		t.TextColor3 = Color3.fromHex(color)
		t.Rotation = o.rot or 0
		if o.align then t.TextXAlignment = o.align end
		if o.stroke then
			local s = Instance.new("UIStroke")
			s.Color = Color3.fromHex(o.stroke)
			s.Thickness = o.strokeT or 2
			s.Parent = t
		end
		t.Parent = sg
		sg.Parent = part
		return sg, t
	end
	local function attach(parentPart, aname, pos)
		local a = Instance.new("Attachment")
		a.Name = aname
		a.Parent = parentPart
		a.WorldCFrame = CFrame.new(pos)
		return a
	end
	local function collider(cname, x0, x1, y0, y1, z0, z1)
		local c = box(m, cname, x0, x1, y0, y1, z0, z1, "#A3A2A5")
		c.Transparency = 1
		c.CanCollide = true
		return c
	end
	local function moving(mname, pivotPos, attrs)
		local mm = Instance.new("Model")
		mm.Name = mname
		for k, v in attrs do mm:SetAttribute(k, v) end
		mm.Parent = groups.Moving
		mm.WorldPivot = CFrame.new(pivotPos)
		return mm
	end
	-- bande : copie du Gold du jeu (meme longueur, meme hauteur, texture qui defile, UsePoint, RunBurstPoint)
	for _, n in { "Belt", "BeltEnds" } do
		GOLD[n]:Clone().Parent = m
	end
	for _, d in m.Belt.RunBurstPoint:GetChildren() do
		if d:IsA("ParticleEmitter") and d.Name ~= "RunBurst" then d:Destroy() end -- les effets du Gold restent au Gold
	end
	if opts.belt then m.Belt.BeltTexture.Color3 = Color3.fromHex(opts.belt) end
	-- Frame (sous la bande) et points du contrat
	local d = opts.deck
	local frame = box(m, "Frame", d[1], d[2], 0, 0.62, d[3], d[4], d[5], { var = d[6], mat = d[7] })
	attach(frame, "UpgradePoint", Vector3.new(8.4, 0, -4))
	attach(frame, "PostTop_L", Vector3.new(-3.75, 7.6, -3.95))
	attach(frame, "PostTop_R", Vector3.new(3.75, 7.6, -3.95))
	attach(frame, "ArchTop", Vector3.new(0, 9.0, -3.95))
	attach(frame, "FloorCenter", Vector3.new(0, 0, 0.95))
	GOLD.UseZone:Clone().Parent = m
	collider("Collision_Base", d[1], d[2], 0, 0.83, d[3], d[4])
	m.WorldPivot = CFrame.new()
	local api = { p = p, box = box, cyl = cyl, ball = ball, glow = glow, seg = seg, label = label, attach = attach,
		collider = collider, moving = moving, frame = frame, groups = groups, model = m }
	return m, api
end

-- controle : pieces visibles, boite englobante hors UseZone et collisions, depassement de l'emprise
local function summary(models)
	local lines = {}
	for _, m in models do
		local n = 0
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "UseZone" then
				n += 1
				local cf, s = d.CFrame, d.Size / 2
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					local w = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
					lo, hi = lo:Min(w), hi:Max(w)
				end end end
			end
		end
		local out = (lo.X < -6.4 or hi.X > 6.4 or lo.Z < -7.33 or hi.Z > 5.83 or hi.Y > 10.05) and "  HORS EMPRISE" or ""
		local moves = {}
		for _, mm in m.Moving:GetChildren() do table.insert(moves, mm.Name .. "(" .. tostring(mm:GetAttribute("FxMotion")) .. ")") end
		local fx = {}
		for _, a in m:GetDescendants() do if a:IsA("Attachment") and a.Name:sub(1, 3) == "Fx_" then table.insert(fx, a.Name) end end
		table.insert(lines, string.format("%s : %d pieces, x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f%s | bouge : %s | %s", m.Name, n,
			lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z, out, table.concat(moves, ", "), table.concat(fx, ", ")))
	end
	return table.concat(lines, "\n")
end
