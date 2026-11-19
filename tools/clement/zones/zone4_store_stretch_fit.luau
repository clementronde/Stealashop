--!nocheck
-- Zone 4 : décor dégagé autour des magasins agrandis (décision de Clément du 2026-11-17 : magasins PNJ de 60 × 72
-- à 78 × 108, étirés en place par tools/clement/store_stretch.luau). Nouvelle emprise des deux magasins :
-- x 402,4..481,6 ; Bijouterie z 52,4..162,1 ; Horlogerie z -162,1..-52,4.
-- Ce script ne touche à aucun STORE_*. Il décale, raccourcit ou retire seulement le décor de la zone 4 qui entre
-- dans cette emprise (Street_LosAngeles, District_LosAngeles) et raccourcit les murets du greybox de la zone 4.
-- À lancer dans Studio (mode Edit) après zone4_losangeles.luau, corridor_widen.luau et zone4_ambience.luau.
-- Relançable : chaque modèle traité reçoit l'attribut StoreStretchFit et n'est plus retouché ; les murets et les
-- retraits sont posés en valeurs absolues.

local rgb = Color3.fromRGB
local Z = workspace.Map.Zone_4
local S, D = Z.Street_LosAngeles, Z.District_LosAngeles
local MARK = "StoreStretchFit"
local log = {}

local function done(m) return m:GetAttribute(MARK) == true end
local function mark(m) m:SetAttribute(MARK, true) end
local function shift(m, v, why)
	if not m or done(m) then return end
	m:PivotTo(m:GetPivot() + v); mark(m)
	table.insert(log, string.format("%s décalé de (%.1f, %.1f) : %s", m.Name, v.X, v.Z, why))
end
-- Étire les pièces d'un modèle (toutes droites) le long de x : [a0, a1] devient [b0, b1]
local function squeezeX(m, a0, a1, b0, b1)
	if not m or done(m) then return end
	local k = (b1 - b0) / (a1 - a0)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local x = b0 + (p.Position.X - a0) * k
			local r = p.CFrame - p.Position
			local sx = math.abs(p.CFrame.RightVector.X) > 0.99 and p.Size.X * k or p.Size.X
			local sz = math.abs(p.CFrame.LookVector.X) > 0.99 and p.Size.Z * k or p.Size.Z
			local sy = math.abs(p.CFrame.UpVector.X) > 0.99 and p.Size.Y * k or p.Size.Y
			p.Size = Vector3.new(sx, sy, sz)
			p.CFrame = CFrame.new(x, p.Position.Y, p.Position.Z) * r
		end
	end
	mark(m)
	table.insert(log, string.format("%s resserré de x %.1f..%.1f à x %.1f..%.1f", m.Name, a0, a1, b0, b1))
end
local function remove(parent, name, why)
	local m = parent:FindFirstChild(name)
	if m then m:Destroy(); table.insert(log, name .. " retiré : " .. why) end
end
local function slab(parent, name, x0, y0, z0, x1, y1, z1, color, studs)
	local old = parent:FindFirstChild(name); if old then old:Destroy() end
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanTouch = false
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" else p.Material = Enum.Material.SmoothPlastic end
	p:SetAttribute("CorridorWiden", 30)
	p.Parent = parent
	return p
end

-- 1) Murets du greybox de la zone 4 : ils s'arrêtent aux nouveaux côtés des magasins
local g = workspace.Greybox.Corridor.Zone_4.Ground
for _, s in { 1, -1 } do
	local t = s > 0 and "N" or "S"
	g["SideWall_" .. t .. "1"].Size = Vector3.new(34.4, 18, 1.5); g["SideWall_" .. t .. "1"].Position = Vector3.new(385.2, 9, s * 60.75)
	g["SideWall_" .. t .. "2"].Size = Vector3.new(48.4, 18, 1.5); g["SideWall_" .. t .. "2"].Position = Vector3.new(505.8, 9, s * 60.75)
end
table.insert(log, "murets : x 368..402,4 et 481,6..530")

-- 2) Boutiques plaquées sur les murets : la 3e (ouest) et la 4e (est) de chaque trottoir sont dans les magasins ;
--    les trous de 4,5 studs qui restent sont bouchés par un pan de façade crème bordé d'or
local B = S.Boutiques
for _, n in { "Boutique_N3", "Boutique_N4", "Boutique_S3", "Boutique_S4" } do remove(B, n, "dans le magasin agrandi") end
local cream, gold, white = rgb(240, 232, 214), rgb(212, 175, 55), rgb(250, 248, 242)
for _, s in { 1, -1 } do
	local t = s > 0 and "N" or "S"
	for _, gap in { { "W", 397.9, 402.4 }, { "E", 481.6, 486.1 } } do
		local nm = "Boutique_Filler_" .. t .. gap[1]
		local f = B:FindFirstChild(nm) or Instance.new("Model")
		f.Name = nm; f.Parent = B
		slab(f, "Wall", gap[2], 0, s * 59.8, gap[3], 24, s * 61.8, cream, true)
		slab(f, "GoldBand", gap[2], 22.6, s * 59.62, gap[3], 23, s * 59.8, gold)
		slab(f, "Cornice", gap[2], 24, s * 59.1, gap[3], 24.75, s * 61.8, white)
	end
