--!nocheck
-- Scénarios a195 (2026-11-15, vague 60, T-086 : un présentoir à la fois). Ajoutés après le préambule de la copie
-- a195 du banc a179 (arbre, gabarit, deux boutiques, setCount, expectedDepth). FLAG_OFF : passe avec
-- Config/ShopGrowth.HideLockedStands = false (ancien rendu : tout le rang d'un coup).

-- Pièces sans numéro dans les visuels du rayon 3 : une garniture contre le socle 10 (à 1,5 stud de son
-- DisplaySlot) et un décor au milieu de l'allée du rang 5 (à 16 studs des socles) ; une SurfaceGui sur la plaque 6.
do
	local R3 = store:FindFirstChild("Rayon_03")
	local p10 = slotPos(10)
	box("StandTrim", R3, T, p10.X - 0.5, 1.5, p10.Z + 1, p10.X + 0.5, 2, p10.Z + 2)
	box("RowDecor", R3, T, -1, 0.3, p10.Z - 1, 1, 1, p10.Z + 1)
	new("SurfaceGui", "AmountGui", store:FindFirstChild("Rayon_02"):FindFirstChild("CollectPad_06"))
	-- décor du rang 3 nommé avec le numéro d un autre rayon : pas le présentoir 12
	box("Light_12", store:FindFirstChild("Rayon_02"), T, -1, 3, slotPos(5).Z - 1, 1, 3.5, slotPos(5).Z + 1)
end
templateBefore = templateSignature() -- gabarit complété ci-dessus

local function standHidden(plot, n)
	local r = math.ceil(n / 4)
	local stand = find(plot, string.format("Rayon_%02d.RayonVisuals.DisplayStand_%02d", r, n))
	local pad = find(plot, string.format("Rayon_%02d.RayonVisuals.CollectPad_%02d", r, n))
	if stand == nil or pad == nil then
		return nil
	end
	local a, b = isHidden(stand), isHidden(pad)
	if a ~= b then
		return "mixte"
	end
	return a
end
-- Présentoirs 5 à 20 visibles, en liste.
local function visibleList(plot)
	local out = {}
	for n = 5, 20 do
		if standHidden(plot, n) == false then
			table.insert(out, tostring(n))
		end
	end
	return table.concat(out, ",")
end
local function expectedVisible(count, all)
	local out = {}
	local last = if all then 4 * math.min(5, math.ceil(count / 4)) else count
	local limit = expectedDepth(count) or 40
	for n = 5, last do
		if slotPos(n).Z + 2 <= limit then
			table.insert(out, tostring(n))
		end
	end
	return table.concat(out, ",")
end

if not FLAG_OFF then
	------------------------------------------------------------ S1 un présentoir à la fois
	print("\nS1 de 4 à 20 présentoirs, un par un (Alice)")
	setCount(alice, 4)
	PlotService.Assign(alice, plot1)
	advance(0)
	local seen = {}
	for count = 4, 20 do
		setCount(alice, count)
		local got = visibleList(plot1)
		seen[count] = got
		check(got == expectedVisible(count, false), `{count} présentoirs : visibles [{got}], attendus [{expectedVisible(count, false)}]`)
		local hiddenOk = true
		for n = count + 1, 4 * math.min(5, math.ceil(count / 4)) do
			if n > 4 and standHidden(plot1, n) ~= true then
				hiddenOk = false
			end
		end
		check(hiddenOk, `{count} : les présentoirs suivants du rayon montré sont cachés (socle et plaque)`)
	end
	setCount(alice, 5)
	local s6 = find(plot1, "Rayon_02.RayonVisuals.DisplayStand_06")
	local gui6 = find(plot1, "Rayon_02.RayonVisuals.CollectPad_06.AmountGui")
	check(s6 and not s6.CanCollide and not s6.CanTouch and not s6.CanQuery and gui6 and gui6.Enabled == false,
		"5 : socle 6 sans collision ni requête, montant de sa plaque éteint")
	check(standHidden(plot1, 5) == false, "5 : socle 5 visible, seul de son rang")
	check(not isHidden(find(plot1, "Rayon_02.RayonVisuals.Light_12")), "5 : décor Light_12 du rayon 2 montré (12 n est pas un de ses présentoirs)")
	setCount(alice, 6)
	check(s6.Parent ~= nil and not isHidden(s6) and s6.CanCollide and gui6.Enabled == true, "6 : socle 6 rendu tel quel (collision, montant)")
	check(standHidden(plot1, 7) == true and standHidden(plot1, 8) == true, "6 : rang suivant (7, 8) caché")
	setCount(alice, 7)
	check(standHidden(plot1, 7) == false and standHidden(plot1, 8) == true, "7 : 7 visible, 8 caché")
	setCount(alice, 9)
	check(standHidden(plot1, 9) == false and standHidden(plot1, 10) == true, "9 : agrandie, 9 visible, 10 caché")

	------------------------------------------------------------ S2 pièces sans numéro
	print("\nS2 pièces sans numéro dans les visuels")
	local trim = find(plot1, "Rayon_03.RayonVisuals.StandTrim")
	local decor = find(plot1, "Rayon_03.RayonVisuals.RowDecor")
	check(trim and isHidden(trim), "9 : garniture du socle 10 (sans numéro, la plus proche du DisplaySlot_10) cachée")
	check(decor and not isHidden(decor), "9 : décor du rang loin des socles montré avec le rang")
	setCount(alice, 10)
	check(not isHidden(trim) and not isHidden(decor), "10 : garniture rendue avec son socle")

	------------------------------------------------------------ S3 profil chargé au milieu, maximum, redescente
	print("\nS3 profil chargé à 11, maximum, redescente")
	setCount(bob, 11)
	PlotService.Assign(bob, plot2)
	advance(0.1)
	check(visibleList(plot2) == seen[11], `Bob chargé à 11 : même rendu qu'Alice pas à pas [{visibleList(plot2)}]`)
	check(standHidden(plot2, 11) == false and standHidden(plot2, 12) == true, "Bob : 11 visible, 12 caché")
	advance(1.5)
	check(visibleList(plot2) == seen[11], "contrôle d'une seconde : rien ne bouge")
	setCount(alice, 20)
	check(visibleList(plot1) == "5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20", "20 : tous les présentoirs visibles")
	advance(1.5)
	check(visibleList(plot1) == seen[20], "20 : le contrôle d'une seconde ne change rien")
	setCount(alice, 11)
	check(visibleList(plot1) == seen[11] and standHidden(plot1, 12) == true, "redescendu de 20 à 11 : même rendu qu'en montant, 12 caché")
	setCount(alice, 12)
	check(standHidden(plot1, 12) == false, "remonté à 12 : 12 rendu")

	------------------------------------------------------------ S4 parcelle libérée
	print("\nS4 parcelle libérée")
	PlotService.Release(bob)
	advance(0.1)
	check(find(plot2, "Rayon_02.RayonVisuals") == nil and find(plot2, "Rayon_03.RayonVisuals") == nil, "Bob parti : plus aucun visuel de rayon")
	setCount(bob, 6)
	PlotService.Assign(bob, plot2)
	advance(0.1)
	check(visibleList(plot2) == "5,6", `Bob revient à 6 : 5 et 6 visibles [{visibleList(plot2)}]`)
	check(templateSignature() == templateBefore, "gabarit et visuels des rayons intacts")
else
	------------------------------------------------------------ S5 interrupteur coupé
	print("\nS5 HideLockedStands = false : tout le rang d'un coup (ancien rendu)")
	setCount(alice, 4)
	PlotService.Assign(alice, plot1)
	advance(0)
	for _, count in { 5, 7, 9, 11, 13, 20 } do
		setCount(alice, count)
		check(visibleList(plot1) == expectedVisible(count, true), `{count} : visibles [{visibleList(plot1)}], attendus [{expectedVisible(count, true)}]`)
	end
	setCount(alice, 9)
	check(not isHidden(find(plot1, "Rayon_03.RayonVisuals.StandTrim")), "9 : garniture du socle 10 montrée")
end

summary()
