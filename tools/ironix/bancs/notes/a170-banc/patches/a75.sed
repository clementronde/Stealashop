# a170 : le remote BoxSecured (colis porté mis à l'abri) est retiré en vague 52 ; l'arrivée en zone safe ne part plus
# que par ItemSecured(itemId). E0d et E0e lisent ItemSecured ; E3r (icône de rareté par UiFeelController.Escape, API
# gardée) reste lancé ; E5 vérifie que Net refuse BoxSecured et passe par ItemSecured.
s/if entry\.Name == "BoxSecured" then/if entry.Name == "ItemSecured" then/
s/^local RARITY_ARG = def ~= nil and #def\.Args == 2$/local RARITY_ARG = true -- a170 : Escape(tier, rarity) gardé (API)/
s/"E0d remote BoxSecured\(tier, rarity\?\) du serveur vers le client"/"E0d a170 : ItemSecured(itemId) du serveur vers le client (BoxSecured retiré)"/
s/"E0e ajouté à la fin de Net\/Definitions \(après SaveSettings\)"/"E0e ItemSecured après SaveSettings dans Net\/Definitions"/
s/^NetServer\.Server\.BoxSecured:Fire\(P1, "Premium"\)$/check(not pcall(function() return NetServer.Server.BoxSecured end), "a170 : remote BoxSecured retiré (Net le refuse)") ; NetServer.Server.ItemSecured:Fire(P1, requireModule(ReplicatedStorage.Shared.Config.Items, "server").List[1].Id)/
