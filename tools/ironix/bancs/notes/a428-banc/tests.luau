---------------------------------------------------------------- a428 : G. zones ouvertes par les renaissances, plusieurs déguisés par zone (L-328 point 2)
do
	local W = makeWorld()
	local service = W.start()
	local C, M = W.config, W.config.Messages
	check(C.OnePerZone == false and C.ZoneRebirthOffset == 1, "G1 Config : OnePerZone coupé, zone n à n − 1 renaissances")
	local a = W.addPlayer("Ana", v3(0, 3, 0))
	local b = W.addPlayer("Bob", v3(0, 3, 0))
	local c = W.addPlayer("Cid", v3(0, 3, 0))
	W.handlers.Disguise(a, 1)
	W.handlers.Disguise(b, 1)
	W.handlers.Disguise(c, 1)
	check(service.GetZone(a) == 1 and service.GetZone(b) == 1 and service.GetZone(c) == 1, "G2 trois déguisés dans la zone 1 en même temps")
	local d = W.addPlayer("Dan", v3(0, 3, 0))
	d:SetAttribute("Rebirths", 4)
	W.handlers.Disguise(d, 6)
	check(not service.IsDisguised(d) and W.lastNote(d) == string.format(M.ZoneLocked, 6, 5), "G3 zone 6 avec 4 renaissances : refus « Rebirth 5 »")
	d:SetAttribute("Rebirths", 5)
	W.handlers.Disguise(d, 6)
	check(service.GetZone(d) == 6, "G4 zone 6 avec 5 renaissances : acceptée")
	local e = W.addPlayer("Eve", v3(0, 3, 0))
	W.handlers.Disguise(e, 2)
	check(not service.IsDisguised(e) and W.lastNote(e) == string.format(M.ZoneLocked, 2, 1), "G5 zone 2 sans renaissance : refus (Clément : zone 2 à 1 renaissance)")
	e:SetAttribute("Rebirths", 1)
	W.handlers.Disguise(e, 2)
	check(service.GetZone(e) == 2, "G6 zone 2 avec 1 renaissance : acceptée")
	check(#W.warns == 0, "G7 aucun avertissement")
end

---------------------------------------------------------------- a428 : H. le dénonciateur récupère l'objet du voleur (L-328 point 7)
-- Ana, déguisée en zone 1, dénonce STORE_Z1_A ; Bob est dans le magasin avec un objet du magasin.
local function denounced(options)
	local W = makeWorld(options)
	local service = W.start()
	local C = W.config
	local snitch = W.addPlayer("Ana", v3(0, 3, 0))
	local thief = W.addPlayer("Bob", v3(200, 3, -60))
	local payload = { Kind = "NPCItem", StoreId = "STORE_Z1_A", ItemId = "Z1_Test" }
	W.carry[thief] = payload
	W.handlers.Disguise(snitch, 1)
	W.moveTo(snitch, v3(200, 3, 0), v3(0, 0, -1))
	W.handlers.Denounce(snitch, "STORE_Z1_A", "Begin")
	advance(C.DenounceTime)
	W.handlers.Denounce(snitch, "STORE_Z1_A", "End")
	local police = W.policeOf[thief]
	-- capture par ce policier : GuardService a fini sa poursuite (TargetUserId = 0), il est sur le voleur
	local function caughtByPolice(night)
		police:SetAttribute("TargetUserId", 0)
		for _, fn in W.catch do
			fn(thief, 1, night == true, W.carry[thief] ~= nil)
		end
	end
	return W, service, snitch, thief, payload, police, caughtByPolice
end

do
	local W, service, snitch, thief, payload, police, caught = denounced()
	local M = W.config.Messages
	check(police ~= nil and #W.denounced == 1, "H0 police lancée sur le voleur par la dénonciation")
	for _, fn in W.catch do
		fn(thief, 1, false, true) -- un vigile l'attrape : le policier court encore (TargetUserId = Bob)
	end
	check(#W.transfers == 0 and W.carry[thief] == payload, "H1 attrapé par un autre que le policier de la dénonciation : rien ne change")
	caught()
	local t = W.transfers[1]
	check(t ~= nil and t.from == thief and t.to == snitch and t.reason == "Denounced", "H2 attrapé par ce policier : CarryService.Transfer(voleur, dénonciateur, « Denounced »)")
	check(W.carry[snitch] == payload and W.carry[thief] == nil, "H3 l'objet passe au dénonciateur, même dans le magasin (pas de retour au rayon)")
	check(W.lastNote(snitch) == string.format(M.Recovered, "Bob"), "H4 le dénonciateur est prévenu")
	W.carry[thief] = { Kind = "NPCItem", StoreId = "STORE_Z1_A" }
	W.carry[snitch] = nil
	caught()
	check(#W.transfers == 1, "H5 une seule fois par dénonciation")
	check(not service.IsDisguised(thief), "H6 le voleur n'était pas déguisé")
	check(#W.warns == 0, "H7 aucun avertissement")
end

do
	local W, _, _, thief, payload, police, caught = denounced()
	rawset(police, "_pivot", CFrame.new(200 + W.config.RecoverCatchRange + 5, 0, -60))
	caught()
	check(#W.transfers == 0 and W.carry[thief] == payload, "H8 policier loin du voleur à la capture : rien")
	rawset(police, "_pivot", CFrame.new(200, 0, -60))
	caught()
	check(#W.transfers == 1, "H9 la même capture, policier sur le voleur : transmis")
end

do
	local W, _, _, thief, payload, _, caught = denounced()
	caught(true)
	check(#W.transfers == 0 and W.carry[thief] == payload, "H10 capture de nuit : rien")
end

do
	local W, _, _, thief, payload, police, caught = denounced()
	police.Parent = nil
	caught()
	check(#W.transfers == 0 and W.carry[thief] == payload, "H11 policier reparti : rien")
end

do
	local W, _, snitch, thief, payload, _, caught = denounced()
	snitch.Parent = nil
	W.players.PlayerRemoving:Fire(snitch)
	caught()
	check(#W.transfers == 0 and W.carry[thief] == payload, "H12 dénonciateur parti : rien (l'objet tombe ou revole comme avant)")
end

do
	local W, _, _, thief, payload, _, caught = denounced({ recoverOff = true })
	caught()
	check(#W.transfers == 0 and W.carry[thief] == payload, "H13 Features.DenounceRecover coupé : rien")
end

do
	local W, _, _, thief, _, _, caught = denounced()
	W.carry[thief] = { Kind = "PlayerItem" }
	caught()
	check(#W.transfers == 0, "H14 objet volé à un joueur : jamais transmis")
end

do
	local W, _, snitch, thief, payload, _, caught = denounced()
	local M = W.config.Messages
	W.carry[snitch] = { Kind = "NPCItem", StoreId = "STORE_Z1_B" }
	caught()
	check(#W.transfers == 1 and W.carry[thief] == payload and W.lastNote(snitch) ~= string.format(M.Recovered, "Bob"), "H15 dénonciateur mains pleines : Transfer refuse, le voleur garde l'objet (suite de la capture comme avant)")
end

do
	local W, service, snitch, thief, payload, _, caught = denounced()
	advance(W.config.Duration + 1)
	check(not service.IsDisguised(snitch), "H16 le déguisement du dénonciateur est fini")
	caught()
	check(W.carry[snitch] == payload and W.carry[thief] == nil, "H17 il récupère l'objet même redevenu joueur")
	check(#W.warns == 0, "H18 aucun avertissement")
end

---------------------------------------------------------------- a428 : K. lecture du code (client et CarryService)
do
	local W = makeWorld()
	W.start()
	check(W.config.Cabin.PromptPart == "PromptPart" and W.config.Cabin.ModelName == "FittingRoom", "K1 Config : cabine FittingRoom, invite sur PromptPart")
	check(string.find(CLIENT_SRC, "FindFirstChild(Disguise.Cabin.PromptPart)", 1, true) ~= nil, "K2 DisguiseController pose l'invite sur PromptPart d'abord")
	local s = string.find(CARRY_SRC, "function CarryService.Transfer(", 1, true)
	check(s ~= nil, "K3 CarryService.Transfer existe")
	local body = if s then string.sub(CARRY_SRC, s, (string.find(CARRY_SRC, "\nend\n", s, true) or #CARRY_SRC)) else ""
	local fin = string.find(body, 'finish(from, "Dropped"', 1, true)
	local free = string.find(body, "held[keyOf(payload)] = nil", 1, true)
	local start = string.find(body, "CarryService.StartCarry(to, payload)", 1, true)
	check(fin ~= nil and free ~= nil and start ~= nil and fin < free and free < start, "K4 Transfer : fin « Dropped » chez le voleur, objet libéré, puis StartCarry du dénonciateur")
	check(string.find(body, 'Kind ~= "NPCItem"', 1, true) ~= nil and string.find(body, "carries[to] ~= nil", 1, true) ~= nil, "K5 Transfer : objet NPCItem seulement, refus si le preneur porte déjà")
	check(string.find(body, "FailNoDrop", 1, true) == nil and string.find(body, "backToShelf", 1, true) == nil, "K6 Transfer : jamais de retour au rayon")
end

REAL_PRINT(`banc a428 : {CHECKS} vérification(s), {FAILS} échec(s)`)
