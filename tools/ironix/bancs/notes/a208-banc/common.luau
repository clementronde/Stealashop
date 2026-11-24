--!nocheck
-- Banc a208 (vague 63) : UI_RobuxShop_v2 (L-200, L-204). Ajouts au faux Roblox d'a39 (stubs d'a164) :
-- ScrollingFrame est un GuiObject, PolicyService (POLICY : réponse, erreur, nombre d'appels), une fausse
-- lueur d'achat (Controllers/UI/PurchaseGlow d'a209 : GLOW.calls), et l'écran v2 tel que la maquette de
-- Clément le décrit (Contract/UI : sections Grid + Template, Featured, Crate, Tabs, List).
SUPER.ScrollingFrame = { "GuiObject", "GuiBase2d" }

POLICY = { calls = 0, restricted = false, fail = false }
do
	local base = games.client
	local policyService = {
		GetPolicyInfoForPlayerAsync = function(_, player)
			POLICY.calls += 1
			if POLICY.fail then
				error("HTTP 500 (faux PolicyService)")
			end
			return { ArePaidRandomItemsRestricted = POLICY.restricted }
		end,
	}
	games.client = {
		GetService = function(_, name)
			if name == "PolicyService" then
				return policyService
			end
			return base:GetService(name)
		end,
		IsLoaded = function()
			return true
		end,
		Loaded = base.Loaded,
	}
end

GLOW = { calls = 0 }
SOURCES["a208/PurchaseGlow"] = "return { Show = function() GLOW.calls += 1 end }"
function addGlow()
	moduleScript(CONTROLLERS:FindFirstChild("UI"), "PurchaseGlow", "a208/PurchaseGlow")
end

---------------------------------------------------------------- écran v2
TEMPLATE_COLOR = Color3.fromHex("3A7BD5") -- CardColor posé par Clément sur chaque Template
TEMPLATE_LIGHT = Color3.fromHex("3A7BD5"):Lerp(Color3.new(1, 1, 1), 0.4)
-- Haut des blocs dans List (pixels, liste en haut) : la caisse, le pack de départ, puis les sections.
V2_OFFSETS = { Crate = 0, Featured = 300, GamepassesSection = 600, BoostsSection = 1100, CashSection = 1500 }
V2_LIST_TOP = 100
local function makeV2Card(parent, name, visible, withOwned)
	local frame = make("Frame", { Name = name, Visible = visible, Size = UDim2.fromScale(1, 1) }, parent)
	frame:SetAttribute("CardColor", TEMPLATE_COLOR)
	make("UIGradient", { Name = "UIGradient", Color = ColorSequence.new(TEMPLATE_COLOR, TEMPLATE_LIGHT) }, frame)
	make("ImageLabel", { Name = "Studs", ImageColor3 = TEMPLATE_COLOR }, frame)
	make("Frame", { Name = "CardShadow" }, frame)
	local icon = make("ImageLabel", { Name = "Icon", Image = "rbxassetid://1" }, frame)
	icon:SetAttribute("IconAsset", "UI_Icon_GP_x2Cash")
	make("TextLabel", { Name = "ItemName", Text = "Sample" }, frame)
	make("TextLabel", { Name = "Effect", Text = "SAMPLE EFFECT", Visible = false }, frame)
	local buy = make("TextButton", { Name = "BuyButton", Text = "" }, frame)
	local content = make("Frame", { Name = "Content" }, buy)
	make("ImageLabel", { Name = "RobuxIcon" }, content)
	make("TextLabel", { Name = "Price", Text = "0" }, content)
	if withOwned then
		local owned = make("Frame", { Name = "Owned", Visible = false }, frame)
		make("TextLabel", { Name = "OwnedLabel", Text = "OWNED" }, owned)
	end
	return frame
end
-- Section : rapport 2 (hauteur 0,5 largeur), Grid à 60 % de haut, une rangée de cartes (Columns = 3).
local function makeV2Section(content, name, withOwned)
	local frame = make("Frame", { Name = name, Size = UDim2.fromScale(1, 0) }, content)
	make("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint", AspectRatio = 2 }, frame)
	local header = make("Frame", { Name = "Header", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.3) }, frame)
	make("Frame", { Name = "Line" }, header)
	local grid = make("Frame", { Name = "Grid", Position = UDim2.fromScale(0, 0.35), Size = UDim2.fromScale(1, 0.6) }, frame)
	grid:SetAttribute("Columns", 3)
	make("UIGridLayout", {
		Name = "UIGridLayout",
		CellSize = UDim2.fromScale(0.3, 1),
		CellPadding = UDim2.fromScale(0.02, 0.1),
		FillDirectionMaxCells = 0,
	}, grid)
	makeV2Card(grid, "Template", false, withOwned)
	makeV2Card(grid, "Preview_1", true, withOwned)
	makeV2Card(grid, "Preview_2", true, withOwned)
	return frame
end
-- Positions à l'écran des blocs selon le défilement (Roblox les recalcule ; ici à la main).
function layoutV2(gui)
	local list = gui:FindFirstChild("List", true)
	for name, offset in V2_OFFSETS do
		local block = list:FindFirstChild(name, true)
		block.AbsolutePosition = Vector2.new(0, V2_LIST_TOP + offset - list.CanvasPosition.Y)
	end
