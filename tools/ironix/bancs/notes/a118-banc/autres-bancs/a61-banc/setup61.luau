--!nocheck
-- Mise en place du banc a61 (vague 21, L-079, L-091 point 6 : écran UI_Inventory, barre Roblox coupée),
-- après celle de la copie d'a61 d'a51 (autres-bancs/a51-banc/setup.luau : hub, zone safe, 6 boutiques,
-- vrais InventoryService, DisplayService, UnboxService, ToolService, ShopService…, vrais InventoryController
-- et UI/Motion côté client, invOf / invBox / invItem) :
--   - écrans du relevé de Studio du 2026-11-10 (agents/wave21-studio.md, section « Inventaire ») faits par
--     buildInventoryUi(player) dans son PlayerGui, avant startClient : UI_HUD.LeftRail.InventoryButton,
--     UI_Inventory (Root, Window, List et ses 4 sections, ScrollTrack, pilules, EquipBestButton, Tabs), et
--     un autre écran du groupe Menu (UI_Other, allumé) ;
--   - icônes ICON_TOOL_Fists et ICON_TOOL_Wrench (pas ICON_TOOL_Bat : la carte garde l'image du Template),
--     en plus de celles d'a51 (ICON_<ItemId> sauf Z1_Brocoli, ICON_BOX_Premium seulement).

make("Decal", { Name = "ICON_TOOL_Fists", Texture = "rbxassetid://9201" }, ICONS)
make("Decal", { Name = "ICON_TOOL_Wrench", Texture = "rbxassetid://9202" }, ICONS)
TEMPLATE_IMAGE = { Items = "rbxassetid://1", Boxes = "rbxassetid://2", Tools = "rbxassetid://3" }

local baseStartServer = startServer
function startServer()
	baseStartServer()
	Mutations = sharedModule("Config/Mutations")
	Format = sharedModule("Format")
	ToolsConfig = sharedModule("Config/Tools")
	BatConfig = sharedModule("Config/Bat")
	UIContract = sharedModule("Contract/UI")
	Find = sharedModule("Contract/Find")
end

local function label(name, text, parent, visible)
	return make("TextLabel", { Name = name, Text = text, Visible = visible ~= false }, parent)
end
local function button(name, text, parent, visible)
	local b = make("TextButton", { Name = name, Text = "", Visible = visible ~= false }, parent)
	label(text.name, text.text, b)
	make("Frame", { Name = "Shade" }, b)
	return b
end
local function card(parent, image)
	local t = make("TextButton", { Name = "Template", Visible = false, Text = "" }, parent)
	make("Frame", { Name = "CardShadow" }, t)
	local clip = make("Frame", { Name = "Clip" }, t)
	make("ImageLabel", { Name = "Rays", ImageColor3 = Color3.new(1, 1, 1) }, clip)
	make("ImageLabel", { Name = "Glow", ImageColor3 = Color3.new(1, 1, 1) }, clip)
	make("ImageLabel", { Name = "Icon", Image = image }, t)
	make("Frame", { Name = "HoverOutline", Visible = false }, t)
	return t
end
local function rarityBar(t)
	local bar = make("Frame", { Name = "RarityBar" }, t)
	make("Frame", { Name = "RarityBarTop" }, bar)
	label("Rarity", "COMMON", bar)
end
local function pill(name, labelName, text, parent, visible)
	local p = make("Frame", { Name = name, Visible = visible }, parent)
	label(labelName, text, p)
	return p
end

INV = {}
function buildInventoryUi(player)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = make("ScreenGui", { Name = "UI_HUD" }, nil)
	local rail = make("Frame", { Name = "LeftRail" }, hud)
	local invButton = make("TextButton", { Name = "InventoryButton", Text = "" }, rail)
	make("ImageLabel", { Name = "BackpackIcon" }, invButton)
	hud.Parent = gui

	local other = make("ScreenGui", { Name = "UI_Other", Enabled = true }, nil)
	other:SetAttribute("ScreenGroup", "Menu")
	make("Frame", { Name = "Root" }, other)
	other.Parent = gui

	local screen = make("ScreenGui", { Name = "UI_Inventory", Enabled = true }, nil) -- copie de StarterGui allumée
	screen:SetAttribute("ScreenGroup", "Menu")
	local root = make("Frame", { Name = "Root" }, screen)
	local window = make("Frame", { Name = "Window" }, root)
	local header = make("Frame", { Name = "Header" }, window)
	label("Title", "Inventory", header)
	local close = button("CloseButton", { name = "XLabel", text = "X" }, header)
	local list = make("ScrollingFrame", {
		Name = "List",
		CanvasPosition = Vector2.new(0, 0),
		AbsoluteWindowSize = Vector2.new(400, 300),
		AbsoluteCanvasSize = Vector2.new(400, 300),
	}, window)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local sections = {}
	local templates = {}
	for _, def in { { "Items", "ITEMS" }, { "Boxes", "BOXES" }, { "Tools", "TOOLS" }, { "Potions", "POTIONS" } } do
		local name = def[1]
		local s = make("Frame", { Name = `{name}Section`, Visible = name == "Items" }, list)
		local row = make("Frame", { Name = "TitleRow" }, s)
		label("SectionTitle", def[2], row)
		if name ~= "Potions" then
			local count = make("Frame", { Name = "SectionCount" }, row)
			label("CountLabel", "9", count)
		end
		local cards = make("Frame", { Name = "Cards" }, s)
		make("UIGridLayout", { Name = "UIGridLayout" }, cards)
		sections[name] = { frame = s, cards = cards }
	end
	-- Items
	do
		local t = card(sections.Items.cards, TEMPLATE_IMAGE.Items)
		label("Income", "+$12K/s", t)
		label("ItemName", "ITEM", t)
		rarityBar(t)
		pill("MutationTag", "MutationLabel", "BIG GOLD", t, true)
		pill("DisplayedBadge", "DisplayedLabel", "ON DISPLAY", t, false)
		button("PlaceButton", { name = "PlaceLabel", text = "PLACE" }, t)
		button("UnequipButton", { name = "UnequipLabel", text = "UNEQUIP" }, t, false)
		templates.Items = t
		-- carte d'exemple de la maquette, retirée par le code
		local preview = make("TextButton", { Name = "Preview_1", Text = "" }, sections.Items.cards)
		make("ImageLabel", { Name = "Icon" }, preview)
	end
	-- Boxes
	do
		local t = card(sections.Boxes.cards, TEMPLATE_IMAGE.Boxes)
		t:FindFirstChild("Icon"):SetAttribute("IconAsset", "ICON_BOX_Premium")
		label("BoxName", "PREMIUM BOX", t)
		rarityBar(t)
		button("PlaceButton", { name = "PlaceLabel", text = "PLACE" }, t)
		pill("PlacedPill", "PlacedLabel", "ON FLOOR", t, false)
		pill("ReadyPill", "ReadyLabel", "READY", t, true)
		pill("TimerPill", "TimerLabel", "0:42", t, false)
		templates.Boxes = t
	end
	-- Tools
	do
		local t = card(sections.Tools.cards, TEMPLATE_IMAGE.Tools)
		t:FindFirstChild("Icon"):SetAttribute("IconAsset", "ICON_TOOL_Hammer")
		label("ToolStat", "Power 20", t)
		label("ToolName", "HAMMER", t)
		button("EquipButton", { name = "EquipLabel", text = "EQUIP" }, t)
		pill("EquippedPill", "EquippedLabel", "EQUIPPED", t, false)
		templates.Tools = t
	end
	local track = make("Frame", {
		Name = "ScrollTrack",
		Position = UDim2.new(1, -8, 0.1, 0),
		Size = UDim2.new(0, 6, 0.8, 0),
		AnchorPoint = Vector2.new(0, 0),
	}, window)
	local counterPill = make("Frame", { Name = "CounterPill" }, window)
	make("ImageLabel", { Name = "BackpackIcon" }, counterPill)
	local counter = label("Counter", "9 / 30 items", counterPill)
	local displayPill = make("Frame", { Name = "DisplayPill" }, window)
	make("ImageLabel", { Name = "DisplayIcon" }, displayPill)
	local displays = label("Displays", "4 / 6 displays", displayPill)
	local equipBest = button("EquipBestButton", { name = "EquipBestLabel", text = "EQUIP BEST" }, window)
	make("ImageLabel", { Name = "StarIcon" }, equipBest)
	local tabs = make("Frame", { Name = "Tabs" }, root)
	make("UIListLayout", { Name = "UIListLayout" }, tabs)
	local tabButtons = {}
	for _, name in { "Items", "Boxes", "Tools", "Potions" } do
		local b = make("TextButton", { Name = `{name}Tab`, Text = "" }, tabs)
		label("TabLabel", name, b)
		make("ImageLabel", { Name = "TabIcon" }, b)
		make("Frame", { Name = "Studs" }, b)
		make("Frame", { Name = "Shade" }, b)
		local selected = make("Frame", { Name = "Selected", Visible = name == "Items" }, b)
		tabButtons[name] = { button = b, selected = selected }
	end
	screen.Parent = gui

	INV = {
		hud = hud,
		invButton = invButton,
		other = other,
		screen = screen,
		close = close,
		list = list,
		sections = sections,
		templates = templates,
		track = track,
		counter = counter,
		displays = displays,
		equipBest = equipBest,
		tabs = tabButtons,
	}
	return INV
end

-- Clic sur un bouton (ou une carte) de l'écran.
function click(element)
	assert(element, "clic sur un élément absent")
	element.Activated:Fire()
	flush()
end
-- Cartes clonées d'une section (sans Template ni UIGridLayout), par nom.
function cardsOf(sectionName)
	local out, n = {}, 0
	for _, child in INV.sections[sectionName].cards:GetChildren() do
		if child.Name ~= "Template" and child:IsA("GuiObject") then
			out[child.Name] = child
			n += 1
		end
	end
	return out, n
end
function cardPart(cardFrame, path)
	return Find.path(cardFrame, path)
end
function countLabel(sectionName)
	local f = INV.sections[sectionName].frame:FindFirstChild("CountLabel", true)
	return f and f.Text
end
function shown(element)
	return element ~= nil and element.Visible == true
end
