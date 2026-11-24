---------------------------------------------------------------- banc a278 (23/11, L-272 : Hover = Grow, IconHover = Spring)
-- Après setup.luau du banc a50, faux Roblox d'a290 (tweens simulés, UserInputService, GuiService, render290), comme le
-- scénario « survol » d'a299. G : cartes Hover = Grow (Motion.HoverCard) ; S : IconHover = Spring (UiAttrFx.Spring) ;
-- W : branchement d'une carte Grow dans UiFeelController (source).
-- UDim2 + UDim2 et == par valeur, comme dans Roblox (repris d'a299).
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
-- Ajouts purs du faux Roblox pour UiAttrFx (Spring) : signaux InputChanged et Destroying, FindFirstAncestorOfClass.
EVENTS.InputChanged = true
EVENTS.Destroying = true
if Methods.FindFirstAncestorOfClass == nil then
	function Methods.FindFirstAncestorOfClass(self, class)
		local current = self.Parent
		while current ~= nil do
			if current.ClassName == class then
				return current
			end
			current = current.Parent
		end
		return nil
	end
end
USE_UIS290 = true
ROBLOX_STRICT = false
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers278")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
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
local GROW = UiMotion.HoverGrow
local SPRING = UiMotion.AttrFx.IconHover.Spring

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
local gui = new("ScreenGui", { Name = "UI_T278", Enabled = true })
gui.Parent = playerGui
local holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1, AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(W, H) }, gui)
local function pointer(x, y)
	UIS290.InputChanged:Fire(input290("MouseMovement", x, y), false)
end
-- Joue `seconds` s par pas de 0,01 s ; rend l'échelle min et max de `o`.
local function watch(o, seconds)
	local lo, hi = math.huge, -math.huge
	for _ = 1, math.max(1, math.ceil(seconds / 0.01)) do
		step(0.01)
		render290(o)
		lo, hi = math.min(lo, sv(o)), math.max(hi, sv(o))
	end
	return lo, hi
end

print("-- Valeurs")
check(GROW.To == 1.08 and GROW.SmallBelow == 250 and GROW.EdgePx == 8 and GROW.Time == 0.1 and GROW.BackTime == 0.1,
	"V1 HoverGrow de la fiche HUD : × 1,08, 250 px, 8 px par bord, 0,1 s aller et retour")
check(SPRING.Angle == 10 and SPRING.Back == 0.35 and SPRING.Enter > 0 and SPRING.Frequency > 0 and SPRING.Damping > 0 and SPRING.Damping < 1,
	"V2 Spring : 10° au plus, retour 0,35 s (fiche shop), ressort amorti (V0)")

---------------------------------------------------------------- G. Hover = Grow
-- Carte w × h px en (x, y) dans `parent`, avec HoverOutline caché et Icon (AnchorPoint (0, 0)).
local function makeCard(name, parent, x, y, w, h, zIndex)
	local card = new("ImageButton", { Name = name, AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = zIndex or 2, Rotation = 0 }, parent)
	card:SetAttribute("Hover", "Grow")
	base290(card, x, y, w, h)
	local outline = new("Frame", { Name = "HoverOutline", Visible = false }, card)
	local icon = new("ImageLabel", { Name = "Icon", Position = UDim2.new(0.1, 0, 0.1, 0), Size = UDim2.fromScale(0.8, 0.8), Rotation = 4, AbsoluteSize = Vector2.new(w * 0.8, h * 0.8) }, card)
	return card, icon, outline
