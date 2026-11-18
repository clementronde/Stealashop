--!nonstrict
-- ui_style_boutique.luau (décision de Clément du 2026-11-18, relayée par la session chef : « garde le style UI de la
-- boutique pour tous les UI du jeu ») : ce qui séparait encore les écrans de la boutique Robux refaite le 18/11.
-- Déjà communs depuis le 17-18/11 : corps de fenêtre translucide, recette de bouton, contours noirs, tailles de
-- fenêtre. Ce script ajoute :
--   1. Police : tout texte non vide qui n'est pas en Montserrat (FredokaOne des boutiques d'armes et d'auras, de
--      quelques billboards ; Arial par défaut) passe en Montserrat Heavy, comme la boutique (ExtraBold pour les
--      lignes d'effet et sous-titres).
--   2. Rayons : la texture dure UI_Tex_Rays (110553518823718) devient les rayons doux de la boutique
--      (96610322911997) dans l'index (cases), la boutique de diamants (packs) et les billboards (BB_Rarest) ; même
--      teinte (le code de l'index la colore par rareté), transparence 0,4 ; les fondus Fade ne coupent plus rien.
--   3. Billboards à cadre de panneau (BB_ShopInfo.Panel, BB_StoreInfo.Panel) : le cadre de la boutique (corps
--      #0E1016, contour noir, filet clair intérieur InnerLine, coins droits), à 0,35 de transparence au lieu de 0,5 :
--      ils flottent sur la scène nette, sans flou derrière. Pas BB_Rarest (plaque dorée voulue) ni BB_GuardShout.
-- Écrans traités : ceux du jeu (pas les anciens UI_Index, UI_Index_v2, UI_RobuxShop) et ReplicatedStorage/Assets/UI.
-- Aucun nom ne change. Sauvegardes : ServerStorage/MapBackups/2026-11-18_StyleBoutique. Peut se relancer, en Edit.
-- Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local HARD = "rbxassetid://110553518823718"
local SOFT = "rbxassetid://96610322911997"
local OLD = { UI_Index = true, UI_Index_v2 = true, UI_RobuxShop = true }
local SMALL = { Effect = true, Subtitle = true, Description = true, Desc = true }

local rec = CHS:TryBeginRecording("UI : style de la boutique sur tous les écrans (police, rayons)")
local stats = { fonts = 0, rays = 0, screens = {} }
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-18_StyleBoutique")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-18_StyleBoutique"
		folder.Parent = SS.MapBackups
	end
	local roots = {}
	for _, g in SG:GetChildren() do
		if g:IsA("ScreenGui") and g.Name:find("^UI_") and not OLD[g.Name] then
			table.insert(roots, g)
		end
	end
	local ui = RS.Assets:FindFirstChild("UI")
	if ui then
		table.insert(roots, ui)
	end
	for _, root in roots do
		local touched = 0
		local function backup()
			if touched == 0 and not folder:FindFirstChild(root.Name) then
				local copy = root:Clone()
				if copy:IsA("ScreenGui") then
					copy.Enabled = false
				end
				copy.Parent = folder
			end
			touched += 1
		end
		for _, d in root:GetDescendants() do
			if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
				local family = d.FontFace.Family:match("families/(.-)%.json") or d.FontFace.Family
				if family ~= "Montserrat" then
					backup()
					local weight = if SMALL[d.Name] then Enum.FontWeight.ExtraBold else Enum.FontWeight.Heavy
					d.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight, d.FontFace.Style)
					stats.fonts += 1
				end
			elseif (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image == HARD then
				backup()
				d.Image = SOFT
				d.ImageTransparency = 0.4
				d.ScaleType = Enum.ScaleType.Stretch
				local fade = d:FindFirstChild("Fade")
				if fade and fade:IsA("UIGradient") then
					fade.Transparency = NumberSequence.new(0)
				end
				stats.rays += 1
			end
		end
		if touched > 0 then
			table.insert(stats.screens, root.Name .. " " .. touched)
		end
	end

	-- 3. Billboards à cadre de panneau.
	for _, name in { "BB_ShopInfo", "BB_StoreInfo" } do
		local bb = ui and ui:FindFirstChild(name)
		local panel = bb and bb:FindFirstChild("Panel")
		if panel and panel:IsA("GuiObject") then
			panel.BackgroundColor3 = Color3.fromHex("0e1016")
			panel.BackgroundTransparency = 0.35
			local corner = panel:FindFirstChildOfClass("UICorner")
			if corner then
				corner:Destroy()
			end
			local s = panel:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			s.Thickness = 0.03
			s.Color = Color3.fromHex("08090c")
			s.Transparency = 0
			s.Parent = panel
			local line = panel:FindFirstChild("InnerLine") or Instance.new("Frame")
			line.Name = "InnerLine"
			line.BackgroundTransparency = 1
			line.BorderSizePixel = 0
			line.Position = UDim2.fromScale(0, 0)
			line.Size = UDim2.fromScale(1, 1)
			line.ZIndex = panel.ZIndex
			local ls = line:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			ls.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			ls.Thickness = 0.012
			ls.Color = Color3.fromHex("9ba2ad")
			ls.BorderStrokePosition = Enum.BorderStrokePosition.Inner
			ls.Parent = line
			line.Parent = panel
			table.insert(stats.screens, name .. " cadre")
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return string.format("%d textes en Montserrat, %d rayons doux : %s", stats.fonts, stats.rays, table.concat(stats.screens, ", "))
