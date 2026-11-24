# a183 (vague 56, L-173), banc a85 (écran de l'arbre), après les correctifs d'a176 : l'écran construit par le banc reçoit le
# calque RebirthLocked de Clément (LockedName, LockedLabel) sur chaque tuile, sauf celles de NO_LAYER183 (calque pas encore
# livré) ; shownLayer le compte. Le joueur des scénarios d'avant a Rebirths = 10 (toutes les tuiles à renaissance ouvertes,
# comme avant ; REBIRTH_OFF183 : renaissance coupée) ; les tuiles à renaissance sont dans le banc a183 (a183-banc/run.sh).
s/^\tfor _, layer in \{ "Bought", "Available", "Locked" \} do$/\tfor _, layer in { "Bought", "Available", "Locked", "RebirthLocked" } do if layer == "RebirthLocked" and NO_LAYER183 and NO_LAYER183[name] then continue end/
s/^\t\tif layer == "Locked" then$/\t\tif layer == "Locked" or layer == "RebirthLocked" then/
/^function start85\(attrs\)$/a\
	if not REBIRTH_OFF183 then P1:SetAttribute("Rebirths", 10) end -- a183 : toutes les renaissances faites (attrs peut le changer)
