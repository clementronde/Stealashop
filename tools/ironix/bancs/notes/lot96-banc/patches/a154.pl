# lot96 : remotes ajoutés après ItemSecured par a314 (vente depuis UI_Displayed, fusion95) et a410 (ReportFocus, lot97).
undef $/; $_ = <>;
s/(WheelResult = true) \}/$1, DisplayedSellAsk = true, DisplayedSellPrice = true, DisplayedSell = true, DisplayedSold = true, ReportFocus = true }/;
print;
