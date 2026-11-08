--!nocheck
-- corridor_widen.luau : élargit le couloir des magasins PNJ des 6 zones, de 60 à 120 studs entre les façades
-- (magasins de z ±66 à z ±96). Se lance dans Studio en mode Edit (barre de commande ou MCP), après les scripts
-- de zone. Une passe générique : aucun script de zone n'est réécrit.
--
-- Relançable sans risque : tout objet traité reçoit l'attribut CorridorWiden (= D) et n'est plus jamais
-- retouché. Un script de zone relancé recrée ses objets sans cette marque : relancer alors ce script, puis
-- tools/clement/env/trees_replace.luau si le script de zone a recréé des arbres en pièces.
-- `_G.CorridorWidenDry = true` avant de lancer : rien ne bouge, le script dit seulement ce qu'il ferait.
--
-- Règles (z = 0 au milieu de la rue, x le long du couloir) :
--  • d'un côté de la rue (magasins avec tous leurs enfants, trottoirs, murets, lampadaires, décor, quartier,
--    arbres, points décalés du centre) : glisse de ±D en z, d'un bloc ;
--  • ce qui traverse la rue (au moins CROSS_W de large en z : chaussée, frontons et enseignes des arches,
--    volumes d'effets, fond de New York) : s'élargit de 2·D, centre fixe ;
--  • les petites pièces centrées (axe de la rue, TruckSpawn, NightPatrol, enseigne centrale, tour du fond) :
--    ne bougent pas ;
--  • les marquages de la chaussée : près du trottoir (|z| ≥ KERB_BAND) ils suivent le trottoir (±D) ; au
--    milieu, leur distance à l'axe est multipliée par K (les voies gardent leurs proportions) ; ceux qui vont
--    de l'axe au trottoir s'allongent de D vers l'extérieur ;
--  • les rangées régulières qui barrent la rue (passages piétons, pavés, lanternes d'un fil) gardent leur pas
--    et se complètent par des clones.
--
-- Entrée depuis le hub (Clément, 2026-11-08 : « il faut aussi élargir la zone d'entrée ») : l'arche ZoneGate_1 et
-- Map/Entry (NightWall, NightWallSlot) s'élargissent comme le reste. L'ouverture du hub (grand mur à x 27,5..30,
-- rue, trottoirs et rail de sortie, piliers, stands) est posée à la même largeur par
-- tools/clement/hub/hub_place_du_mall.luau (EXIT_W = 30). KEEP_HUB_MOUTH = true garde l'ancienne entrée de 69 studs
-- (pour un hub dont l'ouverture n'irait que jusqu'à |z| = 34,5).

local D = 30 -- décalage de chaque côté de la rue
local ROAD = 22.5 -- demi-largeur d'origine de la chaussée
local KERB_BAND = 15 -- au-delà, un marquage garde sa distance au trottoir
local K = (ROAD + D) / ROAD -- au milieu de la chaussée, les distances à l'axe s'étirent
local CROSS_W = 40 -- une pièce au moins aussi large en z « traverse la rue »
local KEEP_HUB_MOUTH = false
local MARK = "CorridorWiden"
local ROW_PITCH = 10 -- au-delà de ce pas, une rangée s'écarte (×K) au lieu de se compléter (piliers du fond)
-- Laissés tels quels : le camion se gare au milieu de la chaussée, la tour du fond de New York est centrée.
local SKIP_NAMES = { TruckSpawn = true, EndTower = true }

local DRY = _G.CorridorWidenDry == true
local Map = workspace:WaitForChild("Map")
local Corridor = workspace.Greybox.Corridor

local stats = { models = 0, moved = 0, prop = 0, stayed = 0, stretched = 0, half = 0, rows = 0, clones = 0, already = 0, stash = 0 }
local notes = {}
local function note(s)
	if #notes < 120 then
		table.insert(notes, s)
	end
end

local skipInst = {}
if KEEP_HUB_MOUTH then
	local zg = Corridor:FindFirstChild("Zone_1") and Corridor.Zone_1:FindFirstChild("ZoneGate_1")
	if zg then
		skipInst[zg] = true
	end
end

local function zext(p)
	local cf, s = p.CFrame, p.Size
	local hz = math.abs(cf.XVector.Z) * s.X / 2 + math.abs(cf.YVector.Z) * s.Y / 2 + math.abs(cf.ZVector.Z) * s.Z / 2
	return cf.Z - hz, cf.Z + hz
end

local function modelZ(m)
	local z0, z1, any = math.huge, -math.huge, false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			any = true
			local a, b = zext(d)
			z0, z1 = math.min(z0, a), math.max(z1, b)
		end
	end
	return any, z0, z1
end

-- Décalage d'un objet ponctuel selon la distance de son centre à l'axe de la rue.
local function pointDelta(zc)
	if math.abs(zc) >= KERB_BAND then
		return zc > 0 and D or -D
	end
	return zc * (K - 1)
end

local count = 0
local function tick()
	count += 1
	if count % 400 == 0 then
		task.wait()
	end
end

local function mark(i)
	if not DRY then
		i:SetAttribute(MARK, D)
	end
end

local function shiftZ(inst, dz)
	if DRY or math.abs(dz) < 1e-4 then
		return
	end
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + Vector3.new(0, 0, dz))
	else
		inst.CFrame = inst.CFrame + Vector3.new(0, 0, dz)
	end
end

-- Axe local de la pièce aligné sur le z du monde (1 = X, 2 = Y, 3 = Z), ou nil.
local function zAxis(p)
	local cf = p.CFrame
	local a = { math.abs(cf.XVector.Z), math.abs(cf.YVector.Z), math.abs(cf.ZVector.Z) }
	for i = 1, 3 do
		if a[i] > 0.985 then
			return i
		end
	end
	return nil
end

local function withAxis(v, i, val)
	return Vector3.new(i == 1 and val or v.X, i == 2 and val or v.Y, i == 3 and val or v.Z)
end

-- Allonge une pièce de `grow` en z du monde et décale son centre de `dzc`.
-- Attaches et SurfaceGui à taille fixe suivent l'étirement.
local function stretch(p, grow, dzc)
	local i = zAxis(p)
	if not i or (p:IsA("Part") and p.Shape == Enum.PartType.Ball) then
		return false
	end
	if p:FindFirstChildWhichIsA("SpecialMesh") then
		note("SpecialMesh dans une pièce étirée (maillage non étiré) : " .. p:GetFullName())
	end
	for _, c in p:GetChildren() do
		if c:IsA("Decal") then
			note("Decal sur une pièce étirée : " .. p:GetFullName())
		end
	end
	if DRY then
		return true
	end
	local s = p.Size
	local old = (i == 1 and s.X) or (i == 2 and s.Y) or s.Z
	local r = (old + grow) / old
	p.Size = withAxis(s, i, old + grow)
	p.CFrame = p.CFrame + Vector3.new(0, 0, dzc)
	for _, c in p:GetChildren() do
		if c:IsA("Attachment") then
			local q = c.Position
			c.Position = withAxis(q, i, ((i == 1 and q.X) or (i == 2 and q.Y) or q.Z) * r)
		elseif c:IsA("SurfaceGui") and c.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then
			local f = c.Face
			local cx, cy
			if f == Enum.NormalId.Front or f == Enum.NormalId.Back then
				cx, cy = 1, 2
			elseif f == Enum.NormalId.Left or f == Enum.NormalId.Right then
				cx, cy = 3, 2
			else
				cx, cy = 1, 3
			end
			local cs = c.CanvasSize
			c.CanvasSize = Vector2.new(cx == i and cs.X * r or cs.X, cy == i and cs.Y * r or cs.Y)
		end
	end
	return true
end

local function doPart(p)
	local z0, z1 = zext(p)
	local zc = (z0 + z1) / 2
	if z0 < -0.5 and z1 > 0.5 then
		if z1 - z0 >= CROSS_W then
			if stretch(p, 2 * D, 0) then
				stats.stretched += 1
			else
				stats.stayed += 1
				note("traverse la rue mais pas d'axe z, laissée : " .. p:GetFullName())
			end
		else
			stats.stayed += 1
		end
	else
		local inner, outer = math.min(math.abs(z0), math.abs(z1)), math.max(math.abs(z0), math.abs(z1))
		local sgn = zc > 0 and 1 or -1
		if inner < 3 and outer > 18 and outer <= ROAD + 1.5 then
			if stretch(p, D, sgn * D / 2) then
				stats.half += 1
			else
				shiftZ(p, pointDelta(zc))
				stats.prop += 1
			end
		else
			if inner < ROAD - 1 and outer > ROAD + 2 then
				note(string.format("à cheval sur la bordure (z %.1f..%.1f), glissée d'un bloc : %s", z0, z1, p:GetFullName()))
			end
			shiftZ(p, pointDelta(zc))
			if math.abs(zc) >= KERB_BAND then
				stats.moved += 1
			else
				stats.prop += 1
			end
		end
	end
	mark(p)
end

-- Rangées régulières de pièces sœurs qui barrent la chaussée : même pas, complétées par des clones.
local function rows(container)
	local groups = {}
	for _, c in container:GetChildren() do
		if c:IsA("BasePart") and not SKIP_NAMES[c.Name] then
			local base = c.Name:match("^(.-)%d+$")
			if base and base ~= "" then
				local z0, z1 = zext(c)
				if math.abs((z0 + z1) / 2) < ROAD and z1 - z0 < CROSS_W then
					local key = base .. "|" .. math.floor(c.Position.X * 2 + 0.5)
					groups[key] = groups[key] or { base = base, list = {} }
					table.insert(groups[key].list, c)
				end
			end
		end
	end
	local handled = {}
	for _, g in groups do
		local L = g.list
		if #L >= 4 then
			table.sort(L, function(a, b)
				return a.Position.Z < b.Position.Z
			end)
			local zmin, zmax = L[1].Position.Z, L[#L].Position.Z
			if zmin < -5 and zmax > 5 then
				local pitch = (zmax - zmin) / (#L - 1)
				local even, marked = pitch <= ROW_PITCH, false
				for j = 2, #L do
					if math.abs((L[j].Position.Z - L[j - 1].Position.Z) - pitch) > 0.3 * pitch then
						even = false
					end
				end
				for _, c in L do
					if c:GetAttribute(MARK) then
						marked = true
					end
				end
				if marked then
					stats.already += #L
				elseif even then
					local span = zmax - zmin + 2 * D
					local n = math.floor(span / pitch + 0.5) + 1
					local p2 = span / (n - 1)
					stats.rows += 1
					stats.clones += n - #L
					note(string.format("rangée %s/%s* : %d → %d (pas %.2f → %.2f)", container.Name, g.base, #L, n, pitch, p2))
					if not DRY then
						local orig = table.clone(L)
						local last = 0 -- plus grand numéro déjà pris par ce nom dans le dossier
						for _, c in container:GetChildren() do
							local num = c.Name:sub(1, #g.base) == g.base and tonumber(c.Name:sub(#g.base + 1))
							if num and num > last then
								last = num
							end
						end
						for j = 1, n do
							local item = orig[j]
							if not item then
								-- même parité que l'original : une rangée qui alterne deux teintes (bandes de danger) alterne encore
								local period = math.max(1, #orig - (#orig % 2))
								item = orig[((j - 1) % period) + 1]:Clone()
								last += 1
								item.Name = g.base .. tostring(last)
								item.Parent = container
							end
							local z = zmin - D + (j - 1) * p2
							item.CFrame = item.CFrame + Vector3.new(0, 0, z - item.Position.Z)
							item:SetAttribute(MARK, D)
						end
					end
				end
				if even or marked then
					for _, c in L do
						handled[c] = true
					end
				end
			end
		end
	end
	return handled
end

local process
local function processChildren(c)
	local handled = rows(c)
	for _, ch in c:GetChildren() do
		if not handled[ch] then
			process(ch)
		end
	end
end

function process(inst)
	if SKIP_NAMES[inst.Name] or skipInst[inst] then
		return
	end
	if inst:GetAttribute(MARK) then
		stats.already += 1
		return
	end
	tick()
	if inst:IsA("Model") then
		local any, z0, z1 = modelZ(inst)
		if not any then
			return
		end
		if z0 < -0.5 and z1 > 0.5 then
			processChildren(inst) -- traverse la rue : pièce par pièce (arches, torii, fond)
		else
			shiftZ(inst, pointDelta((z0 + z1) / 2))
			stats.models += 1
			mark(inst)
		end
	elseif inst:IsA("BasePart") then
		doPart(inst)
		for _, ch in inst:GetChildren() do
			if ch:IsA("BasePart") or ch:IsA("Model") then
				process(ch)
			end
		end
	elseif inst:IsA("Folder") or inst:IsA("Configuration") then
		processChildren(inst)
	end
end

for i = 1, 6 do
	local z = Map:FindFirstChild("Zone_" .. i)
	if z then
		process(z)
	end
end
process(Corridor) -- greybox : chaussée, côtés, murets, arches, points NightPatrol, mur du fond

-- Arbres d'origine rangés par tools/clement/env/trees_replace.luau (ServerStorage/_ARBRES_REMPLACES) : une relance
-- de trees_replace repart d'eux. Ils glissent comme l'arbre de la map, sinon elle replanterait aux anciennes places.
local stash = game:GetService("ServerStorage"):FindFirstChild("_ARBRES_REMPLACES")
if stash then
	for _, m in stash:GetDescendants() do
		local path = m:GetAttribute("Path")
		if m:IsA("Model") and path and path:match("^Workspace%.Map%.Zone_%d") then
			if m:GetAttribute(MARK) then
				stats.already += 1
			else
				local any, z0, z1 = modelZ(m)
				if any then
					shiftZ(m, pointDelta((z0 + z1) / 2))
					stats.stash += 1
					mark(m)
				end
			end
		end
	end
end
if not KEEP_HUB_MOUTH and Map:FindFirstChild("Entry") then
	process(Map.Entry)
end
if not DRY then
	Map:SetAttribute("CorridorWidth", 60 + 2 * D)
end

return string.format(
	"%s : %d modèles et %d pièces glissés de ±%d, %d marquages écartés (×%.2f), %d pièces élargies de %d, %d allongées de %d, %d rangées refaites (+%d clones), %d laissées au centre, %d arbres rangés suivis, %d déjà faits%s",
	DRY and "ESSAI (rien n'a bougé)" or "Couloir élargi",
	stats.models, stats.moved, D, stats.prop, K, stats.stretched, 2 * D, stats.half, D, stats.rows, stats.clones,
	stats.stayed, stats.stash, stats.already,
	#notes > 0 and ("\n" .. table.concat(notes, "\n")) or ""
)
