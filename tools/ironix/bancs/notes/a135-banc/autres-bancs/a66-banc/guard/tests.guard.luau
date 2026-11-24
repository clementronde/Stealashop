--!nocheck
-- Banc a66, partie guard (2026-11-11, décisions de Cantin) : le vrai GuardService sur le faux Roblox et la
-- mise en place du banc a12 (copie d'a66 : magasins, zone safe en X < 0, joueurs, simulation).
--   G1 poursuite sans fin : au-delà de 20 s et de 120 studs, fin en zone safe ; OnGuardGone au retour
--   G2 trajet le plus court, sans anticipation : la cible zigzague, le vigile ne copie pas chaque zigzag
--   G3 vigile de nuit : plus d'abandon au bout de 20 s ; toujours lâché hors du couloir
--   G4 code et Config : plus d'anticipation ni de champs d'abandon

local function main()
	local SRC_GUARD = SOURCES["server/Services/GuardService.luau"] or ""
	if string.find(SRC_GUARD, "OnGuardGone", 1, true) == nil then
		print("\na66 SAUTÉ : cet arbre n'a pas encore la poursuite sans fin ni la fermeture pour le voleur")
		summary()
		return
	end
	local Zones = requireModule(ConfigF:FindFirstChild("Zones"), "server")
	local Night = requireModule(ConfigF:FindFirstChild("Night"), "server")
	local superette = STORES.STORE_Z1_Superette
	local gone = {}
	GuardService.OnGuardGone(function(thief, store)
		table.insert(gone, { thief = thief, store = store, t = now() })
	end)
	local function flat(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	---------------------------------------------------------------- G1
	print("\nG1 : poursuite sans fin, fin en zone safe")
	clearLog()
	local hugo = addPlayer("Hugo", superette.inside)
	CarryService.StartCarry(hugo, payload("STORE_Z1_Superette", 1))
	runFor(DT)
	local g1 = guardOf(hugo)
	check(g1 ~= nil, "G1a vigile lancé sur Hugo")
	motion[hugo] = runTo(Vector3.new(3000, 3, 0), Zones[1].GuardSpeed) -- même vitesse : l'écart ne bouge plus
	runFor(25)
	check(GuardService.IsChased(hugo) and guardOf(hugo) == g1 and not logHas("abandonne Hugo", "PRINT"), "G1b toujours poursuivi après 25 s (plus d'abandon à 20 s)")
	motion[hugo] = runTo(Vector3.new(3000, 3, 0), 60)
	runFor(4)
	local gap = flat(g1.HumanoidRootPart.Position, rootOf(hugo).Position)
	check(GuardService.IsChased(hugo) and gap > 150, `G1c toujours poursuivi à {math.floor(gap)} studs d'avance (plus d'abandon à 120)`)
	motion[hugo] = nil
	rootOf(hugo).CFrame = CFrame.new(-30, 3, 0) -- il atteint la zone safe
	runFor(0.3)
	check(logHas("abandonne Hugo (zone safe)", "PRINT") and not GuardService.IsChased(hugo), "G1d fin de la poursuite en zone safe")
	local cs = lastRemote("ChaseState", hugo)
	check(cs and cs.args[1] == false, "G1e ChaseState(false) à la zone safe")
	check(CarryService.IsCarrying(hugo), "G1f il garde son colis")
	check(#gone == 0, "G1g OnGuardGone : rien tant que le vigile rentre")
	check(runUntilEmpty(40), "G1h le vigile rentre et s'efface")
	check(#gone == 1 and gone[1].thief == hugo and gone[1].store == superette.model, "G1i OnGuardGone(Hugo, magasin) au départ de son vigile")
	CarryService.Consume(hugo)

	---------------------------------------------------------------- G2
	print("\nG2 : trajet le plus court, sans anticipation, sans copier les zigzags")
	clearLog()
	local ivy = addPlayer("Ivy", superette.inside)
	CarryService.StartCarry(ivy, payload("STORE_Z1_Superette", 1))
	runFor(DT)
	local g2 = guardOf(ivy)
	local hum2 = g2:FindFirstChildOfClass("Humanoid")
	-- Zigzag : 16 studs/s vers +X, et ±16 studs/s sur le côté, changé toutes les 0,15 s.
	local side, flipAt = 1, 0
	motion[ivy] = function(pos, dt)
		if now() >= flipAt then
			side = -side
			flipAt = now() + 0.15
		end
		return pos + Vector3.new(16, 0, 16 * side) * dt
	end
	runFor(0.6) -- délai de réaction
	local last = rawget(hum2, "_moveTarget")
	local changes, ahead, playerFlips, guardFlips = 0, 0, 0, 0
	local lastPlayerSide, lastGuardDz = side, 0
	local worst = 0
	local T = 3
	runFor(T, function()
		local target = rawget(hum2, "_moveTarget")
		if target and (last == nil or flat(target, last) > 1e-6) then
			changes += 1
			local d = flat(target, rootOf(ivy).Position)
			worst = math.max(worst, d)
			if d > 0.01 then
				ahead += 1
			end
			if last then
				local dz = target.Z - last.Z
				if dz * lastGuardDz < 0 then
					guardFlips += 1
				end
				if math.abs(dz) > 1e-3 then
					lastGuardDz = dz
				end
			end
			last = target
		end
		if side ~= lastPlayerSide then
			playerFlips += 1
			lastPlayerSide = side
		end
	end)
	motion[ivy] = nil
	print(string.format("    %d reprises du point visé en %d s, %d zigzags du joueur, %d du point visé, écart max au joueur %.3f", changes, T, playerFlips, guardFlips, worst))
	if string.find(SRC_GUARD, "interceptPoint", 1, true) ~= nil then
		-- Copie d'a69 (2026-11-11, interception) : point recalculé toutes les 0,1 s ; ce faux joueur
		-- n'envoie pas de vitesse (AssemblyLinearVelocity nulle) : le point visé reste le joueur.
		check(changes >= 2 and changes <= T / 0.1 + 1, `G2a a69 : le point visé n'est repris qu'au plus toutes les 0,1 s ({changes} en {T} s)`)
		check(ahead == 0, `G2b a69 : sans vitesse envoyée, il vise où est le joueur (écart max {string.format("%.3f", worst)})`)
	else
		check(changes >= 2 and changes <= T / 0.25 + 1, `G2a le point visé n'est repris qu'au plus toutes les 0,25 s ({changes} en {T} s ; avant : toutes les 0,05 s)`)
		check(ahead == 0, `G2b il vise où est le joueur, jamais devant lui (pas d'anticipation ; écart max {string.format("%.3f", worst)})`)
	end
	check(guardFlips < playerFlips, `G2c il ne recopie pas chaque zigzag ({guardFlips} changements de côté contre {playerFlips} pour le joueur)`)
	check(GuardService.IsChased(ivy), "G2d toujours en poursuite")
	CarryService.Consume(ivy)
	check(runUntilEmpty(40), "G2e puis rentre")

	---------------------------------------------------------------- G3
	print("\nG3 : vigile de nuit, plus d'abandon au bout de 20 s")
	clearLog()
	-- Lampe torche du rig de remplacement de nuit : SpotLight, absente du faux Roblox d'a12.
	PROPS.SpotLight = PROPS.SpotLight or { Face = Enum.NormalId.Front, Range = 0, Angle = 0, Brightness = 0, Color = Color3.new(1, 1, 1), Shadows = false }
	local outside = {}
	for k, x in { 1000, 1060 } do
		local p = new("Part", `NightPatrol_Z1_{k}`, Workspace)
		p.Size = Vector3.new(3, 0.2, 3)
		p.CFrame = CFrame.new(x, 0.2, 200)
		p.Anchored = true
		p:SetAttribute("Zone", 1)
		addTag(p, "NightPatrol")
	end
	local jude = addPlayer("Jude", Vector3.new(1015, 3, 200))
	local count = GuardService.StartNightPatrol({
		InCorridor = function(position)
			for player in outside do
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - position).Magnitude < 1e-3 then
					return false
				end
			end
			return true
		end,
		Ignores = function(_player)
			return false
		end,
		SendHome = function(_player)
			return true
		end,
	})
	-- Copie d'a94 (2026-11-12, L-108 point 2) : avec Night.ChaseSpeed (80), Jude part tout de suite à la
	-- vitesse du vigile (sinon attrapé avant 25 s) ; sans le champ, comme avant (vitesse conseillée + 4).
	local judeSpeed = Zones[1].AdvisedSpeed + Night.ChaseSpeedBonus
	if type(Night.ChaseSpeed) == "number" then
		judeSpeed = math.max(Night.ChaseSpeed, judeSpeed)
		motion[jude] = runTo(Vector3.new(4000, 3, 200), judeSpeed)
	end
	runFor(1)
	if not GuardService.IsNightChased(jude) then
		for _, line in FULL_LOG do
			if string.find(line.text, "nuit", 1, true) or string.find(line.text, "Night", 1, true) then
				print("    LOG " .. line.kind .. " " .. line.text)
			end
		end
	end
	check(count >= 1 and GuardService.IsNightChased(jude), "G3a Jude repéré par un vigile de nuit")
	motion[jude] = runTo(Vector3.new(4000, 3, 200), judeSpeed)
	runFor(25)
	check(GuardService.IsNightChased(jude) and not logHas("abandonne Jude", "PRINT"), "G3b toujours poursuivi après 25 s (plus de Night.GiveUpChaseDuration)")
	outside[jude] = true
	runFor(0.3)
	check(not GuardService.IsNightChased(jude) and logHas("abandonne Jude (sorti du couloir)", "PRINT"), "G3c toujours lâché quand il sort du couloir")
	motion[jude] = nil
	GuardService.StopNightPatrol()

	---------------------------------------------------------------- G4
	print("\nG4 : code et Config")
	local balance = SOURCES["shared/Config/Balance.luau"] or ""
	local night = SOURCES["shared/Config/Night.luau"] or ""
	local truck = SOURCES["shared/Config/TruckEvent.luau"] or ""
	check(string.find(SRC_GUARD, "aimPoint", 1, true) == nil and string.find(SRC_GUARD, "LEAD_MAX", 1, true) == nil, "G4a plus d'anticipation (aimPoint, LEAD_*)")
	check(string.find(SRC_GUARD, "GiveUpChaseDuration", 1, true) == nil and string.find(SRC_GUARD, "GiveUpAfter", 1, true) == nil
		and string.find(SRC_GUARD, ".GiveUpLead", 1, true) == nil, "G4b GuardService ne lit plus aucun champ d'abandon")
	check(string.find(balance, "GiveUpChaseDuration", 1, true) == nil and string.find(night, "GiveUpChaseDuration", 1, true) == nil
		and string.find(night, "GiveUpLead", 1, true) == nil and string.find(truck, "DriverGiveUpAfter", 1, true) == nil,
		"G4c Config : GiveUpChaseDuration, Night.GiveUpLead et DriverGiveUpAfter retirés")
	check(string.find(balance, "GiveUpLead", 1, true) ~= nil, "G4d Balance.Guard.GiveUpLead gardé (échelle de la jauge du HUD)")
	summary()
end
main()
