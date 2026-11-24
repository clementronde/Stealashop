-- Scénarios du banc a58 (L-091, point 2).

local function reps(p)
	return p:GetAttribute("BenchReps") or 0
end

-- 1. Répétitions automatiques, sans TrainTap (BenchLift absente) : rythme serveur 1,5 s ----------
do
	local p, _ch, _hum, _root, _hand = newPlayer("Auto")
	local _bench, up = newBench(p, "part", Vector3.new(20, 0, 0))
	check("1 invite Lift créée", promptOf(up) ~= nil)
	sit(p, up)
	check("1 sur le banc", p:GetAttribute("TrainingMachine") == "Bench")
	check("1 immobilisé", SPEEDMOD[p] == 0)
	step(1.25)
	check("1 rien avant 1,5 s", reps(p) == 0, reps(p))
	step(0.25)
	check("1 première répétition à 1,5 s", reps(p) == 1, reps(p))
	step(4.5)
	check("1 quatre répétitions en 6 s", reps(p) == 4, reps(p))
	check("1 Force = 4 × GainPerRep × 1", near(STRENGTH[p] or 0, 4), STRENGTH[p])
	promptOf(up).Triggered:Fire(p) -- Stop
	check("1 descendu par l'invite", p:GetAttribute("TrainingMachine") == nil)
	local before = reps(p)
	step(5)
	check("1 plus de répétition hors du banc", reps(p) == before)
	TAP:Fire(p)
	check("1 TrainTap hors machine ignoré", reps(p) == before)
end

-- 2. Rythme du client (marqueur Top) : le serveur se met en retrait -----------------------------
do
	local p = newPlayer("Client")
	BENCH_LEVEL = 2 -- multiplicateur 2
	local _bench, up = newBench(p, "part", Vector3.new(40, 0, 0))
	sit(p, up)
	for _ = 1, 6 do
		step(1)
		TAP:Fire(p) -- un Top par seconde
	end
	check("2 six répétitions pour six Top", reps(p) == 6, reps(p))
	check("2 gain = 6 × 1 × 2 (formule inchangée)", near(STRENGTH[p] or 0, 12), STRENGTH[p])
	step(3.75)
	check("2 pas de répétition serveur avant 4 s de silence", reps(p) == 6, reps(p))
	step(0.25)
	check("2 silence de 4 s : le serveur reprend", reps(p) == 7, reps(p))
	BENCH_LEVEL = 0
	sit(p, up)
end

-- 3. Limite de débit : au plus 3 répétitions par seconde glissante ------------------------------
do
	local p = newPlayer("Spam")
	local _bench, up = newBench(p, nil, Vector3.new(60, 0, 0))
	sit(p, up)
	for _ = 1, 10 do
		TAP:Fire(p)
	end
	check("3 dix TrainTap d'un coup : trois comptés", reps(p) == 3, reps(p))
	step(0.5)
	TAP:Fire(p)
	check("3 encore refusé dans la même seconde", reps(p) == 3, reps(p))
	step(0.5)
	for _ = 1, 10 do
		TAP:Fire(p)
	end
	check("3 seconde suivante : trois de plus", reps(p) == 6, reps(p))
	-- le rythme serveur ne dépasse pas la limite non plus
	step(10)
	check("3 rythme serveur ≤ 3/s", reps(p) <= 6 + 30)
	sit(p, up)
end

