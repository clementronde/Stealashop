---------------------------------------------------------------- scénario « motion » : le module UI/Motion seul
local Motion = requireModule(MOTION_MODULE, "client")
local OPEN_FROM, OPEN_TIME = UiMotionC.Open.From, UiMotionC.Open.Time
local CLOSE_TO, CLOSE_TIME = UiMotionC.Close.To, UiMotionC.Close.Time
local SHOW_FROM, SHOW_TIME = UiMotionC.Show.From, UiMotionC.Show.Time
local HIDE_TIME = UiMotionC.Hide.Time
local ROLL_TIME = UiMotionC.Roll.Time

-- Un écran comme UI_WeaponShop de Clément (arbre lu dans Studio le 2026-11-08) : un cadre racine
-- Root centré (0,5 ; 0,5), 1 × 0,72 en Scale, avec ses contraintes, une fenêtre et ses enfants ;
-- plus, pour les cas particuliers, un voile plein écran et un badge qui a son propre UIScale.
local function makeShop(name, enabled)
	local gui = new("ScreenGui", { Name = name, Enabled = enabled, ResetOnSpawn = false })
	local root = new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.72),
		BackgroundTransparency = 1,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1.9 }, root)
	new("UISizeConstraint", {}, root)
	local window = new("Frame", {
		Name = "Window",
		Position = UDim2.fromScale(0.02, 0.045),
		Size = UDim2.fromScale(0.961, 0.904),
		BackgroundColor3 = Color3.fromRGB(28, 30, 44),
	}, root)
	new("UICorner", {}, window)
	new("UIStroke", { Thickness = 3.7 }, window)
	new("TextButton", { Name = "CloseButton", Text = "X", Size = UDim2.fromScale(0.08, 0.12) }, window)
	local list = new("Frame", { Name = "List", Size = UDim2.fromScale(0.9, 0.7) }, window)
	new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromScale(1, 0.2) }, list)
	local veil = new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.4 }, gui)
	local badge = new("Frame", { Name = "Badge", Position = UDim2.fromScale(0.9, 0.1), Size = UDim2.fromScale(0.1, 0.1) }, gui)
	local own = new("UIScale", { Name = "UIScale", Scale = 0.8 }, badge)
	gui.Parent = PLAYER_GUI
	return gui, root, veil, badge, own
end

local shop, root, veil, badge, badgeScale = makeShop("UI_WeaponShop", false)
local shopSnap = snapshot(shop)
local function shopUntouched(label)
	local ok, why = sameAs(shopSnap, shop, { [shop] = { Enabled = true } })
	check(ok, `{label} ({why})`)
end

print("\n== M1. Ouverture")
clearLog()
Motion.Open(shop)
local scale = motionScale(root)
check(shop.Enabled == true and Motion.GetState(shop) == "Opening", "M1a Open : écran allumé tout de suite, état Opening")
check(scale ~= nil and scale.Scale == OPEN_FROM, `M1b UIScale « {UiMotionC.ScaleName} » créé sur Root, à {OPEN_FROM}`)
check(countClass(veil, "UIScale") == 0, "M1c voile plein écran (1 × 1) : pas mis à l'échelle")
check(countClass(badge, "UIScale") == 1 and badgeScale.Scale == 0.8 and motionScale(badge) == nil, "M1d badge avec son propre UIScale : rien ajouté, son UIScale intact (0,8)")
check(countLog("UI_WeaponShop.Badge a déjà un UIScale") == 1, "M1e une ligne dans la sortie (Studio) pour le badge")
local values = watchScale(root, OPEN_TIME + 0.1)
local maxScale, minScale, ended = 0, 2, nil
for i, v in values do
	if v then
		maxScale = math.max(maxScale, v)
		minScale = math.min(minScale, v)
	elseif ended == nil then
		ended = i
	end
end
check(maxScale > 1 and maxScale < 1.05 and minScale >= OPEN_FROM - 1e-9, `M1f léger rebond : l'échelle monte de {OPEN_FROM} à {string.format("%.3f", maxScale)}, puis revient à 1`)
check(ended ~= nil and ended >= 7 and ended <= 9, `M1g UIScale retiré à la fin de l'animation ({OPEN_TIME} s : image {ended})`)
check(Motion.GetState(shop) == "Open" and shop.Enabled and motionScale(root) == nil, "M1h écran ouvert, plus aucun UIScale du code")
shopUntouched("M1i aucune propriété de Clément changée, aucun objet laissé")

