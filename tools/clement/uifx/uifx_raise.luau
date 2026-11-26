--!nonstrict
--[[
	uifx_raise.luau : aperçu de l'effet Raise (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : au survol, la carte se soulève : elle grossit, monte un peu, passe devant ses
	voisines, et son ombre s'écarte et pâlit.
	Attribut proposé : Hover = "Raise" (nouvelle valeur de notre attribut Hover ; Grow + montée + ombre).
	Ombre : un frère de la carte nommé <NomDeLaCarte>Shadow, dessiné par Clément (un enfant passerait devant
	la carte, car un enfant s'affiche toujours au-dessus de son parent). Sans ombre : pas d'ombre animée.
	Durée, courbe : × 1,08 en 0,1 s (Quad Out) ; V0 : montée de 3 px, ombre décalée de 4 px et +0,15 de
	transparence ; retour en 0,12 s (Quad Out). Tenu tant que la souris reste.
	Propriétés animées : UIScale.Scale, Position (Offset Y), ZIndex (+1) ; Position et BackgroundTransparency
	(ou ImageTransparency) de l'ombre. Dans une grille, Position est ignorée : seule l'échelle et l'ombre jouent.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(card, { on = true }) au MouseEnter, play(card, { on = false }) au MouseLeave.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Raise dans CoreGui (deux
	cartes avec leur ombre), soulève 3 fois l'une puis l'autre, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Scale = 1.08,
	Lift = 3, -- px vers le haut
	ShadowOffset = 4, -- px vers le bas
	ShadowFade = 0.15, -- transparence en plus sur l'ombre
	InTime = 0.1, -- s, Quad Out
	OutTime = 0.12, -- s, Quad Out
}

local BASE = setmetatable({}, { __mode = "k" })

local function inLayout(gui)
	return gui.Parent ~= nil and gui.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function play(card, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local on = o.on ~= false
	local s = card:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = card
	end
	local shadow = o.shadow or (card.Parent and card.Parent:FindFirstChild(card.Name .. "Shadow"))
	local b = BASE[card]
	if not b then
		b = { scale = s.Scale, pos = card.Position, z = card.ZIndex }
		if shadow then
			b.shadowPos = shadow.Position
			b.shadowProp = shadow:IsA("ImageLabel") and "ImageTransparency" or "BackgroundTransparency"
			b.shadowT = shadow[b.shadowProp]
			b.shadowZ = shadow.ZIndex
		end
		BASE[card] = b
	end

	local info = TweenInfo.new(on and o.InTime or o.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	card.ZIndex = on and b.z + 1 or b.z
	TweenService:Create(s, info, { Scale = on and b.scale * o.Scale or b.scale }):Play()
	if not inLayout(card) then
		TweenService:Create(card, info, { Position = on and b.pos + UDim2.fromOffset(0, -o.Lift) or b.pos }):Play()
	end
	if shadow then
		shadow.ZIndex = on and b.z or b.shadowZ -- reste juste sous la carte soulevée
		TweenService:Create(shadow, info, {
			Position = on and b.shadowPos + UDim2.fromOffset(0, o.ShadowOffset) or b.shadowPos,
			[b.shadowProp] = on and math.min(1, b.shadowT + o.ShadowFade) or b.shadowT,
		}):Play()
	end
	return info.Time
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function cardWithShadow(parent, name, pos)
	new("Frame", {
		Name = name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos + UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(160, 200), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
		ZIndex = 1,
	}, parent)
	local c = new("TextButton", {
		Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(160, 200),
		BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false, Font = Enum.Font.GothamBold,
		TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = name, ZIndex = 2,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, c)
	c.Parent = parent
	return c
end

do
	local NAME = "_UIFX_PREVIEW_Raise"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, CoreGui)

	local ok, err = pcall(function()
		local a = cardWithShadow(sg, "CardA", UDim2.fromScale(0.45, 0.5))
		local b = cardWithShadow(sg, "CardB", UDim2.fromScale(0.55, 0.5))
		local home = a.Position
		for _ = 1, 3 do
			for _, c in { a, b } do
				play(c, { on = true })
				task.wait(0.5)
				play(c, { on = false })
				task.wait(0.25)
			end
		end
		assert(a.Position == home and a.ZIndex == 2, "carte non remise")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_raise : aperçu joué, " .. NAME .. " détruit")
end
