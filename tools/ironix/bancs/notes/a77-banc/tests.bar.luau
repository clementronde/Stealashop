-- Banc a77 (vague 25) : l'haltère Barbell entière suit les mains (client), à la même place relative à Bar.
local Ctl = loadController(SOURCE)
Ctl.Start()

local function newBarbell(origin)
	local bench = newInst("Model", "PLOT_Bench", workspace)
	local frame = newInst("Part", "Frame", bench)
	frame.CFrame = CFrame.new(origin + Vector3.new(0, -2, 0))
	local barbell = newInst("Model", "Barbell", bench)
	local parts = {}
	local function part(name, dx, size, canCollide)
		local p = newInst("Part", name, barbell)
		p.CFrame = CFrame.new(origin + Vector3.new(dx, 0, 0))
		p.Size = size
		p.CanCollide = canCollide
		parts[name] = p
		return p
	end
	part("Bar", 0, Vector3.new(6, 0.3, 0.3), true)
	part("Plate_L1", -2.5, Vector3.new(0.3, 1.5, 1.5), true)
	part("Plate_L2", -2.8, Vector3.new(0.3, 1.2, 1.2), false)
	part("Plate_R1", 2.5, Vector3.new(0.3, 1.5, 1.5), true)
	part("Plate_R2", 2.8, Vector3.new(0.3, 1.2, 1.2), true)
	part("Collar_L", -2.2, Vector3.new(0.2, 0.5, 0.5), true)
	part("Collar_R", 2.2, Vector3.new(0.2, 0.5, 0.5), true)
	CollectionService:AddTag(bench, "Bench")
	return bench, parts, frame
end

do
	local _p, left, right = newPlayer(77, Vector3.new(48, 6, 0), Vector3.new(52, 6, 0))
	local bench, parts, frame = newBarbell(Vector3.new(50, 4, 0))
	local origins, collide = {}, {}
	for name, p in parts do
		origins[name] = p.CFrame
		collide[name] = p.CanCollide
	end
	local frameOrigin = frame.CFrame
	bench:SetAttribute("BenchUserId", 77)
	local before = BULK_MOVES
	HEARTBEAT:Fire(1 / 60)
	check("B1 suit les mains", Ctl.IsFollowing(bench))
	check("B1 un seul BulkMoveTo par image", BULK_MOVES == before + 1, BULK_MOVES - before)
	check("B1 Bar au milieu des mains", nearV(parts.Bar.Position, Vector3.new(50, 6, 0)), parts.Bar.Position)
	check("B1 Plate_L1 à -2,5 de Bar", nearV(parts.Plate_L1.Position, Vector3.new(47.5, 6, 0)), parts.Plate_L1.Position)
	check("B1 Plate_R2 à +2,8 de Bar", nearV(parts.Plate_R2.Position, Vector3.new(52.8, 6, 0)), parts.Plate_R2.Position)
	check("B1 Collar_L à -2,2 de Bar", nearV(parts.Collar_L.Position, Vector3.new(47.8, 6, 0)), parts.Collar_L.Position)
	local allOff = true
	for _, p in parts do
		if p.CanCollide then allOff = false end
	end
	check("B1 collisions coupées sur toute l'haltère", allOff)
	check("B1 le reste du banc ne bouge pas", frame.CFrame == frameOrigin)
	-- mains à la verticale : l'haltère entière tourne autour de Bar
	left.CFrame = CFrame.new(50, 4, 0)
	right.CFrame = CFrame.new(50, 10, 0)
	HEARTBEAT:Fire(1 / 60)
	check("B2 verticale : Bar au milieu", nearV(parts.Bar.Position, Vector3.new(50, 7, 0)), parts.Bar.Position)
	check("B2 verticale : Plate_L1 en bas", nearV(parts.Plate_L1.Position, Vector3.new(50, 4.5, 0)), parts.Plate_L1.Position)
	check("B2 verticale : Collar_R en haut", nearV(parts.Collar_R.Position, Vector3.new(50, 9.2, 0)), parts.Collar_R.Position)
	-- fin de séance : tout exactement à sa place, collisions d'avant
	bench:SetAttribute("BenchUserId", nil)
	HEARTBEAT:Fire(1 / 60)
	local back, same = true, true
	for name, p in parts do
		if p.CFrame ~= origins[name] then back = false end
		if p.CanCollide ~= collide[name] then same = false end
	end
	check("B3 fin : toutes les pièces à leur place exacte", back)
	check("B3 fin : collisions d'avant (Plate_L2 sans collision)", same and parts.Plate_L2.CanCollide == false)
	check("B3 fin : ne suit plus", not Ctl.IsFollowing(bench))
	-- banc retiré pendant l'usage : tout revient aussi
	left.CFrame = CFrame.new(48, 6, 0)
	right.CFrame = CFrame.new(52, 6, 0)
	bench:SetAttribute("BenchUserId", 77)
	HEARTBEAT:Fire(1 / 60)
	CollectionService:RemoveTag(bench, "Bench")
	back = true
	for name, p in parts do
		if p.CFrame ~= origins[name] then back = false end
	end
	check("B4 banc retiré : toutes les pièces à leur place", back)
end

-- Bar dans un modèle qui n'est pas Barbell : Bar seule, comme avant.
do
	newPlayer(78, Vector3.new(68, 6, 0), Vector3.new(72, 6, 0))
	local bench = newInst("Model", "PLOT_Bench", workspace)
	local holder = newInst("Model", "Weights", bench)
	local bar = newInst("Part", "Bar", holder)
	bar.CFrame = CFrame.new(70, 4, 0)
	bar.Size = Vector3.new(6, 0.3, 0.3)
	local plate = newInst("Part", "Plate_L1", holder)
	plate.CFrame = CFrame.new(67.5, 4, 0)
	local plateOrigin = plate.CFrame
	CollectionService:AddTag(bench, "Bench")
	bench:SetAttribute("BenchUserId", 78)
	HEARTBEAT:Fire(1 / 60)
	check("B5 sans Barbell : Bar suit", nearV(bar.Position, Vector3.new(70, 6, 0)), bar.Position)
	check("B5 sans Barbell : le disque reste sur le banc", plate.CFrame == plateOrigin)
	bench:SetAttribute("BenchUserId", nil)
	HEARTBEAT:Fire(1 / 60)
end

print("banc a77 (haltère) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
