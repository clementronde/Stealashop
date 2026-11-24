-- Banc a72 (vague 24) : BenchBarController place la barre au milieu des mains, dans leur axe, et la
-- rend à sa place exacte.
local Ctl = loadController(SOURCE)

local function newBench(origin, kind)
	local bench = newInst("Model", "PLOT_Bench", workspace)
	local parts
	if kind == "model" then
		local bar = newInst("Model", "Bar", bench)
		local rod = newInst("Part", "Rod", bar)
		rod.CFrame = CFrame.new(origin)
		rod.Size = Vector3.new(6, 0.3, 0.3)
		local p1 = newInst("Part", "PlateL", bar)
		p1.CFrame = CFrame.new(origin + Vector3.new(-3, 0, 0))
		p1.Size = Vector3.new(0.3, 1, 1)
		local p2 = newInst("Part", "PlateR", bar)
		p2.CFrame = CFrame.new(origin + Vector3.new(3, 0, 0))
		p2.Size = Vector3.new(0.3, 1, 1)
		p2.CanCollide = false
		parts = { rod, p1, p2 }
	else
		local bar = newInst("Part", "Bar", bench)
		bar.CFrame = CFrame.new(origin)
		bar.Size = Vector3.new(6, 0.3, 0.3)
		parts = { bar }
	end
	CollectionService:AddTag(bench, "Bench")
	return bench, parts
end

Ctl.Start()

-- 1. Barre (pièce) au milieu des mains, grand axe dans l'axe main gauche → main droite ------------
do
	local _p, left, right = newPlayer(1, Vector3.new(-2, 5, 1), Vector3.new(2, 5, 1))
	local bench, parts = newBench(Vector3.new(0, 4, 0))
	local bar = parts[1]
	local origin = bar.CFrame
	HEARTBEAT:Fire(1 / 60)
	check("1 sans attribut : barre immobile", bar.CFrame == origin and not Ctl.IsFollowing(bench))
	bench:SetAttribute("BenchUserId", 1)
	HEARTBEAT:Fire(1 / 60)
	check("1 suit les mains", Ctl.IsFollowing(bench))
	check("1 au milieu des mains", nearV(bar.Position, Vector3.new(0, 5, 1)), bar.Position)
	check("1 dans l'axe des mains", nearV(bar.CFrame.RightVector, Vector3.new(1, 0, 0)))
	check("1 collisions coupées chez le client", bar.CanCollide == false)
	-- l'animation lève les mains de travers
	left.CFrame = CFrame.new(-1, 6, 0)
	right.CFrame = CFrame.new(1, 7, 0)
	HEARTBEAT:Fire(1 / 60)
	check("1 suit à chaque image : milieu", nearV(bar.Position, Vector3.new(0, 6.5, 0)), bar.Position)
	check("1 suit à chaque image : axe", nearV(bar.CFrame.RightVector, Vector3.new(2, 1, 0).Unit), bar.CFrame.RightVector)
	-- fin de séance : place exacte et collisions rendues
	bench:SetAttribute("BenchUserId", nil)
	HEARTBEAT:Fire(1 / 60)
	check("1 fin : barre à sa place exacte", bar.CFrame == origin, bar.CFrame)
	check("1 fin : collisions rendues", bar.CanCollide == true and not Ctl.IsFollowing(bench))
	left.CFrame = CFrame.new(-5, 0, 0)
	HEARTBEAT:Fire(1 / 60)
	check("1 après la fin : la barre ne bouge plus", bar.CFrame == origin)
end

-- 2. Barre en modèle : toutes les pièces suivent, mains à la verticale ---------------------------
do
	local _p, left, right = newPlayer(2, Vector3.new(8, 5, 0), Vector3.new(12, 5, 0))
	local bench, parts = newBench(Vector3.new(10, 4, 0), "model")
	local o1, o2, o3 = parts[1].CFrame, parts[2].CFrame, parts[3].CFrame
	bench:SetAttribute("BenchUserId", 2)
	HEARTBEAT:Fire(1 / 60)
	check("2 tige au milieu", nearV(parts[1].Position, Vector3.new(10, 5, 0)), parts[1].Position)
	check("2 disques à 3 studs de part et d'autre", nearV(parts[2].Position, Vector3.new(7, 5, 0)) and nearV(parts[3].Position, Vector3.new(13, 5, 0)))
	left.CFrame = CFrame.new(10, 4, 0)
	right.CFrame = CFrame.new(10, 8, 0)
	HEARTBEAT:Fire(1 / 60)
	check("2 verticale : tige au milieu", nearV(parts[1].Position, Vector3.new(10, 6, 0)), parts[1].Position)
	check("2 verticale : disque gauche en bas, droit en haut", nearV(parts[2].Position, Vector3.new(10, 3, 0)) and nearV(parts[3].Position, Vector3.new(10, 9, 0)), tostring(parts[2].Position) .. " " .. tostring(parts[3].Position))
	-- banc retiré pendant l'usage
	CollectionService:RemoveTag(bench, "Bench")
	check("2 banc retiré : pièces à leur place", parts[1].CFrame == o1 and parts[2].CFrame == o2 and parts[3].CFrame == o3)
	check("2 banc retiré : collisions d'avant", parts[1].CanCollide == true and parts[3].CanCollide == false)
end

-- 3. Mains absentes : attend sur le banc, puis suit ; mains inversées (barre tournée) ------------
do
	local _p, _l, _r, character = newPlayer(3, nil, nil)
	local bench, parts = newBench(Vector3.new(30, 4, 0))
	local bar = parts[1]
	local origin = bar.CFrame
	bench:SetAttribute("BenchUserId", 3)
	HEARTBEAT:Fire(1 / 60)
	check("3 sans mains : barre sur le banc", bar.CFrame == origin and not Ctl.IsFollowing(bench))
	local l = newInst("Part", "LeftHand", character)
	l.CFrame = CFrame.new(32, 5, 0) -- main gauche à +X : la barre doit se retourner sans erreur
	local r = newInst("Part", "RightHand", character)
	r.CFrame = CFrame.new(28, 5, 0)
	HEARTBEAT:Fire(1 / 60)
	check("3 mains arrivées : suit", Ctl.IsFollowing(bench) and nearV(bar.Position, Vector3.new(30, 5, 0)))
	r.CFrame = CFrame.new(28, 5, 2)
	HEARTBEAT:Fire(1 / 60)
	check("3 axe gauche → droite suivi", math.abs(bar.CFrame.RightVector:Dot(Vector3.new(-4, 0, 2).Unit)) > 0.999, bar.CFrame.RightVector)
	-- un autre joueur prend le banc (attribut changé) : remise en place puis suivi du nouveau
	local _q = newPlayer(4, Vector3.new(29, 9, 0), Vector3.new(31, 9, 0))
	bench:SetAttribute("BenchUserId", 4)
	HEARTBEAT:Fire(1 / 60)
	check("3 autre joueur : suit ses mains", nearV(bar.Position, Vector3.new(30, 9, 0)), bar.Position)
	bench:SetAttribute("BenchUserId", nil)
	HEARTBEAT:Fire(1 / 60)
	check("3 fin : place exacte", bar.CFrame == origin)
end

print("banc a72 (barre du banc) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
