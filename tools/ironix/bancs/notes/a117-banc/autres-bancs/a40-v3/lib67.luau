--!nocheck
---------------------------------------------------------------- a67 : écrans de Clément (vague 23, relevé de Studio du 2026-11-11)
-- UI_Index_v3 : arbre du prototype tools/clement/index_v3.luau (build), noms de ui-index-v3.md.
-- UI_Settings : relevé d'agents/wave23-studio.md ; UI_HUD.SocialRow.SettingsButton caché.
-- Faux Roblox : pas de moteur de mise en page, AbsolutePosition / AbsoluteSize posés à la main.

V3_SECTIONS = V2_SECTIONS
V3_NAMES = { "MINI MART", "LONDON", "TOKYO", "L.A.", "PARIS", "NEW YORK", "SECRETS" }
V3_CLIP_SAMPLE = Color3.fromHex("b0b7c3")
V3_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("a8a8a8"))
V3_DETAIL_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("808080"))
V3_EFFECTS = { "Shiny", "Gold", "Neon", "Diamond", "Glitch", "Hacked", "Rainbow" }
V3_CLAIM_POS = UDim2.new(0.5, 0, 0.95, 0)
V3_CLAIM_ALL_POS = UDim2.new(0.985, 0, 0.5, 0) -- a117

-- Copie a117 (vague 34, L-127) : pastille « ! » cachée de Clément (Frame + UIScale Pulse).
function v3Alert(name, parent)
	local alert = make("Frame", { Name = name, Visible = false }, parent)
	make("UIScale", { Name = "Pulse", Scale = 1 }, alert)
	return alert
end

local function v3Button(name, props, parent)
	local button = make("TextButton", { Name = name, Text = "" }, parent)
	for k, v in props or {} do
		button[k] = v
	end
	make("Frame", { Name = "Shade", BackgroundTransparency = 1 }, button)
	return button
end

