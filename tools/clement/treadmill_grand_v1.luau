--!nocheck
--[[
	treadmill_grand_v1.luau (Clément, 2026-11-24, validé par Clément via le chef 3D : « Tapis et objets »).
	Comparaison avec les tapis des jeux du genre (StealAShop-Art/References/3D/Tapis) : nos tapis faisaient à peine
	plus d'un perso de long, sans arche ni néon pour Base, Silver et Fire.

	À lancer en Edit, après treadmill_assets.luau, treadmill_fx.luau, rarest_treadmill_v2.luau et grande_boutique_v1.luau.
	Sauvegarde : ServerStorage/MapBackups/2026-11-24_TapisGrands. Idempotent : l'attribut SizeScale garde l'échelle
	posée (WidthScale = 1,5 de treadmill_assets.luau n'est pas touché, la largeur n'est donc pas refaite deux fois).

	1. Les 11 PLOT_Treadmill_* et le Treadmill du gabarit PLOT_Shop et des 6 boutiques du hub grandissent autour de
	   leur pivot : ×KX en largeur, ×KY en hauteur, ×KZ en longueur (cadre 8,6 → 12,9 de long, 6,8 → 8 de large ;
	   bande 6,3 → 9,5 × 5,2 → 6,1). Pièces, effets, Collision_*, UsePoint et attachments suivent ; UseZone garde ses
	   8 studs de haut. Les noms lus par le code (Belt, BeltArrows, BeltTexture, UsePoint, UseZone, UpgradePoint) ne
	   changent pas.
	2. Une arche à chaque palier (Model Arch) au-dessus de la console : montants et traverse de 1 stud, de 9 studs
	   (Base) à 12 (Void), couleur du cadre du palier ; liseré néon de 0,25 stud sur les faces intérieures, à la
	   couleur de la lueur du palier (cyan pour Base et Silver, qui n'ont pas de lueur). Sans collision.
	3. Chevrons qui défilent : Beam BeltChevrons sur la bande (image de FX_Tutorial_Arrow, blanc, néon), de la console
	   vers l'arrière, TextureSpeed, sans script. L'ancien motif BeltArrows reste (nom lu par TreadmillFxController)
	   mais devient invisible.
	4. Place : le tapis agrandi recule vers la rue pour garder 1 stud devant la façade (z −43) ; UpgradePoint reste
	   à 5 studs devant la console.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local KX, KY, KZ = 1.18, 1.18, 1.5
local FACADE_Z = -43 -- avant de la façade dans le repère de la boutique (Stage_1)
local REAR_GAP = 1 -- jeu entre l'arrière du tapis et la façade
local UPGRADE_AHEAD = 5 -- UpgradePoint devant la console
local ARCH_W = 1 -- section des montants et de la traverse
local NEON_T = 0.25
local CHEVRON_TEXTURE = "rbxassetid://134123418187915" -- FX_Tutorial_Arrow (le nôtre)

local plots = RS.Assets.Plots
local U = require(RS.Shared.Config.Upgrades)
local ORDER = U.TreadmillVariants

local function visBox(m: Model, pv: CFrame)
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "UseZone" and not d.Name:match("^Collision_") then
			local c = pv:ToObjectSpace(d.CFrame)
			local hs = d.Size / 2
			local ex = (c.RightVector * hs.X):Abs() + (c.UpVector * hs.Y):Abs() + (c.LookVector * hs.Z):Abs()
			mn = mn:Min(c.Position - ex)
			mx = mx:Max(c.Position + ex)
		end
	end
	return mn, mx
end

local function axisFactor(a: Vector3, k: Vector3): number
	return math.sqrt((a.X * k.X) ^ 2 + (a.Y * k.Y) ^ 2 + (a.Z * k.Z) ^ 2)
end

-- 1. agrandissement autour du pivot
local function grow(m: Model): boolean
	if m:GetAttribute("SizeScale") then return false end
	local K = Vector3.new(KX, KY, KZ)
	local pv = m:GetPivot()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local k = if d.Name == "UseZone" then Vector3.new(KX, 1, KZ) else K
			local atts = {}
			for _, a in d:GetDescendants() do if a:IsA("Attachment") then atts[a] = pv:ToObjectSpace(a.WorldCFrame) end end
			local cf = pv:ToObjectSpace(d.CFrame)
			local old = d.Size
			local f = { axisFactor(cf.RightVector, k), axisFactor(cf.UpVector, k), axisFactor(cf.LookVector, k) }
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local u = (f[1] * f[2] * f[3]) ^ (1 / 3)
				f = { u, u, u }
			elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
				local u = (f[2] + f[3]) / 2
				f[2], f[3] = u, u
			end
			d.Size = Vector3.new(old.X * f[1], old.Y * f[2], old.Z * f[3])
			local y = if d.Name == "UseZone" then cf.Y else cf.Y * k.Y
			d.CFrame = pv * (CFrame.new(cf.X * k.X, y, cf.Z * k.Z) * cf.Rotation)
			for a, l in atts do
				a.WorldCFrame = pv * (CFrame.new(l.X * k.X, l.Y * k.Y, l.Z * k.Z) * l.Rotation)
			end
			if d.Name == "Belt" then
				for _, t in d:GetChildren() do
					if t:IsA("Texture") and t.StudsPerTileU > 1.01 then
						t.StudsPerTileU *= d.Size.X / old.X
						t.StudsPerTileV *= d.Size.Z / old.Z
					end
				end
			end
		end
	end
	m:SetAttribute("SizeScale", K)
	return true
end

local function mainColor(m: Model): Color3
	local f = m:FindFirstChild("Frame")
	if f and f:IsA("BasePart") then return f.Color end
	local best, vol = Color3.fromRGB(183, 187, 195), 0
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Transparency < 0.5 and d.Material ~= Enum.Material.Neon and d.Name ~= "Belt" and d.Name ~= "BeltEnds" and not d.Name:match("^Collision_") and d.Name ~= "UseZone" then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then best, vol = d.Color, v end
		end
	end
	return best
end

local function glowColor(m: Model): Color3
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Transparency < 0.9 then return d.Color end
	end
	return Color3.fromRGB(0, 200, 255) -- Base et Silver, sans lueur : cyan (un liseré blanc disparaît sur le cadre blanc)
end

-- 2. arche au-dessus de la console
local function arch(m: Model, tier: number)
	local old = m:FindFirstChild("Arch")
	if old then old:Destroy() end
	local pv = m:GetPivot()
	local belt = m:FindFirstChild("Belt")
	local mn, mx = visBox(m, pv)
	local H = 9 + 3 * (tier - 1) / math.max(#ORDER - 1, 1)
	local half = 4 -- cadre de 8 de large
	-- au-dessus de la console : juste devant la bande (avant du tapis, vers −Z)
	local cz = mn.Z + 1.4
	if belt and belt:IsA("BasePart") then
		local bc = pv:ToObjectSpace(belt.CFrame)
		cz = bc.Z - belt.Size.Z / 2 - 0.9
	end
	local A = Instance.new("Model")
	A.Name = "Arch"
	local color, glow = mainColor(m), glowColor(m)
	local function p(name, x, y, z, sx, sy, sz, c, mat)
		local q = Instance.new("Part")
		q.Name = name
		q.Anchored = true
		q.CanCollide = false
		q.CanQuery = false
		q.CanTouch = false
		q.TopSurface = Enum.SurfaceType.Smooth
		q.BottomSurface = Enum.SurfaceType.Smooth
		q.Size = Vector3.new(sx, sy, sz)
		q.CFrame = pv * CFrame.new(x, y, z)
		q.Color = c
		q.Material = mat
		q.CastShadow = mat ~= Enum.Material.Neon
		q.Parent = A
		return q
	end
	local px = half - ARCH_W / 2
	p("Post_L", -px, H / 2, cz, ARCH_W, H, ARCH_W, color, Enum.Material.SmoothPlastic)
	p("Post_R", px, H / 2, cz, ARCH_W, H, ARCH_W, color, Enum.Material.SmoothPlastic)
	p("Beam", 0, H - ARCH_W / 2, cz, 2 * half, ARCH_W, ARCH_W, color, Enum.Material.SmoothPlastic)
	local inner = half - ARCH_W
	local nz = ARCH_W * 0.6
	p("Neon_L", -(inner + NEON_T / 2), (H - ARCH_W) / 2 + 0.4, cz, NEON_T, H - ARCH_W - 0.8, nz, glow, Enum.Material.Neon)
	p("Neon_R", inner + NEON_T / 2, (H - ARCH_W) / 2 + 0.4, cz, NEON_T, H - ARCH_W - 0.8, nz, glow, Enum.Material.Neon)
	p("Neon_Top", 0, H - ARCH_W - NEON_T / 2, cz, 2 * inner, NEON_T, nz, glow, Enum.Material.Neon)
	A.Parent = m
	return H
end

-- 3. chevrons qui défilent sur la bande
local function chevrons(m: Model)
	local belt = m:FindFirstChild("Belt")
	if not (belt and belt:IsA("BasePart")) then return "pas de Belt" end
	for _, n in { "BeltChevrons", "ChevronStart", "ChevronEnd" } do
		local o = belt:FindFirstChild(n)
		if o then o:Destroy() end
	end
	local pv = m:GetPivot()
	local bc = pv:ToObjectSpace(belt.CFrame)
	local top = bc.Y + belt.Size.Y / 2 + 0.06
	local z0, z1 = bc.Z - belt.Size.Z / 2 + 0.3, bc.Z + belt.Size.Z / 2 - 0.3
	-- Axis des attachments vers le haut : le Beam est posé à plat sur la bande
	local flat = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis)
	local a0 = Instance.new("Attachment")
	a0.Name = "ChevronStart"
	a0.Parent = belt
	a0.WorldCFrame = pv * CFrame.new(0, top, z0) * flat
	local a1 = Instance.new("Attachment")
	a1.Name = "ChevronEnd"
	a1.Parent = belt
	a1.WorldCFrame = pv * CFrame.new(0, top, z1) * flat
	local b = Instance.new("Beam")
	b.Name = "BeltChevrons"
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = false
	b.Texture = CHEVRON_TEXTURE
	b.TextureMode = Enum.TextureMode.Static
	b.TextureLength = (z1 - z0) / 4
	b.TextureSpeed = 0.6
	b.Width0, b.Width1 = 3.5, 3.5
	b.Segments = 1
	b.Color = ColorSequence.new(Color3.new(1, 1, 1))
	b.Transparency = NumberSequence.new(0.05)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 2
	b.ZOffset = 0
	b.Parent = belt
	local arrows = m:FindFirstChild("BeltArrows")
	if arrows and arrows:IsA("BasePart") then arrows.Transparency = 1 end
	return "ok"
end

-- sauvegarde
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-24_TapisGrands") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-24_TapisGrands"
	for _, v in plots:GetChildren() do
		if v.Name:match("^PLOT_Treadmill_") then v:Clone().Parent = f end
	end
	local t = plots.PLOT_Shop.Treadmill:Clone()
	t.Name = "PLOT_Shop.Treadmill"
	t.Parent = f
	for _, s in workspace.Map.Hub.Shops:GetChildren() do
		local st = s:IsA("Model") and s:FindFirstChild("Treadmill")
		if st then
			local c = st:Clone()
			c.Name = s.Name .. ".Treadmill"
			c.Parent = f
		end
	end
	f.Parent = backups
end

local out = {}
-- variantes : agrandir, arche, chevrons, et place commune (même pivot pour toutes)
local maxRear, minFront = -1e9, 1e9
for i, name in ORDER do
	local v = plots:FindFirstChild("PLOT_Treadmill_" .. name)
	if v then
		grow(v)
		local H = arch(v, i)
		local c = chevrons(v)
		local mn, mx = visBox(v, v:GetPivot())
		maxRear = math.max(maxRear, mx.Z)
		minFront = math.min(minFront, mn.Z)
		table.insert(out, string.format("%-12s %.1f × %.1f × %.1f, arche %.1f, chevrons %s", name, mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z, H, c))
	else
		table.insert(out, name .. " : variante absente")
	end
end
-- UpgradePoint commun : 5 studs devant la console la plus avancée
for _, name in ORDER do
	local v = plots:FindFirstChild("PLOT_Treadmill_" .. name)
	local up = v and v:FindFirstChild("UpgradePoint", true)
	if up then
		local rot = v:GetPivot():ToObjectSpace(up.WorldCFrame).Rotation
		up.WorldCFrame = v:GetPivot() * CFrame.new(0, 0, minFront - UPGRADE_AHEAD) * rot
	end
end

-- tapis des boutiques : copie de Base à la nouvelle place
local base = plots:FindFirstChild("PLOT_Treadmill_Base")
local function placeShop(shop: Model, pv: CFrame)
	local old = shop:FindFirstChild("Treadmill")
	if not old then return shop.Name .. " : pas de Treadmill" end
	local lp = pv:ToObjectSpace(old:GetPivot())
	local z = FACADE_Z - REAR_GAP - maxRear
	local newLocal = CFrame.new(lp.X, lp.Y, math.min(lp.Z, z)) * lp.Rotation
	local attrs = old:GetAttributes()
	local tags = game:GetService("CollectionService"):GetTags(old)
	local c = base:Clone()
	c.Name = "Treadmill"
	for k, val in attrs do if c:GetAttribute(k) == nil then c:SetAttribute(k, val) end end
	for _, tg in tags do game:GetService("CollectionService"):AddTag(c, tg) end
	c:PivotTo(pv * newLocal)
	c.Parent = old.Parent
	old:Destroy()
	local up = c:FindFirstChild("UpgradePoint", true)
	local p = pv:ToObjectSpace(c:GetPivot())
	return string.format("%s : pivot (%.2f ; %.2f), UpgradePoint (%.2f ; %.2f)", shop.Name, p.X, p.Z, pv:ToObjectSpace(up.WorldCFrame).X, pv:ToObjectSpace(up.WorldCFrame).Z)
end
table.insert(out, placeShop(plots.PLOT_Shop, CFrame.identity))
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(out, placeShop(s, s:GetPivot())) end
end
print("[treadmill_grand_v1]\n" .. table.concat(out, "\n"))
return table.concat(out, "\n")
