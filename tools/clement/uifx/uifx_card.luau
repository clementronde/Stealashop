--!nonstrict
--[[
	uifx_card.luau : aperçu de l'effet Card (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : une fiche d'info apparaît à côté du bouton survolé (détail d'un objet, d'un gamepass),
	en sortant de lui ; elle repart quand la souris s'en va.
	Attribut proposé : HoverCard = "<nom du cadre fiche>" sur le bouton ; le cadre fiche est dessiné et caché
	par Clément dans le même écran (le code le cherche par son nom dans le ScreenGui du bouton).
	Durée, courbe (V0) : entrée 0,85 → 1 en 0,12 s (Back Out), en partant de 6 px plus près du bouton ;
	sortie en 0,08 s (Quad In) vers 0,85 et 6 px, puis Visible = false. Sur téléphone : appui long.
	Propriétés animées : Visible, UIScale.Scale (UIScale existant, sinon « FxScale ») et Position de la fiche
	(revient à la Position posée par Clément).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(button, { on = true }) au MouseEnter, play(button, { on = false }) au MouseLeave ;
	options.card force le cadre fiche sans lire HoverCard. Renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Card dans CoreGui (un bouton
	et sa fiche cachée), joue 3 survols, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	From = 0.85, -- échelle de départ
	Shift = 6, -- px : la fiche part de ce décalage vers le bouton
	InTime = 0.12, -- s, Back Out
	OutTime = 0.08, -- s, Quad In
}

local HOME = setmetatable({}, { __mode = "k" })
local TOKEN = setmetatable({}, { __mode = "k" })

local function findCard(button, o)
	if o.card then return o.card end
	local name = button:GetAttribute("HoverCard")
	local root = button:FindFirstAncestorWhichIsA("LayerCollector")
	return name and root and root:FindFirstChild(name, true) or nil
end

local function play(button, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local card = findCard(button, o)
	if not card then return 0 end
	local on = o.on ~= false
	local s = card:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = card
	end
	local home = HOME[card] or card.Position
	HOME[card] = home
	local n = (TOKEN[card] or 0) + 1
	TOKEN[card] = n

	-- décalage de 6 px vers le bouton (centre à centre)
	local wasVisible = card.Visible
	card.Visible = true
	local dir = (button.AbsolutePosition + button.AbsoluteSize / 2) - (card.AbsolutePosition + card.AbsoluteSize / 2)
	dir = dir.Magnitude > 0 and dir.Unit * o.Shift or Vector2.zero
	local near = home + UDim2.fromOffset(dir.X, dir.Y)

	if on then
		if not wasVisible then
			s.Scale = o.From
			card.Position = near
		end
		local info = TweenInfo.new(o.InTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(s, info, { Scale = 1 }):Play()
		TweenService:Create(card, info, { Position = home }):Play()
		return o.InTime
	end
	card.Visible = wasVisible
	if not wasVisible then return 0 end
	local info = TweenInfo.new(o.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(s, info, { Scale = o.From }):Play()
	local out = TweenService:Create(card, info, { Position = near })
	out.Completed:Once(function(state)
		-- revenue entre-temps (tween annulé ou nouveau survol) : on ne cache rien
		if state ~= Enum.PlaybackState.Completed or TOKEN[card] ~= n then return end
		card.Visible = false
		card.Position = home
		s.Scale = 1
	end)
	out:Play()
	return o.OutTime
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

do
	local NAME = "_UIFX_PREVIEW_Card"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = new("TextButton", {
			Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5),
			Size = UDim2.fromOffset(120, 120), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Item",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		b:SetAttribute("HoverCard", "ItemCard")
		b.Parent = sg
		local card = new("Frame", {
			Name = "ItemCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.42, 76, 0.5, 0),
			Size = UDim2.fromOffset(200, 120), BackgroundColor3 = Color3.fromRGB(190, 190, 190), Visible = false,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, card)
		new("TextLabel", {
			Name = "Title", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			TextSize = 20, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Golden Crown\n$120/s",
		}, card)
		card.Parent = sg
		local home = card.Position
		task.wait()
		for _ = 1, 3 do
			task.wait(play(b, { on = true }) + 0.6)
			task.wait(play(b, { on = false }) + 0.35)
		end
		assert(not card.Visible and card.Position == home, "fiche non remise")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_card : aperçu joué, " .. NAME .. " détruit")
end
