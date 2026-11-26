--!nonstrict
--[[
	uifx_prompt.luau : aperçu de l'effet Prompt (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : notre propre dessin pour une invite d'action (« Open », « Steal ») à la place de
	l'invite grise de Roblox ; elle arrive en grossissant, s'écrase un peu quand on appuie, et repart.
	Attribut proposé : PromptUi = "BB_Prompt" sur le ProximityPrompt, avec ProximityPrompt.Style = Custom.
	Modèle proposé : BillboardGui BB_Prompt dans ReplicatedStorage/Assets/UI, avec un cadre Card (animé), et
	dans Card : Key (touche), Action (ActionText de l'invite), Object (ObjectText), HoldBar > HoldFill (voir
	uifx_hold.luau). Jamais « Text » comme nom (propriété Roblox).
	Durée, courbe (V0) : entrée 0,6 → 1 en 0,15 s (Back Out) ; appui × 0,92 en 0,05 s (Quad Out), relâché
	retour en 0,1 s (Back Out) ; sortie vers 0 en 0,08 s (Quad In). Une fois.
	Propriété animée : UIScale.Scale de Card (UIScale existant, sinon « FxScale »).

	Branchement côté Ironix (client) : ProximityPromptService.PromptShown(prompt) -> si Style = Custom, cloner
	le modèle nommé par prompt:GetAttribute("PromptUi"), Adornee = prompt.Parent, remplir Key, Action, Object,
	puis play(card, { phase = "In" }) ; PromptButtonHoldBegan / InputBegan -> "Press" ; relâché -> "Release" ;
	prompt.PromptHidden -> play(card, { phase = "Out" }), puis détruire le clone après la durée renvoyée.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(card, { phase = "In" | "Press" | "Release" | "Out" }) ; renvoie la durée.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Prompt dans CoreGui (la carte
	dans un ScreenGui, car l'aperçu ne touche pas au Workspace), joue 3 fois entrée, appui, sortie, puis
	détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	From = 0.6, -- échelle de départ de l'entrée
	InTime = 0.15, -- s, Back Out
	Press = 0.92, -- échelle pendant l'appui
	PressTime = 0.05, -- s, Quad Out
	ReleaseTime = 0.1, -- s, Back Out
	OutTime = 0.08, -- s, Quad In
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

local function play(card, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local uiScale = getScale(card)
	local phase = o.phase or "In"
	local target, info
	if phase == "In" then
		uiScale.Scale = o.From
		card.Visible = true
		target, info = 1, TweenInfo.new(o.InTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	elseif phase == "Press" then
		target, info = o.Press, TweenInfo.new(o.PressTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	elseif phase == "Release" then
		target, info = 1, TweenInfo.new(o.ReleaseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else -- "Out"
		target, info = 0, TweenInfo.new(o.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	TweenService:Create(uiScale, info, { Scale = target }):Play()
	return info.Time
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local INK = Color3.fromRGB(13, 13, 20)

local function promptCard(parent)
	local card = new("Frame", {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 72), BackgroundColor3 = Color3.fromRGB(150, 150, 150), Visible = false,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, card)
	new("UIStroke", { Thickness = 3, Color = INK }, card)
	local key = new("TextLabel", {
		Name = "Key", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Color3.fromRGB(205, 205, 205), Font = Enum.Font.GothamBold,
		TextSize = 28, TextColor3 = INK, Text = "E",
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, key)
	key.Parent = card
	new("TextLabel", {
		Name = "Action", Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -84, 0, 30),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "Steal",
	}, card)
	new("TextLabel", {
		Name = "Object", Position = UDim2.fromOffset(74, 38), Size = UDim2.new(1, -84, 0, 22),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 18, TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "Golden Crown",
	}, card)
	card.Parent = parent
	return card
end

do
	local NAME = "_UIFX_PREVIEW_Prompt"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local card = promptCard(sg)
		for _ = 1, 3 do
			task.wait(play(card, { phase = "In" }) + 0.4)
			task.wait(play(card, { phase = "Press" }) + 0.2)
			task.wait(play(card, { phase = "Release" }) + 0.4)
			task.wait(play(card, { phase = "Out" }) + 0.3)
			card.Visible = false
		end
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_prompt : aperçu joué, " .. NAME .. " détruit")
end