print("\n== M2. Ouvrir un écran déjà ouvert")
local created = TWEEN_STATS.created
Motion.Open(shop)
check(Motion.GetState(shop) == "Open" and motionScale(root) == nil and TWEEN_STATS.created == created, "M2 rien ne se passe (pas de tween, pas de UIScale)")
check(countLog("UI_WeaponShop.Badge a déjà un UIScale") == 1, "M2b la ligne du badge n'est écrite qu'une fois")

print("\n== M3. Fermeture")
local closedCalls = 0
Motion.Close(shop, function()
	closedCalls += 1
end)
scale = motionScale(root)
check(shop.Enabled and Motion.GetState(shop) == "Closing" and scale ~= nil and scale.Scale == 1, "M3a Close : écran encore allumé, état Closing, UIScale à 1")
step(0.06)
scale = motionScale(root)
check(shop.Enabled and scale ~= nil and scale.Scale < 1 and scale.Scale > CLOSE_TO and closedCalls == 0, `M3b à 0,06 s : sortie en cours (échelle {scale and string.format("%.3f", scale.Scale)}), suite pas encore appelée`)
step(CLOSE_TIME)
check(shop.Enabled == false and Motion.GetState(shop) == "Closed" and motionScale(root) == nil, "M3c fin de la sortie : écran éteint, UIScale retiré")
check(closedCalls == 1, "M3d la suite (after) est appelée une fois")
shopUntouched("M3e aucune propriété de Clément changée")

print("\n== M4. Fermer un écran déjà fermé")
local calls4 = 0
created = TWEEN_STATS.created
Motion.Close(shop, function()
	calls4 += 1
end)
check(calls4 == 1 and shop.Enabled == false and TWEEN_STATS.created == created, "M4 fermé tout de suite : suite appelée aussitôt, aucun tween")

print("\n== M5. Réouverture pendant la fermeture")
Motion.Open(shop)
step(OPEN_TIME + 0.05)
local calls5 = 0
Motion.Close(shop, function()
	calls5 += 1
end)
step(0.06)
local mid = motionScale(root)
local midValue = mid and mid.Scale
local cancelled = TWEEN_STATS.cancelled
Motion.Open(shop)
local again = motionScale(root)
check(Motion.GetState(shop) == "Opening" and shop.Enabled, "M5a Open pendant Closing : état Opening, écran resté allumé")
check(again ~= nil and again == mid and again.Scale == midValue, `M5b l'échelle repart d'où elle était ({string.format("%.3f", midValue or -1)}), sans saut à {OPEN_FROM}`)
check(TWEEN_STATS.cancelled == cancelled + 1, "M5c le tween de sortie est annulé (Completed(Cancelled) ignoré)")
step(OPEN_TIME + 0.05)
check(Motion.GetState(shop) == "Open" and shop.Enabled and motionScale(root) == nil, "M5d revenu à 1 : ouvert, plus de UIScale")
step(1)
check(calls5 == 0 and shop.Enabled, "M5e la suite de la fermeture annulée n'est jamais appelée")
shopUntouched("M5f aucune propriété de Clément changée")

print("\n== M6. Fermeture pendant l'ouverture")
Motion.Close(shop)
step(CLOSE_TIME + 0.05)
check(shop.Enabled == false, "M6a fermé")
Motion.Open(shop)
step(0.05)
local s6 = motionScale(root)
local v6 = s6 and s6.Scale
Motion.Close(shop)
check(Motion.GetState(shop) == "Closing" and motionScale(root) == s6 and s6 and s6.Scale == v6, "M6b Close pendant Opening : sortie depuis l'échelle du moment")
step(CLOSE_TIME + 0.05)
check(shop.Enabled == false and Motion.GetState(shop) == "Closed" and motionScale(root) == nil, "M6c fermé, UIScale retiré")
shopUntouched("M6d aucune propriété de Clément changée")
check(calls5 == 0, "M6e la suite annulée en M5 ne ressort pas aux fermetures suivantes")

print("\n== M7. Écran allumé sans Motion (copie de StarterGui arrivée allumée)")
local lit = makeShop("UI_Lit", true)
local litRoot = el(lit, "Root")
local calls7 = 0
created = TWEEN_STATS.created
Motion.Close(lit, function()
	calls7 += 1
end)
check(lit.Enabled == false and Motion.GetState(lit) == "Closed" and motionScale(litRoot) == nil and TWEEN_STATS.created == created, "M7a Close : éteint d'un coup, sans animation")
check(calls7 == 1, "M7b suite appelée aussitôt")
local lit2 = makeShop("UI_Lit2", true)
created = TWEEN_STATS.created
Motion.Open(lit2)
check(lit2.Enabled and Motion.GetState(lit2) == "Open" and motionScale(el(lit2, "Root")) == nil and TWEEN_STATS.created == created, "M7c Open sur un écran déjà allumé : pas d'entrée animée (déjà visible), il compte comme ouvert")
Motion.Close(lit2)
check(lit2.Enabled and Motion.GetState(lit2) == "Closing", "M7d puis Close : sortie animée, comme un écran ouvert par Motion")
step(CLOSE_TIME + 0.05)
check(lit2.Enabled == false and motionScale(el(lit2, "Root")) == nil, "M7e éteint au bout de la sortie")

