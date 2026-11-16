--!strict
-- ShopFxController (vague 63, a209 ; liaison L-204 points 1 et 3 ; client) : démarre les animations des boutiques
-- qui suivent leurs écrans toutes seules : la boucle de la caisse exclusive (Controllers/UI/CrateLoop) et le solde de
-- diamants de UI_DiamondShop (Controllers/UI/DiamondBalance). La lueur d'un achat Robux (Controllers/UI/PurchaseGlow)
-- est appelée par le contrôleur qui ouvre l'invite d'achat. Réglages : Config/ShopFx.

local UI = script.Parent:WaitForChild("UI")
local CrateLoop = require(UI:WaitForChild("CrateLoop"))
local DiamondBalance = require(UI:WaitForChild("DiamondBalance"))

local ShopFxController = {}

function ShopFxController.Start()
	task.spawn(CrateLoop.Start)
	DiamondBalance.Start()
end

return ShopFxController