end
do
	local neighbour = new("Frame", { Name = "Neighbour", ZIndex = 5 }, holder)
	local card, icon, outline = makeCard("GrowCard", holder, 300, 100, 200, 240, 2)
	local iconPosition, iconRotation = icon.Position, icon.Rotation
	Motion.HoverCard(card)
	pointer(400, 220)
	card.MouseEnter:Fire()
	local _, hi = watch(card, 0.15)
	check(near(hi, 1.08, 1e-3) and near(sv(card), 1.08, 1e-3), `G1 carte de 200 × 240 px : × {fmt(hi)} (attendu 1,08)`)
	check(card.Rotation == 0, "G2 la carte ne penche pas (pas de CardTilt)")
	check(scaleOf(icon) == nil and icon.Position == iconPosition and icon.Rotation == iconRotation, "G3 l'Icon n'est ni grossi, ni penché, ni décalé")
	check(outline.Visible == true, "G4 HoverOutline allumé")
	check(card.ZIndex == 6, `G5 ZIndex relevé au-dessus des voisines (5) : {card.ZIndex}`)
	-- 0,1 s : arrivée au bout de Time (Quad Out, sans dépassement).
	pointer(-50, -50)
	card.MouseLeave:Fire()
	local lo2, hi2 = watch(card, 0.15)
	check(hi2 <= 1.08 + 1e-6 and lo2 >= 1 - 1e-6, `G6 retour sans dépassement ({fmt(lo2)} à {fmt(hi2)})`)
	check(scaleOf(card) == nil and card.ZIndex == 2 and outline.Visible == false and not Motion.IsCentered(card),
		`G7 souris sortie : UIScale retiré, ZIndex de Clément (2), HoverOutline caché ({card.ZIndex})`)
	check(card.AnchorPoint.X == 0 and card.AnchorPoint.Y == 0 and card.Position == UDim2.fromOffset(300, 100), "G8 AnchorPoint et Position de Clément")
	-- Temps de montée : à 0,05 s, en route ; à 0,1 s, arrivé.
	pointer(400, 220)
	card.MouseEnter:Fire()
	step(0.05)
	local mid = sv(card)
	step(0.06)
	check(mid > 1.02 and mid < 1.08 and near(sv(card), 1.08, 1e-3), `G9 montée en 0,1 s Quad Out ({fmt(mid)} à 0,05 s)`)
	-- Re-survol pendant le retour : la carte repart vers 1,08 sans perdre son ZIndex de Clément.
	card.MouseLeave:Fire()
	step(0.04)
	card.MouseEnter:Fire()
	step(0.15)
	check(near(sv(card), 1.08, 1e-3) and card.ZIndex == 6, "G10 re-survol pendant le retour : × 1,08, ZIndex relevé")
	card.MouseLeave:Fire()
	step(0.2)
	check(card.ZIndex == 2 and scaleOf(card) == nil, "G11 puis retour : ZIndex 2, UIScale retiré")
	neighbour:Destroy()
end
do
	-- Grande carte : 8 px par bord (400 px de large → 1 + 16 / 400 = 1,04).
	local card = makeCard("BigCard", holder, 100, 100, 400, 300)
	Motion.HoverCard(card)
	card.MouseEnter:Fire()
	step(0.15)
	render290(card)
	local grown = card.AbsoluteSize.X - 400
	check(near(sv(card), 1.04, 1e-3) and near(grown, 16, 0.01), `G12 carte de 400 × 300 px : × {fmt(sv(card))}, + {fmt(grown / 2)} px par bord`)
	card.MouseLeave:Fire()
	step(0.2)
	-- Juste sous 250 px : × 1,08.
	local small = makeCard("SmallCard", holder, 100, 100, 249, 100)
	Motion.HoverCard(small)
	small.MouseEnter:Fire()
	step(0.15)
	check(near(sv(small), 1.08, 1e-3), `G13 carte de 249 px : × {fmt(sv(small))}`)
	small.MouseLeave:Fire()
	step(0.2)
end
do
	-- Dans une grille (layout) : grossit, n'est pas recentrée (le layout la place), ZIndex relevé puis rendu.
	local grid = new("ScrollingFrame", { Name = "Grid", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(W, H) }, holder)
	new("UIGridLayout", { Name = "UIGridLayout" }, grid)
	local a = makeCard("GridA", grid, 0, 0, 200, 200, 3)
	makeCard("GridB", grid, 210, 0, 200, 200, 3)
	Motion.HoverCard(a)
	a.MouseEnter:Fire()
	step(0.15)
	check(near(sv(a), 1.08, 1e-3) and not Motion.IsCentered(a) and a.ZIndex == 4, `G14 carte de grille : × 1,08, pas recentrée, ZIndex 4 ({a.ZIndex})`)
	a.MouseLeave:Fire()
	step(0.2)
	check(a.ZIndex == 3 and scaleOf(a) == nil, "G15 retour : ZIndex 3, UIScale retiré")
