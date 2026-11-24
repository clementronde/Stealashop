-- Banc a77 (vague 25) : TrainingService ancre et coupe les collisions de toute l'haltère Barbell, puis rend
-- ses réglages et sa place exacte (faux Roblox de la copie a72 du banc a58).
local function barbellBench(owner, origin)
	local plot = newInst("Model", "Plot", workspace)
	plot._tags.PlayerPlot = true
	plot:SetAttribute("OwnerUserId", owner.UserId)
	local bench = newInst("Model", "PLOT_Bench", plot)
	local frame = newInst("Part", "Frame", bench)
	frame.CFrame = CFrame.new(origin)
	local up = newInst("Attachment", "UsePoint", frame)
	up.WorldCFrame = CFrame.new(origin)
	up.WorldPosition = origin
	local barbell = newInst("Model", "Barbell", bench)
	local parts = {}
	for i, spec in { { "Bar", 0 }, { "Plate_L1", -2.5 }, { "Plate_L2", -2.8 }, { "Plate_R1", 2.5 }, { "Plate_R2", 2.8 }, { "Collar_L", -2.2 }, { "Collar_R", 2.2 } } do
		local p = newInst("Part", spec[1], barbell)
		p.CFrame = CFrame.new(origin + Vector3.new(spec[2], 4, 0))
		p.Anchored = (i % 2 == 1)
		p.CanCollide = (i ~= 3)
		parts[spec[1]] = p
	end
	local inner = newInst("WeldConstraint", "Inner", parts.Plate_L1)
	inner.Part0 = parts.Bar
	inner.Part1 = parts.Plate_L1
	local toBench = newInst("WeldConstraint", "ToBench", parts.Bar)
	toBench.Part0 = frame
	toBench.Part1 = parts.Bar
	CollectionService:AddTag(bench, "Bench")
	return bench, up, parts, inner, toBench
end

do
	local p, _ch, hum = newPlayer("Haltere")
	local bench, up, parts, inner, toBench = barbellBench(p, Vector3.new(200, 0, 0))
	local saved = {}
	for name, part in parts do
		saved[name] = { cf = part.CFrame, anchored = part.Anchored, collide = part.CanCollide }
	end
	sit(p, up)
	step(0.5)
	check("S1 BenchUserId posé", bench:GetAttribute("BenchUserId") == p.UserId)
	local allHeld = true
	for _, part in parts do
		if not (part.Anchored == true and part.CanCollide == false) then allHeld = false end
	end
	check("S1 toute l'haltère ancrée et sans collision", allHeld)
	check("S1 liaison haltère → banc coupée", toBench.Enabled == false)
	check("S1 liaison interne (Bar → disque) gardée", inner.Enabled == true)
	-- les clients la déplacent : simulé côté serveur
	for _, part in parts do
		part.CFrame = CFrame.new(0, 50, 0)
	end
	hum.Died:Fire()
	check("S2 mort : descendu, attribut retiré", p:GetAttribute("TrainingMachine") == nil and bench:GetAttribute("BenchUserId") == nil)
	local back = true
	for name, part in parts do
		local s = saved[name]
		if part.CFrame ~= s.cf or part.Anchored ~= s.anchored or part.CanCollide ~= s.collide then
			back = false
			print("  écart : " .. name)
		end
	end
	check("S2 chaque pièce : place exacte, Anchored et CanCollide d'avant", back)
	check("S2 liaison haltère → banc rétablie", toBench.Enabled == true)
end

print("banc a77 (haltère, serveur) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
