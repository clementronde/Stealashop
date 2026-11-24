--!nocheck
-- Scénario « config » (a191) : Config/Index, récompenses fixes de zone (L-183).
advance(1000)
startServer()
local Tools = sharedModule("Config/Tools")
local Cosmetics = sharedModule("Config/Cosmetics")
local Zones = sharedModule("Config/Zones")

section("ZoneRewards : une ligne par zone, croissante, objets existants")
check(#Index.ZoneRewards == Index.ZoneCount and Index.ZoneCount == 6, "6 récompenses pour 6 zones")
local kinds = {}
for zone = 1, Index.ZoneCount do
	local r = Index.ZoneRewards[zone]
	local prev = Index.ZoneRewards[zone - 1]
	check(r.Cash > 0 and r.Speed > 0 and (prev == nil or (r.Cash > prev.Cash and r.Speed > prev.Speed)), `zone {zone} : {r.Cash} $, +{r.Speed} de Vitesse, plus que la zone d'avant`)
	local def = if r.Item.Kind == "Weapon" then Tools.ById[r.Item.Id] else Cosmetics.ById[r.Item.Id]
	check(def ~= nil and (r.Item.Kind == "Weapon" or def.Kind == r.Item.Kind), `zone {zone} : {r.Item.Kind} {r.Item.Id} au catalogue`)
	kinds[r.Item.Kind] = (kinds[r.Item.Kind] or 0) + 1
	local nextZone = Zones[zone + 1]
	if nextZone then
		check(r.Speed == nextZone.SpeedRequired / 10, `zone {zone} : Vitesse = 10 % de la zone {zone + 1}`)
	end
end
check(kinds.Weapon == 2 and kinds.Aura == 2 and kinds.Trail == 2, "deux armes, deux auras, deux trails")

section("lecture")
check(Index.ZoneCash(1) == 10000 and Index.ZoneCash(6) == 4500000000 and Index.ZoneCash(0) == 0 and Index.ZoneCash(7) == 0, "ZoneCash : 10 K$ … 4,5 B$, 0 hors des zones")
check(Index.ZoneReward(2).Item.Id == "Flame" and Index.ZoneReward(7) == nil, "ZoneReward(2) = Flame ; zone 7 : nil")
check(Index.ZoneRewardText(1) == "+$10K +300 SPEED +WRENCH", `texte zone 1 : « {Index.ZoneRewardText(1)} »`)
check(Index.ZoneRewardText(6) == "+$4.5B +1B SPEED +HYPERSPACE", `texte zone 6 : « {Index.ZoneRewardText(6)} »`)
check(Index.ZoneRewardText(9) == "" and Index.ZoneRewardName(9) == "", "zone inconnue : textes vides")
check(Index.ZoneRewardName(3) == "Turbo" and Index.ZoneRewardName(4) == "Sledgehammer", "noms affichés des objets")
check(Index.ZoneRewardIcon(1) == "TOOL_Wrench" and Index.ZoneRewardIcon(2) == "Aura_Flamme" and Index.ZoneRewardIcon(3) == "Trail_Turbo", `icônes : {Index.ZoneRewardIcon(1)}, {Index.ZoneRewardIcon(2)}, {Index.ZoneRewardIcon(3)}`)
check(Index.ZoneRewardIcon(0) == nil, "icône d'une zone inconnue : nil")

section("plus de pourcentages")
check(Index.ZoneBonus == nil and Index.ZoneSpeedBonus == nil and Index.ZoneCashMinutes == nil, "ZoneBonus, ZoneSpeedBonus, ZoneCashMinutes retirés")
check(Index.IncomeBonus == nil and Index.SpeedMultiplier == nil, "IncomeBonus et SpeedMultiplier retirés")
check(IndexService.GetIncomeBonus == nil and IndexService.GetSpeedMultiplier == nil, "IndexService : GetIncomeBonus et GetSpeedMultiplier retirés")
check(Index.View.PageSize == 8, "UI_Index_v4 : 8 cartes par page (4 × 2)")

summary("scénario config")
