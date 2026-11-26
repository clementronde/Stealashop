--!nonstrict
--[[
	uifx_fade_in.luau : aperçu de l'effet Fade in (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : l'élément apparaît en fondu chaque fois qu'il devient visible, et s'efface en sortant.
	Attribut proposé : Appear = "FadeIn" (nouvelle valeur de notre attribut Appear).
	Durée, courbe (V0) : entrée 1 → 0 en 0,2 s (Quad Out) ; sortie 0 → 1 en 0,15 s (Quad In), puis Visible = false.
	Une fois par apparition.
	Propriétés animées : CanvasGroup.GroupTransparency si l'élément est un CanvasGroup (le plus simple) ; sinon
	chaque transparence de l'élément et de ses enfants (fond, image, texte, contour du texte, UIStroke), en
	revenant aux valeurs de Clément, lues une fois.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(gui) montre l'élément en fondu ; play(gui, { out = true }) le cache. Renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_FadeIn dans CoreGui (un cadre
	simple et un CanvasGroup), joue 3 entrées et sorties, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	InTime = 0.2, -- s, Quad Out
	OutTime = 0.15, -- s, Quad In
}

local BASE = setmetatable({}, { __mode = "k" }) -- transparences de Clément, lues une fois
local TOKEN = setmetatable({}, { __mode = "k" })

local function transparencyProps(inst)
	if inst:IsA("UIStroke") then return { "Transparency" } end
	if not inst:IsA("GuiObject") then return {} end
	local list = { "BackgroundTransparency" }
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		table.insert(list, "TextTransparency")
		table.insert(list, "TextStrokeTransparency")
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
		table.insert(list, "ImageTransparency")
	end
	return list
end

local function baseOf(root)
	if BASE[root] then return BASE[root] end
	local entries = {}
	local function add(inst)
		for _, p in transparencyProps(inst) do
			table.insert(entries, { inst = inst, prop = p, base = inst[p] })
		end
	end
	add(root)
	for _, d in root:GetDescendants() do add(d) end
	BASE[root] = entries
	return entries
end

-- hidden = 0 : allure de Clément ; hidden = 1 : invisible
local function setHidden(root, hidden)
	if root:IsA("CanvasGroup") then root.GroupTransparency = hidden return end
	for _, e in baseOf(root) do e.inst[e.prop] = e.base + (1 - e.base) * hidden end
end

local function fadeTo(root, hidden, info)
	if root:IsA("CanvasGroup") then
		TweenService:Create(root, info, { GroupTransparency = hidden }):Play()
		return
	end
	for _, e in baseOf(root) do
		if e.inst.Parent then
			TweenService:Create(e.inst, info, { [e.prop] = e.base + (1 - e.base) * hidden }):Play()
		end
	end
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local n = (TOKEN[gui] or 0) + 1
	TOKEN[gui] = n
	baseOf(gui)
	if not o.out then
		if not gui.Visible then
			setHidden(gui, 1)
			gui.Visible = true
		end
		fadeTo(gui, 0, TweenInfo.new(o.InTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		return o.InTime
	end
	fadeTo(gui, 1, TweenInfo.new(o.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	task.delay(o.OutTime, function()
		if TOKEN[gui] ~= n then return end -- réaffiché entre-temps
		gui.Visible = false
		setHidden(gui, 0) -- caché, mais prêt avec l'allure de Clément
	end)
	return o.OutTime
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function panel(class, parent, text, pos)
	local p = new(class, {
		Name = "Preview" .. class, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(240, 140), BackgroundColor3 = Color3.fromRGB(150, 150, 150), Visible = false,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, p)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(13, 13, 20) }, p)
	new("TextLabel", {
		Name = "Title", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = text,
	}, p)
	p.Parent = parent
	return p
end

do
	local NAME = "_UIFX_PREVIEW_FadeIn"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local a = panel("Frame", sg, "Frame", UDim2.fromScale(0.4, 0.5))
		local b = panel("CanvasGroup", sg, "CanvasGroup", UDim2.fromScale(0.6, 0.5))
		for _ = 1, 3 do
			play(a)
			play(b)
			task.wait(0.7)
			play(a, { out = true })
			play(b, { out = true })
			task.wait(0.4)
		end
		assert(not a.Visible and a.BackgroundTransparency == 0, "sortie inattendue")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_fade_in : aperçu joué, " .. NAME .. " détruit")
end
