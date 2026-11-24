--!nocheck
-- R. Objet sorti : réservé ShelfOpen.ReserveTime s à l'ouvreur, puis à tout joueur dans le magasin ;
-- prise par GrabItem (maintien du type du colis d'origine) ; portage NPCItem (objet sur la tête,
-- BB_Carry, pas de contour rouge) ; le vigile du magasin part à la prise ; magasin fermé pour le voleur.

startAll()
local Format = sharedModule("Format")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local LMIN = luckValues()[1]
local function waitNoGuard(maxSeconds)
	local t = 0
	while #guards() > 0 and t < maxSeconds do
		advance(0.5)
		t += 0.5
	end
	return #guards() == 0
end
-- Ouvre le colis du rayon `n` à ×LMIN et attend la sortie (crans ratés). Renvoie l'objet sorti.
local function reveal(p, n)
	local item = openAndReveal(p, STORE_A, n, LMIN, { 1 })
	assert(item, "objet pas sorti (rayon " .. n .. ")")
	return item
end

section("R1 réservé à l'ouvreur, puis à tous")
breakStore(A, STORE_A)
advance(1.1)
local item1 = reveal(A, 1)
local reservedUntil = item1:GetAttribute("ShelfReservedUntil")
check(not takeItem(B, STORE_A, 1), "R1a avant ShelfReservedUntil : un autre joueur ne le prend pas")
check(itemAt(STORE_A, 1) == item1, "R1b l'objet reste sur son rayon")
advance(reservedUntil - Workspace:GetServerTimeNow() - 0.6)
check(not takeItem(B, STORE_A, 1), "R1c toujours réservé 0,2 s avant la fin (maintien compris)")
advance(reservedUntil - Workspace:GetServerTimeNow() + 0.05)
local itemId, rarityId = item1:GetAttribute("ItemId"), item1:GetAttribute("Rarity")
local mutation = Mutations.Sanitize({ Size = item1:GetAttribute("MutationSize"), Effect = item1:GetAttribute("MutationEffect") })
local income, tier1 = item1:GetAttribute("Income"), item1:GetAttribute("Tier")
check(takeItem(B, STORE_A, 1), "R1d après ShelfReservedUntil : tout joueur dans le magasin le prend")

section("R2 portage NPCItem")
local payload = Carry.GetPayload(B)
check(payload ~= nil and payload.Kind == "NPCItem", "R2a payload NPCItem")
check(payload.ItemId == itemId and payload.Rarity == rarityId, "R2b objet et rareté de l'objet sorti")
check(payload.Zone == 1 and payload.StoreId == STORE_A.Name and payload.SlotId == STORE_A.Name .. "/01", "R2c zone, magasin et rayon d'origine")
check(payload.Luck == LMIN, "R2d chance de l'ouverture")
check((payload.Mutation == nil) == (mutation == nil) and (mutation == nil or (payload.Mutation.Size == mutation.Size and payload.Mutation.Effect == mutation.Effect)), "R2e mutation de l'objet sorti")
check(isDestroyed(item1) and itemAt(STORE_A, 1) == nil and boxAt(STORE_A, 1) == nil, "R2f le rayon est vide")
check(B:GetAttribute("Carrying") == rarityId, "R2g attribut Carrying = la rareté")
local visual = B.Character:FindFirstChild("CarryVisual")
check(visual ~= nil and visual:IsA("Model"), "R2h l'objet est sur la tête (CarryVisual)")
local label = visual and visual:FindFirstChild("BB_Carry", true)
check(label ~= nil, "R2i étiquette BB_Carry (pas BB_Box)")
check(label ~= nil and label:FindFirstChild("ItemName").Text == Mutations.ItemName(Items.ById[itemId].DisplayName, mutation), "R2j ItemName : nom de l'objet, mutation devant")
check(label ~= nil and label:FindFirstChild("Rarity").Text == Rarities.ById[rarityId].DisplayNameUpper, "R2k Rarity")
check(label ~= nil and label:FindFirstChild("Income").Text == Format.income(income), "R2l Income = celui de l'objet sorti (" .. Format.income(income) .. ")")
check(visual ~= nil and visual:FindFirstChild("StolenOutline", true) == nil, "R2m pas de contour rouge (réservé aux objets volés à un joueur)")
check(visual ~= nil and visual:FindFirstChild("BB_Box", true) == nil, "R2n pas d'étiquette de colis")
check(humanoidOf(B).WalkSpeed < 16 and near(humanoidOf(B).WalkSpeed, 16 * Balance.Carry.NPCBoxSpeedMultiplier, 0.2), "R2o malus de portage du colis PNJ (" .. humanoidOf(B).WalkSpeed .. ")")

