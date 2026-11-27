--!nonstrict
-- ui_inventaire_refG.luau (Clément, 26/11 : « Les onglets doivent être à gauche. […] La croix est trop grosse, pareil
-- pour equip best. ») : à lancer en Edit APRÈS ui_inventaire_refF.luau.
--   - Tabs en colonne à gauche du corps, sous le bandeau ; chaque onglet (rectangle validé) a au moins 44 px de haut
--     sur téléphone (largeur en unités mixtes 0,12 + 50 px, rapport du rectangle validé 3,22) ;
--   - la grille passe à droite des onglets ; recherche et compteurs sur une rangée au-dessus, aide en dessous ;
--   - EquipBestButton et CloseButton à la taille des boutons validés du HUD : au plus 290 × 90 et 70 × 70 sur PC
--     (rectangle Shop du LeftRail en 1920 × 1080), au moins 44 px de haut sur téléphone.
-- Aucun nom ne change. Sauvegarde : ServerStorage/MapBackups/2026-11-26_UI_Inventory_avant_refG.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local function place(o, ap, pos, size)
	o.AnchorPoint = ap
	o.Position = pos
	o.Size = size
end

local function sizeLimit(o, minSize, maxSize)
	local c = o:FindFirstChild("ValidatedSize")
	if not (c and c:IsA("UISizeConstraint")) then
		c = Instance.new("UISizeConstraint")
		c.Name = "ValidatedSize"
	end
	c.MinSize = minSize
	c.MaxSize = maxSize
	c.Parent = o
end

local function apply(gui)
	local w = gui.Root.Window
	local header = w.Header
	-- boutons du bandeau à la taille des validés
	local best = header.EquipBestButton
	place(best, Vector2.new(1, 0.5), UDim2.fromScale(0.905, 0.5), UDim2.fromScale(0.24, 0.8)) -- décollé de la croix
	sizeLimit(best, Vector2.new(142, 44), Vector2.new(290, 90))
	local close = header.CloseButton
	place(close, Vector2.new(1, 0.5), UDim2.fromScale(0.99, 0.5), UDim2.fromScale(0.07, 0.8))
	sizeLimit(close, Vector2.new(44, 44), Vector2.new(70, 70))
	for _, b in { best, close } do -- une seule contrainte de taille par bouton (l'ancienne de la croix gardait 86 px)
		for _, c in b:GetChildren() do
			if c:IsA("UISizeConstraint") and c.Name ~= "ValidatedSize" then
				c:Destroy()
			end
		end
	end
	-- onglets en colonne à gauche
	local tabs = w.Tabs
	place(tabs, Vector2.zero, UDim2.new(0.015, 0, 0.112, 24), UDim2.new(0.12, 56, 0.85, -40)) -- 45 px de haut en 844 × 390
	local tl = tabs:FindFirstChildOfClass("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Vertical
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tl.VerticalAlignment = Enum.VerticalAlignment.Top
	tl.Padding = UDim.new(0.02, 8) -- Clément, 26/11 : « écarte les onglets entre eux » (22 px en 1920 × 1080, 12 px sur téléphone)
	for _, t in tabs:GetChildren() do
		if t:IsA("GuiButton") then
			t.Size = UDim2.fromScale(1, 0.24) -- la largeur commande (rapport 3,22) : 44 px de haut en 844 × 390
		end
	end
	-- à droite des onglets : recherche et compteurs, puis l'aide, puis la grille
	local x0, x0px = 0.135, 66
	local search = w.SearchBox
	place(search, Vector2.zero, UDim2.new(x0, x0px, 0.112, 24), UDim2.new(0.3, 0, 0.04, 26))
	w.HintLabel.Position = UDim2.new(x0, x0px + 2, 0.162, 56)
	w.HintLabel.AnchorPoint = Vector2.zero
	w.HintLabel.Size = UDim2.new(0.45, 0, 0.03, 10)
	for i, n in { "CounterPill", "DisplayPill" } do
		local pill = w[n]
		place(pill, Vector2.new(1, 0), UDim2.new(if i == 1 then 0.77 else 0.98, 0, 0.117, 28), UDim2.new(0.19, 0, 0.03, 10))
	end
	place(w.List, Vector2.zero, UDim2.new(x0, x0px, 0.202, 72), UDim2.new(0.975 - x0, -x0px, 0.785, -80))
	local track = w:FindFirstChild("ScrollTrack")
	if track then
		place(track, Vector2.zero, UDim2.new(0.982, 0, 0.202, 72), UDim2.new(0, 6, 0.785, -80))
	end
	local empty = w:FindFirstChild("EmptyLabel")
	if empty then
		empty.Position = UDim2.new(0.56, x0px / 2, 0.6, 0)
	end
end

local gui = SG.UI_Inventory
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-26_UI_Inventory_avant_refG") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-26_UI_Inventory_avant_refG"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Inventory, onglets à gauche, croix et Equip Best à la taille des validés")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Inventory : onglets à gauche, croix et Equip Best réduits"
