---------------------------------------------------------------- scénario « pop » (a304, 21/11 : les cases poppent dès l'ouverture)
-- Après setup.luau du banc a50 ; tweens simulés dans le temps (ext-a189). Modules montés à part (Controllers304) :
-- Motion, Appear, HudMask, UiMotionController (comme le banc a212). Échantillonnage toutes les 1/120 s : échelle propre
-- de chaque case (son UIScale) et échelle vue (produit avec l'UIScale de la fenêtre et des cadres au-dessus).
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers304")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
local appearModule = moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseController304"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController304")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local Appear = requireModule(appearModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
Motion.SetSoundPlayer(function()
	return true
end)
step(0.1)

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end
	return nil
end
local function own(object)
	local s = scaleOf(object)
	return if s then s.Scale else 1
end
local function seen(object)
	local v = 1
	local o = object
	while o and not o:IsA("ScreenGui") do
		v *= own(o)
		o = o.Parent
	end
	return v
end
local function fmt(v)
	return string.format("%.3f", v)
end
local function screen(name)
	local gui = new("ScreenGui", { Name = name, Enabled = false })
	gui.Parent = playerGui
	return gui
end
local function rest(o)
	return { o.Position.X.Scale, o.Position.X.Offset, o.Position.Y.Scale, o.Position.Y.Offset, o.Size.X.Scale, o.Size.X.Offset, o.Size.Y.Scale, o.Size.Y.Offset, o.AnchorPoint.X, o.AnchorPoint.Y }
end
local function sameRest(a, b)
	for i = 1, #a do
		if math.abs(a[i] - b[i]) > 1e-9 then
			return false
		end
	end
	return true
end

-- Ouvre `gui` et suit `items` pendant `seconds` s : départ du pop = premier instant où l'échelle propre dépasse celle de l'ouverture, temps passé
-- avec une échelle (propre ou vue) entre 0,01 et 0,2, échelle propre juste après l'ouverture.
local DT = 1 / 120
local function follow(gui, items, seconds, during)
	local stats = {}
	for i, item in items do
		stats[i] = { start = nil, band = 0, bandSeen = 0, first = nil, max = 0 }
	end
	Motion.Open(gui)
	for i, item in items do
		stats[i].first = own(item)
	end
	local t = 0
	while t < seconds do
		if during then
			during(t)
		end
		step(DT)
		t += DT
		for i, item in items do
			local s, v = own(item), seen(item)
			local st = stats[i]
			if st.start == nil and scaleOf(item) ~= nil and s > st.first + 1e-6 then
				st.start = t
			end
			if s > 0.01 and s < 0.2 then
				st.band += DT
			end
			if v > 0.01 and v < 0.2 then
				st.bandSeen += DT
			end
			st.max = math.max(st.max, st.band, st.bandSeen)
		end
	end
	return stats
end
local function verdict(label, items, stats, starts, rests)
	local hidden, band, late, back = true, true, "", true
	local worst = 0
	for i, item in items do
		local st = stats[i]
		hidden = hidden and st.first == 0
		worst = math.max(worst, st.band, st.bandSeen)
		if st.band > 0.1 or st.bandSeen > 0.1 then
			band = false
		end
		local want = starts[i]
		if st.start == nil or st.start > want + 2 / 60 then
			late = late .. ` {item.Name} à {if st.start then fmt(st.start) else "jamais"} s (au plus {fmt(want)} + 2 images)`
		end
		if scaleOf(item) ~= nil or not sameRest(rest(item), rests[i]) then
			back = false
		end
	end
	check(hidden, `{label} : chaque case à l'échelle 0 dès l'ouverture`)
	check(band, `{label} : aucune case vue entre 0,01 et 0,2 plus de 0,1 s (pire : {fmt(worst)} s)`)
	check(late == "", `{label} : le pop part sans attente au-delà du décalage de cascade{late}`)
	check(back, `{label} : au repos, UIScale retiré, Position, Size et AnchorPoint de Clément`)
end

print("-- Valeurs")
local cas = UiMotion.Appear.Cascade
local st = UiMotion.OpenStagger
check(cas.From == 0 and cas.Start == 0 and st.From == 0 and st.Start == 0, "V1 Cascade et OpenStagger : From = 0 et Start = 0 (validé par Cantin, 21/11)")
check(cas.Gap == 0.022 and cas.Time == 0.13 and cas.Max == 8 and st.Gap == 0.022 and st.Time == 0.13 and st.Max == 8, "V2 ordre et rythme de la cascade gardés (22 ms entre deux, 0,13 s, 8 au plus)")
check(UiMotion.Appear.Blocks.From == 0 and UiMotion.Hover.Centered == true, "V3 blocs déjà à 0, survol centré d'a299 gardé")

print("-- Cascade (Appear)")
local gGui = screen("UI_T304Cards")
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, gGui)
local grid = new("Frame", { Name = "Cards", Size = UDim2.fromScale(1, 0.8) }, root)
grid:SetAttribute("Appear", "Cascade")
local cards, rests, starts = {}, {}, {}
for i = 10, 1, -1 do -- ordre de l'arbre à l'envers : de gauche à droite quand même
	cards[i] = new("Frame", { Name = "Card" .. i, AbsolutePosition = Vector2.new(100 * i, 200), Position = UDim2.new(0.1 * i, 3, 0.2, 0), Size = UDim2.fromScale(0.09, 0.5), AnchorPoint = Vector2.new(0, 0) }, grid)
end
for i = 1, 10 do
	rests[i] = rest(cards[i])
	starts[i] = (math.min(i, cas.Max) - 1) * cas.Gap
end
step(0.05)
verdict("K1 cascade de 10 cartes", cards, follow(gGui, cards, 0.8), starts, rests)
Motion.Close(gGui)
step(0.4)

print("-- Cascade, rang propre (Appear.SetCascade)")
local rGui = screen("UI_T304Rank")
local rroot = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, rGui)
local slots = new("Frame", { Name = "Odds", Size = UDim2.fromScale(1, 1) }, rroot)
slots:SetAttribute("Appear", "Cascade")
local odds, oRests, oStarts = {}, {}, {}
for i = 1, 6 do
	odds[i] = new("Frame", { Name = "Odd_" .. i, AbsolutePosition = Vector2.new(80 * i, 0), Position = UDim2.fromScale(0.15 * i, 0.5), Size = UDim2.fromScale(0.12, 0.3), AnchorPoint = Vector2.new(0.5, 0.5) }, slots)
	odds[i]:SetAttribute("Rank", i - 1)
	oRests[i] = rest(odds[i])
	oStarts[i] = (i - 1) * 0.033
