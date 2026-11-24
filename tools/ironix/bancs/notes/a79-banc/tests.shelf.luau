--!nocheck
-- a79, scénario « shelf » (L-097 point 3) : sur le rayon, le colis prend le modèle de la rareté de son
-- contenu (tiré à la mise en rayon), BOX_<Rareté>, sinon BOX_<Tier>, sinon le bloc V0 ; jamais teint.
-- Mise en place : celle du banc a17-heist (copie d'a66), lue sur place jusqu'à « démarrage ».
-- Livrés ici : BOX_Uncommon à BOX_Secret (pas BOX_Common : les colis Communs gardent BOX_Premium ou le V0),
-- chacun avec une pièce Mark_<Rareté> et une Tint d'une couleur à lui, et un script à retirer.
do
	local boxesFolder = Assets:FindFirstChild("Boxes")
	local delivered = { Uncommon = true, Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }
	local tintColor = {}
	for index, rarity in { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
		local m = new("Model", "BOX_" .. rarity, boxesFolder)
		local color = Color3.fromRGB(10 * index, 20, 30)
		tintColor[rarity] = color
		local t = new("Part", "Tint", m, { Size = Vector3.new(1.8, 1.2, 1.8), CFrame = CFrame.new(0, 0.6, 0), Color = color })
		t.PivotOffset = CFrame.new(0, -0.6, 0)
		m.PrimaryPart = t
		new("Part", "Mark_" .. rarity, m, { Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 1.3, 0) })
		new("Script", "Junk", m)
	end

	print("== a79 : modèle du colis sur le rayon selon sa rareté")
	clearLog()
	Heist.Init()
	GrabRemote = ReplicatedStorage.Remotes.GrabItem
	taskLib.spawn(Heist.Start)
	check(
		logHas("modèles BOX_Uncommon, BOX_Rare, BOX_Epic, BOX_Legendary, BOX_Mythic, BOX_Secret, BOX_Premium", "PRINT"),
		"S1 Init : modèles par rareté puis par type annoncés dans la sortie"
	)
	local byRarity, byTier, v0, wrong, scripts, painted = 0, 0, 0, {}, 0, 0
	for _, store in { superette, kiosque, electro } do
		for _, box in boxesOf(store):GetChildren() do
			local label = C.labels[box]
			local rarity = label and label.Rarity
			local tier = box:GetAttribute("Tier")
			local mark = nil
			for _, child in box:GetChildren() do
				if string.sub(child.Name, 1, 5) == "Mark_" then
					mark = string.sub(child.Name, 6)
				end
				if child:IsA("Script") then
					scripts += 1
				end
			end
			if delivered[rarity] then
				if mark == rarity then
					byRarity += 1
					local t = box:FindFirstChild("Tint")
					if t == nil or t.Color ~= tintColor[rarity] then
						painted += 1
					end
				else
					table.insert(wrong, `{box.Name} {rarity} : {mark or "sans marque"}`)
				end
			elseif tier == "Premium" then
				if mark == nil and box:FindFirstChild("Lid") ~= nil then
					byTier += 1
				else
					table.insert(wrong, `{box.Name} {rarity} Premium : pas BOX_Premium`)
				end
			else
				if mark == nil and box:FindFirstChild("Body") ~= nil and box:FindFirstChild("Lid") == nil then
					v0 += 1
				else
					table.insert(wrong, `{box.Name} {rarity} {tier} : pas le bloc V0`)
				end
			end
		end
	end
	check(#wrong == 0, `S2 chaque colis : BOX_<Rareté>, sinon BOX_<Tier>, sinon V0 ({table.concat(wrong, " ; ")})`)
	check(byRarity >= 1, `S3 au moins un colis au modèle de sa rareté ({byRarity})`)
	check(byTier >= 1, `S4 repli sur BOX_<Tier> pour une rareté pas livrée (Commun en Premium : {byTier})`)
	check(v0 >= 1, `S5 repli sur le bloc V0 sans BOX_<Rareté> ni BOX_<Tier> ({v0})`)
	check(byRarity + byTier + v0 == 30, `S6 les 30 colis comptés ({byRarity} + {byTier} + {v0})`)
	check(painted == 0, "S7 BOX_<Rareté> pas reteint : la couleur de Clément reste")
	check(scripts == 0, "S8 aucun script dans les colis posés")
	check(#CS:GetTagged("ShelfBox") == 30, "S9 tag ShelfBox sur chaque colis, comme avant")
end
summary()
