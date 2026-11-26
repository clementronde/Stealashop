--!nonstrict
--[[
	uifx_reveal.luau : aperçu de l'effet Reveal (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : à l'ouverture, l'élément grandit depuis la moitié de sa taille en se balançant,
	puis se pose.
	Attribut proposé : Appear = "Reveal" (nouvelle valeur de notre attribut Appear).
	Durée, courbe (V0) : UIScale 0,5 → 1 en 0,35 s (Back Out) ; Rotation −8° → +4° (0,175 s, Quad Out)
	→ 0° (0,175 s, Sine InOut), sur la même durée. Une fois.
	Propriétés animées : UIScale.Scale (UIScale existant, sinon « FxScale ») ; Rotation (autour de son
	AnchorPoint ; revient à la Rotation posée par Clément).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(gui) à l'ouverture ; renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Reveal dans CoreGui, joue
	3 ouvertures, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	From = 0.5, -- échelle de départ
	Time = 0.35, -- s
	Swing = -8, -- degrés au départ
	Over = 4, -- degrés au rebond
}

local SCALE_BASE = setmetatable({}, { __mode = "k" })
local ROT_BASE = setmetatable({}, { __mode = "k" })

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = gui
	end
	if SCALE_BASE[s] == nil then SCALE_BASE[s] = s.Scale end
	if ROT_BASE[gui] == nil then ROT_BASE[gui] = gui.Rotation end
	local base, rot = SCALE_BASE[s], ROT_BASE[gui]

	s.Scale = base * o.From
	gui.Rotation = rot + o.Swing
	gui.Visible = true
	TweenService:Create(s, TweenInfo.new(o.Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
	local half = o.Time / 2
	local first = TweenService:Create(gui, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = rot + o.Over })
	first.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and gui.Parent then
			TweenService:Create(gui, TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = rot }):Play()
		end
	end)
	first:Play()
	return o.Time
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

do
	local NAME = "_UIFX_PREVIEW_Reveal"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local p = new("Frame", {
			Name = "PreviewPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(260, 160), BackgroundColor3 = Color3.fromRGB(150, 150, 150), Visible = false,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, p)
		new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(13, 13, 20) }, p)
		new("TextLabel", {
			Name = "Title", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			TextSize = 26, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Reveal",
		}, p)
		p.Parent = sg
		for _ = 1, 3 do
			task.wait(play(p) + 0.6)
			p.Visible = false
			task.wait(0.25)
		end
		assert(math.abs(p.Rotation) < 1e-3, "rotation non remise")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_reveal : aperçu joué, " .. NAME .. " détruit")
end
