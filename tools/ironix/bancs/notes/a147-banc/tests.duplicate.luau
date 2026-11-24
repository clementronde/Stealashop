--!nocheck
-- Point 3 : un même uid d'objet chez deux joueurs du serveur (plantage entre les deux sauvegardes de
-- PvPService.deposit) : avertissement et DuplicateItem au chargement du second profil. Rien n'est changé.
startServer()
local ada = join("Ada", plainProfile("x", 2))
local cy = join("Cy", plainProfile("c", 2))
advance(0.5)
section("profils sans doublon")
check(#eventsNamed("DuplicateItem") == 0, "aucun DuplicateItem")
check(not logHas("objet en double", "WARN"), "aucun avertissement")
section("doublon")
local bobData = plainProfile("b", 1)
addItem(bobData, "x-2", "Z3_Ecouteurs", nil)
bobData.Items["x-2"].Zone = 3
local bob = join("Bob", bobData)
advance(0.5)
local list = eventsNamed("DuplicateItem")
check(#list == 1, `un DuplicateItem (trouvé {#list})`)
local e = list[1]
check(e ~= nil and e.player == bob and fieldOf(e, 1) == "Rarity - Common" and fieldOf(e, 2) == "Zone - 3", "joueur Bob, Rarity - Common, Zone - 3")
check(logHas("objet en double : uid x-2 (Z3_Ecouteurs) chez Bob et chez Ada (rien n'est changé)", "WARN", "server"), "avertissement dans la sortie")
check(DataService.Get(ada).Items["x-2"] ~= nil and DataService.Get(bob).Items["x-2"] ~= nil, "rien n'est retiré")
check(bob.Parent == Players and ada.Parent == Players and cy.Parent == Players, "personne n'est expulsé")
check(noRefusal(), "Roblox accepte l'envoi")
section("fin")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario duplicate")
