--!nonstrict
--[[
	uifx_pulse.luau : aperçu de l'effet Pulse (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : l'élément gonfle et dégonfle comme un battement de cœur (bouton à réclamer, alerte).
	Attribut proposé : Idle = "Pulse" (nouvelle valeur de notre attribut Idle).
	Durée, courbe (V0 du catalogue) : deux battements rapprochés × 1,08 (0,12 s chacun, Quad Out à la montée,
	Quad In à la descente), puis pause ; un cycle complet dure 1,2 s. Continu.
	Propriété animée : UIScale.Scale (UIScale existant de l'élément, sinon un UIScale « FxScale » créé).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(guiObject, options) ; stop() arrête et remet l'échelle d'origine.
	Aperçu : coller dans la barre de commande de Studio en Edit. Construit _UIFX_PREVIEW_Pulse dans CoreGui,
	joue 3 cycles, puis détruit tout (rien n'est écrit dans la place).
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Scale = 1.08, -- taille au sommet du battement
	Beat = 0.12, -- s : durée d'un battement (montée + descente)
	Beats = 2, -- battements rapprochés par cycle
	Cycle = 1.2, -- s : durée d'un cycle complet, pause comprise
}

local function getScale(gui)
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = gui
	end
	return s
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local uiScale = getScale(gui)
	local base = uiScale.Scale
	local running = true
	local current

	local function tweenTo(value, time, dir)
		current = TweenService:Create(uiScale, TweenInfo.new(time, Enum.EasingStyle.Quad, dir), { Scale = value })
		current:Play()
		task.wait(time)
	end

	task.spawn(function()
		while running do
			local start = os.clock()
			for _ = 1, o.Beats do
				if not running then break end
				tweenTo(base * o.Scale, o.Beat / 2, Enum.EasingDirection.Out)
				if not running then break end
				tweenTo(base, o.Beat / 2, Enum.EasingDirection.In)
			end
			local rest = o.Cycle - (os.clock() - start)
			if rest > 0 and running then task.wait(rest) end
		end
	end)

	return function()
		running = false
		if current then current:Cancel() end
		if uiScale.Parent then uiScale.Scale = base end
	end
end

-- APERÇU -------------------------------------------------------------------------------------------------
do
	local NAME = "_UIFX_PREVIEW_Pulse"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name = NAME
	sg.ResetOnSpawn = false
	sg.Parent = CoreGui

	local ok, err = pcall(function()
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.fromOffset(220, 64)
		b.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.TextSize = 22
		b.TextColor3 = Color3.fromRGB(13, 13, 20)
		b.Text = "Pulse"
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = b
		b.Parent = sg

		local stop = play(b)
		task.wait(DEFAULTS.Cycle * 3)
		stop()
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_pulse : aperçu joué, " .. NAME .. " détruit")
end
