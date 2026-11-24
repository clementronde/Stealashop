--!nocheck
-- A. Studio, Features.FortuneTower = false (coupé à la main depuis a148) : aucune vitrine automatique ; le crochet
-- FortuneTest la fait apparaître (bloc V0), PV partagés, barre client, casse, butin, prise, retrait.
-- B. Fin au temps, Seal, Open, alerte de la nuit.

-- a148 (vague 42) : true est livré ; ce scénario coupe l'interrupteur à la main (le crochet de test Studio).
local SHIPPED_ON = string.find(SOURCES["shared/Config/Features.luau"], "FortuneTower = true,", 1, true) ~= nil
setFeature("FortuneTower", false)
setFeature("TruckEvent", false) -- pas de camion qui passe pendant les longues attentes
local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local Night = serverModule("NightCycleService")
local Items = sharedModule("Config/Items")
local FortuneTower = sharedModule("Config/FortuneTower")
local Features = sharedModule("Config/Features")
local Zones = sharedModule("Config/Zones")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(680, 3, 2), Vector3.new(1, 0, 0))
spawnCharacter(B, Vector3.new(680, 3, -2), Vector3.new(1, 0, 0))
giveTool(A, "Hammer")
giveTool(B, "Hammer")
startClient(A)

section("A0. Valeurs V0 dérivées")
check(SHIPPED_ON and Features.FortuneTower == false, "A0a a148 : Features.FortuneTower = true livré (coupé ici à la main)")
check(FortuneTower.LootZones and table.concat(FortuneTower.LootZones, ",") == "2,3,4,5,6", "A0h a148 : Mythiques des zones 2 à 6")
check(FortuneTower.MaxHP == 4 * Zones[6].AdvisedDamage * 5 * 90 and FortuneTower.MaxHP == 3600000000, `A0b a134 : PV = 4 × 2 000 000 × 5 × 90 ({FortuneTower.MaxHP})`)
check(near(FortuneTower.RarityOdds.Mythic, 90, 1e-9) and near(FortuneTower.RarityOdds.Secret, 10, 1e-9) and FortuneTower.RarityOdds.Divine == 0, "A0c Mythic 90 %, Secret 10 %, Divine 0 %")
check(FortuneTower.RarityOdds.Legendary == nil, "A0d rien en dessous de Mythique")
check(near(FortuneTower.SizeOdds.Huge, 80, 1e-9) and near(FortuneTower.SizeOdds.Colossal, 20, 1e-9), "A0e Huge 80 %, Colossal 20 %")
check(FortuneTower.SpawnIntervalMin == 40 * 60 and FortuneTower.SpawnIntervalMax == 60 * 60, "A0f toutes les 40 à 60 min")
check(FortuneTower.Lifetime == 180 and FortuneTower.LootCount == 8 and FortuneTower.LootTier == "Luxe", "A0g 180 s, 8 colis Luxe")

