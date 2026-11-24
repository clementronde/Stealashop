--!nocheck
-- Banc a164 : scénarios du vrai RebirthService (voir run.sh). Un scénario par exécution (état neuf).

-- Profil prêt pour la 1re renaissance : 25B, le Diamant géant (exposé), un autre objet.
local function readyProfile()
	local d = newData()
	d.Cash = 25e9
	d.Items.req1 = item("Z6_DiamantGeant", 6)
	d.Items.low = item("Z1_PotDeNouilles", 1)
	d.Display["1"] = "req1"
	return d
end

local function start(rebirthOn, studio)
	IS_STUDIO = studio == true
	patchFeatures(rebirthOn)
	local service = loadRebirthService()
	service.Init()
	return service
end

if SCENARIO == "off" then
	-- Coupé hors Studio (Features.Rebirth = false, le jeu publié) : rien ne bouge.
	local baseIncome = FAKES.DisplayService.GetIncomeMultiplier
	local baseGain = FAKES.TrainingService.GetGainMultiplier
	local baseVault = FAKES.PvPService.GetVaultSlots
	local d = readyProfile()
	d.Rebirths = 3
	DATA[P1] = d
	local service = start(false, false)
	check(Config.Features.Rebirth == false, "O0 Features.Rebirth = false (vraie valeur)")
	check(not service.IsEnabled(), "O1 coupé")
	check(FAKES.DisplayService.GetIncomeMultiplier == baseIncome and FAKES.TrainingService.GetGainMultiplier == baseGain and FAKES.PvPService.GetVaultSlots == baseVault, "O2 aucune accroche installée")
	local before = deepCopy(d)
	check(REBIRTH_HANDLER ~= nil, "O3 remote Rebirth écouté (et ignoré)")
	REBIRTH_HANDLER(P1, 4)
	REBIRTH_HANDLER(P1, 1)
	local ok, reason = service.Request(P1, 4)
	check(not ok and reason == "Disabled", `O4 Request refusé : Disabled ({reason})`)
	check(deepEqual(before, d), "O5 profil identique, même avec 3 renaissances déjà dans le profil")
	check(P1:GetAttribute("Rebirths") == nil and P1:GetAttribute("RebirthItemOwned") == nil, "O6 aucun attribut")
	check(#NOTES == 0 and #TELEMETRY == 0 and SAVES[P1] == nil and count(CALLS) == 0, "O7 ni message, ni télémétrie, ni sauvegarde, ni appel de service")
	Workspace:SetAttribute("RebirthTest", true)
	check(not service.IsEnabled() and P1:GetAttribute("Rebirths") == nil, "O8 hors Studio, RebirthTest n'allume rien")
elseif SCENARIO == "studio" then
	-- Coupé en Studio : accroches posées mais neutres, tant que RebirthTest n'est pas vrai.
	local d = readyProfile()
	d.Rebirths = 3
	DATA[P1] = d
	local service = start(false, true)
	check(not service.IsEnabled(), "S1 coupé en Studio sans RebirthTest")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 1 and FAKES.TrainingService.GetGainMultiplier(P1, "Treadmill") == 1 and FAKES.PvPService.GetVaultSlots(P1) == 1, "S2 accroches neutres (×1, ×1, 1 coffre-fort)")
	local before = deepCopy(d)
	local ok, reason = service.Request(P1, 4)
	check(not ok and reason == "Disabled" and deepEqual(before, d), "S3 Request refusé, profil identique")
	check(P1:GetAttribute("Rebirths") == nil, "S4 pas d'attribut Rebirths")
	Workspace:SetAttribute("RebirthTest", true)
	check(service.IsEnabled() and P1:GetAttribute("Rebirths") == 3 and P1:GetAttribute("RebirthItemOwned") == false, "S5 RebirthTest = true : allumé, Rebirths = 3, pas de Statue de la Liberté")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 2.5 and FAKES.TrainingService.GetGainMultiplier(P1, "Treadmill") == 1.5 and FAKES.PvPService.GetVaultSlots(P1) == 2, "S6 allumé : revenus ×2,5, tapis ×1,5, 2 coffres-forts")
	Workspace:SetAttribute("RebirthTest", false)
	check(not service.IsEnabled() and P1:GetAttribute("Rebirths") == nil and P1:GetAttribute("RebirthItemOwned") == nil, "S7 RebirthTest = false : coupé, attributs retirés")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 1, "S8 coupé : revenus ×1")
	check(deepEqual(before, d), "S9 profil jamais touché")
