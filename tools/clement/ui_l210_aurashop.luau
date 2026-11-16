--!nonstrict
-- ui_l210_aurashop.luau (retours du test de Clément du 2026-11-16, L-210) : boutique d'auras.
--   - UI_AuraShop.Root.List.Template : TrailIconRotation 90 → 0, les images des traînées ne sont plus couchées.
--   - ReplicatedStorage/Assets/UI/ShopCardBg : IconScale = 0,92 sur les 8 paliers (avant 0,62 pour le Commun jusqu'à 1
--     pour le Mythique) : tous les visuels ont la même taille, grande. Ces modèles servent aussi à la boutique d'armes,
--     dont les visuels passent eux aussi à la même taille.
-- Sauvegardes dans ServerStorage/MapBackups/2026-11-16_L210 (UI_AuraShop, ShopCardBg). Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local UI = game:GetService("ReplicatedStorage").Assets.UI

local ICON_SCALE = 0.92

local function backup(object)
	local folder = SS.MapBackups:FindFirstChild("2026-11-16_L210")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-16_L210"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(object.Name) then
		local copy = object:Clone()
		if copy:IsA("ScreenGui") then
			copy.Enabled = false
		end
		copy.Parent = folder
	end
end

local rec = CHS:TryBeginRecording("UI : traînées droites, visuels des boutiques à la même taille (L-210)")
local ok, err = pcall(function()
	local shop = SG.UI_AuraShop
	local tiers = UI.ShopCardBg
	backup(shop)
	backup(tiers)
	shop.Root.List.Template:SetAttribute("TrailIconRotation", 0)
	for _, tier in tiers:GetChildren() do
		if tier:GetAttribute("IconScale") ~= nil then
			tier:SetAttribute("IconScale", ICON_SCALE)
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique d'auras : traînées droites, visuels à la même taille"
