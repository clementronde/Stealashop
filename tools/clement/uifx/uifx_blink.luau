--!nonstrict
--[[
	uifx_blink.luau : aperçu de l'effet Blink (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : l'élément s'allume et s'éteint doucement, sans fin (« NEW », point d'alerte).
	Attribut proposé : Idle = "Blink" (nouvelle valeur de notre attribut Idle).
	Durée, courbe (V0) : transparence 0 → 0,7 → 0 en 1 s (Sine InOut, 0,5 s par sens). Continu.
	Propriétés animées : CanvasGroup.GroupTransparency si l'élément est un CanvasGroup ; sinon ses
	transparences et celles de ses enfants (fond, image, texte, contour du texte, UIStroke), chacune
	tirée de 70 % vers l'invisible à partir de la valeur posée par Clément.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(gui, options) ; stop() arrête et remet les transparences de Clément.
	Tout ce qui tourne seul s'arrête quand l'élément n'est pas affiché (à brancher côté contrôleur).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Blink dans CoreGui (une
	pastille « NEW »), joue 3 clignements, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Depth = 0.7, -- part du chemin vers l'invisible au creux
	Cycle = 1, -- s : allumé → éteint → allumé
}

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

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local info = TweenInfo.new(o.Cycle / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tweens, restore = {}, {}
	if gui:IsA("CanvasGroup") then
		local base = gui.GroupTransparency
		table.insert(restore, { inst = gui, prop = "GroupTransparency", base = base })
		table.insert(tweens, TweenService:Create(gui, info, { GroupTransparency = base + (1 - base) * o.Depth }))
	else
		for _, inst in { gui, table.unpack(gui:GetDescendants()) } do
			for _, p in transparencyProps(inst) do
				local base = inst[p]
				if base < 1 then
					table.insert(restore, { inst = inst, prop = p, base = base })
					table.insert(tweens, TweenService:Create(inst, info, { [p] = base + (1 - base) * o.Depth }))
				end
			end
		end
	end
	for _, t in tweens do t:Play() end
	return function()
		for _, t in tweens do t:Cancel() end
		for _, e in restore do
			if e.inst.Parent then e.inst[e.prop] = e.base end
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

do
	local NAME = "_UIFX_PREVIEW_Blink"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local badge = new("TextLabel", {
			Name = "NewBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(110, 44), BackgroundColor3 = Color3.fromRGB(150, 150, 150), Font = Enum.Font.GothamBold,
			TextSize = 24, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "NEW",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, badge)
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(13, 13, 20), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
		badge.Parent = sg
		local stop = play(badge)
		task.wait(DEFAULTS.Cycle * 3)
		stop()
		assert(badge.BackgroundTransparency == 0 and badge.TextTransparency == 0, "transparences non remises")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_blink : aperçu joué, " .. NAME .. " détruit")
end