end
do
	-- Grow + IconHover = Jump : l'Icon saute (UiAttrFx), la carte grossit ; l'Icon revient exactement.
	local card, icon = makeCard("GrowJump", holder, 600, 100, 200, 200)
	card:SetAttribute("IconHover", "Jump")
	local rest = icon.Position
	UiAttrFx.Wire(card)
	Motion.HoverCard(card)
	card.MouseEnter:Fire()
	local top = 0
	for _ = 1, 45 do
		step(0.01)
		top = math.max(top, rest.Y.Offset - icon.Position.Y.Offset)
	end
	local height = icon.AbsoluteSize.Y * UiMotion.AttrFx.IconHover.Jump.Height
	check(near(top, height, 0.6) and near(sv(card), 1.08, 1e-3), `G16 Grow + Jump : l'Icon saute de {fmt(top)} px (attendu {fmt(height)}), la carte × 1,08`)
	card.MouseLeave:Fire()
	step(0.5)
	check(icon.Position == rest and scaleOf(icon) == nil and scaleOf(card) == nil, "G17 sortie : Icon et carte au repos")
end
do
	-- Une carte Pop ou sans attribut ne change pas (a286 et vague 59).
	local card, plainIcon = makeCard("PlainCard", holder, 100, 300, 200, 200)
	plainIcon:Destroy() -- le faux Roblox ne simule pas un tween de Position (comme a299, N1)
	card:SetAttribute("Hover", nil)
	Motion.HoverCard(card)
	card.MouseEnter:Fire()
	step(0.2)
	check(near(sv(card), UiMotion.Hover.CardTo, 1e-3) and card.ZIndex == 2, `G18 carte sans Grow : × {fmt(sv(card))} (CardTo), ZIndex inchangé`)
	card.MouseLeave:Fire()
	step(0.3)
end

---------------------------------------------------------------- S. IconHover = Spring
local crate = new("Frame", { Name = "Crate", AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(200, 200), Size = UDim2.fromOffset(200, 200), Visible = true }, holder)
crate:SetAttribute("IconHover", "Spring")
local before = UiAttrFx.GetState()
UiAttrFx.Wire(crate)
local after = UiAttrFx.GetState()
check(after.Springs == before.Springs + 1 and after.IconHovers == before.IconHovers and after.Running == true, `S1 Wire : 1 Spring suivi ({after.Springs}), aucune Icon demandée, boucle lancée`)
check(not logHas("IconHover = Spring", "PRINT"), "S2 plus de ligne « pas codé » en Studio")
local x0, y0, w0 = UiAttrFx.Spring(crate)
check(x0 == 0 and y0 == 0 and w0 == 0, "S3 sans survol : 0, 0, poids 0 (la caméra se balance comme avant)")
check(select(3, UiAttrFx.Spring(holder)) == 0, "S4 autre élément : poids 0")

crate.MouseEnter:Fire()
crate.InputChanged:Fire(input290("MouseMovement", 300, 200)) -- bord droit, au milieu
step(SPRING.Enter / 2)
local _, _, wHalf = UiAttrFx.Spring(crate)
step(1)
local x1, y1, w1 = UiAttrFx.Spring(crate)
check(wHalf > 0 and wHalf < 1, `S5 entrée : poids en route ({fmt(wHalf)} à Enter / 2)`)
check(w1 == 1 and near(x1, SPRING.Angle, 0.05) and near(y1, 0, 0.05), `S6 pointeur au bord droit : {fmt(x1)}°, {fmt(y1)}° (attendu {SPRING.Angle}, 0), poids 1`)
-- Le ressort dépasse un peu (amorti < 1) puis se pose : pointeur au bord bas gauche.
crate.InputChanged:Fire(input290("MouseMovement", 100, 300))
local minX, maxY = math.huge, -math.huge
for _ = 1, 60 do
	step(1 / 60)
	local x, y = UiAttrFx.Spring(crate)
	minX, maxY = math.min(minX, x), math.max(maxY, y)
