--!nonstrict
-- ui_images_groupe.luau (26/11) : remplace les images des boutons validés publiées sur le compte perso de Clément par
-- leurs copies publiées au nom du groupe RoundStone Studio (mêmes pixels, rendues depuis ses dessins Figma ; Decals
-- publiés par Clément avec publier_fx.ps1, Id d'image lus par InsertService:LoadAsset → Decal.Texture, tailles
-- identiques vérifiées). Le soleil de UI_Escape.Card.Rays prend FX_UI_Rays du chef VFX.
-- Le soleil des boutons du HUD et les 3 reflets (images de FrameWisp) ne sont PAS remplacés ici : ils attendent nos
-- propres textures (Textures_UI).
-- PREVIEW = true : compte seulement. Sauvegarde : ServerStorage/MapBackups/2026-11-26_Images_avant_groupe.

local PREVIEW = true

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local MAP = { -- ancienne image (compte perso) → nouvelle image (groupe)
	["116649210912980"] = "106152192388594", -- UI_Btn_Rect_Vert_bg
	["121701361036689"] = "121128273060347", -- UI_Btn_Rect_Bleu_bg
	["106832425220089"] = "78893674434588", -- UI_Btn_Rect_Rose_bg
	["96125036634075"] = "138217238375689", -- UI_Btn_Carre_Vert_bg
	["135718041377684"] = "132315684078469", -- UI_Btn_Carre_Bleu_bg
	["80338194945818"] = "108792730558229", -- UI_Btn_Carre_Rose_bg
	["95865487016240"] = "130385405874171", -- UI_Btn_Carre_Or_bg
	["126967898545063"] = "138662707772978", -- UI_Btn_Icon_Shop_PC
	["100069128319577"] = "109481697421629", -- UI_Btn_Icon_Shop_Tel
	["93573275119926"] = "79613310882765", -- UI_Btn_Icon_Index
	["140698887397491"] = "101582522402204", -- UI_Btn_Icon_Upgrades
	["129815299195794"] = "72080391578022", -- UI_Btn_Icon_Display
}
local RAYS = "rbxassetid://70682642272028" -- FX_UI_Rays (chef VFX, groupe)

local roots = { SG }
local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
local ui = assets and assets:FindFirstChild("UI")
if ui then
	table.insert(roots, ui)
end

local found, owners = {}, {}
for _, r in roots do
	for _, d in r:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			local id = d.Image:match("^rbxassetid://(%d+)$")
			if id and MAP[id] then
				table.insert(found, d)
				local top = d
				while top.Parent and top.Parent ~= SG and top.Parent ~= ui do
					top = top.Parent
				end
				owners[top] = true
			end
		end
	end
end
local rays = SG:FindFirstChild("UI_Escape") and SG.UI_Escape:FindFirstChild("Card") and SG.UI_Escape.Card:FindFirstChild("Rays")
if rays then
	owners[SG.UI_Escape] = true
end

if PREVIEW then
	return #found .. " images à remplacer, et Card.Rays : " .. tostring(rays ~= nil)
end

local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-26_Images_avant_groupe") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-26_Images_avant_groupe"
	for top in owners do
		top:Clone().Parent = f
	end
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : images des boutons validés au nom du groupe, FX_UI_Rays sur Card.Rays")
local ok, err = pcall(function()
	for _, d in found do
		d.Image = "rbxassetid://" .. MAP[d.Image:match("%d+")]
	end
	if rays then
		rays.Image = RAYS
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return #found .. " images remplacées, Card.Rays = FX_UI_Rays"
