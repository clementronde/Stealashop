# a172 (vague 53), banc a105, scénario « arrive » : Features.ShelfOpen est parti (l antivol au sol est le seul déroulé).
s/check\(sharedModule\("Config\/Features"\)\.ShelfOpen == true, "Features\.ShelfOpen = true \(main\)"\)/check(sharedModule("Config\/Features").ShelfOpen == nil, "a172 : Features.ShelfOpen n existe plus")/
