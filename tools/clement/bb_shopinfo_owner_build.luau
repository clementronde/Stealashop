--!nonstrict
-- bb_shopinfo_owner_build.luau (demande de Clément du 2026-11-17, benchmark du genre, liaison L-216) : BB_ShopInfo montre
-- la tête du propriétaire et son meilleur objet, et le $/s devient le texte le plus gros.
--   ReplicatedStorage/Assets/UI/BB_ShopInfo, 10 × 5,5 studs → 11 × 6 studs (SizeOffset et MaxDistance 180 gardés) :
--     Panel (cadre droit, plus de UICorner : règle de Clément « boutons arrondis, cadres droits »)
--       OwnerAvatar  (nouveau) ImageLabel carré à gauche : le code y met la tête du propriétaire
--                    (rbxthumb://type=AvatarHeadShot&id=<UserId>&w=150&h=150) ; vide, c'est un carré sombre
--       OwnerName    « Alice's Shop », en haut à droite
--       Income       « +$12.4K/s », vert, le plus gros texte (1,1 stud de haut au lieu de 0,9)
--       BestItem     (nouveau) TextLabel, le nom du meilleur objet exposé ; le code le colore à sa rareté
--       HPLine       HPIcon + HP « 7/40 »
--     Status         pastille sous le panneau, inchangée (coins droits, même règle)
--   Tous les anciens noms sont gardés. À lancer en Edit. Sauvegarde dans ServerStorage/MapBackups/2026-11-17_Benchmark/
--   BB_ShopInfo. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local bb = game:GetService("ReplicatedStorage").Assets.UI.BB_ShopInfo
assert(not bb.Panel:FindFirstChild("OwnerAvatar"), "BB_ShopInfo a déjà OwnerAvatar")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("1b1b24")

local function place(o, x, y, w, h, align)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
	if align and o:IsA("TextLabel") then
		o.TextXAlignment = align
	end
end
local function dropCorner(o)
	local c = o:FindFirstChildOfClass("UICorner")
	if c then
		c:Destroy()
	end
end

local rec = CHS:TryBeginRecording("UI : BB_ShopInfo, tête du propriétaire et meilleur objet (L-216)")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_Benchmark")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_Benchmark"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild("BB_ShopInfo") then
		bb:Clone().Parent = folder
	end

	bb.Size = UDim2.fromScale(11, 6)
	local panel = bb.Panel
	dropCorner(panel)
	dropCorner(bb.Status)

	-- Tête du propriétaire, carré à gauche du panneau (panneau de 11 × 4,56 studs : 0,8 de sa hauteur = 0,33 de sa largeur).
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "OwnerAvatar"
	avatar.Image = ""
	avatar.ScaleType = Enum.ScaleType.Crop
	avatar.BackgroundColor3 = Color3.fromHex("2b313c")
	avatar.BackgroundTransparency = 0
	avatar.BorderSizePixel = 0
	avatar.ZIndex = 2
	place(avatar, 0.03, 0.1, 0.33, 0.8)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = avatar
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 0.04
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.2
	stroke.Parent = avatar
	avatar.Parent = panel

	-- Textes à droite, alignés à gauche : nom, revenu (le plus gros), meilleur objet, PV de la porte.
	local X, W = 0.39, 0.585
	place(panel.OwnerName, X, 0.07, W, 0.19, Enum.TextXAlignment.Left)
	place(panel.Income, X, 0.27, W, 0.33, Enum.TextXAlignment.Left)
	local best = Instance.new("TextLabel")
	best.Name = "BestItem"
	best.Text = "Golden Lucky Cat"
	best.FontFace = HEAVY
	best.TextColor3 = Color3.new(1, 1, 1) -- couleur de la rareté : posée par le code
	best.TextScaled = true
	best.TextWrapped = true
	best.BackgroundTransparency = 1
	best.ZIndex = 2
	place(best, X, 0.61, W, 0.16, Enum.TextXAlignment.Left)
	local bestStroke = Instance.new("UIStroke")
	bestStroke.Thickness = 0.1
	bestStroke.Color = INK
	bestStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	bestStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	bestStroke.LineJoinMode = Enum.LineJoinMode.Round
	bestStroke.Parent = best
	best.Parent = panel
	place(panel.HPLine, X, 0.79, W, 0.17)
	local layout = panel.HPLine:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	panel.HPLine.HP.TextXAlignment = Enum.TextXAlignment.Left
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BB_ShopInfo : OwnerAvatar et BestItem"
