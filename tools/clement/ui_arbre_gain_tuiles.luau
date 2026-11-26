--!nonstrict
-- ui_arbre_gain_tuiles.luau (L-332 point 2, Clément, 2026-11-24, relayé par le chef UI : « le gain par niveau doit se
-- lire sans clic, écrit en gros sur chaque tuile », DA d'accord) : à lancer en Edit.
--   - Chaque tuile Tile_* de UI_SkillTree.Tree reçoit, dans son cadre Info (caché sur une tuile verrouillée), un
--     TextLabel Gain : le gain du niveau suivant en gros (« +10% », « ×2 », « +1 »), écrit par le code. Pour lui faire
--     de la place, l'empilement de la tuile est resserré : Level, Icon (un peu plus petite), TileName, Gain, PriceRow,
--     tout à l'intérieur de l'hexagone (aucun débordement sur les tuiles voisines).
--   - InfoPanel : StatBox plus haut et NodeEffect plus gros (l'icône rapetisse encore un peu).
-- Aucun nom existant changé, aucun script. Version grise d'abord (STYLED = false : texte blanc simple), puis habillée
-- (STYLED = true : vert vif à contour noir, comme les gains du jeu).
-- PREVIEW = true : rien ne change ; une copie de l'écran avec des gains d'exemple est posée dans StarterGui
-- (_PREVIEW_CLAUDE_TreeGain, non archivable, à détruire). PREVIEW = false : l'écran change (sauvegarde
-- ServerStorage/MapBackups/2026-11-24_GainTuiles).

local PREVIEW = true
local STYLED = true

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local GREEN = Color3.fromHex("#5CFF5C")
local WHITE = Color3.new(1, 1, 1)
-- gains d'exemple de l'aperçu (le code écrira les vrais, depuis Config/SkillTree)
local SAMPLES = {
	Tile_Glass = "×2",
	Tile_ShopLevel = "+1 SLOT",
	Tile_Cameras = "+1",
	Tile_Guards = "+1",
	Tile_PotionLuck = "+10%",
	Tile_GlassRegen = "+20%",
	Tile_Curtain = "+30s",
	Tile_DoorGuard = "+1",
	Tile_PotionTime = "+15s",
}

local function place(o, y, w, h)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(0.5, y)
	o.Size = UDim2.fromScale(w, h)
end

local function tile(t, sample)
	local info = t:FindFirstChild("Info")
	if not info then
		return false
	end
	place(info.Level, 0.175, 0.34, 0.075)
	place(info.Icon, 0.33, 0.2, 0.2)
	place(info.TileName, 0.5, 0.72, 0.11)
	local gain = info:FindFirstChild("Gain")
	if not gain then
		gain = Instance.new("TextLabel")
		gain.Name = "Gain"
		gain.Parent = info
	end
	place(gain, 0.625, 0.78, 0.15)
	gain.BackgroundTransparency = 1
	gain.FontFace = info.TileName.FontFace
	gain.Text = sample or "+0%"
	gain.TextColor3 = if STYLED then GREEN else WHITE
	gain.TextScaled = false
	gain.TextWrapped = true
	gain.TextScaled = true
	gain.ZIndex = info.TileName.ZIndex
	local s = gain:FindFirstChildOfClass("UIStroke")
	if STYLED then
		s = s or Instance.new("UIStroke")
		s.Color = Color3.new(0, 0, 0)
		s.Thickness = 0.14
		s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = gain
	elseif s then
		s:Destroy()
	end
	place(info.PriceRow, 0.765, 0.6, 0.09)
	return true
end

local function panel(p)
	p.NodeIcon.Position = UDim2.fromScale(0.5, 0.37)
	p.NodeIcon.Size = UDim2.fromScale(1, 0.12)
	p.NodeLevel.Position = UDim2.fromScale(0.5, 0.457)
	p.NodeLevel.Size = UDim2.fromScale(0.8, 0.05)
	local box = p.StatBox
	box.Position = UDim2.fromScale(0.5, 0.487)
	box.Size = UDim2.fromScale(0.88, 0.215)
	box.NodeStat.Position = UDim2.fromScale(0.5, 0.2)
	box.NodeStat.Size = UDim2.fromScale(0.9, 0.26)
	box.NodeEffect.Position = UDim2.fromScale(0.5, 0.64)
	box.NodeEffect.Size = UDim2.fromScale(0.94, 0.56)
end

local function apply(gui, preview)
	local n = 0
	for _, t in gui.Tree:GetChildren() do
		if t.Name:match("^Tile_") then
			if tile(t, if preview then SAMPLES[t.Name] else nil) then
				n += 1
			end
		end
	end
	panel(gui.InfoPanel)
	return n
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_TreeGain")
	if old then
		old:Destroy()
	end
	local src = SG.UI_SkillTree
	local was = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = was
	copy.Name = "_PREVIEW_CLAUDE_TreeGain"
	copy.Archivable = false
	copy.Enabled = true
	copy.DisplayOrder = 200
	local n = apply(copy, true)
	copy.InfoPanel.StatBox.NodeEffect.Text = "+10%  ▶  +20%"
	copy.Parent = SG
	return "aperçu posé : " .. n .. " tuiles"
end

local rec = CHS:TryBeginRecording("UI : gain en gros sur les tuiles de l'arbre, NodeEffect plus gros (L-332 point 2)")
local count
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_GainTuiles")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_GainTuiles"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_SkillTree") then
		SG.UI_SkillTree:Clone().Parent = backups
	end
	count = apply(SG.UI_SkillTree, false)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_SkillTree : Gain sur " .. tostring(count) .. " tuiles, NodeEffect plus gros"
