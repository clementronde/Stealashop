--!nocheck
-- Banc a312, partie « roue », sur le harnais du banc a266 (faux Roblox d'a53, vrai WheelController, écran gris UI_Wheel
-- de setup266). Play f92 : à partir du 2e tour d'une session, la roue s'arrêtait sur un autre secteur que le lot gagné
-- (5 MIN CASH gagné, arrêt sur 15 MIN CASH) : l'AbsolutePosition des segments suit la rotation de la roue, et l'ancien
-- targetRotation prenait l'angle à l'écran (rotation comprise) pour l'angle de la mise en page.
-- Ici, le faux écran a de vraies AbsolutePosition / AbsoluteSize, recalculées avant chaque tour comme Roblox : segment i
-- au centre de la roue + 150 px à l'angle (mise en page θi + Wheel.Rotation). Mise en page de Clément décalée de 10°
-- (θi = -80 + (i - 1) × 45) pour que le repli « Segment_01 en haut » ne puisse pas passer pour juste.
-- Le tirage du jitter (rng:NextNumber du contrôleur) est forcé à 0 puis à 1 : l'écart au centre du secteur va au
-- maximum des deux côtés (± Wheel.Jitter × demi-secteur).
-- R1 : rotation de départ 0, 37, 200, 359, et 1837 (après 5 tours) ; chaque secteur 1 à 8, jitter mini et maxi : la roue
--      finit avec le secteur gagné sous Pointer, à l'écart attendu exactement, au moins Turns tours plus loin.
-- R2 : 6 tours de suite sans remise à zéro (secteurs 1, 5, 3, 8, 2, 6, comme une session) : chaque arrêt est juste.
-- R3 : Pointer à droite de la roue (angle 0) au lieu d'en haut, départ 200.
-- R4 : sans mise en page lisible (pas d'AbsolutePosition : le repli) et cadre plein tourné (segments centrés sur la
--      roue, angle pris dans leur Rotation), départ 200 : arrêts justes (déjà justes avant a312).
advance(1000)
startServer()
wheelTest("days 10")
local ada = join("Ada", newProfile8(), 71)
advance(1.5)
buildUi(ada)
buildQuestUi(ada)
startClient(ada)
advance(0.5)
local WC = clientModule("WheelController")
WC.Open()
advance(0.3)
check(WC.GetState().Open, "roue ouverte")

local count = #Wheel.Sectors
local HALF = 180 / count
local JMAX = Wheel.Jitter * HALF
local wheel = QUI.wheel
local pointer = QUI.wheelGui:FindFirstChild("Window"):FindFirstChild("Pointer")
local remote = ReplicatedStorage:FindFirstChild("WheelResult", true)
check(remote ~= nil and pointer ~= nil and count == 8, `remote WheelResult, Pointer, {count} secteurs`)

local CX, CY, RADIUS, SEG = 500, 300, 150, 60
local LAYOUT0 = -80
local function layout(i)
	return LAYOUT0 + (i - 1) * 360 / count
end
local pointerAngle = -90
local function placePointer(angle)
	pointerAngle = angle
	local r = math.rad(angle)
	pointer.AbsoluteSize = Vector2.new(20, 20)
	pointer.AbsolutePosition = Vector2.new(CX + 230 * math.cos(r) - 10, CY + 230 * math.sin(r) - 10)
end
-- Comme Roblox : la position à l'écran d'un segment suit la rotation de la roue.
local mode = "positions"
local function place()
	wheel.AbsoluteSize = Vector2.new(400, 400)
	wheel.AbsolutePosition = Vector2.new(CX - 200, CY - 200)
	local rot = wheel.Rotation or 0
	for i = 1, count do
		local seg = QUI.segments[i]
		if mode == "positions" then
			local a = math.rad(layout(i) + rot)
			seg.AbsoluteSize = Vector2.new(SEG, SEG)
			seg.AbsolutePosition = Vector2.new(CX + RADIUS * math.cos(a) - SEG / 2, CY + RADIUS * math.sin(a) - SEG / 2)
			seg.Rotation = 0
		elseif mode == "full" then
			-- cadre plein : centré sur la roue (la rotation de la roue ne déplace pas son centre), angle = -90 + Rotation
			seg.AbsoluteSize = Vector2.new(400, 400)
			seg.AbsolutePosition = Vector2.new(CX - 200, CY - 200)
			seg.Rotation = layout(i) + 90
		else -- pas de mise en page lisible
			seg.AbsoluteSize = nil
			seg.AbsolutePosition = nil
			seg.Rotation = 0
		end
	end