print("\n== M8. Écran détruit ou hors du jeu")
local gone = makeShop("UI_Gone", false)
Motion.Open(gone)
step(0.05)
gone:Destroy()
local ok8 = pcall(function()
	Motion.Close(gone)
	step(0.3)
end)
check(ok8 and gone.Enabled == false and Motion.GetState(gone) == "Closed", "M8a écran détruit pendant l'ouverture : Close sans erreur, éteint")
local loose = new("ScreenGui", { Name = "UI_Loose", Enabled = false })
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, loose)
Motion.Open(loose)
check(loose.Enabled and motionScale(el(loose, "Root")) == nil and Motion.GetState(loose) == "Open", "M8b écran sans parent : allumé, sans animation")

print("\n== M9. Éléments (Show / Hide), comme HeistTimer et GuardMeter")
local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
local timer = new("TextLabel", {
	Name = "HeistTimer",
	Text = "HEIST: 7s",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.04),
	Size = UDim2.fromScale(0.24, 0.066),
}, hud)
new("UIStroke", { Thickness = 3 }, timer)
local meter = new("Frame", { Name = "GuardMeter", Visible = false, Size = UDim2.fromScale(0.267, 0.026) }, hud)
new("Frame", { Name = "Fill", Size = UDim2.new(0.6, 0, 1, 0) }, meter)
local styled = new("Frame", { Name = "Styled", Visible = false, Size = UDim2.fromScale(0.2, 0.1) }, hud)
local styledScale = new("UIScale", { Name = "Pop", Scale = 1.2 }, styled)
hud.Parent = PLAYER_GUI
local hudSnap = snapshot(hud)

Motion.Show(timer)
local ts = motionScale(timer)
check(timer.Visible and Motion.GetState(timer) == "Opening" and ts ~= nil and ts.Scale == SHOW_FROM, `M9a Show : visible tout de suite, UIScale à {SHOW_FROM}`)
step(SHOW_TIME + 0.05)
check(Motion.GetState(timer) == "Open" and motionScale(timer) == nil and timer.Visible, "M9b apparu : UIScale retiré")
Motion.Hide(timer)
step(0.05)
check(timer.Visible and Motion.GetState(timer) == "Closing" and motionScale(timer) ~= nil, "M9c Hide : encore visible pendant la sortie")
step(HIDE_TIME)
check(timer.Visible == false and Motion.GetState(timer) == "Closed" and motionScale(timer) == nil, "M9d disparu : Visible = false, UIScale retiré")
Motion.Show(timer)
step(0.1)
Motion.Hide(timer)
step(0.04)
Motion.Show(timer)
check(timer.Visible and Motion.GetState(timer) == "Opening", "M9e Show pendant Hide : il revient, sans disparaître")
step(SHOW_TIME + 0.05)
check(timer.Visible and Motion.GetState(timer) == "Open" and motionScale(timer) == nil, "M9f apparu pour de bon")
created = TWEEN_STATS.created
Motion.Hide(meter)
check(meter.Visible == false and TWEEN_STATS.created == created, "M9g Hide d'un élément déjà caché : rien")
-- Visible coupé par un autre code pendant l'apparition : pas d'état bloqué.
Motion.Show(meter)
step(0.05)
meter.Visible = false
step(SHOW_TIME)
Motion.Show(meter)
check(meter.Visible and Motion.GetState(meter) == "Opening", "M9h caché par un autre code pendant l'apparition : un Show suivant le remontre")
step(SHOW_TIME + 0.05)
Motion.Hide(meter)
step(HIDE_TIME + 0.05)
check(meter.Visible == false and motionScale(meter) == nil, "M9i puis Hide : caché, UIScale retiré")
-- Élément qui a déjà son propre UIScale : pas d'échelle, il apparaît d'un coup.
created = TWEEN_STATS.created
Motion.Show(styled)
check(styled.Visible and Motion.GetState(styled) == "Open" and TWEEN_STATS.created == created, "M9j élément avec son UIScale : visible d'un coup, sans tween")
Motion.Hide(styled)
check(styled.Visible == false and styledScale.Scale == 1.2 and countClass(styled, "UIScale") == 1, "M9k caché d'un coup, son UIScale intact (1,2)")
local okHud, whyHud = sameAs(hudSnap, hud, {
	[timer] = { Visible = true },
	[meter] = { Visible = true },
	[styled] = { Visible = true },
})
check(okHud, `M9l aucune propriété de Clément changée hors Visible ({whyHud})`)

