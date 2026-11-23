--!nonstrict
-- ui_reglages_interrupteur_curseurs.luau (Clément, 2026-11-22) : applique à UI_Settings le style validé sur la maquette
-- (tools/clement/ui_reglages_interrupteur_curseurs_preview.luau, Figma 294:4, retouches de Clément comprises) :
-- interrupteur VfxRow.Toggle en pilule (OnFill vert / OffFill rose, chacun rebord + Face + Quilt + Rim), calé à droite ;
-- rond blanc ToggleKnob ; curseurs MusicRow / SoundRow : piste en creux, remplissage en pilule, rond blanc, Knob.Halo
-- caché (montré par le code pendant le glisser, si Ironix le veut). Fiche : docs/claude/notes/2026-11-22_video-reglages.md,
-- section 4.
-- Ce qui est lu par le code garde son nom et son parent (Toggle, OnFill, OffFill, ToggleKnob, ToggleLabel, Track, Fill,
-- Knob, ValueLabel). Retirés : les anciens décors Lip, Rim et Gloss de Track, et les anciens Gloss / Studs / dégradés de
-- Fill (non lus par le code). Aucun UIScale sur Knob (le code pose KnobScale lui-même). Aucun script.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-22_ReglagesStyle/UI_Settings. À ne lancer qu'une fois (ce n'est pas
-- rejouable tel quel : un 2e passage referait les calques).

local SG = game:GetService("StarterGui")
local INK = Color3.fromRGB(13, 13, 20)
local WHITE = Color3.new(1, 1, 1)
local GREEN, PINK = Color3.fromHex("9AFF09"), Color3.fromHex("FF3D8B")
local QUILT = "rbxassetid://87198718489515"

local function corner(o, s) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(s, 0) c.Parent = o return c end
local function stroke(o, color, thickness, inner, mode)
	local s = Instance.new("UIStroke")
	s.Color = color s.Thickness = thickness s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border s.LineJoinMode = Enum.LineJoinMode.Round
	if inner then s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
	s.Parent = o
	return s
end
local function grad(o, a, b, rot) local g = Instance.new("UIGradient") g.Rotation = rot or 90 g.Color = ColorSequence.new(a, b) g.Parent = o return g end
local function clear(o, pred) for _, c in ipairs(o:GetChildren()) do if pred(c) then c:Destroy() end end end
local function isBorder(c) return c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border end

-- Pilule au style des boutons : f devient le rebord sombre (Lip), avec dedans Face (dégradé), Quilt et Rim.
local function pill(f, color, z, opts)
	opts = opts or {}
	clear(f, function(c) return c:IsA("UIGradient") or c:IsA("UICorner") or isBorder(c) or c.Name == "Gloss" or c.Name == "Studs" or c.Name == "Face" end)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = color:Lerp(INK, 0.45)
	corner(f, 0.5)
	if not opts.noInk then stroke(f, INK, opts.ink or 0.065) end
	local face = Instance.new("Frame") face.Name = "Face" face.BorderSizePixel = 0
	face.Size = UDim2.fromScale(1, opts.faceH or 0.88) face.BackgroundColor3 = WHITE face.ZIndex = z
	corner(face, 0.5)
	grad(face, color:Lerp(WHITE, 0.28), color)
	local q = Instance.new("ImageLabel") q.Name = "Quilt" q.BackgroundTransparency = 1 q.Image = QUILT
	-- retouche de Clément (2026-11-22) : motif deux fois plus léger (0,82 -> 0,91)
	q.ScaleType = Enum.ScaleType.Tile q.ImageTransparency = opts.quilt or 0.91 q.Size = UDim2.fromScale(1, 1) q.ZIndex = z
	local a = f.AbsoluteSize.Y > 0 and f.AbsoluteSize.X / f.AbsoluteSize.Y or 3
	q.TileSize = UDim2.fromScale(math.clamp(0.9 / a, 0.03, 1), 0.9)
	corner(q, 0.5) q.Parent = face
	local rim = Instance.new("Frame") rim.Name = "Rim" rim.BackgroundTransparency = 1 rim.Size = UDim2.fromScale(1, 1) rim.ZIndex = z
	corner(rim, 0.5)
	local rs = stroke(rim, WHITE, opts.rim or 0.04, true) rs.Transparency = 0.45
	-- retouche de Clément (2026-11-22) : rien de la face sur l'ombre ; le liseré s'efface vers le bas (dégradé du contour)
	local rg = Instance.new("UIGradient") rg.Name = "RimFade" rg.Rotation = 90
	rg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(0.9, 1), NumberSequenceKeypoint.new(1, 1) })
	rg.Parent = rs
	rim.Parent = face
	face.Parent = f
	return face
end

-- Rond blanc : dégradé blanc -> gris bleuté, contour sombre. Sans motif (retouche de Clément, 2026-11-22).
local SLIDER_COLORS = { MusicRow = Color3.fromHex("A970FF"), SoundRow = Color3.fromHex("FFC62E") }
local function knobStyle(k, z)
	clear(k, function(c) return c:IsA("UIGradient") or c:IsA("UICorner") or isBorder(c) or c.Name == "Quilt" end)
	k.BackgroundColor3 = WHITE k.BackgroundTransparency = 0
	corner(k, 0.5)
	stroke(k, INK, 0.09)
	grad(k, WHITE, Color3.fromHex("CDD3E2"))
	local shade = k:FindFirstChild("Shade")
	if shade then clear(shade, function(c) return c:IsA("UICorner") end) corner(shade, 0.5) end
