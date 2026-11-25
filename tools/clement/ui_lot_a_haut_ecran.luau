-- Lot A des retours de test du 2026-11-25 (L-379, L-372, L-375) : le haut de l'écran et la carte Boosts.
-- À lancer dans Studio en Edit (barre de commande ou execute_luau). Ne touche aucun nom lu par le code.
--
-- (5) et (9) UI_Announce.Banner (annonces et bannière des caisses rares) : tout en haut, juste sous la barre de Roblox
--     ({0.5, 0}, {0, 4}), plus large (0,8) et plus allongé (rapport 20) : une phrase longue (« X secured a MYTHIC …
--     worth $225.4B! ») tient sur une seule ligne aux 5 tailles mesurées.
-- (7) Carte Boosts de UI_RobuxShop_v2 (chance serveur, L-375) : la ligne Effect passe de 7 à 10 px de haut sur
--     téléphone, sans toucher ItemName ni BuyButton.
-- UI_HUD.NightCountdown et AdminButton restent à leur place d'origine (en bas à droite) : un premier essai les avait
-- montés en haut, Clément les a voulus en bas à droite (25/11, « Le night in doit être en bas à droite »).
-- Sauvegardes : ServerStorage/MapBackups/2026-11-25_LotA (avant le lot) et 2026-11-25_NightRetour.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local announce = StarterGui:FindFirstChild("UI_Announce")
local shop = StarterGui:FindFirstChild("UI_RobuxShop_v2")
assert(announce and shop, "UI_Announce ou UI_RobuxShop_v2 introuvable")

local backups = ServerStorage:FindFirstChild("MapBackups")
assert(backups, "MapBackups introuvable")
local backup = backups:FindFirstChild("2026-11-25_LotA")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "2026-11-25_LotA"
	announce:Clone().Parent = backup
	shop:Clone().Parent = backup
	backup.Parent = backups
end

-- (5) et (9) UI_Announce.Banner
local banner = announce:FindFirstChild("Banner")
assert(banner and banner:IsA("GuiObject"), "UI_Announce.Banner introuvable")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 4)
banner.Size = UDim2.new(0.8, 0, 0.12, 0)
local ratio = banner:FindFirstChildOfClass("UIAspectRatioConstraint")
if ratio then
	ratio.AspectRatio = 20
end

-- (7) Carte Boosts
local boosts = shop:FindFirstChild("BoostsSection", true)
local grid = boosts and boosts:FindFirstChild("Grid")
local template = grid and grid:FindFirstChild("Template")
local effect = template and template:FindFirstChild("Effect")
if effect and effect:IsA("TextLabel") then
	effect.Position = UDim2.new(effect.Position.X.Scale, effect.Position.X.Offset, 0.6225, 0)
	effect.Size = UDim2.new(effect.Size.X.Scale, effect.Size.X.Offset, 0.085, 0)
	effect.TextWrapped = true
	effect.TextScaled = true
end

print("[ui_lot_a_haut_ecran] fait")
