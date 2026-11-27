--!nocheck
-- Mur de nuit en vraie barricade (repasse qualité du 26/11, validée par Clément) : Map/Entry/NightWall se lisait comme
-- un aplat. On garde toutes ses pièces, leurs noms, le tag NightWall et le WorldPivot (le code fait monter le modèle par
-- PivotTo) ; on ajoute du relief dans NightWall/Barricade, sans collision, sans script :
--   - nervures verticales (Rib_L_*, Rib_C_*) tous les 12 studs sur les deux faces, hors du panneau central ;
--   - deux lisses horizontales par face (Rail_*), à y 4 et 20 (au-dessus et au-dessous du panneau) ;
--   - plinthe de danger en relief au pied (Kick_*), jaune et noir par pas de 6 studs, sur les deux faces ;
--   - boîtiers sombres autour des 8 feux d'alarme (Housing_*).
-- Tout reste dans l'épaisseur x −1,9..1,9 du repère du mur (les feux sont déjà à ±1,55) : le calcul du côté
-- couloir ou zone safe du code n'est pas touché.
-- Avant : NightWall copié (sans tag) dans ServerStorage/MapBackups/<date>_NightWall. Relançable : Barricade est refaite.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")
local rgb = Color3.fromRGB
local nw = workspace.Map.Entry:FindFirstChild("NightWall")
assert(nw, "Map/Entry/NightWall introuvable")
local pv = nw:GetPivot() -- repère du mur : x à travers l'épaisseur (−x côté zone safe, +x côté couloir), y vers le haut

local DARK, YELLOW, BLACK, STEEL = rgb(58, 64, 75), rgb(255, 204, 40), rgb(30, 32, 38), rgb(120, 128, 140)

local rec = CHS:TryBeginRecording("Mur de nuit en barricade", { allowNoUndo = true })

local mb = game.ServerStorage:FindFirstChild("MapBackups")
local name = os.date("%Y-%m-%d") .. "_NightWall"
if not mb:FindFirstChild(name) then
	local b = Instance.new("Folder")
	b.Name = name
	b:SetAttribute("Note", "Map/Entry/NightWall avant la barricade en relief (repasse du 26/11), tags retirés de la copie. Pour revenir : supprimer NightWall/Barricade, ou remplacer NightWall par cette copie et lui remettre le tag NightWall.")
	local c = nw:Clone()
	for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	for _, t in CS:GetTags(c) do CS:RemoveTag(c, t) end
	c.Parent = b
	b.Parent = mb
end

local old = nw:FindFirstChild("Barricade")
if old then old:Destroy() end
local B = Instance.new("Model")
B.Name = "Barricade"

local function box(nm, x0, x1, y0, y1, z0, z1, col, mat)
	local p = Instance.new("Part")
	p.Name = nm
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or Enum.Material.Plastic
	if not mat then p.MaterialVariant = "Studs" end
	p.Color = col
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = pv * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Parent = B
	return p
end

for _, side in { { "L", -1 }, { "C", 1 } } do
	local tag, s = side[1], side[2]
	local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
	-- nervures (le panneau central occupe z −12,3..12,3)
	local k = 0
	for _, z in { -54, -42, -30, -18, 18, 30, 42, 54 } do
		k += 1
		local x0, x1 = X(0.9, 1.7)
		box("Rib_" .. tag .. "_" .. k, x0, x1, 0, 22, z - 0.7, z + 0.7, DARK)
	end
	-- lisses
	for i, y in { 4, 20 } do
		local x0, x1 = X(0.9, 1.3)
		box("Rail_" .. tag .. "_" .. i, x0, x1, y - 0.5, y + 0.5, -63.1, 63.1, STEEL, Enum.Material.DiamondPlate)
	end
	-- plinthe de danger
	local n = 0
	local z = -63
	while z < 63 do
		n += 1
		local x0, x1 = X(0.9, 1.45)
		box("Kick_" .. tag .. "_" .. n, x0, x1, 0, 2.5, z, math.min(z + 6, 63), (n % 2 == 1) and YELLOW or BLACK)
		z += 6
	end
end

-- boîtiers des feux d'alarme
local h = 0
for _, p in nw:GetChildren() do
	if p:IsA("BasePart") and p.Name:match("^WarningLight_") then
		h += 1
		local lp = pv:PointToObjectSpace(p.Position)
		local s = lp.X > 0 and 1 or -1
		local x0, x1 = math.min(s * 1.4, s * 1.9), math.max(s * 1.4, s * 1.9)
		box("Housing_" .. h .. "_Top", x0, x1, lp.Y + 0.6, lp.Y + 0.9, lp.Z - 0.9, lp.Z + 0.9, DARK)
		box("Housing_" .. h .. "_Bottom", x0, x1, lp.Y - 0.9, lp.Y - 0.6, lp.Z - 0.9, lp.Z + 0.9, DARK)
		box("Housing_" .. h .. "_L", x0, x1, lp.Y - 0.6, lp.Y + 0.6, lp.Z - 0.9, lp.Z - 0.6, DARK)
		box("Housing_" .. h .. "_R", x0, x1, lp.Y - 0.6, lp.Y + 0.6, lp.Z + 0.6, lp.Z + 0.9, DARK)
	end
end

local pivotBefore = nw:GetPivot()
B.Parent = nw
nw.WorldPivot = pivotBefore -- ne pas déplacer le point que le code fait monter
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return ("Barricade : %d pièces neuves ; pivot inchangé %s ; sauvegarde MapBackups/%s"):format(#B:GetChildren(), tostring(nw:GetPivot().Position), name)
