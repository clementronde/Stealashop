--!nonstrict
-- ui_escape_v4_garder.luau (Clément, 25/11 dans la nuit, sur ITEM SECURED : « on a dit qu'on retirait le fond, que
-- l'objet était en 3D, qu'il y avait un sunburst, etc. Comme garder objet final. ») : à lancer en Edit APRÈS
-- ui_escape_v3_objet3d.luau. Aligne UI_Escape sur l'écran « Keep it? / Get a copy? » final (Figma page 42, 344:372) :
--   - le voile noir à faible opacité est montré (Veil, transparence 0,5) ;
--   - l'objet en 3D sans fond (Card.Preview) avec le sunburst derrière (Card.Rays), comme avant ;
--   - le nom en grand et en blanc sous l'objet (Card.ItemName) ;
--   - une seule ligne sous le nom : rareté, $/s en vert, poids (Card.Rarity, Card.Income, Card.Weight, visible).
-- Aucun nom ne change. Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Escape_avant_v4.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local function place(o, ap, pos, size)
	o.AnchorPoint = ap
	o.Position = pos
	o.Size = size
end

local function apply(gui)
	local veil = gui.Veil
	veil.Visible = true
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.5
	local card = gui.Card
	place(card.ItemName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.67), UDim2.fromScale(1.3, 0.13))
	card.ItemName.TextXAlignment = Enum.TextXAlignment.Center
	local y, h = 0.81, 0.075
	place(card.Rarity, Vector2.new(1, 0), UDim2.fromScale(0.31, y), UDim2.fromScale(0.36, h))
	card.Rarity.TextXAlignment = Enum.TextXAlignment.Right
	place(card.Income, Vector2.new(0.5, 0), UDim2.fromScale(0.5, y), UDim2.fromScale(0.34, h))
	card.Income.TextXAlignment = Enum.TextXAlignment.Center
	place(card.Weight, Vector2.new(0, 0), UDim2.fromScale(0.69, y), UDim2.fromScale(0.3, h))
	card.Weight.TextXAlignment = Enum.TextXAlignment.Left
	card.Weight.Visible = true
	card.Weight.TextColor3 = Color3.new(1, 1, 1)
	-- le sunburst doux du HUD (validé) à la place de UI_Tex_Rays, dont les bords carrés se voyaient ; le chef VFX
	-- le remplacera par FX_UI_Rays une fois publiée
	card.Rays.Image = "rbxassetid://70682642272028" -- FX_UI_Rays (chef VFX, au nom du groupe)
	card.Rays.ImageTransparency = 0.35
	-- pas de caisse sous l'objet : l'écran « Get a copy? » n'en a pas, et elle chevauchait la ligne rareté · $/s · poids
	gui.Banner.BoxIcon.Visible = false
end

local gui = SG.UI_Escape
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Escape_avant_v4") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Escape_avant_v4"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Escape aligné sur Get a copy (voile, nom, ligne rareté · $/s · poids)")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Escape v4 : aligné sur l'écran Get a copy"
