--!nonstrict
-- ui_hud_tuiles_speed_sleep.luau (Clément, 2026-11-21) : les boutons Robux en situation du HUD, « x2 SPEED »
-- (UI_HUD.RightRail.SpeedBoostButton, sur un tapis) et « zZz » (SleepButton, dans le couloir), deviennent des carrés
-- comme Displays, d'après la 2e vidéo TikTok (maquette validée par Clément : Figma « Steal a Shop — UI », page
-- « 30 HUD, tapis, poursuite », node 210:369 ; fiche docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, section 8).
--   Même taille et même place de départ que Displays (sous lui, aligné à droite, à 0,523 de la rangée : l'écart laisse
--   la place au survol × 1,1) ; nos couleurs et nos icônes : zZz garde son indigo, x2 SPEED prend l'arc-en-ciel de la
--   maquette (son jaune d'avant se confondait avec Displays).
--   Icon au centre, Label en bas à cheval sur le bord (comme « Displays »), Price en haut à droite dans le carré.
--   Nouveau décor : RaysClip (cadre qui découpe) avec Rays (rayons doux blancs, ceux de la boutique) entre le reflet et
--   l'icône ; attribut SpinSpeed = 100 (degrés par seconde, à coder) sur Rays.
--   Attribut IconHover = "Lean" sur les deux boutons (l'icône penche vers la souris, à coder).
--   zZz : Cooldown devient un voile sombre sur tout le carré avec le temps restant (le code ne fait que le montrer) ;
--   Hint (« Guards sleep 60s ») est caché, faute de place (le code ne le lit pas ; Visible = true pour le remettre).
-- Aucun nom changé, rien déplacé ni supprimé, aucun script. Valeurs absolues : peut se relancer. En Edit, annulable.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-21_HUD_SpeedSleep/UI_HUD (une seule fois).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BACKUP = "2026-11-21_HUD_SpeedSleep"
local RAYS_IMAGE = "rbxassetid://96610322911997" -- rayons doux (s'effacent vers les bords), ceux de la boutique Robux

local function child(parent, class, name)
	local found = parent:FindFirstChild(name)
	if found and found:IsA(class) then
		return found
	end
	local made = Instance.new(class)
	made.Name = name
	made.Parent = parent
	return made
end

local function tile(button)
	-- taille et place : comme Displays (DisplayedButton), sous lui
	button.AnchorPoint = Vector2.new(1, 0)
	button.Size = UDim2.fromScale(0.4148148, 0.430769235)
	button.Position = UDim2.fromScale(1, 0.523076952)
	local ratio = button:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then
		ratio.AspectRatio = 1
		ratio.DominantAxis = Enum.DominantAxis.Width
	end

	local icon = button:FindFirstChild("Icon")
	if icon then
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.47)
		icon.Size = UDim2.fromScale(0.72, 0.72)
		icon.Rotation = 0
	end
	local label = button:FindFirstChild("Label")
	if label then
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 1)
		label.Size = UDim2.fromScale(0.94, 0.26)
	end
	local price = button:FindFirstChild("Price")
	if price then
		price.AnchorPoint = Vector2.new(1, 0)
		price.Position = UDim2.fromScale(0.96, 0.04)
		price.Size = UDim2.fromScale(0.56, 0.216)
	end

	-- rayons : découpés par le carré, au-dessus du reflet (ZIndex 3), sous le contour (5) et l'icône (6)
	local clip = child(button, "Frame", "RaysClip")
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0, 0)
	clip.Position = UDim2.fromScale(0.03, 0.03)
	clip.Size = UDim2.fromScale(0.94, 0.85)
	clip.ZIndex = 4
	local rays = child(clip, "ImageLabel", "Rays")
	rays.BackgroundTransparency = 1
	rays.BorderSizePixel = 0
	rays.Image = RAYS_IMAGE
	rays.ImageColor3 = Color3.new(1, 1, 1)
	rays.ImageTransparency = 0.35
	rays.ScaleType = Enum.ScaleType.Fit
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.6, 1.6)
	rays.ZIndex = 4
	if not rays:FindFirstChildOfClass("UIAspectRatioConstraint") then
		Instance.new("UIAspectRatioConstraint").Parent = rays
	end
	rays:SetAttribute("SpinSpeed", 100)

	button:SetAttribute("IconHover", "Lean")
end

local rec = CHS:TryBeginRecording("UI : HUD, x2 SPEED et zZz en carrés (2026-11-21)")
local ok, err = pcall(function()
	local hud = SG.UI_HUD
	local backups = SS:FindFirstChild("MapBackups")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "MapBackups"
		backups.Parent = SS
	end
	local folder = backups:FindFirstChild(BACKUP)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BACKUP
		folder.Parent = backups
	end
	if not folder:FindFirstChild(hud.Name) then
		local copy = hud:Clone()
		copy.Parent = folder
	end

	local rail = hud.RightRail
	tile(rail.SpeedBoostButton)
	tile(rail.SleepButton)

	-- x2 SPEED : l'arc-en-ciel de la maquette validée (le jaune d'avant, presque celui de Displays juste au-dessus, les
	-- faisait se confondre ; il reste dans la sauvegarde)
	local rainbow = rail.SpeedBoostButton:FindFirstChildOfClass("UIGradient")
	if rainbow then
		rainbow.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("ff4d6e")),
			ColorSequenceKeypoint.new(0.2, Color3.fromHex("ffb542")),
			ColorSequenceKeypoint.new(0.4, Color3.fromHex("fff259")),
			ColorSequenceKeypoint.new(0.6, Color3.fromHex("5ceb6b")),
			ColorSequenceKeypoint.new(0.8, Color3.fromHex("4fc2ff")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("a66bff")),
		})
		rainbow.Rotation = 45
	end

	-- zZz en recharge : voile sombre sur tout le carré, temps restant au centre
	local sleep = rail.SleepButton
	local cooldown = sleep:FindFirstChild("Cooldown")
	if cooldown then
		cooldown.AnchorPoint = Vector2.new(0, 0)
		cooldown.Position = UDim2.fromScale(0, 0)
		cooldown.Size = UDim2.fromScale(1, 0.91)
		cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
		cooldown.BackgroundTransparency = 0.45
		cooldown.BorderSizePixel = 0
		cooldown.ZIndex = 9
		local pad = child(cooldown, "UIPadding", "UIPadding")
		pad.PaddingTop = UDim.new(0.3, 0)
		pad.PaddingBottom = UDim.new(0.3, 0)
		pad.PaddingLeft = UDim.new(0.12, 0)
		pad.PaddingRight = UDim.new(0.12, 0)
		local corner = child(cooldown, "UICorner", "UICorner")
		corner.CornerRadius = UDim.new(0.06, 0)
	end
	local hint = sleep:FindFirstChild("Hint")
	if hint then
		hint.Visible = false
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "x2 SPEED et zZz en carrés"
