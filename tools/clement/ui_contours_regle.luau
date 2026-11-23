--!nonstrict
-- ui_contours_regle.luau (Clément, 2026-11-21) : la règle des boutons sur tous les écrans de StarterGui, demandée par
-- Clément : « le contour de tous les boutons comme les boutons rectangles du HUD », « les boutons ne doivent pas se
-- superposer, même au survol (notamment le zZz) », « réduis d'un tout petit peu les croix pour fermer ».
-- Fiche : docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, section 9. Un seul script, rejouable (valeurs
-- absolues ou lues dans la sauvegarde), en Edit, annulable en une étape. Aucun nom changé, rien déplacé ni supprimé,
-- aucun script laissé dans l'UI.
--
-- La règle du contour (celle des boutons rectangulaires du HUD, LeftRail) : UIStroke #0D0D14, Thickness 0,05 en
-- ScaledSize (5 % du bouton), BorderStrokePosition Outer, LineJoinMode Round, ApplyStrokeMode Border.
--
-- 1. Contours remis à la règle :
--    UI_Admin : les boutons visibles qui n'avaient aucun contour (outil des développeurs) ;
--    UI_HUD.AdminButton (2,5 px noir) ; UI_Settings…VfxRow.Toggle (2 px noir) ;
--    UI_Rebirth.ConfirmButton : ses faces Disabled, Ready, Confirm (noir 7 %, à l'intérieur) ;
--    UI_Hotbar : le fond Back des cases et du bouton Inventory (noir 3 %) ;
--    UI_Index_v3 : la face Clip des cartes (#1B1B24, 2 %).
--    Laissés tels quels : les titres et leurs contours (Label.UIStroke, dont les 7 boutons du HUD retouchés par la
--    session ui-tiktok, où UIStroke reste blanc et la couleur est dans le UIGradient Gleam), les choix du receleur (du
--    texte, sans cadre), les onglets à icône (récompenses, diamants), les tuiles de l'arbre (contour dessiné dans
--    l'image), les poignées des curseurs de UI_Settings.
-- 2. Croix de fermeture (bouton « X ») 10 % plus petites, minimum 44 px gardé ou ajouté (règle du téléphone) :
--    UI_Wheel, UI_Rebirth, UI_WeaponShop, UI_AuraShop, UI_Rewards, UI_Settings, UI_Index_v3, UI_DiamondShop,
--    UI_HelpInvite (taille d'origine lue dans la sauvegarde), UI_RobuxShop_v2 (valeur absolue). Pas touchés : le
--    bouton « Close » de l'arbre, la flèche « > » du dock, la croix de UI_Admin (déjà à 44 px fixes).
-- 3. Écarts pour que rien ne se chevauche au survol (× 1,1, Hover = Pop) ni au rebond du relâché (× 1,21) :
--    UI_HUD.RightRail.SleepButton (« zZz ») : le prix, qui dépassait de 13 px au-dessus du bouton et touchait
--      Displays, passe dans le bouton, en haut à droite ; Label et Cooldown un peu plus étroits pour lui laisser la place ;
--    UI_RobuxShop_v2 : les 3 boutons d'achat de la caisse ancrés au centre et 2,3 % plus étroits ;
--    UI_Index_v3 : écart des cartes 2,5 % en largeur et 6 px en hauteur (il était de 2 % et 0 px) ;
--    UI_DiamondShop : le bouton « + » décollé de la croix (ils se chevauchaient de 6 px sur les petits écrans, à cause
--      du minimum de 44 px), et le compteur Header.Balance décalé d'autant pour rester libre ; onglets un peu plus
--      écartés ;
--    UI_Admin : les 6 boutons de type (KindRow) écartés de 10 px, et 77 px de large au lieu de 80, pour tenir dans la rangée ;
--    UI_SkillTree : le bouton « Close » passe du bas au centre au coin en bas à droite (il recouvrait les hexagones du bas).
-- Sauvegardes : ServerStorage/MapBackups/2026-11-21_Contours/<Ecran> (une seule fois par écran, avant tout changement).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BACKUP = "2026-11-21_Contours"
local INK = Color3.fromHex("0d0d14")
local CLOSE_FACTOR = 0.9
local MIN_TAP = 44

local SCREENS = {
	"UI_Admin", "UI_HUD", "UI_Settings", "UI_Rebirth", "UI_Hotbar", "UI_Index_v3", "UI_DiamondShop",
	"UI_Wheel", "UI_WeaponShop", "UI_AuraShop", "UI_Rewards", "UI_HelpInvite", "UI_RobuxShop_v2", "UI_SkillTree",
}
local CROSSES = {
	UI_Wheel = "Root.Window.CloseButton", UI_Rebirth = "Root.Window.CloseButton", UI_WeaponShop = "Root.CloseButton",
	UI_AuraShop = "Root.CloseButton", UI_Rewards = "Root.Window.CloseButton", UI_Settings = "Root.Window.CloseButton",
	UI_Index_v3 = "Root.Window.CloseButton", UI_DiamondShop = "Root.Window.CloseButton", UI_HelpInvite = "Card.CloseButton",
}

local log = {}
local function note(text)
	table.insert(log, text)
end

local function resolve(root, path)
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function rule(stroke)
	stroke.Color = INK
	stroke.Thickness = 0.05
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0
	stroke.Enabled = true
end

local function ruleOn(object)
	if not object then
		return 0
	end
	local stroke = object:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = object
	end
	rule(stroke)
	return 1
end

local function minTap(button)
	local constraint = button:FindFirstChildOfClass("UISizeConstraint")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Parent = button
	end
	local min = constraint.MinSize
	constraint.MinSize = Vector2.new(math.max(min.X, MIN_TAP), math.max(min.Y, MIN_TAP))
end

local function backupScreens(backups)
	local folder = backups:FindFirstChild(BACKUP)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BACKUP
		folder.Parent = backups
	end
	for _, name in SCREENS do
		local gui = SG:FindFirstChild(name)
		if gui and not folder:FindFirstChild(name) then
			local copy = gui:Clone()
			copy.Enabled = false
			copy.Parent = folder
			task.wait() -- un écran à la fois : Studio reste fluide
		end
	end
	return folder
end

-- 1. Contours -------------------------------------------------------------------------------------------------
local function contours()
	local n = 0
	local admin = SG:FindFirstChild("UI_Admin")
	if admin then
		for _, d in admin:GetDescendants() do
			if d:IsA("GuiButton") and d.BackgroundTransparency < 0.95 then
				n += ruleOn(d)
			end
		end
	end
	n += ruleOn(resolve(SG, "UI_HUD.AdminButton"))
	local toggle = SG:FindFirstChild("UI_Settings") and SG.UI_Settings:FindFirstChild("VfxRow", true)
	n += ruleOn(toggle and toggle:FindFirstChild("Toggle"))
	local confirm = SG:FindFirstChild("UI_Rebirth") and SG.UI_Rebirth:FindFirstChild("ConfirmButton", true)
	if confirm then
		for _, face in { "Disabled", "Ready", "Confirm" } do
			n += ruleOn(confirm:FindFirstChild(face))
		end
	end
	local hotbar = SG:FindFirstChild("UI_Hotbar")
	if hotbar then
		for _, d in hotbar:GetDescendants() do
			if d:IsA("GuiButton") and d:FindFirstChild("Back") then
				n += ruleOn(d.Back)
			end
		end
	end
	local index = SG:FindFirstChild("UI_Index_v3")
	if index then
		for _, d in index:GetDescendants() do
			if d:IsA("GuiButton") then
				local clip = d:FindFirstChild("Clip")
				if clip and clip:FindFirstChildOfClass("UIStroke") then
					n += ruleOn(clip)
				end
			end
		end
	end
	note(("contours remis à la règle : %d"):format(n))
end

-- 2. Croix --------------------------------------------------------------------------------------------------------
local function crosses(folder)
	local n = 0
	for screen, path in CROSSES do
		local live = resolve(SG, screen .. "." .. path)
		local saved = resolve(folder, screen .. "." .. path) -- taille d'origine, prise avant le premier passage
		if live and saved then
			local s = saved.Size
			live.Size = UDim2.new(s.X.Scale * CLOSE_FACTOR, s.X.Offset * CLOSE_FACTOR, s.Y.Scale * CLOSE_FACTOR, s.Y.Offset * CLOSE_FACTOR)
			minTap(live)
			n += 1
		end
	end
	local shopClose = resolve(SG, "UI_RobuxShop_v2.Root.Window.CloseButton")
	if shopClose then
		shopClose.Size = UDim2.fromScale(0.0673 * CLOSE_FACTOR, 0.11 * CLOSE_FACTOR)
		minTap(shopClose)
		n += 1
	end
	note(("croix réduites : %d"):format(n))
end

-- 3. Écarts -------------------------------------------------------------------------------------------------------
local function gaps()
	-- « zZz » : le prix dans le bouton, en haut à droite
	-- seulement tant que le bouton est une pilule : depuis le 21/11, ui_hud_tuiles_speed_sleep.luau en fait un carré
	-- (UIAspectRatioConstraint à 1), avec le prix à sa place ; on n'y touche plus ici
	local sleep = resolve(SG, "UI_HUD.RightRail.SleepButton")
	local sleepRatio = sleep and sleep:FindFirstChildOfClass("UIAspectRatioConstraint")
	if sleepRatio and sleepRatio.AspectRatio <= 1.5 then
		sleep = nil
		note("zZz : déjà en carré, pas touché")
	end
	if sleep then
		local price, label, cooldown = sleep:FindFirstChild("Price"), sleep:FindFirstChild("Label"), sleep:FindFirstChild("Cooldown")
		if price then
			price.AnchorPoint = Vector2.new(0, 0)
			price.Size = UDim2.fromScale(0.26, 0.3125)
			price.Position = UDim2.fromScale(0.965 - 0.26, 0.06)
		end
		for _, text in { label, cooldown } do
			if text then
				text.Size = UDim2.fromScale(0.32, 0.5)
			end
		end
		note("zZz : prix dans le bouton")
	end
	-- boutique Robux : boutons de la caisse ancrés au centre, 2,3 % plus étroits
	local row = resolve(SG, "UI_RobuxShop_v2.Root.Window.List.Content.Crate.BuyRow")
	if row then
		local width = 0.309
		for i, center in { width / 2, 0.5, 1 - width / 2 } do
			local button = row:FindFirstChild("BuyButton" .. i)
			if button then
				button.AnchorPoint = Vector2.new(0.5, 0.5)
				button.Size = UDim2.fromScale(width, 1)
				button.Position = UDim2.fromScale(center, 0.5)
			end
		end
		note("caisse : boutons ancrés au centre")
	end
	-- index : écart des cartes
	local index = SG:FindFirstChild("UI_Index_v3")
	if index then
		local n = 0
		for _, d in index:GetDescendants() do
			if d:IsA("UIGridLayout") and d.Parent and d.Parent.Name == "Cards" then
				d.CellPadding = UDim2.new(0.025, 0, 0, 6)
				n += 1
			end
		end
		note(("index : %d grilles de cartes écartées"):format(n))
	end
	-- diamants : « + » décollé de la croix, onglets écartés
	local diamond = SG:FindFirstChild("UI_DiamondShop")
	if diamond then
		local add = diamond:FindFirstChild("AddButton", true)
		if add then
			-- bord droit du « + » = bord droit de la croix (0,9878) − sa largeur réduite (0,0606) − 28 px : l'écart tient
			-- même quand la croix est élargie par son minimum de 44 px (fenêtre de 400 px de large et plus)
			add.Position = UDim2.new(0.9272, -28, add.Position.Y.Scale, add.Position.Y.Offset)
		end
		-- le compteur de diamants (Header.Balance) suit vers la gauche : 8 px au moins avant le « + », le titre reste libre
		local balance = diamond:FindFirstChild("Balance", true)
		if balance then
			balance.Position = UDim2.new(0.83, -41, balance.Position.Y.Scale, balance.Position.Y.Offset)
		end
		local tab = diamond:FindFirstChild("GetDiamondsTab", true)
		local list = tab and tab.Parent:FindFirstChildOfClass("UIListLayout")
		if list then
			list.Padding = UDim.new(0.03, 0)
		end
		note("diamants : « + » décollé, onglets écartés")
	end
	-- arbre de compétences : le bouton « Close », centré en bas, recouvrait les deux hexagones du bas (surtout sur
	-- téléphone) : il passe dans le coin en bas à droite, libre sur PC comme sur téléphone (même taille, même style)
	local tree = SG:FindFirstChild("UI_SkillTree")
	local treeClose = tree and tree:FindFirstChild("CloseButton")
	if treeClose then
		treeClose.AnchorPoint = Vector2.new(1, 1)
		treeClose.Position = UDim2.fromScale(0.985, 0.975)
		note("arbre : « Close » dans le coin")
	end
	-- Admin : les 6 boutons de type (Item, Box, Aura…) se touchaient de 2 px au survol : écart 10 px, boutons de 77 px
	local kindRow = SG:FindFirstChild("UI_Admin") and SG.UI_Admin:FindFirstChild("KindRow", true)
	if kindRow then
		local list = kindRow:FindFirstChildOfClass("UIListLayout")
		if list then
			list.Padding = UDim.new(0, 10)
		end
		for _, child in kindRow:GetChildren() do
			if child:IsA("GuiButton") then
				child.Size = UDim2.new(0, 77, child.Size.Y.Scale, child.Size.Y.Offset)
			end
		end
		note("admin : boutons de type écartés")
	end
end

local rec = CHS:TryBeginRecording("UI : règle des boutons sur tous les écrans (2026-11-21)")
local ok, err = pcall(function()
	local backups = SS:FindFirstChild("MapBackups")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "MapBackups"
		backups.Parent = SS
	end
	local folder = backupScreens(backups)
	contours()
	crosses(folder)
	gaps()
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return table.concat(log, " ; ")
