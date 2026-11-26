--!nonstrict
--[[
	uifx_hold.luau : aperçu de l'effet Hold (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : dans notre invite BB_Prompt, une barre se remplit pendant qu'on tient la touche,
	se vide si on lâche trop tôt, et la carte fait un petit sursaut quand l'action part.
	Attribut : aucun nouvel attribut ; élément HoldFill (dans Card > HoldBar du modèle BB_Prompt, voir
	uifx_prompt.luau). HoldFill est ancré à gauche, sa largeur en Scale va de 0 à 1.
	Durée, courbe : remplie en HoldDuration de l'invite (Linear, reprend où elle en est) ; vidée en 0,2 s
	(Quad Out) si on lâche ; à la fin (Triggered), la carte × 1,15 → 1 en 0,15 s (Quad Out). Une fois par appui.
	Propriétés animées : HoldFill.Size (X en Scale) ; UIScale.Scale de la carte (UIScale existant, sinon
	« FxScale »). Variante en anneau (UIGradient.Transparency d'un UIStroke) non faite ici.

	Branchement côté Ironix (client) : prompt.PromptButtonHoldBegan -> play(fill, { phase = "Begin",
	HoldDuration = prompt.HoldDuration }) ; PromptButtonHoldEnded -> "End" ; prompt.Triggered ->
	play(fill, { phase = "Done", card = card }).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(fill, { phase = "Begin" | "End" | "Done", HoldDuration = s, card = Card }) ; renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Hold dans CoreGui (la carte dans
	un ScreenGui, car l'aperçu ne touche pas au Workspace) ; tient jusqu'au bout, lâche à mi-chemin, puis
	tient jusqu'au bout encore, et détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	HoldDuration = 1, -- s : remplacé par prompt.HoldDuration
	DrainTime = 0.2, -- s, Quad Out
	Bump = 1.15, -- sursaut de la carte à la fin
	BumpTime = 0.15, -- s, Quad Out
}

local CURRENT = setmetatable({}, { __mode = "k" })

local function getScale(gui)
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = gui
	end
	return s
end

local function tweenFill(fill, x, info)
	if CURRENT[fill] then CURRENT[fill]:Cancel() end
	local t = TweenService:Create(fill, info, { Size = UDim2.new(x, 0, fill.Size.Y.Scale, fill.Size.Y.Offset) })
	CURRENT[fill] = t
	t:Play()
end

local function play(fill, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local phase = o.phase or "Begin"
	local now = fill.Size.X.Scale
	if phase == "Begin" then
		local time = math.max(o.HoldDuration * (1 - now), 0)
		tweenFill(fill, 1, TweenInfo.new(time, Enum.EasingStyle.Linear))
		return time
	elseif phase == "End" then
		tweenFill(fill, 0, TweenInfo.new(o.DrainTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		return o.DrainTime
	end
	-- "Done"
	if CURRENT[fill] then CURRENT[fill]:Cancel() end
	fill.Size = UDim2.new(1, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
	if o.card then
		local s = getScale(o.card)
		s.Scale = o.Bump
		TweenService:Create(s, TweenInfo.new(o.BumpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	return o.BumpTime
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local INK = Color3.fromRGB(13, 13, 20)

local function promptCard(parent)
	local card = new("Frame", {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 84), BackgroundColor3 = Color3.fromRGB(150, 150, 150),
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, card)
	new("UIStroke", { Thickness = 3, Color = INK }, card)
	new("TextLabel", {
		Name = "Action", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = INK, Text = "[E] Steal",
	}, card)
	local bar = new("Frame", {
		Name = "HoldBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 16), BackgroundColor3 = Color3.fromRGB(95, 95, 95),
	})
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, bar)
	local fill = new("Frame", {
		Name = "HoldFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(235, 235, 235),
	})
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	fill.Parent = bar
	bar.Parent = card
	card.Parent = parent
	return card, fill
end

do
	local NAME = "_UIFX_PREVIEW_Hold"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local card, fill = promptCard(sg)
		-- 1) tenu jusqu'au bout
		task.wait(play(fill, { phase = "Begin", HoldDuration = 1 }))
		task.wait(play(fill, { phase = "Done", card = card }) + 0.4)
		assert(fill.Size.X.Scale == 1, "barre pas pleine")
		fill.Size = UDim2.fromScale(0, 1)
		-- 2) lâché à mi-chemin
		play(fill, { phase = "Begin", HoldDuration = 1 })
		task.wait(0.5)
		task.wait(play(fill, { phase = "End" }) + 0.4)
		assert(fill.Size.X.Scale < 0.01, "barre pas vidée")
		-- 3) tenu jusqu'au bout encore
		task.wait(play(fill, { phase = "Begin", HoldDuration = 1 }))
		task.wait(play(fill, { phase = "Done", card = card }) + 0.4)
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_hold : aperçu joué, " .. NAME .. " détruit")
end
