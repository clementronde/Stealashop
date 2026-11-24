--!nocheck
-- Scénario « off » (a298, client) : Features.FramewispFx = false : ni effet Figma*, ni reflet du bouton entier, rien de
-- créé ni de touché (le Gleam sur un texte reste ignoré : c'est UiAttrFx, décision « HUD et boutons d'achat »).
REPLACE("shared/Config/Features.luau", "FramewispFx = true,", "FramewispFx = false,")
startServer()
local ada = join("Ada", newProfile())
advance(1)
CLIENT_PLAYER = ada
Players.LocalPlayer = ada
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local UI_FOLDER = CONTROLLERS:FindFirstChild("UI")
moduleScript(UI_FOLDER, "FramewispFx", "client/Controllers/UI/FramewispFx.luau")
local Fx = requireModule(moduleScript(UI_FOLDER, "UiAttrFx", "client/Controllers/UI/UiAttrFx.luau"), "client")
local FW = requireModule(UI_FOLDER:FindFirstChild("FramewispFx"), "client")
local Features = sharedModule("Config/Features", "client")
local AF = sharedModule("Config/UiMotion", "client").AttrFx
local function gui(class, name, props, parent)
	local base = {
		Name = name, Visible = true, ZIndex = 2, Rotation = 0, BackgroundTransparency = 1, ImageTransparency = 0,
		TextTransparency = 0, Image = "", Text = "", Size = UDim2.fromScale(0.2, 0.2), AbsoluteSize = Vector2.new(100, 100),
		AbsolutePosition = Vector2.new(0, 0), MouseEnter = newSignal(), MouseLeave = newSignal(),
		MouseButton1Down = newSignal(), MouseButton1Up = newSignal(), InputBegan = newSignal(),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return make(class, base, parent)
end
local hud = make("ScreenGui", { Name = "UI_HUD", Enabled = true }, playerGui)
local rail = gui("Frame", "LeftRail", nil, hud)
local shop = gui("TextButton", "Frame 1", nil, rail)
for k, v in { FigmaBurst = true, FigmaGleam = true, FigmaSmooth = true, FW_Owned = true } do
	shop:SetAttribute(k, v)
end
local sun = gui("ImageLabel", "Sunburst", { Image = "rbxassetid://1", Rotation = 5 }, shop)
sun:SetAttribute("FigmaSpin", true)
local label = gui("TextLabel", "Label", { Text = "SHOP" }, shop)
local quests = gui("TextButton", "QuestsButton", { BackgroundTransparency = 0 }, rail)
local plain = gui("ImageButton", "Plain", { AutoButtonColor = true }, rail)
plain:SetAttribute("FW_Owned", true)
local art = gui("ImageLabel", "Art", { Image = "rbxassetid://2", ImageColor3 = Color3.new(1, 0.5, 0.25) }, plain)
local robux = make("ScreenGui", { Name = "UI_RobuxShop_v2", Enabled = true }, playerGui)
local buy = gui("TextButton", "BuyButton", { BackgroundTransparency = 0 }, robux)
local itemName = gui("TextLabel", "ItemName", { Text = "Golden Rocket" }, robux)
itemName:SetAttribute("Gleam", "Loop")
local ok, err = pcall(function()
	for _, screen in { hud, robux } do
		for _, object in screen:GetDescendants() do
			Fx.Wire(object)
		end
	end
end)
check(ok, `Wire sans erreur ({tostring(err)})`)
check(Features.FramewispFx == false, "banc : FramewispFx éteint")
local st = FW.GetState()
local total = 0
for _, n in st do
	total += n
end
check(total == 0, "aucun effet suivi")
advance(3, 0.05)
shop.Activated:Fire()
plain.MouseEnter:Fire()
check(sun.Rotation == 5, "Sunburst ne tourne pas")
local made = 0
for _, screen in { hud, robux } do
	for _, d in screen:GetDescendants() do
		if d.Name == AF.Framewisp.Gleam.CopyName or d.Name == AF.ButtonSheen.Name or string.find(d.Name, AF.Framewisp.Burst.LayerSuffix, 1, true) then
			made += 1
		end
	end
end
check(made == 0, `rien de créé (ni copie, ni SheenFx, ni calque d'éclats : {made})`)
check(quests:FindFirstChild(AF.ButtonSheen.Name) == nil and buy:FindFirstChild(AF.ButtonSheen.Name) == nil, "pas de reflet de bouton entier")
check(art.ImageColor3 == Color3.new(1, 0.5, 0.25) and plain.AutoButtonColor == true, "pas d'assombrissement, AutoButtonColor de Clément")
check(itemName:FindFirstChild(AF.Gleam.Name) == nil, "Gleam sur un texte : ignoré quand même (UiAttrFx)")
check(label:FindFirstChild(AF.Framewisp.Gleam.CopyName) == nil, "Label du plugin : rien")
summary("scénario off")