section("A1. Coupé : rien d'automatique")
check(logHas("événement Fortune Tower coupé", "PRINT", "server"), "A1a une ligne au démarrage")
check(logHas('SetAttribute("FortuneTest", true)', "PRINT", "server"), "A1b la ligne dit comment tester")
advance(65 * 60, 1)
check(#vaults() == 0, "A1c aucune vitrine en 65 min à 2 joueurs")

section("A2. Crochet FortuneTest : apparition")
clearLog()
moveTo(B, Vector3.new(690, 3, 0)) -- là où la vitrine apparaît
Workspace:SetAttribute("FortuneTest", true)
flush()
local vault = currentVault()
local bx = B.Character.HumanoidRootPart.Position.X
check(bx < 686 - 2.9 and bx > 686 - 3.1, `A2l Bob, pris dedans, posé 3 studs devant la face avant (x = {bx})`)
moveTo(B, Vector3.new(680, 3, -2))
check(vault ~= nil, "A2a une vitrine")
check(Workspace:GetAttribute("FortuneTest") == nil, "A2b l'attribut est effacé")
check(vault and vault.Name == "FortuneVault" and vault:GetAttribute("Zone") == 6 and vault:GetAttribute("VaultNumber") == 1, "A2c FortuneVault, zone 6, n° 1")
local pivot = vault:GetPivot()
check((pivot.Position - Vector3.new(690, 0, 0)).Magnitude < 1e-3, `A2d au milieu de la chaussée de la zone 6, 30 studs après ses magasins ({pivot.Position})`)
check(pivot.LookVector:Dot(Vector3.new(-1, 0, 0)) > 0.999, "A2e face avant vers les joueurs qui arrivent (−X)")
check(logHas("ENV_Event_FortuneVault pas encore rangé", "WARN", "server"), "A2f bloc V0 signalé (orange)")
check(vault:FindFirstChild("Window", true) ~= nil and vault:FindFirstChild("HealthBarPoint", true) ~= nil, "A2g bloc V0 : Window et HealthBarPoint")
check(vault:GetAttribute("MaxHP") == FortuneTower.MaxHP and vault:GetAttribute("HP") == FortuneTower.MaxHP, "A2h 100 800 000 PV pleins")
local spawnedAt = vault:GetAttribute("SpawnedAt")
check(type(spawnedAt) == "number" and near(vault:GetAttribute("EndsAt"), spawnedAt + 180, 1e-6), "A2i SpawnedAt et EndsAt (+180 s)")
local spawned = notifies("A giant vault appeared at the Fortune Tower")
check(#spawned == 1 and spawned[1].to == nil and spawned[1].args[2] == "Announce", "A2j annonce à tout le serveur (Announce)")
check(hasTag(vault, "HitTarget"), "A2k cible d'événement (HitTarget)")

section("A3. Barre de PV (client)")
local bar = A.PlayerGui:FindFirstChild("BB_WindowHP_FortuneVault")
check(bar ~= nil and bar.Enabled == true, "A3a repli BB_WindowHP (ni BB_FortuneHP ni BB_TruckHP dans le banc), allumée")
check(bar and bar.Adornee and bar.Adornee.Name == "HealthBarPoint", "A3b sur HealthBarPoint")
check(bar and bar.MaxDistance == FortuneTower.HealthBarMaxDistance, "A3c visible de loin (250 studs)")
local label = bar and bar:FindFirstChild("Label", true)
check(label and string.find(label.Text, "/", 1, true) ~= nil, `A3d Label « PV / PV max » ({label and label.Text})`)

section("A4. PV partagés")
local id = vault:GetAttribute("WindowId")
Tool.damage[A] = 1050000000 -- a134 : tour à 3.6B PV
Tool.damage[B] = 1050000000
fireAs(A, "HitWindow", id)
advance(0.15)
fireAs(B, "HitWindow", id)
advance(0.25)
check(vault:GetAttribute("HP") == FortuneTower.MaxHP - 2100000000, `A4a deux joueurs, une seule réserve de PV ({vault:GetAttribute("HP")})`)
check(#currentVault():GetChildren() > 0 and #fortuneDrops() == 0, "A4b pas encore cassée : aucun colis")
check(label and string.find(label.Text, "1.5B", 1, true) ~= nil, `A4c barre suit les PV ({label and label.Text})`)

section("A5. Casse : butin")
Tool.damage[A] = 2100000000
clearLog()
fireAs(A, "HitWindow", id)
advance(0.2)
check(vault:GetAttribute("Broken") == true, "A5a Broken")
local window = vault:FindFirstChild("Window", true)
check(window.Transparency == 1 and window.CanCollide == false and window.CanQuery == false, "A5b vitre cachée, ne bloque plus rien")
check(type(vault:GetAttribute("OpenedAt")) == "number", "A5c OpenedAt posé")
check(#notifies("The Fortune vault is open: grab the loot!") == 1, "A5d annonce de l'ouverture")
check(bar.Enabled == false, "A5e barre cachée")
local drops = fortuneDrops()
check(#drops == 8, `A5f 8 colis au sol ({#drops})`)
local okPayload, okSize, okRarity, okZone, okPos = true, true, true, true, true
for _, model in drops do
	local payload, position = Carry.GetDrop(model:GetAttribute("DropId"))
	if payload == nil or payload.Kind ~= "NPCBox" or payload.Tier ~= "Luxe" or model:GetAttribute("Tier") ~= "Luxe" or payload.StoreId ~= "Truck_Fortune_1" or not string.match(payload.SlotId, "^Truck_Fortune_1/0%d$") then
		okPayload = false
	end
	local size = payload and payload.Mutation and payload.Mutation.Size
	if size ~= "Huge" and size ~= "Colossal" then
		okSize = false
	end
	local item = payload and Items.ById[payload.ItemId]
	if item == nil or item.Rarity ~= payload.Rarity or (payload.Rarity ~= "Mythic" and payload.Rarity ~= "Secret") then
		okRarity = false
	end
	-- a148 : Mythique des zones 2 à 6, le colis porte la zone de son objet (Secret : zone 6).
	if payload and payload.Rarity == "Mythic" and (item.Zone == nil or item.Zone < 2 or item.Zone > 6 or payload.Zone ~= item.Zone) then
		okZone = false
	end
	if payload and payload.Rarity == "Secret" and payload.Zone ~= 6 then
		okZone = false
	end
	if position == nil or not near(position.Y, 0, 1e-6) or position.X > 690 then
		okPos = false
	end
end
check(okPayload, "A5g colis PNJ Luxe, StoreId Truck_Fortune_1, SlotId Truck_Fortune_1/0n")
check(okSize, "A5h tous Huge ou Colossal")
check(okRarity, "A5i Mythique ou Secret, objet de la bonne rareté")
check(okZone, "A5j a148 : Mythique des zones 2 à 6, colis de la zone de son objet")
check(okPos, "A5k au sol, devant la face avant")
check(logHas("vitrine n° 1 cassée par Alice", "PRINT", "server"), "A5l ligne en Studio")

section("A6. Invite et prise")
local first = drops[1]
local prompt = first:FindFirstChildWhichIsA("ProximityPrompt", true)
check(prompt and prompt.ObjectText == "Luxury Box" and prompt.ActionText == "Grab" and prompt.HoldDuration == 1, "A6a invite « Grab / Luxury Box », 1 s")
check(prompt and prompt.Enabled == true, "A6b allumée mains vides")
local dropId = first:GetAttribute("DropId")
local _, landing = Carry.GetDrop(dropId)
-- Trop loin.
moveTo(A, landing + Vector3.new(20, 3, 0))
fireAs(A, "GrabDropped", dropId)
advance(1.05)
fireAs(A, "GrabDropped", dropId)
flush()
check(not Carry.IsCarrying(A), "A6c trop loin : refusé")
-- Maintien trop court.
moveTo(A, landing + Vector3.new(1, 3, 0))
fireAs(A, "GrabDropped", dropId)
advance(0.3)
fireAs(A, "GrabDropped", dropId)
flush()
check(not Carry.IsCarrying(A), "A6d maintien trop court : refusé")
advance(1.5) -- le maintien expire
fireAs(A, "GrabDropped", dropId)
advance(1.0)
fireAs(A, "GrabDropped", dropId)
flush()
check(Carry.IsCarrying(A), "A6e maintien de 1 s : porté")
local carried = Carry.GetPayload(A)
check(carried and carried.StoreId == "Truck_Fortune_1", "A6f le colis de la vitrine")
check(Carry.GetDrop(dropId) == nil and first.Parent == nil, "A6g plus au sol")
-- Mains pleines.
local second = drops[2]
local id2 = second:GetAttribute("DropId")
local _, landing2 = Carry.GetDrop(id2)
moveTo(A, landing2 + Vector3.new(1, 3, 0))
fireAs(A, "GrabDropped", id2)
advance(1.05)
fireAs(A, "GrabDropped", id2)
flush()
check(Carry.GetDrop(id2) ~= nil, "A6h mains pleines : refusé")
advance(0.5)
check(second:FindFirstChildWhichIsA("ProximityPrompt", true).Enabled == false, "A6i invites éteintes en portant")

section("A7. Retrait")
advance(FortuneTower.BoxLifetime + 1, 0.5)
check(#fortuneDrops() == 0, "A7a colis jamais ramassés : disparus au bout de 60 s")
check(vault.Parent == nil and #vaults() == 0, "A7b vitrine ouverte retirée")
check(A.PlayerGui:FindFirstChild("BB_WindowHP_FortuneVault") == nil, "A7c barre retirée")

section("B1. Fin au temps")
clearLog()
Workspace:SetAttribute("FortuneTest", true)
flush()
local v2 = currentVault()
check(v2 and v2:GetAttribute("VaultNumber") == 2, "B1a deuxième vitrine")
advance(179, 0.5)
check(v2.Parent ~= nil, "B1b encore là à 179 s")
advance(1.5, 0.1)
check(v2.Parent == nil and #fortuneDrops() == 0, "B1c refermée à 180 s, rien lâché")
check(#notifies("The Fortune vault sealed itself. Too slow!") == 1, "B1d annonce Sealed")

section("B2. Seal et Open")
Workspace:SetAttribute("FortuneTest", true)
flush()
local v3 = currentVault()
Workspace:SetAttribute("FortuneTest", "Seal")
flush()
check(v3.Parent == nil and #vaults() == 0, "B2a Seal : refermée")
Workspace:SetAttribute("FortuneTest", true)
flush()
Workspace:SetAttribute("FortuneTest", "Open")
flush()
check(#fortuneDrops() == 8, "B2b Open : 8 colis")
Workspace:SetAttribute("FortuneTest", "Nimporte")
flush()
check(logHas("attendu true", "WARN", "server"), "B2c valeur inconnue : une ligne")
advance(FortuneTower.RemoveDelay + 1, 0.5)

section("B3. Alerte de la nuit")
Workspace:SetAttribute("FortuneTest", true)
flush()
local v4 = currentVault()
Night._set("Warning", 30)
flush()
advance(0.2)
check(v4.Parent == nil, "B3a refermée à l'alerte")
check(#notifies("Night is coming: the Fortune vault sealed itself.") == 1, "B3b annonce SealedNight")

summary("scénario crochet")
