-- BB_ShelfOpen.Row.LuckIcon : l'émoji 🍀 (TextLabel) devient l'icône de trèfle du jeu (ImageLabel, UI_Icon_DP_Luck3),
-- demande de Clément du 2026-11-25 (« mettre une icône qui ressemble plus » ; « l'icône du trèfle, je crois que tu en as
-- déjà un »). Même nom, même taille (52 × 52 px), même LayoutOrder : ShelfOpenController le lit comme GuiObject et le
-- fait pencher à chaque tic (Rotation), donc rien ne change côté code.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_LuckIcon. À relancer sans risque.

local bb = game:GetService("ReplicatedStorage").Assets.UI.BB_ShelfOpen
local row = bb.Row
local old = row:FindFirstChild("LuckIcon")
if not old or old:IsA("ImageLabel") then
	return "rien à faire"
end
local backups = game:GetService("ServerStorage"):FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_LuckIcon") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_LuckIcon"
	bb:Clone().Parent = f
	f.Parent = backups
end
local img = Instance.new("ImageLabel")
img.Name = "LuckIcon"
img.BackgroundTransparency = 1
img.Size = old.Size
img.LayoutOrder = old.LayoutOrder
img.AnchorPoint = old.AnchorPoint
img.Position = old.Position
img.Rotation = old.Rotation
img.ZIndex = old.ZIndex
img.Image = game:GetService("ReplicatedStorage").Assets.Icons.UI_Icon_DP_Luck3.Texture
img.ScaleType = Enum.ScaleType.Fit
for k, v in old:GetAttributes() do
	img:SetAttribute(k, v)
end
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 1
ar.Parent = img
for _, c in old:GetChildren() do
	if not c:IsA("UIStroke") and not c:IsA("UITextSizeConstraint") then
		c:Clone().Parent = img
	end
end
old:Destroy()
img.Parent = row
return "LuckIcon = " .. img.Image
