-- Zones au sol de la zone safe remises (Clément, session de test du 2026-11-25, par le chef map : « il manque les zones de
-- Pawn Shop, Aura, Spin the Wheel… quand on marche sur cette zone, ça ouvre le Pawn Shop. Il faut les remettre »).
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relancer refait la même chose.
-- Ce qui manquait : les 7 GroundDisc (disque doux du 2026-11-17 : pièce invisible, SurfaceGui Disc avec Fill et des
-- anneaux Ring_N, particules LightRise et Sparkles), retirés avec le jardin (L-322, point 5) et gardés dans
-- ServerStorage/MapBackups/2026-11-24_HubAvantJardin/GroundDiscs. Les stands, la roue, le cadeau et le noob n'ont pas
-- bougé depuis (L-323) : chaque disque revient tel quel dans le modèle le plus proche (4 stands, ENV_Hub_FreeGift,
-- ENV_Hub_InviteNoob, ENV_Hub_Wheel), au-dessus du damier (dessus à 0,12, cases à 0,03).
-- Les plaques ShopPad (invisibles depuis le 2026-11-17, dessus à 0,22 au-dessus du sol à 0) et la WheelZone
-- (ENV_Hub_Wheel/Zone) sont en place : rien à y changer. Décor : sans collision ni requête ni toucher, aucun script.
-- Sauvegarde : ServerStorage/Assets/MapBackup_2026-11-25_ZonesSol (ce que le script retire, s'il y a lieu).
-- Clément, même jour (« les zones peuvent être rectangulaires pour les shops ? ») : sous les 4 stands, le disque devient
-- une zone rectangulaire GroundZone, au même style (voile au centre, bandes qui s'éclairent vers le bord puis s'éteignent,
-- mêmes particules) et calée sur la plaque ShopPad : son bord lumineux tombe à 1 stud autour de la plaque, là où le stand
-- s'ouvre vraiment. La roue, le cadeau et le noob gardent leur disque rond.
local hub = workspace.Map.Hub
local SS = game:GetService("ServerStorage")
local src = SS.MapBackups["2026-11-24_HubAvantJardin"]:FindFirstChild("GroundDiscs", true)
assert(src, "GroundDiscs introuvables dans la sauvegarde 2026-11-24_HubAvantJardin")

local bk = SS.Assets:FindFirstChild("MapBackup_2026-11-25_ZonesSol")
if not bk then
	bk = Instance.new("Folder"); bk.Name = "MapBackup_2026-11-25_ZonesSol"
	bk:SetAttribute("Note", "Zones au sol remises (hub_zones_sol.luau) : les disques viennent de MapBackups/2026-11-24_HubAvantJardin/GroundDiscs ; ce dossier garde ce qui a été retiré pour eux")
	bk.Parent = SS.Assets
end

-- les modèles qui portent une zone
local targets = {}
for _, grp in { hub.Stalls, hub.Zones } do
	for _, m in grp:GetChildren() do
		if m:IsA("Model") and m.Name ~= "ENV_Hub_Leaderboard" and m.Name ~= "ENV_Hub_LeaderboardStatue" then table.insert(targets, m) end
	end
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local out = {}
for _, d in src:GetChildren() do
	local best, bd = nil, math.huge
	for _, m in targets do
		local cf = m:GetBoundingBox()
		local dist = (flat(cf.Position) - flat(d.Position)).Magnitude
		if dist < bd then best, bd = m, dist end
	end
	if best and bd < 20 then
		local old = best:FindFirstChild("GroundDisc"); if old then old:Destroy() end
		local c = d:Clone()
		c.CFrame = CFrame.new(d.Position.X, 0.07, d.Position.Z)
		c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.CastShadow = false
		c.Parent = best
		table.insert(out, string.format("%s : disque de %.0f en (%.0f ; %.0f)", best.Name, c.Size.X, c.Position.X, c.Position.Z))
	else
		table.insert(out, string.format("disque en (%.0f ; %.0f) sans modèle proche, laissé de côté", d.Position.X, d.Position.Z))
	end
end

-- stands : le disque devient une zone rectangulaire calée sur la plaque ShopPad
local MARGIN, RIM = 1, 0.9 -- marge autour de la plaque ; le bord lumineux (bande la plus vive) est à 90 % du rectangle
local PPS, STEP = 16, 0.3 -- pixels par stud du SurfaceGui, largeur d'une bande en studs (4,8 px, comme le disque)
local function rectZone(stall, disc)
	local pad = stall:FindFirstChild("ShopPad", true)
	if not (pad and pad:IsA("BasePart")) then return nil end
	-- emprise de la plaque au sol, dans le repère du monde
	local ex = math.abs(pad.CFrame.RightVector.X) * pad.Size.X + math.abs(pad.CFrame.LookVector.X) * pad.Size.Z
	local ez = math.abs(pad.CFrame.RightVector.Z) * pad.Size.X + math.abs(pad.CFrame.LookVector.Z) * pad.Size.Z
	local W, H = (ex + 2 * MARGIN) / RIM, (ez + 2 * MARGIN) / RIM
	local R = disc.Size.X / 2 -- rayon du disque d'origine : les bandes gardent leur distance au bord, en studs
	local color = disc.Disc.Fill.BackgroundColor3
	local z = Instance.new("Part"); z.Name = "GroundZone"
	z.Anchored = true; z.CanCollide = false; z.CanQuery = false; z.CanTouch = false; z.CastShadow = false
	z.Transparency = 1; z.Material = Enum.Material.SmoothPlastic
	z.Size = Vector3.new(W, 0.1, H); z.CFrame = CFrame.new(pad.Position.X, 0.07, pad.Position.Z)
	local g = Instance.new("SurfaceGui"); g.Name = "Zone"; g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = PPS
	g.LightInfluence = 0; g.Brightness = disc.Disc.Brightness; g.MaxDistance = disc.Disc.MaxDistance; g.ClipsDescendants = false
	local function rect(name, inset)
		local f = Instance.new("Frame"); f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(1 - 2 * inset / W, 1 - 2 * inset / H)
		f.BorderSizePixel = 0; f.BackgroundColor3 = color; f.BackgroundTransparency = 1
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, math.round(0.6 * PPS)); c.Parent = f
		f.Parent = g
		return f
	end
	-- les bandes du disque, à la même distance du bord (studs) et à la même transparence ; celles qui ne tiennent pas
	-- dans le rectangle (trop au centre) laissent la place au voile Fill
	local deepest = math.huge
	local n = 0
	for _, ring in disc.Disc:GetChildren() do
		if ring.Name:match("^Ring_") then
			local inset = (1 - ring.Size.X.Scale) * R
			if inset < math.min(W, H) / 2 - 0.6 then
				local s = ring.UIStroke:Clone()
				s.Thickness = STEP * PPS
				s.Parent = rect(ring.Name, inset)
				deepest = math.min(deepest, inset)
				n += 1
			end
		end
	end
	local fill = rect("Fill", deepest)
	fill.BackgroundTransparency = disc.Disc.Fill.BackgroundTransparency
	g.Parent = z
	-- particules du disque, en boîte sur le rectangle
	for _, e in disc:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Shape = Enum.ParticleEmitterShape.Box
			c.Rate = e.Rate * (W * H) / (math.pi * R * R)
			c.Parent = z
		end
	end
	z.Parent = stall
	disc:Destroy()
	return string.format("%s : zone rectangulaire %.1f × %.1f sur la plaque (%d bandes)", stall.Name, W, H, n)
end
for _, s in hub.Stalls:GetChildren() do
	local d = s:FindFirstChild("GroundDisc")
	if d then
		local old = s:FindFirstChild("GroundZone"); if old then old:Destroy() end
		table.insert(out, rectZone(s, d) or (s.Name .. " : pas de plaque ShopPad, disque gardé"))
	end
end

-- déco du jardin posée sur un disque : rangée dans la sauvegarde (fleurs et brins d'herbe de la place)
local moved = 0
local decor = hub:FindFirstChild("Garden") and hub.Garden:FindFirstChild("Decor")
if decor then
	for _, m in targets do
		local disc = m:FindFirstChild("GroundDisc") or m:FindFirstChild("GroundZone")
		if disc then
			for _, cat in { "Front", "Grass" } do
				local c = decor:FindFirstChild(cat)
				for _, x in (c and c:GetChildren() or {}) do
					local p = x:IsA("Model") and x:GetPivot().Position or x.Position
					if (flat(p) - flat(disc.Position)).Magnitude < disc.Size.X / 2 + 0.5 then x.Parent = bk; moved += 1 end
				end
			end
		end
	end
end
table.insert(out, "déco rangée dans la sauvegarde : " .. moved)
return table.concat(out, "\n")
