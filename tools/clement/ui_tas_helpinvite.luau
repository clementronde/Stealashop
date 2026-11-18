--!nonstrict
-- ui_tas_helpinvite.luau (décision de Clément du 2026-11-17, note Throw a Seed, « Capture par la police ou le vigile
-- faute de puissance ou de vitesse ») : nouvel écran UI_HelpInvite, montré par le code après une capture quand le
-- joueur manquait de puissance ou de vitesse.
--   UI_HelpInvite (ScreenGui, éteint, DisplayOrder 45 : au-dessus de UI_Escape et de la capture)
--     Card          carte sombre à tenons, sous le centre de l'écran (Appear = Pop) ; rapport 2,6, au moins 360 px de
--                   large (téléphone), au plus 620
--       Icon        l'icône d'invitation du HUD (deux amis)
--       Message     « Not strong enough? Invite a friend to help you rob this store! » (début en jaune, RichText) ; le
--                   code y met la variante vitesse : « Not fast enough? Invite a friend to help you rob this store! »
--       InviteButton  bouton vert de la recette (InviteLabel « INVITE ») : ouvre l'invitation de Roblox
--       CloseButton   croix rose au coin
-- Les boutons sont des copies des boutons de la recette (UI_Displayed DisplayButton, UI_Rewards CloseButton), au moins
-- 44 px de haut sur téléphone. Peut se relancer (l'écran est refait), en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local STRENGTH_TEXT = '<font color="#FFD23A">Not strong enough?</font> Invite a friend to help you rob this store!'

local function place(object, ax, ay, px, py, sx, sy)
	object.AnchorPoint = Vector2.new(ax, ay)
	object.Position = UDim2.fromScale(px, py)
	object.Size = UDim2.fromScale(sx, sy)
end
local function square(object)
	local ar = object:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	ar.Parent = object
end

local rec = CHS:TryBeginRecording("UI : écran UI_HelpInvite (invite un ami après une capture)")
local ok, err = pcall(function()
	local old = SG:FindFirstChild("UI_HelpInvite")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UI_HelpInvite"
	gui.Enabled = false
	gui.DisplayOrder = 45
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local card = Instance.new("Frame")
	card.Name = "Card"
	place(card, 0.5, 0.5, 0.5, 0.62, 0.4, 0.3)
	card.BackgroundColor3 = Color3.fromHex("2b313c")
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card:SetAttribute("Appear", "Pop")
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 2.6
	ar.Parent = card
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(360, 138)
	limits.MaxSize = Vector2.new(620, 238)
	limits.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.06, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 3
	stroke.Color = Color3.fromHex("0f1116")
	stroke.Parent = card
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromHex("ffffff"), Color3.fromHex("b9bec8"))
	shade.Parent = card
	local studs = SG.UI_Displayed.Dock.Panel:FindFirstChild("Studs")
	if studs then
		local s = studs:Clone()
		s.Position = UDim2.fromScale(0, 0)
		s.Size = UDim2.fromScale(1, 1)
		s.ZIndex = 2
		s.Parent = card
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	place(icon, 0, 0.5, 0.04, 0.5, 0.26, 0.66)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	local hudInvite = SG.UI_HUD:FindFirstChild("InviteButton", true)
	local hudIcon = if hudInvite then hudInvite:FindFirstChild("Icon", true) else nil
	icon.Image = if hudIcon and hudIcon:IsA("ImageLabel") then hudIcon.Image else "rbxassetid://102094661385258"
	square(icon)
	icon.Parent = card

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	place(message, 0, 0, 0.32, 0.1, 0.62, 0.46)
	message.BackgroundTransparency = 1
	message.RichText = true
	message.Text = STRENGTH_TEXT
	message.FontFace = HEAVY
	message.TextScaled = true
	message.TextWrapped = true
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextYAlignment = Enum.TextYAlignment.Center
	message.TextColor3 = Color3.new(1, 1, 1)
	message.ZIndex = 3
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	textStroke.Thickness = 0.12
	textStroke.Color = Color3.fromHex("0f1116")
	textStroke.LineJoinMode = Enum.LineJoinMode.Round
	textStroke.Parent = message
	message.Parent = card

	-- Bouton vert de la recette.
	local green = SG.UI_Displayed:FindFirstChild("DisplayButton", true)
	local invite = green:Clone()
	invite.Name = "InviteButton"
	invite.LayoutOrder = 0
	place(invite, 0, 0.5, 0.32, 0.77, 0.42, 0.32)
	local cap = invite:FindFirstChildOfClass("UISizeConstraint")
	if cap then
		cap.MaxSize = Vector2.new(10000, 68)
	end
	local label = invite:FindFirstChildOfClass("TextLabel")
	label.Name = "InviteLabel"
	label.Text = "INVITE"
	place(label, 0, 0, 0.08, 0.2, 0.84, 0.52)
	invite.Parent = card

	-- Croix rose au coin.
	local closeSource = SG.UI_Rewards:FindFirstChild("CloseButton", true)
	local close = closeSource:Clone()
	close.Name = "CloseButton"
	place(close, 0.5, 0.5, 0.985, 0.03, 0.2, 0.33)
	square(close)
	local closeCap = close:FindFirstChildOfClass("UISizeConstraint")
	if closeCap then
		closeCap:Destroy()
	end
	close.Parent = card

	card.Parent = gui
	gui.Parent = SG
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HelpInvite"
