-- Panneaux des classements de la semaine (L-313 point 3 ; Clément, 2026-11-24, transmis par la session chef de projet) :
-- deux ENV_Hub_Leaderboard de plus dans Map/Hub/Zones, Stat = WeeklyIncome (top 100 en $/s de la semaine) et
-- Stat = WeeklySteals (top 100 en vols), remplis par LeaderboardService.AddBoard (code de Cantin, a409).
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relancer refait les deux panneaux à l'identique.
-- Gabarit : copie du panneau Stat = Income posé par hub_place_du_mall.luau et habillé par la session UI (L-165) :
-- Board (SurfaceGui sur Screen), Header.Title (réécrit par le code), Header.Subtitle, List.Template (Rank, Avatar,
-- PlayerName, Value). Ce qui change :
--  - couleurs : orange pour l'argent de la semaine, rouge pour les vols (toit, socle, fond, en-tête, pastille) ;
--  - sous-titre « Resets every Monday » (remise à zéro le lundi à 0 h UTC, Config/WeeklyLeaderboard) ;
--  - List devient une ScrollingFrame (même place, même taille) : le code y clone les 100 lignes (MaxRows) ; Template et
--    marge en pixels (un enfant de ScrollingFrame en échelle suivrait la hauteur du canevas), canevas automatique en Y ;
--  - SPOT : la place choisie par Clément (voir plus bas), à plat ou rehaussé au-dessus des stands.
-- Aucun script, rien de nouveau au contrat (mêmes noms qu'en L-165). Screen garde CanQuery = true.
local CS = game:GetService("CollectionService")
local rgb = Color3.fromRGB
local zones = workspace.Map.Hub.Zones

-- emplacements : pivot (pieds), sens de la face avant (dx), pieds allongés (lift), taille (scale)
local SPOTS = {
	-- A : coin sud-est, en miroir des deux panneaux de tous les temps (coin nord-est, z 226 et 256) ; non retenu
	A = { WeeklyIncome = { x = 25.6, y = 0, z = -226, dx = -1, lift = 0, scale = 1 }, WeeklySteals = { x = 25.6, y = 0, z = -256, dx = -1, lift = 0, scale = 1 } },
	-- B : contre les murs est, de part et d'autre de la sortie, au-dessus des stands ; non retenu
	B = { WeeklyIncome = { x = 25.6, y = 0, z = 101, dx = -1, lift = 15, scale = 1 }, WeeklySteals = { x = 25.6, y = 0, z = -101, dx = -1, lift = 15, scale = 1 } },
	-- C (Clément, 2026-11-24 : « dans le fond de la map ») : sur le haut du mur de terre ouest (plat à 43,2 de z -39 à 31),
	-- dans l'axe de la sortie et de l'arrivée, face à la place ; un quart plus grands, ils dépassent les toits des
	-- boutiques 3 et 4 vus de la place ; argent à gauche (vu de la place), vols à droite
	C = { WeeklyIncome = { x = -277.5, y = 43.2, z = 18, dx = 1, lift = 0, scale = 1.25 }, WeeklySteals = { x = -277.5, y = 43.2, z = -18, dx = 1, lift = 0, scale = 1.25 } },
}
local SPOT = "C"
local MAX_DISTANCE = 450 -- de la sortie au mur ouest : 303 studs (300 sur les panneaux de tous les temps)

local THEME = {
	WeeklyIncome = { title = "MONEY/S THIS WEEK", accent = rgb(240, 138, 30), bg = rgb(255, 241, 224),
		head = { rgb(255, 184, 82), rgb(236, 112, 18) }, pill = { rgb(255, 170, 72), rgb(226, 100, 12) },
		icon = "rbxassetid://138179722277427" },
	WeeklySteals = { title = "STEALS THIS WEEK", accent = rgb(224, 64, 64), bg = rgb(253, 232, 230),
		head = { rgb(255, 122, 114), rgb(214, 44, 52) }, pill = { rgb(255, 110, 102), rgb(200, 40, 50) },
		icon = "rbxassetid://117932214637008" }, -- couronne de BB_Rarest, en attendant une icône de vol
}

local src
for _, m in zones:GetChildren() do
	if m.Name == "ENV_Hub_Leaderboard" and m:GetAttribute("Stat") == "Income" then src = m end
end
assert(src, "panneau Stat = Income introuvable dans Map/Hub/Zones")
for _, m in zones:GetChildren() do
	if m.Name == "ENV_Hub_Leaderboard" and tostring(m:GetAttribute("Stat")):match("^Weekly") then m:Destroy() end
end
-- hauteur d'une ligne et marge, en pixels, lues sur le panneau posé (une copie hors du jeu n'a pas de taille)
local srcList = src.Screen.Board.List
local rowH = math.floor(srcList.Template.AbsoluteSize.Y + 0.5)
local pad = math.floor(srcList.UIListLayout.Padding.Scale * srcList.AbsoluteSize.Y + srcList.UIListLayout.Padding.Offset + 0.5)
assert(rowH > 10, "taille des lignes illisible")

