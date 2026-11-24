---------------------------------------------------------------- scénario « open » (L-094) : ouverture des écrans
local M = UiMotionC
local ST = M.OpenStagger
local Motion = requireModule(MOTION_MODULE, "client")

print("\n== O0. Valeurs validées par Clément (tableau, lignes « Étendues à tout le jeu »)")
check(M.Open.From == 0.55 and M.Open.Time == 0.14 and M.Open.Style == Enum.EasingStyle.Back and M.Open.Direction == Enum.EasingDirection.Out, "O0a Open : Root 0,55 → 1 en 0,14, Back Out")
check(ST.From == 0 and ST.Time == 0.14 and ST.Start == 0.08 and ST.Gap == 0.035 and ST.Max == 14 and ST.Style == Enum.EasingStyle.Back, "O0b OpenStagger : 0 → 1 en 0,14, départ 0,08, 0,035 entre deux, 14 au plus, Back Out")
check(M.Close.To == 0 and M.Close.Time == 0.09 and M.Close.Style == Enum.EasingStyle.Quad and M.Close.Direction == Enum.EasingDirection.In, "O0c Close : 1 → 0 en 0,09, Quad In")
check(M.Swap.OutTime == 0.1 and M.Swap.OutGap == 0.03 and M.Swap.Style == Enum.EasingStyle.Quad and M.Swap.Direction == Enum.EasingDirection.In, "O0d Swap : sortie à 0 en 0,1, 0,03 entre deux, Quad In")
check(M.Hover.To == 1.06 and M.Hover.Time == 0.08 and M.Hover.ShadeTransparency == 0.78 and M.Press.To == 0.95 and M.Press.Time == 0.05 and M.Press.ShadeTransparency == 0.62, "O0e Hover × 1,06 en 0,08, Shade 0,78 ; Press × 0,95 en 0,05, Shade 0,62")
check(M.Release.Time == 0.2 and M.Release.Style == Enum.EasingStyle.Back and M.Success.From == 1.22 and M.Success.Time == 0.28 and M.Success.SoundDelay == 0.12, "O0f Release en 0,2 Back Out ; Success × 1,22 → 1 en 0,28, son 0,12 s après")

-- Un écran comme UI_Inventory : Root (1 × 0,72) / Window / List avec 16 cartes (HoverOutline), 4 par
-- rangée, un Template caché, et une page cachée avec sa carte ; PageB (5 cartes) cachée pour Swap.
local function card(name, parent, col, row)
	local c = new("Frame", { Name = name, Position = UDim2.fromScale(col * 0.25, row * 0.2), Size = UDim2.fromScale(0.24, 0.18) }, parent)
	new("Frame", { Name = "HoverOutline", Visible = false, Size = UDim2.fromScale(1, 1) }, c)
	new("ImageLabel", { Name = "Icon" }, c)
	return c
