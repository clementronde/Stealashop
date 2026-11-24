# a158, banc a30 (batte) : ce qui tombe au coup de batte est un objet sorti d un colis (NPCItem) : attribut ItemId au lieu
# de Tier, étiquette BB_Carry au lieu de BB_Box, invite « Grab » au nom de l objet. Scénarios « drop », « guard » et « trials »
# retirés : ils prenaient un colis fermé sur le rayon (ancien déroulé) pour le faire tomber.
s/check\(model:GetAttribute\("Tier"\) == "Standard" and model:GetAttribute\("BatDrop"\) == true and model\.Parent == dropsFolder\(\), "S9e attributs Tier et BatDrop, dans Workspace\/CarryDrops"\)/check(model:GetAttribute("Tier") == nil and model:GetAttribute("ItemId") == "Z1_Donut" and model:GetAttribute("BatDrop") == true and model.Parent == dropsFolder(), "S9e a158 : attributs ItemId et BatDrop (plus de Tier), dans Workspace\/CarryDrops")/
s/local label = model:FindFirstChild\("BB_Box", true\)/local label = model:FindFirstChild("BB_Carry", true) -- a158 : objet au sol, étiquette BB_Carry/
s/prompt\.ObjectText == "Premium Box", `K7b/prompt.ObjectText == "Donut", `K7b a158 (nom de l objet)/