end

_G.ReglagesApres = function(window)
	local rows = window:FindFirstChild("Rows")
	-- interrupteur (VfxRow.Toggle)
	local t = rows.VfxRow.Toggle
	clear(t, isBorder)
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.24, 0.7)
	-- retouche de Clément (2026-11-22, Figma) : interrupteur calé à droite, sur le bord droit des flèches › (0,97)
	t.AnchorPoint = Vector2.new(1, 0.5) t.Position = UDim2.fromScale(0.97, 0.5)
	local tc = t:FindFirstChildOfClass("UISizeConstraint") if tc then tc.MinSize = Vector2.new(88, 44) end -- téléphone : pilule 2:1
	pill(t.OnFill, GREEN, t.OnFill.ZIndex)
	pill(t.OffFill, PINK, t.OffFill.ZIndex)
	local tk = t.ToggleKnob
	tk.Size = UDim2.fromScale(1, 0.7)
	tk.AnchorPoint = Vector2.new(1, 0.5) tk.Position = UDim2.fromScale(0.955, 0.44)
	knobStyle(tk, tk.ZIndex)
	local tl = t.ToggleLabel
	tl.AnchorPoint = Vector2.new(0, 0.5) tl.Position = UDim2.fromScale(0.1, 0.44) tl.Size = UDim2.fromScale(0.5, 0.56)
	local ts = tl:FindFirstChildOfClass("UIStroke") if ts then ts.Color = INK end
	local sh = t:FindFirstChild("Shade") if sh then clear(sh, function(c) return c:IsA("UICorner") end) corner(sh, 0.5) end
	-- curseurs (MusicRow, SoundRow)
	for _, rn in { "MusicRow", "SoundRow" } do
		local sl = rows[rn].Slider
		local tr, fill, knob = sl.Track, sl.Track.Fill, sl.Knob
		local color = SLIDER_COLORS[rn]
		sl.Size = UDim2.new(0.27, 0, sl.Size.Y.Scale, 0) -- « 100% » n'est plus mangé par le rond (PC et téléphone)
		local v = rows[rn].ValueLabel v.Position = UDim2.new(0.895, 0, v.Position.Y.Scale, 0) v.Size = UDim2.new(0.095, 0, v.Size.Y.Scale, 0)
		clear(tr, function(c) return c.Name == "Lip" or c.Name == "Rim" or c.Name == "Gloss" or c:IsA("UICorner") or isBorder(c) or c:IsA("UIGradient") end)
		tr.Size = UDim2.fromScale(1, 0.56)
		tr.BackgroundColor3 = WHITE tr.BackgroundTransparency = 0
		grad(tr, Color3.fromHex("080A12"), Color3.fromHex("2B3149"))
		corner(tr, 0.5) stroke(tr, INK, 0.12)
		clear(fill, function(c) return c:IsA("UIStroke") end)
		pill(fill, color, fill.ZIndex, { noInk = true, faceH = 0.78, rim = 0.06, quilt = 0.93 })
		knobStyle(knob, knob.ZIndex)
		-- halo caché, montré par le code pendant le glisser (proposition 6)
		local halo = knob:FindFirstChild("Halo") or Instance.new("Frame")
		halo.Name = "Halo" halo.AnchorPoint = Vector2.new(0.5, 0.5) halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.fromScale(1.75, 1.75) halo.BackgroundColor3 = color:Lerp(WHITE, 0.5) halo.BackgroundTransparency = 0.55
		halo.ZIndex = math.max(1, knob.ZIndex - 1) halo.Visible = false halo.BorderSizePixel = 0
		if not halo:FindFirstChildOfClass("UICorner") then corner(halo, 0.5) end
		halo.Parent = knob
	end
end

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local gui = SG:FindFirstChild("UI_Settings")
assert(gui, "UI_Settings introuvable")
local window = gui.Root.Window
assert(not window.Rows.VfxRow.Toggle.OnFill:FindFirstChild("Face"), "déjà appliqué")
local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder") mb.Name = "MapBackups" mb.Parent = SS
local bf = mb:FindFirstChild("2026-11-22_ReglagesStyle") or Instance.new("Folder") bf.Name = "2026-11-22_ReglagesStyle" bf.Parent = mb
if not bf:FindFirstChild("UI_Settings") then local c = gui:Clone() c.Enabled = false c.Parent = bf end
local rec = CHS:TryBeginRecording("UI : Réglages, interrupteur et curseurs au style des boutons")
local wasEnabled = gui.Enabled
gui.Enabled = true -- écran allumé le temps du passage : tailles à jour pour la mosaïque du motif
task.wait(0.2)
local ok, err = pcall(_G.ReglagesApres, window)
gui.Enabled = wasEnabled
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
return "UI_Settings : interrupteur et curseurs au nouveau style"