-- Règle de Clément (L-118 points 8 et 9, 2026-11-13) : plus de vigile à la prise (il sort à la fin du
-- chrono) ; on n'est jamais sorti du magasin ; c'est en sortant qu'il se ferme pour soi.
-- a114 (Cantin, 2026-11-13) : la prise d'un objet sorti fait de nouveau sortir un vigile, tout de suite.
section("R3 un vigile à la prise, magasin fermé pour le voleur quand il sort")
advance(0.3)
check(guardFor(B) ~= nil, "R3a a114 : un vigile sort à la prise de l'objet")
local box2 = boxAt(STORE_A, 2)
standAt(B, STORE_A, 2)
fireOpen(B, box2:GetAttribute("SlotId"))
check(not isOpening(box2), "R3c mains pleines : pas d'ouverture")
Carry.Consume(B) -- rangé (UnboxService le fera à l'entrée de la zone safe)
flush()
standAt(B, STORE_A, 2)
local stay = rootOf(B).Position
fireOpen(B, box2:GetAttribute("SlotId"))
check(isOpening(box2), "R3d toujours dans le magasin, mains vides : il ouvre encore")
advance(0.3)
check((rootOf(B).Position - stay).Magnitude < 1, "R3e personne n'est sorti du magasin")
moveTo(B, Vector3.new(stay.X, 3, 28)) -- sur le trottoir, hors du volume Bounds
advance(0.3)
local closed = B:GetAttribute("ClosedStores")
check(type(closed) == "string" and string.find(closed, STORE_A.Name, 1, true) ~= nil, "R3g sorti : magasin fermé pour lui (ClosedStores)")
standAt(B, STORE_A, 3)
advance(0.3)
check(not (rootOf(B).Position.Z > 32), "R3h il revient : sorti devant la vitrine (z " .. math.round(rootOf(B).Position.Z) .. ")")
check(itemAt(STORE_A, 1) == nil and boxAt(STORE_A, 1) == nil, "R3f objet rangé : il ne revient pas sur son rayon")

section("R4 l'ouvreur d'abord, maintien, portée")
advance(12)
check(waitNoGuard(60), "R4 (banc) plus de vigile")
reopen(A, STORE_A)
local item3 = reveal(A, 3)
local grabTime = Balance.Heist.BoxTiers[item3:GetAttribute("Tier")].GrabTime
if grabTime > 0.2 then
	check(not takeItem(A, STORE_A, 3, 0.02), "R4a maintien trop court : refusé")
	advance(1.2) -- le maintien ouvert expire
end
standAt(A, STORE_A, 10)
fireAs(A, "GrabItem", item3:GetAttribute("SlotId"))
advance(grabTime + 0.05)
fireAs(A, "GrabItem", item3:GetAttribute("SlotId"))
flush()
check(not Carry.IsCarrying(A), "R4b trop loin du rayon : refusé")
advance(1.2)
check(takeItem(A, STORE_A, 3), "R4c l'ouvreur prend son objet pendant la réservation")
check(Carry.GetPayload(A).Kind == "NPCItem" and Carry.GetPayload(A).SlotId == STORE_A.Name .. "/03", "R4d portage NPCItem du rayon 3")
-- Un objet déjà sorti, pendant qu'il porte : refusé (mains pleines).
Carry.Consume(A)
flush()
check(logCount("tick :", "WARN", "server") == 0, "R5 aucune erreur du tick")

summary("scénario reserve")
