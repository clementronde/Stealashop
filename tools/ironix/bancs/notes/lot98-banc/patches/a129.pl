# lot98-commun (petit chef 2) : banc a14 (et a59, a129, qui reprennent ses tests et son faux Roblox) sur le lot 98.
#  1. Faux Model:ScaleTo de pc3-lot98-bancs/a14/scale.luau (a418) : PivotOffset mis à l'échelle comme dans Roblox (le
#     pivot, en bas au centre, reste sur le présentoir). Sans cela, le bas du bloc V0 grandi ×2 passait 0,8 stud sous sa
#     place et le contrôle « pivot en bas » ne passait que grâce à ce trou.
#  2. a418 : la canette (10 kg) est ×2 ; les contrôles du bloc V0 lisent sa taille au lieu de 1,6 en dur : bas du bloc
#     sur DisplaySlot_01, BillboardPoint (billboard V0, toujours au sommet) au sommet du bloc.
#  3. a317 (L-304 point 3) : la copie de BB_Item est accrochée au sommet de l'objet avec StudsOffset (0, 0, 0)
#     (DisplayMotion.BillboardStudsOffset) ; avant : au pied, StudsOffset de Clément (0, 2, 0) gardé.
undef $/; $_ = <>;
s/(\n\t\t\td\.Size = d\.Size \* k\r?\n)(\t\tend\r?\n\tend\r?\n\trawset\(self, "_pc3Scale", scale\))/$1\t\t\tlocal offset = d.PivotOffset -- lot98-commun : comme Roblox\n\t\t\tif offset ~= nil then\n\t\t\t\td.PivotOffset = CFrame.new(offset.Position * (k - 1)) * offset\n\t\t\tend\n$2/;
s/check\(near\(canRoot\.Position\.Y, 2\.5 \+ 0\.8\) and/check(near(canRoot.Position.Y - canRoot.Size.Y \/ 2, 2.5) and/;
s/check\(near\(canBillboard\.Adornee\.WorldPosition\.Y, 2\.5 \+ 1\.6\), "BillboardPoint au sommet de l'objet"\)/check(near(canBillboard.Adornee.WorldPosition.Y, canRoot.Position.Y + canRoot.Size.Y \/ 2), "BillboardPoint au sommet de l'objet (lot98 : bloc ×" .. tostring(canModel:GetScale()) .. ", a418)")/;
s/hotBillboard\.StudsOffset == Vector3\.new\(0, 2, 0\) and hotBillboard:FindFirstChild\("Card"\) ~= nil, "copie de BB_Item \(réglages de Clément gardés\)"\)/hotBillboard.StudsOffset == Vector3.new(0, 0, 0) and hotBillboard:FindFirstChild("Card") ~= nil, "copie de BB_Item (Card gardé ; a317, L-304 : accrochée au sommet, StudsOffset 0)")/;
# 4. a418 : la figurine (Root 1 × 2 × 1, pivot en bas) est mise à l'échelle selon son poids : « posée par son pivot »
#    contrôle le bas du Root sur la place (avant : centre à place + 1, la demi-hauteur du Root à l'échelle 1).
s/check\(near\(hotModel\.PrimaryPart\.Position\.Y, hotSlotPosition\.Y \+ 1\) and/check(near(hotModel.PrimaryPart.Position.Y - hotModel.PrimaryPart.Size.Y \/ 2, hotSlotPosition.Y) and/;
print;
