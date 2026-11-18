--!nonstrict
-- ui_tas_fenetres.luau (demande de Clément du 2026-11-17, d'après Throw a Seed, note section 3) : fenêtres ramenées vers
-- 51 à 53 % × 55 à 64 % de l'écran, comme leur magasin. Boutique Robux et index : déjà à la même taille (52 % × 54 %,
-- ui_l218_shop_size.luau). Ici, seulement la taille de Root (le contenu suit, en Scale) :
--   UI_WeaponShop, UI_AuraShop : Root (0,515 ; 217 px ; 0,92) → (0,448 ; 135 px ; 0,92) : 995 × 591 sur PC (52 % × 55 %
--     au lieu de 63 % × 66 %), 513 × 304 sur téléphone (inchangé) ;
--   UI_Rewards : Root × 0,92 (52 % × 57 % sur PC au lieu de 57 % × 62 %) ;
--   UI_Rebirth : Root × 0,85 (53 % × 58 % au lieu de 63 % × 68 %) ;
--   UI_Settings : Root × 0,9 (59 % de haut au lieu de 66 %).
-- Les minimums de chaque écran gardent le téléphone. Sauvegardes dans ServerStorage/MapBackups/2026-11-17_ThrowASeed
-- (<écran>_avantTaille). À lancer une seule fois (les facteurs s'appliquent à la taille d'avant). Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local FACTORS = { UI_Rewards = 0.92, UI_Rebirth = 0.85, UI_Settings = 0.9 }
local SHOPS = { "UI_WeaponShop", "UI_AuraShop" }

local rec = CHS:TryBeginRecording("UI : fenêtres ramenées à 52 % × 55-60 % (Throw a Seed)")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_ThrowASeed")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_ThrowASeed"
		folder.Parent = SS.MapBackups
	end
	local function backup(gui)
		if not folder:FindFirstChild(gui.Name .. "_avantTaille") then
			local copy = gui:Clone()
			copy.Name = gui.Name .. "_avantTaille"
			copy.Enabled = false
			copy.Parent = folder
		end
	end
	for name, k in FACTORS do
		local gui = SG[name]
		backup(gui)
		local s = gui.Root.Size
		gui.Root.Size = UDim2.new(s.X.Scale * k, math.floor(s.X.Offset * k + 0.5), s.Y.Scale * k, math.floor(s.Y.Offset * k + 0.5))
	end
	for _, name in SHOPS do
		local gui = SG[name]
		backup(gui)
		gui.Root.Size = UDim2.new(0.448, 135, 0.92, 0)
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "fenêtres ramenées"
