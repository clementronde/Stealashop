--!nocheck
-- Point 2 : Net.OnViolation est branché sur un compteur par joueur (TelemetryService.GetRefusalCount), une ligne en
-- Studio par refus, et la télémétrie RemoteRefused (cumul par remote et raison, envoyé au plus 60 s après, ou au
-- départ). Aucune expulsion. Un rappel déjà posé sur Net.OnViolation reste appelé.
local Net = sharedModule("Net/Net")
local earlier = {}
Net.OnViolation = function(player, remoteName, reason)
	table.insert(earlier, `{player.Name}:{remoteName}:{reason}`)
end
startServer()
local ada = join("Ada", plainProfile("a"))
local bob = join("Bob", plainProfile("b"))
advance(1)
section("arguments refusés")
check(TelemetryService.GetRefusalCount(ada) == 0, "aucun refus à l'arrivée")
fireAs(ada, "BuyItem", 42)
flush()
check(TelemetryService.GetRefusalCount(ada) == 1, `un refus compté (trouvé {TelemetryService.GetRefusalCount(ada)})`)
check(logHas("[TelemetryService] Ada : demande refusée n° 1 de la session (BuyItem, ArgType)", "PRINT", "server"), "Studio : une ligne avec le compteur")
check(table.find(earlier, "Ada:BuyItem:ArgType") ~= nil, "le rappel posé avant TelemetryService est toujours appelé")
advance(0.5)
fireAs(ada, "BuyItem", 43)
fireAs(ada, "Notify", "hack")
flush()
check(TelemetryService.GetRefusalCount(ada) == 3, `trois refus comptés (trouvé {TelemetryService.GetRefusalCount(ada)})`)
check(TelemetryService.GetRefusalCount(bob) == 0, "Bob : aucun refus")
check(#eventsNamed("RemoteRefused") == 0, "rien envoyé tout de suite (cumul)")
section("envoi du cumul")
advance(61)
local list = eventsNamed("RemoteRefused", ada)
check(#list == 2, `deux RemoteRefused (BuyItem ArgType, Notify WrongDirection) (trouvé {#list})`)
local byRemote = {}
for _, e in list do
	byRemote[fieldOf(e, 1)] = e
end
local buy = byRemote["Remote - BuyItem"]
check(buy ~= nil and fieldOf(buy, 2) == "Reason - ArgType" and buy.value == 2, "BuyItem : Reason - ArgType, valeur 2")
local notify = byRemote["Remote - Notify"]
check(notify ~= nil and fieldOf(notify, 2) == "Reason - WrongDirection" and notify.value == 1, "Notify : Reason - WrongDirection, valeur 1")
section("départ")
fireAs(bob, "BuyItem", true)
flush()
check(#eventsNamed("RemoteRefused", bob) == 0, "Bob : cumul pas encore envoyé")
leave(bob)
advance(0.5)
check(#eventsNamed("RemoteRefused", bob) == 1, "Bob : le cumul part à son départ")
check(ada.Parent == Players, "Ada n'est pas expulsée")
check(noRefusal(), "Roblox accepte chaque envoi")
section("fin")
check(not logHas("[TelemetryService]", "WARN"), "aucun avertissement de TelemetryService")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario refusals")
