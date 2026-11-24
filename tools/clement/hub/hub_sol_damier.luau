-- Damier du sol du hub, refait d'un seul tenant (Clément, 2026-11-24 : « depuis le déplacement des boutiques, le damier
-- n'est pas uniforme sur le sol »). Le damier de hub_ambiance_ville.luau sautait les cases cachées au moment où il a été
-- posé : il restait des trous (cases claires) là où étaient les anciennes boutiques et les massifs ronds retirés.
-- À lancer dans Studio (MCP execute_luau, mode Edit) APRÈS hub_jardin.luau (et après hub_ambiance_ville.luau, dont il
-- remplace Map/Hub/Ambiance/FloorTiles). Relancer refait la même chose.
--  1) sol (Ground_Plaza, Ground_Flank_N, Ground_Flank_S, dans les murs du hub) : une case foncée sur deux, cases de 8
--     alignées sur le monde, sauf là où une pièce opaque la cache entièrement (sol de boutique, stand, massif, mur) ;
--  2) dessus des massifs, terrasses et talus (Garden/Beds) : mêmes deux verts et même damier (aligné sur le monde quand
--     le dessus est droit, sur le massif quand il est tourné), dans Map/Hub/Ambiance/RaisedTiles : la pelouse se lit
--     d'un seul tenant, reliefs compris.
-- Cases en décor (ni collision, ni requête, ni toucher, ni ombre), Plastic + Studs. Aucun script.
local rgb = Color3.fromRGB
local hub = workspace.Map.Hub
local TILE_A, TILE_B, CELL = rgb(106, 186, 88), rgb(94, 172, 78), 8
local X0, X1, Z1 = -276, 30, 272 -- intérieur du hub (L-323 : agrandi à |z| 272)
local amb = hub:FindFirstChild("Ambiance")
if not amb then amb = Instance.new("Model"); amb.Name = "Ambiance"; amb.Parent = hub end
for _, n in { "FloorTiles", "RaisedTiles" } do local o = amb:FindFirstChild(n); if o then o:Destroy() end end
local decor = hub:FindFirstChild("Garden") and hub.Garden:FindFirstChild("Decor")

local function tile(parent, cf, sx, sz)
	local p = Instance.new("Part"); p.Name = "Tile"; p.Anchored = true
	p.Size = Vector3.new(sx, 0.08, sz); p.CFrame = cf; p.Color = TILE_B
	p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Parent = parent
	return p
end

-- ce qui cache une case : toute pièce opaque du hub hors sol, cases et déco voxel. Les pièces sans requête (sols de
-- boutique, stands) comptent aussi : on les rend interrogeables le temps du calcul, puis on les remet comme avant.
local excl = { hub.Ground, amb }
if decor then table.insert(excl, decor) end
local toggled = {}
for _, d in hub:GetDescendants() do
	if d:IsA("BasePart") and not d:IsDescendantOf(hub.Ground) and not d:IsDescendantOf(amb) and not (decor and d:IsDescendantOf(decor)) then
		if d.Transparency > 0.2 then
			table.insert(excl, d)
		elseif not d.CanQuery then
			d.CanQuery = true; table.insert(toggled, d)
		end
	end
end
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = excl
task.wait() -- les pièces rendues interrogeables entrent dans les requêtes

