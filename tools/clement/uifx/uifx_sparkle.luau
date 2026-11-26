--!nonstrict
--[[
	uifx_sparkle.luau : aperçu de l'effet Sparkle (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : des petites étoiles naissent autour de l'élément, tournent et s'éteignent, sans fin.
	Attribut proposé : Idle = "Sparkle" (nouvelle valeur de notre attribut Idle ; aussi au survol ou à un
	moment du jeu, en appelant play puis stop).
	Étoile : faite de deux barres blanches croisées (Frames natives, UICorner), sans texture ; options.image
	la remplace par une image d'étoile de Clément (aucune dans nos textures au 25/11).
	Durée, courbe (V0) : chaque étoile 0 → 1 en 0,3 s (Back Out) puis 1 → 0 en 0,3 s (Quad In), + 90° de
	rotation sur ses 0,6 s ; une nouvelle toutes les 0,3 s, posée au hasard sur l'élément et un peu autour.
	Propriétés animées : UIScale.Scale et Rotation de chaque étoile « FxSparkle » (enfant de l'élément,
	détruite à la fin). Si l'élément coupe ses enfants (ClipsDescendants), les étoiles du bord sont coupées.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(gui, options) ; stop() arrête et retire les étoiles restantes.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Sparkle dans CoreGui, joue
	environ 3 s d'étoiles, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Every = 0.3, -- s entre deux étoiles
	Life = 0.6, -- s de vie d'une étoile
	Spin = 90, -- degrés sur sa vie
	MinSize = 14, -- px
	MaxSize = 26, -- px
	Spread = 0.1, -- part de la taille de l'élément au-delà de ses bords
	Color = Color3.new(1, 1, 1),
	image = nil, -- rbxassetid d'une étoile, sinon deux barres croisées
}

local function makeStar(o, size)
	local star
	if o.image then
		star = Instance.new("ImageLabel")
		star.Image = o.image
		star.ImageColor3 = o.Color
	else
		star = Instance.new("Frame")
		for _, s in { UDim2.fromScale(1, 0.2), UDim2.fromScale(0.2, 1) } do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = s
			bar.BackgroundColor3 = o.Color
			bar.BorderSizePixel = 0
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = bar
			bar.Parent = star
		end
	end
	star.Name = "FxSparkle"
	star.BackgroundTransparency = 1
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Size = UDim2.fromOffset(size, size)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = star
	return star, scale
end

local function spawnStar(gui, o, rng)
	local size = rng:NextNumber(o.MinSize, o.MaxSize)
	local star, scale = makeStar(o, size)
	local x = rng:NextNumber(-o.Spread, 1 + o.Spread)
	local y = rng:NextNumber(-o.Spread, 1 + o.Spread)
	star.Position = UDim2.fromScale(x, y)
	local rot = rng:NextNumber(0, 90)
	star.Rotation = rot
	star.ZIndex = gui.ZIndex + 5
	for _, d in star:GetChildren() do
		if d:IsA("GuiObject") then d.ZIndex = star.ZIndex end
	end
	star.Parent = gui
	local half = o.Life / 2
	TweenService:Create(star, TweenInfo.new(o.Life, Enum.EasingStyle.Linear), { Rotation = rot + o.Spin }):Play()
	local grow = TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	grow.Completed:Once(function()
		if not star.Parent then return end
		local shrink = TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		shrink.Completed:Once(function() star:Destroy() end)
		shrink:Play()
	end)
	grow:Play()
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local rng = Random.new()
	local running = true
	task.spawn(function()
		while running and gui.Parent do
			spawnStar(gui, o, rng)
			task.wait(o.Every)
		end
	end)
	return function()
		running = false
		for _, c in gui:GetChildren() do
			if c.Name == "FxSparkle" then c:Destroy() end
		end
	end
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local most = 0
do
	local NAME = "_UIFX_PREVIEW_Sparkle"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = new("TextButton", {
			Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Legendary",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		b.Parent = sg
		local stop = play(b)
		local t0 = os.clock()
		while os.clock() - t0 < 3 do
			local count = 0
			for _, c in b:GetChildren() do if c.Name == "FxSparkle" then count += 1 end end
			most = math.max(most, count)
			task.wait(0.05)
		end
		stop()
		assert(not b:FindFirstChild("FxSparkle"), "étoile restée")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_sparkle : aperçu joué, " .. NAME .. " détruit")
end