end
function buildRobuxShopV2(parent)
	local gui = make("ScreenGui", { Name = "UI_RobuxShop_v2", Enabled = false, ResetOnSpawn = false })
	local root = make("Frame", { Name = "Root" }, gui)
	local window = make("Frame", { Name = "Window" }, root)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local tabs = make("Frame", { Name = "Tabs" }, window)
	for _, name in { "OffersTab", "GamepassesTab", "CashTab", "BoostsTab" } do
		local tab = make("TextButton", { Name = name, Text = "" }, tabs)
		make("TextLabel", { Name = "TabLabel", Text = string.upper((string.gsub(name, "Tab$", ""))) }, tab)
	end
	local list = make("ScrollingFrame", {
		Name = "List",
		AbsolutePosition = Vector2.new(0, V2_LIST_TOP),
		CanvasPosition = Vector2.new(0, 0),
		AbsoluteCanvasSize = Vector2.new(0, 2600),
		AbsoluteWindowSize = Vector2.new(0, 500),
		CanvasSize = UDim2.new(0, 0, 0, 0), -- a238 : CanvasSize (canvas ajusté au contenu)
	}, window)
	local content = make("Frame", { Name = "Content", Size = UDim2.fromScale(1, 0), AbsoluteSize = Vector2.new(400, 1600) }, list) -- a238 : AbsoluteSize (canvas ajusté au contenu)
	make("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint", AspectRatio = 0.25 }, content)
	make("UIListLayout", { Name = "UIListLayout", Padding = UDim.new(0.01, 0) }, content)
	-- Caisse exclusive (L-204) : trois lots, six chances.
	local crate = make("Frame", { Name = "Crate", Size = UDim2.fromScale(1, 0) }, content)
	make("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint", AspectRatio = 1.5 }, crate)
	make("TextLabel", { Name = "Title", Text = "EXCLUSIVE CRATE" }, crate)
	for index = 1, 6 do
		local odd = make("Frame", { Name = `Odd_{index}` }, crate)
		make("ImageLabel", { Name = "Icon" }, odd)
		make("TextLabel", { Name = "Chance", Text = "?%" }, odd)
	end
	local row = make("Frame", { Name = "BuyRow" }, crate)
	for index = 1, 3 do
		local button = make("TextButton", { Name = `BuyButton{index}`, Text = "" }, row)
		make("TextLabel", { Name = "Count", Text = "x Crates" }, button)
		make("TextLabel", { Name = "OldPrice", Text = "000" }, button)
		local priceRow = make("Frame", { Name = "Content" }, button)
		make("ImageLabel", { Name = "RobuxIcon" }, priceRow)
		make("TextLabel", { Name = "Price", Text = "0" }, priceRow)
	end
	-- Pack de départ (Featured).
	local featured = make("Frame", { Name = "Featured", Size = UDim2.fromScale(1, 0) }, content)
	make("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint", AspectRatio = 2.5 }, featured)
	make("TextLabel", { Name = "ItemName", Text = "Starter Pack" }, featured)
	local timer = make("Frame", { Name = "Timer" }, featured)
	make("ImageLabel", { Name = "ClockIcon" }, timer)
	make("TextLabel", { Name = "Label", Text = "Ends in 0:00" }, timer)
	local perks = make("Frame", { Name = "Perks" }, featured)
	for index = 1, 3 do
		make("TextLabel", { Name = `Perk{index}`, Text = "Perk" }, perks)
	end
	local featuredBuy = make("TextButton", { Name = "BuyButton", Text = "" }, featured)
	local featuredPrice = make("Frame", { Name = "Content" }, featuredBuy)
	make("TextLabel", { Name = "Price", Text = "0" }, featuredPrice)
	makeV2Section(content, "GamepassesSection", true)
	makeV2Section(content, "BoostsSection", false)
	makeV2Section(content, "CashSection", false)
	gui.Parent = parent
	layoutV2(gui)
	return gui
end
function v2El(gui, path)
	local current = gui
	for segment in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(segment, true)
	end
	return current
end
-- Clés des cartes clonées d'une section, dans l'ordre (LayoutOrder).
function v2Keys(gui, sectionName)
	local grid = v2El(gui, sectionName .. ".Grid")
	local cards = {}
	for _, child in grid:GetChildren() do
		if string.sub(child.Name, 1, 6) == "Offer_" then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local out = {}
	for _, card in cards do
		table.insert(out, (string.gsub(card.Name, "^Offer_", "")))
	end
	return table.concat(out, ",")
end
function v2Card(gui, key)
	return gui:FindFirstChild("Offer_" .. key, true)
end
function previewsLeft(gui)
	local n = 0
	for _, d in gui:GetDescendants() do
		if string.sub(d.Name, 1, 8) == "Preview_" then
			n += 1
		end
	end
	return n
end
-- Clic sur un onglet, puis positions recalculées ; renvoie le haut de la liste (CanvasPosition.Y).
function clickTab(gui, name)
	click(v2El(gui, "Tabs." .. name))
	advance(0.5)
	layoutV2(gui)
	return v2El(gui, "List").CanvasPosition.Y
end