local nFloor, nRaised, nSkip = 0, 0, 0
local ok, err = pcall(function()
	-- une case est cachée si ses 5 points (centre et coins) ont une pièce au-dessus du niveau y0 (rayon depuis y0 + 6)
	local function hidden(cx, cz, hx, hz, y0, toWorld)
		for _, o in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local pt = toWorld(cx + o[1] * (hx - 0.4), cz + o[2] * (hz - 0.4))
			local r = workspace:Raycast(Vector3.new(pt.X, y0 + 6, pt.Z), Vector3.new(0, -6.5, 0), rp)
			if not (r and r.Position.Y > y0 + 0.05) then return false end
		end
		return true
	end
	local function world(x, z) return Vector3.new(x, 0, z) end

	-- 1) sol
	local floor = Instance.new("Model"); floor.Name = "FloorTiles"
	for _, n in { "Ground_Plaza", "Ground_Flank_N", "Ground_Flank_S" } do
		local g = hub.Ground:FindFirstChild(n)
		if g then
			g.Color = TILE_A
			local top = g.Position.Y + g.Size.Y / 2
			local gx0, gx1 = math.max(g.Position.X - g.Size.X / 2, X0), math.min(g.Position.X + g.Size.X / 2, X1)
			local gz0, gz1 = math.max(g.Position.Z - g.Size.Z / 2, -Z1), math.min(g.Position.Z + g.Size.Z / 2, Z1)
			for i = math.floor(gx0 / CELL), math.ceil(gx1 / CELL) - 1 do
				for j = math.floor(gz0 / CELL), math.ceil(gz1 / CELL) - 1 do
					if (i + j) % 2 == 1 then
						local x0, x1 = math.max(i * CELL, gx0), math.min((i + 1) * CELL, gx1)
						local z0, z1 = math.max(j * CELL, gz0), math.min((j + 1) * CELL, gz1)
						if x1 - x0 > 0.5 and z1 - z0 > 0.5 then
							local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
							if hidden(cx, cz, (x1 - x0) / 2, (z1 - z0) / 2, top, world) then
								nSkip += 1
							else
								-- 0,025 de plus de chaque côté : les côtés ne se confondent pas avec ceux des voisins
								tile(floor, CFrame.new(cx, top - 0.01, cz), x1 - x0 + 0.05, z1 - z0 + 0.05)
								nFloor += 1
							end
						end
					end
				end
			end
		end
	end
	floor.Parent = amb

	-- 2) dessus des reliefs
	local raised = Instance.new("Model"); raised.Name = "RaisedTiles"
	local beds = hub:FindFirstChild("Garden") and hub.Garden:FindFirstChild("Beds")
	for _, p in (beds and beds:GetChildren() or {}) do
		if p:IsA("BasePart") and (p.Name == "BedTop" or p.Name == "TerraceTop" or p.Name == "BermTop") then
			p.Color = TILE_A
			local top = p.Position.Y + p.Size.Y / 2
			local hx, hz = p.Size.X / 2, p.Size.Z / 2
			local rot = p.CFrame - p.Position
			local straight = math.abs(p.CFrame.LookVector.Z + 1) < 1e-3 or math.abs(p.CFrame.LookVector.Z - 1) < 1e-3
			-- grille : celle du monde pour un dessus droit, sinon celle du massif, centrée sur lui
			local ox, oz, toW
			if straight then
				ox, oz = 0, 0
				hx, hz = math.abs(rot:VectorToWorldSpace(Vector3.new(hx, 0, hz)).X), math.abs(rot:VectorToWorldSpace(Vector3.new(hx, 0, hz)).Z)
				toW = function(u, v) return Vector3.new(u, 0, v) end
			else
				local nx, nz = math.ceil(2 * hx / CELL), math.ceil(2 * hz / CELL)
				ox, oz = p.Position.X - nx * CELL / 2, p.Position.Z - nz * CELL / 2
				toW = function(u, v) local w = p.CFrame * Vector3.new(u - p.Position.X, 0, v - p.Position.Z); return w end
			end
			-- bornes dans le repère de la grille (u, v) : monde pour un dessus droit, massif recentré sinon
			local u0, u1, v0, v1 = p.Position.X - hx, p.Position.X + hx, p.Position.Z - hz, p.Position.Z + hz
			for i = math.floor((u0 - ox) / CELL), math.ceil((u1 - ox) / CELL) - 1 do
				for j = math.floor((v0 - oz) / CELL), math.ceil((v1 - oz) / CELL) - 1 do
					if (i + j) % 2 == 1 then
						local a0, a1 = math.max(ox + i * CELL, u0), math.min(ox + (i + 1) * CELL, u1)
						local b0, b1 = math.max(oz + j * CELL, v0), math.min(oz + (j + 1) * CELL, v1)
						if a1 - a0 > 0.5 and b1 - b0 > 0.5 then
							local cu, cv = (a0 + a1) / 2, (b0 + b1) / 2
							if hidden(cu, cv, (a1 - a0) / 2, (b1 - b0) / 2, top, toW) then
								nSkip += 1
							else
								local c = toW(cu, cv)
								tile(raised, CFrame.new(c.X, top - 0.01, c.Z) * (straight and CFrame.identity or rot), a1 - a0 + 0.05, b1 - b0 + 0.05)
								nRaised += 1
							end
						end
					end
				end
			end
		end
	end
	raised.Parent = amb
end)
for _, d in toggled do d.CanQuery = false end
assert(ok, err)
return string.format("damier : %d cases au sol, %d sur les reliefs, %d cachées (sautées) ; %d pièces remises sans requête", nFloor, nRaised, nSkip, #toggled)