end
Appear.SetCascade(slots, function(item)
	return item:GetAttribute("Rank") or 0
end, 0.033)
step(0.05)
verdict("K2 six cases d'une caisse (rang, 0,033 s)", odds, follow(rGui, odds, 0.8), oStarts, oRests)
Motion.Close(rGui)
step(0.4)

print("-- Cascade, cartes clonées après l'ouverture")
local lGui = screen("UI_T304Late")
local lroot = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, lGui)
local lgrid = new("Frame", { Name = "List", Size = UDim2.fromScale(1, 1) }, lroot)
lgrid:SetAttribute("Appear", "Cascade")
new("Frame", { Name = "Template", Visible = false }, lgrid)
step(0.05)
local late = {}
Motion.Open(lGui)
-- Trois lignes clonées 0,1 s après l'ouverture (données reçues) : elles entrent aussitôt, à 0 d'abord.
step(0.1)
for i = 1, 3 do
	late[i] = new("Frame", { Name = "Row" .. i, AbsolutePosition = Vector2.new(0, 60 * i), Position = UDim2.fromScale(0, 0.1 * i), Size = UDim2.fromScale(1, 0.1) }, lgrid)
end
local firstLate = own(late[1])
local tl, band, startL = 0, 0, nil
while tl < 0.6 do
	step(DT)
	tl += DT
	local s = own(late[3])
	if startL == nil and scaleOf(late[3]) ~= nil and s > 0 then
		startL = tl
	end
	if s > 0.01 and s < 0.2 then
		band += DT
	end
end
check(firstLate == 0 or scaleOf(late[1]) == nil, `K3 ligne clonée après l'ouverture : à 0 dès son arrivée ({fmt(firstLate)})`)
check(band <= 0.1 and startL ~= nil and startL <= 2 * cas.Gap + 2 / 60, `K4 ligne clonée : pop tout de suite (3e à {if startL then fmt(startL) else "jamais"} s, {fmt(band)} s entre 0,01 et 0,2)`)
check(scaleOf(late[1]) == nil and scaleOf(late[3]) == nil, "K5 lignes clonées : au repos, UIScale retirés")
Motion.Close(lGui)
step(0.4)

print("-- OpenStagger (Motion)")
local sGui = screen("UI_T304Stagger")
local sroot = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, sGui)
local hov, hRests, hStarts = {}, {}, {}
for i = 5, 1, -1 do
	hov[i] = new("Frame", { Name = "Item" .. i, AbsolutePosition = Vector2.new(100 * i, 200), Position = UDim2.new(0.15 * i, 0, 0.3, 4), Size = UDim2.fromScale(0.12, 0.4) }, sroot)
	new("Frame", { Name = "HoverOutline", Visible = false }, hov[i])
end
for i = 1, 5 do
	hRests[i] = rest(hov[i])
	hStarts[i] = (i - 1) * st.Gap + 1 / 60 -- ordre de lecture calculé à la fin de l'image
end
step(0.05)
-- OpenStagger pose ses UIScale à l'ouverture même : lu juste après Motion.Open.
verdict("K6 OpenStagger de 5 cartes", hov, follow(sGui, hov, 0.8), hStarts, hRests)
Motion.Close(sGui)
step(0.4)

print("-- Animations réduites")
P1:SetAttribute("VfxEnabled", false)
check(Appear.Reduced(), "R1 VISUAL EFFECTS sur OFF : Appear.Reduced()")
Motion.Open(gGui)
step(1 / 30)
local none = true
for _, c in cards do
	none = none and scaleOf(c) == nil
end
Motion.Open(sGui)
step(1 / 30)
for _, c in hov do
	none = none and scaleOf(c) == nil
end
check(none, "R2 animations réduites : cases là d'un coup, aucun UIScale")
Motion.Close(gGui)
Motion.Close(sGui)
step(1 / 30)
P1:SetAttribute("VfxEnabled", true)
step(0.5)
summary()
