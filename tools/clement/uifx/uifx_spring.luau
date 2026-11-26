--!nonstrict
--[[
	uifx_spring.luau : aperçu de l'effet Spring en 2D (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : pendant le survol, l'icône penche vers le pointeur, tenue par un ressort ; quand
	la souris sort, elle revient droite avec un petit rebond.
	Attribut : IconHover = "Spring" (valeur déjà lue par RobuxShopController pour la caisse 3D ; ici sur
	une icône 2D, enfant Icon du bouton, sinon le bouton lui-même).
	Durée, courbe : 10° au plus au bord du bouton ; ressort de 3 Hz, amortissement 0,6 (l'entrée se fait
	par le ressort, environ 0,15 s) ; retour 0,35 s (Back Out). Continu pendant le survol.
	Propriété animée : Rotation de l'icône (revient à la Rotation posée par Clément).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(button, options) quand le bouton est affiché ; stop() quand il est caché.
	Le pointeur vient de UserInputService:GetMouseLocation() (moins la barre du haut) ; options.getPointer
	le remplace (renvoie un Vector2 écran, ou nil).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Spring dans CoreGui ; un
	pointeur simulé passe 3 fois sur le bouton de gauche à droite puis sort ; puis tout est détruit.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local DEFAULTS = {
	MaxAngle = 10, -- degrés au bord
	Frequency = 3, -- Hz
	Damping = 0.6,
	BackTime = 0.35, -- s, Back Out
}

local function mousePointer()
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local function play(button, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local icon = o.target or button:FindFirstChild("Icon") or button
	local rot0 = icon.Rotation
	local omega = 2 * math.pi * o.Frequency
	local x, v = 0, 0
	local hovering = false
	local back

	local conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 30)
		local p = (o.getPointer or mousePointer)()
		local pos, size = button.AbsolutePosition, button.AbsoluteSize
		local inside = p ~= nil and p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
		if inside then
			if back then
				back:Cancel()
				back = nil
				x = icon.Rotation - rot0
			end
			hovering = true
			local k = math.clamp((p.X - (pos.X + size.X / 2)) / math.max(size.X / 2, 1), -1, 1)
			local a = omega * omega * (k * o.MaxAngle - x) - 2 * o.Damping * omega * v
			v += a * dt
			x += v * dt
			icon.Rotation = rot0 + x
		elseif hovering then
			hovering = false
			x, v = 0, 0
			back = TweenService:Create(icon, TweenInfo.new(o.BackTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = rot0 })
			back:Play()
		end
	end)

	return function()
		conn:Disconnect()
		if back then back:Cancel() end
		if icon.Parent then icon.Rotation = rot0 end
	end
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local peak = 0
do
	local NAME = "_UIFX_PREVIEW_Spring"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = new("TextButton", {
			Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(160, 160), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
			Text = "",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		local icon = new("TextLabel", {
			Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(90, 90), BackgroundColor3 = Color3.fromRGB(205, 205, 205), Font = Enum.Font.GothamBold,
			TextSize = 26, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Icon",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, icon)
		icon.Parent = b
		b.Parent = sg
		task.wait()

		local pointer = nil
		local stop = play(b, { getPointer = function() return pointer end })
		local pos, size = b.AbsolutePosition, b.AbsoluteSize
		for _ = 1, 3 do
			local t0 = os.clock()
			while os.clock() - t0 < 1.2 do
				local k = (os.clock() - t0) / 1.2
				pointer = pos + Vector2.new(size.X * (0.02 + 0.96 * k), size.Y / 2)
				peak = math.max(peak, math.abs(icon.Rotation))
				task.wait()
			end
			pointer = nil
			task.wait(0.6)
		end
		assert(math.abs(icon.Rotation) < 0.05, "icône pas revenue droite")
		stop()
	end)

	sg:Destroy()
	if not ok then error(err) end
	print(string.format("uifx_spring : aperçu joué (pente max %.1f°), %s détruit", peak, NAME))
end
