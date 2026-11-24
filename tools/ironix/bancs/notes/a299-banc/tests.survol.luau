---------------------------------------------------------------- scénario « survol » (a299, 21/11 : grossir autour du centre)
-- Après setup.luau du banc a50, faux Roblox d'a290 (tweens simulés, UserInputService, render290). Le centre à l'écran
-- est calculé ici d'après Position, Size, AnchorPoint et UIScale (le faux Roblox ne dessine rien), image par image.
-- B boutons (Motion.Button, Hover = Pop, Press = Squash) d'AnchorPoint (0, 0), (0,5 ; 0,5) et (1, 1) ; E UIScale de
-- Clément ; L bouton rangé par un layout ; Q contrainte ; P carte Pop (Icon × 1,15) ; J carte Pop + IconHover Jump ;
-- N carte sans Pop (× 1,03) ; O réglage coupé.
-- UDim2 + UDim2 et == par valeur (UiAttrFx Jump, Motion.HoverCard, comme dans Roblox) : le faux Roblox d'a50 rend des
-- tables nues ; les UDim2 créés à partir d'ici en ont la métatable.
local UD2 = {}
local function ud2(xs, xo, ys, yo)
	return setmetatable({ X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } }, UD2)
end
UD2.__add = function(a, b)
	return ud2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__eq = function(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
UDim2.new = ud2
UDim2.fromScale = function(x, y)
	return ud2(x, 0, y, 0)
end
UDim2.fromOffset = function(x, y)
	return ud2(0, x, 0, y)
end
USE_UIS290 = true
ROBLOX_STRICT = false
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers299")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
-- UiAttrFx tire ses délais au hasard (Random), absent du faux Roblox d'a50 : un Random fixe suffit ici.
Random = Random or {
	new = function()
		return {
			NextNumber = function(_self, lo, hi)
				return ((lo or 0) + (hi or 1)) / 2
			end,
			NextInteger = function(_self, lo, _hi)
				return lo
			end,
		}
	end,
}
local fxModule = moduleScript(ui, "UiAttrFx", "client/Controllers/UI/UiAttrFx.luau")
local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local UiAttrFx = requireModule(fxModule, "client")
Motion.SetSoundPlayer(function()
	return true
end)

print("-- Survol a299")
check(UiMotion.Hover.Centered == true, "V1 Config/UiMotion.Hover.Centered allumé")
check(UiMotion.HoverPop.To == 1.1 and UiMotion.HoverPop.IconScale == 1.15 and UiMotion.Hover.CardTo == 1.03 and UiMotion.PressSquash.To == 0.75,
	"V2 échelles de Clément inchangées (× 1,10 ; Icon × 1,15 ; carte × 1,03 ; appui 0,75)")

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end
	return nil
end
local function sv(object)
	local s = scaleOf(object)
	return if s then s.Scale else 1
end
local function fmt(v)
	return string.format("%.3f", v)
end
local W, H = 1000, 600
local gui = new("ScreenGui", { Name = "UI_T299", Enabled = true })
gui.Parent = playerGui
local holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1, AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(W, H) }, gui)

-- Centre à l'écran d'un élément dans un parent de pw × ph px en (ox, oy) ; real : taille dessinée (contrainte).
local function center(o, pw, ph, ox, oy, real)
	local w = if real then real.X else o.Size.X.Scale * pw + o.Size.X.Offset
	local h = if real then real.Y else o.Size.Y.Scale * ph + o.Size.Y.Offset
	local x = ox + o.Position.X.Scale * pw + o.Position.X.Offset
	local y = oy + o.Position.Y.Scale * ph + o.Position.Y.Offset
	local s = sv(o)
	local a = o.AnchorPoint
	return x + (0.5 - a.X) * w * s, y + (0.5 - a.Y) * h * s
