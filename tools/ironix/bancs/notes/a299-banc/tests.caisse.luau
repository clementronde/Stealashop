---------------------------------------------------------------- scénario « caisse » (a299, 21/11 : objets de la caisse fixes)
-- Après la tête du banc a209 (modules montés, aides, buildShop) : la boucle de la caisse sur 4,5 s, image par image.
-- K1 réglage ; K2 à K6 cases, leur contenu, RarityGlow et Star fixes en Y ; K7 à K11 le reste bouge toujours ;
-- K12 à K14 fermeture, « Réduire les mouvements », effets coupés : tout à la place de Clément.
-- BOB0 = true (partie « caisse-bob0 ») : Config/ShopFx.Crate.Bob mis à 0 avant le require : la caisse (Icon) est
-- figée aussi, la secousse reste.
print("-- Caisse a299" .. (if BOB0 then " (Bob = 0)" else ""))
check(ShopFx.Crate.OddBob == 0, `K1 Config/ShopFx.Crate.OddBob = 0 ({ShopFx.Crate.OddBob})`)
local okPose = true
for k = 0, 80 do
	local pose = CrateLoop.Sample(k * 0.05)
	for n = 1, 6 do
		if pose.OddY[n] ~= 0 then
			okPose = false
		end
	end
end
check(okPose, "K1b CrateLoop.Sample : OddY = 0 pour les 6 cases, toute la boucle")

local shop = buildShop("UI_RobuxShop_v2")
step(0.05)
local crate = shop.Root.Window.List.Content.Crate
local odds = crate.Odds
local icon, rays, glow = crate.Icon, crate.Backdrop.Rays, crate.Backdrop.Glow
local cells, stars, rarity, inner = {}, {}, {}, {}
for _, c in odds:GetChildren() do
	if string.match(c.Name, "^Odd_") then
		cells[tonumber(string.sub(c.Name, 5))] = c
	elseif c.Name == "Star" then
		table.insert(stars, c)
	elseif c.Name == "RarityGlow" then
		table.insert(rarity, c)
	end
end
-- Contenu des cases, comme dans Studio : un Icon (ImageLabel) par case, AnchorPoint (0, 0).
for n, c in cells do
	inner[n] = new("ImageLabel", { Name = "Icon", Position = UDim2.fromScale(-0.026, -0.123), Size = UDim2.fromScale(1, 1) }, c)
end
local function centerY(o)
	return o.Position.Y.Scale + o.Size.Y.Scale * 0.5, o.Position.Y.Offset + o.Size.Y.Offset * 0.5
end
local rest = {}
for _, o in { icon, rays, glow, table.unpack(stars) } do
	rest[o] = { Position = o.Position, Size = o.Size, Rotation = o.Rotation }
end
for _, o in rarity do
	rest[o] = { Position = o.Position, Size = o.Size, T = o.ImageTransparency }
end
for n, c in cells do
	rest[c] = { Position = c.Position, Size = c.Size, AnchorPoint = c.AnchorPoint }
	rest[inner[n]] = { Position = inner[n].Position, Size = inner[n].Size }
end

shop.Enabled = true
step(1 / 30)
check(CrateLoop.IsMoving(shop), "K2 écran allumé : la boucle tourne")
local cellMoved, innerMoved, starY, glowY = 0, 0, 0, 0
local starMin, starMax = math.huge, -math.huge
local tMin, tMax = math.huge, -math.huge
local raysMin, raysMax = math.huge, -math.huge
local iconYMin, iconYMax = math.huge, -math.huge
local iconRotMax = 0
local cascade = false
for _ = 1, 135 do -- 4,5 s
	step(1 / 30)
	for n, c in cells do
		if c.Position ~= rest[c].Position or c.Size ~= rest[c].Size or c.AnchorPoint ~= rest[c].AnchorPoint then
			cellMoved += 1
		end
		if inner[n].Position ~= rest[inner[n]].Position or inner[n].Size ~= rest[inner[n]].Size then
			innerMoved += 1
		end
		for _, ch in c:GetChildren() do
			if ch:IsA("UIScale") then
				cascade = true
			end
		end
	end
	for _, s in stars do
		local ys, yo = centerY(s)
		local bs, bo = centerY(rest[s])
		if not near(ys, bs, 1e-9) or not near(yo, bo, 1e-9) then
			starY += 1
		end
		local w = s.Size.X.Scale / rest[s].Size.X.Scale
		starMin, starMax = math.min(starMin, w), math.max(starMax, w)
	end
	for _, r in rarity do
		local ys, yo = centerY(r)
		local bs, bo = centerY(rest[r])
		if not near(ys, bs, 1e-9) or not near(yo, bo, 1e-9) then
			glowY += 1
		end
		tMin, tMax = math.min(tMin, r.ImageTransparency), math.max(tMax, r.ImageTransparency)
	end
	raysMin, raysMax = math.min(raysMin, rays.Rotation), math.max(raysMax, rays.Rotation)
	iconYMin, iconYMax = math.min(iconYMin, icon.Position.Y.Offset), math.max(iconYMax, icon.Position.Y.Offset)
	iconRotMax = math.max(iconRotMax, math.abs(icon.Rotation - rest[icon].Rotation))
