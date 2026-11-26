--!nonstrict
--[[
	uifx_tip.luau : aperçu de l'effet Tip (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : une petite bulle de texte au-dessus de l'élément survolé (« Guards sleep 60s »,
	nom d'un bouton), après un court temps de survol.
	Attribut proposé : Tip = "<texte>" sur l'élément. Bulle modèle proposée : UI_Tip.Template (cadre caché de
	Clément), avec un TextLabel enfant nommé Message (jamais « Text », propriété Roblox). Sans modèle, l'aperçu
	fait une bulle grise.
	Durée, courbe (V0) : après 0,35 s de survol, 0,8 → 1 en 0,1 s (Back Out) ; sortie en 0,06 s (Quad Out,
	vers 0,8), puis la bulle est détruite. Sur téléphone : appui long.
	Propriétés animées : UIScale.Scale de la bulle clonée ; Visible. La bulle est posée au-dessus de l'élément
	(AnchorPoint en bas au centre), dans le même ScreenGui.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(gui, { on = true, template = UI_Tip.Template }) au MouseEnter ;
	play(gui, { on = false }) au MouseLeave (annule aussi une bulle pas encore sortie).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Tip dans CoreGui, joue
	3 survols (dont un trop court, sans bulle), puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Delay = 0.35, -- s de survol avant la bulle
	From = 0.8, -- échelle de départ
	InTime = 0.1, -- s, Back Out
	OutTime = 0.06, -- s
	Gap = 8, -- px entre l'élément et la bulle
}

local BUBBLE = setmetatable({}, { __mode = "k" })
local TOKEN = setmetatable({}, { __mode = "k" })

local function defaultBubble()
	local b = Instance.new("Frame")
	b.Name = "Template"
	b.AutomaticSize = Enum.AutomaticSize.XY
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	local m = Instance.new("TextLabel")
	m.Name = "Message"
	m.AutomaticSize = Enum.AutomaticSize.XY
	m.BackgroundTransparency = 1
	m.Font = Enum.Font.GothamBold
	m.TextSize = 18
	m.TextColor3 = Color3.new(1, 1, 1)
	m.Parent = b
	return b
end

local function hide(gui, time)
	local bubble = BUBBLE[gui]
	BUBBLE[gui] = nil
	if not bubble then return end
	local s = bubble:FindFirstChildOfClass("UIScale")
	if s then
		TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.8 }):Play()
	end
	task.delay(time, function() bubble:Destroy() end)
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local n = (TOKEN[gui] or 0) + 1
	TOKEN[gui] = n
	if o.on == false then
		hide(gui, o.OutTime)
		return o.OutTime
	end
	local text = o.text or gui:GetAttribute("Tip")
	local root = gui:FindFirstAncestorWhichIsA("LayerCollector")
	if not text or not root then return 0 end
	task.delay(o.Delay, function()
		if TOKEN[gui] ~= n or not gui.Parent then return end -- la souris est partie avant
		hide(gui, 0)
		local bubble = o.template and o.template:Clone() or defaultBubble()
		bubble.Name = "FxTip"
		local message = bubble:FindFirstChild("Message", true)
		if message then message.Text = text end
		local s = bubble:FindFirstChildOfClass("UIScale")
		if not s then
			s = Instance.new("UIScale")
			s.Parent = bubble
		end
		s.Scale = o.From
		local top = gui.AbsolutePosition + Vector2.new(gui.AbsoluteSize.X / 2, -o.Gap)
		bubble.AnchorPoint = Vector2.new(0.5, 1)
		bubble.Position = UDim2.fromOffset(top.X, top.Y)
		bubble.ZIndex = 50
		bubble.Visible = true
		bubble.Parent = root
		BUBBLE[gui] = bubble
		TweenService:Create(s, TweenInfo.new(o.InTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	return o.Delay + o.InTime
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

do
	local NAME = "_UIFX_PREVIEW_Tip"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = new("TextButton", {
			Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Sleep gas",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		b:SetAttribute("Tip", "Guards sleep 60s")
		b.Parent = sg
		for i = 1, 3 do
			play(b, { on = true })
			task.wait(i == 2 and 0.2 or 1) -- le 2e survol est trop court : pas de bulle
			if i == 2 then assert(not sg:FindFirstChild("FxTip"), "bulle sortie trop tôt") end
			play(b, { on = false })
			task.wait(0.3)
		end
		assert(not sg:FindFirstChild("FxTip"), "bulle restée")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_tip : aperçu joué, " .. NAME .. " détruit")
end
