--!nocheck
-- Mise en place du banc a76 (vague 25, cases stables de la barre du bas), après setup74.luau :
--   - vrai HotbarService (serveur : disposition gardée dans le champ Hotbar du profil, attribut
--     HotbarLayout, remote SetHotbar) ;
--   - layoutBar() : place Bar et ses cases à l'écran (AbsolutePosition / AbsoluteSize : Bar en
--     (200, 600) de 600 × 100, la case de rang r en (200 + 100 (r - 1), 600) de 100 × 100) ;
--   - slotCenter(rang), cardOf(section, nom) ;
--   - mouseDrag(frame, points, opts) / touchDrag(frame, points, opts) : appui sur `frame` (en son
--     centre, ou opts.from), mouvements jusqu'à chaque point, puis relâché au dernier ; opts.activated
--     = Activated de `frame` aussi au relâché (comme Roblox quand on lâche sur le bouton d'origine).
moduleScript(SERVICES, "HotbarService", "server/Services/HotbarService.luau")

BAR_ORIGIN = Vector2.new(200, 600)
SLOT_SIZE = 100
function layoutBar(screen)
	local gui = screen or HB.screen
	local bar = gui:FindFirstChild("Bar")
	bar.AbsolutePosition = BAR_ORIGIN
	bar.AbsoluteSize = Vector2.new(600, SLOT_SIZE)
	for _, child in bar:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Slot_" then
			child.AbsolutePosition = Vector2.new(BAR_ORIGIN.X + SLOT_SIZE * (child.LayoutOrder - 1), BAR_ORIGIN.Y)
			child.AbsoluteSize = Vector2.new(SLOT_SIZE, SLOT_SIZE)
		end
	end
end
function slotCenter(rank)
	return Vector2.new(BAR_ORIGIN.X + SLOT_SIZE * (rank - 1) + SLOT_SIZE / 2, BAR_ORIGIN.Y + SLOT_SIZE / 2)
end
-- La case de rang `rank` (cases clonées de la barre).
function slotAtRank(rank)
	for _, child in HB.screen.Bar:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Slot_" and child.LayoutOrder == rank then
			return child
		end
	end
	return nil
end
function cardOf(sectionName, name)
	local card = INV.sections[sectionName].cards:FindFirstChild(name)
	if card then
		card.AbsolutePosition = Vector2.new(300, 200)
		card.AbsoluteSize = Vector2.new(80, 80)
	end
	return card
end
local function centerOf(frame)
	local p, s = frame.AbsolutePosition, frame.AbsoluteSize
	return Vector2.new(p.X + s.X / 2, p.Y + s.Y / 2)
end
local function drag(kind, frame, points, opts)
	opts = opts or {}
	local from = opts.from or centerOf(frame)
	local touch = kind == "Touch"
	local input = {
		UserInputType = if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(from.X, from.Y, 0),
	}
	frame.InputBegan:Fire(input)
	if not touch then
		frame.MouseButton1Down:Fire()
	end
	flush()
	local last = from
	for _, point in points do
		last = point
		if touch then
			input.Position = Vector3.new(point.X, point.Y, 0)
			UserInputServiceStub.InputChanged:Fire(input, false)
		else
			UserInputServiceStub.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(point.X, point.Y, 0) }, false)
		end
		flush()
		if opts.during then
			opts.during(point)
		end
	end
	if opts.hold then
		advance(opts.hold)
	end
	local ended = if touch then input else { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(last.X, last.Y, 0) }
	if touch then
		input.Position = Vector3.new(last.X, last.Y, 0)
	end
	UserInputServiceStub.InputEnded:Fire(ended, false)
	if opts.activated then
		frame.Activated:Fire()
	end
	flush()
end
function mouseDrag(frame, points, opts)
	drag("Mouse", frame, points, opts)
end
function touchDrag(frame, points, opts)
	drag("Touch", frame, points, opts)
end
-- Le calque du glisser (écran HotbarDrag) et sa copie.
function dragGhost(player)
	local layer = player.PlayerGui:FindFirstChild("HotbarDrag")
	return layer and layer:FindFirstChild("DragGhost")
end
function hotbarSent()
	return serverCalls("SetHotbar")
end
function layoutText(list)
	return table.concat(list, ",")
end
