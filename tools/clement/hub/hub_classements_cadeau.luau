-- Classements de tous les temps (ENV_Hub_Leaderboard, Stat Income et Speed, tag Leaderboard) déplacés à droite du
-- cadeau (Clément, session de test du 2026-11-25, par le chef map : ils étaient cachés par des arbres, au fond du couloir
-- est, en z 226 et 256). À lancer dans Studio (MCP execute_luau, mode Edit). Relancer refait la même chose.
-- Contre le mur est (x 25,6), face à la place comme avant, juste au nord du cadeau (ENV_Hub_FreeGift, z 143 à 161) :
-- Income en z Z_INCOME, Speed à côté ; LIFT studs ajoutés aux pieds (0 : la hauteur d'avant). Le code les trouve par
-- leur tag : rien à changer chez Ironix. Les classements de la semaine (WeeklyIncome, WeeklySteals, au fond) ne bougent
-- pas. Ancienne place : attributs de ServerStorage/Assets/MapBackup_2026-11-25_Classements.
-- Ce qui pousse là où vont les panneaux, ou entre eux et l'arrivée (déco du jardin), est rangé dans la même sauvegarde.
local hub = workspace.Map.Hub
local SS = game:GetService("ServerStorage")
-- LIFT 14 : vus de l'arrivée (Spawn), le stand d'armes, le stand Robux et le cadeau cachaient 47 à 51 % de l'écran à la
-- hauteur d'avant ; avec 14 studs de plus aux pieds, plus rien (mesuré en Edit par rayons, depuis l'arrivée et 3 points
-- de la place ; 10 suffit dès qu'on avance de quelques pas)
local X, Z_INCOME, GAP, LIFT = 25.6, 180, 1.6, 14

local bk = SS.Assets:FindFirstChild("MapBackup_2026-11-25_Classements")
if not bk then
	bk = Instance.new("Folder"); bk.Name = "MapBackup_2026-11-25_Classements"
	bk:SetAttribute("Note", "Classements Income et Speed déplacés à droite du cadeau (hub_classements_cadeau.luau) : ancienne place en attributs, déco retirée rangée ici")
	bk.Parent = SS.Assets
end
local boards = {}
for _, m in hub.Zones:GetChildren() do
	if m.Name == "ENV_Hub_Leaderboard" then
		local s = m:GetAttribute("Stat")
		if s == "Income" or s == "Speed" then boards[s] = m end
	end
end
assert(boards.Income and boards.Speed, "classements Income et Speed introuvables dans Map/Hub/Zones")

local out = {}
local z = Z_INCOME
for _, stat in { "Income", "Speed" } do
	local m = boards[stat]
	if bk:GetAttribute(stat .. "_Pivot") == nil then bk:SetAttribute(stat .. "_Pivot", m:GetPivot()) end
	local _, s = m:GetBoundingBox()
	local w = math.max(s.X, s.Z) -- largeur du panneau (27,2)
	-- pieds : on défait d'abord une hausse déjà posée (attribut Lift), puis on pose la nouvelle
	local function lift(dy)
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				if p.Name:match("^Leg_") then p.Size += Vector3.new(0, dy, 0); p.CFrame += Vector3.new(0, dy / 2, 0)
				else p.CFrame += Vector3.new(0, dy, 0) end
			end
		end
	end
	local was = m:GetAttribute("Lift") or 0
	if was ~= 0 then lift(-was) end
	m:PivotTo(CFrame.lookAt(Vector3.new(X, 0, z), Vector3.new(X - 1, 0, z)))
	if LIFT ~= 0 then lift(LIFT) end
	m:SetAttribute("Lift", LIFT ~= 0 and LIFT or nil)
	table.insert(out, string.format("%s : (%.1f ; %.0f), pieds +%d", stat, X, z, LIFT))
	z += w + GAP
end

-- déco du jardin dans la boîte des panneaux (2 studs de marge) : rangée dans la sauvegarde
local moved = {}
local decor = hub:FindFirstChild("Garden") and hub.Garden:FindFirstChild("Decor")
if decor then
	for _, m in pairs(boards) do
		local cf, s = m:GetBoundingBox()
		for _, cat in decor:GetChildren() do
			for _, x in cat:GetChildren() do
				local p = x:IsA("Model") and x:GetPivot().Position or x.Position
				local l = cf:PointToObjectSpace(Vector3.new(p.X, cf.Y, p.Z))
				local r = 2
				if x:IsA("Model") then local _, xs = x:GetBoundingBox(); r += math.max(xs.X, xs.Z) / 2 end
				if math.abs(l.X) <= s.X / 2 + r and math.abs(l.Z) <= s.Z / 2 + r then x.Parent = bk; table.insert(moved, x.Name) end
			end
		end
	end
end
table.insert(out, "déco rangée dans la sauvegarde : " .. #moved .. (#moved > 0 and (" (" .. table.concat(moved, ", ") .. ")") or ""))
return table.concat(out, "\n")
