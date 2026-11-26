--!nonstrict
--[[
	uifx_float.luau : aperçu de l'effet Float (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : l'élément flotte doucement de haut en bas, sans fin.
	Attribut proposé : Idle = "Float" (nouvelle valeur de notre attribut Idle).
	Durée, courbe (V0) : ± 4 px, cycle de 2,4 s (Sine InOut). Continu.
	Propriété animée : Position (Offset Y), autour de la Position posée par Clément. Dans un UIListLayout ou
	UIGridLayout, Position est ignorée : faire flotter un enfant (l'icône), pas la case.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(gui, options) ; stop() arrête et remet la Position d'origine.
	Tout ce qui tourne seul s'arrête quand l'élément n'est pas affiché (à brancher côté contrôleur).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Float dans CoreGui, joue
	3 cycles, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Amplitude = 4, -- px
	Cycle = 2.4, -- s : un aller-retour complet
}

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local home = gui.Position
	local up = home + UDim2.fromOffset(0, -o.Amplitude)
	local down = home + UDim2.fromOffset(0, o.Amplitude)
	local quarter = o.Cycle / 4
	local loop
	-- départ en douceur vers le haut, puis aller-retour haut ↔ bas sans fin
	local start = TweenService:Create(gui, TweenInfo.new(quarter, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = up })
	start.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or not gui.Parent then return end
		loop = TweenService:Create(gui, TweenInfo.new(o.Cycle / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = down })
		loop:Play()
	end)
	start:Play()
	return function()
		start:Cancel()
		if loop then loop:Cancel() end
		if gui.Parent then gui.Position = home end
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
	local NAME = "_UIFX_PREVIEW_Float"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = grayButton(sg, "Float", UDim2.fromScale(0.5, 0.5))
		local home = b.Position
		local stop = play(b)
		task.wait(DEFAULTS.Cycle * 3)
		stop()
		assert(b.Position == home, "position non remise")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_float : aperçu joué, " .. NAME .. " détruit")
end
