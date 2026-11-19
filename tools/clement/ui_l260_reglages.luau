--!nonstrict
-- ui_l260_reglages.luau (Clément, 2026-11-19 : réglages de maquette demandés par Cantin en L-260) : à lancer en Edit.
--   (a) UI_WeaponShop : le texte des EquipButton (le texte du bouton lui-même, écrit par le code) passait sous Fill (13)
--       et Shade (14), l'écran étant en ZIndex Global. Le bouton passe à 15 (fond transparent : seul son texte monte),
--       Shade à 16 pour assombrir aussi le texte au survol, comme Price sur BuyButton.
--   (b) UI_WeaponShop et UI_AuraShop s'ouvraient à 556 × 330 px : même recette que la boutique Robux (L-256), 80 % de la
--       hauteur de l'écran, centrés, rapport 1,683 gardé, au moins 505 × 300 px sur téléphone. DisplayOrder 5 → 7, au-dessus
--       de UI_Hotbar et du voile UI_Veil (L-259).
--   (c) UI_Displayed : les lignes de Reserve.ReserveList prenaient toute la hauteur de la liste (une seule ligne visible).
--       CellSize passe à la moitié de la liste moins l'écart : deux lignes entières visibles, jamais une ligne coupée au repos.
--   (d) UI_RobuxShop_v2 : Crate.Icon.Preview avait perdu sa Camera : recréée avec le cadrage de L-252
--       (box_shop_crate_import_setup.luau : lacet −28°, tangage 22°, champ 32°).
-- Aucun nom changé, aucun script. Sauvegardes : ServerStorage/MapBackups/2026-11-19_L260. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local YAW, PITCH, FOV = math.rad(-28), math.rad(22), 32

local rec = CHS:TryBeginRecording("UI : réglages de maquette L-260")
local report = {}
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-19_L260")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-19_L260"
		backups.Parent = SS.MapBackups
	end
	for _, n in { "UI_WeaponShop", "UI_AuraShop", "UI_Displayed", "UI_RobuxShop_v2" } do
		if not backups:FindFirstChild(n) then
			SG[n]:Clone().Parent = backups
		end
	end

	-- (a) texte des boutons Equip de la boutique d'armes au-dessus de leur fond
	-- Template et cartes d'exemple Preview_* (retirées par le code, mais la maquette doit montrer le texte).
	local n = 0
	for _, d in SG.UI_WeaponShop.Root.List:GetDescendants() do
		if d.Name == "EquipButton" and d:IsA("TextButton") then
			d.ZIndex = 15
			d.Shade.ZIndex = 16
			n += 1
		end
	end
	table.insert(report, string.format("(a) %d EquipButton à 15, Shade à 16", n))

	-- (b) boutiques d'armes et d'auras à 80 % de la hauteur, centrées
	for _, n in { "UI_WeaponShop", "UI_AuraShop" } do
		local gui = SG[n]
		local root = gui.Root
		local ar = root:FindFirstChildOfClass("UIAspectRatioConstraint")
		ar.AspectType = Enum.AspectType.FitWithinMaxSize
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.Size = UDim2.fromScale(0.8, 0.8)
		local sc = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
		sc.MinSize = Vector2.new(math.floor(300 * ar.AspectRatio), 300)
		sc.MaxSize = Vector2.new(math.floor(961 * ar.AspectRatio), 961)
		sc.Parent = root
		gui.DisplayOrder = 7
		table.insert(report, string.format("(b) %s 0,8 × 0,8, rapport %.3f, DisplayOrder 7", n, ar.AspectRatio))
	end

	-- (c) deux lignes entières dans la réserve
	local grid = SG.UI_Displayed.Dock.Panel.Reserve.ReserveList:FindFirstChildOfClass("UIGridLayout")
	local gap = grid.CellPadding.Y.Offset
	grid.CellSize = UDim2.new(grid.CellSize.X.Scale, grid.CellSize.X.Offset, 0.5, -math.ceil(gap / 2))
	table.insert(report, "(c) CellSize " .. tostring(grid.CellSize))

	-- (d) caméra de l'aperçu de la caisse exclusive
	local preview = SG.UI_RobuxShop_v2.Root.Window.List.Content.Crate.Icon.Preview
	local model = preview:FindFirstChildWhichIsA("Model")
	assert(model, "pas de modèle dans Crate.Icon.Preview")
	local old = preview:FindFirstChildOfClass("Camera")
	if old then
		old:Destroy()
	end
	local _, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.FieldOfView = FOV
	local distance = (size.Magnitude / 2) / math.sin(math.rad(FOV / 2)) * 0.98
	local dir = Vector3.new(-math.sin(math.abs(YAW)) * math.cos(PITCH), math.sin(PITCH), -math.cos(YAW) * math.cos(PITCH))
	camera.CFrame = CFrame.lookAt(dir * distance, Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera
	table.insert(report, "(d) Camera recréée")
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return table.concat(report, " ; ")
