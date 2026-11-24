--!nocheck
-- O. OpenShelfBox : validations (9.4), tirage de la chance, attributs du contrat sur le colis, sortie
-- de l'objet à ShelfRevealAt, attributs et pose de l'objet sorti, rien de secret avant la sortie.

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
local LMID = lucks[2]
-- Une chance dont la montée dure assez pour faire les contrôles O3 et O4 avant la sortie (5 à 7 s).
local LBIG = LMAX
for _, l in lucks do
	if SOS.revealDelay(l) >= 5 and SOS.revealDelay(l) <= 7 then
		LBIG = l
	end
end

section("O1 magasin fermé, colis fermés")
check(boxCount(STORE_A) == 10 and itemCount(STORE_A) == 0, "O1a 10 colis fermés sur les rayons, aucun objet sorti")
-- Copie a109 (vague 32) : BoxRarity, la rareté de la caisse, est permise ; jamais ItemId, Rarity ni Mutation*.
local allowed = { SlotId = true, Slot = true, Tier = true, Landed = true, BoxRarity = true }
local leak = nil
for _, b in shelfBoxes(STORE_A) do
	for name in b:GetAttributes() do
		if not allowed[name] then
			leak = name
		end
	end
end
check(leak == nil, "O1b aucun attribut du contenu sur un colis fermé (" .. tostring(leak) .. ")")
local box1 = openBox(B, STORE_A, 1, LMID)
check(not isOpening(box1), "O1c magasin fermé : ouverture refusée")

section("O2 avance du casseur, lancement, attributs du colis")
breakStore(B, STORE_A)
check(STORE_A:GetAttribute("HeistOpen") == true, "O2a magasin ouvert")
local box2 = openBox(A, STORE_A, 2, LMID)
check(not isOpening(box2), "O2b pendant l'avance du casseur, un autre joueur n'ouvre pas")
box1 = openBox(B, STORE_A, 1, LBIG)
check(isOpening(box1), "O2c le casseur ouvre tout de suite")
local openAt = box1:GetAttribute("ShelfOpenAt")
check(box1:GetAttribute("ShelfOpenBy") == B.UserId, "O2d ShelfOpenBy = l'ouvreur")
check(type(openAt) == "number" and near(openAt, Workspace:GetServerTimeNow(), 0.3), "O2e ShelfOpenAt = heure du serveur du lancement")
check(box1:GetAttribute("ShelfLuck") == LBIG, "O2f ShelfLuck = la chance tirée (×" .. tostring(box1:GetAttribute("ShelfLuck")) .. ")")
check(near(box1:GetAttribute("ShelfRevealAt"), openAt + SOS.revealDelay(LBIG), 1e-6), "O2g ShelfRevealAt = ShelfOpenAt + revealDelay(chance)")
check(box1:GetAttribute("ItemId") == nil and box1:GetAttribute("Rarity") == nil, "O2h le contenu ne se lit pas sur le colis en cours d'ouverture")
check(itemCount(STORE_A) == 0, "O2i aucun objet sorti avant ShelfRevealAt")

section("O3 colis déjà en cours, prise d'un colis fermé")
advance(1.1) -- fin de l'avance du casseur
standAt(A, STORE_A, 1)
fireOpen(A, box1:GetAttribute("SlotId"))
fireOpen(B, box1:GetAttribute("SlotId"))
check(box1:GetAttribute("ShelfOpenAt") == openAt and box1:GetAttribute("ShelfOpenBy") == B.UserId, "O3a un colis en cours d'ouverture ne se relance pas")
local box3 = boxAt(STORE_A, 3)
standAt(A, STORE_A, 3)
fireAs(A, "GrabItem", box3:GetAttribute("SlotId"))
advance(1.1)
fireAs(A, "GrabItem", box3:GetAttribute("SlotId"))
flush()
check(not Carry.IsCarrying(A) and boxAt(STORE_A, 3) == box3, "O3b GrabItem sur un colis fermé : refusé, le colis reste")
standAt(A, STORE_A, 1)
fireAs(A, "GrabItem", box1:GetAttribute("SlotId"))
advance(0.4)
fireAs(A, "GrabItem", box1:GetAttribute("SlotId"))
flush()
check(not Carry.IsCarrying(A), "O3c GrabItem sur un colis en cours d'ouverture : refusé")

