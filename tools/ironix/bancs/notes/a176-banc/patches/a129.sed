# a176 (vague 54), banc a129 (pvp) : plus de coffre-fort, SafeSlots n'est plus lu par PvPController.
s/^check\(not prompt1\.Enabled, "présentoir 1 mis à l'abri : invite éteinte au tour suivant"\)$/check(prompt1.Enabled, "(a176) SafeSlots posé à la main : ignoré, invite toujours allumée")/
s/^check\(before and tags == 2, `deux étiquettes « SAFE » \(présentoirs 1 et 3 ; trouvé \{tags\}\)`\)$/check(not before and tags == 0, `(a176) aucune étiquette « SAFE » (trouvé {tags})`)/
