--!nocheck
-- Banc a88, scénario guard (2026-11-11, vague 28) : le vrai GuardService et son point d'accroche
-- IsHiddenFromNight (posé par PotionService pour la potion d'invisibilité ; simulé ici).
--   N1 caché : le vigile de nuit ne le repère pas, même tout près et dans le cône de sa lampe
--   N2 plus caché : repéré
--   N3 caché pendant la poursuite : le vigile continue
--   N4 accroche en erreur : compte pour « visible », une ligne

local function main()
	local SRC_GUARD = SOURCES["server/Services/GuardService.luau"] or ""
	if string.find(SRC_GUARD, "IsHiddenFromNight", 1, true) == nil then
		print("\na88 SAUTÉ : cet arbre n'a pas encore GuardService.IsHiddenFromNight")
		summary()
		return
	end
	check(GuardService.IsHiddenFromNight(nil) == false, "N0 par défaut : personne n'est caché")
	PROPS.SpotLight = PROPS.SpotLight or { Face = Enum.NormalId.Front, Range = 0, Angle = 0, Brightness = 0, Color = Color3.new(1, 1, 1), Shadows = false }
	for k, x in { 1000, 1060 } do
		local p = new("Part", `NightPatrol_Z1_{k}`, Workspace)
		p.Size = Vector3.new(3, 0.2, 3)
		p.CFrame = CFrame.new(x, 0.2, 200)
		p.Anchored = true
		p:SetAttribute("Zone", 1)
		addTag(p, "NightPatrol")
	end
	local kim = addPlayer("Kim", Vector3.new(1015, 3, 200))
	local hidden = { [kim] = true }
	local base = GuardService.IsHiddenFromNight
	GuardService.IsHiddenFromNight = function(player)
		return base(player) or hidden[player] == true
	end
	local hooks = {
		InCorridor = function(_position)
			return true
		end,
		Ignores = function(_player)
			return false
		end,
		SendHome = function(_player)
			return true
		end,
	}

	print("\nN1 : caché")
	clearLog()
	local count = GuardService.StartNightPatrol(hooks)
	runFor(3)
	check(count >= 1 and not GuardService.IsNightChased(kim), "N1 invisible : pas repéré en 3 s, à 15 studs d'un vigile de nuit")

	print("\nN2 : visible")
	check(not logHas("repère Kim", "PRINT"), "N1 aucune ligne « repère Kim »")
	motion[kim] = runTo(Vector3.new(4000, 3, 200), 60) -- il s'enfuit (sinon il est attrapé tout de suite)
	hidden[kim] = nil
	runFor(1)
	check(logHas("repère Kim", "PRINT") and GuardService.IsNightChased(kim), "N2 l'effet fini : repéré et poursuivi")

	print("\nN3 : caché pendant la poursuite")
	hidden[kim] = true
	runFor(3)
	check(GuardService.IsNightChased(kim) and not logHas("abandonne Kim", "PRINT"), "N3 déjà poursuivi : le vigile continue")
	motion[kim] = nil
	GuardService.StopNightPatrol()
	rootOf(kim).CFrame = CFrame.new(-500, 3, 200) -- loin, hors de vue
	runFor(0.5)

	print("\nN4 : accroche en erreur")
	clearLog()
	local lee = addPlayer("Lee", Vector3.new(1015, 3, 200))
	GuardService.IsHiddenFromNight = function(_player)
		error("panne simulée")
	end
	GuardService.StartNightPatrol(hooks)
	runFor(2)
	check(logHas("repère Lee", "PRINT"), "N4 erreur : compte pour visible, repéré")
	check(logHas("IsHiddenFromNight", "WARN"), "N4 une ligne dans la sortie")
	GuardService.StopNightPatrol()
	GuardService.IsHiddenFromNight = base
	if DEBUG88 or FAILS > 0 then
		for _, line in FULL_LOG do
			if string.find(line.text, "Kim", 1, true) or string.find(line.text, "Lee", 1, true) or string.find(line.text, "nuit", 1, true) then
				print("    LOG " .. line.kind .. " " .. line.text)
			end
		end
	end
	summary()
end
main()
