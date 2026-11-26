--!nonstrict
-- ui_escape_v3_objet3d.luau (Clément, 2026-11-25 au soir, sur la capture grise : « L'item doit être en 3D, retirer le
-- fond de l'item, et mettre un sunburst ») : à lancer en Edit APRÈS ui_escape_v2_gris.luau.
--   - Card sans fond ni contour : l'objet flotte.
--   - Card.Preview (ViewportFrame, l'objet en 3D) visible et au premier plan ; ItemIcon reste en repli derrière (le
--     code le cache quand il a mis le modèle dans Preview).
--   - Le sunburst : Rays passe de SecuredFx dans Card, centré derrière Preview (il suit l'objet à toutes les tailles
--     d'écran), visible à tous les paliers, qui tourne (FigmaSpin, 18 °/s). Image provisoire UI_Tex_Rays ; le chef VFX
--     la remplace par FX_UI_Rays teinte à la couleur de la rareté.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Escape_v1 (état d'avant la v2).

local CHS = game:GetService("ChangeHistoryService")
local gui = game:GetService("StarterGui").UI_Escape

local rec = CHS:TryBeginRecording("UI : UI_Escape, objet en 3D sans fond, sunburst derrière")
local ok, err = pcall(function()
	local card = gui.Card
	card.BackgroundTransparency = 1
	local s = card:FindFirstChildOfClass("UIStroke")
	if s then
		s:Destroy()
	end
	local preview = card.Preview
	preview.Visible = true
	preview.Size = UDim2.fromScale(0.78, 0.78)
	preview.Position = UDim2.fromScale(0.5, 0.36)
	preview.ZIndex = 7
	preview.Ambient = Color3.fromRGB(200, 200, 200)
	preview.LightColor = Color3.fromRGB(255, 255, 255)
	preview.LightDirection = Vector3.new(-1, -1, -1)
	card.ItemIcon.ZIndex = 6
	local rays = gui.SecuredFx:FindFirstChild("Rays")
	if rays then
		rays.Parent = card
	end
	rays = card:FindFirstChild("Rays")
	assert(rays, "Rays introuvable : lancer d'abord ui_escape_v2_gris.luau")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = preview.Position
	rays.Size = UDim2.fromScale(1.25, 1.25)
	rays.ZIndex = 5
	rays.Visible = true
	rays.ImageTransparency = 0.25
	if rays.Image == "" then
		rays.Image = "rbxassetid://110553518823718" -- UI_Tex_Rays, en attendant FX_UI_Rays
	end
	rays:SetAttribute("FigmaSpin", 1)
	rays:SetAttribute("SpinSpeed", 18)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end

-- Suite (chef VFX, 25/11) : Rays, RaysBack et Burst centrés sur Preview, dans Card (tailles en multiples de Preview :
-- Rays 1,5 au palier normal, RaysBack 2,4, Burst 1,0 ; le code les règle par palier). Rain reste dans SecuredFx.
do
	local card = gui.Card
	local preview = card.Preview
	preview.BackgroundTransparency = 1
	local P = preview.Size.X.Scale
	local function center(o, k, z, tr, vis)
		if not o then
			return
		end
		o.Parent = card
		o.AnchorPoint = Vector2.new(0.5, 0.5)
		o.Position = preview.Position
		o.Size = UDim2.fromScale(P * k, P * k)
		o.ZIndex = z
		o.ImageTransparency = tr
		o.Visible = vis
		local ar = o:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = o
	end
	center(card:FindFirstChild("Rays"), 1.5, 5, 0.55, true)
	center(gui.SecuredFx:FindFirstChild("RaysBack") or card:FindFirstChild("RaysBack"), 2.4, 4, 0.6, false)
	center(gui.SecuredFx:FindFirstChild("Burst") or card:FindFirstChild("Burst"), 1.0, 6, 0, false)
end

return "UI_Escape : objet en 3D sans fond, Rays, RaysBack et Burst centrés sur Preview"
