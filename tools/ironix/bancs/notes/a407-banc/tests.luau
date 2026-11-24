--!nocheck
-- Banc a407 (vague GC6, MAJ 3) : outils de renaissance (Features.RebirthTools, Config/Tools RequiresRebirth,
-- KeepOnRebirth, DoorHits). Lu après la lib.luau d'a244.

-- Charge un vrai service de ServerScriptService/Services, ses voisins pris dans `parent`.
local function loadService(name, parent)
	local env = setmetatable({
		script = { Name = name, Parent = parent },
		require = function(target)
			local path = if type(target) == "table" then rawget(target, "__path") else nil
			if path ~= nil then
				return charge(path)
			end
			return target
		end,
		warn = function(...) table.insert(WARNS, table.concat({ ... }, " ")) end,
		print = function(...) if VERBOSE then print(...) end end,
	}, { __index = getfenv(0) })
	local fn = assert(loadstring(SOURCES[name], "=" .. name))
	setfenv(fn, env)
	return fn()
end

local function has(list, id)
	return table.find(list, id) ~= nil
end

if SCENARIO == "config" then
	local Tools = Config.Tools
	local Rebirths = Config.Rebirths
	check(Config.Features.RebirthTools == true, "C1 Features.RebirthTools = true")
	local ag = Tools.ById.AngleGrinder
	local jack = Tools.ById.Jackhammer
	local ram = Tools.ById.BatteringRam
	check(jack ~= nil and ram ~= nil, "C2 Jackhammer et BatteringRam dans Config/Tools")
	check(jack.Power == ag.Power and ram.Power == ag.Power, "C3 puissance de l'Angle Grinder (zone 6 à deux joueurs)")
	check(jack.RequiresRebirth == 5 and ram.RequiresRebirth == 7, "C4 ouverts aux 5e et 7e renaissances")
	check(jack.KeepOnRebirth == true and ram.KeepOnRebirth == true, "C5 gardés à la renaissance")
	check(ram.DoorHits == 3 and jack.DoorHits == nil and ag.DoorHits == nil, "C6 Bélier : 3 coups par frappe sur une porte, les autres 1")
	check(jack.Asset == "TOOL_Jackhammer" and ram.Asset == "TOOL_BatteringRam", "C7 modèles TOOL_Jackhammer et TOOL_BatteringRam")
	check(Tools.List[#Tools.List - 1] == jack and Tools.List[#Tools.List] == ram and jack.Order == 8 and ram.Order == 9, "C8 en fin de boutique, rangs 8 et 9")
	local strongest = 0
	for _, tool in Tools.List do
		strongest = math.max(strongest, tool.Power)
	end
	check(strongest <= ag.Power * 1.12, "C9 aucun outil au-dessus de 1,12 × Angle Grinder")
	check(Tools.NeedsRebirth(jack, nil) == 5 and Tools.NeedsRebirth(jack, 4) == 5, "C10 fermé sans attribut et à 4 renaissances")
	check(Tools.NeedsRebirth(jack, 5) == nil and Tools.NeedsRebirth(jack, 12) == nil, "C11 ouvert à 5 et au-delà")
	check(Tools.NeedsRebirth(jack, "5") == 5 and Tools.NeedsRebirth(jack, 0 / 0) == 5 and Tools.NeedsRebirth(jack, -1) == 5, "C12 valeur illisible : fermé")
	check(Tools.NeedsRebirth(ram, 6) == 7 and Tools.NeedsRebirth(ram, 7) == nil, "C13 Bélier : 6 fermé, 7 ouvert")
	check(Tools.NeedsRebirth(ag, nil) == nil and Tools.NeedsRebirth(Tools.ById.Fists, nil) == nil, "C14 outils ordinaires jamais fermés")
	check(#Tools.UnlockedBy(5) == 1 and Tools.UnlockedBy(5)[1] == jack, "C15 UnlockedBy(5) = Jackhammer")
	check(#Tools.UnlockedBy(7) == 1 and Tools.UnlockedBy(7)[1] == ram and #Tools.UnlockedBy(6) == 0, "C16 UnlockedBy(7) = Bélier, 6 : rien")
	check(Rebirths.Get(5).RewardText == "New tool in the Weapon Shop: Jackhammer", `C17 texte du 5e palier ({Rebirths.Get(5).RewardText})`)
	check(Rebirths.Get(7).RewardText == "New tool in the Weapon Shop: Battering Ram", `C18 texte du 7e palier ({Rebirths.Get(7).RewardText})`)
	check(Rebirths.Get(1).RewardText == "New skill: Lock", `C19 1er palier inchangé ({Rebirths.Get(1).RewardText})`)
	check(Rebirths.Get(6).RewardText == "" and Rebirths.Get(11).RewardText == "", "C20 6e et 11e : rien de plus que le multiplicateur")
	check(Rebirths.IncomeMultiplier(5) == 3.5 and Rebirths.IncomeMultiplier(10) == 6, "C21 multiplicateur inchangé (+50 % par renaissance)")
	check(Tools.RebirthsAttribute == Config.SkillTree.RebirthsAttribute, "C22 même attribut Rebirths que l'arbre")
elseif SCENARIO == "off" then
	PATCHES["Config/Features"] = function(source)
		local out, n = string.gsub(source, "\tRebirthTools = true,", "\tRebirthTools = false,")
		assert(n == 1, "Features : ligne RebirthTools = true introuvable")
		return out
	end
	local Tools = Config.Tools
	check(Config.Features.RebirthTools == false, "O1 interrupteur coupé")
	check(Tools.ById.Jackhammer == nil and Tools.ById.BatteringRam == nil and #Tools.List == 7, "O2 aucun outil de renaissance dans la boutique")
	check(#Tools.UnlockedBy(5) == 0 and Config.Rebirths.Get(5).RewardText == "", "O3 5e palier : pas de texte d'outil")
elseif SCENARIO == "keep" then
	local function profile(owned, equipped)
		local d = newData()
		d.Rebirths = 4
		d.Cash = 30e9
		d.Tools = { Owned = owned, Equipped = equipped }
		d.Items.req = item("Z3_PcGamer", 3)
		d.Items.a = item("Z1_PotDeNouilles", 1)
		return d
	end
	local d = profile({ "Fists", "Wrench", "Jackhammer", "AngleGrinder", "BatteringRam" }, "AngleGrinder")
	DATA[P1] = d
	local e = profile({ "Fists", "Wrench", "AngleGrinder" }, "AngleGrinder")
	DATA[P2] = e
	local service = loadRebirthService()
	service.Init()
	REBIRTH_HANDLER(P1, 5)
	check(d.Rebirths == 5, `K1 5e renaissance faite ({tostring(d.Rebirths)})`)
	check(#d.Tools.Owned == 3 and d.Tools.Owned[1] == "Fists" and has(d.Tools.Owned, "Jackhammer") and has(d.Tools.Owned, "BatteringRam"), `K2 outils gardés : Fists, Jackhammer, BatteringRam ({table.concat(d.Tools.Owned, ",")})`)
	check(not has(d.Tools.Owned, "AngleGrinder") and not has(d.Tools.Owned, "Wrench"), "K3 outils ordinaires remis à zéro")
	check(CALLS["Tool.Equip:BatteringRam"] == 1 and d.Tools.Equipped == "BatteringRam", `K4 le meilleur outil gardé revient en main ({tostring(d.Tools.Equipped)})`)
	check(CALLS["Tool.Equip:Fists"] ~= nil, "K5 poings en main avant la remise à zéro (comme avant)")
	local fistsBefore = CALLS["Tool.Equip:Fists"]
	REBIRTH_HANDLER(P2, 5)
	check(e.Rebirths == 5 and #e.Tools.Owned == 1 and e.Tools.Owned[1] == "Fists" and e.Tools.Equipped == "Fists", "K6 sans outil de renaissance : poings seuls, comme avant")
	check(CALLS["Tool.Equip:Fists"] == fistsBefore + 1 and CALLS["Tool.Equip:Jackhammer"] == nil, "K7 aucun outil remis en main en plus")
	local dup = profile({ "Fists", "Jackhammer", "Jackhammer" }, "Jackhammer")
	DATA[P1] = dup
	REBIRTH_HANDLER(P1, 5)
	check(dup.Rebirths == 5 and #dup.Tools.Owned == 2 and dup.Tools.Equipped == "Jackhammer", `K8 doublon dans le profil : gardé une fois ({table.concat(dup.Tools.Owned, ",")})`)
	check(#WARNS == 0, `K9 aucun avertissement ({WARNS[1] or ""})`)
elseif SCENARIO == "door" then
	local ToolService = loadService("ToolService", FAKES)
	local function set(owned, equipped)
		DATA[P1] = newData()
		DATA[P1].Tools = { Owned = owned, Equipped = equipped }
	end
	set({ "Fists", "BatteringRam" }, "BatteringRam")
	check(ToolService.GetDoorHits(P1) == 3, "D1 Bélier en main : 3 coups par frappe")
	set({ "Fists", "Jackhammer" }, "Jackhammer")
	check(ToolService.GetDoorHits(P1) == 1, "D2 Marteau-piqueur : 1")
	set({ "Fists", "AngleGrinder" }, "AngleGrinder")
	check(ToolService.GetDoorHits(P1) == 1, "D3 Angle Grinder : 1")
	set({ "Fists" }, "BatteringRam")
	check(ToolService.GetDoorHits(P1) == 1, "D4 Bélier équipé mais pas possédé : poings, 1")
	DATA[P1] = nil
	check(ToolService.GetDoorHits(P1) == 1, "D5 sans profil : 1")
	set({ "Fists", "BatteringRam" }, "BatteringRam")
	check(ToolService.GetHitDamage(P1) == Config.Tools.ById.AngleGrinder.Power, "D6 dégâts sur une vitrine : ceux de l'Angle Grinder")
elseif SCENARIO == "shop" then
	local real = loadService("ToolService", FAKES)
	local parent = setmetatable({
		FindFirstChild = function() return nil end,
		ToolService = real,
		PlotService = { GetPlot = function() return nil end },
		UnboxService = { Refresh = function() end },
	}, { __index = FAKES })
	local buy
	NET.Server.BuyItem = { Connect = function(_, fn) buy = fn end }
	NET.Server.EquipTool = { Connect = function() end }
	local d = newData()
	d.Cash = 10e9
	d.Tools = { Owned = { "Fists" }, Equipped = "Fists" }
	DATA[P1] = d
	local ShopService = loadService("ShopService", parent)
	ShopService.Init()
	local function lastText()
		local n = lastNote(P1)
		return if n then n[2] else ""
	end
	buy(P1, "Jackhammer")
	check(lastText() == "Reach Rebirth 5 to buy the Jackhammer.", `S1 sans attribut Rebirths : fermé ({lastText()})`)
	P1:SetAttribute("Rebirths", 4)
	buy(P1, "Jackhammer")
	check(lastText() == "Reach Rebirth 5 to buy the Jackhammer." and d.Cash == 10e9, `S2 4 renaissances : fermé, argent intact ({lastText()})`)
	buy(P1, "BatteringRam")
	check(lastText() == "Reach Rebirth 7 to buy the Battering Ram.", `S3 Bélier fermé à 4 ({lastText()})`)
	P1:SetAttribute("Rebirths", 5)
	buy(P1, "Jackhammer")
	check(lastText() == "Go to the Weapon Shop to buy tools.", `S4 5 renaissances : ouvert, la suite des contrôles d'avant ({lastText()})`)
	P1:SetAttribute("Rebirths", nil)
	buy(P1, "AngleGrinder")
	check(lastText() == "Go to the Weapon Shop to buy tools.", `S5 outil ordinaire : jamais fermé ({lastText()})`)
	check(d.Cash == 10e9 and #d.Tools.Owned == 1, "S6 rien acheté ni payé")
	check(string.find(P1:GetAttribute("OwnedTools") or "", "Fists", 1, true) ~= nil, "S7 OwnedTools publié")
else
	error("scénario inconnu : " .. tostring(SCENARIO))
end

print(`{checks} vérification(s), {fails} échec(s)`)