end
local function layoutFor(i)
	if mode == "none" then
		return -90 + (i - 1) * 360 / count -- repli : Segment_01 en haut, sens horaire
	end
	return layout(i)
end
local function wrap(a)
	return (a + 180) % 360 - 180
end

local RMT = getmetatable(Random.new(1))
local realNext = RMT.NextNumber
-- Un tour : WheelResult(index, "") reçu par le client (le serveur a déjà décidé et donné le lot), jitter forcé.
local function spinTo(index, forced)
	place()
	local start = (wheel.Rotation or 0) % 360
	RMT.NextNumber = function(self, a, b)
		if a ~= nil then
			return a + forced * (b - a)
		end
		return forced
	end
	remote:FireClient(ada, index, "")
	RMT.NextNumber = realNext
	advance(Wheel.SpinSeconds + 0.1)
	local final = wheel.Rotation or 0
	local jitter = (forced * 2 - 1) * JMAX
	local offset = wrap(layoutFor(index) + final - pointerAngle) -- écart du centre du secteur à Pointer
	-- secteur réellement sous Pointer : celui dont le centre en est le plus près
	local under, best = nil, math.huge
	for i = 1, count do
		local d = math.abs(wrap(layoutFor(i) + final - pointerAngle))
		if d < best then
			under, best = i, d
		end
	end
	local turns = final - start
	local ok = under == index and math.abs(offset - jitter) < 1e-6 and turns >= Wheel.Turns * 360 - 1e-6 and turns < (Wheel.Turns + 1) * 360
	return ok, `arrêt {string.format("%.2f", final)} : secteur {under} sous Pointer (attendu {index}), écart {string.format("%.2f", offset)} (attendu {string.format("%.2f", jitter)}), {string.format("%.1f", turns / 360)} tours`
end

section("R1 : départ 0, 37, 200, 359, 1837 ; secteurs 1 à 8 ; jitter mini et maxi")
placePointer(-90)
for _, start in { 0, 37, 200, 359, 1837 } do
	local bad = {}
	for index = 1, count do
		for _, forced in { 0, 1 } do
			wheel.Rotation = start
			local ok, text = spinTo(index, forced)
			if not ok then
				table.insert(bad, `secteur {index}, jitter {if forced == 0 then "-" else "+"} : {text}`)
			end
		end
	end
	check(#bad == 0, `départ {start} : {2 * count - #bad}/{2 * count} arrêts justes{if #bad > 0 then " ; " .. table.concat(bad, " | ", 1, math.min(#bad, 3)) else ""}`)
end

section("R2 : 6 tours de suite, comme une session")
wheel.Rotation = 0
local chain = { { 1, 1 }, { 5, 0 }, { 3, 1 }, { 8, 0 }, { 2, 1 }, { 6, 0 } }
for n, step in chain do
	local before = wheel.Rotation
	local ok, text = spinTo(step[1], step[2])
	check(ok, `tour {n} (départ {string.format("%.2f", before)}) : {text}`)
end

section("R3 : Pointer à droite (angle 0)")
placePointer(0)
do
	local bad = 0
	for index = 1, count do
		for _, forced in { 0, 1 } do
			wheel.Rotation = 200
			local ok = spinTo(index, forced)
			if not ok then
				bad += 1
			end
		end
	end
	check(bad == 0, `départ 200, Pointer à droite : {2 * count - bad}/{2 * count} arrêts justes`)
end
placePointer(-90)

section("R4 : repli sans mise en page, cadre plein tourné")
for _, m in { "none", "full" } do
	mode = m
	local bad = 0
	for index = 1, count do
		for _, forced in { 0, 1 } do
			wheel.Rotation = 200
			local ok = spinTo(index, forced)
			if not ok then
				bad += 1
			end
		end
	end
	check(bad == 0, `{if m == "none" then "repli (Segment_01 en haut)" else "cadre plein tourné"}, départ 200 : {2 * count - bad}/{2 * count} arrêts justes`)
end
mode = "positions"
check(logCount("[WheelController]", "WARN") == 0, "aucun avertissement de WheelController")
summary("scénario a312roue")
