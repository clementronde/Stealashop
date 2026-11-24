--!nonstrict
-- ui_hotbar_antivol_case.luau (L-286, demande de Cantin du 2026-11-21, relancée le 24/11 ; validée par Clément) : à
-- lancer en Edit. Le voile « sous antivol » de la barre du bas, UI_Hotbar.Bar.Template.AntiTheft, couvrait les 76 %
-- du haut de la case (Size {1,0},{0.76,0}) : il couvre maintenant toute la case ({1,0},{1,0}), Dim compris (fond
-- inchangé, 0,45). Padlock, ChainA et ChainB passent au centre (Y 0,5) et gardent leur taille en pixels ; ils sont
-- rangés dans un CanvasGroup LockArt à GroupTransparency 0,25 (75 % d'opacité d'un seul tenant : les chaînes ne se
-- voient pas à travers le cadenas). Noms inchangés ; le code ne lit que AntiTheft et AntiTheft.LockLabel (caché ici).
-- Aucun script. PREVIEW = true : rien ne change ; une copie de la barre avec la case d'exemple et son voile montrés
-- est posée dans StarterGui (_PREVIEW_CLAUDE_Hotbar, non archivable, à détruire). PREVIEW = false : la barre change
-- (sauvegarde ServerStorage/MapBackups/2026-11-24_Antivol).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local OLD_H = 0.76 -- ancienne hauteur du voile, en fraction de la case

local function apply(gui)
	local veil = gui.Bar.Template.AntiTheft
	if veil.Size.Y.Scale ~= 1 then
		-- les tailles en Y des enfants étaient en fraction de 0,76 de la case : on garde leurs pixels
		for _, name in { "ChainA", "ChainB", "Padlock" } do
			local c = veil:FindFirstChild(name, true)
			if c then
				c.Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, c.Size.Y.Scale * OLD_H, c.Size.Y.Offset)
			end
		end
	end
	veil.AnchorPoint = Vector2.new(0, 0)
	veil.Position = UDim2.fromScale(0, 0)
	veil.Size = UDim2.fromScale(1, 1)
	local art = veil:FindFirstChild("LockArt")
	if not art then
		art = Instance.new("CanvasGroup")
		art.Name = "LockArt"
		art.BackgroundTransparency = 1
		art.BorderSizePixel = 0
		art.Size = UDim2.fromScale(1, 1)
		art.ZIndex = 15
		art.Parent = veil
	end
	art.GroupTransparency = 0.25
	for _, name in { "ChainA", "ChainB", "Padlock" } do
		local c = veil:FindFirstChild(name, true)
		c.Parent = art
		c.Position = UDim2.fromScale(0.5, 0.5)
	end
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Hotbar")
	if old then
		old:Destroy()
	end
	local src = SG.UI_Hotbar
	local was = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = was
	copy.Name = "_PREVIEW_CLAUDE_Hotbar"
	copy.Archivable = false
	copy.Enabled = true
	copy.DisplayOrder = 200
	apply(copy)
	local tpl = copy.Bar.Template
	tpl.Visible = true
	tpl.AntiTheft.Visible = true
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : voile antivol de la barre du bas sur toute la case (L-286)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Antivol")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Antivol"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Hotbar") then
		SG.UI_Hotbar:Clone().Parent = backups
	end
	apply(SG.UI_Hotbar)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Hotbar.Bar.Template.AntiTheft : toute la case, LockArt à 75 %"