-- 4. Barre (pièce) soudée à la main puis rendue à sa place exacte -------------------------------
do
	local p, _ch, hum, _root, hand = newPlayer("Barre")
	local _bench, up, bar = newBench(p, "part", Vector3.new(80, 0, 0))
	local origin = bar.CFrame
	sit(p, up)
	check("4 pas de soudure avant la mise en place", #barWelds(bar) == 0)
	step(0.5)
	local w = barWelds(bar)
	check("4 une soudure main → barre", #w == 1 and w[1].Part0 == hand and w[1].Part1 == bar)
	check("4 barre décrochée", bar.Anchored == false)
	check("4 barre sans collision ni masse", bar.CanCollide == false and bar.Massless == true)
	check("4 taille inchangée", bar.Size == Vector3.new(6, 0.3, 0.3))
	-- la physique ferait suivre la main : on simule le déplacement
	bar.CFrame = CFrame.new(81, 6, 1)
	step(2)
	check("4 une seule soudure (pas de doublon)", #barWelds(bar) == 1)
	hum.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping)
	check("4 saut : descendu", p:GetAttribute("TrainingMachine") == nil)
	check("4 soudure retirée", #barWelds(bar) == 0)
	check("4 barre à sa place exacte", bar.CFrame == origin, tostring(bar.CFrame))
	check("4 barre ancrée, collisions et masse rendues", bar.Anchored == true and bar.CanCollide == true and bar.Massless == false)
	check("4 vitesse rendue", SPEEDMOD[p] == nil)
end

-- 5. Barre en modèle : liaison au banc coupée pendant l'usage, rétablie ensuite ; mort -----------
do
	local p, _ch, hum, _root, hand = newPlayer("Modele")
	local bench, up, _bar, parts = newBench(p, "model", Vector3.new(100, 0, 0))
	local rod, plate = parts[1], parts[2]
	local o1, o2 = rod.CFrame, plate.CFrame
	sit(p, up)
	step(0.5)
	check("5 deux pièces soudées", #barWelds(rod) == 1 and #barWelds(plate) == 1 and barWelds(rod)[1].Part0 == hand)
	check("5 liaison barre → banc coupée", bench._toBench.Enabled == false)
	check("5 liaison interne gardée", bench._inner.Enabled == true)
	rod.CFrame = CFrame.new(0, 0, 0)
	plate.CFrame = CFrame.new(3, 0, 0)
	hum.Died:Fire()
	check("5 mort : descendu", p:GetAttribute("TrainingMachine") == nil)
	check("5 soudures retirées", #barWelds(rod) == 0 and #barWelds(plate) == 0)
	check("5 pièces à leur place", rod.CFrame == o1 and plate.CFrame == o2)
	check("5 réglages d'origine (plaque non ancrée, sans collision)", rod.Anchored == true and plate.Anchored == false and plate.CanCollide == false)
	check("5 liaison barre → banc rétablie", bench._toBench.Enabled == true)
end

-- 6. Banc retiré et départ du joueur pendant l'usage --------------------------------------------
do
	local p = newPlayer("Retire")
	local bench, up, bar = newBench(p, "part", Vector3.new(120, 0, 0))
	local origin = bar.CFrame
	sit(p, up)
	step(0.5)
	bar.CFrame = CFrame.new(0, 9, 0)
	CollectionService:RemoveTag(bench, "Bench")
	check("6 banc retiré : descendu", p:GetAttribute("TrainingMachine") == nil)
	check("6 banc retiré : barre rendue", bar.CFrame == origin and bar.Anchored == true and #barWelds(bar) == 0)

	local q = newPlayer("Depart")
	local _b2, up2, bar2 = newBench(q, "part", Vector3.new(140, 0, 0))
	local origin2 = bar2.CFrame
	sit(q, up2)
	step(0.5)
	bar2.CFrame = CFrame.new(0, 9, 0)
	q.Parent = nil
	Players.PlayerRemoving:Fire(q)
	check("6 départ : barre rendue", bar2.CFrame == origin2 and bar2.Anchored == true and #barWelds(bar2) == 0)
end

-- 7. Sans Bar : une ligne en Studio, le banc marche quand même ------------------------------------
do
	local p = newPlayer("SansBarre")
	local _bench, up = newBench(p, nil, Vector3.new(160, 0, 0))
	check("7 ligne dans la sortie", hasLog("pas de pièce ni de modèle Bar"))
	sit(p, up)
	step(1.7)
	check("7 répétitions sans barre", reps(p) == 1, reps(p))
	check("7 TrainingMachine posé", p:GetAttribute("TrainingMachine") == "Bench")
	sit(p, up)
end

-- 8. Pas propriétaire : refusé, aucune soudure ----------------------------------------------------
do
	local owner = newPlayer("Proprio")
	local intrus = newPlayer("Intrus")
	local _bench, up, bar = newBench(owner, "part", Vector3.new(180, 0, 0))
	sit(intrus, up)
	step(2)
	check("8 intrus refusé", intrus:GetAttribute("TrainingMachine") == nil and reps(intrus) == 0)
	check("8 barre intacte", bar.Anchored == true and #barWelds(bar) == 0)
end

print("banc a58 : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