end
-- Joue `seconds` s par pas de 0,01 s ; rend l'écart maximal du centre (px) à (cx, cy), et les échelles min et max.
local function watch(o, seconds, at, cx, cy, real)
	local dev, lo, hi = 0, math.huge, -math.huge
	for _ = 1, math.max(1, math.ceil(seconds / 0.01)) do
		step(0.01)
		render290(o)
		local x, y = at(o, real)
		dev = math.max(dev, math.abs(x - cx), math.abs(y - cy))
		lo, hi = math.min(lo, sv(o)), math.max(hi, sv(o))
	end
	return dev, lo, hi
end
local function inHolder(o, real)
	return center(o, W, H, 0, 0, real)
end
local function sameRest(o, rest)
	return o.Position == rest.Position and o.AnchorPoint == rest.AnchorPoint and o.Size == rest.Size and scaleOf(o) == rest.scale and not Motion.IsCentered(o)
end
local function restOf(o)
	return { Position = o.Position, AnchorPoint = o.AnchorPoint, Size = o.Size, scale = scaleOf(o) }
end
local function pointer(x, y)
	UIS290.InputChanged:Fire(input290("MouseMovement", x, y), false)
end

---------------------------------------------------------------- B. Boutons, trois AnchorPoint
local n = 0
local function makeButton(ap, parent, props)
	n += 1
	local b = new("TextButton", { Name = "Button" .. n, AnchorPoint = ap, Position = UDim2.new(0.2, 10, 0.3, 6), Size = UDim2.new(0.1, 20, 0.1, 8) }, parent or holder)
	for k, v in props or {} do
		b[k] = v
	end
	b:SetAttribute("Hover", "Pop")
	b:SetAttribute("Press", "Squash")
	return b
end
-- Rectangle de Studio (sans UIScale) pour render290 et la zone de clic d'a290.
local function placeBase(b, real)
	local w = if real then real.X else b.Size.X.Scale * W + b.Size.X.Offset
	local h = if real then real.Y else b.Size.Y.Scale * H + b.Size.Y.Offset
	local x = b.Position.X.Scale * W + b.Position.X.Offset - b.AnchorPoint.X * w
	local y = b.Position.Y.Scale * H + b.Position.Y.Offset - b.AnchorPoint.Y * h
	base290(b, x, y, w, h)
	return x + w / 2, y + h / 2
end
for _, ap in { Vector2.new(0, 0), Vector2.new(0.5, 0.5), Vector2.new(1, 1) } do
	local tag = `({ap.X} ; {ap.Y})`
	local b = makeButton(ap)
	local mx, my = placeBase(b)
	local rest = restOf(b)
	Motion.Button(b)
	local clicks = 0
	Motion.Activated(b):Connect(function()
		clicks += 1
	end)
	local cx, cy = inHolder(b)
	check(near(cx, mx, 1e-6) and near(cy, my, 1e-6), `B0 {tag} centre calculé = centre du rectangle de Studio`)
	pointer(cx, cy)
	b.MouseEnter:Fire()
	step(0.001)
	local centered = Motion.IsCentered(b)
	check(centered == (ap.X ~= 0.5), `B1 {tag} recentré pendant le survol : {centered} (AnchorPoint {b.AnchorPoint.X} ; {b.AnchorPoint.Y})`)
	local dev, _, hi = watch(b, 0.3, inHolder, cx, cy)
	check(near(hi, 1.1, 1e-3) and dev <= 0.5, `B2 {tag} survol × {fmt(hi)} : centre fixe ({fmt(dev)} px)`)
	local input = input290("MouseButton1", cx, cy)
	b.InputBegan:Fire(input)
	UIS290.InputBegan:Fire(input, false)
	b.MouseButton1Down:Fire()
	local dev2, lo2 = watch(b, 0.12, inHolder, cx, cy)
	check(near(lo2, 0.75, 1e-3) and dev2 <= 0.5, `B3 {tag} appui écrasé à × {fmt(lo2)} : centre fixe ({fmt(dev2)} px)`)
	input.UserInputState = Enum.UserInputState.End
	UIS290.InputEnded:Fire(input, false)
	b.MouseButton1Up:Fire()
	b.Activated:Fire(input, 1)
	local dev3, _, hi3 = watch(b, 0.4, inHolder, cx, cy)
	check(clicks == 1 and hi3 > 1.09 and dev3 <= 0.5, `B4 {tag} relâché : un clic ({clicks}), rebond × {fmt(hi3)}, centre fixe ({fmt(dev3)} px)`)
	pointer(-50, -50)
	b.MouseLeave:Fire()
	local dev4 = watch(b, 0.5, inHolder, cx, cy)
	check(dev4 <= 0.5 and sameRest(b, rest), `B5 {tag} souris sortie : centre fixe ({fmt(dev4)} px), puis Position, AnchorPoint et Size de Clément exactement, plus de UIScale`)
	-- Survol bref (entrée puis sortie aussitôt), puis souris sortie sans MouseLeave (a290, L-275).
	pointer(cx, cy)
	b.MouseEnter:Fire()
	step(0.02)
	pointer(-50, -50)
	b.MouseLeave:Fire()
	local dev5 = watch(b, 0.5, inHolder, cx, cy)
	check(dev5 <= 0.5 and sameRest(b, rest), `B6 {tag} survol bref : retour exact au repos ({fmt(dev5)} px)`)
	pointer(cx, cy)
	b.MouseEnter:Fire()
	watch(b, 0.2, inHolder, cx, cy)
	pointer(-50, -50)
	local dev6 = watch(b, 0.6, inHolder, cx, cy)
	check(dev6 <= 0.5 and sameRest(b, rest), `B7 {tag} souris sortie sans MouseLeave : retour exact au repos ({fmt(dev6)} px)`)
	b.MouseLeave:Fire()
	step(0.2)
