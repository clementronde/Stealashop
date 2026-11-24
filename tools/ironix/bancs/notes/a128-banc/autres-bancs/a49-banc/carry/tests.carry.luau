--!nocheck
-- Scénario « carry » (a49, DEV-131) : à la suite du banc a17-carry (copie d'a22, sans son bilan), le
-- vrai CarryService avec les BB_Box et BB_Carry de Clément de sa section 6 : la mutation du payload sur
-- BB_Box (colis porté et colis du rayon, AttachBoxLabel), le nom précédé de la mutation sur BB_Carry
-- (ou un texte Mutation s'il existe), payload à mutation invalide refusé.

-- Contrôles d'a17-carry comptés à part : ce scénario ne compte que les siens (un échec là-bas compte aussi).
local checks0 = CHECKS
print(string.format("  (a17-carry avant a49 : %d vérification(s), %d échec(s))", CHECKS, FAILS))
section("a49. Mutations sur les étiquettes")
local D = newPlayer("Dora")
local charD = spawnCharacter(D, 40)
check(Carry.StartCarry(D, npc({ Mutation = { Size = "Big", Effect = "Gold" } })), "portage d'un colis muté Big Gold")
local gD = visualOf(charD):FindFirstChild("BB_Box", true)
local mD = gD and gD:FindFirstChild("Mutation", true)
check(mD ~= nil and mD.Visible == true and mD.Text == "BIG · GOLD", `BB_Box porté : Mutation « BIG · GOLD » visible ({mD and mD.Text})`)
local leaked = false
for _, d in visualOf(charD):GetDescendants() do
	if d:IsA("TextLabel") and string.find(d.Text, "Noodles", 1, true) then
		leaked = true
	end
end
check(not leaked, "toujours ni nom ni ItemId sur le colis porté")
Carry.Consume(D)
check(Carry.StartCarry(D, npc({ Mutation = { Effect = "Rainbow" } })), "colis Rainbow seul")
local mR = visualOf(charD):FindFirstChild("BB_Box", true):FindFirstChild("Mutation", true)
check(mR.Text == "RAINBOW" and mR.Visible, "BB_Box : « RAINBOW »")
Carry.Consume(D)
check(Carry.StartCarry(D, npc({})), "colis sans mutation")
check(visualOf(charD):FindFirstChild("BB_Box", true):FindFirstChild("Mutation", true).Visible == false, "sans mutation : Mutation cachée")
Carry.Consume(D)
clearLog()
check(Carry.StartCarry(D, npc({ Mutation = { Size = "Mega" } })) == false, "mutation inconnue dans le payload : portage refusé (bogue du service appelant)")
check(Carry.StartCarry(D, npc({ Mutation = "Gold" })) == false, "mutation qui n'est pas une table : refusé")
check(logCount("WARN", "mutation invalide") >= 1, "refus signalé (« mutation invalide »)")

section("a49. Colis du rayon : AttachBoxLabel(model, rareté, objet, mutation)")
local shelf = make("Model", { Name = "ShelfBox_01" }, Workspace)
local sp = make("Part", { Name = "Block", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0.5, 80), Anchored = true }, shelf)
shelf.PrimaryPart = sp
local s1 = Carry.AttachBoxLabel(shelf, "Common", "Z1_CanetteDeSoda", { Size = "Huge", Effect = "Diamond" })
local sm = s1 and s1:FindFirstChild("Mutation", true)
check(sm ~= nil and sm.Visible and sm.Text == "HUGE · DIAMOND", `rayon : « HUGE · DIAMOND » ({sm and sm.Text})`)
local shelf2 = make("Model", { Name = "ShelfBox_02" }, Workspace)
local sp2 = make("Part", { Name = "Block", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(3, 0.5, 80), Anchored = true }, shelf2)
shelf2.PrimaryPart = sp2
local s2 = Carry.AttachBoxLabel(shelf2, "Common", "Z1_CanetteDeSoda")
check(s2 ~= nil and s2:FindFirstChild("Mutation", true).Visible == false, "rayon sans mutation (3 arguments, comme avant) : Mutation cachée")
local shelf3 = make("Model", { Name = "ShelfBox_03" }, Workspace)
local sp3 = make("Part", { Name = "Block", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(6, 0.5, 80), Anchored = true }, shelf3)
shelf3.PrimaryPart = sp3
local s3 = Carry.AttachBoxLabel(shelf3, "Common", "Z1_CanetteDeSoda", { Size = "Mega", Effect = "Neon" })
check(s3 ~= nil and s3:FindFirstChild("Mutation", true).Text == "NEON", "rayon : Id inconnu ignoré (« NEON »)")

section("a49. Objet volé muté : BB_Carry")
local E = newPlayer("Eli")
local charE = spawnCharacter(E, 60)
local stolen = { Kind = "PlayerItem", ItemUid = "uid-m1", ItemId = "Z3_Smartphone", Rarity = "Rare", Income = 1000, VictimUserId = 98, SlotIndex = 2, Mutation = { Size = "Big", Effect = "Gold" } }
check(Carry.StartCarry(E, stolen), "portage d'un objet volé Big Gold")
local gE = visualOf(charE):FindFirstChild("BB_Carry", true)
check(gE:FindFirstChild("ItemName", true).Text == "Big Gold Smartphone", `BB_Carry sans champ Mutation : « Big Gold Smartphone » ({gE:FindFirstChild("ItemName", true).Text})`)
check(gE:FindFirstChild("Income", true).Text == "+$1K/s", "revenu du payload (mutation déjà comprise par le serveur)")
Carry.Fail(E, "Caught")
-- Clément ajoute un texte Mutation à BB_Carry (nom proposé) : la mutation y va, ItemName garde le nom seul.
make("TextLabel", { Name = "Mutation", Text = "X", Visible = false }, bb.Card)
local stolen2 = table.clone(stolen)
stolen2.ItemUid = "uid-m2"
check(Carry.StartCarry(E, stolen2), "même objet, BB_Carry avec un texte Mutation")
local gE2 = visualOf(charE):FindFirstChild("BB_Carry", true)
local mE2 = gE2:FindFirstChild("Mutation", true)
check(gE2:FindFirstChild("ItemName", true).Text == "Smartphone" and mE2.Text == "BIG · GOLD" and mE2.Visible, "texte Mutation « BIG · GOLD », ItemName = nom seul")
Carry.Fail(E, "Caught")
local stolen3 = table.clone(stolen)
stolen3.ItemUid = "uid-m3"
stolen3.Mutation = nil
check(Carry.StartCarry(E, stolen3), "objet volé sans mutation")
check(visualOf(charE):FindFirstChild("BB_Carry", true):FindFirstChild("Mutation", true).Visible == false, "sans mutation : texte Mutation caché")
Carry.Fail(E, "Caught")

print(string.format("scénario carry : %d vérification(s), %d échec(s)", CHECKS - checks0, FAILS))
if FAILS > 0 then
	dumpLog()
end
