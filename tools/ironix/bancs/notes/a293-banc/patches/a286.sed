# a293 : Features.NewTraps et HeistPartnerBonus allumés (validés par Cantin, 21/11).
s/check\(Features\.NewTraps == false and Features\.HeistPartnerBonus == false, "NewTraps et HeistPartnerBonus coupés"\)/check(Features.NewTraps == true and Features.HeistPartnerBonus == true, "NewTraps et HeistPartnerBonus allumés (a293)")/
# a293 : la colle est gardée au 1er emplacement (Traps.SlotLayoutNew = colle, banane, portique, trappe) : la banane est au 2e.
s/^\tlocal state = sweep\(1\)$/\tlocal state = sweep(2) -- a293 : banane au 2e emplacement/
s/^local state = sweep\(1\)$/local state = sweep(2) -- a293 : banane au 2e emplacement/