end

-- 3) Rue : palmier N3 sorti de la façade (avec sa fosse et ses palmes qui tombent), tours et panneau décalés
local dx = 491 - 482.5
shift(S.Palms:FindFirstChild("Palm_N3"), Vector3.new(dx, 0, 0), "ses palmes entraient dans la façade")
shift(S.Palms:FindFirstChild("TreeWell_N3"), Vector3.new(dx, 0, 0), "suit le palmier")
shift(S.Ambience:FindFirstChild("FX_Z4_PalmLeaves_N3"), Vector3.new(dx, 0, 0), "suit le palmier")
shift(S.Skyline:FindFirstChild("Tower_N1"), Vector3.new(-1.5, 0, 0), "touchait le côté ouest")
shift(S.Skyline:FindFirstChild("Tower_N2"), Vector3.new(3, 0, 0), "touchait le côté est")
shift(S.Skyline:FindFirstChild("Tower_S2"), Vector3.new(4.5, 0, 0), "touchait le côté est")
shift(S.Billboards:FindFirstChild("Billboard_N"), Vector3.new(-4.5, 0, 0), "touchait le côté ouest")

-- 4) Quartier : immeubles resserrés, tours de fond reculées derrière les magasins (sol prolongé jusqu'à |z| 200)
local Bd = D.Buildings
squeezeX(Bd:FindFirstChild("Apartments_N"), 374.5, 405.5, 374.5, 401.5)
squeezeX(Bd:FindFirstChild("Hotel_N"), 478.5, 523.5, 483, 523.5)
squeezeX(Bd:FindFirstChild("SoundStage_S"), 480, 522, 484, 522)
shift(Bd:FindFirstChild("StarTower"), Vector3.new(0, 0, 27.5), "reculée derrière la bijouterie (z 163..196)")
shift(Bd:FindFirstChild("Tower_S3"), Vector3.new(0, 0, -27.5), "reculée derrière l'horlogerie")
local sand, lawn = rgb(224, 200, 170), rgb(118, 168, 78)
for _, s in { 1, -1 } do
	local t = s > 0 and "N" or "S"
	local gr = slab(D.Ground, "Ground_" .. t .. "_BackFar", 402.4, -2, s * 170, 481.6, 0, s * 200, sand, true)
	gr.CanCollide = true
	slab(D.Ground, "Lawn_" .. t .. "_BackFar", 403, 0, s * 170, 481, 0.1, s * 199, lawn, true)
end
local P = D.Palms
for _, n in { "Palm_B3", "Palm_B4" } do shift(P:FindFirstChild(n), Vector3.new(0, 0, 39), "suit la Star Tower") end
for _, n in { "Palm_B8", "Palm_B9" } do shift(P:FindFirstChild(n), Vector3.new(0, 0, -38), "suit la tour d'hôtel") end
shift(P:FindFirstChild("Palm_B11"), Vector3.new(11.4, 0, 0), "sorti du côté est de l'horlogerie")
for _, n in { "Palm_B5", "Palm_B6", "Palm_B10" } do remove(P, n, "pas de place hors du magasin agrandi") end

-- 5) Contrôle : plus aucune pièce visible de mon décor dans la nouvelle emprise, au-dessus du sol
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local h = Vector3.new(
		(math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z) / 2,
		(math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z) / 2,
		(math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z) / 2)
	return cf.Position - h, cf.Position + h
end
local hits = {}
for _, f in { S, D } do
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local a, b = aabb(d)
			for _, s in { 1, -1 } do
				local z0, z1 = s > 0 and 52.5 or -162.1, s > 0 and 162.1 or -52.5
				if a.X < 481.5 and b.X > 402.5 and a.Z < z1 and b.Z > z0 and b.Y > 0.6 then
					local m = d; while m.Parent and m.Parent.Parent ~= f do m = m.Parent end
					hits[m.Name] = true
				end
			end
		end
	end
end
local hl = {}
for k in hits do table.insert(hl, k) end
table.sort(hl)
table.insert(log, "dans l'emprise après correction : " .. (#hl == 0 and "rien" or table.concat(hl, ", ")))
return table.concat(log, "\n")
