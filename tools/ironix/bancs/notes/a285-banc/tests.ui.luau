--!nocheck
-- Scénario « ui » (a285, client) : B1 à B5 la chance du serveur dans UI_EventBanner (Monetization.ServerLuck.Enabled
-- allumé ici ; l'événement live passe devant ; fin, facteur 1 et élément absent) ; U1 à U9 UI/UiAttrFx sur un faux
-- écran, valeurs des fiches de L-272 : UIGradient Gleam de Clément (sous UIStroke ou TextLabel) qui défile ensemble
-- puis revient à From, Gleam Loop et Hover (copie blanche GleamFx avec contour, bande douce), rien de plus sous un
-- Gleam de Clément, IconHover Jump (un saut, pas relancé) et Lean (penche puis revient), Spring non codé, Idle Wiggle
-- (par moments, décalés dans l'écran, sous Appear aussi), Idle Fall (12 copies au plus, tailles, transparence),
-- animations réduites, valeurs inconnues sans erreur, Destroying ; U10 branchement dans UiFeelController et Motion.
REPLACE("shared/Config/Monetization.luau", "local SERVER_LUCK = false", "local SERVER_LUCK = true")
startServer()
local ada = join("Ada", newProfile())
advance(1)
CLIENT_PLAYER = ada
Players.LocalPlayer = ada
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local UI_FOLDER = CONTROLLERS:FindFirstChild("UI")
local LiveEvents = sharedModule("Config/LiveEvents", "client")
local Monetization = sharedModule("Config/Monetization", "client")

---------------------------------------------------------------- bannière
local banner = make("ScreenGui", { Name = "UI_EventBanner", Enabled = false, ResetOnSpawn = false }, playerGui)
local root = make("Frame", { Name = "Root" }, banner)
local title = make("TextLabel", { Name = "Title", Text = "" }, root)
local timer = make("TextLabel", { Name = "Timer", Text = "" }, root)
local effect = make("TextLabel", { Name = "Effect", Text = "" }, root)
local Banner = requireModule(moduleScript(CONTROLLERS, "EventBannerController", "client/Controllers/EventBannerController.luau"), "client")
Banner.Start()
flush()

section("B1 rien en cours : bannière éteinte")
check(Monetization.ServerLuck.Enabled == true, "banc : SERVER_LUCK allumé")
check(banner.Enabled == false and Banner.GetState().Shown == false, "éteinte")

section("B2 chance du serveur ×4 : titre, effet, chrono")
Workspace:SetAttribute("ServerLuckEndsAt", Workspace:GetServerTimeNow() + 600)
Workspace:SetAttribute("ServerLuck", 4)
flush()
check(banner.Enabled == true and Banner.GetState().Id == "ServerLuck", "allumée, Id ServerLuck")
check(title.Text == "SERVER LUCK ×4" and effect.Text == "Rarer boxes for everyone", `textes : « {title.Text} », « {effect.Text} »`)
check(timer.Text == "10:00" or timer.Text == "9:59", `chrono : « {timer.Text} »`)
advance(60, 0.5)
check(timer.Text == "9:00" or timer.Text == "8:59", `1 min plus tard : « {timer.Text} »`)

section("B3 l'événement live passe devant, puis la chance revient")
local eventId, format = next(LiveEvents.ById)
Workspace:SetAttribute(LiveEvents.EndsAtAttribute, Workspace:GetServerTimeNow() + 120)
Workspace:SetAttribute(LiveEvents.IdAttribute, eventId)
flush()
check(Banner.GetState().Id == eventId and title.Text == format.DisplayName, `événement {eventId} montré : « {title.Text} »`)
Workspace:SetAttribute(LiveEvents.IdAttribute, nil)
Workspace:SetAttribute(LiveEvents.EndsAtAttribute, nil)
flush()
check(Banner.GetState().Id == "ServerLuck" and title.Text == "SERVER LUCK ×4", "fin de l'événement : la chance revient")

section("B4 fin de la chance, facteur 1 : éteinte")
advance(541, 0.5)
check(banner.Enabled == false and Banner.GetState().Shown == false, "temps écoulé : éteinte")
Workspace:SetAttribute("ServerLuckEndsAt", Workspace:GetServerTimeNow() + 600)
Workspace:SetAttribute("ServerLuck", 1)
flush()
check(banner.Enabled == false, "facteur 1 : rien")

section("B5 élément absent : pas d'erreur")
effect:Destroy()
Workspace:SetAttribute("ServerLuck", 2)
flush()
check(banner.Enabled == true and title.Text == "SERVER LUCK ×2", "sans Effect : titre écrit, aucune erreur")
check(not logHas("EventBannerController", "WARN", "client"), "aucune alerte")
Workspace:SetAttribute("ServerLuck", nil)
Workspace:SetAttribute("ServerLuckEndsAt", nil)
flush()

---------------------------------------------------------------- effets d'UI
local Fx = requireModule(moduleScript(UI_FOLDER, "UiAttrFx", "client/Controllers/UI/UiAttrFx.luau"), "client")
local UiMotion = sharedModule("Config/UiMotion", "client")
local AF = UiMotion.AttrFx
local GG = AF.GleamGradient
local function gui(class, name, props, parent)
	local base = { Name = name, Visible = true, ZIndex = 2, Rotation = 0, BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), AbsoluteSize = Vector2.new(100, 100), MouseEnter = newSignal(), MouseLeave = newSignal() }
	for k, v in props or {} do
		base[k] = v
	end
	return make(class, base, parent)
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local screen = make("ScreenGui", { Name = "UI_Test", Enabled = true }, playerGui)
local panel = gui("Frame", "Panel", nil, screen)
local itemName = gui("TextLabel", "ItemName", { Text = "Golden Rocket", TextColor3 = Color3.new(1, 0.8, 0), TextTransparency = 0 }, panel)
itemName:SetAttribute("Gleam", "Loop")
make("UIStroke", { Name = "UIStroke", Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0 }, itemName)
local card = gui("ImageButton", "Card", { Image = "rbxassetid://1" }, panel)
card:SetAttribute("Gleam", "Hover")
card:SetAttribute("IconHover", "Jump")
local icon = gui("ImageLabel", "Icon", { Image = "rbxassetid://2", Position = UDim2.new(0.5, 0, 0.4, 0) }, card)
local leanBtn = gui("TextButton", "LeanButton", { Text = "Go" }, panel)
leanBtn:SetAttribute("IconHover", "Lean")
local leanIcon = gui("ImageLabel", "Icon", { Rotation = 2 }, leanBtn)
local springBtn = gui("Frame", "Crate", nil, panel)
springBtn:SetAttribute("IconHover", "Spring")
gui("ImageLabel", "Icon", nil, springBtn)
-- HUD : Gleam de Clément sous Label.UIStroke, et un autre sous un TextLabel ; Gleam = Loop en plus sur le bouton.
local hud = make("ScreenGui", { Name = "UI_Hud", Enabled = true }, playerGui)
local hudBtn = gui("TextButton", "DisplayedButton", { Text = "" }, hud)
hudBtn:SetAttribute("Gleam", "Loop")
local hudLabel = gui("TextLabel", "Label", { Text = "Displays" }, hudBtn)
local hudStroke = make("UIStroke", { Name = "UIStroke", Thickness = 2 }, hudLabel)
local strokeGleam = make("UIGradient", { Name = "Gleam", Offset = Vector2.new(GG.From, 0), Rotation = 15 }, hudStroke)
local title = gui("TextLabel", "Title", { Text = "SHOP" }, hud)
local textGleam = make("UIGradient", { Name = "Gleam", Offset = Vector2.new(GG.From, 0) }, title)
local hammer = gui("ImageLabel", "Hammer", { Rotation = 10 }, panel)
hammer:SetAttribute("Idle", "Wiggle")
local stamped = gui("ImageLabel", "Hang1", { Rotation = 5 }, panel)
stamped:SetAttribute("Idle", "Wiggle")
stamped:SetAttribute("Appear", "DropIn")
local cash = gui("Frame", "CashCard", nil, panel)
cash:SetAttribute("Idle", "Fall")
local layer = gui("Frame", "FallLayer", nil, cash)
local fallItem = gui("ImageLabel", "FallItem", { ImageTransparency = 0.2, Visible = false, Size = UDim2.new(0.2, 10, 0.2, 10) }, layer)
local bad = gui("Frame", "Bad", nil, panel)
bad:SetAttribute("Idle", "Spin")
bad:SetAttribute("Gleam", "Shine")
local lonely = gui("Frame", "Lonely", nil, panel)
lonely:SetAttribute("IconHover", "Jump")
local noFall = gui("Frame", "NoLayer", nil, panel)
noFall:SetAttribute("Idle", "Fall")
local ok, err = pcall(function()
	for _, object in { panel, itemName, card, icon, leanBtn, leanIcon, springBtn, hudBtn, hudLabel, title, hammer, stamped, cash, layer, fallItem, bad, lonely, noFall } do
		Fx.Wire(object)
		Fx.Wire(object) -- une seule fois
	end
end)
check(ok, `Wire sans erreur ({tostring(err)})`)

section("U1 état après Wire")
local state = Fx.GetState()
check(state.Gleams == 2 and state.Gradients == 2 and state.IconHovers == 2 and state.Wiggles == 2 and state.Falls == 1 and state.Running == true,
	`2 reflets, 2 Gleam de Clément, 2 icônes (pas Spring), 2 balancements (Appear compris), 1 chute ({state.Gleams}, {state.Gradients}, {state.IconHovers}, {state.Wiggles}, {state.Falls}, {tostring(state.Running)})`)
check(logHas("Idle = « Spin » inconnu", "PRINT", "client") and logHas("Gleam = « Shine » inconnu", "PRINT", "client"), "valeurs inconnues : une ligne en Studio")
check(logHas("pas d'enfant Icon", "PRINT", "client") and logHas("pas de FallLayer.FallItem", "PRINT", "client"), "enfant manquant : une ligne en Studio")
check(logHas("IconHover = Spring", "PRINT", "client"), "Spring : pas codé, une ligne en Studio")
check(hudBtn:FindFirstChild(AF.Gleam.Name) == nil and logHas("déjà un UIGradient Gleam de Clément", "PRINT", "client"), "Gleam = Loop sur un bouton qui a déjà un Gleam de Clément : pas de copie")

section("U2 Gleam de Clément : défile ensemble, pause, remis à From")
local tg = now()
local seen = {}
local together = true
local cycle = GG.Sweep + GG.Pause
for i = 0, math.ceil(cycle * 20) do
	Fx.Step(tg + i * 0.05)
	seen[#seen + 1] = strokeGleam.Offset.X
	together = together and near(strokeGleam.Offset.X, textGleam.Offset.X)
end
local maxX = -math.huge
for _, x in seen do
	maxX = math.max(maxX, x)
end
check(near(seen[1], GG.From), `départ à From ({seen[1]})`)
check(maxX > 0.6 and maxX <= GG.To + 1e-6, `défile jusqu'à To ({maxX})`)
check(together, "les deux Gleam de l'écran ensemble")
Fx.Step(tg + GG.Sweep / 2)
check(strokeGleam.Offset.X > GG.From + 0.5 and strokeGleam.Offset.X < GG.To - 0.5, `à mi-passage : au milieu ({strokeGleam.Offset.X})`)
Fx.Step(tg + GG.Sweep + GG.Pause / 2)
check(near(strokeGleam.Offset.X, GG.From), "pendant la pause : à From")
Fx.Step(tg + GG.Sweep / 2)
hud.Enabled = false
Fx.Step(tg + 1)
check(near(strokeGleam.Offset.X, GG.From) and near(textGleam.Offset.X, GG.From), "écran éteint : remis à From")
hud.Enabled = true
Fx.Step(tg + 50.3)
check(near(strokeGleam.Offset.X, GG.From), "rallumé : repart du début (premier pas à From)")
Fx.Step(tg + 50.3 + GG.Sweep / 2)
check(strokeGleam.Offset.X > GG.From + 0.5, "puis défile")
hud.Enabled = false
Fx.Step(tg + 60)
hud.Enabled = true

section("U3 Gleam Loop : copie blanche, contour, bande douce, texte suivi")
local overlay = itemName:FindFirstChild(AF.Gleam.Name)
check(overlay ~= nil and overlay.ClassName == "TextLabel" and overlay.Text == "Golden Rocket" and overlay.Visible == false, "GleamFx : TextLabel caché, même texte")
check(overlay and overlay.TextColor3 == Color3.new(1, 1, 1) and overlay.ZIndex == 3 and overlay.BackgroundTransparency == 1 and overlay.Size == UDim2.fromScale(1, 1), "blanc, par-dessus (ZIndex + 1), sans fond, toute la taille")
local gradient = overlay and overlay:FindFirstChildOfClass("UIGradient")
local stroke = overlay and overlay:FindFirstChildOfClass("UIStroke")
local strokeGradient = stroke and stroke:FindFirstChildOfClass("UIGradient")
check(gradient ~= nil and gradient.Rotation == AF.Gleam.Rotation, `UIGradient de transparence penché de {AF.Gleam.Rotation}°`)
check(stroke ~= nil and stroke.Color == Color3.new(1, 1, 1) and stroke.Thickness == 3 and strokeGradient ~= nil, "contour blanc de même épaisseur, avec son dégradé")
local function peakOf(g)
	local best = 1
	for _, kp in (g.Transparency.Keypoints or g.Transparency.Start) do -- faux Roblox : la liste est dans Start
		best = math.min(best, kp.Value)
	end
	return 1 - best
end
check(gradient and near(peakOf(gradient), AF.Gleam.TextPeak) and strokeGradient and near(peakOf(strokeGradient), AF.Gleam.StrokePeak), `opacité {AF.Gleam.TextPeak} sur les lettres, {AF.Gleam.StrokePeak} sur le contour`)
local kps = gradient and (gradient.Transparency.Keypoints or gradient.Transparency.Start) or {}
check(#kps == 11 and near(kps[2].Time, 0.5 - AF.Gleam.Loop.Width / 2) and near(kps[10].Time, 0.5 + AF.Gleam.Loop.Width / 2), `bande de {AF.Gleam.Loop.Width} de large ({#kps} points)`)
itemName.Text = "Neon Jukebox"
check(overlay and overlay.Text == "Neon Jukebox", "le texte de la copie suit")
check(itemName.TextColor3 ~= Color3.new(1, 1, 1), "l'élément de Clément garde sa couleur")
local period = AF.Gleam.Loop.Pass + AF.Gleam.Loop.Pause
local t0 = now() + 100
local shownAt = nil
local offsets = {}
local hiddenAfter = false
local synced = true
for i = 0, math.ceil((period + AF.Gleam.Loop.Pass) * 20) + 2 do
	local t = t0 + i * 0.05
	Fx.Step(t)
	if overlay.Visible then
		shownAt = shownAt or t
		if not hiddenAfter then
			table.insert(offsets, gradient.Offset.X)
			synced = synced and near(gradient.Offset.X, strokeGradient.Offset.X)
		end
	elseif shownAt then
		hiddenAfter = true
	end
end
check(shownAt ~= nil and shownAt - t0 <= period + 0.06, `reflet passé dans les {period} s`)
check(#offsets >= math.floor(AF.Gleam.Loop.Pass * 20) - 1 and offsets[#offsets] > offsets[1], `le reflet traverse en ~{AF.Gleam.Loop.Pass} s ({#offsets} images, {offsets[1]} → {offsets[#offsets]})`)
check(synced, "lettres et contour ensemble")
check(hiddenAfter, "puis caché jusqu'au suivant")
screen.Enabled = false
local any = false
for i = 0, math.ceil(period * 20) + 2 do
	Fx.Step(t0 + 20 + i * 0.05)
	any = any or overlay.Visible
end
check(not any, "écran éteint : aucun reflet")
screen.Enabled = true

section("U4 Gleam Hover : au survol du bouton")
local cardOverlay = card:FindFirstChild(AF.Gleam.Name)
check(cardOverlay ~= nil and cardOverlay.ClassName == "ImageLabel" and cardOverlay.Image == "rbxassetid://1" and cardOverlay.ImageColor3 == Color3.new(1, 1, 1), "GleamFx : ImageLabel blanche, même image")
Fx.Step(now())
check(cardOverlay.Visible == false, "sans survol : rien")
card.MouseEnter:Fire()
local started = now()
Fx.Step(started + 0.1)
check(cardOverlay.Visible == true, "survol : le reflet passe")
Fx.Step(started + AF.Gleam.Hover.Pass + 0.05)
check(cardOverlay.Visible == false, `puis caché après {AF.Gleam.Hover.Pass} s`)
card.MouseLeave:Fire()

section("U5 IconHover Jump et Lean")
local moves = {}
icon:GetPropertyChangedSignal("Position"):Connect(function()
	table.insert(moves, icon.Position)
end)
local rest = icon.Position
card.MouseEnter:Fire()
local jump = 100 * AF.IconHover.Jump.Height
check(#moves >= 2 and moves[1] == rest + UDim2.fromOffset(0, -jump) and moves[#moves] == rest, `Jump : monte de {jump} px puis retombe à sa place ({#moves} mouvements)`)
local count = #moves
card.MouseLeave:Fire()
check(#moves == count, "sortie : rien de plus")
leanBtn.MouseEnter:Fire()
check(near(leanIcon.Rotation, 2 + AF.IconHover.Lean.Tilt), `Lean : penche de {AF.IconHover.Lean.Tilt}° depuis sa Rotation ({leanIcon.Rotation})`)
leanBtn.MouseLeave:Fire()
check(near(leanIcon.Rotation, 2), "Lean : revient à la sortie")

section("U6 Idle Wiggle : par moments, décalés")
local tw = now() + 300
local W = AF.Wiggle
screen.Enabled = false -- l'écran s'ouvre à tw
Fx.Step(tw - 1)
screen.Enabled = true
Fx.Step(tw)
local early = true
for i = 1, math.floor((W.Every - 0.1) * 10) do
	Fx.Step(tw + i * 0.1)
	early = early and hammer.Rotation == 10 and stamped.Rotation == 5
end
check(early, `rien avant {W.Every} s (après l'apparition)`)
local minR, maxR = math.huge, -math.huge
for i = 0, math.floor(W.Time * 20) do
	Fx.Step(tw + W.Every + i * 0.05)
	minR = math.min(minR, hammer.Rotation)
	maxR = math.max(maxR, hammer.Rotation)
end
check(maxR > 10 + W.Angle - 0.5 and minR < 10 - W.Angle + 0.5 and maxR <= 10 + W.Angle + 1e-6, `balance de ± {W.Angle}° autour de 10° ({math.floor(minR * 10) / 10} à {math.floor(maxR * 10) / 10})`)
Fx.Step(tw + W.Every + W.Time + 0.05)
check(hammer.Rotation == 10, "fin du balancement : remis à sa Rotation")
Fx.Step(tw + W.Every + W.Stagger / 2)
check(stamped.Rotation == 5, `le 2e de l'écran attend {W.Stagger} s de plus`)
Fx.Step(tw + W.Every + W.Stagger + W.Time / 4)
check(stamped.Rotation > 5 + W.Angle - 0.5, `puis balance à son tour, Appear = DropIn compris ({stamped.Rotation})`)
hammer.Visible = false
Fx.Step(tw + 2 * W.Every + 0.2)
check(hammer.Rotation == 10, "caché : à sa Rotation")
hammer.Visible = true
Fx.Step(tw + 2 * W.Every + 0.3)
check(hammer.Rotation == 10, "réaffiché : attend de nouveau")

section("U7 Idle Fall")
local function copies()
	local list = {}
	for _, child in layer:GetChildren() do
		if child.Name == AF.Fall.CopyName then
			table.insert(list, child)
		end
	end
	return list
end
local F = AF.Fall
local tf = now() + 400
Fx.Step(tf)
local c1 = copies()[1]
check(#copies() == 1 and c1.Visible == true, "une copie qui tombe, visible (le FallItem invisible reste caché)")
local sx = c1 and c1.Size.X.Scale / 0.2
check(sx and sx >= F.MinScale - 1e-6 and sx <= F.MaxScale + 1e-6 and near(c1.Size.X.Offset / 10, sx), `taille entre {F.MinScale} et {F.MaxScale} ({sx})`)
Fx.Step(tf + F.Time / F.Count + 0.01)
check(#copies() == 2, `une 2e copie après {F.Time / F.Count} s ({#copies()})`)
local maxLive, minT = 0, 1
for i = 1, 200 do
	Fx.Step(tf + i * 0.1)
	maxLive = math.max(maxLive, #copies())
	for _, c in copies() do
		minT = math.min(minT, c.ImageTransparency)
	end
end
check(maxLive <= F.Count and maxLive >= F.Count - 2, `jusqu'à {F.Count} copies en l'air ({maxLive})`)
check(minT >= F.Transparency - 1e-6, `jamais moins transparentes que {F.Transparency} ({minT})`)
screen.Enabled = false
Fx.Step(tf + 30)
check(#copies() == 0 and fallItem.Visible == false, "écran éteint : copies détruites, FallItem rendu tel quel (invisible)")
screen.Enabled = true

section("U8 animations réduites : rien ne bouge")
local Motion = requireModule(UI_FOLDER:FindFirstChild("Motion"), "client")
local was = Motion.IsReduced
Motion.IsReduced = function()
	return true
end
local tr = now() + 500
Fx.Step(tr)
Fx.Step(tr + GG.Sweep / 2)
check(near(strokeGleam.Offset.X, GG.From) and #copies() == 0 and hammer.Rotation == 10, "Gleam à From, aucune chute, aucun balancement")
Motion.IsReduced = was

section("U9 Destroying : l'effet est oublié")
hammer:Destroy()
cash:Destroy()
textGleam:Destroy()
local after = Fx.GetState()
check(after.Wiggles == 1 and after.Falls == 0 and after.Gleams == 2 and after.Gradients == 1, "balancement, chute et Gleam détruits oubliés, le reste gardé")

section("U10 branchements (texte des sources)")
local feel = SOURCES["client/Controllers/UiFeelController.luau"]
check(feel ~= nil and string.find(feel, "UiAttrFx.Wire(object)", 1, true) ~= nil, "UiFeelController appelle UiAttrFx.Wire sur chaque élément")
local motion = SOURCES["client/Controllers/UI/Motion.luau"]
check(string.find(motion, 'GetAttribute("IconHover")', 1, true) ~= nil, "Motion.HoverCard laisse l'Icon à IconHover")
check(string.find(SOURCES["client/Controllers/UI/UiAttrFx.luau"], "local ENABLED = Features.UiAttrFx == true", 1, true) ~= nil, "derrière Features.UiAttrFx")
check(not logHas("UiAttrFx", "WARN", "client"), "aucune alerte")

summary("scénario ui")