function buildIndexV3Gui(parent, options)
	options = options or {}
	local gui = make("ScreenGui", { Name = "UI_Index_v3", Enabled = false, ResetOnSpawn = false })
	gui:SetAttribute("ScreenGroup", "Menu")
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 0.69) }, gui)
	local window = make("Frame", { Name = "Window" }, root)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "Index" }, header)
	local close = v3Button("CloseButton", nil, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local panel = make("Frame", { Name = "ListPanel" }, window)
	local list = make("ScrollingFrame", {
		Name = "List",
		CanvasPosition = Vector2.new(0, 250),
		AbsolutePosition = Vector2.new(0, 100),
		AbsoluteWindowSize = Vector2.new(600, 400),
		AbsoluteCanvasSize = Vector2.new(600, 3000),
	}, panel)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local template = make("TextButton", { Name = "Template", Text = "", Visible = false }, list)
	local clip = make("Frame", { Name = "Clip", BackgroundColor3 = V3_CLIP_SAMPLE }, template)
	make("UIGradient", { Name = "UIGradient", Color = V3_GRADIENT }, clip)
	make("ImageLabel", { Name = "Glow", Image = "rbxassetid://130850617844067", ImageColor3 = Color3.new(1, 1, 1) }, clip)
	make("ImageLabel", { Name = "Rays", Image = "rbxassetid://110553518823718", ImageColor3 = Color3.new(1, 1, 1) }, clip)
	make("ImageLabel", { Name = "Icon", Image = "", ImageColor3 = Color3.new(1, 1, 1) }, template)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, template)
	make("Frame", { Name = "Lock", Visible = false }, template)
	make("Frame", { Name = "HoverOutline", Visible = false }, template)
	for index, name in V3_SECTIONS do
		local section = make("Frame", { Name = name, LayoutOrder = index, Visible = name ~= "SecretsSection", AbsolutePosition = Vector2.new(0, 100 + (index - 1) * 400) }, list)
		local art = make("ImageLabel", { Name = "ZoneArt" }, section)
		make("ImageLabel", { Name = "ZoneIcon" }, art)
		v3Alert("ZoneAlert", art) -- a117
		make("TextLabel", { Name = "ZoneName", Text = if options.emptyName == index then "" else V3_NAMES[index] }, art)
		local content = make("Frame", { Name = "Content" }, section)
		local cards = make("Frame", { Name = "Cards" }, content)
		make("UIGridLayout", { Name = "UIGridLayout" }, cards)
		local bar = make("Frame", { Name = "ZoneBar" }, content)
		make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1) }, bar)
		make("TextLabel", { Name = "ZoneCount", Text = "0/0" }, bar)
		make("ImageLabel", { Name = "ZoneItem", Image = "", ImageColor3 = Color3.new(1, 1, 1) }, bar)
	end
	local unlocked = make("Frame", { Name = "UnlockedBar" }, window)
	make("TextLabel", { Name = "Counter", Text = "Unlocked: 0/83" }, unlocked)
	-- a117 : Claim All (script alerts_claimall_build de Clément : copie du ClaimButton de UI_Offline).
	local claimAll = v3Button("ClaimAllButton", { Position = V3_CLAIM_ALL_POS }, unlocked)
	local claimAllContent = make("Frame", { Name = "Content" }, claimAll)
	make("TextLabel", { Name = "ClaimAllLabel", Text = "CLAIM ALL" }, claimAllContent)
	v3Alert("ClaimAllAlert", claimAll)
	make("ImageLabel", { Name = "BookIcon" }, window)
	local detail = make("Frame", { Name = "Detail", BackgroundColor3 = V3_CLIP_SAMPLE }, window)
	make("UIGradient", { Name = "UIGradient", Color = V3_DETAIL_GRADIENT }, detail)
	local iconFrame = make("Frame", { Name = "IconFrame" }, detail)
	make("ImageLabel", { Name = "DetailIcon", Image = "", ImageColor3 = Color3.new(1, 1, 1) }, iconFrame)
	make("TextLabel", { Name = "DetailName", Text = "???" }, detail)
	make("TextLabel", { Name = "DetailRarity", Text = "Common", TextColor3 = Color3.new(1, 1, 1) }, detail)
	make("TextLabel", { Name = "DetailIncome", Text = "???" }, detail)
	local rewards = make("Frame", { Name = "Rewards" }, window)
	make("TextLabel", { Name = "RewardsTitle", Text = "Rewards:" }, rewards)
	for _, spec in { { "SpeedReward", "+Speed" }, { "CashReward", "+Cash" } } do
		local tile = make("Frame", { Name = spec[1] }, rewards)
		make("ImageLabel", { Name = "Icon" }, tile)
		make("TextLabel", { Name = "Amount", Text = spec[2] }, tile)
	end
	local claim = v3Button("ClaimButton", { Position = V3_CLAIM_POS }, rewards)
	make("TextLabel", { Name = "ClaimLabel", Text = "Claim!" }, claim)
	v3Alert("ClaimAlert", claim) -- a117
	local categories = make("Frame", { Name = "Categories" }, root)
	for order, spec in { { "NormalButton", "NORMAL" }, { "SecretsButton", "SECRETS" }, { "MutationsButton", "MUTATIONS" } } do
		local button = v3Button(spec[1], { LayoutOrder = order }, categories)
		make("TextLabel", { Name = "Label", Text = spec[2] }, button)
		make("Frame", { Name = "Selected", Visible = order == 1 }, button)
		v3Alert("CategoryAlert", button) -- a117
	end
	make("ImageLabel", { Name = "StarIcon" }, categories.MutationsButton)
	local tabs = make("Frame", { Name = "MutationTabs", Visible = false }, root)
	for order, effect in V3_EFFECTS do
		local tab = v3Button(`{effect}Tab`, { LayoutOrder = order }, tabs)
		make("TextLabel", { Name = "TabLabel", Text = string.upper(effect) }, tab)
		make("Frame", { Name = "Selected", Visible = order == 1 }, tab)
	end
	make("TextLabel", { Name = "MutationCaption", Text = "Collect every item in SHINY!", Visible = false }, root)
	gui.Parent = parent
	return gui
end

function v3Cards(gui, sectionName)
	local out = {}
	local cards = gui.Root.Window.ListPanel.List[sectionName].Content.Cards
	for _, child in cards:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Item_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
function v3AllCards(gui)
	local n = 0
	for _, name in V3_SECTIONS do
		n += #v3Cards(gui, name)
	end
	return n
end
function v3CardOf(gui, sectionName, itemId)
	for _, card in v3Cards(gui, sectionName) do
		if string.match(card.Name, "^Item_%d+_(.+)$") == itemId then
			return card
		end
	end
	return nil
end

-- UI_HUD avec LeftRail (comme buildHud) et SocialRow : InviteButton, RewardsButton, SettingsButton (caché).
function buildHud67(playerGui)
	local gui = buildHud(nil)
	local social = make("Frame", { Name = "SocialRow" }, gui)
	for _, spec in { { "InviteButton", true }, { "RewardsButton", true }, { "SettingsButton", false } } do
		local button = make("TextButton", { Name = spec[1], Text = "", Visible = spec[2] }, social)
		make("ImageLabel", { Name = if spec[1] == "SettingsButton" then "SettingsIcon" else "Icon" }, button)
		make("Frame", { Name = "Shade", BackgroundTransparency = 1 }, button)
	end
	make("TextLabel", { Name = "SettingsLabel", Text = "SETTINGS" }, social.SettingsButton)
	gui.Parent = playerGui
	return gui
end