end

---------------------------------------------------------------- E. UIScale de Clément : jamais touché
for _, ap in { Vector2.new(0, 0), Vector2.new(1, 1) } do
	local tag = `({ap.X} ; {ap.Y})`
	local b = makeButton(ap)
	local own = new("UIScale", { Name = "UIScale", Scale = 0.9 }, b)
	placeBase(b)
	local rest = restOf(b)
	Motion.Button(b)
	local cx, cy = inHolder(b)
	pointer(cx, cy)
	b.MouseEnter:Fire()
	local dev = watch(b, 0.3, inHolder, cx, cy)
	check(dev <= 0.5 and sameRest(b, rest) and own.Scale == 0.9 and #b:GetChildren() == 1, `E1 {tag} UIScale de Clément : ni recentré ni grossi, rien d'ajouté ({fmt(dev)} px)`)
	pointer(-50, -50)
	b.MouseLeave:Fire()
	watch(b, 0.4, inHolder, cx, cy)
	check(sameRest(b, rest) and own.Parent == b and own.Scale == 0.9, `E2 {tag} souris sortie : tout comme Clément l'a posé`)
end

---------------------------------------------------------------- L. Bouton rangé par un layout : pas recentré
do
	local row = new("Frame", { Name = "Row", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(W, H) }, holder)
	new("UIListLayout", { Name = "UIListLayout" }, row)
	local b = makeButton(Vector2.new(0, 0), row)
	placeBase(b)
	local rest = restOf(b)
	Motion.Button(b)
	pointer(260, 220)
	b.MouseEnter:Fire()
	step(0.001)
	local centered = Motion.IsCentered(b)
	local _, _, hi = watch(b, 0.3, inHolder, 0, 0)
	check(not centered and b.AnchorPoint == rest.AnchorPoint and b.Position == rest.Position and near(hi, 1.1, 1e-3),
		`L1 dans un UIListLayout : ni AnchorPoint ni Position touchés (le layout le place), survol × {fmt(hi)} comme avant`)
	pointer(-50, -50)
	b.MouseLeave:Fire()
	watch(b, 0.5, inHolder, 0, 0)
	check(sameRest(b, rest), "L2 souris sortie : au repos")
end

---------------------------------------------------------------- Q. Contrainte : la taille dessinée compte
do
	local real = Vector2.new(60, 60)
	local b = makeButton(Vector2.new(0, 0), nil, { Size = UDim2.fromScale(0.3, 0.1) })
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, b)
	placeBase(b, real)
	local rest = restOf(b)
	Motion.Button(b)
	local cx, cy = inHolder(b, real)
	pointer(cx, cy)
	b.MouseEnter:Fire()
	local dev, _, hi = watch(b, 0.3, inHolder, cx, cy, real)
	check(Motion.IsCentered(b) and near(hi, 1.1, 1e-3) and dev <= 0.5, `Q1 UIAspectRatioConstraint (Size 300 × 60, dessiné 60 × 60) : centre fixe ({fmt(dev)} px)`)
	pointer(-50, -50)
	b.MouseLeave:Fire()
	local dev2 = watch(b, 0.5, inHolder, cx, cy, real)
	check(dev2 <= 0.5 and sameRest(b, rest), `Q2 souris sortie : retour exact au repos ({fmt(dev2)} px)`)
