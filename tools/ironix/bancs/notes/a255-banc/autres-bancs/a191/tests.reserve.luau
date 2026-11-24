--!nocheck
-- Scénario « reserve » (a206, vague 63, L-202 point 4, L-192 Q2-Q4) : la réserve côté serveur (DisplayService) :
-- migration d'un profil sans champ Reserve, profil déjà migré, nettoyage, plafond Config/Displayed.ReserveMax,
-- remote PlaceFromReserve validé (uid hors réserve, mauvais type), objet exposé autrement, objet parti, retour au jeu.
-- Copie a219 (vague 66, L-210 point 2, 2026-11-16) : ReserveCatchAll : un objet ni exposé ni en main qui manque à la
-- réserve y entre (boucle d'une seconde, chargement) : r3 et c9 y sont désormais ; « uid hors réserve » = pas à lui.
advance(1000)
startServer()
local Displayed = sharedModule("Config/Displayed")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, R3, E3 = pick(1, "Common"), pick(3, "Rare"), pick(3, "Epic")
local function reserveOf(player)
	return table.concat(dataOf(player).Reserve or {}, ",")
end
local function displayed(player)
	local out = {}
	for key, uid in dataOf(player).Display do
		out[uid] = tonumber(key)
	end
	return out
end

section("Config/Displayed")
check(type(Displayed.ReserveMax) == "number" and Displayed.ReserveMax >= 1, `ReserveMax V0 = {Displayed.ReserveMax}`)
check(Displayed.ReserveAttribute == "DisplayReserve", "attribut DisplayReserve")
check(Displayed.ReserveCatchAll == true and Displayed.SwapWhenFull == true, "a219 : ReserveCatchAll et SwapWhenFull V0 = true")

section("profil déjà migré : la réserve est nettoyée, puis complétée (a219)")
local data = newProfile()
addItem(data, "e3", E3, 1, 3, 1)
addItem(data, "r3", R3, nil, 3, 2)
addItem(data, "c1", C1, nil, 1, 3)
data.Reserve = { "c1", "zz-parti", "e3", "c1" } -- un objet parti, un exposé, un doublon
local ada = join("Ada", data, 501)
advance(1.5)
check(reserveOf(ada) == "c1,r3", `nettoyée puis complétée : c1, puis r3 au bout (« {reserveOf(ada)} »)`)
check(ada:GetAttribute("DisplayReserve") == "c1,r3", "attribut à jour")
check(dataOf(ada).Items.r3 ~= nil, "r3 toujours au joueur")

section("PlaceFromReserve : le serveur valide")
fireAs(ada, "PlaceFromReserve", "zz-autre") -- pas à lui
advance(1.2)
check(displayed(ada)["zz-autre"] == nil and reserveOf(ada) == "c1,r3", "uid hors réserve : rien")
fireAs(ada, "PlaceFromReserve", "e3") -- déjà exposé
advance(1.2)
check(displayed(ada).e3 == 1 and reserveOf(ada) == "c1,r3", "uid exposé : rien ne bouge")
fireAs(ada, "PlaceFromReserve", 42)
fireAs(ada, "PlaceFromReserve", nil)
advance(1.2)
check(reserveOf(ada) == "c1,r3" and displayed(ada).c1 == nil, "mauvais type : refusé par Net")
fireAs(ada, "PlaceFromReserve", "c1")
advance(1.2)
check(displayed(ada).c1 ~= nil and reserveOf(ada) == "r3", `c1 exposé, r3 seul en réserve (« {reserveOf(ada)} »)`)
check(#notifies(ada, "placed on a display!") == 1, "Notify")

section("objet de la réserve exposé autrement (PlaceItem) ou parti : il quitte la réserve")
fireAs(ada, "UnplaceItem", "c1")
advance(1.2)
check(displayed(ada).c1 == nil and reserveOf(ada) == "r3,c1", `retiré (pas de mains dans ce harnais) : en réserve (« {reserveOf(ada)} »)`)
local DisplayService = serverModule("DisplayService")
check(DisplayService.AddToReserve(ada, "r3") == false and DisplayService.AddToReserve(ada, "e3") == false, "déjà dedans ou exposé : refusé")
DisplayService.PlaceAuto(ada, "r3")
advance(1.2)
check(displayed(ada).r3 ~= nil and reserveOf(ada) == "c1", `r3 posé autrement : sorti de la réserve (« {reserveOf(ada)} »)`)
dataOf(ada).Items.c1 = nil
advance(1.2)
check(reserveOf(ada) == "" and ada:GetAttribute("DisplayReserve") == "", "c1 parti du profil : sorti de la réserve")

section("retour au jeu : la réserve est gardée, pas re-migrée ; l'objet arrivé hors liste y entre au bout (a219)")
fireAs(ada, "UnplaceItem", "r3")
advance(1.2)
check(reserveOf(ada) == "r3", "r3 en réserve")
addItem(dataOf(ada), "c9", C1, nil, 1, 9) -- arrivé hors présentoir, pas dans la réserve
leave(ada)
advance(1)
local ada2 = join("Ada", nil, 501)
advance(1.5)
check(reserveOf(ada2) == "r3,c9" and ada2:GetAttribute("DisplayReserve") == "r3,c9", `réserve gardée, c9 ajouté au bout (« {reserveOf(ada2)} »)`)

section("migration plafonnée à ReserveMax, les plus rentables d'abord")
local big = newProfile()
for i = 1, Displayed.ReserveMax + 2 do
	addItem(big, string.format("c%02d", i), C1, nil, 1, i)
end
addItem(big, "e9", E3, nil, 3, 99)
local cy = join("Cy", big)
advance(1.5)
local list = dataOf(cy).Reserve
check(#list == Displayed.ReserveMax, `{#list} = ReserveMax`)
check(list[1] == "e9", "l'Épique en tête")
check(countKeys(dataOf(cy).Items) == Displayed.ReserveMax + 3, "rien ne quitte Items")
advance(2.2)
check(#dataOf(cy).Reserve == Displayed.ReserveMax, "a219 : la boucle ne dépasse jamais ReserveMax")

summary("scénario reserve")
