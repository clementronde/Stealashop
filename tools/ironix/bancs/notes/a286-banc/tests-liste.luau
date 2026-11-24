--!nocheck
-- Banc a286, partie « liste » (harnais a191 copie a242) : UI_Displayed en une seule liste (écran après
-- tools/clement/ui_displayed_une_liste.luau : pas de Panel.Reserve, Template avec RemoveButton ET DisplayButton,
-- Panel.ListEmpty). Exposés d'abord (RemoveButton seul), puis la réserve dans la même List (DisplayButton seul, sous
-- les exposés) ; DisplayButton → PlaceFromReserve ; ListEmpty quand il n'y a rien ; aucune ligne « Reserve introuvable ».
advance(1000)
startServer()
local DisplayedConfig = sharedModule("Config/Displayed")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3, E3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare"), pick(4, "Epic")
check(C1 and U1 and R3 and E3, `objets de test trouvés ({C1}, {U1}, {R3}, {E3})`)

check(DisplayedConfig.ShowReserve == true, "Config/Displayed.ShowReserve = true")
local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "r3", R3, nil, 3, 3) -- réserve
addItem(data, "e3", E3, nil, 4, 4) -- réserve
local ada = join("Ada", data)
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildGui(playerGui)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")

section("liste unique : exposés puis réserve")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not logHas("Reserve introuvable", ""), "aucune ligne « Reserve introuvable »")
Displayed.Toggle()
flush()
local list = gui.Dock.Panel.List
local all = rowsIn(list, nil)
local exposed, reserve = rowsIn(list, "Row_"), rowsIn(list, "Reserve_")
check(#exposed == 2 and #reserve == 2 and #all == 4, `2 exposés et 2 en réserve dans la même List ({#exposed}, {#reserve}, {#all})`)
check(all[1] and all[2] and string.sub(all[1].Name, 1, 4) == "Row_" and string.sub(all[2].Name, 1, 4) == "Row_", "les exposés en haut")
check(all[3] and all[4] and string.sub(all[3].Name, 1, 8) == "Reserve_" and string.sub(all[4].Name, 1, 8) == "Reserve_", "la réserve en dessous")
local okButtons = true
for _, r in exposed do
	if not (r.RemoveButton.Visible == true and r.DisplayButton.Visible == false) then okButtons = false end
end
check(okButtons, "exposés : RemoveButton seul")
okButtons = true
for _, r in reserve do
	if not (r.RemoveButton.Visible == false and r.DisplayButton.Visible == true) then okButtons = false end
end
check(okButtons, "réserve : DisplayButton seul")
check(gui.Dock.Panel.ListEmpty.Visible == false, "ListEmpty caché (il y a des objets)")
check(gui.Dock.Panel.DisplayCount.CountLabel.Text == "2/4", `compte « {gui.Dock.Panel.DisplayCount.CountLabel.Text} »`)

section("DisplayButton : PlaceFromReserve")
local calls = #serverCalls("PlaceFromReserve")
local target = reserve[1]
local uid = string.match(target.Name, "^Reserve_%d+_(.+)$")
click(target.DisplayButton)
check(#serverCalls("PlaceFromReserve") == calls + 1 and serverCalls("PlaceFromReserve")[calls + 1].args[1] == uid, `PlaceFromReserve({uid})`)
advance(1.2)
exposed, reserve = rowsIn(list, "Row_"), rowsIn(list, "Reserve_")
check(#exposed == 3 and #reserve == 1, `après la pose : 3 exposés, 1 en réserve ({#exposed}, {#reserve})`)
all = rowsIn(list, nil)
check(all[4] and string.sub(all[4].Name, 1, 8) == "Reserve_", "la réserve reste sous les exposés")

section("RemoveButton : UnplaceItem")
calls = #serverCalls("UnplaceItem")
click(exposed[1].RemoveButton)
check(#serverCalls("UnplaceItem") == calls + 1, "UnplaceItem envoyé")

summary("scénario a286 liste")
