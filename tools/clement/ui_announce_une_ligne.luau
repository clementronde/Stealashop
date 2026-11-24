--!nonstrict
-- ui_announce_une_ligne.luau (Clément, 2026-11-24 : « il faut refaire l'UI, la laisser seulement 5 secondes quand le
-- jour arrive, juste une phrase "il y a une caisse légendaire en zone 6" suffit », puis « pas de fond, pas d'image,
-- juste du texte blanc avec la rareté en couleur ») : à lancer en Edit.
-- UI_Announce.Banner n'a plus ni fond, ni contour, ni image : une seule ligne de texte blanc à contour noir, en haut
-- au centre ; la rareté garde la couleur que le code écrit dans Message (RichText). Icon et Detail sont cachés.
-- Noms lus par le code gardés : Banner, Banner.Icon, Banner.Message, Banner.Detail (facultatif). La durée (5 s), le
-- moment (au lever du jour) et la phrase sont dans le code (Config/Announce, Config/Unbox) : liaison pour Ironix.
-- Aucun script.
-- PREVIEW = true : rien ne change ; une copie allumée est posée dans StarterGui (_PREVIEW_CLAUDE_Announce, non
-- archivable, à détruire). PREVIEW = false : UI_Announce change (sauvegarde ServerStorage/MapBackups/2026-11-24_Annonce).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local function apply(gui)
	local banner = gui.Banner
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.13)
	banner.Size = UDim2.fromScale(0.6, 0.06)
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	for _, c in banner:GetChildren() do
		-- plus de fond : ni dégradé, ni contour, ni studs, ni liserés
		if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") or c.Name == "Studs" or c.Name == "TrimTop" or c.Name == "TrimBottom" then
			c:Destroy()
		end
	end
	local ar = banner:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 14
	ar.Parent = banner
	local sc = banner:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	sc.MinSize = Vector2.new(460, 32)
	sc.MaxSize = Vector2.new(1100, 80)
	sc.Parent = banner

	local icon = banner:FindFirstChild("Icon")
	if icon then
		icon.Visible = false -- plus d'image (Clément)
	end
	local detail = banner:FindFirstChild("Detail")
	if detail then
		detail.Visible = false -- une seule phrase (Clément)
	end

	local message = banner.Message
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.5)
	message.Size = UDim2.fromScale(1, 1)
	message.BackgroundTransparency = 1
	message.TextColor3 = Color3.new(1, 1, 1)
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.TextYAlignment = Enum.TextYAlignment.Center
	message.TextScaled = false
	message.TextWrapped = true
	message.TextScaled = true
	message.ZIndex = 4
	local ms = message:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	ms.Color = Color3.new(0, 0, 0)
	ms.Thickness = 0.12
	ms.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ms.LineJoinMode = Enum.LineJoinMode.Round
	ms.Parent = message
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Announce")
	if old then
		old:Destroy()
	end
	local copy = SG.UI_Announce:Clone()
	copy.Name = "_PREVIEW_CLAUDE_Announce"
	copy.Archivable = false
	copy.Enabled = true
	apply(copy)
	copy.Banner.Message.Text = 'A <font color="#FFC21A">LEGENDARY</font> box is in Zone 6!'
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : annonce en une ligne de texte")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Annonce")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Annonce"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Announce") then
		SG.UI_Announce:Clone().Parent = backups
	end
	apply(SG.UI_Announce)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Announce : une ligne de texte"
