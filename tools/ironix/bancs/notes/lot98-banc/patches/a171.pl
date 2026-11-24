# lot98-commun (petit chef 2) : banc a171 (couverture après a158) sur le lot 98.
#  a49/stand, a317 (L-304 point 3, validé par Clément) : BB_Item de Clément accroché au sommet de la boîte de l'objet,
#    DisplayMotion.BillboardTopOffset (-0,15) plus bas, au lieu du pied (L-027). Attendu : point à (sommet des pièces
#    visibles - 0,15) au-dessus du présentoir, pour l'objet Huge comme pour l'objet sans taille, et plus haut pour Huge.
#  a38/off et a38/client, a319 (L-303) : DoubleSpeed est le 3e gamepass (6 cartes codées) ; le boost SpeedBoost est
#    retiré de Config/Boosts (onglet Boosts : SleepGuards puis Ouvrir maintenant).
undef $/; $_ = <>;
my $top = 'local function lot98Top(m, at) -- lot98-commun : sommet des pièces visibles (hors halo invisible), depuis le présentoir
	local top = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local y = d.CFrame.Position.Y + d.Size.Y / 2
			top = if top then math.max(top, y) else y
		end
	end
	return (top or at.Y) - at.Y
end
';
s/(\r?\n)(check\(p1 ~= nil and near\(p1\.WorldPosition\.Y - at1\.Y, 1\.6, 1e-3\), `BB_Item de Clément sur un objet Huge : point monté de ce que l'objet a gagné \(1,6 stud ; \{p1 and string\.format\("%\.3f", p1\.WorldPosition\.Y - at1\.Y\)\}\)`\))/$1${top}check(p1 ~= nil and n1 ~= nil and near(p1.WorldPosition.Y - at1.Y, lot98Top(n1, at1) - 0.15, 1e-3), `BB_Item de Clément sur un objet Huge : point au sommet de l'objet - 0,15 (a317, L-304 ; {p1 and string.format("%.3f", p1.WorldPosition.Y - at1.Y)})`)/;
s/check\(p2 ~= nil and near\(p2\.WorldPosition\.Y - at2\.Y, 0, 1e-3\), "sans taille : point au pied de l'objet, comme avant \(L-027\)"\)/check(p2 ~= nil and n2 ~= nil and near(p2.WorldPosition.Y - at2.Y, lot98Top(n2, at2) - 0.15, 1e-3) and p1 ~= nil and p1.WorldPosition.Y - at1.Y > p2.WorldPosition.Y - at2.Y + 0.5, "sans taille : point au sommet de l'objet - 0,15, plus bas que l'objet Huge (a317, L-304)")/;
s/#cardsOf\(gui\) == 5, "vitrine : le bouton du HUD ouvre l'écran \(5 gamepasses\)"\)/#cardsOf(gui) == 6, "vitrine : le bouton du HUD ouvre l'écran (6 gamepasses, DoubleSpeed d'a319)")/;
s/keys\(\) == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands", `gamepasses codés, dans l'ordre/keys() == "DoubleCash,DoubleTraining,DoubleSpeed,AutoCollect,FastOpen,ExtraStands", `gamepasses codés, dans l'ordre (a319 : DoubleSpeed en 3e)/;
s/keys\(\) == "SpeedBoost,SleepGuards,OpenNow", `\(fusion57, a208\) boosts du HUD puis Ouvrir maintenant/keys() == "SleepGuards,OpenNow", `(fusion57, a208 ; a319 : SpeedBoost retiré) boosts du HUD puis Ouvrir maintenant/;
print;
