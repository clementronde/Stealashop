--!nonstrict
-- ui_contours_noirs.luau (Clément, 2026-11-18 : « je pense que le contour des boutons noirs est mieux, donc mettre
-- tous les contours des boutons noirs ») : sur tous les boutons de la recette (ceux qui ont Lip et Rim, posés par
-- ui_tas_boutons.luau), le contour du bouton (son UIStroke, ou celui de son cadre Outline pour les boutons pour payer)
-- passe en noir #0D0D14. Rien d'autre ne change (faces, rebords, textes). Test fait avant : planche
-- StealAShop-Art/Captures/2026-11-18_ShopFigma/contours_noir_fondu.jpg. Peut se relancer, en Edit. Annulable.
-- Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local BLACK = Color3.fromHex("0d0d14")

local rec = CHS:TryBeginRecording("UI : contours des boutons en noir")
local count, screens = 0, {}
local ok, err = pcall(function()
	for _, gui in SG:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name:find("^UI_") then
			local n = 0
			for _, b in gui:GetDescendants() do
				if b:IsA("GuiButton") and b:FindFirstChild("Lip") and b:FindFirstChild("Rim") then
					local holder = b:FindFirstChild("Outline")
					local s = (holder and holder:IsA("GuiObject") and holder:FindFirstChildOfClass("UIStroke")) or b:FindFirstChildOfClass("UIStroke")
					if s then
						s.Color = BLACK
						n += 1
					end
				end
			end
			if n > 0 then
				count += n
				table.insert(screens, gui.Name .. " " .. n)
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return string.format("%d contours en noir : %s", count, table.concat(screens, ", "))
