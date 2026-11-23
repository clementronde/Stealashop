--!nonstrict
-- ui_displayed_telephone.luau (Clément, 2026-11-22) : UI_Displayed sur téléphone, boutons d'au moins 44 px (règle UI du
-- projet). À lancer en Edit après ui_displayed_v2.luau. Aucun script, aucun nom changé.
--
-- Sur un téléphone en paysage (iPhone 17 Pro : 750 x 381), le panneau ne fait que 335 px de haut : la croix faisait
-- 24 px, DISPLAY BEST 37 px, REMOVE / DISPLAY / SELL 18 px et YES / NO 25 px. Des UISizeConstraint « PhoneMin » ne
-- jouent que sur les petits écrans ; sur PC (1920 x 1080), rien ne bouge à quelques pixels près :
--   - Header et CloseButton : 44 px au moins ;
--   - List : commence sous l'en-tête (0.085 + 18 px) et finit au-dessus de DISPLAY BEST (0.765 - 20 px), ScrollTrack
--     aligné dessus ;
--   - DisplayBestButton : accroché en bas (AnchorPoint 0, 1 ; Y 0.985), 44 px au moins ;
--   - Template : 100 px au moins (deux boutons empilés de 44 px), IconSlot en largeur 0.22 (sur PC la vignette est
--     limitée par la hauteur : même taille ; sur téléphone elle ne mord plus sur le texte) ; ses boutons 44 px au moins ;
--   - SectionTemplate : 24 px au moins ; Confirm : 190 px au moins (YES / NO de 48 px).
-- Sur téléphone, la liste montre 2 lignes et défile. Vérifié en simulateur iPhone 17 Pro et FigmaRef_1920x1080 :
-- docs/claude/video/references/2026-11-21_ShopTikTok/frames/displayed_v2_telephone.jpg et displayed_v2_pc_couleurs.jpg.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-22_BoutonsFW/UI_Displayed_avantTelephone. Rejouable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local g = SG:FindFirstChild("UI_Displayed")
assert(g, "UI_Displayed introuvable")
local dock = g:FindFirstChild("Dock", true)
local panel = dock and dock:FindFirstChild("Panel")
local header = panel and panel:FindFirstChild("Header")
local list = panel and panel:FindFirstChild("List")
local tpl = list and list:FindFirstChild("Template")
assert(header and list and tpl, "UI_Displayed n'est pas en liste unique : lancer d'abord ui_displayed_v2.luau")

local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder")
mb.Name = "MapBackups" mb.Parent = SS
local bf = mb:FindFirstChild("2026-11-22_BoutonsFW") or Instance.new("Folder")
bf.Name = "2026-11-22_BoutonsFW" bf.Parent = mb
if not bf:FindFirstChild("UI_Displayed_avantTelephone") then
	local c = g:Clone() c.Name = "UI_Displayed_avantTelephone" c.Enabled = false c.Parent = bf
end

local function minSize(o, x, y)
	if not o then return end
	local c = o:FindFirstChild("PhoneMin")
	if not c then c = Instance.new("UISizeConstraint") c.Name = "PhoneMin" c.Parent = o end
	c.MinSize = Vector2.new(x, y)
end

local rec = CHS:TryBeginRecording("UI : Displays, boutons de 44 px sur téléphone")
local ok, err = pcall(function()
	minSize(header, 0, 44)
	minSize(header:FindFirstChild("CloseButton"), 44, 44)
	list.Position = UDim2.new(0.03, 0, 0.085, 18)
	list.Size = UDim2.new(0.94, 0, 0.765, -20)
	local st = panel:FindFirstChild("ScrollTrack")
	if st then st.Position = UDim2.new(0.97, 0, 0.085, 22) st.Size = UDim2.new(0, 5, 0.765, -28) end
	local db = dock:FindFirstChild("DisplayBestButton")
	if db then
		db.AnchorPoint = Vector2.new(0, 1)
		db.Position = UDim2.new(0.127, 0, 0.985, 0)
		minSize(db, 0, 44)
	end
	minSize(tpl, 0, 100)
	local icon = tpl:FindFirstChild("IconSlot")
	if icon then icon.Size = UDim2.new(0.22, 0, 0.84, 0) end
	local buttons = tpl:FindFirstChild("Buttons")
	for _, n in { "RemoveButton", "DisplayButton", "SellButton" } do minSize(buttons and buttons:FindFirstChild(n), 0, 44) end
	minSize(list:FindFirstChild("SectionTemplate"), 0, 24)
	minSize(dock:FindFirstChild("Confirm"), 0, 190)
end)
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
return "UI_Displayed : minimums téléphone posés"