print("\n== R. Chiffres qui défilent")
local cash = new("TextLabel", { Name = "Cash", Text = "$11.1B", Size = UDim2.fromScale(0.3, 0.1) }, hud)
local money = FormatC.money
created = TWEEN_STATS.created
Motion.Roll(cash, nil, 1500, money)
check(cash.Text == "$1.5K" and TWEEN_STATS.created == created, "R1 premier remplissage : « $1.5K » tout de suite, sans défilement")
Motion.Roll(cash, nil, 100, money)
check(cash.Text == "$100", "R1b premier remplissage (from = nil) : toujours d'un coup")
Motion.Roll(cash, 100, 150, money)
check(cash.Text == "$100", "R2a juste après Roll : rien n'a encore bougé (le tween avance à l'image suivante)")
local seen = watchTexts(cash, ROLL_TIME + 0.1)
local integers, rising = true, true
for i, text in seen do
	if string.find(text, "%.") then
		integers = false
	end
	if i > 1 and parseMoney(text) < parseMoney(seen[i - 1]) then
		rising = false
	end
end
check(#seen >= 6 and seen[2] ~= "$150", `R2b le nombre défile : {#seen} valeurs ({table.concat(seen, " ", 1, math.min(#seen, 6))} …)`)
check(integers and rising, "R2c deux bouts entiers : que des entiers, toujours croissants")
check(cash.Text == "$150", "R2d valeur finale exacte : « $150 »")
check(ACTIVE_TWEENS() == 0, "R2e plus aucun tween en cours")

local income = new("TextLabel", { Name = "Income", Text = "+$1.2K/s" }, hud)
Motion.Roll(income, nil, 1.5, FormatC.income)
Motion.Roll(income, 1.5, 3.5, FormatC.income)
step(ROLL_TIME + 0.05)
check(income.Text == "+$3.5/s", "R3 bouts décimaux : valeur finale exacte « +$3.5/s »")

Motion.Roll(cash, nil, 5000, money)
Motion.Roll(cash, 5000, 1000, money)
seen = watchTexts(cash, ROLL_TIME + 0.1)
local falling = true
for i = 2, #seen do
	if parseMoney(seen[i]) > parseMoney(seen[i - 1]) then
		falling = false
	end
end
check(falling and #seen >= 4 and cash.Text == "$1K", `R4 baisse : le nombre descend ({seen[2]}…) jusqu'à « $1K »`)

Motion.Roll(cash, nil, 0, money)
Motion.Roll(cash, 0, 1000, money)
step(0.2)
local before = parseMoney(cash.Text)
Motion.Roll(cash, 1000, 2000, money)
step(1 / 30)
local after = parseMoney(cash.Text)
check(before > 300 and before < 1000 and after > before and after < 1000, `R5a nouvelle valeur en plein défilement : repart du nombre affiché ({before} puis {after}), sans saut à 1000`)
step(ROLL_TIME)
check(cash.Text == "$2K", "R5b puis arrive exactement à « $2K »")

Motion.Roll(cash, nil, 0, money)
Motion.Roll(cash, 0, 1000, money)
step(0.2)
created = TWEEN_STATS.created
Motion.Roll(cash, 0, 1000, money)
check(TWEEN_STATS.created == created, "R6a même valeur visée en plein défilement : pas de nouveau tween")
step(ROLL_TIME - 0.2 + 0.05)
check(cash.Text == "$1K", "R6b arrivée à l'heure prévue, « $1K »")

Motion.Roll(cash, nil, 0, money)
Motion.Roll(cash, 0, 1000, money)
step(0.2)
local frozen = cash.Text
Motion.StopRoll(cash)
step(1)
check(cash.Text == frozen and ACTIVE_TWEENS() == 0, `R7 StopRoll : le texte reste « {frozen} », plus de tween`)

Motion.Roll(cash, nil, 11.1e9, money)
created = TWEEN_STATS.created
Motion.Roll(cash, 11.1e9, 11.12e9, money)
check(cash.Text == "$11.1B" and TWEEN_STATS.created == created, "R8 même texte au départ et à l'arrivée : écrit d'un coup, sans tween")

local values0 = 0
for _, inst in ALL do
	if inst.ClassName == "NumberValue" and not rawget(inst, "_destroyed") then
		values0 += 1
	end
end
check(values0 == 0, "R9 aucun NumberValue laissé (détruits en fin de défilement ou à l'arrêt)")

summary()
