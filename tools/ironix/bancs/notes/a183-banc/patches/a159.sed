# a183 (vague 56, L-173), banc a159 (portes en coups, verrou, combat égal) : la tuile Curtain (Lock) demande 1 renaissance ; les
# joueurs du banc reçoivent Rebirths = 10 (attribut posé en jeu par RebirthService), le scénario lock achète comme avant.
s/^(local ([A-Za-z0-9_]+) = join\("[A-Za-z0-9_]+", [A-Za-z0-9_]+\))$/\1 \2:SetAttribute("Rebirths", 10) -- a183 : toutes les renaissances faites/