end
local gui = new("ScreenGui", { Name = "UI_Inventory", Enabled = false, ResetOnSpawn = false })
local root = new("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.72), BackgroundTransparency = 1 }, gui)
local window = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.96, 0.9) }, root)
local pageA = new("Frame", { Name = "ItemsPage", Size = UDim2.fromScale(1, 1) }, window)
local cardsA = {}
for i = 16, 1, -1 do -- créées dans le désordre : l'ordre vient des positions
	local index = i - 1
	cardsA[i] = card(`Card_{i}`, pageA, index % 4, index // 4)
end
local template = card("Template", pageA, 0, 0)
template.Visible = false
local hidden = new("Frame", { Name = "HiddenPage", Visible = false, Size = UDim2.fromScale(1, 1) }, window)
local hiddenCard = card("Hidden_1", hidden, 0, 0)
local pageB = new("Frame", { Name = "ToolsPage", Visible = false, Size = UDim2.fromScale(1, 1) }, window)
local cardsB = {}
for i = 1, 5 do
	cardsB[i] = card(`Tool_{i}`, pageB, (i - 1) % 4, (i - 1) // 4)
end
local clementScale = new("UIScale", { Name = "UIScale", Scale = 0.9 }, cardsA[16])
gui.Parent = PLAYER_GUI
local snap = snapshot(gui)
local function stag(object)
	return scaleNamed(object, ST.ScaleName)
end
local elapsed = 0
local function wait(seconds)
	step(seconds)
	elapsed += seconds
end

print("\n== O1. Ouverture : Root à 0,55, toutes les cartes visibles à 0")
Motion.Open(gui)
local rootScale = motionScale(root)
check(gui.Enabled and rootScale ~= nil and rootScale.Scale == M.Open.From, "O1a Root à 0,55")
local all = true
for i = 1, 15 do
	local s = stag(cardsA[i])
	all = all and s ~= nil and s.Scale == 0
end
check(all, "O1b les 15 cartes visibles à 0 (UIScale passager)")
check(stag(template) == nil and stag(hiddenCard) == nil and stag(cardsB[1]) == nil, "O1c ni le Template, ni les cartes d'une page cachée")
check(stag(cardsA[16]) == nil and clementScale.Scale == 0.9, "O1d carte avec l'UIScale de Clément : pas touchée")
check(Motion.GetStaggerCount(gui) == 15, `O1e 15 cartes à faire entrer ({Motion.GetStaggerCount(gui)})`)

print("\n== O2. Une à une, dans l'ordre de lecture")
wait(1 / 30) -- l'ordre est calculé à la fin de l'image
wait(ST.Start + 0.005 - 1 / 30) -- t ≈ 0,085 : la 1re est partie, pas la 2e
check(stag(cardsA[1]).Scale > 0 and stag(cardsA[2]).Scale == 0, `O2a à 0,085 s : la 1re part, pas la 2e ({stag(cardsA[1]).Scale})`)
wait(ST.Gap) -- t ≈ 0,12 : la 2e
check(stag(cardsA[2]).Scale > 0 and stag(cardsA[3]).Scale == 0, "O2b 0,035 s plus tard : la 2e")
local maxRoot = 0
for _ = 1, 3 do
	wait(1 / 30)
	local s = motionScale(root)
	if s then
		maxRoot = math.max(maxRoot, s.Scale)
	end
end
check(motionScale(root) == nil, `O2c Root à 1 en {M.Open.Time} s, UIScale retiré (le dépassement est contrôlé par le banc a37, M1f)`)
-- t ≈ 0,22. La 13e part à 0,08 + 12 × 0,035 = 0,50 ; la 14e et la 15e ensemble à 0,535.
wait(0.51 - elapsed)
check(stag(cardsA[13]).Scale > 0 and stag(cardsA[14]).Scale == 0 and stag(cardsA[15]).Scale == 0, "O2d à 0,51 s : la 13e partie, ni la 14e ni la 15e")
wait(0.56 - elapsed)
check(stag(cardsA[14]).Scale > 0 and near(stag(cardsA[14]).Scale, stag(cardsA[15]).Scale, 1e-6), "O2e la 14e et la 15e ensemble (14 au plus)")
wait(0.535 + ST.Time + 0.05 - elapsed)
check(Motion.GetStaggerCount(gui) == 0 and anyUIScale(pageA) == clementScale, "O2f toutes arrivées : plus aucun UIScale du code")
check(Motion.GetState(gui) == "Open", "O2g écran ouvert")

print("\n== O3. Fermeture : 1 → 0 en 0,09, puis éteint")
Motion.Close(gui)
step(M.Close.Time / 2)
local closing = motionScale(root)
check(gui.Enabled and closing ~= nil and closing.Scale < 1 and closing.Scale > 0, "O3a en train de rapetisser")
step(M.Close.Time / 2 + 1 / 30)
check(gui.Enabled == false and motionScale(root) == nil, "O3b éteint, UIScale retiré")

print("\n== O4. Fermé pendant l'arrivée des cartes : tout est retiré")
Motion.Open(gui)
step(0.2)
check(Motion.GetStaggerCount(gui) > 0, "O4a des cartes encore en route")
Motion.Close(gui)
check(Motion.GetStaggerCount(gui) == 0 and stag(cardsA[10]) == nil, "O4b fermeture : les cartes reprennent leur taille tout de suite")
step(0.5)
check(gui.Enabled == false and anyUIScale(gui) == clementScale, "O4c éteint, rien laissé")

print("\n== O5. Changement d'onglet (Swap)")
Motion.Open(gui)
step(1)
local changes = 0
local function toTools()
	changes += 1
	pageA.Visible = false
	pageB.Visible = true
end
Motion.Swap(gui, toTools)
check(changes == 0 and stag(cardsA[1]) ~= nil and stag(cardsA[1]).Scale == 1, "O5a les cartes visibles sortent d'abord (page pas encore changée)")
local outTotal = (math.min(15, ST.Max) - 1) * M.Swap.OutGap + M.Swap.OutTime
step(M.Swap.OutTime + 1 / 30)
check(stag(cardsA[15]).Scale < 0.05 and stag(cardsA[1]).Scale > 0.5, "O5b de la dernière à la première")
step(outTotal - M.Swap.OutTime)
check(changes == 1 and pageB.Visible and not pageA.Visible, `O5c au bout de {outTotal} s : la page change (une fois)`)
check(stag(cardsA[1]) == nil, "O5d anciennes cartes rendues à leur taille")
check(stag(cardsB[1]) ~= nil and stag(cardsB[1]).Scale == 0 and stag(cardsB[5]) ~= nil, "O5e les nouvelles cartes entrent comme OpenStagger")
step(1)
check(Motion.GetStaggerCount(gui) == 0 and anyUIScale(pageB) == nil, "O5f arrivées, rien laissé")

print("\n== O6. Deux onglets de suite : chaque changement est fait, une fois, dans l'ordre")
local order = {}
Motion.Swap(gui, function()
	table.insert(order, "A")
	pageB.Visible = false
	pageA.Visible = true
end)
step(0.05)
Motion.Swap(gui, function()
	table.insert(order, "B")
	pageA.Visible = false
	pageB.Visible = true
end)
check(table.concat(order, ",") == "A", "O6a le 1er changement est fait tout de suite quand le 2e arrive")
step(1.5)
check(table.concat(order, ",") == "A,B" and pageB.Visible, `O6b puis le 2e ({table.concat(order, ",")})`)
check(Motion.GetStaggerCount(gui) == 0, "O6c rien en route")

print("\n== O7. Écran fermé, ou fermé pendant la sortie : changement tout de suite")
Motion.Close(gui)
step(0.3)
local direct = 0
Motion.Swap(gui, function()
	direct += 1
end)
check(direct == 1, "O7a écran éteint : change() tout de suite")
Motion.Open(gui)
step(1)
local late = 0
Motion.Swap(gui, function()
	late += 1
	pageB.Visible = false
	pageA.Visible = true
end)
step(0.05)
Motion.Close(gui)
check(late == 1, "O7b fermé pendant la sortie : change() fait à la fermeture")
step(1)
check(late == 1 and gui.Enabled == false and anyUIScale(gui) == clementScale, "O7c une seule fois, rien laissé")
local same, why = sameAs(snap, gui, { [gui] = { Enabled = true }, [pageA] = { Visible = true }, [pageB] = { Visible = true } })
check(same, `O8 écran comme au départ ({why})`)
summary()
