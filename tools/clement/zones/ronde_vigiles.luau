--!nocheck
-- Points de ronde des vigiles de jour dans les 12 magasins PNJ (liaison L-493, à la demande de Cantin ; aide pour L-494 :
-- « la ronde bute partout, et la sortie est inondée »). Le code (Guard/DayPatrol, a518) lit dans le magasin les points
-- GuardPatrol_01 à GuardPatrol_20 (Config/Guards.DayPatrol.PointName, PointMax), dans l'ordre des numéros, en boucle ;
-- sans eux, il passait devant chaque ShelfSlot, trop près des rayons.
-- Méthode, magasin par magasin :
--   1. grille de GRID stud sur le volume Bounds ; une case est bloquée si une pièce qui a CanCollide occupe la tranche
--      y = pieds + 1 à pieds + 6 (pieds : hauteur du GuardSpawn) ;
--   2. dégagement de chaque case = distance à la case bloquée la plus proche (ou au bord de Bounds) ;
--   3. salle de vente = cases libres reliées à l'avant du magasin (milieu de la vitrine, Window), avec un dégagement d'au
--      moins CLEAR (rayon de l'agent du chemin, Config/Guards AgentRadiusMax 2,5, plus une marge) ;
--   4. candidates : cases de la salle à au moins FRONT_KEEP studs de la vitrine et de la porte (Door : la sortie reste
--      libre) ;
--   5. SECTORS secteurs d'angle autour du centre des candidates ; dans chacun, la case la plus dégagée parmi celles assez
--      loin du centre (la ronde tourne autour des gondoles au lieu de couper au milieu), à MIN_SPACING des autres ;
--   6. numérotés dans l'ordre du tour, en partant du point le plus proche du GuardSpawn.
-- Pose : Folder « GuardPatrol » dans le magasin, avec des Parts GuardPatrol_01… de 1 stud, invisibles, ancrées, sans
-- collision, toucher, requête ni ombre, aux pieds du vigile. Aucun script, aucun tag. Rien d'autre n'est touché.
-- Relançable : le dossier GuardPatrol est refait. Avant : rien à sauvegarder (objets neufs) ; l'ancien dossier, s'il
-- existe, part dans ServerStorage/MapBackups/<date>_RondeVigiles.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local GRID, CLEAR, FRONT_KEEP, SECTORS, MIN_SPACING, MIN_RADIUS_FRAC = 1, 3.5, 12, 10, 7, 0.45
local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local stores = {}
for _, z in workspace.Map:GetChildren() do
	for _, c in z:GetChildren() do if c.Name:match("^STORE_Z%d_") then table.insert(stores, c) end end
end
table.sort(stores, function(a, b) return a.Name < b.Name end)

local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_RondeVigiles"
local rec = CHS:TryBeginRecording("Points de ronde des vigiles", { allowNoUndo = true })

local function posOf(x)
	if x:IsA("Attachment") then return x.WorldPosition end
	if x:IsA("BasePart") then return x.Position end
	return x:GetPivot().Position
end

local report = {}
for _, store in stores do
	local bounds = store:FindFirstChild("Bounds", true)
	local spawn = store:FindFirstChild("GuardSpawn", true)
	local door = store:FindFirstChild("Door", true)
	local window = store:FindFirstChild("Window", true)
	local feet = posOf(spawn).Y
	local bcf, bsz = bounds.CFrame, bounds.Size
	local nx, nz = math.floor(bsz.X / GRID), math.floor(bsz.Z / GRID)
	local function cellPos(i, j)
		return bcf:PointToWorldSpace(Vector3.new(-bsz.X / 2 + (i - 0.5) * GRID, 0, -bsz.Z / 2 + (j - 0.5) * GRID))
	end
	-- 1) cases bloquées
	local op = OverlapParams.new()
	op.RespectCanCollide = true
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { bounds }
	local blocked = {}
	for i = 1, nx do
		blocked[i] = {}
		for j = 1, nz do
			local p = cellPos(i, j)
			local hits = workspace:GetPartBoundsInBox(CFrame.new(p.X, feet + 3.5, p.Z), Vector3.new(GRID * 0.9, 5, GRID * 0.9), op)
			blocked[i][j] = #hits > 0
		end
		if i % 10 == 0 then task.wait() end
	end
	-- 2) dégagement (distance euclidienne approchée par une propagation à 8 voisins)
	local clear = {}
	local queue, head = {}, 1
	for i = 1, nx do
		clear[i] = {}
		for j = 1, nz do
			if blocked[i][j] or i == 1 or j == 1 or i == nx or j == nz then
				clear[i][j] = 0
				table.insert(queue, { i, j })
			else
				clear[i][j] = math.huge
			end
		end
	end
	while head <= #queue do
		local c = queue[head]
		head += 1
		local ci, cj = c[1], c[2]
		for di = -1, 1 do for dj = -1, 1 do
			local ni, nj = ci + di, cj + dj
			if (di ~= 0 or dj ~= 0) and ni >= 1 and nj >= 1 and ni <= nx and nj <= nz then
				local v = clear[ci][cj] + ((di ~= 0 and dj ~= 0) and 1.414 or 1) * GRID
				if v < clear[ni][nj] then clear[ni][nj] = v table.insert(queue, { ni, nj }) end
			end
		end end
	end
	-- 3) salle de vente : reliée à l'avant (case libre la plus proche du milieu de la vitrine, côté intérieur)
	local wpos = posOf(window)
	local inward = (bcf.Position - wpos) * Vector3.new(1, 0, 1)
	inward = inward.Magnitude > 0 and inward.Unit or Vector3.new(0, 0, 1)
	local seedP = wpos + inward * 8
	local best, bestD = nil, math.huge
	for i = 1, nx do for j = 1, nz do
		if clear[i][j] >= CLEAR then
			local d = ((cellPos(i, j) - seedP) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestD then best, bestD = { i, j }, d end
		end
	end end
	local room = {}
	if best then
		local q, h = { best }, 1
		room[best[1] .. "," .. best[2]] = true
		while h <= #q do
			local c = q[h]
			h += 1
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ni, nj = c[1] + d[1], c[2] + d[2]
				local k = ni .. "," .. nj
				if ni >= 1 and nj >= 1 and ni <= nx and nj <= nz and not room[k] and clear[ni][nj] >= CLEAR then
					room[k] = true
					table.insert(q, { ni, nj })
				end
			end
		end
	end
	-- 4) candidates, loin de la vitrine et de la porte
	local dpos = posOf(door)
	local cands = {}
	for k in room do
		local i, j = k:match("(%-?%d+),(%-?%d+)")
		i, j = tonumber(i), tonumber(j)
		local p = cellPos(i, j)
		local fromFront = (p - wpos):Dot(inward)
		local fromDoor = ((p - dpos) * Vector3.new(1, 0, 1)).Magnitude
		if fromFront >= FRONT_KEEP and fromDoor >= FRONT_KEEP then
			table.insert(cands, { p = Vector3.new(p.X, feet, p.Z), c = clear[i][j] })
		end
	end
	-- 5) secteurs autour du centre
	local center = Vector3.zero
	for _, c in cands do center += c.p end
	center = #cands > 0 and center / #cands or bcf.Position
	local rmax = 0
	for _, c in cands do
		c.r = ((c.p - center) * Vector3.new(1, 0, 1)).Magnitude
		c.a = math.atan2(c.p.Z - center.Z, c.p.X - center.X)
		rmax = math.max(rmax, c.r)
	end
	local chosen = {}
	for s = 0, SECTORS - 1 do
		local a0 = -math.pi + s * 2 * math.pi / SECTORS
		local a1 = a0 + 2 * math.pi / SECTORS
		local pick = nil
		for _, c in cands do
			if c.a >= a0 and c.a < a1 and c.r >= MIN_RADIUS_FRAC * rmax then
				local ok = true
				for _, o in chosen do if ((o.p - c.p) * Vector3.new(1, 0, 1)).Magnitude < MIN_SPACING then ok = false break end end
				if ok and (not pick or c.c > pick.c) then pick = c end
			end
		end
		if pick then table.insert(chosen, pick) end
	end
	-- 6) ordre du tour, en partant du point le plus proche du GuardSpawn
	table.sort(chosen, function(x, y) return x.a < y.a end)
	local sp = posOf(spawn)
	local startIdx, sd = 1, math.huge
	for idx, c in chosen do
		local d = ((c.p - sp) * Vector3.new(1, 0, 1)).Magnitude
		if d < sd then startIdx, sd = idx, d end
	end
	local ordered = {}
	for k = 0, #chosen - 1 do table.insert(ordered, chosen[(startIdx - 1 + k) % #chosen + 1]) end
	-- segments droits dégagés ?
	local straight = 0
	for k = 1, #ordered do
		local a, b = ordered[k].p, ordered[k % #ordered + 1].p
		local okSeg = true
		local steps = math.ceil((b - a).Magnitude / GRID)
		for t = 0, steps do
			local p = a:Lerp(b, t / math.max(steps, 1))
			local l = bcf:PointToObjectSpace(p)
			local i = math.clamp(math.floor((l.X + bsz.X / 2) / GRID) + 1, 1, nx)
			local j = math.clamp(math.floor((l.Z + bsz.Z / 2) / GRID) + 1, 1, nz)
			if clear[i][j] < 2.5 then okSeg = false break end
		end
		if okSeg then straight += 1 end
	end
	-- pose
	local old = store:FindFirstChild("GuardPatrol")
	if old then
		local b = mb:FindFirstChild(bname) or Instance.new("Folder")
		b.Name = bname
		b.Parent = mb
		old.Name = store.Name .. "_GuardPatrol"
		old.Parent = b
	end
	local folder = Instance.new("Folder")
	folder.Name = "GuardPatrol"
	for k, c in ordered do
		if k > 20 then break end
		local p = Instance.new("Part")
		p.Name = ("GuardPatrol_%02d"):format(k)
		p.Size = Vector3.new(1, 1, 1)
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Transparency = 1
		p.CFrame = CFrame.new(c.p)
		p:SetAttribute("Clearance", math.floor(c.c * 10) / 10)
		p.Parent = folder
	end
	folder.Parent = store
	local minC = math.huge
	for _, c in ordered do minC = math.min(minC, c.c) end
	table.insert(report, ("%s : %d points, dégagement min %.1f, %d/%d tronçons droits dégagés, salle %d cases"):format(store.Name, #ordered, minC, straight, #ordered, (function() local n = 0 for _ in room do n += 1 end return n end)()))
	task.wait()
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(report, "\n")
