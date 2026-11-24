--!nocheck
-- Scénario « effects » : chaque effet codé des gamepasses et le bonus Premium, par les points
-- d'accroche des services ; aucun effet pour un joueur qui n'a rien acheté.
--   ×2 Argent (Income doublé, caisse 2 fois plus vite, valeur exposée inchangée), Premium (+10 %,
--   cumulé : ×2,2), ×2 Entraînement (banc et tapis), Encaissement auto (caisse vidée chaque seconde,
--   source « Auto », sans ligne dans la sortie), Ouverture rapide (attente ÷ 2, colis du tuto à 5 s
--   exactes, achat pendant une attente), +4 présentoirs (DisplaySlot_21 à _24 posés : débloqués,
--   remplis après ceux de base ; boutique sans présentoir bonus : rien ; cache à l'arrivée).

startServer()

-- Premier objet du catalogue de cette rareté (hors objet du tuto), et sa zone.
local function itemOf(rarity)
	for zone = 1, 6 do
		local list = Items.ByZone[zone] and Items.ByZone[zone][rarity]
		for _, item in list or {} do
			if item.Id ~= Tutorial.GuaranteedItemId then
				return item.Id, zone
			end
		end
	end
	error("pas d'objet " .. rarity)
end
local function withItems(data, count)
	for index = 1, count do
		addItem(data, `e-{index}`, "Z3_Smartphone", index, 3)
	end
	return data
end
-- Copie a46 (L-086) : les colis de Bob et de Cid se posent sur les présentoirs 1 à 4 ; leurs objets vont sur
-- les présentoirs 5 à 7 (3 présentoirs achetés).
local function withItemsHigh(data, count)
	data.Upgrades.DisplaySlots = count
	for index = 1, count do
		addItem(data, `e-{index}`, "Z3_Smartphone", index + 4, 3)
	end
	return data
end
local cashOuts = {}
DisplayService.OnCashOut(function(player, amount, source)
	table.insert(cashOuts, { player = player, amount = amount, source = source })
end)

-- Possession chez Roblox (UserId 1 à 4 dans l'ordre des arrivées).
MARKET.owns[1] = { [PASS_IDS.DoubleCash] = true, [PASS_IDS.ExtraStands] = true } -- Ada, boutique 1 (présentoirs bonus)
MARKET.owns[2] = { [PASS_IDS.DoubleTraining] = true, [PASS_IDS.AutoCollect] = true, [PASS_IDS.FastOpen] = true } -- Bob, boutique 2
-- Cid (3), boutique 3 : rien acheté. Dan (4), boutique 4 : +4 présentoirs, sans présentoir bonus posé.
MARKET.owns[4] = { [PASS_IDS.ExtraStands] = true }

local ada = join("Ada", withItems(newProfile(), 3))
local bob = join("Bob", withItemsHigh(newProfile(), 3))
local cid = join("Cid", withItemsHigh(newProfile(), 3))
local dan = join("Dan", newProfile())
advance(2)

section("aucun effet sans achat (Cid)")
local cidExposed = cid:GetAttribute("ExposedIncome")
check(cidExposed > 0 and cid:GetAttribute("Income") == cidExposed, `Income = valeur exposée ({cidExposed} $/s)`)
check(cid:GetAttribute("DisplaySlotsUnlocked") == 7, "7 présentoirs (copie a46 : 3 achetés)")
check(MonetizationService.GetIncomeMultiplier(cid) == 1, "M global de la boutique = 1")
local cidCash = cashOf(cid)
advance(3)
check(cashOf(cid) == cidCash, "pas d'encaissement automatique")
local rareId, rareZone = itemOf("Rare")
local cidBox = placeBox(cid, 1, "Rare", rareId, "Premium", rareZone)
check(cidBox ~= nil and near(cidBox.ReadyAt - serverTime(), 45, 0.05), "attente normale (Rare : 45 s)")
for _, name in { "PassDoubleCash", "PassDoubleTraining", "PassAutoCollect", "PassFastOpen", "PassExtraStands" } do
	check(cid:GetAttribute(name) == nil, `pas d'attribut {name}`)
end

section("×2 Argent")
local exposed = ada:GetAttribute("ExposedIncome")
check(exposed == cidExposed and ada:GetAttribute("Income") == 2 * exposed, `Income = 2 × {exposed} ; valeur exposée inchangée (anti-racket)`)
check(DisplayService.GetIncome(ada) == exposed, "DisplayService.GetIncome : valeur exposée, sans bonus")
local register0 = DisplayService.GetRegister(ada)
local cidRegister0 = DisplayService.GetRegister(cid)
advance(10)
local adaGain = DisplayService.GetRegister(ada) - register0
local cidGain = DisplayService.GetRegister(cid) - cidRegister0
check(near(adaGain, 2 * cidGain, 2), `caisse : {adaGain} $ en 10 s, contre {cidGain} $ sans gamepass`)

section("Roblox Premium")
cid.MembershipType = Enum.MembershipType.Premium
advance(1.1)
check(near(cid:GetAttribute("Income"), 1.1 * cidExposed, 1e-6), "Premium : +10 % de revenus")
ada.MembershipType = Enum.MembershipType.Premium
advance(1.1)
check(near(ada:GetAttribute("Income"), 2.2 * exposed, 1e-6), "Premium et ×2 Argent : × 2,2 (les % s'additionnent, les ×2 se multiplient)")
cid.MembershipType = Enum.MembershipType.None
advance(1.1)
check(cid:GetAttribute("Income") == cidExposed, "plus Premium : revenus normaux")

section("×2 Entraînement")
local function benchRep(player)
	local S = refsOfShop(shopOf(player))
	-- a65 (L-093) : plus d'invite au banc, on y monte en entrant dans sa zone.
	moveTo(player, S.bench + Vector3.new(0, 2, 0))
	advance(0.6)
	local before = dataOf(player).Stats.Strength
	fireAs(player, "TrainTap")
	flush()
	local gain = dataOf(player).Stats.Strength - before
	moveTo(player, S.bench + Vector3.new(0, 2, 10)) -- descend (a65 : éloigné du banc, puis hors de sa zone)
	advance(0.6)
	return gain
end
local bobRep = benchRep(bob)
local cidRep = benchRep(cid)
check(cidRep == Training.Bench.GainPerRep, `sans gamepass : +{cidRep} Force par répétition`)
check(bobRep == 2 * Training.Bench.GainPerRep, `×2 Entraînement : +{bobRep} Force par répétition`)
-- a41 (2026-11-08, L-071) : le tapis n'a plus d'invite ; on s'arrête dessus (la séance part en
-- 0,3 s environ), puis on en descend.
local function treadmillSecond(player)
	local S = refsOfShop(shopOf(player))
	moveTo(player, S.treadmill + Vector3.new(0, 2, 0))
	advance(0.6)
	check(player:GetAttribute("TrainingMachine") == "Treadmill", `{player.Name} arrêté sur son tapis : à l'entraînement, sans invite`)
	local before = dataOf(player).Stats.Speed
	advance(3.05)
	local gain = dataOf(player).Stats.Speed - before
	moveTo(player, S.treadmill + Vector3.new(6, 2, 0)) -- descend
	advance(0.6)
	return gain
end
local bobRun = treadmillSecond(bob)
local cidRun = treadmillSecond(cid)
check(cidRun > 0 and near(bobRun, 2 * cidRun, 1e-6), `tapis : +{bobRun} Vitesse en 3 s, contre +{cidRun}`)

section("Encaissement auto")
moveTo(bob, Vector3.new(-200, 3, -200)) -- loin de sa boutique
table.clear(cashOuts)
clearLog()
local bobCash = cashOf(bob)
advance(5)
local auto = 0
local other = 0
for _, e in cashOuts do
	if e.player == bob then
		if e.source == "Auto" then
			auto += e.amount
		else
			other += 1
		end
	end
end
check(cashOf(bob) > bobCash and cashOf(bob) - bobCash == auto, `+{cashOf(bob) - bobCash} $ en 5 s, loin de la boutique, source « Auto »`)
check(other == 0 and DisplayService.GetRegister(bob) <= bob:GetAttribute("Income") + 1, "caisse vidée chaque seconde")
check(not logHas("Bob encaisse", "PRINT", "server"), "aucune ligne « encaisse » dans la sortie")
check(#cashOuts > 0 and not (function()
	for _, e in cashOuts do
		if e.player ~= bob then
			return true
		end
	end
	return false
end)(), "les autres joueurs n'encaissent pas tout seuls")

