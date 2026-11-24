--!nocheck
-- Scénario « config » (a201, copie du scénario d'a191) : Config/Index, la récompense de zone n'est qu'un objet (L-192).
advance(1000)
startServer()
local Tools = sharedModule("Config/Tools")
local Cosmetics = sharedModule("Config/Cosmetics")

section("ZoneRewards : un objet par zone, rien d'autre")
check(#Index.ZoneRewards == Index.ZoneCount and Index.ZoneCount == 6, "6 récompenses pour 6 zones")
local kinds = {}
local ids = {}
for zone = 1, Index.ZoneCount do
	local r = Index.ZoneRewards[zone]
	local keys = {}
	for key in r do
		table.insert(keys, key)
	end
	check(#keys == 1 and r.Item ~= nil and r.Cash == nil and r.Speed == nil and r.Diamonds == nil, `zone {zone} : Item seul ({table.concat(keys, ", ")})`)
	local def = if r.Item.Kind == "Weapon" then Tools.ById[r.Item.Id] else Cosmetics.ById[r.Item.Id]
	check(def ~= nil and (r.Item.Kind == "Weapon" or def.Kind == r.Item.Kind), `zone {zone} : {r.Item.Kind} {r.Item.Id} au catalogue`)
	kinds[r.Item.Kind] = (kinds[r.Item.Kind] or 0) + 1
	table.insert(ids, r.Item.Id)
end
check(table.concat(ids, ",") == "Wrench,Flame,Turbo,Sledgehammer,Galaxy,Hyperspace", `objets d'a191 gardés : {table.concat(ids, ",")}`)
check(kinds.Weapon == 2 and kinds.Aura == 2 and kinds.Trail == 2, "deux armes, deux auras, deux trails")

section("lecture")
check(Index.ZoneCash == nil, "ZoneCash retiré")
check(Index.ZoneReward(2).Item.Id == "Flame" and Index.ZoneReward(7) == nil, "ZoneReward(2) = Flame ; zone 7 : nil")
check(Index.ZoneRewardText(1) == "+WRENCH", `texte zone 1 : « {Index.ZoneRewardText(1)} »`)
check(Index.ZoneRewardText(6) == "+HYPERSPACE", `texte zone 6 : « {Index.ZoneRewardText(6)} »`)
check(Index.ZoneRewardText(9) == "" and Index.ZoneRewardName(9) == "", "zone inconnue : textes vides")
check(Index.ZoneRewardName(3) == "Turbo" and Index.ZoneRewardName(4) == "Sledgehammer", "noms affichés des objets")
check(Index.ZoneRewardIcon(1) == "TOOL_Wrench" and Index.ZoneRewardIcon(2) == "Aura_Flamme" and Index.ZoneRewardIcon(3) == "Trail_Turbo", `icônes : {Index.ZoneRewardIcon(1)}, {Index.ZoneRewardIcon(2)}, {Index.ZoneRewardIcon(3)}`)
check(Index.ZoneRewardIcon(0) == nil, "icône d'une zone inconnue : nil")

section("plus de pourcentages")
check(Index.ZoneBonus == nil and Index.ZoneSpeedBonus == nil and Index.ZoneCashMinutes == nil, "ZoneBonus, ZoneSpeedBonus, ZoneCashMinutes retirés")
check(IndexService.GetIncomeBonus == nil and IndexService.GetSpeedMultiplier == nil, "IndexService : GetIncomeBonus et GetSpeedMultiplier retirés")
check(Index.View.PageSize == 8, "UI_Index_v4 : 8 cartes par page (4 × 2)")

summary("scénario config")
