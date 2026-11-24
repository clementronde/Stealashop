
---------------------------------------------------------------- a158 : plus de colis porté (NPCBox)
section("a158-1. Le colis porté fermé (NPCBox) n'existe plus")
clearLog()
local oldBox = { Kind = "NPCBox", Tier = "Premium", Zone = 1, Rarity = "Rare", ItemId = "Z1_PotDeNouilles", StoreId = "STORE_Z1_Superette", SlotId = "ShelfSlot_07" }
check(Carry.StartCarry(A, oldBox) == false, "StartCarry d'un payload NPCBox : refusé")
check(logCount("WARN", "Kind inconnu (NPCBox)") == 1, "refus signalé : Kind inconnu (NPCBox)")
check(not Carry.IsCarrying(A) and A:GetAttribute("Carrying") == nil and visualOf(charA) == nil, "aucun effet : rien sur la tête")
check(Carry.PlaceDrop == nil, "CarryService.PlaceDrop retiré (plus de colis posé au sol sans porteur)")
check(Workspace:FindFirstChild("CarryDrops") == nil, "aucun colis au sol")
check(#started == 0, "aucun OnCarryStarted")

section("a158-2. Objet sorti d'un colis (NPCItem) : porté comme avant")
clearLog()
local p1 = npc()
check(Carry.StartCarry(A, p1) == true, "StartCarry d'un objet NPCItem")
check(Carry.GetPayload(A) == p1 and A:GetAttribute("Carrying") == "Rare", "même table, attribut Carrying = rareté")
check(Stats.modifiers[A].Carry == Balance.Carry.NPCBoxSpeedMultiplier, "malus 0,9 (Balance.Carry.NPCBoxSpeedMultiplier garde son nom)")
local v1 = visualOf(charA)
local block = v1 and v1:FindFirstChild("Tint", true)
check(block ~= nil and block.Size == Vector3.new(1.2, 1.2, 1.2) and block.Color == Rarities.ById.Rare.Color, "bloc V0 d'un objet (1,2 stud), à la couleur de la rareté")
check(v1:FindFirstChild("BB_Carry", true) ~= nil and v1:FindFirstChild("BB_Box", true) == nil, "étiquette BB_Carry, jamais BB_Box sur la tête")
check(v1:HasTag("CarriedItem"), "tag CarriedItem (mutation de l'objet porté)")
check(logCount("WARN", "") == 0, "aucun avertissement")
local bad = {
	{ npc({ Luck = 0 }), "chance invalide" },
	{ npc({ Zone = 7 }), "zone inconnue" },
	{ npc({ StoreId = "" }), "StoreId ou SlotId manquant" },
	{ npc({ Rarity = "Epic" }), "est Rare, pas Epic" },
}
for _, case in bad do
	clearLog()
	check(Carry.StartCarry(B, case[1]) == false and logCount("WARN", case[2]) == 1, "refus : " .. case[2])
end
check(Carry.StartCarry(B, npc({ Zone = 2, SlotId = "autre" })) == true, "objet d'une zone voisine : permis (tirage de la sortie, vague 32)")
Carry.Consume(B)

section("a158-3. Attrapé : l'objet tombe ; lâché, ramassé, expiré")
check(Carry.Fail(A, "Caught") == true, "Fail « Caught » d'un objet : true")
local e = lastEnded()
check(e.player == A and e.result == "Dropped" and e.reason == "Caught" and e.payload == p1, "OnCarryEnded(…, Dropped, Caught)")
local folder = Workspace:FindFirstChild("CarryDrops")
local dropModel = folder and folder:GetChildren()[1]
check(dropModel ~= nil and dropModel:GetAttribute("BatDrop") == true and dropModel:GetAttribute("ItemId") == "Z1_PotDeNouilles", "au sol : attributs BatDrop et ItemId")
check(dropModel:GetAttribute("Tier") == nil, "plus d'attribut Tier (c'était celui du colis)")
local dropId = dropModel:GetAttribute("DropId")
check(Carry.IsFallenDrop(dropId) == true, "IsFallenDrop : tombé des mains d'un porteur")
check(Carry.PickUpDrop(A, dropId) == false, "le joueur attrapé ne le reprend pas tout de suite (étourdi)")
check(Carry.PickUpDrop(B, dropId) == true and Carry.GetPayload(B) == p1, "un autre joueur le ramasse : même payload")
local dropId2 = Carry.Drop(B, nil, "Released")
check(dropId2 ~= nil and lastEnded().result == "Dropped" and lastEnded().reason == "Released", "lâché (G) : Dropped, Released")
advance(Bat.DroppedLifetime + 0.2)
check(Carry.GetDrop(dropId2) == nil and #expired == 1 and expired[1].payload == p1, "pas ramassé : OnDropExpired au bout de Bat.DroppedLifetime")
check(Carry.StartCarry(A, p1) == true, "l'objet rendu peut être repris")
check(Carry.Fail(A, "Died") == true and lastEnded().result == "Failed", "autre échec : Failed (il revole vers son rayon)")

section("a158-4. Objet volé à un joueur : rien ne change")
local item = { Kind = "PlayerItem", ItemUid = "uid-1", ItemId = "Z3_Smartphone", Rarity = "Rare", Income = 12400, VictimUserId = 99, SlotIndex = 3 }
check(Carry.StartCarry(B, item), "portage d'un objet volé")
check(Stats.modifiers[B].Fixed == Balance.Carry.StolenItemWalkSpeed, "vitesse fixe")
check(Carry.Drop(B, Vector3.new(0, 0, 0)) == nil and lastEnded().result == "Failed" and lastEnded().reason == "Bat", "Drop d'un objet volé : Failed, Bat (il ne tombe pas)")

section("a158-5. Colis du rayon : AttachBoxLabel gardé")
local shelf = make("Model", { Name = "ShelfBox_01" }, Workspace)
local shelfBody = make("Part", { Name = "Body", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(0, 0.6, 50), Anchored = true, PivotOffset = CFrame.new(0, -0.6, 0) }, shelf)
shelf.PrimaryPart = shelfBody
local label = Carry.AttachBoxLabel(shelf, "Rare", nil)
check(label ~= nil and label.Name == "BB_Box", "BB_Box sur une caisse du rayon (rareté seule)")

print(string.format("scénario carry : %d vérification(s), %d échec(s)", CHECKS, FAILS))
if FAILS > 0 then
	print("Sortie des modules :")
	dumpLog()
end