section("O4 portée, volume Bounds, emplacement inconnu")
standAt(A, STORE_A, 10) -- à 18 studs du rayon 1… et vise le rayon 2
fireOpen(A, box2:GetAttribute("SlotId"))
check(not isOpening(box2), "O4a à plus de GrabMaxDistance du rayon : refusé")
local p2 = slotAttachment(STORE_A, 2).WorldPosition
moveTo(A, Vector3.new(p2.X, 3, 28)) -- sur le trottoir, hors du volume Bounds
fireOpen(A, box2:GetAttribute("SlotId"))
check(not isOpening(box2), "O4b hors du volume Bounds : refusé")
fireOpen(A, "STORE_Z1_Superette/99")
fireOpen(A, "n'importe quoi")
check(logCount("tick :", "WARN", "server") == 0, "O4c emplacement inconnu : aucun effet, aucune erreur")

section("O5 sortie de l'objet à ShelfRevealAt")
-- L-118 point 4 (2026-11-13) : la montée dure 2 s au plus, le colis du rayon 1 est déjà sorti ; on suit
-- un colis neuf, ouvert ici (rayon 9).
box1 = openBox(B, STORE_A, 9, LBIG)
openAt = box1:GetAttribute("ShelfOpenAt")
local revealIn = box1:GetAttribute("ShelfRevealAt") - Workspace:GetServerTimeNow()
check(revealIn > 0.2, "O5 (banc) la sortie n'est pas encore passée")
local startRarity, startMutation = boxLabel(box1)
advance(revealIn - 0.07)
check(boxAt(STORE_A, 9) == box1 and itemAt(STORE_A, 9) == nil, "O5a juste avant ShelfRevealAt : toujours le colis")
table.insert(HEIST_FORCED, 0) -- copie a109 : tirage de la rareté de l'objet tout en bas, la plus basse de la table de la caisse
local tier1, slotId1 = box1:GetAttribute("Tier"), box1:GetAttribute("SlotId")
advance(0.14)
table.clear(HEIST_FORCED)
local item1 = itemAt(STORE_A, 9)
check(boxAt(STORE_A, 9) == nil and isDestroyed(box1), "O5b à ShelfRevealAt : le colis a disparu")
check(item1 ~= nil and item1.Name == "ShelfItem_09", "O5c l'objet sorti est à sa place (ShelfItem_09, tag ShelfItem)")
check(cfClose(item1:GetPivot(), slotAttachment(STORE_A, 9).WorldCFrame, 1e-3), "O5d pivot posé sur le ShelfSlot, tourné comme lui")
check(item1:GetAttribute("SlotId") == slotId1 and item1:GetAttribute("Slot") == "ShelfSlot_09", "O5e SlotId et Slot du colis d'origine")
check(item1:GetAttribute("Tier") == tier1, "O5f Tier du colis d'origine (temps de prise)")
local def = Items.ById[item1:GetAttribute("ItemId")]
check(def ~= nil and def.Rarity == item1:GetAttribute("Rarity") and not def.TutorialOnly, "O5g ItemId connu, de la rareté annoncée, pas un objet du tuto")
-- Copie a109 (vague 32) : rareté de l'objet tirée à la sortie dans la table de la caisse (0 = la plus basse).
local lowest1 = nil
for _, r in Rarities.List do
	if lowest1 == nil and (SO.BoxRarityOdds[startRarity][r.Id] or 0) > 0 then
		lowest1 = r.Id
	end
end
check(box1:GetAttribute("BoxRarity") == startRarity, "O5h (banc) BoxRarity = la rareté de l'étiquette (" .. tostring(startRarity) .. ")")
check(item1:GetAttribute("Rarity") == lowest1, "O5h tirage tout en bas : la plus basse de la table de la caisse (" .. tostring(lowest1) .. ")")
check(startMutation == nil, "O5i aucune mutation sur l'étiquette de la caisse (tirée à la sortie)")
local income = Formulas.ItemIncome(def.Zone or 1, def.Rarity) * Mutations.IncomeMultiplier({ Size = item1:GetAttribute("MutationSize"), Effect = item1:GetAttribute("MutationEffect") })
check(near(item1:GetAttribute("Income"), income, 1e-6), "O5j Income = revenu de l'objet, mutation comprise")
check(item1:GetAttribute("ShelfLuck") == LBIG, "O5k ShelfLuck recopiée")
check(item1:GetAttribute("ShelfReservedBy") == B.UserId, "O5l ShelfReservedBy = l'ouvreur")
check(near(item1:GetAttribute("ShelfReservedUntil"), openAt + SOS.revealDelay(LBIG) + SO.ReserveTime, 0.05), "O5m ShelfReservedUntil = sortie + ReserveTime")
check(item1:GetAttribute("Landed") == true, "O5n Landed")
local solid, scripts = false, 0
for _, d in item1:GetDescendants() do
	if d:IsA("BasePart") and (d.Anchored ~= true or d.CanCollide ~= false) then
		solid = true
	end
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
check(not solid and scripts == 0, "O5o pièces ancrées, sans collision, aucun script")
check(item1.Parent == STORE_A:FindFirstChild("ShelfBoxes"), "O5p rangé dans le dossier ShelfBoxes du magasin")

