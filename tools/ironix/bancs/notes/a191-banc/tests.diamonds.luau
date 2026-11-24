--!nocheck
-- Scénario « diamonds » (a191, L-182 point 10) : leur place dans le profil et le getter serveur, rien d'autre.
advance(1000)
startServer()
section("gabarit")
local fresh = DataService.NewData()
check(fresh.Diamonds == 0, "NewData : Diamonds = 0")
local version = fresh.Version
section("profil sans Diamonds")
local data = newProfile(version)
data.Index = {}
check(data.Diamonds == nil, "profil de test sans le champ")
local ada = join("Ada", data)
advance(1.5)
check(dataOf(ada).Diamonds == 0 and DataService.GetDiamonds(ada) == 0, "complété à 0 au chargement")
check(dataOf(ada).Version == version, `pas de nouvelle version ({dataOf(ada).Version})`)
section("getter")
dataOf(ada).Diamonds = 12
check(DataService.GetDiamonds(ada) == 12, "12")
dataOf(ada).Diamonds = 3.7
check(DataService.GetDiamonds(ada) == 3, "3,7 → 3")
for _, bad in { -5, 0 / 0, math.huge, "x" } do
	dataOf(ada).Diamonds = bad
	check(DataService.GetDiamonds(ada) == 0, `valeur invalide {tostring(bad)} → 0`)
end
dataOf(ada).Diamonds = 7
local userAda = ada.UserId
leave(ada)
check(SAVED[`Player_{userAda}`].Diamonds == 7, "sauvegardé")
check(DataService.GetDiamonds(ada) == 0, "joueur parti : 0")
check(ada:GetAttribute("Diamonds") == nil, "aucun attribut Diamonds (rien d'affiché hors de UI_DiamondShop)")
summary("scénario diamonds")
