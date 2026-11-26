--!nonstrict
--[[
	uifx_shake.luau : aperçu de l'effet Shake (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : une secousse courte et amortie de gauche à droite (refus d'achat, pas assez
	d'argent) ; en option, répétée par moments.
	Attribut proposé : Idle = "Shake" (par moments) ; et Motion.Shake commun à tous les refus d'achat
	(aujourd'hui joué par l'arbre de compétences seulement).
	Durée, courbe : ± 6 px, 4 allers-retours en 0,3 s, Quad Out, amplitude qui baisse à chaque aller,
	retour exact à la place (valeurs de Config/UiMotion.Shake). Par moments : toutes les 4 s (V0).
	Propriété animée : Position (Offset X). Dans un UIListLayout ou UIGridLayout, Position est ignorée :
	secouer alors un enfant (par exemple le contenu de la carte), pas la carte.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(gui) secoue une fois (renvoie la durée) ; play(gui, { Every = 4 }) secoue toutes les 4 s
	et renvoie stop(). Une secousse relancée pendant la précédente repart de la vraie place.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Shake dans CoreGui, joue
	3 secousses, puis 2 par moments, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Amplitude = 6, -- px
	Count = 4, -- allers-retours
	Time = 0.3, -- s
	Every = nil, -- s : nil = une seule secousse
}

local HOME = setmetatable({}, { __mode = "k" }) -- vraie place pendant une secousse
local TOKEN = setmetatable({}, { __mode = "k" })

local function shakeOnce(gui, o)
	local home = HOME[gui] or gui.Position
	HOME[gui] = home
	local n = (TOKEN[gui] or 0) + 1
	TOKEN[gui] = n
	local steps = o.Count * 2
	local dt = o.Time / (steps + 1)
	local info = TweenInfo.new(dt, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.spawn(function()
		for i = 1, steps + 1 do
			if TOKEN[gui] ~= n or not gui.Parent then return end
			local offset = 0
			if i <= steps then
				local sign = (i % 2 == 1) and 1 or -1
				offset = sign * o.Amplitude * (1 - (i - 1) / steps)
			end
			TweenService:Create(gui, info, { Position = home + UDim2.fromOffset(offset, 0) }):Play()
			task.wait(dt)
		end
		if TOKEN[gui] == n then
			gui.Position = home
			HOME[gui] = nil
		end
	end)
	return o.Time
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	if not o.Every then return shakeOnce(gui, o) end
	local running = true
	task.spawn(function()
		while running and gui.Parent do
			shakeOnce(gui, o)
			task.wait(o.Every)
		end
	end)
	return function()
		running = false
		TOKEN[gui] = (TOKEN[gui] or 0) + 1
		if HOME[gui] then
			gui.Position = HOME[gui]
			HOME[gui] = nil
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

local function grayButton(parent, text, pos)
	local b = new("TextButton", {
		Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = text,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
	b.Parent = parent
	return b
end

do
	local NAME = "_UIFX_PREVIEW_Shake"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local a = grayButton(sg, "Refus", UDim2.fromScale(0.4, 0.5))
		local b = grayButton(sg, "Par moments", UDim2.fromScale(0.6, 0.5))
		local home = a.Position
		for _ = 1, 3 do
			play(a)
			task.wait(0.6)
		end
		play(a)
		task.wait(0.1)
		play(a) -- relancée en pleine secousse
		task.wait(0.5)
		assert(a.Position == home, "le bouton n'est pas revenu à sa place")
		local stop = play(b, { Every = 1 })
		task.wait(2.2)
		stop()
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_shake : aperçu joué, " .. NAME .. " détruit")
end
