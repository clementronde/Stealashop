--!nocheck
-- Scénario « client » (L-086) : le vrai UnboxController sur la boutique du joueur. Invites « Place Box »
-- sur les présentoirs libres et débloqués quand on porte un colis (rien sur un présentoir verrouillé,
-- pris ou avec un colis), « Open » quand le colis est prêt ; l'objet exposé sur le présentoir du colis
-- reste caché chez celui qui ouvre jusqu'à la révélation (Reveal), puis revient. Plus d'invite sur les
-- UnboxBench_xx. L'écran UI_Unbox est la copie d'a23 (relevé de Studio du 2026-11-07).

local function new(class, props, parent)
	return make(class, props, parent)
end
local function S(x, y)
	return UDim2.fromScale(x, y)
end
local CENTER = Vector2.new(0.5, 0.5)
function buildUnbox(parent)
	local gui = new("ScreenGui", { Name = "UI_Unbox", Enabled = false, IgnoreGuiInset = false }, parent)
	local panel = new("Frame", { Name = "RevealPanel", Size = S(0.75, 0.92), Position = S(0.5, 0.52), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 4 }, gui)
	local rarity = new("TextLabel", { Name = "Rarity", Size = S(0.9, 0.13), Position = S(0.5, 0.607), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "LEGENDARY", TextColor3 = Color3.new(1, 0.8, 0.1) }, panel)
	new("UIStroke", { Name = "UIStroke" }, rarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, rarity)
	local preview = new("Frame", { Name = "ItemPreview", Size = S(0.225, 0.225), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 3 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, preview)
	local itemName = new("TextLabel", { Name = "ItemName", Size = S(0.85, 0.068), Position = S(0.5, 0.705), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "Winning Scratch Card" }, panel)
	new("UIStroke", { Name = "UIStroke" }, itemName)
	local income = new("TextLabel", { Name = "Income", Size = S(0.5, 0.078), Position = S(0.5, 0.785), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "+$50/s" }, panel)
	new("UIStroke", { Name = "UIStroke" }, income)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, panel)
	local rays = new("ImageLabel", { Name = "Rays", Size = S(0.633, 0.633), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 1, Image = "", Rotation = 10 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, rays)
	new("UIGradient", { Name = "Rainbow", Enabled = false, Rotation = 45 }, rays)
	for i = 1, 8 do
		new("Frame", { Name = string.format("Beam_%02d", i), Rotation = i * 45, BackgroundColor3 = Color3.new(1, 1, 0.8) }, rays)
	end
	local glow = new("Frame", { Name = "Glow", Size = S(0.36, 0.36), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 0.8, ZIndex = 2 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, glow)
	new("UICorner", { Name = "UICorner" }, glow)
	new("Frame", { Name = "GlowCore", Size = S(0.7, 0.7), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.7 }, glow)
	local buttons = new("Frame", { Name = "Buttons", Size = S(0.7, 0.122), Position = S(0.5, 0.917), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 6 }, panel)
	new("UIListLayout", { Name = "UIListLayout" }, buttons)
	for _, spec in { { "ContinueButton", true, "CONTINUE" }, { "OpenNextButton", false, "OPEN NEXT" } } do
		local button = new("TextButton", { Name = spec[1], Size = S(0.45, 1), Visible = spec[2], BackgroundTransparency = 0, Text = "" }, buttons)
		for _, deco in { "UISizeConstraint", "UICorner", "UIStroke", "UIGradient" } do
			new(deco, { Name = deco }, button)
		end
		new("ImageLabel", { Name = "Studs", Image = "rbxassetid://3014551673" }, button)
		new("TextLabel", { Name = "Label", Text = spec[3] }, button)
	end
	new("Frame", { Name = "Backdrop", Size = S(1, 1), BackgroundTransparency = 0.65, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 1 }, gui)
	local skip = new("TextButton", { Name = "SkipButton", Size = S(1, 1), Visible = false, BackgroundTransparency = 1, ZIndex = 2, Text = "" }, gui)
	new("TextLabel", { Name = "Label", Size = S(0.3, 0.045), Position = S(0.98, 0.96), Text = "TAP TO SKIP" }, skip)
	local upgrade = new("Frame", { Name = "Upgrade", Size = S(0.42, 0.17), Position = S(0.5, 0.5), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, upgrade)
	new("TextLabel", { Name = "UpgradeLabel", Size = S(1, 0.55), Position = S(0.5, 0), Text = "UPGRADE!" }, upgrade)
	local upgradeRarity = new("TextLabel", { Name = "UpgradeRarity", Size = S(0.8, 0.42), Position = S(0.5, 1), Text = "UNCOMMON" }, upgrade)
	new("UIStroke", { Name = "UIStroke" }, upgradeRarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, upgradeRarity)
	local reel = new("Frame", { Name = "Reel", Size = S(0.2, 0.35), Position = S(0.5, 0.445), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reel)
	local reelGlow = new("Frame", { Name = "ReelGlow", Size = S(1.15, 1.15), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.55, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1 }, reel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reelGlow)
	new("UICorner", { Name = "UICorner" }, reelGlow)
	new("Frame", { Name = "GlowCore", Size = S(0.6, 0.6), BackgroundTransparency = 0.6 }, reelGlow)
	new("ViewportFrame", { Name = "ReelView", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 2, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0 }, reel)
	local confetti = new("Frame", { Name = "Confetti", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 6 }, gui)
	local template = new("Frame", { Name = "Template", Size = S(0.011, 0.018), Position = S(0.5, 0.3), Visible = false, BackgroundTransparency = 0 }, confetti)
	new("UIStroke", { Name = "UIStroke" }, template)
	new("Frame", { Name = "Flash", Size = S(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 7 }, gui)
	return gui
end

-- Toutes les propriétés de `root` et de ses descendants (pour vérifier la remise en état).
local function snapshot(root)
	local out = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, inst in list do
		local props = {}
		for k, v in rawget(inst, "_props") do
			props[k] = v
		end
		out[inst] = { props = props, parent = rawget(inst, "_parent") }
	end
	return out
end

advance(1000)
startServer()
local data = newProfile(4)
addItem(data, "it2", "Z1_Donut", 2, 1)
local ada = join("Ada", data)
advance(1.5)
local gui = buildUnbox(ada:FindFirstChild("PlayerGui"))
startClient(ada)
advance(0.5)

local plot = shopOf(ada)
local function promptOf(name)
	local att = plot:FindFirstChild(name, true)
	return if att then att:FindFirstChild("UnboxPrompt") else nil
end
local function slotPrompt(i)
	return promptOf(string.format("DisplaySlot_%02d", i))
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(slotPrompt(1) ~= nil and slotPrompt(1).ObjectText == "Stand", "une invite « Stand » sur chaque présentoir")
check(slotPrompt(20) ~= nil and slotPrompt(21) ~= nil, "présentoirs 20 et bonus 21 aussi")
check(promptOf("UnboxBench_01") == nil, "plus d'invite sur UnboxBench_01")
check(not slotPrompt(1).Enabled and not slotPrompt(3).Enabled, "sans colis porté : invites cachées")

section("on porte un colis : « Place Box » sur les présentoirs libres et débloqués")
CarryService.Give(ada, npcBox("Common", "Z1_Banane"))
flush()
check(slotPrompt(1).Enabled and slotPrompt(1).ActionText == "Place Box" and slotPrompt(3).Enabled and slotPrompt(4).Enabled, "1, 3 et 4 : « Place Box »")
check(not slotPrompt(2).Enabled, "2 (objet exposé) : rien")
check(not slotPrompt(5).Enabled and not slotPrompt(21).Enabled, "5 et 21 (verrouillés) : rien")
goToStand(ada, 1)
local calls = #serverCalls("PlaceBox")
slotPrompt(1).Triggered:Fire()
flush()
advance(0.5)
check(#serverCalls("PlaceBox") == calls + 1 and serverCalls("PlaceBox")[calls + 1].args[1] == 1, "déclenchée : PlaceBox(1)")
check(dataOf(ada).Boxes["1"] ~= nil, "le serveur a posé le colis sur le présentoir 1")
check(not slotPrompt(1).Enabled and not slotPrompt(3).Enabled, "plus de colis porté, colis qui attend : invites cachées")

section("colis prêt : « Open », objet caché jusqu'à la révélation")
advance(math.max(0, dataOf(ada).Boxes["1"].ReadyAt - serverTime()) + 0.5)
check(slotPrompt(1).Enabled and slotPrompt(1).ActionText == "Open", "colis prêt : « Open »")
local opens = #serverCalls("OpenBox")
slotPrompt(1).Triggered:Fire()
flush()
local uid = dataOf(ada).Display["1"]
check(#serverCalls("OpenBox") == opens + 1 and uid ~= nil, "OpenBox(1) : l'objet est exposé sur le présentoir 1 côté serveur")
local folder = plot:FindFirstChild("DisplayItems")
advance(0.1)
local inFolder = false
for _, child in folder:GetChildren() do
	if child:GetAttribute("ItemUid") == uid then
		inFolder = true
	end
end
check(not inFolder, "pendant le rouleau : l'objet exposé n'est plus dans la boutique (chez ce client)")
check(gui.Enabled, "écran UI_Unbox ouvert")
advance(8)
local back = false
for _, child in folder:GetChildren() do
	if child:GetAttribute("ItemUid") == uid then
		back = true
	end
end
check(back, "après la révélation : l'objet est revenu sur son présentoir")
check(not slotPrompt(1).Enabled, "présentoir 1 pris : plus d'invite")

summary("scénario client")
