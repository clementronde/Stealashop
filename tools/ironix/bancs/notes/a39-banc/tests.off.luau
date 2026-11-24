--!nocheck
-- Scénario « off » (pre.off.luau) : vitrine Robux, aperçu Rebirth et index coupés, comme avant L-071.
-- Les trois boutons du HUD sont cachés, rien ne s'ouvre ni ne change dans les écrans, la plaque du
-- comptoir Robux n'ouvre rien ; celle de la boutique d'armes marche toujours.

local HUD = buildHud(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
local WEAPON = buildWeaponShop(PLAYER_GUI)
local REBIRTH = buildRebirth(PLAYER_GUI)
local _, robuxCounter = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, true)
makeStall("ENV_Hub_WeaponStall", "WeaponShop", WEAPON_PIVOT, true)
P1:SetAttribute("Cash", 6400)
local robuxSnap = snapshot(ROBUX)
local rebirthSnap = snapshot(REBIRTH)
startClient()

section("Config/Features")
check(Features.RobuxShop == false and Features.RobuxShopPreview == false, "RobuxShop et RobuxShopPreview à false")
check(Features.Index == false and Features.Rebirth == false and Features.RebirthPreview == false, "Index, Rebirth et RebirthPreview à false")
check(not logHas("[Loader", "WARN", "client"), "aucun contrôleur en échec au chargement")

section("HUD : les trois boutons cachés")
for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
	check(hudButton(HUD, name).Visible == false, `{name} caché`)
end

section("rien ne s'ouvre")
check(robuxCounter:FindFirstChild("RobuxShopPrompt") == nil, "pas d'invite sur le comptoir Robux")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == false, "le bouton Shop n'ouvre rien")
click(hudButton(HUD, "RebirthButton"))
check(REBIRTH.Enabled == false, "le bouton Rebirth n'ouvre rien")
moveTo(onPadSpot(ROBUX_PIVOT))
advance(0.2)
check(ROBUX.Enabled == false, "la plaque du comptoir Robux n'ouvre rien")
local robuxChanges = diffSnapshot(robuxSnap, ROBUX)
check(#robuxChanges == 0, `UI_RobuxShop pas touché ({table.concat(robuxChanges, " ; ")})`)
local rebirthChanges = diffSnapshot(rebirthSnap, REBIRTH)
check(#rebirthChanges == 0, `UI_Rebirth pas touché ({table.concat(rebirthChanges, " ; ")})`)
check(#MARKET.prompts == 0 and #MARKET.infoCalls == 0, "aucun appel à MarketplaceService")

section("la plaque de la boutique d'armes marche toujours")
moveTo(onPadSpot(WEAPON_PIVOT))
advance(0.1)
check(WEAPON.Enabled == true, "UI_WeaponShop ouvert par sa plaque")

summary("scénario off")
