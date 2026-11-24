--!nocheck
-- Scénario « halo » du banc a122 (vague 37) : Shared/RarityHalo pose exactement les mêmes instances que l'ancien
-- rendu de CarryService et de DisplayService (ancien-halo.luau, figé de main 2be54ff) : même arbre, mêmes noms,
-- mêmes propriétés et valeurs, pour chaque rareté, porté (8 combinaisons d'effets propres du modèle) et exposé
-- (3 tailles d'objet). VISUAL EFFECTS sur OFF : CosmeticController éteint ce qui est sous HaloPoint et
-- RarityHalo ; le banc vérifie que ces noms ne changent pas.
local Rarities = RARITIES
local New = NEW_HALO

check(New.CarryPoint == "HaloPoint" and New.DisplayPart == "RarityHalo" and New.RaysCenter == "RaysCenter", "noms HaloPoint, RarityHalo, RaysCenter (CosmeticController, DisplayController)")

-- Porté ou au sol
local carried, carriedRays, carriedEmpty = 0, 0, 0
for _, rarity in Rarities.List do
	for mask = 0, 7 do
		local own = { Light = mask % 2 == 1, Particles = (mask // 2) % 2 == 1, Beams = (mask // 4) % 2 == 1 }
		local center = CFrame.new(0.25, 1.1, -0.4)
		local a = Instance.new("Part")
		a.Name = "Anchor"
		OLD.AddCarried(a, center, rarity, own)
		local b = Instance.new("Part")
		b.Name = "Anchor"
		New.AddCarried(b, center, rarity, own)
		local da, db = dumpTree(a), dumpTree(b)
		check(da == db, "porté " .. rarity.Id .. ", effets propres " .. mask .. " : même arbre")
		if da ~= db and VERBOSE then
			print("ancien :\n" .. da .. "\nnouveau :\n" .. db)
		end
		carried += 1
		if #a:GetChildren() == 0 then
			carriedEmpty += 1
		end
		if string.find(db, "Beam HaloRay_8", 1, true) then
			carriedRays += 1
		end
	end
	local a, b = Instance.new("Part"), Instance.new("Part")
	OLD.AddCarried(a, CFrame.new(0, 0.8, 0), rarity, OLD.CarryNoEffects)
	New.AddCarried(b, CFrame.new(0, 0.8, 0), rarity, New.NoEffects)
	check(dumpTree(a) == dumpTree(b), "porté " .. rarity.Id .. ", NoEffects (objet volé, bloc V0) : même arbre")
end
check(carriedRays > 0 and carriedEmpty > 0 and carriedEmpty < carried, "cas portés variés (" .. carried .. " cas, " .. carriedRays .. " avec rayons, " .. carriedEmpty .. " sans halo)")

-- Effets propres d'un modèle BOX_<Rareté>
for mask = 0, 7 do
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Parent = model
	if mask % 2 == 1 then
		Instance.new("PointLight").Parent = body
	end
	if (mask // 2) % 2 == 1 then
		Instance.new(if mask >= 4 then "Sparkles" else "ParticleEmitter").Parent = body
	end
	if (mask // 4) % 2 == 1 then
		Instance.new("Beam").Parent = model
	end
	check(dumpValue(OLD.CarryOwnEffects(model)) == dumpValue(New.OwnEffects(model)), "OwnEffects, modèle " .. mask .. " : même résultat")
end

-- Exposé
local displayed, displayedRays = 0, 0
for _, rarity in Rarities.List do
	for _, size in { Vector3.new(1.2, 1.6, 1.2), Vector3.new(3, 1, 2), Vector3.new(0.8, 2.4, 0.5) } do
		local box = CFrame.new(4, 2.5, -1)
		local a = Instance.new("Model")
		a.Name = "DisplayItem_01"
		OLD.AddDisplayed(a, rarity, box, size)
		local b = Instance.new("Model")
		b.Name = "DisplayItem_01"
		New.AddDisplayed(b, rarity, box, size)
		local da, db = dumpTree(a), dumpTree(b)
		check(da == db, "exposé " .. rarity.Id .. ", taille " .. size.X .. "x" .. size.Y .. "x" .. size.Z .. " : même arbre")
		if da ~= db and VERBOSE then
			print("ancien :\n" .. da .. "\nnouveau :\n" .. db)
		end
		displayed += 1
		if string.find(db, "RaysCenter", 1, true) then
			displayedRays += 1
		end
	end
	check(dumpValue(OLD.Sequence(OLD.Colors(rarity))) == dumpValue(New.Sequence(New.Colors(rarity))), "couleurs " .. rarity.Id .. " (aussi RarityRainbow) : mêmes")
end
check(displayedRays > 0 and displayedRays < displayed, "cas exposés variés (" .. displayed .. " cas, " .. displayedRays .. " avec rayons)")

finish("halo")
