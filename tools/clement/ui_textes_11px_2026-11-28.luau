-- Textes à 11 px au moins sur téléphone, et plus rien de coupé (règles de Clément, feu vert du Chef le 28/11) ; chef UI.
-- À lancer en Edit. Sauvegarde de l'avant : ServerStorage/MapBackups/2026-11-28_UI_textes_11px_avant (Index v3, arbre,
-- inventaire, rebirth). À relancer sans risque : chaque réglage est posé à sa valeur, sans s'ajouter.
-- Principe : un UITextSizeConstraint MinTextSize 11 ne fait grandir le texte que là où il passait sous 11 px (téléphone,
-- 844 × 332 et 667 × 317) ; sur PC, où le texte est déjà plus grand, rien ne change. Aucun nom du contrat ne change,
-- aucun script n'est posé.

local SG = game:GetService("StarterGui")
local MIN = 11

local function minText(t: Instance?, maxSize: number?)
	if not t or not t:IsA("GuiObject") then return end
	local c = t:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize or 100
		c.Parent = t
	end
	c.MinTextSize = MIN
	if c.MaxTextSize < MIN then c.MaxTextSize = MIN end
end

-- 1. Index : bandeaux des zones, fiche de l'objet, titre de la récompense ; liste qui s'arrête entre deux rangées.
local index = SG:FindFirstChild("UI_Index_v3")
if index then
	local win = index.Root.Window
	-- Les noms des zones (NameShade.ZoneName et ZoneTheme) ne sont PAS touchés : à 11 px, « MINI MART » passe sur
	-- 2 lignes dans une colonne de 57 px et la 2e ligne disparaît (vu en capture). Question pour Clément.
	minText(win.Detail:FindFirstChild("DetailRarity"))
	local mutations = win.Detail:FindFirstChild("DetailMutations")
	minText(mutations)
	if mutations then
		-- un peu plus large, pour que « Big · Gold · Rainbow » tienne sur une ligne à 11 px (PC : +1 px de texte)
		mutations.Position = UDim2.new(0.11, 0, mutations.Position.Y.Scale, 0)
		mutations.Size = UDim2.new(0.78, 0, mutations.Size.Y.Scale, 0)
	end
	minText(win.Rewards:FindFirstChild("RewardsTitle"))
	-- La 3e rangée de cartes sortait coupée aux trois quarts (mêmes proportions aux 5 tailles : la fenêtre a un rapport
	-- fixe) : la vue s'arrête maintenant dans l'écart entre la 2e et la 3e rangée.
	local list = win.ListPanel.List
	list.Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, 0.896, 0)
end

-- 2. Arbre : « LOCKED » des tuiles fermées, plus haut (4 px au zoom 1, 8,8 px au zoom téléphone 2,2 → 12 px).
local tree = SG:FindFirstChild("UI_SkillTree")
if tree then
	for _, tile in tree.Tree:GetChildren() do
		local locked = tile:FindFirstChild("Locked")
		local label = locked and locked:FindFirstChild("LockedLabel")
		if label then label.Size = UDim2.new(label.Size.X.Scale, 0, 0.09, 0) end
	end
	-- Sur téléphone, la phrase d'aide chevauchait le compteur d'argent (11 px) : les deux lignes descendent un peu.
	tree.Hint.Position = UDim2.new(0.5, 0, 0.085, 26)
	tree.HelpLabel.Position = UDim2.new(0.5, 0, 0.135, 34)
end

-- 2 bis. Récompenses, temps de jeu : la 4e ligne sortait coupée. Les lignes prennent un tiers de la vue (astuce des
-- lignes entières : CellSize en fraction de la liste, sans UIAspectRatioConstraint sous la grille).
local rewards = SG:FindFirstChild("UI_Rewards")
if rewards then
	local grid = rewards.Root.Window.PlaytimePage.List:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local ar = grid:FindFirstChildOfClass("UIAspectRatioConstraint")
		if ar then ar:Destroy() end
		grid.CellSize = UDim2.new(1, 0, 0.3333, -15)
	end
end

-- 3. Inventaire : rareté, mutation, Hold et Sell, compteurs des cartes d'outils et de potions.
local inv = SG:FindFirstChild("UI_Inventory")
if inv then
	for _, d in inv:GetDescendants() do
		local p = d.Parent
		if d:IsA("TextLabel") then
			if d.Name == "Rarity" and p and p.Name == "RarityBar" then minText(d)
			-- MutationTag.MutationLabel n'est PAS touché : à 11 px, « BIG GOLD » ne tient pas dans l'étiquette (vu en capture).
			elseif (d.Name == "Label" or d.Name == "LabelShadow") and p and (p.Name == "SellButton" or p.Name == "HoldButton") then minText(d)
			elseif d.Name == "Count" or d.Name == "ToolStat" or d.Name == "PotionStat" then minText(d)
			end
		elseif d:IsA("Frame") and d.Name == "RarityBar" then
			-- la barre suit son texte : 12 px au moins de haut
			local sc = d:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
			sc.MinSize = Vector2.new(0, 12)
			sc.Parent = d
		end
	end
end

-- 4. Rebirth : le bouton REBIRTH sortait de la fenêtre (téléphone, 1024 et 1366 × 710). Il est maintenant fixé en bas de
-- la fenêtre, hors de la liste qui défile ; la liste s'arrête au-dessus. Le code trouve ConfirmButton par son nom.
local rebirth = SG:FindFirstChild("UI_Rebirth")
if rebirth then
	local win = rebirth.Root.Window
	local body = win.Body
	local actions = win:FindFirstChild("Actions") or body:FindFirstChild("Actions")
	if actions then
		actions.Parent = win
		actions.AnchorPoint = Vector2.new(0.5, 1)
		actions.Position = UDim2.new(0.5, 0, 1, -10)
		actions.Size = UDim2.new(1, 0, 0, 48)
		actions.ZIndex = math.max(actions.ZIndex, body.ZIndex)
	end
	body.Size = UDim2.new(1, 0, 0.84, -78)
	-- YOU LOSE : la Force est retirée depuis le 14/11 (feu vert du Chef). « Upgrades » attend la réponse de Cantin.
	local row = body:FindFirstChild("Row3", true)
	local label = row and row:FindFirstChild("RowLabel")
	if label and label.Text == "Speed & Strength" then label.Text = "Speed" end
end

return "ok"