end
local x2, y2 = UiAttrFx.Spring(crate)
check(minX < -SPRING.Angle and minX > -1.5 * SPRING.Angle, `S7 ressort amorti : dépasse un peu ({fmt(minX)}°) puis se pose`)
check(near(x2, -SPRING.Angle, 0.3) and near(y2, SPRING.Angle, 0.3), `S8 bord bas gauche : {fmt(x2)}°, {fmt(y2)}°`)
-- Pointeur dans le repère décalé de la barre du haut (36 px) : appris au premier point de chaque survol.
crate.MouseLeave:Fire()
local minW = math.huge
for _ = 1, 40 do
	step(0.01)
	minW = math.min(minW, select(3, UiAttrFx.Spring(crate)))
end
local _, _, wOut = UiAttrFx.Spring(crate)
check(minW < 0 and wOut == 0, `S9 sortie : retour Back Out en {SPRING.Back} s (poids au plus bas {fmt(minW)}, puis 0)`)
crate.MouseEnter:Fire()
crate.InputChanged:Fire(input290("MouseMovement", 200, 70)) -- 70 + 36 = 106 : dans la caisse, en haut
step(1.5)
local x3, y3 = UiAttrFx.Spring(crate)
check(near(x3, 0, 0.05) and near(y3, (106 - 200) / 100 * SPRING.Angle, 0.1), `S10 repère décalé de la barre du haut : appris ({fmt(x3)}°, {fmt(y3)}°)`)
crate.MouseLeave:Fire()
step(0.5)
-- Toucher (téléphone) : suivi pendant le toucher seulement ; MouseLeave pendant le toucher ignoré.
local touch = input290("Touch", 100, 200)
crate.InputBegan:Fire(touch)
crate.MouseLeave:Fire()
step(1)
local x4, _, w4 = UiAttrFx.Spring(crate)
check(w4 == 1 and near(x4, -SPRING.Angle, 0.1), `S11 toucher au bord gauche : {fmt(x4)}°, poids 1 (MouseLeave ignoré pendant le toucher)`)
crate.InputChanged:Fire(input290("Touch", 300, 200)) -- un autre doigt : ignoré
step(0.5)
check(near((UiAttrFx.Spring(crate)), -SPRING.Angle, 0.1), "S12 un autre toucher ne déplace rien")
crate.InputEnded:Fire(touch)
step(0.5)
check(select(3, UiAttrFx.Spring(crate)) == 0, "S13 fin du toucher : poids 0")
-- Écran éteint pendant le survol : retour au repos.
crate.MouseEnter:Fire()
step(0.5)
gui.Enabled = false
step(0.5)
check(select(3, UiAttrFx.Spring(crate)) == 0, "S14 écran éteint pendant le survol : poids 0")
crate.MouseEnter:Fire()
step(0.2)
check(select(3, UiAttrFx.Spring(crate)) == 0, "S15 écran éteint : un survol ne fait rien")
gui.Enabled = true

---------------------------------------------------------------- W. Branchement
local feel = SOURCES["client/Controllers/UiFeelController.luau"]
check(feel:find('hover == "Pop" or hover == "Grow"', 1, true) ~= nil, "W1 UiFeelController : un cadre Hover = Grow est une carte (Motion.HoverCard)")
local shop = SOURCES["client/Controllers/RobuxShopController.luau"]
check(shop:find("springOf(crate)", 1, true) ~= nil and shop:find('FindFirstChild("UiAttrFx")', 1, true) ~= nil,
	"W2 RobuxShopController lit UiAttrFx.Spring sur Crate (module facultatif)")

summary()
