-- Scénarios du banc a98 (panel admin, L-108 point 4).

local Admin = requireShared("Shared.Config.Admin")
local AdminLists = requireShared("Shared.AdminLists")
local Items = requireShared("Shared.Config.Items")
local Rarities = requireShared("Shared.Config.Rarities")
local Mutations = requireShared("Shared.Config.Mutations")
local Cosmetics = requireShared("Shared.Config.Cosmetics")
local Monetization = requireShared("Shared.Config.Monetization")

-- 0. Contrat : remotes, catalogue, listes -----------------------------------------------------------
do
	local def = defOf("AdminCommand")
	check("0 AdminCommand déclaré, client → serveur", def ~= nil and def.Direction == "ClientToServer")
	check("0 AdminResult déclaré, serveur → client", defOf("AdminResult") ~= nil and defOf("AdminResult").Direction == "ServerToClient")
	check("0 17 commandes", #Admin.Commands == 17, #Admin.Commands)
	check("0 Items = Config/Items", #AdminLists.Entries("Items") == #Items.List)
	check("0 Boxes = raretés", #AdminLists.Entries("Boxes") == #Rarities.List)
	check("0 Mutations = None + tailles + effets", #AdminLists.Entries("Mutations") == 1 + #Mutations.Sizes + #Mutations.Effects)
	check("0 None d'Id vide en tête", AdminLists.Entries("Mutations")[1].Id == "" and AdminLists.Entries("Mutations")[1].Label == "None")
	check("0 Auras et Trails", #AdminLists.Entries("Auras") == #Cosmetics.Auras and #AdminLists.Entries("Trails") == #Cosmetics.Trails)
	check("0 Gamepasses", #AdminLists.Entries("Gamepasses") == #Monetization.Passes and AdminLists.Has("Gamepasses", "VIP"))
	check("0 Zones : safe + 6", #AdminLists.Entries("Zones") == 7 and AdminLists.Entries("Zones")[1].Id == "0")
	check("0 Events : Truck, Night, Day", AdminLists.Has("Events", "Truck") and AdminLists.Has("Events", "Night") and AdminLists.Has("Events", "Day"))
	check("0 Has refuse un Id inconnu", not AdminLists.Has("Items", "Nope"))
end

-- 1. Serveur en ligne : seuls les admins du groupe ---------------------------------------------------
STUDIO = false
RANKS = { Owner = 255, Member = 10 }
local owner = newPlayer("Owner")
local member = newPlayer("Member")
loadAdmin()
newStore(2, 0, -60)
newStore(2, 0, 60)
newStore(3, 100, -60)
newStore(5, 300, -60, true) -- dans _INBOX_CLEMENT : ignoré
do
	check("1 rang lu dans le groupe du jeu (CreatorId)", #called("GetRankInGroup") >= 2 and called("GetRankInGroup")[1].args[2] == 777)
	check("1 IsAdmin posé au propriétaire du groupe", owner:GetAttribute("IsAdmin") == true)
	check("1 IsAdmin absent pour un membre de rang 10", member:GetAttribute("IsAdmin") == nil)
	local replies = #REPLIES
	fire(member, "GiveCash", nil, 1000)
	check("1 non-admin : rien donné", DATA[member].Cash == 0)
	check("1 non-admin : aucune réponse", #REPLIES == replies)
	check("1 non-admin : une ligne dans la sortie", hasLog("Member (2) n'est pas admin"))
	fire(member, "GiveCash", owner, 1000)
	check("1 non-admin : rien donné à un autre", DATA[owner].Cash == 0)

	fire(owner, "GiveCash", nil, 1000)
	check("1 admin : argent donné à soi", DATA[owner].Cash == 1000, DATA[owner].Cash)
	local r = lastReply()
	check("1 admin : réponse ok", r and r[1] == "GiveCash" and r[2] == true and string.find(r[3], "$1", 1, true) ~= nil, r and r[3])
	check("1 télémétrie AdminCommand", #called("Telemetry") == 1 and called("Telemetry")[1].args[2] == "AdminCommand" and called("Telemetry")[1].args[3][1] == "Command - GiveCash")
	check("1 journal de la commande", hasLog("Owner (1) GiveCash → Owner value=1000 : ok"))

	fire(owner, "GiveCash", member, 50)
	check("1 cible : un autre joueur", DATA[member].Cash == 50 and DATA[owner].Cash == 1000)

	fire(owner, "GivePotion", nil, nil, "Speed")
	r = lastReply()
	check("1 StudioOnly refusée en ligne", r[2] == false and r[3] == Admin.Messages.StudioOnly)
	check("1 aucun crochet posé en ligne", Workspace:GetAttribute("PotionTest") == nil)
	fire(owner, "StartEvent", nil, nil, "Truck")
	check("1 événement refusé en ligne", lastReply()[2] == false and Workspace:GetAttribute("TruckSpawnNow") == nil)

	fire(owner, "Nope")
	check("1 commande inconnue refusée", lastReply()[1] == "Nope" and lastReply()[2] == false and lastReply()[3] == "Unknown command.")

	local gone = newPlayer("Gone")
	removePlayer(gone)
	fire(owner, "GiveCash", gone, 10)
	check("1 cible partie refusée", lastReply()[2] == false and DATA[gone].Cash == 0)

	fire(owner, "Teleport", nil, 2)
	local pos = owner.Character._pivotTo
	check("1 téléport zone 2 : milieu des 2 magasins, au-dessus", pos ~= nil and pos.X == 0 and pos.Z == 0 and pos.Y == 14, pos and tostring(pos.X) .. "," .. pos.Y .. "," .. pos.Z)
	check("1 téléport : anti-triche prévenu", #called("Allow") == 1 and called("Allow")[1].args[1] == owner)
	fire(owner, "Teleport", member, 5)
	check("1 téléport : zone sans magasin hors _INBOX refusée", lastReply()[2] == false and member.Character._pivotTo == nil)
	fire(owner, "Teleport", member, 0)
	check("1 téléport 0 : boutique", lastReply()[2] == true and called("TeleportHome")[1].args[1] == member)
	fire(owner, "Teleport", nil, 2.5)
	check("1 téléport zone non entière refusée", lastReply()[2] == false)

	-- Remise à zéro (en ligne aussi).
	DATA[member].Cash = 999
	fire(owner, "ResetProfile", member, nil, "reset")
	check("1 reset sans le bon mot refusé", lastReply()[2] == false and member._kicked == nil)
	fire(owner, "ResetProfile", member, nil, "RESET")
	check("1 reset : réponse ok", lastReply()[2] == true)
	check("1 reset : cible renvoyée", member._kicked == Admin.Messages.Kicked)
	local data = DATA[member]
	RELEASING(member)
	check("1 reset : profil neuf", data.Cash == 0 and data.Index == nil and data.Version == 8)
	check("1 reset : achats Robux gardés", data.Purchases["p-1"] == 123 and data.Monetization.StarterPack == true)
	RELEASING(owner)
	check("1 départ sans reset : profil intact", DATA[owner].Cash == 1000)
end

-- 2. Studio : tout le monde est admin, arguments revalidés -----------------------------------------------
STUDIO = true
CALLS = {}
local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
loadAdmin()
do
	check("2 Studio : IsAdmin pour tous", alice:GetAttribute("IsAdmin") == true and bob:GetAttribute("IsAdmin") == true)
	-- Forme (Net/Validate) : refus avant le service.
	check("2 forme : montant négatif", fire(alice, "GiveCash", nil, -5) == "ArgValue")
	check("2 forme : montant infini", fire(alice, "GiveCash", nil, math.huge) == "ArgValue")
	check("2 forme : commande non texte", fire(alice, 12) == "ArgType")
	check("2 forme : cible non joueur", fire(alice, "GiveCash", "Bob", 5) == "ArgType")
	check("2 forme : texte trop long", fire(alice, "GiveItem", nil, nil, string.rep("x", 65)) == "ArgValue")
	check("2 forme : trop d'arguments", fire(alice, "GiveCash", nil, 1, "a", "b", "c") == "ArgCount")

	fire(alice, "GiveCash", nil, 0.5)
	check("2 GiveCash < 1 refusé", lastReply()[2] == false and DATA[alice].Cash == 0)
	fire(alice, "GiveCash")
	check("2 GiveCash sans montant refusé", lastReply()[2] == false)
	fire(alice, "GiveSpeed", nil, 250)
	fire(alice, "GiveStrength", bob, 1e9)
	check("2 GiveSpeed et GiveStrength", DATA[alice].Stats.Speed == 250 and DATA[bob].Stats.Strength == 1e9)

	PLOTS[alice] = "PlotA"
	fire(alice, "SetTreadmill", nil, 21)
	check("2 SetTreadmill > MaxLevel refusé", lastReply()[2] == false and DATA[alice].Upgrades.Treadmill == 0)
	fire(alice, "SetTreadmill", nil, 8)
	check("2 SetTreadmill 8", DATA[alice].Upgrades.Treadmill == 8)
	check("2 SetTreadmill : attributs, colis, tapis, rayons rafraîchis", #called("ShopRefresh") == 1 and #called("UnboxRefresh") == 1 and called("VariantRefresh")[1].args[1] == "PlotA" and #called("RayonRefresh") == 1)
	fire(alice, "SetBench", nil, 2.5)
	check("2 SetBench non entier refusé", lastReply()[2] == false and DATA[alice].Upgrades.Bench == 0)
	fire(alice, "SetBench", bob, 20)
	check("2 SetBench 20 sur Bob", DATA[bob].Upgrades.Bench == 20)
	fire(alice, "SetShopLevel", nil, 3)
	check("2 SetShopLevel 3 : 5 présentoirs achetés (9 débloqués)", DATA[alice].Upgrades.DisplaySlots == 5, DATA[alice].Upgrades.DisplaySlots)
	fire(alice, "SetShopLevel", nil, 1)
	check("2 SetShopLevel 1 : 0", DATA[alice].Upgrades.DisplaySlots == 0)
	fire(alice, "SetRayons", nil, 5)
	check("2 SetRayons 5 : 16 (max)", DATA[alice].Upgrades.DisplaySlots == 16)
	fire(alice, "SetRayons", nil, 2)
	check("2 SetRayons 2 : 4", DATA[alice].Upgrades.DisplaySlots == 4)
	fire(alice, "SetRayons", nil, 6)
	check("2 SetRayons 6 refusé", lastReply()[2] == false and DATA[alice].Upgrades.DisplaySlots == 4)

	-- Objets.
	local someItem = Items.List[1]
	fire(alice, "GiveItem", nil, nil, "Nope")
	check("2 GiveItem inconnu refusé", lastReply()[2] == false and next(DATA[alice].Items) == nil)
	fire(alice, "GiveItem", nil, nil, someItem.Id, "Purple")
	check("2 GiveItem mutation inconnue refusée", lastReply()[2] == false and next(DATA[alice].Items) == nil)
	fire(alice, "GiveItem", nil, nil, someItem.Id, "Huge Gold")
	local uid, entry = next(DATA[alice].Items)
	check("2 GiveItem avec mutation", entry ~= nil and entry.Id == someItem.Id and entry.Mutation.Size == "Huge" and entry.Mutation.Effect == "Gold" and entry.Zone == (someItem.Zone or 1), lastReply()[3])
	check("2 GiveItem : index et inventaire", called("Discover")[1].args[2] == someItem.Id and #called("InventoryRefresh") == 1)
	DATA[alice].Items[uid] = nil
	fire(alice, "GiveItem", nil, nil, someItem.Id, "")
	uid, entry = next(DATA[alice].Items)
	check("2 GiveItem sans mutation", entry ~= nil and entry.Mutation == nil)
	FULL[bob] = true
	fire(alice, "GiveItem", bob, nil, someItem.Id)
	check("2 GiveItem inventaire plein refusé", lastReply()[2] == false and next(DATA[bob].Items) == nil)
	FULL[bob] = nil
	local secret = Items.Secrets[1]
	if secret then
		fire(alice, "GiveItem", bob, 4, secret.Id)
		local _, s = next(DATA[bob].Items)
		check("2 GiveItem Secret en zone 4", s ~= nil and s.Zone == 4)
	end

	-- Colis.
	fire(alice, "GiveBox", nil, nil, "Shiny")
	check("2 GiveBox rareté inconnue refusée", lastReply()[2] == false and next(DATA[alice].Boxes) == nil)
	fire(alice, "GiveBox", nil, nil, "Epic")
	local _, box = next(DATA[alice].Boxes)
	check("2 GiveBox Epic exacte", box ~= nil and box.Rarity == "Epic" and Items.ById[box.ItemId].Rarity == "Epic" and box.Spot == nil, lastReply()[3])
	check("2 GiveBox : Tier Premium (V0)", box ~= nil and box.Tier == "Premium")
	fire(bob, "GiveBox", nil, 3, "Common")
	local _, b2 = next(DATA[bob].Boxes)
	check("2 GiveBox zone 3 demandée", b2 ~= nil and b2.Zone == 3 and b2.Tier == "Standard")
	fire(bob, "GiveBox", nil, 7, "Common")
	check("2 GiveBox zone 7 refusée", lastReply()[2] == false)

	-- Cosmétiques.
	local aura, trail = Cosmetics.Auras[1], Cosmetics.Trails[1]
	fire(alice, "GiveAura", nil, nil, trail.Id)
	check("2 GiveAura avec un Id de trail refusé", lastReply()[2] == false and #called("Grant") == 0)
	fire(alice, "GiveAura", nil, nil, aura.Id)
	check("2 GiveAura : Grant puis Equip", called("Grant")[1].args[2] == aura.Id and called("Equip")[1].args[2] == aura.Id)
	fire(alice, "GiveTrail", bob, nil, trail.Id)
	check("2 GiveTrail sur Bob", called("Grant")[2].args[1] == bob and called("Grant")[2].args[2] == trail.Id)

	-- Crochets Studio.
	fire(alice, "GivePotion", bob, nil, "Speed")
	check("2 GivePotion : crochet PotionTest", Workspace:GetAttribute("PotionTest") == `{bob.UserId} give Speed`)
	fire(alice, "GivePotion", nil, nil, "Beer")
	check("2 GivePotion inconnue refusée", lastReply()[2] == false)
	fire(alice, "GiveGamepass", nil, nil, "VIP")
	check("2 GiveGamepass boutique coupée refusé", lastReply()[2] == false and Workspace:GetAttribute("MonetizationTest") == nil)
	FEATURE_ROBUX = true
	fire(alice, "GiveGamepass", nil, nil, "Cash10")
	check("2 GiveGamepass : un produit (vrai achat) refusé", lastReply()[2] == false and Workspace:GetAttribute("MonetizationTest") == nil)
	fire(alice, "GiveGamepass", nil, nil, "VIP")
	check("2 GiveGamepass VIP : crochet MonetizationTest", Workspace:GetAttribute("MonetizationTest") == `{alice.UserId} VIP`)
	fire(alice, "SetSkill", nil, 2, "GlassThickness")
	check("2 SetSkill : crochet SkillTest", Workspace:GetAttribute("SkillTest") == `{alice.UserId} GlassThickness 2`)
	fire(alice, "SetSkill", nil, 99, "GlassThickness")
	check("2 SetSkill > MaxLevel refusé", lastReply()[2] == false)
	fire(alice, "StartEvent", nil, 3, "Truck")
	check("2 StartEvent Truck zone 3", Workspace:GetAttribute("TruckSpawnNow") == 3)
	Workspace:SetAttribute("TruckSpawnNow", nil)
	fire(alice, "StartEvent", nil, 9, "Truck")
	check("2 StartEvent Truck zone 9 refusé", lastReply()[2] == false and Workspace:GetAttribute("TruckSpawnNow") == nil)
	fire(alice, "StartEvent", nil, nil, "Truck")
	local z = Workspace:GetAttribute("TruckSpawnNow")
	check("2 StartEvent Truck sans zone : au hasard 1 à 6", type(z) == "number" and z >= 1 and z <= 6)
	fire(alice, "StartEvent", nil, 20, "Night")
	check("2 StartEvent Night 20 s", called("SkipTo")[1].args[1] == "Night" and called("SkipTo")[1].args[2] == 20)
	fire(alice, "StartEvent", nil, nil, "Day")
	check("2 StartEvent Day", called("SkipTo")[2].args[1] == "Day" and called("SkipTo")[2].args[2] == nil)
	fire(alice, "StartEvent", nil, nil, "Rain")
	check("2 StartEvent Rain pas encore", lastReply()[2] == false and lastReply()[3] == "Unknown event.")
	check("2 StartEvent sans cible : journal sans flèche", hasLog("Alice (") and hasLog("StartEvent value=20"))
end

print(`banc a98 : {CHECKS} vérification(s), {FAILS} échec(s)`)
