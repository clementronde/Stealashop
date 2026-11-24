# a309 (22/11, Cantin) : les paliers de 15 et 60 min donnent un colis de zone (Config/Rewards.ZoneBox), ouvert tout de
# suite par la scène de la caisse exclusive quand le joueur est en zone safe (le joueur du banc a53 l'est : pas de
# message pour l'objet montré) ; 60 min : la zone suivante (zone 2 quand tous les objets sont de la zone 1) ; textes.
s/^check\(std and #notifies\(ada, giftText\(std\)\) == 1, .*$/check(std and #notifies(ada, giftText(std)) == 0 and #remotes("RevealStarted", function(e) return e.args[1] == ada and e.args[2] == "ExclusiveCrate" and e.args[4] == std.Id end) == 1, `zone safe : scène d'ouverture de {std and std.Id}, sans Notify (a309)`)/
s/gifts\[1\]\.entry\.Zone == 1 and storedBoxes\(ada\) == boxes0, "un objet de plus \(zone 1\), aucun colis"/gifts[1].entry.Zone == 2 and storedBoxes(ada) == boxes0, "un objet de plus (zone 2 : la zone suivante, a309), aucun colis"/
s/60 min: Item up to Mythic/60 min: Rare box from the next zone/g
