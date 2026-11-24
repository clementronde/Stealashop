# a171, banc a49 (mutations), scénario « heist » : gardé jusqu au tirage des mutations à la mise en rayon (fréquences, une
# par famille, jamais le Pot de nouilles). La suite prenait un colis fermé du rayon (GrabItem, refusé depuis a158) : retirée ;
# la mutation qui passe du colis du rayon à l objet ouvert sur place est vérifiée par les bancs a103 (open) et a109 (draw).
/^print\("== a49 : la mutation de l'étiquette est celle du payload/,/^print\(string\.format\("scénario heist/{/^print\(string\.format/!d}
