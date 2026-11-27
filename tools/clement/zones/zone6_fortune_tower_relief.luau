--!nocheck
-- Fortune Tower en relief (repasse qualité du 26/11, validée par Clément) : la façade du fond du couloir
-- (Zone_6/Street_NewYork/Backdrop) se lisait comme un mur peint. On garde toutes ses pièces et leurs noms
-- (EndFacade, EndPier_1..6, EndWindow_1..4, EndSign, EndBand, EndCornice, horloge, EndDoors…) et on ajoute du relief :
--   - piliers EndPier_1..6 plus épais (0,52 → 1,6 stud, la face arrière reste collée à la façade) ;
--   - corniche EndCornice plus profonde (3,88 → 5), pour couvrir les piliers ;
--   - autour de chaque fenêtre : appui doré qui avance, linteau, montants, et meneaux sur les grandes ;
--   - socle (Plinth_L, Plinth_R) au pied de la façade, de part et d'autre de la porte ;
--   - couronne art déco en gradins au-dessus de la corniche (Crown_1..3 et sa flèche).
-- Tout le neuf va dans Backdrop/Relief, sans collision, sans script ni tag. La face avant de la façade est à x = 868
-- et regarde vers −x (vers le couloir).
-- Avant : Backdrop entier copié dans ServerStorage/MapBackups/<date>_FortuneTower. Relançable : Relief est refait et
-- les tailles des piliers et de la corniche sont posées en valeur absolue.
-- À lancer dans Studio (MCP execute_luau, Edit).

local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromRGB
local bd = workspace.Map.Zone_6.Street_NewYork:FindFirstChild("Backdrop")
assert(bd, "Zone_6/Street_NewYork/Backdrop introuvable")

local FRONT = 868 -- face avant de la façade
local CREAM, PIER, GOLD, DARKCREAM = rgb(214, 198, 166), rgb(206, 190, 158), rgb(212, 172, 60), rgb(176, 158, 124)

local rec = CHS:TryBeginRecording("Fortune Tower en relief", { allowNoUndo = true })

-- Sauvegarde (une fois par jour)
local mb = game.ServerStorage:FindFirstChild("MapBackups")
local name = os.date("%Y-%m-%d") .. "_FortuneTower"
if not mb:FindFirstChild(name) then
	local b = Instance.new("Folder")
	b.Name = name
	b:SetAttribute("Note", "Backdrop de Zone_6/Street_NewYork avant le relief de la Fortune Tower (repasse du 26/11). Pour revenir : remplacer Backdrop par cette copie.")
	local c = bd:Clone()
	for _, d in c:GetDescendants() do for _, t in game:GetService("CollectionService"):GetTags(d) do game:GetService("CollectionService"):RemoveTag(d, t) end end
	c.Parent = b
	b.Parent = mb
end

local old = bd:FindFirstChild("Relief")
if old then old:Destroy() end
local R = Instance.new("Model")
R.Name = "Relief"

local function box(nm, x0, x1, y0, y1, z0, z1, col, mat)
	local p = Instance.new("Part")
	p.Name = nm
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or Enum.Material.Plastic
	if not mat then p.MaterialVariant = "Studs" end
	p.Color = col
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.Position = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Parent = R
	return p
end

-- 1) Piliers plus épais, face arrière collée à la façade
for i = 1, 6 do
	local p = bd:FindFirstChild("EndPier_" .. i)
	if p then
		local d = 1.6
		p.Size = Vector3.new(d, p.Size.Y, p.Size.Z)
		p.Position = Vector3.new(FRONT - d / 2, p.Position.Y, p.Position.Z)
	end
end
-- 2) Corniche plus profonde (face arrière gardée)
local cor = bd:FindFirstChild("EndCornice")
if cor then
	local back = cor.Position.X + cor.Size.X / 2
	local d = 5
	cor.Size = Vector3.new(d, cor.Size.Y, cor.Size.Z)
	cor.Position = Vector3.new(back - d / 2, cor.Position.Y, cor.Position.Z)
end

-- 3) Encadrement des fenêtres
for i = 1, 4 do
	local w = bd:FindFirstChild("EndWindow_" .. i)
	if w then
		local y0, y1 = w.Position.Y - w.Size.Y / 2, w.Position.Y + w.Size.Y / 2
		local z0, z1 = w.Position.Z - w.Size.Z / 2, w.Position.Z + w.Size.Z / 2
		local t = "Win" .. i .. "_"
		box(t .. "Sill", FRONT - 1.2, FRONT, y0 - 0.8, y0, z0 - 0.6, z1 + 0.6, GOLD, Enum.Material.SmoothPlastic)
		box(t .. "Head", FRONT - 0.9, FRONT, y1, y1 + 0.9, z0 - 0.6, z1 + 0.6, DARKCREAM)
		box(t .. "JambL", FRONT - 0.7, FRONT, y0, y1, z0 - 0.6, z0, DARKCREAM)
		box(t .. "JambR", FRONT - 0.7, FRONT, y0, y1, z1, z1 + 0.6, DARKCREAM)
		local wide = (z1 - z0) > 8
		if wide then box(t .. "Mullion", FRONT - 0.45, FRONT - 0.05, y0, y1, (z0 + z1) / 2 - 0.25, (z0 + z1) / 2 + 0.25, GOLD, Enum.Material.SmoothPlastic) end
		-- traverses tous les 6 studs
		local y = y0 + 6
		local k = 0
		while y < y1 - 1 do
			k += 1
			box(t .. "Transom_" .. k, FRONT - 0.45, FRONT - 0.05, y - 0.2, y + 0.2, z0, z1, GOLD, Enum.Material.SmoothPlastic)
			y += 6
		end
	end
end

-- 4) Socle au pied de la façade, de part et d'autre de la porte (porte : z −6,9..6,9)
local half = 61.5
box("Plinth_L", FRONT - 1, FRONT, 0, 1.6, -half, -7.2, DARKCREAM)
box("Plinth_R", FRONT - 1, FRONT, 0, 1.6, 7.2, half, DARKCREAM)

-- 5) Couronne art déco en gradins au-dessus de la corniche (y = 36,9)
local top = cor and (cor.Position.Y + cor.Size.Y / 2) or 36.9
local steps = { { 40, 3 }, { 26, 3 }, { 13, 3 } }
local y = top
for i, s in steps do
	box("Crown_" .. i, FRONT + 0.4, FRONT + 3.4, y, y + s[2], -s[1], s[1], CREAM)
	box("Crown_" .. i .. "_Edge", FRONT + 0.2, FRONT + 0.4, y + s[2] - 0.5, y + s[2], -s[1], s[1], GOLD, Enum.Material.SmoothPlastic)
	y += s[2]
end
box("Crown_Spire", FRONT + 1.4, FRONT + 2.4, y, y + 6, -1.2, 1.2, GOLD, Enum.Material.SmoothPlastic)

R.Parent = bd
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return ("Relief : %d pièces neuves ; piliers à 1,6 de profondeur ; corniche à 5 ; sauvegarde MapBackups/%s"):format(#R:GetChildren(), name)
