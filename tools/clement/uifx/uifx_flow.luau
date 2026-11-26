--!nonstrict
--[[
	uifx_flow.luau : aperçu de l'effet Flow (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : les couleurs de l'arc-en-ciel coulent dans le fond, dans le contour, ou les deux.
	Attribut proposé : Idle = "Flow" (nouvelle valeur de notre attribut Idle) ; options.mode = "Fill"
	(fond), "Stroke" (contour) ou "Both".
	Durée, courbe : un tour complet des couleurs en 3 s (Linear). Continu.
	Propriété animée : UIGradient.Color d'un UIGradient « FlowGradient » (sur l'élément pour le fond, sous
	son UIStroke pour le contour), dont les couleurs tournent à chaque image. Le dégradé multiplie la couleur
	de Clément : sur un fond blanc ou très clair, l'arc-en-ciel est franc ; sur un fond foncé, il fonce.
	Sans UIStroke, le mode « Stroke » crée un contour « FlowStroke » de 4 px.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(gui, { mode = "Both" }) ; stop() arrête et retire ce que le code a créé.
	Tout ce qui tourne seul s'arrête quand l'élément n'est pas affiché (à brancher côté contrôleur).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Flow dans CoreGui (trois
	boutons : fond, contour, les deux), joue 3 tours, puis détruit tout.
]]

local RunService = game:GetService("RunService")

local DEFAULTS = {
	mode = "Fill", -- "Fill" | "Stroke" | "Both"
	Cycle = 3, -- s pour un tour des couleurs
	Keys = 8, -- points du dégradé
	Saturation = 0.6,
	Value = 1,
	Rotation = 0, -- degrés du dégradé
	StrokeThickness = 4, -- px, si le code crée le contour
}

local function colorsAt(o, phase)
	local keys = {}
	for i = 0, o.Keys - 1 do
		local t = i / (o.Keys - 1)
		keys[i + 1] = ColorSequenceKeypoint.new(t, Color3.fromHSV((t + phase) % 1, o.Saturation, o.Value))
	end
	return ColorSequence.new(keys)
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local created, gradients = {}, {}

	local function addGradient(parent)
		local g = Instance.new("UIGradient")
		g.Name = "FlowGradient"
		g.Rotation = o.Rotation
		g.Color = colorsAt(o, 0)
		g.Parent = parent
		table.insert(created, g)
		table.insert(gradients, g)
	end

	if o.mode == "Fill" or o.mode == "Both" then addGradient(gui) end
	if o.mode == "Stroke" or o.mode == "Both" then
		local stroke = gui:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "FlowStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = o.StrokeThickness
			stroke.Parent = gui
			table.insert(created, stroke)
		end
		addGradient(stroke)
	end

	local start = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local seq = colorsAt(o, ((os.clock() - start) / o.Cycle) % 1)
		for _, g in gradients do g.Color = seq end
	end)

	return function()
		conn:Disconnect()
		for _, inst in created do inst:Destroy() end
	end
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

do
	local NAME = "_UIFX_PREVIEW_Flow"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local stops = {}
		for i, mode in { "Fill", "Stroke", "Both" } do
			local b = new("TextButton", {
				Name = "Preview" .. mode, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 2) * 240, 0.5, 0),
				Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(230, 230, 230), AutoButtonColor = false,
				Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = mode,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
			b.Parent = sg
			stops[i] = { b, play(b, { mode = mode }) }
		end
		task.wait(DEFAULTS.Cycle * 3)
		for _, pair in stops do
			pair[2]()
			assert(not pair[1]:FindFirstChild("FlowGradient", true), "dégradé resté")
		end
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_flow : aperçu joué, " .. NAME .. " détruit")
end