section("Ouverture rapide")
moveTo(bob, refsOfShop(shopOf(bob)).center)
local epic, epicZone = itemOf("Epic")
local bobBox = placeBox(bob, 1, "Epic", epic, "Premium", epicZone)
check(bobBox ~= nil and near(bobBox.ReadyAt - serverTime(), Rarities.ById.Epic.OpenDelay / 2, 0.05), `attente divisée par 2 : {bobBox and string.format("%.1f", bobBox.ReadyAt - serverTime())} s pour un Épique (90 s)`)
TUTORIAL_ACTIVE[bob] = true
local tutoBox = placeBox(bob, 2, "Rare", Tutorial.GuaranteedItemId, "Premium", 1)
check(tutoBox ~= nil and near(tutoBox.ReadyAt - serverTime(), Tutorial.OpenDelay, 0.05), "colis garanti du tuto : 5 s exactes (l'accroche du tuto passe par-dessus)")
TUTORIAL_ACTIVE[bob] = nil
-- Achat pendant une attente : l'attente restante des colis déjà posés est divisée par 2.
local mythic, mythicZone = itemOf("Mythic")
local legendary, legendaryZone = itemOf("Legendary")
local cidLong = placeBox(cid, 2, "Mythic", mythic, "Luxe", mythicZone)
local cidLegend = placeBox(cid, 3, "Legendary", legendary, "Luxe", legendaryZone)
advance(20)
local before = cidLong.ReadyAt - serverTime()
local legendBefore = cidLegend.ReadyAt - serverTime()
local readyBefore = slotBox(cid, 1).ReadyAt -- le Rare du début, déjà prêt
finishPassPurchase(cid, PASS_IDS.FastOpen, true)
local after = slotBox(cid, 2).ReadyAt - serverTime()
check(near(after, before / 2, 0.05), `colis Mythique en attente : {string.format("%.0f", before)} s → {string.format("%.0f", after)} s`)
check(near(slotBox(cid, 3).ReadyAt - serverTime(), legendBefore / 2, 0.05), "le colis Légendaire en attente aussi")
check(slotBox(cid, 1).ReadyAt == readyBefore, "un colis déjà prêt n'est pas touché")
check(#notifies(cid, "Fast Open: anti-theft 2× shorter!") == 1, "Notify")
local model = floorBoxN(cid, 2) -- a51 : le colis posé au sol n° 2
check(model ~= nil and model:GetAttribute("ReadyAt") == slotBox(cid, 2).ReadyAt, "le colis sur l'établi suit (attribut ReadyAt)")
local cidNext = placeBox(cid, 4, "Epic", epic, "Premium", epicZone)
check(near(cidNext.ReadyAt - serverTime(), 45, 0.05), "colis suivant : 45 s au lieu de 90")

section("+4 présentoirs")
check(ada:GetAttribute("DisplaySlotsUnlocked") == 8, "boutique 1 (présentoirs bonus posés) : 4 + 4 = 8 présentoirs")
local adaData = dataOf(ada)
local placed = {}
for index = 1, 6 do
	local uid = `x-{index}`
	adaData.Items[uid] = { Id = "Z1_CanetteDeSoda", Source = "NPC", At = 0, Zone = 1 }
	placed[index] = DisplayService.PlaceAuto(ada, uid)
end
local got = {}
for index = 1, 5 do
	got[placed[index] or 0] = true
end
check(got[4] and got[21] and got[22] and got[23] and got[24], `5 objets : le présentoir de base libre (4) et les présentoirs bonus 21 à 24 ({tostring(placed[1])}, {tostring(placed[2])}, {tostring(placed[3])}, {tostring(placed[4])}, {tostring(placed[5])})`)
check(placed[6] == nil, "le 9e objet n'a plus de présentoir : inventaire")
local bonusUid = adaData.Display["21"]
check(bonusUid ~= nil and shopOf(ada).DisplayItems:FindFirstChild("DisplayItem_21") ~= nil, "objet exposé sur le présentoir 21 (affiché)")
local function bonusCount(data)
	local n = 0
	for key in data.Display do
		if tonumber(key) >= 21 then
			n += 1
		end
	end
	return n
end
check(bonusCount(adaData) == 4, "4 objets sur les présentoirs bonus")
check(DisplayService.HasRoom(ada), "encore de la place dans l'inventaire")
check(dan:GetAttribute("PassExtraStands") == true and dan:GetAttribute("DisplaySlotsUnlocked") == 4, "boutique 4 sans présentoir bonus posé : gamepass sans effet (4)")
local danData = dataOf(dan)
danData.Items["dz"] = { Id = "Z1_Banane", Source = "NPC", At = 0, Zone = 1 }
local ok, why = DisplayService.PlaceItem(dan, "dz", 21)
check(not ok and why == "NoSlot", `présentoir 21 absent : refusé (NoSlot, trouvé {tostring(why)})`)
local bok, bwhy = DisplayService.PlaceItem(bob, "e-1", 21)
check(not bok and bwhy == "Locked", `Bob, présentoirs bonus posés mais sans le gamepass : 21 verrouillé ({tostring(bwhy)})`)

section("+4 présentoirs : cache à l'arrivée, Roblox lent")
leave(ada)
MARKET.ownsDelay = 5
local back = join("Ada", nil, 1)
check(bonusCount(dataOf(back)) == 4 and dataOf(back).Display["21"] == bonusUid, "retour : les objets des présentoirs bonus restent exposés pendant que Roblox répond")
check(back:GetAttribute("DisplaySlotsUnlocked") == 8 and back:GetAttribute("Income") > 0, "8 présentoirs et revenus tout de suite")
MARKET.owns[1][PASS_IDS.ExtraStands] = nil -- remboursé entre-temps
advance(40)
check(back:GetAttribute("PassExtraStands") == nil and back:GetAttribute("DisplaySlotsUnlocked") == 4, "Roblox répond « pas possédé » : 4 présentoirs")
check(bonusCount(dataOf(back)) == 0 and dataOf(back).Items[bonusUid] ~= nil, "les objets des présentoirs bonus retournent dans l'inventaire")
MARKET.ownsDelay = 0.1

summary("scénario effects")