KNOB_POS = UDim2.new(0.8, 0, 0.5, 0)
TOGGLE_KNOB_POS = UDim2.new(0.97, 0, 0.5, 0)
TOGGLE_LABEL_POS = UDim2.new(0.08, 0, 0.5, 0)
function buildSettingsGui(parent)
	local gui = make("ScreenGui", { Name = "UI_Settings", Enabled = false, ResetOnSpawn = false })
	gui:SetAttribute("ScreenGroup", "Menu")
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, gui)
	make("Frame", { Name = "WindowShadow" }, root)
	local window = make("Frame", { Name = "Window" }, root)
	make("Frame", { Name = "Studs" }, window)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "Settings" }, header)
	local close = v3Button("CloseButton", nil, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local rows = make("Frame", { Name = "Rows" }, window)
	make("UIListLayout", { Name = "UIListLayout" }, rows)
	for order, spec in { { "MusicRow", "MUSIC", "80%", 400 }, { "SoundRow", "SOUND EFFECTS", "100%", 500 } } do
		local row = make("Frame", { Name = spec[1], LayoutOrder = order }, rows)
		make("TextLabel", { Name = "RowLabel", Text = spec[2] }, row)
		make("TextLabel", { Name = "ValueLabel", Text = spec[3] }, row)
		make("ImageLabel", { Name = "Icon" }, row)
		local slider = make("Frame", { Name = "Slider" }, row)
		local track = make("TextButton", { Name = "Track", Text = "", AbsolutePosition = Vector2.new(100, spec[4]), AbsoluteSize = Vector2.new(200, 20) }, slider)
		make("Frame", { Name = "Fill", Size = UDim2.new(0.8, 0, 1, 0) }, track)
		make("TextButton", { Name = "Knob", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = KNOB_POS }, slider)
	end
	local vfx = make("Frame", { Name = "VfxRow", LayoutOrder = 4 }, rows)
	make("TextLabel", { Name = "RowLabel", Text = "VISUAL EFFECTS" }, vfx)
	make("ImageLabel", { Name = "Icon" }, vfx)
	local toggle = v3Button("Toggle", nil, vfx)
	make("TextLabel", { Name = "ToggleLabel", Text = "ON", AnchorPoint = Vector2.new(0, 0.5), Position = TOGGLE_LABEL_POS }, toggle)
	make("Frame", { Name = "OnFill", Visible = true }, toggle)
	make("Frame", { Name = "OffFill", Visible = false }, toggle)
	make("Frame", { Name = "ToggleKnob", AnchorPoint = Vector2.new(1, 0.5), Position = TOGGLE_KNOB_POS }, toggle)
	local click = make("Frame", { Name = "ClickRow", LayoutOrder = 3 }, rows)
	make("TextLabel", { Name = "RowLabel", Text = "CLICK SOUND" }, click)
	make("TextLabel", { Name = "ChoiceLabel", Text = "CLASSIC" }, click)
	make("ImageLabel", { Name = "Icon" }, click)
	for _, spec in { { "PrevButton", "<" }, { "NextButton", ">" } } do
		local button = v3Button(spec[1], nil, click)
		make("TextLabel", { Name = "ArrowLabel", Text = spec[2] }, button)
	end
	-- a162 (2026-11-14, ajout pur) : champ de code cadeau et compte à rebours, facultatifs au contrat.
	local code = make("Frame", { Name = "CodeRow", LayoutOrder = 5 }, rows)
	make("TextBox", { Name = "CodeBox", Text = "" }, code)
	v3Button("RedeemButton", nil, code)
	make("TextLabel", { Name = "CodeStatus", Text = "" }, code)
	make("TextLabel", { Name = "UpdateCountdown", Text = "" }, window)
	gui.Parent = parent
	return gui
end

-- Sons de Clément : ReplicatedStorage/Assets/Sounds/UI/Clicks/UI_Click_<Id>, et UI/UI_Deny.
function buildClickSounds()
	local sounds = ASSETS:FindFirstChild("Sounds") or folder(ASSETS, "Sounds")
	local ui = sounds:FindFirstChild("UI") or folder(sounds, "UI")
	local clicks = ui:FindFirstChild("Clicks") or folder(ui, "Clicks")
	for _, id in { "Classic", "Sharp", "Tick", "Bubble", "Soft" } do
		make("Sound", { Name = `UI_Click_{id}`, Volume = 0.5 }, clicks)
	end
	make("Sound", { Name = "UI_Deny", Volume = 0.5 }, ui)
end

-- Motion.Pop noté (objet, départ) sans rien changer à son effet.
POPS = {}
function watchPops()
	local Motion = requireModule(CONTROLLERS.UI.Motion, "client")
	local pop = Motion.Pop
	Motion.Pop = function(object, from, info)
		table.insert(POPS, { name = object.Name, object = object, from = from })
		return pop(object, from, info)
	end
	local sounds = {}
	Motion.SetSoundPlayer(function(name)
		table.insert(sounds, name)
	end)
	return sounds
end
function popsOf(name, from)
	local n = 0
	for _, entry in POPS do
		if entry.name == name and (from == nil or entry.from == from) then
			n += 1
		end
	end
	return n
end
