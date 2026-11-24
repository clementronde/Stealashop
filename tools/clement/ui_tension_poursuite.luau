--!nonstrict
-- ui_tension_poursuite.luau (Clément, 2026-11-24 : « il faut qu'on ait un peu d'UI de tension pendant un braquage, à
-- toi de voir comment ça se passe sur les autres jeux » ; pistes du rapport
-- StealAShop-Art/References/2026-11-24_Top20_Roblox_analyse.md, section 3.2) : à lancer en Edit.
-- La partie visuelle, que le code d'Ironix déclenche :
--   - UI_Chase.RunBanner : « RUN! » plus grand (≈ 30 % de plus), toujours en haut au centre, sous la barre de Roblox.
--   - ReplicatedStorage/Assets/FX/FX_ChaseChevron : un chevron « > » en deux barres néon jaunes à contour sombre, à
--     poser au sol (pivot au sol, pointe vers −Z, l'avant du modèle) ; le code en aligne une file du voleur à sa
--     boutique et les allume l'un après l'autre. Aucune collision, aucune requête de rayon.
--   - ReplicatedStorage/Assets/FX/HL_ChaseGuard : le Highlight rouge du vigile qui poursuit (visible à travers les
--     murs), à copier sur le modèle du vigile pendant la poursuite seulement.
-- UI_Escape.Flash (flash d'arrivée) existe déjà. Aucun nom existant changé, aucun script.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-24_Tension.

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local YELLOW = Color3.fromHex("#FFD21F")
local DARK = Color3.fromHex("#1B1B24")

local function bar(parent, name, angle, color, size, y)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if color == YELLOW then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	-- les deux barres se rejoignent à la pointe (−Z) : chacune penchée de ±angle autour de Y
	local half = size.Z / 2
	local side = if name:find("Left") then -1 else 1
	local tip = CFrame.new(0, y, -half * math.cos(math.rad(angle)))
	p.CFrame = tip * CFrame.Angles(0, math.rad(angle) * side, 0) * CFrame.new(0, 0, half)
	p.Parent = parent
	return p
end

local function chevron()
	local m = Instance.new("Model")
	m.Name = "FX_ChaseChevron"
	-- contour sombre dessous, néon jaune dessus
	bar(m, "EdgeLeft", 40, DARK, Vector3.new(0.75, 0.08, 2.6), 0.04)
	bar(m, "EdgeRight", 40, DARK, Vector3.new(0.75, 0.08, 2.6), 0.04)
	bar(m, "Left", 40, YELLOW, Vector3.new(0.5, 0.1, 2.4), 0.09)
	bar(m, "Right", 40, YELLOW, Vector3.new(0.5, 0.1, 2.4), 0.09)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Note", "Pointe vers −Z ; pivot au sol. Le code aligne une file et allume Left/Right l'un après l'autre.")
	return m
end

local function highlight()
	local h = Instance.new("Highlight")
	h.Name = "HL_ChaseGuard"
	h.FillColor = Color3.fromHex("#FF2A2A")
	h.FillTransparency = 0.55
	h.OutlineColor = Color3.fromHex("#FFE1E1")
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = true
	return h
end

local function biggerRun(gui)
	local banner = gui.RunBanner
	banner.Position = UDim2.fromScale(0.5, 0.035)
	banner.Size = UDim2.fromScale(0.26, 0.13)
	local sc = banner:FindFirstChildOfClass("UISizeConstraint")
	if sc then
		sc.MinSize = Vector2.new(240, 83)
	end
end

local rec = CHS:TryBeginRecording("UI et FX : tension de la poursuite (RUN! plus grand, chevrons, vigile en rouge)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Tension")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Tension"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Chase") then
		SG.UI_Chase:Clone().Parent = backups
	end
	biggerRun(SG.UI_Chase)
	local fx = RS.Assets.FX
	for _, n in { "FX_ChaseChevron", "HL_ChaseGuard" } do
		local old = fx:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	chevron().Parent = fx
	highlight().Parent = fx
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "RunBanner plus grand ; FX_ChaseChevron et HL_ChaseGuard dans Assets/FX"