local out = {}
for _, stat in { "WeeklyIncome", "WeeklySteals" } do
	local t, spot = THEME[stat], SPOTS[SPOT][stat]
	local m = src:Clone()
	m:SetAttribute("Stat", stat)
	if not CS:HasTag(m, "Leaderboard") then CS:AddTag(m, "Leaderboard") end
	m.Roof.Color = t.accent; m.Footer.Color = t.accent
	local g = m.Screen.Board
	g.Background.BackgroundColor3 = t.bg
	g.Header.UIGradient.Color = ColorSequence.new(t.head[1], t.head[2])
	g.Header.Title.Text = t.title
	g.Header.Subtitle.Text = "Resets every Monday"
	g.Header.LeftIcon.Image = t.icon; g.Header.RightIcon.Image = t.icon
	-- List : Frame -> ScrollingFrame
	local old = g.List
	local list = Instance.new("ScrollingFrame"); list.Name = "List"
	list.AnchorPoint = old.AnchorPoint; list.Position = old.Position; list.Size = old.Size
	list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.ZIndex = old.ZIndex; list.LayoutOrder = old.LayoutOrder
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 12; list.ScrollBarImageColor3 = rgb(27, 31, 39)
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	for _, c in old:GetChildren() do c.Parent = list end
	list.UIListLayout.Padding = UDim.new(0, pad)
	list.Template.Size = UDim2.new(1, 0, 0, rowH)
	list.Template.ValuePill.UIGradient.Color = ColorSequence.new(t.pill[1], t.pill[2])
	if stat == "WeeklySteals" then list.Template.Value.Text = "128" end -- exemple (le code écrit le nombre de vols)
	list.Parent = g
	old:Destroy()
	-- place : face avant (-Z du pivot) vers l'ouest, la place ; pieds allongés de lift
	g.MaxDistance = MAX_DISTANCE
	local f = CFrame.lookAt(Vector3.new(spot.x, spot.y, spot.z), Vector3.new(spot.x + spot.dx, spot.y, spot.z))
	m:PivotTo(f)
	if spot.scale ~= 1 then m:ScaleTo(spot.scale) end
	if spot.lift > 0 then
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				if p.Name:match("^Leg_") then
					p.Size += Vector3.new(0, spot.lift, 0); p.CFrame += Vector3.new(0, spot.lift / 2, 0)
				else
					p.CFrame += Vector3.new(0, spot.lift, 0)
				end
			end
		end
	end
	m.Parent = zones
	table.insert(out, string.format("%s : (%.1f ; %.1f ; %.0f), taille ×%.2f, rehaussé de %d, lignes de %d px, marge %d px", stat, spot.x, spot.y, spot.z, spot.scale, spot.lift, rowH, pad))
end
return "emplacement " .. SPOT .. "\n" .. table.concat(out, "\n")
