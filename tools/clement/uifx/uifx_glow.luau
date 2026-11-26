--!nonstrict
--[[
	uifx_glow.luau : aperçu de l'effet Glow (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : un halo autour de l'élément respire (grandit et s'éclaire, puis revient), sans fin.
	Attribut proposé : Idle = "Glow" (nouvelle valeur de notre attribut Idle).
	Deux façons, toutes deux natives :
	- par défaut, un contour UIStroke enfant nommé GlowStroke (celui de Clément s'il existe, sinon un
	  contour doré créé par le code) : épaisseur × 1,5 et transparence 0,4 → 0,2 ;
	- avec options.halo (une ImageLabel de halo posée derrière l'élément par Clément, en frère) : UIScale
	  1 → 1,1 et ImageTransparency 0,4 → 0,2.
	Texture du halo : UI_Tex_Ring_Thick.png de notre bibliothèque (_Vault/UI/Textures_UI), NON PUBLIÉE :
	HALO_IMAGE ci-dessous reste vide (rbxassetid à remplir après publication) ; tant qu'il est vide,
	l'aperçu ne montre que le contour.
	Durée, courbe (V0) : cycle de 2 s (Sine InOut, 1 s par sens). Continu.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : local stop = play(gui, { halo = imageLabel? }) ; stop() arrête, remet les valeurs de
	Clément et retire le contour créé par le code.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Glow dans CoreGui, joue
	3 respirations, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local HALO_IMAGE = "" -- rbxassetid://… de UI_Tex_Ring_Thick.png, non publiée au 25/11

local DEFAULTS = {
	Cycle = 2, -- s
	Thickness = 4, -- px, contour créé par le code
	Grow = 1.5, -- épaisseur du contour au plus fort (×)
	HaloScale = 1.1,
	From = 0.4, -- transparence au repos
	To = 0.2, -- transparence au plus fort
	Color = Color3.fromRGB(255, 214, 90),
}

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local info = TweenInfo.new(o.Cycle / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tweens, undo = {}, {}

	if o.halo then
		local halo = o.halo
		local s = halo:FindFirstChildOfClass("UIScale")
		if not s then
			s = Instance.new("UIScale")
			s.Name = "FxScale"
			s.Parent = halo
			table.insert(undo, function() s:Destroy() end)
		end
		local base, t0 = s.Scale, halo.ImageTransparency
		halo.ImageTransparency = o.From
		table.insert(tweens, TweenService:Create(s, info, { Scale = base * o.HaloScale }))
		table.insert(tweens, TweenService:Create(halo, info, { ImageTransparency = o.To }))
		table.insert(undo, function() s.Scale = base; halo.ImageTransparency = t0 end)
	else
		local stroke = gui:FindFirstChild("GlowStroke")
		if stroke then
			local th, tr = stroke.Thickness, stroke.Transparency
			table.insert(undo, function() stroke.Thickness = th; stroke.Transparency = tr end)
		else
			stroke = Instance.new("UIStroke")
			stroke.Name = "GlowStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = o.Color
			stroke.Thickness = o.Thickness
			stroke.Parent = gui
			table.insert(undo, function() stroke:Destroy() end)
		end
		stroke.Transparency = o.From
		table.insert(tweens, TweenService:Create(stroke, info, { Thickness = stroke.Thickness * o.Grow, Transparency = o.To }))
	end

	for _, t in tweens do t:Play() end
	return function()
		for _, t in tweens do t:Cancel() end
		for _, f in undo do f() end
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
	local NAME = "_UIFX_PREVIEW_Glow"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local halo
		if HALO_IMAGE ~= "" then
			halo = new("ImageLabel", {
				Name = "PreviewHalo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Image = HALO_IMAGE,
				ImageColor3 = DEFAULTS.Color,
			}, sg)
		end
		local b = new("TextButton", {
			Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
			Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = "Claim",
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		b.Parent = sg
		local stop = play(b)
		local stopHalo = halo and play(b, { halo = halo })
		task.wait(DEFAULTS.Cycle * 3)
		stop()
		if stopHalo then stopHalo() end
		assert(not b:FindFirstChild("GlowStroke"), "contour créé resté")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_glow : aperçu joué, " .. NAME .. " détruit")
end
