--!nonstrict
-- bb_shopinfo_lock_build.luau (demandes de Cantin en L-191, acceptées par Clément le 2026-11-15) :
--   1. Assets/UI/BB_ShopInfo un peu plus grand (8 × 4,4 studs → 10 × 5,5, × 1,25) et visible de plus loin
--      (MaxDistance 120 → 180). Aucun nom ne change.
--   2. Assets/UI/BB_AntiTheft : un cadenas doré, LockIcon (ImageLabel, l'image du cadenas de l'index), au-dessus
--      de ItemName et TimeLabel. Le billboard grandit (1,9 → 3,1 studs de haut) et monte d'autant (StudsOffset
--      2,6 → 3,2) : son bas reste à la même place au-dessus de l'objet. LockIcon est visible ; le code le cache
--      quand il écrit « UNLOCKED! » (objet posé au sol, dont le cadenas 3D saute déjà). Sur l'objet tenu en main,
--      le billboard part à la fin de l'antivol, donc rien à faire.
-- À lancer en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local UI = game:GetService("ReplicatedStorage").Assets.UI

local LOCK_IMAGE = "rbxassetid://112359396081383" -- cadenas doré, déjà dans UI_Index (Template.Lock)

local rec = CHS:TryBeginRecording("UI : BB_ShopInfo plus grand, cadenas dans BB_AntiTheft (L-191)")
local ok, err = pcall(function()
	local shopInfo = UI.BB_ShopInfo
	shopInfo.Size = UDim2.new(10, 0, 5.5, 0)
	shopInfo.MaxDistance = 180

	local bb = UI.BB_AntiTheft
	bb.Size = UDim2.new(4, 40, 3.1, 38)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	local icon = bb:FindFirstChild("LockIcon") or Instance.new("ImageLabel")
	icon.Name = "LockIcon"
	icon.Image = LOCK_IMAGE
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromScale(1, 0.4)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 1
	icon.Parent = bb
	bb.ItemName.Position = UDim2.fromScale(0, 0.4)
	bb.ItemName.Size = UDim2.fromScale(1, 0.3)
	bb.TimeLabel.Position = UDim2.fromScale(0, 0.7)
	bb.TimeLabel.Size = UDim2.fromScale(1, 0.3)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BB_ShopInfo et BB_AntiTheft : faits"