section("O6 tirée à ×1 : l'objet sort juste après les rabats")
local box4 = openBox(C, STORE_A, 4, LMIN)
check(isOpening(box4) and box4:GetAttribute("ShelfLuck") == LMIN, "O6a ouverture à ×" .. LMIN)
check(near(box4:GetAttribute("ShelfRevealAt") - box4:GetAttribute("ShelfOpenAt"), SO.FlapsTime + SOS.riseTime(LMIN), 1e-6), "O6b délai = rabats + montée")
advance(SOS.revealDelay(LMIN) - 0.05)
check(itemAt(STORE_A, 4) == nil, "O6c pas avant la fin des rabats")
advance(0.1)
check(itemAt(STORE_A, 4) ~= nil and boxAt(STORE_A, 4) == nil, "O6d sorti juste après")

section("O7 bornes du tirage (table de Config/ShelfOpen)")
advance(16) -- fin du chrono et des réservations
-- L-118 : le magasin reste ouvert tant que des joueurs y sont (et le vigile a pu sortir Bob) : vitrine neuve.
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(B, STORE_A)
local total = 0
for _, e in SO.LuckTable do
	total += e.Weight
end
local first, second, last = SO.LuckTable[1], SO.LuckTable[2], SO.LuckTable[#SO.LuckTable]
local function drawWith(p, slot, value)
	standAt(p, STORE_A, slot)
	local box = boxAt(STORE_A, slot)
	table.insert(HEIST_FORCED, value)
	fireOpen(p, box:GetAttribute("SlotId"))
	table.clear(HEIST_FORCED)
	return box:GetAttribute("ShelfLuck")
end
check(drawWith(B, 5, first.Weight / total - 1e-6) == first.Luck, "O7a juste sous le premier poids : ×" .. first.Luck)
check(drawWith(B, 6, first.Weight / total + 1e-6) == second.Luck, "O7b juste au-dessus : ×" .. second.Luck)
check(drawWith(B, 7, 1 - 1e-9) == last.Luck, "O7c tout en haut : ×" .. last.Luck)
check(drawWith(B, 8, 0) == first.Luck, "O7d tout en bas : ×" .. first.Luck)

section("O8 débit du remote")
advance(25) -- fin du chrono, ouvertures finies, réservations passées
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
Heist.RefillAll()
flush()
check(boxCount(STORE_A) == 10 and itemCount(STORE_A) == 0, "O8a remplissage : 10 colis fermés, plus aucun objet sorti")
breakStore(B, STORE_A)
standAt(B, STORE_A, 5)
local rate = sharedModule("Net/Definitions")
local limit = nil
for _, d in rate.List do
	if d.Name == "OpenShelfBox" then
		limit = d.RatePerSecond
	end
end
check(type(limit) == "number" and limit > 0, "O8b OpenShelfBox a un débit limité (" .. tostring(limit) .. "/s)")
-- a116 (Cantin, 2026-11-13) : un appel seul ne fait que commencer le maintien, il ne lance rien.
for n = 1, 10 do
	standAt(B, STORE_A, n)
	fireAs(B, "OpenShelfBox", boxAt(STORE_A, n):GetAttribute("SlotId"))
end
flush()
local started = 0
for _, b in shelfBoxes(STORE_A) do
	if isOpening(b) then
		started += 1
	end
end
check(started == 0, "O8c a116 : 10 appels dans le même instant, un par colis : " .. started .. " ouverture lancée (un appel seul ne lance rien)")

section("O9 répartition du tirage (sans valeur forcée)")
advance(25)
local counts, draws, unknown = {}, 0, 0
local known = {}
for _, e in SO.LuckTable do
	known[e.Luck] = true
end
for round = 1, 4 do
	WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
	flush()
	Heist.RefillAll()
	flush()
	breakStore(B, STORE_A)
	for n = 1, 10 do
		local box = openBox(B, STORE_A, n)
		local luck = box:GetAttribute("ShelfLuck")
		if isOpening(box) then
			draws += 1
			counts[luck] = (counts[luck] or 0) + 1
			if not known[luck] then
				unknown += 1
			end
		end
	end
	advance(25)
end
local share = (counts[first.Luck] or 0) / math.max(draws, 1)
local expected = first.Weight / total
check(draws == 40 and unknown == 0, "O9a 40 tirages, tous dans la table (" .. draws .. ")")
check(math.abs(share - expected) < 0.3, string.format("O9b part de ×%s : %.2f pour %.2f attendu", tostring(first.Luck), share, expected))
check(logCount("tick :", "WARN", "server") == 0, "O9c aucune erreur du tick")

summary("scénario open")
