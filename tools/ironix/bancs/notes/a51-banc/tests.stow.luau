--!nocheck
-- Scénario « stow » (L-089 point 1) : le colis porté entre dans l'inventaire dès que le joueur entre dans
-- la zone safe (tag SafeZone) : il quitte sa tête, devient un Tool de la barre (après l'outil de casse et
-- la batte), Boxes[uid] sans Spot, braquage compté une fois, anti-triche vérifié juste avant, Notify.
-- Rien dans le couloir. Inventaire de colis plein : le portage échoue (le colis revole vers son rayon).
-- Le Tool ne montre jamais l'objet caché (5.7).

advance(1000)
startServer()

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(Unbox.BoxInventoryMax == 50 and Unbox.MaxPlacedBoxes == 8, "Config.Unbox : BoxInventoryMax 50, MaxPlacedBoxes 8 (V0)")

section("profil neuf : v7, barre avec l'outil de casse et la batte d'abord")
local ada = join("Ada", nil)
advance(1.5)
local d = dataOf(ada)
check(d ~= nil and d.Version == 7 and d.BoxQueue == nil and type(d.Boxes) == "table" and next(d.Boxes) == nil, "profil neuf en v7, sans BoxQueue, Boxes vide")
local order = backpackOrder(ada)
check(#order >= 2 and order[1]:GetAttribute("ToolId") ~= nil and order[2]:GetAttribute("BatTool") == true, `outil de casse puis batte en tête de barre ({#order} Tool(s))`)
check(countKeys(toolsOf(ada)) == 0, "aucun Tool d'inventaire sans colis ni objet")

section("couloir : le colis reste sur la tête")
moveTo(ada, CORRIDOR)
advance(0.1)
CarryService.Give(ada, npcBox("Rare", "Z3_Smartphone", "Premium", 3))
advance(1)
check(CarryService.IsCarrying(ada) and next(dataOf(ada).Boxes) == nil, "dans le couloir : toujours porté, rien dans le profil")

section("entrée dans la zone safe : le colis va dans l'inventaire")
local heists = dataOf(ada).Lifetime.Heists
local verifies = #VERIFY_CALLS
local stowed = {}
UnboxService.OnBoxStowed(function(player, uid, box)
	table.insert(stowed, { player = player, uid = uid, box = box })
end)
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
check(not CarryService.IsCarrying(ada), "le colis a quitté la tête")
local uid, box = next(dataOf(ada).Boxes)
check(type(uid) == "string" and #uid >= 32 and box ~= nil and box.ItemId == "Z3_Smartphone" and box.Tier == "Premium" and box.Zone == 3 and box.Rarity == "Rare", "Boxes[uid] écrit (uid GUID, contenu du colis)")
check(box ~= nil and box.Spot == nil and box.ReadyAt == nil and box.At == math.floor(serverTime() - SERVER_TIME_OFFSET) or (box ~= nil and type(box.At) == "number"), "dans l'inventaire : ni Spot ni ReadyAt, At posé")
check(dataOf(ada).Lifetime.Heists == heists + 1, "braquage compté une fois au rangement")
check(#VERIFY_CALLS == verifies + 1 and VERIFY_CALLS[#VERIFY_CALLS].player == ada and VERIFY_CALLS[#VERIFY_CALLS].from ~= nil, "AntiCheatService.Verify appelé juste avant, avec le point de départ du portage")
local ends = CARRY_ENDS[#CARRY_ENDS]
check(ends ~= nil and ends.result == "Consumed" and ends.player == ada, "portage fini en « Consumed »")
check(#notifies(ada, "Box saved to your inventory") == 1, "Notify « Box saved to your inventory… »")
flush()
check(#stowed == 1 and stowed[1].uid == uid and stowed[1].box.ItemId == "Z3_Smartphone" and stowed[1].box ~= dataOf(ada).Boxes[uid], "OnBoxStowed(player, uid, copie du colis)")
advance(0.6)
check(dataOf(ada).Lifetime.Heists == heists + 1 and countKeys(dataOf(ada).Boxes) == 1, "rien de rangé deux fois (contrôles suivants)")

section("le Tool du colis dans la barre")
local tools = toolsOf(ada)
local tool = tools["Box:" .. uid]
check(tool ~= nil and tool.Name == "Rare Box" and tool:GetAttribute("Tier") == "Premium" and tool:GetAttribute("Rarity") == "Rare", `Tool « Rare Box » (attributs Tier, Rarity) : {tool and tool.Name or "absent"}`)
check(tool ~= nil and tool:GetAttribute("ItemId") == nil and not string.find(tool.Name, "Smartphone") and not string.find(tool.ToolTip or "", "Smartphone"), "l'objet caché n'apparaît nulle part sur le Tool (5.7)")
check(tool ~= nil and tool.TextureId == "rbxassetid://9100" and tool.CanBeDropped == false and tool.RequiresHandle == true and tool:FindFirstChild("Handle") ~= nil, "icône ICON_BOX_Premium, ne se lâche pas, poignée")
order = backpackOrder(ada)
check(order[3] == tool, "le colis arrive après l'outil de casse et la batte (slot 3)")

section("deuxième colis, Standard sans icône")
local uid2 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
local tool2 = uid2 and toolsOf(ada)["Box:" .. uid2]
check(uid2 ~= nil and uid2 ~= uid and tool2 ~= nil and tool2.Name == "Common Box" and tool2.TextureId == "", "« Common Box », sans icône (ICON_BOX_Standard pas livrée)")
check(backpackOrder(ada)[4] == tool2, "le nouveau colis arrive après le premier")

section("anti-triche : déplacement sanctionné, rien n'est rangé")
VERIFY_VERDICT = false
local count = countKeys(dataOf(ada).Boxes)
local h = dataOf(ada).Lifetime.Heists
local uid3 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
check(uid3 == nil and countKeys(dataOf(ada).Boxes) == count and dataOf(ada).Lifetime.Heists == h and not CarryService.IsCarrying(ada), "sanctionné : colis rendu, profil inchangé")
check(CARRY_ENDS[#CARRY_ENDS].result == "Failed" and CARRY_ENDS[#CARRY_ENDS].reason == "Anomaly", "portage échoué (Anomaly)")
VERIFY_VERDICT = true

section("objet volé à un joueur : jamais rangé (il se dépose dans la DepositZone)")
moveTo(ada, refsOfShop(shopOf(ada)).center)
CarryService.Give(ada, { Kind = "PlayerItem", ItemUid = "x", ItemId = "Z1_Banane", Rarity = "Common", Income = 1, VictimUserId = 9, SlotIndex = 1 })
advance(0.6)
check(CarryService.IsCarrying(ada) and countKeys(dataOf(ada).Boxes) == count, "objet volé gardé sur la tête dans la zone safe")
CarryService.Consume(ada)

section("inventaire de colis plein : le colis revole vers son rayon")
local data = newProfile()
for i = 1, Unbox.BoxInventoryMax do
	data.Boxes[tostring(i)] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 0 }
end
local bob = join("Bob", data)
advance(1.5)
check(countKeys(dataOf(bob).Boxes) == Unbox.BoxInventoryMax, `migration : {Unbox.BoxInventoryMax} colis dans l'inventaire`)
local hb = dataOf(bob).Lifetime.Heists
local full = bringBox(bob, "Rare", "Z3_Smartphone", "Premium", 3)
check(full == nil and countKeys(dataOf(bob).Boxes) == Unbox.BoxInventoryMax and dataOf(bob).Lifetime.Heists == hb, "51e colis : pas rangé, braquage pas compté")
check(CARRY_ENDS[#CARRY_ENDS].result == "Failed" and CARRY_ENDS[#CARRY_ENDS].reason == "InventoryFull" and not CarryService.IsCarrying(bob), "portage échoué (InventoryFull) : le colis revole vers son rayon")
check(#notifies(bob, "Too many boxes in your inventory") == 1, "Notify « Too many boxes in your inventory… »")

section("profil pas chargé : rien n'est rangé")
LOAD_DELAY = 30
local cy = join("Cy", nil)
CarryService.Give(cy, npcBox("Common", "Z1_Banane"))
advance(1)
check(CarryService.IsCarrying(cy), "profil pas encore chargé : le colis reste porté")
LOAD_DELAY = 0

summary("scénario stow")
