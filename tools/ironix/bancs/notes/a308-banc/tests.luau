---------------------------------------------------------------- banc a308 : boutons qui remplissent leur parent
-- Après setup.luau et setup-a60.luau du banc a60 (vrai UiFeelController, vrai Motion, tweens au temps simulé).
-- Écrans comme ceux de Clément (relevés dans Studio le 22/11, en lecture seule) : Root > List (ScrollingFrame) > carte
-- > Card (cadre dessiné) > Content > ButtonRow > EquipButton (Size {1,0},{1,0}, Hover = Pop, Press = Squash) et
-- BuyButton (Size {0,627,0},{1,0}). EMPTY_LIST (scénario « vide ») : Hover.FillParentScreens = {} dans la source.
local H, S, POP, SQ, FIT = UiMotionC.Hover, UiMotionC.Success, UiMotionC.HoverPop, UiMotionC.PressSquash, UiMotionC.HoverFit
local LIST = not EMPTY_LIST
ISA.ScrollingFrame = ISA.ScrollingFrame or ISA.Frame
PROPS.ScrollingFrame = PROPS.ScrollingFrame or PROPS.Frame

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child.ClassName == "UIScale" then
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
	return string.format("%.4f", v)
end

-- Une boutique : une carte « Wrench » visible et le Template caché de la liste. anchor0 : EquipButton en AnchorPoint
-- (0, 0) et Position (0, 0) (même place que (0,5 ; 0,5) au centre ; vérifie le recentrage a299 et le retour exact).
local function makeShop(screenName, anchor0)
	local gui = new("ScreenGui", { Name = screenName, Enabled = true }, PLAYER_GUI)
	local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local list = new("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)
	local function card(name, visible)
		local holder = new("Frame", { Name = name, Visible = visible, Size = UDim2.fromScale(0.25, 0.6), BackgroundTransparency = 1 }, list)
		local cardFrame = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0 }, holder)
		local content = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cardFrame)
		local row = new("Frame", { Name = "ButtonRow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.85), Size = UDim2.fromScale(0.9, 0.12), BackgroundTransparency = 1 }, content)
		local equip = new("TextButton", {
			Name = "EquipButton",
			AnchorPoint = if anchor0 then Vector2.new(0, 0) else Vector2.new(0.5, 0.5),
			Position = if anchor0 then UDim2.fromScale(0, 0) else UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 15,
		}, row)
		equip:SetAttribute("Hover", "Pop")
		equip:SetAttribute("Press", "Squash")
		local buy = new("TextButton", { Name = "BuyButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3135, 0.5), Size = UDim2.fromScale(0.627, 1), ZIndex = 9 }, row)
		buy:SetAttribute("Hover", "Pop")
		buy:SetAttribute("Press", "Squash")
		return holder, equip, buy
	end
	local _, equip, buy = card("Wrench", true)
	local template = card("Template", false)
	return gui, list, template, equip, buy
end

local weapon, weaponList, weaponTemplate, wEquip, wBuy = makeShop("UI_WeaponShop", false)
local aura, _, _, aEquip, aBuy = makeShop("UI_AuraShop", true)
local other, _, _, oEquip, oBuy = makeShop("UI_Inventory", false) -- un écran UI_* hors liste
local snaps = { [weapon] = snapshot(weapon), [aura] = snapshot(aura), [other] = snapshot(other) }

local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)

-- Échelle la plus grande qui garde le bouton dans sa carte (HoverFit : Inset px du bord de Card), le bouton grossissant
-- autour de son centre. Calculée au repos : le faux Roblox ne compte pas le UIScale dans AbsoluteSize (Roblox, si).
local function fitOf(button)
	local cardFrame = button.Parent.Parent.Parent
	local size, pos = button.AbsoluteSize, button.AbsolutePosition
	local w, h = size.X, size.Y
	local cx, cy = pos.X + w / 2, pos.Y + h / 2
	local o, r = cardFrame.AbsolutePosition, cardFrame.AbsoluteSize
	local i = FIT.Inset
	return math.min((cx - o.X - i) / (w / 2), (o.X + r.X - i - cx) / (w / 2), (cy - o.Y - i) / (h / 2), (o.Y + r.Y - i - cy) / (h / 2))
end

print("\n== C. Config")
if LIST then
	check(#H.FillParentScreens == 2 and table.find(H.FillParentScreens, "UI_WeaponShop") ~= nil and table.find(H.FillParentScreens, "UI_AuraShop") ~= nil,
		"C1 Hover.FillParentScreens = UI_WeaponShop, UI_AuraShop")
else
	check(#H.FillParentScreens == 0, "C1 scénario vide : Hover.FillParentScreens = {}")
end

-- Survol, appui, relâché, clic et retour au repos d'un bouton branché. anchor0 : AnchorPoint (0, 0) de Clément ; au
-- premier survol, Motion calcule le plafond HoverFit avant le recentrage a299 (plafond « depuis le coin », plus bas) :
-- seul le plafond centré est exigé comme borne haute.
local function wiredCase(tag, button, anchor0)
	local restAnchor, restPos, restSize = button.AnchorPoint, button.Position, button.Size
	local fit = fitOf(button)
	local hoverGoal = math.min(POP.To, math.max(fit, 1))
	local centerX = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	button.MouseEnter:Fire()
	step(POP.Time + 1 / 30)
	local first = sv(button)
	if anchor0 then
		check(scaleOf(button) ~= nil and first > 1 and first <= hoverGoal + 1e-3, `{tag}a survol : × {fmt(first)} (> 1, ≤ {fmt(hoverGoal)})`)
	else
		check(scaleOf(button) ~= nil and near(first, hoverGoal, 1e-3), `{tag}a survol : × {fmt(first)} (attendu {fmt(hoverGoal)} = Pop {POP.To} ramené au bord de la carte)`)
		check(first > 1.05, `{tag}b le grossissement se voit (> 1,05 : {fmt(first)})`)
	end
	local a = button.AnchorPoint
	check(near(a.X, 0.5, 1e-6) and near(a.Y, 0.5, 1e-6), `{tag}c grossit autour du centre (AnchorPoint ({a.X} ; {a.Y}) pendant le survol)`)
	local cx = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	check(near(cx, centerX, 1e-3), `{tag}d centre à l'écran inchangé ({fmt(cx)} / {fmt(centerX)})`)
	check(first <= fit + 1e-3, `{tag}e reste dans la carte (× {fmt(first)} ≤ {fmt(fit)}) : rien n'est coupé par le clip de Card`)
	button.MouseButton1Down:Fire()
	step(0.2)
	check(near(sv(button), SQ.To, 1e-3), `{tag}f appui : écrasé à × {SQ.To} ({fmt(sv(button))})`)
	button.MouseButton1Up:Fire()
	local peak = 1
	for _ = 1, 30 do
		step(1 / 60)
		peak = math.max(peak, sv(button))
	end
	check(peak > 1 and peak <= fit + 1e-3, `{tag}g relâché : rebond (pic × {fmt(peak)}) dans la carte`)
	step(0.5)
	check(near(sv(button), hoverGoal, 1e-3), `{tag}h puis retour au survol, plafond centré (× {fmt(sv(button))})`)
	button.MouseLeave:Fire()
	step(1)
	check(scaleOf(button) == nil, `{tag}i sortie : UIScale retiré`)
	check(button.AnchorPoint == restAnchor and button.Position == restPos and button.Size == restSize,
		`{tag}j repos exact : AnchorPoint, Position et Size de Clément (mêmes valeurs{if anchor0 then ", AnchorPoint (0, 0) remis" else ""})`)
	-- Clic au doigt (sans survol) : Success (EquipButton est dans Success.Buttons), saut ramené dans la carte.
	button.Activated:Fire()
	local jump = sv(button)
	check(jump > 1 and jump <= fit + 1e-3, `{tag}k clic : Success joué (× {fmt(jump)} ; Success.From {S.From} ramené à ≤ {fmt(fit)})`)
	step(S.Time + 0.2)
	check(scaleOf(button) == nil and button.AnchorPoint == restAnchor and button.Position == restPos and button.Size == restSize,
		`{tag}l après le clic : repos exact, aucun UIScale`)
end

local function skippedCase(tag, button, label)
	button.MouseEnter:Fire()
	step(0.3)
	check(scaleOf(button) == nil, `{tag}a {label} : survol sans effet`)
	button.MouseButton1Down:Fire()
	step(0.2)
	check(scaleOf(button) == nil, `{tag}b {label} : appui sans effet`)
	button.MouseButton1Up:Fire()
	button.Activated:Fire()
	step(0.05)
	check(scaleOf(button) == nil, `{tag}c {label} : clic sans Success`)
	button.MouseLeave:Fire()
	step(0.5)
end

if LIST then
	print("\n== W. UI_WeaponShop : EquipButton (remplit ButtonRow) branché")
	wiredCase("W1", wEquip, false)
	print("\n== A. UI_AuraShop : EquipButton en AnchorPoint (0, 0) branché, recentré le temps de l'effet")
	wiredCase("A1", aEquip, true)
else
	print("\n== W. Liste vide : EquipButton laissé de côté comme avant a308")
	skippedCase("W1", wEquip, "UI_WeaponShop.EquipButton")
	skippedCase("A1", aEquip, "UI_AuraShop.EquipButton")
end

print("\n== B. BuyButton (ne remplit pas son parent) : branché dans les deux cas")
wBuy.MouseEnter:Fire()
step(POP.Time + 1 / 30)
check(scaleOf(wBuy) ~= nil and sv(wBuy) > 1, `B1 UI_WeaponShop.BuyButton : survol (× {fmt(sv(wBuy))})`)
wBuy.MouseLeave:Fire()
aBuy.MouseEnter:Fire()
step(POP.Time + 1 / 30)
check(scaleOf(aBuy) ~= nil and sv(aBuy) > 1, `B2 UI_AuraShop.BuyButton : survol (× {fmt(sv(aBuy))})`)
aBuy.MouseLeave:Fire()
oBuy.MouseEnter:Fire()
step(POP.Time + 1 / 30)
check(scaleOf(oBuy) ~= nil, "B3 UI_Inventory.BuyButton : survol (rien ne change hors des boutons pleins)")
oBuy.MouseLeave:Fire()
step(1)

print("\n== O. Autre écran : le même EquipButton reste écarté")
skippedCase("O1", oEquip, "UI_Inventory.EquipButton")

print("\n== T. Template caché et copie d'une liste")
weaponTemplate:FindFirstChild("Card").Content.ButtonRow.EquipButton.MouseEnter:Fire()
step(0.3)
check(anyUIScale(weaponTemplate) == nil, "T1 EquipButton du Template caché : pas branché")
weaponTemplate:FindFirstChild("Card").Content.ButtonRow.EquipButton.MouseLeave:Fire()
local copy = weaponTemplate:Clone()
copy.Parent = weaponList
copy.Name = "Crowbar" -- renommée juste après son arrivée, comme le font les contrôleurs
copy.Visible = true
step(1 / 30)
local copyEquip = copy.Card.Content.ButtonRow.EquipButton
copyEquip.MouseEnter:Fire()
step(POP.Time + 1 / 30)
if LIST then
	check(scaleOf(copyEquip) ~= nil and sv(copyEquip) > 1.05, `T2 EquipButton d'une copie de la liste : branché (× {fmt(sv(copyEquip))})`)
else
	check(scaleOf(copyEquip) == nil, "T2 liste vide : EquipButton d'une copie laissé de côté")
end
copyEquip.MouseLeave:Fire()
step(1)
copy:Destroy()

print("\n== R. Rien n'est laissé")
step(1)
for gui, snap in snaps do
	local same, why = sameAs(snap, gui)
	check(same, `R1 {gui.Name} comme au départ ({why})`)
end
check(ACTIVE_TWEENS() == 0, "R2 aucun tween en cours")

summary()
