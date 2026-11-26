--!nonstrict
-- ui_offre_robux_v2_place.luau (Clément, 2026-11-25 : « écarte plus l'offre Robux du Display. Sur téléphone il doit
-- encore être au-dessus de Display ») : à lancer en Edit, après ui_offre_robux_gris.luau.
--   - PC (RightRail.OfferAnchor.FeaturedOffer) : même place au-dessus du bouton, mais 36 px d'écart au lieu de 6.
--   - Téléphone (RightRailTouch.OfferAnchor.FeaturedOffer) : l'offre passe AU-DESSUS du bouton Display (et plus à sa
--     gauche). Depuis que NightCountdown est revenu en bas, il y a ≈ 110 px entre le haut du bouton et la barre de
--     Roblox : l'offre y tient en version compacte (≈ 95 × 100 px), sans Subtitle ni bulles de bonus (cachés dans la
--     copie téléphone seulement), avec Title, Income, Preview, PackName, Price et Timer plus grands.
-- Aucun nom ne change. Sauvegarde : ServerStorage/MapBackups/2026-11-25_OffreRobux_v1.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local function rows(offer, layout)
	for name, r in layout do
		local c = offer:FindFirstChild(name)
		if c then
			if r == false then
				c.Visible = false
			else
				c.Visible = true
				c.AnchorPoint = Vector2.new(0.5, 0)
				c.Position = UDim2.fromScale(0.5, r[1])
				c.Size = UDim2.fromScale(r[3] or c.Size.X.Scale, r[2])
			end
		end
	end
end

local function offerOf(hud, railName)
	local rail = hud:FindFirstChild(railName, true)
	local anchor = rail and rail:FindFirstChild("OfferAnchor")
	local offer = anchor and anchor:FindFirstChild("FeaturedOffer")
	assert(offer, railName .. ".OfferAnchor.FeaturedOffer introuvable : lancer d'abord ui_offre_robux_gris.luau")
	return offer
end

local function apply(hud)
	-- PC : plus d'écart au-dessus du bouton
	local pc = offerOf(hud, "RightRail")
	pc.Position = UDim2.new(0.5, 0, 0, -36)

	-- téléphone : au-dessus du bouton, compacte
	local ph = offerOf(hud, "RightRailTouch")
	ph.AnchorPoint = Vector2.new(0.62, 1)
	ph.Position = UDim2.new(0.5, 0, 0, -10)
	ph.Size = UDim2.fromScale(1.7, 1.75)
	local sc = ph:FindFirstChildOfClass("UISizeConstraint")
	if sc then
		sc.MinSize = Vector2.new(80, 84)
		sc.MaxSize = Vector2.new(116, 92) -- sous la barre de Roblox : haut de l'offre à 65 px (844 × 390), 71 px (667 × 375)
	end
	rows(ph, {
		Title = { 0, 0.16, 1 },
		Subtitle = false,
		Income = { 0.16, 0.12, 0.8 },
		Preview = { 0.28, 0.36, 0.7 },
		BonusA = false,
		BonusB = false,
		PackName = { 0.64, 0.12, 1 },
		Price = { 0.76, 0.12, 0.8 },
		Timer = { 0.88, 0.11, 0.6 },
	})
	ph:SetAttribute("PhoneCompact", true)

	-- compte à rebours de la nuit tout à droite sur téléphone aussi (Clément, 25/11 : « tout à droite »)
	local nc = hud:FindFirstChild("NightCountdown", true)
	if nc then
		nc:SetAttribute("PhonePosition", UDim2.fromScale(0.98, 0.985))
		nc:SetAttribute("PhoneAnchorPoint", Vector2.new(1, 1))
	end
end

local hud = SG.UI_HUD
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_OffreRobux_v1") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_OffreRobux_v1"
	for _, rn in { "RightRail", "RightRailTouch" } do
		local rail = hud:FindFirstChild(rn, true)
		local a = rail and rail:FindFirstChild("OfferAnchor")
		if a then
			local c = a:Clone()
			c.Name = rn .. "_OfferAnchor"
			c.Parent = f
		end
	end
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : offre Robux écartée du Display, au-dessus sur téléphone")
local ok, err = pcall(apply, hud)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "FeaturedOffer : PC à 36 px au-dessus du bouton, téléphone au-dessus du bouton en version compacte"
