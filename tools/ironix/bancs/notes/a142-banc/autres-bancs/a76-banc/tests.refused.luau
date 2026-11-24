--!nocheck
-- Scénario « refused » (vague 25) : SetHotbar validé côté serveur. Refusé, rien ne change : uid d'un autre
-- joueur, 7 cases (Net), identifiant en double, identifiant trop long (Net), mauvais type (Net). Accepté :
-- 3 cases (les autres vides), objet exposé ou colis posé (encore au joueur). Débit limité (4 par seconde).

advance(1000)
startServer()
local adaData = newProfile()
addItem(adaData, "mine", "Z3_Smartphone", nil, 3, 1)
addItem(adaData, "onShelf", "Z1_Donut", 1, 1, 2)
local bobData = newProfile()
addItem(bobData, "bobItem", "Z1_Banane", nil, 1, 1)
local ada = join("Ada", adaData)
local bob = join("Bob", bobData)
advance(1.5)

local function saved(player)
	local list = dataOf(player).Hotbar
	return list and layoutText(list) or "nil"
end

section("accepté")
fireAs(ada, "SetHotbar", "mine", "Tool", "")
flush()
check(saved(ada) == "mine,Tool,,,,", `3 cases, le reste vide : {saved(ada)}`)
check(ada:GetAttribute("HotbarLayout") == "mine,Tool,,,,", "attribut remis")
advance(1.1)

section("refusé : rien ne change")
fireAs(ada, "SetHotbar", "Tool", "bobItem")
flush()
check(saved(ada) == "mine,Tool,,,,", `uid d'un objet de Bob : refusé ({saved(ada)})`)
check(saved(bob) == "nil", "rien chez Bob")
advance(0.3)
fireAs(ada, "SetHotbar", "Tool", "Bat", "mine", "", "", "", "")
flush()
check(saved(ada) == "mine,Tool,,,,", "7 cases : refusé (Net)")
advance(0.3)
fireAs(ada, "SetHotbar", "mine", "mine")
flush()
check(saved(ada) == "mine,Tool,,,,", "identifiant en double : refusé")
advance(0.3)
fireAs(ada, "SetHotbar", string.rep("a", 65))
flush()
check(saved(ada) == "mine,Tool,,,,", "identifiant de 65 caractères : refusé (Net)")
advance(0.3)
fireAs(ada, "SetHotbar", 12, "Tool")
flush()
check(saved(ada) == "mine,Tool,,,,", "nombre au lieu d'un texte : refusé (Net)")
advance(0.3)
fireAs(ada, "SetHotbar", "Tool,Bat")
flush()
check(saved(ada) == "mine,Tool,,,,", "virgule dans un identifiant : refusé")
check(ada:GetAttribute("HotbarLayout") == "mine,Tool,,,,", "attribut inchangé")
advance(1.1)

section("objet exposé : encore au joueur, accepté")
fireAs(ada, "SetHotbar", "onShelf", "", "", "", "", "Bat")
flush()
check(saved(ada) == "onShelf,,,,,Bat", `objet exposé accepté : {saved(ada)}`)
advance(1.1)

section("débit : 4 par seconde")
for i = 1, 6 do
	fireAs(ada, "SetHotbar", if i % 2 == 0 then "Tool" else "Bat", tostring(i) == "1" and "mine" or "")
end
flush()
local list = dataOf(ada).Hotbar
check(list[1] == "Tool" and saved(ada) == "Tool,,,,,", `les 2 derniers appels ignorés : {saved(ada)}`)

summary("scénario refused")
