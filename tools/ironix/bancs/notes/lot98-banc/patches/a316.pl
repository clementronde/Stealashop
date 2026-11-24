# lot98-commun (petit chef 2) : faux Model:ScaleTo du banc a316 (pièces sans rotation, autour du pivot) : PivotOffset mis
# à l'échelle comme dans Roblox. Sans cela, depuis a418 (canette de 10 kg ×2), DisplayService fait ScaleTo(2) puis
# PivotTo(place) : le pivot du faux restait 0,8 au-dessus du bas du bloc grandi, le bloc descendait de 0,8 sous la place
# (y 1,95 sous 2,75). Dans Roblox, le pivot (bas au centre) reste en bas : aucun enfoncement (voir RAPPORT.md).
undef $/; $_ = <>;
s/(\t\t\t\td\.Size = d\.Size \* k\r?\n\t\t\t\td\.CFrame = CFrame\.new\(pivot \+ \(p - pivot\) \* k\)\r?\n)/$1\t\t\t\tlocal offset = d.PivotOffset -- lot98-commun : comme Roblox\n\t\t\t\tif offset ~= nil then\n\t\t\t\t\td.PivotOffset = CFrame.new(offset.Position * k)\n\t\t\t\tend\n/;
print;
