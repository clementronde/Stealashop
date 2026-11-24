# a243 (vague 72) : la fiche Trap (pièges de boutique) s'ajoute à la fin de Models.List, après le stand du receleur.
s/^local lastModel = Models\.List\[#Models\.List\]$/local lastModel = Models.List[#Models.List - (if Models.List[#Models.List] == Models.Trap and Models.Trap ~= nil then 1 else 0)]/
s/then Models\.List\[#Models\.List - 1\] else lastModel/then Models.List[(table.find(Models.List, lastModel) :: number) - 1] else lastModel/
s/check\(Models\.List\[#Models\.List\] == Models\.RobuxShopCounter and /check(Models.List[#Models.List - (if Models.List[#Models.List] == Models.Trap and Models.Trap ~= nil then 1 else 0)] == Models.RobuxShopCounter and /