end

---------------------------------------------------------------- P, J, N. Cartes (Motion.HoverCard)
-- Carte de 200 × 240 px en (500, 200), dans une grille (comme les cartes de Clément) ; son Icon AnchorPoint (0, 0).
local function makeCard(name, pop, parent, ap)
	local card = new("ImageButton", { Name = name, AnchorPoint = ap or Vector2.new(0, 0), Position = UDim2.fromOffset(500, 200), Size = UDim2.fromOffset(200, 240) }, parent)
	if pop then
		card:SetAttribute("Hover", "Pop")
	end
	base290(card, 500, 200, 200, 240)
	local icon = new("ImageLabel", { Name = "Icon", Position = UDim2.new(-0.026, 4, -0.123, 2), Size = UDim2.fromScale(1, 1), AbsoluteSize = Vector2.new(200, 240) }, card)
	return card, icon
end
local function inCard(icon)
	return center(icon, 200, 240, 0, 0)
end
local grid = new("ScrollingFrame", { Name = "Grid", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(W, H) }, holder)
new("UIGridLayout", { Name = "UIGridLayout" }, grid)
do
	local card, icon = makeCard("PopCard", true, grid)
	local rest = restOf(icon)
	Motion.HoverCard(card)
	local cx, cy = inCard(icon)
	pointer(600, 320)
	card.MouseEnter:Fire()
	local dev, _, hi = watch(icon, 0.3, inCard, cx, cy)
	check(near(hi, 1.15, 1e-3) and dev <= 0.5, `P1 carte Pop : Icon × {fmt(hi)} autour de son centre ({fmt(dev)} px)`)
	check(card.AnchorPoint.X == 0 and card.AnchorPoint.Y == 0 and card.Position.X.Offset == 500 and card.Position.Y.Offset == 200 and not Motion.IsCentered(card), "P2 la carte (dans la grille) garde AnchorPoint et Position")
	pointer(-50, -50)
	card.MouseLeave:Fire()
	local dev2 = watch(icon, 0.5, inCard, cx, cy)
	check(dev2 <= 0.5 and sameRest(icon, rest), `P3 souris sortie : Icon exactement à la place de Clément ({fmt(dev2)} px)`)
	-- Icon avec un UIScale de Clément : ni recentré ni grossi.
	local card2, icon2 = makeCard("PopCard2", true, grid)
	new("UIScale", { Name = "UIScale", Scale = 1 }, icon2)
	local rest2 = restOf(icon2)
	Motion.HoverCard(card2)
	pointer(600, 320)
	card2.MouseEnter:Fire()
	watch(icon2, 0.3, inCard, 0, 0)
	check(sameRest(icon2, rest2), "P4 Icon avec un UIScale de Clément : rien touché")
	pointer(-50, -50)
	card2.MouseLeave:Fire()
	step(0.5)
