---------------------------------------------------------------- R11 (a141)
print("\nR11 (a141, L-141) deux contours RayonSpot_0n par rayon, un de chaque côté de l'allée")
do
	local plot6 = new("Model", "PLOT_Shop_06", Workspace)
	local r1 = new("Model", "Rayon_01", plot6)
	for i = 1, 4 do
		new("Attachment", string.format("DisplaySlot_%02d", i), part("Top", r1))
	end
	local r2 = new("Model", "Rayon_02", plot6)
	local anchor2 = part("RayonAnchor", r2)
	for i = 5, 8 do
		new("Attachment", string.format("DisplaySlot_%02d", i), anchor2)
	end
	local r3 = new("Model", "Rayon_03", plot6)
	local anchor3 = part("RayonAnchor", r3)
	for i = 9, 12 do
		new("Attachment", string.format("DisplaySlot_%02d", i), anchor3)
	end
	local spots = new("Folder", "RayonSpots", plot6)
	-- Rayon 2 : deux pièces du même nom ; rayon 3 : un modèle qui porte deux contours du même nom.
	local left2 = part("RayonSpot_02", spots)
	local right2 = part("RayonSpot_02", spots)
	local group3 = new("Model", "RayonSpot_03", spots)
	local left3 = part("RayonSpot_03", group3)
	local right3 = part("RayonSpot_03", group3)
	right3.Transparency = 0.4 -- valeur d'origine à rendre telle quelle
	addTag(plot6, "PlayerPlot")
	local eve = new("Player", "Eve", Players)
	rawget(eve, "_props").UserId = 106
	FAKE_DATA[eve] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0 } }
	eve:SetAttribute("DisplaySlotsLevel", 0)
	PlotService.Assign(eve, plot6)
	advance(0)
	check(left2.Transparency == 0 and right2.Transparency == 0, "4 présentoirs : les deux contours du rayon 2 visibles")
	buy(eve, 1)
	check(left2.Transparency == 1 and right2.Transparency == 1 and not left2.CanCollide and not right2.CanCollide, "5 présentoirs : les deux contours du rayon 2 cachés")
	check(left3.Transparency == 0 and math.abs(right3.Transparency - 0.4) < 1e-6, "… ceux du rayon 3 toujours visibles")
	buy(eve, 5)
	check(left3.Transparency == 1 and right3.Transparency == 1, "9 présentoirs : les contours du rayon 3 cachés (modèle et enfants du même nom)")
	buy(eve, 0)
	check(left2.Transparency == 0 and right2.Transparency == 0 and left2.CanCollide and right2.CanCollide, "retour à 4 : les deux contours du rayon 2 rendus")
	check(left3.Transparency == 0 and math.abs(right3.Transparency - 0.4) < 1e-6, "… et ceux du rayon 3, valeurs d'origine (0,4 rendu)")
	PlotService.Release(eve)
end

summary()