elseif SCENARIO == "refus" then
	local d = readyProfile()
	DATA[P1] = d
	local service = start(true, false)
	check(service.IsEnabled(), "R0 allumé (Features.Rebirth = true)")
	local function refused(label, level, wanted, noteWanted)
		local before = deepCopy(d)
		local notes = #NOTES
		local ok, reason = service.Request(P1, level)
		check(not ok and reason == wanted, `{label} : refusé {wanted} ({tostring(ok)}, {tostring(reason)})`)
		check(deepEqual(before, d), `{label} : profil identique`)
		local note = lastNote(P1)
		if noteWanted then
			check(#NOTES == notes + 1 and note[3] == "Warning" and string.find(note[2], noteWanted, 1, true) ~= nil, `{label} : Notify « {note and note[2]} »`)
		else
			check(#NOTES == notes, `{label} : aucun message`)
		end
	end
	refused("R1 palier 2 sans la 1re", 2, "Stale", nil)
	refused("R2 palier 0", 0, "Stale", nil)
	refused("R3 palier pas un nombre", "1", "Stale", nil)
	CARRYING[P1] = true
	refused("R4 porte un colis", 1, "Carrying", "Bring home")
	CARRYING[P1] = nil
	HELD.low = true
	refused("R5 un objet en train d'être volé", 1, "Stolen", "being stolen")
	HELD.low = nil
	d.Items.floor = item("Z1_PotDeNouilles", 1, { Spot = { X = 1, Y = 0, Z = 2 }, AntiTheft = true })
	refused("R6 un objet au sol", 1, "Floor", "shop floor")
	d.Items.floor = nil
	d.Boxes.fb = { Tier = "Standard", Zone = 1, ItemId = "Z1_PotDeNouilles", Rarity = "Rare", Spot = { X = 0, Y = 0, Z = 0 }, ReadyAt = 5 }
	refused("R7 un colis au sol", 1, "Floor", "shop floor")
	d.Boxes.fb = nil
	d.Items.req1 = nil
	d.Display["1"] = nil
	refused("R8 sans Diamant géant", 1, "NoItem", "Giant Diamond")
	d.Boxes.bx = { Tier = "Luxe", Zone = 6, ItemId = "Z6_DiamantGeant", Rarity = "Rare" }
	refused("R9 Diamant géant encore dans un colis", 1, "NoItem", "Giant Diamond")
	d.Boxes.bx = nil
	d.Items.req1 = item("Z6_DiamantGeant", 6)
	d.Cash = 18e9
	REGISTER[P1] = 1e9
	refused("R10 18B + 1B sur les plaques", 1, "NoCash", "$20B")
	check(REGISTER[P1] == 1e9 and (CALLS.CashOut or 0) == 0, "R11 plaques pas encaissées après un refus")
	check(SAVES[P1] == nil and #TELEMETRY == 0, "R12 ni sauvegarde ni télémétrie après les refus")
	d.Cash = 19e9
	local ok = service.Request(P1, 1)
	check(ok and d.Cash == 0 and d.Rebirths == 1 and REGISTER[P1] == 0, "R13 19B + 1B sur les plaques : accepté, argent à 0")
	local before = deepCopy(d)
	local again, reason = service.Request(P1, 1)
	check(not again and reason == "Stale" and deepEqual(before, d), "R14 la même demande deux fois : la 2e ignorée")
elseif SCENARIO == "reset" then
	-- Ordre des revenus supposé par ce scénario.
	local mythic = incomeOf("Z6_CleDuCoffreUltime", 6)
	local legend = incomeOf("Z6_CoffreDeDiamants", 6)
	local rareGold = incomeOf("Z6_DiamantGeant", 6, { Effect = "Gold" })
	check(mythic > legend and legend > rareGold and rareGold > incomeOf("Z5_MasqueAncien", 5) * 0 , `T0 revenus : Mythique {mythic} > Légendaire {legend} > Rare doré {rareGold}`)
	local d = newData()
	d.Cash = 25e9
	REGISTER[P1] = 3e9
	d.Items.req1 = item("Z6_DiamantGeant", 6)
	d.Items.req2 = item("Z6_DiamantGeant", 6, { Mutation = { Effect = "Gold" } })
	d.Items.a = item("Z6_CleDuCoffreUltime", 6)
	d.Items.b = item("Z6_CoffreDeDiamants", 6, { AntiTheft = true, UnlockAt = 123 })
	d.Items.c = item("Z1_PotDeNouilles", 1)
	d.Items.d = item("Z2_PelucheGeante", 2)
	d.Boxes.box1 = { Tier = "Luxe", Zone = 6, ItemId = "Z6_CoffreDeDiamants", Rarity = "Legendary", At = 9 }
	d.Boxes.box2 = { Tier = "Standard", Zone = 1, ItemId = "Z1_PotDeNouilles", Rarity = "Rare", At = 9 }
	d.Display = { ["1"] = "req1", ["2"] = "b", ["3"] = "c" }
	d.Vault = { ["1"] = "d" }
	d.Hotbar = { "Tool", "Bat", "c", "a", "box2", "" }
	DATA[P1] = d
	DATA[P2] = newData()
	local kept = deepCopy({ SkillTree = d.SkillTree, Index = d.Index, Purchases = d.Purchases, Monetization = d.Monetization, Boosts = d.Boosts, Rewards = d.Rewards, Tutorial = d.Tutorial, Lifetime = d.Lifetime, PotionStock = d.PotionStock, ZonesReached = d.ZonesReached })
	local service = start(true, false)
	check(P1:GetAttribute("Rebirths") == 0 and P1:GetAttribute("RebirthItemOwned") == true, "T1 attributs au chargement : 0 renaissance, Diamant géant possédé")
	local ok, reason = service.Request(P1, 1)
	check(ok == true and reason == nil, `T2 renaissance acceptée ({tostring(reason)})`)
	check(d.Cash == 0 and P1:GetAttribute("Cash") == 0, `T3 argent à 0, plaques comprises ({d.Cash})`)
	check(d.Rebirths == 1 and P1:GetAttribute("Rebirths") == 1 and P1:GetAttribute("RebirthItemOwned") == false, "T4 Rebirths = 1 (profil et attribut), Trône en or pas possédé")
	check(count(d.Items) == 3 and d.Items.a ~= nil and d.Items.b ~= nil and d.Items.box1 ~= nil, "T5 3 objets gardés : Clé (Mythique), Coffre exposé, Coffre du colis (à égalité, l'exposé d'abord)")
	check(d.Items.req1 == nil and d.Items.req2 == nil and d.Items.c == nil and d.Items.d == nil, "T6 Diamants (remis et doré), Pot de nouilles et Peluche partis")
	check(d.Items.box1.Id == "Z6_CoffreDeDiamants" and d.Items.box1.Zone == 6 and d.Items.box1.Source == "NPC", "T7 colis gardé ouvert d'office : l'objet du colis, même uid")
	check(d.Items.b.AntiTheft == nil and d.Items.b.UnlockAt == nil and d.Items.b.Spot == nil, "T8 antivol retiré des objets gardés")
	local shown = {}
	for _, uid in d.Display do
		shown[uid] = true
	end
	check(count(d.Display) == 3 and shown.a and shown.b and shown.box1, "T9 les 3 gardés sur les présentoirs (PlaceAuto)")
	check(count(d.Vault) == 0 and count(d.Boxes) == 0, "T10 coffre-fort du profil et colis vidés")
	check(#d.Tools.Owned == 1 and d.Tools.Owned[1] == "Fists" and d.Tools.Equipped == "Fists", "T11 outils : Fists seulement")
	check(#d.Cosmetics.Auras == 0 and #d.Cosmetics.Trails == 0 and d.Cosmetics.EquippedAura == nil and d.Cosmetics.EquippedTrail == nil, "T12 auras et trails retirés")
	check(d.Upgrades.Treadmill == 0 and d.Upgrades.Bench == 0 and d.Upgrades.DisplaySlots == 0 and d.Upgrades.UnboxBenches == 2, "T13 tapis, banc et présentoirs à 0 (UnboxBenches, sans effet, gardé)")
	check(d.Stats.Speed == 0 and d.Stats.Strength == 0, "T14 Speed et Strength à 0")
	check(d.Offline.Pending == nil and d.Offline.LastSeenAt == 1000, "T15 gains hors ligne pas réclamés perdus")
	check(deepEqual(d.Hotbar, { "Tool", "Bat", "", "a", "", "" }), `T16 barre du bas : cases des objets partis vidées ({table.concat(d.Hotbar, ",")})`)
	local same = true
	for key, value in kept do
		if not deepEqual(value, d[key]) then
			same = false
			print("    changé : " .. key)
		end
	end
	check(same, "T17 gardés tels quels : arbre, index, achats Robux, Monetization, boosts, récompenses, tuto, Lifetime, potions, zones")
	check(SAVES[P1] == 1, "T18 une sauvegarde demandée tout de suite")
	local economy, event = TELEMETRY[1], TELEMETRY[2]
	check(economy and economy[1] == "Economy" and economy[2] == "Rebirth" and economy[3] == 20e9 and economy[4] == "Rebirth1", "T19 télémétrie : dépense Rebirth 20B, SKU Rebirth1")
	check(event and event[1] == "Event" and event[2] == "Rebirth" and event[3][1] == "Level - 1" and event[4] == 30000, "T20 télémétrie : événement Rebirth, Level - 1, temps de jeu")
	local note = lastNote(P1)
	check(note and note[2] == "Rebirth 1! Income x1.5 forever." and note[3] == "Info", `T21 message au joueur ({note and note[2]})`)
	local other = lastNote(P2)
	check(other and other[2] == "Ada reached Rebirth 1!", "T22 annonce aux autres joueurs du serveur")
	check(#DISCOVERED == 1 and DISCOVERED[1] == "Z6_CoffreDeDiamants", "T23 index : l'objet du colis gardé découvert")
	for _, name in { "Held.Stow", "Train.Stop", "Tool.Equip:Fists", "CashOut", "Stats.Refresh", "Cosmetic.Refresh", "Shop.Refresh", "Unbox.Refresh", "Machine.Refresh", "Rayon.Refresh", "Inventory.Refresh", "Tool.RefreshDamage" } do
		check((CALLS[name] or 0) >= 1, `T24 service remis d'accord : {name}`)
	end
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 1.5 and FAKES.TrainingService.GetGainMultiplier(P1, "Treadmill") == 1 and FAKES.PvPService.GetVaultSlots(P1) == 1, "T25 après la 1re : revenus ×1,5, tapis ×1, 1 coffre-fort")
	check(FAKES.DisplayService.GetIncomeMultiplier(P2) == 1, "T26 l'autre joueur : ×1")

	-- L'objet requis remis est la copie qui rapporte le moins ; il ne compte pas dans les 3.
	local e = newData()
	e.Cash = 20e9
	e.Items.plain = item("Z6_DiamantGeant", 6)
	e.Items.gold = item("Z6_DiamantGeant", 6, { Mutation = { Effect = "Gold" } })
	e.Items.noodle = item("Z1_PotDeNouilles", 1)
	DATA[P2] = e
	check(service.Request(P2, 1) == true, "T27 2e joueur : renaissance avec exactement 20B")
	check(count(e.Items) == 2 and e.Items.gold ~= nil and e.Items.noodle ~= nil and e.Items.plain == nil, "T28 le Diamant sans mutation remis, le doré gardé, et le Pot de nouilles (moins de 3 objets)")
	check(e.Cash == 0, "T29 argent à 0")
elseif SCENARIO == "bonus" then
	FAKES.DisplayService.GetIncomeMultiplier = function() return 2 end -- ×2 Argent d'avant (MonetizationService)
	FAKES.TrainingService.GetGainMultiplier = function() return 2 end -- ×2 Entraînement
	FAKES.PvPService.GetVaultSlots = function() return 3 end -- arbre : Safe niveau 2
	local d = newData()
	DATA[P1] = d
	start(true, false)
	local function at(n)
		d.Rebirths = n
		return FAKES.DisplayService.GetIncomeMultiplier(P1), FAKES.TrainingService.GetGainMultiplier(P1, "Treadmill"), FAKES.PvPService.GetVaultSlots(P1)
	end
	local cases = {
		{ 0, 2, 2, 3 },
		{ 1, 3, 2, 3 },
		{ 2, 4, 2, 4 },
		{ 3, 5, 3, 4 },
		{ 6, 8, 4.5, 4 },
		{ 10, 12, 4.5, 4 },
		{ 12, 14, 4.5, 4 },
	}
	for _, c in cases do
		local income, gain, vault = at(c[1])
		check(income == c[2] and math.abs(gain - c[3]) < 1e-9 and vault == c[4], `B {c[1]} renaissance(s) : revenus ×{income} (attendu {c[2]}), tapis ×{gain} ({c[3]}), coffres {vault} ({c[4]}), bonus d'avant gardés`)
	end
	d.Rebirths = 3
	check(FAKES.TrainingService.GetGainMultiplier(P1, "Bench") == 2, "B2 le bonus de tapis ne touche que le tapis")
	for _, bad in { -1, 0 / 0, math.huge, "3" } do
		d.Rebirths = bad
		check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 2 and FAKES.PvPService.GetVaultSlots(P1) == 3, `B3 Rebirths illisible ({tostring(bad)}) : comme 0`)
	end
	d.Rebirths = 2.7
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 4, "B4 2,7 compte pour 2")
	DATA[P1] = nil
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 2, "B5 sans profil : ×1 de plus")
elseif SCENARIO == "atomic" then
	local d = readyProfile()
	d.Items.extra = item("Z6_CleDuCoffreUltime", 6)
	DATA[P1] = d
	local service = start(true, false)
	-- Services en erreur après le profil : la renaissance tient quand même.
	FAKES.StatsService.Refresh = function() error("Stats en panne") end
	FAKES.InventoryService.Refresh = function() error("Inventaire en panne") end
	FAKES.DisplayService.PlaceAuto = function() error("Présentoirs en panne") end
	FAKES.TelemetryService.LogEvent = function() error("Télémétrie en panne") end
	local co = coroutine.create(function()
		return service.Request(P1, 1)
	end)
	local resumed, ok = coroutine.resume(co)
	check(resumed and coroutine.status(co) == "dead", "A1 Request finit sans un seul yield (aucune sauvegarde ne peut passer au milieu)")
	check(ok == true, "A2 renaissance acceptée malgré trois services en panne après coup")
	check(SPEND_SNAPSHOT and SPEND_SNAPSHOT.Rebirths == 1 and SPEND_SNAPSHOT.Items == 2 and SPEND_SNAPSHOT.Equipped == "Fists" and SPEND_SNAPSHOT.Speed == 0, "A3 l'argent est retiré en dernier : tout le reste déjà écrit")
	check(d.Rebirths == 1 and d.Cash == 0 and count(d.Items) == 2 and d.Items.req1 == nil and count(d.Display) == 0, "A4 profil entier : compteur, argent, objets (présentoirs vides : PlaceAuto en panne)")
	check(SAVES[P1] == 1, "A5 sauvegarde demandée quand même")
	local warned = 0
	for _, line in WARNS do
		if string.find(line, "après la renaissance", 1, true) then
			warned += 1
		end
	end
	check(warned == 3, `A6 une ligne d'avertissement par service en panne ({warned})`)
	check(P1:GetAttribute("Rebirths") == 1, "A7 attribut posé")
elseif SCENARIO == "test" then
	local d = readyProfile()
	DATA[P1] = d
	local service = start(false, true)
	Workspace:SetAttribute("RebirthTestLevel", "101 4")
	check(service.IsEnabled() and d.Rebirths == 4 and P1:GetAttribute("Rebirths") == 4, "E1 « 101 4 » : allumé, 4 renaissances")
	check(Workspace:GetAttribute("RebirthTestLevel") == nil, "E2 attribut de test remis à nil")
	check(FAKES.DisplayService.GetIncomeMultiplier(P1) == 3, "E3 revenus ×3 après la 4e")
	Workspace:SetAttribute("RebirthTestLevel", "Ada 1")
	check(d.Rebirths == 1 and P1:GetAttribute("Rebirths") == 1 and P1:GetAttribute("RebirthItemOwned") == false, "E4 par le nom : 1 renaissance, Trône en or pas possédé")
	local before = deepCopy(d)
	Workspace:SetAttribute("RebirthTestLevel", "999 3")
	Workspace:SetAttribute("RebirthTestLevel", "101 x")
	Workspace:SetAttribute("RebirthTestLevel", "101 -2")
	check(deepEqual(before, d) and #WARNS >= 3, "E5 joueur inconnu ou nombre invalide : rien, un avertissement")
	d.Items.throne = item("Z6_TroneEnOr", 6)
	Workspace:SetAttribute("RebirthTest", true)
	check(P1:GetAttribute("RebirthItemOwned") == true, "E6 Trône en or possédé : RebirthItemOwned")
	d.Items.throne.Spot = { X = 0, Y = 0, Z = 0 }
	Workspace:SetAttribute("RebirthTest", false)
	Workspace:SetAttribute("RebirthTest", true)
	check(P1:GetAttribute("RebirthItemOwned") == false, "E7 Trône posé au sol : pas compté")
	Workspace:SetAttribute("RebirthTest", false)
	local ok, reason = service.Request(P1, 2)
	check(not ok and reason == "Disabled" and P1:GetAttribute("Rebirths") == nil, "E8 RebirthTest = false : coupé, plus d'attribut")
else
	error("scénario inconnu : " .. tostring(SCENARIO))
end

print(`{checks} vérification(s), {fails} échec(s)`)
