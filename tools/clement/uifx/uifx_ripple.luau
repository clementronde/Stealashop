--!nonstrict
--[[
	uifx_ripple.luau : aperçu de l'effet Ripple (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : un rond clair part du point du clic, grandit et s'efface, coupé par le bouton.
	Attribut proposé : Press = "Ripple" (nouvelle valeur de notre attribut Press).
	Durée, courbe (V0) : de 0 à 2,2 × le grand côté du bouton en 0,45 s (Quad Out), transparence 0,6 → 1.
	Une fois par clic.
	Propriétés animées : Size et BackgroundTransparency d'un rond « FxRipple » créé par le code (UICorner 50 %),
	détruit à la fin. Le bouton passe en ClipsDescendants = true (Roblox ne coupe pas selon l'UICorner : pour
	des coins arrondis exacts, faire du bouton un CanvasGroup).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(button, { at = Vector2 }) avec la position écran du clic (input.Position) ; sans « at »,
	le rond part du centre. Renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Ripple dans CoreGui, joue
	3 clics (coin gauche, centre, coin droit), puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Spread = 2.2, -- × le grand côté du bouton
	Time = 0.45, -- s, Quad Out
	From = 0.6, -- transparence de départ
	Color = Color3.new(1, 1, 1),
}

local function play(button, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local size = button.AbsoluteSize
	if size.X == 0 then size = Vector2.new(button.Size.X.Offset, button.Size.Y.Offset) end
	local local_ = o.at and (o.at - button.AbsolutePosition) or size / 2
	local d = math.max(size.X, size.Y) * o.Spread
	if not button:IsA("CanvasGroup") then button.ClipsDescendants = true end

	local dot = Instance.new("Frame")
	dot.Name = "FxRipple"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(local_.X, local_.Y)
	dot.Size = UDim2.fromOffset(0, 0)
	dot.BackgroundColor3 = o.Color
	dot.BackgroundTransparency = o.From
	dot.BorderSizePixel = 0
	dot.ZIndex = button.ZIndex + 5
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	dot.Parent = button

	local t = TweenService:Create(dot, TweenInfo.new(o.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(d, d),
		BackgroundTransparency = 1,
	})
	t.Completed:Once(function() dot:Destroy() end)
	t:Play()
	return o.Time
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
	local NAME = "_UIFX_PREVIEW_Ripple"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local b = grayButton(sg, "Ripple", UDim2.fromScale(0.5, 0.5))
		task.wait() -- laisse Roblox calculer AbsolutePosition
		local p, s = b.AbsolutePosition, b.AbsoluteSize
		for _, at in { p + Vector2.new(20, 16), p + s / 2, p + s - Vector2.new(20, 16) } do
			task.wait(play(b, { at = at }) + 0.25)
		end
		assert(not b:FindFirstChild("FxRipple"), "rond resté dans le bouton")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_ripple : aperçu joué, " .. NAME .. " détruit")
end
