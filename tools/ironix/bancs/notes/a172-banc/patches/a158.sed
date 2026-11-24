# a172 (vague 53), banc a158, scénario « base » : UnboxService.OnBoxPlaced, OnBoxOpened et GetOpenDelay, gardées inertes par
# a158 tant que MonetizationService et IndexService les lisaient, sont retirées (plus aucun appelant) : on vérifie leur absence
# (GetOpenDelay n est pas vérifiée ici : le setup de ce banc en pose une à lui sur UnboxService).
/^local off = UnboxService\.OnBoxPlaced\(function\(\)$/,/^check\(type\(UnboxService\.GetOpenDelay\) == "function"/c\
check(UnboxService.OnBoxPlaced == nil and UnboxService.OnBoxOpened == nil, "a172 : OnBoxPlaced et OnBoxOpened retirées (plus aucun appelant)")\
check(type(UnboxService.GetLuck) == "function", "GetLuck encore là (GiveItem)")
s/^check\(called == 0, "écouteurs OnBoxPlaced et OnBoxOpened : jamais appelés"\)$/check(called == 0, "a172 : (plus d écouteurs OnBox*)")/