end
do
	local card, icon = makeCard("JumpCard", true, grid)
	card:SetAttribute("IconHover", "Jump")
	local rest = restOf(icon)
	Motion.HoverCard(card)
	UiAttrFx.Wire(card)
	local cx, cy = inCard(icon)
	local height = icon.AbsoluteSize.Y * UiMotion.AttrFx.IconHover.Jump.Height
	pointer(600, 320)
	card.MouseEnter:Fire()
	local devX, top = 0, 0
	for _ = 1, 45 do
		step(0.01)
		local x, y = inCard(icon)
		devX = math.max(devX, math.abs(x - cx))
		top = math.max(top, cy - y)
	end
	check(devX <= 0.5 and near(top, height, 0.6), `J1 Pop + Jump : l'Icon saute de {fmt(top)} px (attendu {fmt(height)}) sans glisser de côté ({fmt(devX)} px)`)
	local x, y = inCard(icon)
	check(near(x, cx, 0.5) and near(y, cy, 0.5) and Motion.IsCentered(icon), `J2 saut fini, survol tenu : Icon à sa place, grossi autour du centre`)
	pointer(-50, -50)
	card.MouseLeave:Fire()
	step(0.5)
	check(sameRest(icon, rest), "J3 souris sortie : Icon exactement à la place de Clément")
	-- Sortie au milieu du saut.
	pointer(600, 320)
	card.MouseEnter:Fire()
	step(0.1)
	pointer(-50, -50)
	card.MouseLeave:Fire()
	step(0.6)
	check(sameRest(icon, rest), "J4 sortie au milieu du saut : Icon exactement à la place de Clément")
end
do
	-- Carte sans Pop hors layout (× 1,03), AnchorPoint (1, 1) : la carte grossit autour de son centre. Son Icon est retiré :
	-- le faux Roblox d'a50 ne simule pas un tween de Position (l'Icon d'une carte sans Pop est vu par les bancs a285 et a286).
	local card, icon = makeCard("PlainCard", false, holder, Vector2.new(1, 1))
	icon:Destroy()
	base290(card, 300, -40, 200, 240)
	local rest = restOf(card)
	Motion.HoverCard(card)
	local cx, cy = inHolder(card)
	pointer(cx, cy)
	card.MouseEnter:Fire()
	local dev, _, hi = watch(card, 0.3, inHolder, cx, cy)
	check(near(hi, 1.03, 1e-3) and dev <= 0.5 and Motion.IsCentered(card), `N1 carte sans Pop (1 ; 1) : × {fmt(hi)} autour de son centre ({fmt(dev)} px)`)
	pointer(-50, -50)
	card.MouseLeave:Fire()
	local dev2 = watch(card, 0.5, inHolder, cx, cy)
	check(dev2 <= 0.5 and sameRest(card, rest), `N2 souris sortie : carte exactement comme Clément ({fmt(dev2)} px)`)
end

---------------------------------------------------------------- O. Réglage coupé : comme avant (depuis le coin)
do
	local b = makeButton(Vector2.new(0, 0))
	placeBase(b)
	local rest = restOf(b)
	local ok = pcall(function()
		(UiMotion.Hover :: any).Centered = false
	end)
	if ok and UiMotion.Hover.Centered == false then
		Motion.Button(b)
		pointer(260, 220)
		b.MouseEnter:Fire()
		watch(b, 0.3, inHolder, 0, 0)
		check(not Motion.IsCentered(b) and b.AnchorPoint == rest.AnchorPoint and b.Position == rest.Position and near(sv(b), 1.1, 1e-3), "O1 Hover.Centered = false : survol comme avant (rien recentré)")
		pointer(-50, -50)
		b.MouseLeave:Fire()
		watch(b, 0.5, inHolder, 0, 0)
		check(sameRest(b, rest), "O2 souris sortie : au repos")
	else
		check(SOURCES["client/Controllers/UI/Motion.luau"]:find("not UiMotion.Hover.Centered", 1, true) ~= nil, "O1 (Config gelée) Motion lit Hover.Centered avant de recentrer")
	end
end
summary()
