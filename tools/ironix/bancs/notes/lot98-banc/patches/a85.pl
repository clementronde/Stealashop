# lot98-commun (petit chef 2) : a419 (manette, Features.Gamepad) : SkillTreeController écoute SelectionGained des tuiles
# (sélection à la manette) et InputBegan des boutons, et SkillTree/Nav pose Selectable = false sur sa couche ; le faux
# Roblox de ces bancs (copie a60/a62 + a85) n'avait ni SelectionGained (« membre inconnu ») ni la propriété Selectable.
# Signaux ajoutés à la liste EVENTS (jamais tirés ici : souris et doigt comme avant), Selectable aux objets d'UI.
undef $/; $_ = <>;
s/(\nlocal EVENTS = \{\r?\n(?:[^\n]*\n)*?\}\r?\n)/$1EVENTS.SelectionGained = true -- lot98-commun : a419\nEVENTS.SelectionLost = true\nEVENTS.InputBegan = true\nEVENTS.InputEnded = true\nEVENTS.InputChanged = true\nfor _, guiClass in { "Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "TextBox", "CanvasGroup" } do\n\tif PROPS[guiClass] ~= nil and PROPS[guiClass].Selectable == nil then\n\t\tPROPS[guiClass].Selectable = string.find(guiClass, "Button", 1, true) ~= nil\n\tend\nend\n/;
# a411 : Tile_FittingRoom est au contrat seule et facultative (TileOptional, « pas encore livrée ») :
#  - K1c : ses calques ne sont pas au contrat, voulu (seule la tuile est attendue ; vérifiée par le banc a312) ;
#  - K2a : l'écran relevé reçoit la tuile (écran complet, comme livré) ; sans elle le ContractChecker écrit la ligne jaune
#    « absent (facultatif) », pas une ligne rouge ;
#  - H7a : SkillTreeController écrit dans Studio « [SkillTree] UI_SkillTree.Tree.Tile_FittingRoom introuvable » tant
#    qu'elle n'est pas livrée (print de Studio) : cette ligne-là est admise, toute autre « [SkillTree] » reste un échec.
s/(\tfor _, part in )\{ "", "\.Bought", "\.Available", "\.Locked", "\.Info\.Level", "\.Info\.TileName", "\.Info\.PriceRow\.Price", "\.Info\.PriceRow\.PriceNeed" \} do/$1(if skill.TileOptional then { "" } else { "", ".Bought", ".Available", ".Locked", ".Info.Level", ".Info.TileName", ".Info.PriceRow.Price", ".Info.PriceRow.PriceNeed" }) do -- lot98-commun : a411/;
s/(\nlocal gui = buildSkillTree\(StarterGui\)\r?\n)(local hudGui = buildHud85\(StarterGui\)\r?\n)/$1do -- lot98-commun : a411, tuile facultative livrée\n\tlocal tree98 = gui:FindFirstChild("Tree", true)\n\tif tree98 and tree98:FindFirstChild("Tile_FittingRoom") == nil then\n\t\tmake("TextButton", { Name = "Tile_FittingRoom" }, tree98)\n\tend\nend\n$2/;
s/check\(not logHas\("\[SkillTree\]"\) ?, "H7a aucune ligne « \[SkillTree\] » \(tous les éléments trouvés\)"\)/local lot98Other = nil\nfor _, line in LOG do\n\tif string.find(line.text, "[SkillTree]", 1, true) and not string.find(line.text, "Tree.Tile_FittingRoom introuvable", 1, true) then\n\t\tlot98Other = line.text\n\tend\nend\ncheck(lot98Other == nil, `H7a aucune ligne « [SkillTree] » (tous les éléments trouvés ; lot98 : sauf Tile_FittingRoom, facultative, a411) {lot98Other or ""}`)/;
print;