end
check(cellMoved == 0, `K3 Odd_1 à Odd_6 : Position, Size et AnchorPoint jamais écrits pendant 4,5 s ({cellMoved} écart(s))`)
check(innerMoved == 0, `K4 contenu des cases (Icon) : jamais déplacé ({innerMoved} écart(s))`)
check(starY == 0, `K5 Star : centre fixe en Y ({starY} écart(s))`)
check(glowY == 0, `K6 RarityGlow : centre fixe en Y ({glowY} écart(s))`)
check(starMin < 0.5 and starMax > 1.2, `K7 Star clignotent toujours (× {string.format("%.2f", starMin)} à × {string.format("%.2f", starMax)})`)
check(tMax - tMin > 0.1, `K8 RarityGlow pulse toujours (transparence de {string.format("%.2f", tMin)} à {string.format("%.2f", tMax)})`)
check(raysMax - raysMin > 30, `K9 Rays tournent toujours ({string.format("%.1f", raysMin)}° à {string.format("%.1f", raysMax)}°)`)
check(cascade, "K9b entrée en cascade des cases (UIScale de l'ouverture) toujours là")
if BOB0 then
	check(iconYMin == rest[icon].Position.Y.Offset and iconYMax == rest[icon].Position.Y.Offset, `K10 Bob = 0 : la caisse (Icon) ne monte ni ne descend ({iconYMin} à {iconYMax})`)
else
	check(iconYMin < rest[icon].Position.Y.Offset - 5 and iconYMax > rest[icon].Position.Y.Offset + 5, `K10 la caisse (Icon) monte et descend toujours (Bob = 7 : {string.format("%.1f", iconYMin)} à {string.format("%.1f", iconYMax)})`)
end
check(iconRotMax > 1, `K11 la secousse de la caisse reste ({string.format("%.1f", iconRotMax)}°)`)

local function allAtRest()
	for n, c in cells do
		if c.Position ~= rest[c].Position or inner[n].Position ~= rest[inner[n]].Position then
			return false
		end
	end
	for _, o in { icon, rays, glow, table.unpack(stars) } do
		if o.Position ~= rest[o].Position or o.Size ~= rest[o].Size or o.Rotation ~= rest[o].Rotation then
			return false
		end
	end
	for _, r in rarity do
		if r.Position ~= rest[r].Position or r.Size ~= rest[r].Size or r.ImageTransparency ~= rest[r].T then
			return false
		end
	end
	return true
end
FAKE_GUISERVICE.ReducedMotionEnabled = true
step(0.6)
check(not CrateLoop.IsMoving(shop) and allAtRest(), "K12 « Réduire les mouvements » : pas de boucle, tout à la place de Clément")
FAKE_GUISERVICE.ReducedMotionEnabled = false
step(0.6)
check(CrateLoop.IsMoving(shop), "K13 réglage retiré : la boucle reprend")
P1:SetAttribute(Settings.VfxAttribute, false)
step(0.6)
check(not CrateLoop.IsMoving(shop) and allAtRest(), "K14 effets visuels coupés : tout à la place de Clément")
P1:SetAttribute(Settings.VfxAttribute, true)
step(0.6)
shop.Enabled = false
step(0.6)
check(not CrateLoop.IsMoving(shop) and allAtRest(), "K15 écran fermé : tout à la place de Clément")
summary()
