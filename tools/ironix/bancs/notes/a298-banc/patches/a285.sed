# a298 (21/11, « HUD et boutons d'achat », validé par Cantin, 21/11) : UiAttrFx ignore désormais Gleam sur un texte
# (ItemName) : un reflet de moins en U1 et U9, et U3 (copie blanche du texte d'ItemName) devient « pas de copie, une
# ligne en Studio, l'attribut reste ». Le reste du banc a285 est inchangé.
s/^check\(state\.Gleams == 2 and /check(state.Gleams == 1 and /
s/^(\t)`2 reflets, /\1`a298 : 1 reflet (ItemName ignoré), /
/^section\("U3 /,/^screen\.Enabled = true$/c\
section("U3 a298 : Gleam = Loop sur un texte (ItemName) ignoré")\
check(itemName:FindFirstChild(AF.Gleam.Name) == nil, "a298 : pas de copie GleamFx sur ItemName")\
check(itemName:GetAttribute("Gleam") == "Loop", "a298 : l'attribut de Clément reste")\
check(logHas("sur un texte", "PRINT", "client"), "a298 : une ligne en Studio")
s/after\.Gleams == 2 and /after.Gleams == 1 and /
