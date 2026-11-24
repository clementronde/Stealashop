--!nocheck
-- Scénarios du banc DEV-017 : CarryService (serveur) et CarryController (client).
-- Copie d'a11, adaptée par a17 (L-031) : BB_Box sur le colis PNJ porté, BB_Carry pour l'objet
-- volé seulement, revenu en Format.income, CarryService.AttachBoxLabel (colis du rayon).

-- a22 : catalogue v2, chaque objet a sa catégorie anglaise (plus de catégorie d'essai injectée).

---------------------------------------------------------------- bouchons
SOURCES["stub/StatsService"] = [[
local StatsService = { calls = {}, modifiers = {} }
function StatsService.SetSpeedModifier(player, key, multiplier)
	table.insert(StatsService.calls, { player = player, key = key, multiplier = multiplier })
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player][key] = multiplier
end
function StatsService.SetFixedSpeed(player, walkSpeed) -- vitesse fixe (objet volé, Cantin 2026-11-13)
	table.insert(StatsService.calls, { player = player, key = "Fixed", multiplier = walkSpeed })
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player].Fixed = walkSpeed
end
return StatsService
]]
SOURCES["stub/AnimationController"] = [[
local AnimationController = { calls = {} }
function AnimationController.SetCarrying(on)
	table.insert(AnimationController.calls, on)
end
return AnimationController
]]

---------------------------------------------------------------- arbre du jeu
local shared = make("Folder", { Name = "Shared" }, ReplicatedStorage)
for key in SOURCES do
	local rel = string.match(key, "^shared/(.+)%.luau$")
	if rel then
		local parent = shared
		local segments = string.split(rel, "/")
		for i = 1, #segments - 1 do
			parent = parent:FindFirstChild(segments[i]) or make("Folder", { Name = segments[i] }, parent)
		end
		moduleScript(parent, segments[#segments], key)
	end
end
local server = make("Folder", { Name = "Server" }, ServerScriptService)
local services = make("Folder", { Name = "Services" }, server)
local carryModule = moduleScript(services, "CarryService", "server/Services/CarryService.luau")
local statsModule = moduleScript(services, "StatsService", "stub/StatsService")
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = make("Folder", { Name = "Client" }, sps)
local controllers = make("Folder", { Name = "Controllers" }, clientFolder)
local controllerModule = moduleScript(controllers, "CarryController", "client/Controllers/CarryController.luau")
local animModule = moduleScript(controllers, "AnimationController", "stub/AnimationController")

local Carry = requireModule(carryModule, "server")
local Stats = requireModule(statsModule, "server")
local Rarities = requireModule(shared.Config.Rarities, "server")
local Balance = requireModule(shared.Config.Balance, "server")
local Bat = requireModule(shared.Config.Bat, "server")
Carry.Init()

---------------------------------------------------------------- aides
local userIds = 0
local function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	return player
end
local function spawnCharacter(player, x)
	x = x or 0
	local character = make("Model", { Name = player.Name })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(x, 3, 0) }, character)
	local head = make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(x, 4.6, 0) }, character)
	local humanoid = make("Humanoid", { Name = "Humanoid" }, character)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character, humanoid, head
end
local function npc(overrides)
	local payload = {
		Kind = "NPCBox",
		Tier = "Premium",
		Zone = 1,
		Rarity = "Rare",
		ItemId = "Z1_PotDeNouilles",
		StoreId = "STORE_Z1_Superette",
		SlotId = "ShelfSlot_07",
	}
	for k, v in overrides or {} do
		payload[k] = v
	end
	return payload
end
local started, ended, expired = {}, {}, {}
Carry.OnCarryStarted(function(player, payload)
	table.insert(started, { player = player, payload = payload })
end)
Carry.OnCarryEnded(function(player, payload, result, reason)
	table.insert(ended, { player = player, payload = payload, result = result, reason = reason })
end)
Carry.OnDropExpired(function(dropId, payload)
	table.insert(expired, { dropId = dropId, payload = payload })
end)
local function lastEnded()
	return ended[#ended]
end
local function visualOf(character)
	return character:FindFirstChild("CarryVisual")
end
local function count(root, class)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA(class) then
			n += 1
		end
	end
	return n
end
local function section(name)
	print("--- " .. name)
end

local A = newPlayer("Alice")
local charA, humA, headA = spawnCharacter(A, 0)
local B = newPlayer("Bob")
local charB, humB, headB = spawnCharacter(B, 20)

---------------------------------------------------------------- 1. portage de base, bloc V0
section("1. StartCarry : bloc V0, étiquette V0")
local fists = make("Tool", { Name = "Poings" }, charA)
local p1 = npc()
clearLog()
check(Carry.StartCarry(A, p1) == true, "StartCarry valide renvoie true")
check(Carry.IsCarrying(A), "IsCarrying après StartCarry")
check(Carry.GetPayload(A) == p1, "GetPayload renvoie la même table")
check(A:GetAttribute("Carrying") == "Rare", "attribut Carrying = rareté")
check(Stats.modifiers[A].Carry == Balance.Carry.NPCBoxSpeedMultiplier, "malus colis PNJ 0,9 posé")
check(fists.Parent == A.Backpack, "outil tenu rangé dans le Backpack")
check(#started == 1 and started[1].player == A and started[1].payload == p1, "OnCarryStarted(player, payload)")
local v1 = visualOf(charA)
check(v1 ~= nil, "CarryVisual dans le personnage")
check(v1.ModelStreamingMode == "Enum.ModelStreamingMode.Atomic", "visuel en streaming atomique")
local block = v1:FindFirstChild("Tint", true)
check(block ~= nil and block.Color == Rarities.ById.Rare.Color, "bloc V0 teint à la couleur Rare")
for _, part in v1:GetDescendants() do
	if part:IsA("BasePart") then
		check(
			part.Anchored == false and part.CanCollide == false and part.CanTouch == false and part.CanQuery == false and part.Massless == true,
			"pièce du visuel : non ancrée, sans collision ni masse, ignorée des rayons"
		)
	end
end
local weld = v1:FindFirstChild("CarryWeld", true)
check(weld ~= nil and weld.Part0 == headA and weld.Part1 == block, "soudure Head → pièce d'accroche")
check(cfClose(weld.C0, CFrame.new(0, 0.6 + 0.25, 0)), "C0 = haut de la tête + 0,25")
check(cfClose(block.CFrame * weld.C1, headA.CFrame * weld.C0), "visuel déjà placé là où la soudure le met")
check(math.abs(block.CFrame.Position.Y - (4.6 + 0.6 + 0.25 + 0.8)) < 1e-6, "dessous du colis juste au-dessus de la tête")
local halo = block:FindFirstChild("HaloPoint")
check(halo ~= nil and cfClose(halo.CFrame, CFrame.identity), "halo au centre du colis")
check(count(v1, "PointLight") == 1 and v1:FindFirstChildWhichIsA("PointLight", true).Range == 10, "halo Rare = net (lumière 10)")
check(count(v1, "ParticleEmitter") == 1 and v1:FindFirstChildWhichIsA("ParticleEmitter", true).Rate == 10, "halo Rare : 10 particules/s")
check(count(v1, "Beam") == 0, "halo Rare : pas de rayons")
local labelPoint = block:FindFirstChild("LabelPoint")
check(labelPoint ~= nil and cfClose(labelPoint.CFrame, CFrame.new(0, 0.8, 0)), "étiquette au sommet du colis")
local gui = v1:FindFirstChild("BB_Box", true)
check(gui ~= nil and gui:IsA("BillboardGui") and gui.Adornee == labelPoint, "étiquette V0 BB_Box accrochée au LabelPoint")
check(v1:FindFirstChild("BB_Carry", true) == nil, "colis PNJ : pas de BB_Carry (L-031)")
check(gui and gui.MaxDistance == 32, "étiquette V0 : portée 32 (ShelfBoxes.V0LabelMaxDistance)")
local rarityLabel = gui and gui:FindFirstChild("Rarity", true)
check(rarityLabel ~= nil and rarityLabel.Text == Rarities.ById.Rare.DisplayNameUpper and rarityLabel.TextColor3 == Rarities.ById.Rare.Color, "étiquette V0 : rareté Rare en bleu")
check(not v1:HasTag("CarryRainbow"), "pas d'arc-en-ciel pour Rare")
check(logCount("PRINT", "BOX_Premium pas encore livré") == 1, "BOX_Premium manquant signalé une fois")
check(logCount("PRINT", "BB_Box pas encore livré") == 1, "BB_Box manquant signalé une fois")
check(logCount("WARN", "") == 0, "aucun avertissement sur un portage normal")

---------------------------------------------------------------- 2. refus
section("2. Refus")
clearLog()
check(Carry.StartCarry(A, npc({ SlotId = "ShelfSlot_01" })) == false, "refus : porte déjà")
check(logCount("WARN", "") == 0, "porte déjà : refus silencieux")
check(Carry.StartCarry(B, p1) == false, "refus : même payload déjà porté")
check(logCount("WARN", "déjà porté ou au sol") == 1, "doublon signalé")
local bad = {
	{ npc({ Rarity = "Shiny" }), "rareté inconnue" },
	{ npc({ ItemId = "Z1_Inconnu" }), "objet inconnu" },
	{ npc({ Rarity = "Epic" }), "est Rare, pas Epic" },
	{ npc({ Zone = 2 }), "zone 1, pas de la zone 2" },
	{ npc({ Zone = 7 }), "zone inconnue" },
	{ npc({ Zone = 1.5 }), "zone inconnue" },
	{ npc({ Tier = "Gold" }), "type de colis inconnu" },
	{ npc({ StoreId = "" }), "StoreId ou SlotId manquant" },
	{ npc({ Kind = "Pet" }), "Kind inconnu" },
	{ "texte", "payload absent" },
}
for _, case in bad do
	clearLog()
	check(Carry.StartCarry(B, case[1]) == false, "refus : " .. case[2])
	check(logCount("WARN", case[2]) == 1, "avertissement : " .. case[2])
end
check(not Carry.IsCarrying(B) and B:GetAttribute("Carrying") == nil, "aucun effet après un refus")
local C = newPlayer("Chloe")
clearLog()
check(Carry.StartCarry(C, npc({ SlotId = "c" })) == false, "refus : pas de personnage")
local charC, humC = spawnCharacter(C, 40)
humC.Health = 0
check(Carry.StartCarry(C, npc({ SlotId = "c" })) == false, "refus : personnage mort")
humC.Health = 100
charC.Head:Destroy()
check(Carry.StartCarry(C, npc({ SlotId = "c" })) == false, "refus : pas de tête")
check(logCount("WARN", "") == 0, "refus de personnage silencieux")
check(#started == 1, "aucun OnCarryStarted pour un refus")

---------------------------------------------------------------- 3. Consume
section("3. Consume")
clearLog()
local returned = Carry.Consume(A)
check(returned == p1, "Consume renvoie le payload")
check(not Carry.IsCarrying(A) and Carry.GetPayload(A) == nil, "plus rien porté")
check(A:GetAttribute("Carrying") == nil, "attribut retiré")
check(Stats.modifiers[A].Carry == nil, "malus retiré")
check(isDestroyed(v1) and visualOf(charA) == nil, "visuel détruit")
local e = lastEnded()
check(e.player == A and e.payload == p1 and e.result == "Consumed" and e.reason == "Consumed", "OnCarryEnded(…, Consumed, Consumed)")
check(Carry.Consume(A) == nil, "Consume sans rien porter : nil")
check(Carry.Fail(A, "Caught") == false, "Fail sans rien porter : false")
fists.Parent = charA
flush()
check(fists.Parent == charA, "après le portage, on peut ressortir un outil")
check(Carry.StartCarry(B, p1) == true, "un payload rendu peut être repris")
check(Carry.Consume(B, "Placed") == p1 and lastEnded().reason == "Placed", "Consume avec raison")

---------------------------------------------------------------- 4. échecs
section("4. Échecs : capture, mort, départ, personnage retiré, anomalie")
local p2 = npc({ SlotId = "ShelfSlot_02", Rarity = "Common", ItemId = "Z1_CanetteDeSoda", Tier = "Standard" })
check(Carry.StartCarry(A, p2), "portage d'un Commun")
check(count(visualOf(charA), "PointLight") == 0 and count(visualOf(charA), "ParticleEmitter") == 0, "Commun : aucun halo")
check(Carry.Fail(A, "Caught") == true, "Fail renvoie true")
e = lastEnded()
check(e.result == "Failed" and e.reason == "Caught" and e.payload == p2, "OnCarryEnded(…, Failed, Caught)")
check(Stats.modifiers[A].Carry == nil and A:GetAttribute("Carrying") == nil, "Fail retire malus et attribut")

check(Carry.StartCarry(A, p2), "reprise pour la mort")
local visualDeath = visualOf(charA)
humA.Health = 0
humA.Died:Fire()
e = lastEnded()
check(e.result == "Failed" and e.reason == "Died", "mort : Failed, Died")
check(isDestroyed(visualDeath) and Stats.modifiers[A].Carry == nil, "mort : visuel et malus retirés")
charA, humA, headA = spawnCharacter(A, 0)

check(Carry.StartCarry(A, p2), "reprise pour le départ")
Players.PlayerRemoving:Fire(A)
e = lastEnded()
check(e.result == "Failed" and e.reason == "Left", "départ : Failed, Left")

check(Carry.StartCarry(A, p2), "reprise pour le personnage retiré")
charA.Parent = nil
e = lastEnded()
check(e.result == "Failed" and e.reason == "CharacterRemoved", "personnage retiré : Failed, CharacterRemoved")
charA, humA, headA = spawnCharacter(A, 0)

local D = newPlayer("Dan")
local charD = spawnCharacter(D, 60)
check(Carry.StartCarry(D, p2), "portage avant une déconnexion")
D.Parent = nil
charD.Parent = nil
e = lastEnded()
check(e.player == D and e.reason == "Left", "personnage retiré après le départ du joueur : Left")
Players.PlayerRemoving:Fire(D)
check(lastEnded() == e, "PlayerRemoving après coup : pas de deuxième fin")

clearLog()
check(Carry.ReportAnomaly(A, "Teleport") == false, "anomalie sans portage : false")
check(logCount("WARN", "") == 0, "anomalie sans portage : rien écrit")
check(Carry.StartCarry(A, p2), "reprise pour l'anomalie")
check(Carry.ReportAnomaly(A, "Teleport 42 studs") == true, "ReportAnomaly renvoie true")
check(logCount("WARN", "Teleport 42 studs") == 1, "anomalie journalisée avec son détail")
e = lastEnded()
check(e.result == "Failed" and e.reason == "Anomaly", "anomalie : Failed, Anomaly")

---------------------------------------------------------------- 5. outils pendant le portage
section("5. Outils pendant le portage")
local hammer = make("Tool", { Name = "Marteau" }, A.Backpack)
check(Carry.StartCarry(A, p2), "portage")
hammer.Parent = charA
check(hammer.Parent == charA, "outil en main juste après l'équipement (avant defer)")
flush()
check(hammer.Parent == A.Backpack, "outil rangé au tour suivant")
Carry.Consume(A)
hammer.Parent = charA
flush()
check(hammer.Parent == charA, "plus de rangement après le portage")
hammer.Parent = A.Backpack

---------------------------------------------------------------- 6. modèles de Clément
section("6. BOX_Luxe et BB_Carry de Clément")
local assets = make("Folder", { Name = "Assets" }, ReplicatedStorage)
local boxes = make("Folder", { Name = "Boxes" }, assets)
local luxe = make("Model", { Name = "BOX_Luxe" }, boxes)
local body = make("Part", { Name = "Body", Size = Vector3.new(2, 1.5, 2), CFrame = CFrame.new(100, 0.75, 100), Anchored = true }, luxe)
local lid = make("Part", { Name = "Lid", Size = Vector3.new(2.1, 0.2, 2.1), CFrame = CFrame.new(100, 1.6, 100), Anchored = true }, luxe)
local band = make("Part", { Name = "Tint", Size = Vector3.new(2.05, 0.4, 2.05), CFrame = CFrame.new(100, 0.75, 100), Anchored = true }, luxe)
make("Attachment", { Name = "CarryAttachment", CFrame = CFrame.new(0, -0.75, 0) }, body)
-- LabelPoint de Clément : devant le colis, 0,35 stud au-dessus (L-031).
local deliveredPoint = make("Attachment", { Name = "LabelPoint", CFrame = CFrame.new(0, 1.1, -1) }, body)
make("Script", { Name = "Cache" }, luxe)
make("ProximityPrompt", { Name = "Prompt" }, lid)
luxe.PrimaryPart = body
local ui = make("Folder", { Name = "UI" }, assets)
local bb = make("BillboardGui", { Name = "BB_Carry", StudsOffset = Vector3.new(0, 1, 0) }, ui)
local card = make("Frame", { Name = "Card" }, bb)
make("TextLabel", { Name = "ItemName" }, card)
make("TextLabel", { Name = "Rarity" }, card)
make("TextLabel", { Name = "Income" }, card)
-- BB_Box de Clément (L-031) : Lines/Category, Lines/Rarity, Lines/Mutation, AlwaysOnTop, 32 studs.
local bbBox = make("BillboardGui", { Name = "BB_Box", StudsOffset = Vector3.new(0, 0.9, 0), AlwaysOnTop = true, MaxDistance = 32 }, ui)
local lines = make("Frame", { Name = "Lines" }, bbBox)
make("TextLabel", { Name = "Category", Text = "DRINK" }, lines)
make("TextLabel", { Name = "Rarity", Text = "COMMON" }, lines)
make("TextLabel", { Name = "Mutation", Text = "GOLD" }, lines)

clearLog()
local p3 = npc({ Tier = "Luxe", Zone = 2, Rarity = "Legendary", ItemId = "Z2_PelucheGeante", StoreId = "STORE_Z2_Jouets", SlotId = "ShelfSlot_10" }) -- a22 : Ticket retiré
check(Carry.StartCarry(A, p3), "portage d'un colis Luxe Légendaire")
local v3 = visualOf(charA)
check(v3:FindFirstChildWhichIsA("LuaSourceContainer", true) == nil, "script retiré de la copie")
check(v3:FindFirstChild("Prompt", true) == nil, "invite retirée de la copie")
local vBody, vLid, vTint = v3:FindFirstChild("Body"), v3:FindFirstChild("Lid"), v3:FindFirstChild("Tint")
check(vBody and vLid and vTint, "pièces du modèle copiées")
check(not vBody.Anchored and not vLid.Anchored and not vTint.Anchored, "pièces désancrées")
check(vTint.Color == Rarities.ById.Legendary.Color, "pièce Tint à la couleur Légendaire")
check(vBody.Color == body.Color and vLid.Color == lid.Color, "les autres pièces gardent leur couleur")
check(count(v3, "WeldConstraint") == 2, "Lid et Tint soudés à la pièce d'accroche")
local w3 = v3:FindFirstChild("CarryWeld", true)
check(w3.Part1 == vBody and cfClose(w3.C1, CFrame.new(0, -0.75, 0)), "soudure par le CarryAttachment")
check(cfClose(vBody.CFrame * w3.C1, headA.CFrame * w3.C0), "CarryAttachment posé sur la tête")
check(math.abs((vLid.CFrame.Position.Y - vBody.CFrame.Position.Y) - 0.85) < 1e-6, "positions relatives gardées")
check(count(v3, "Beam") == 8 and v3:FindFirstChildWhichIsA("PointLight", true).Range == 14, "halo Légendaire : rayons")
local g3 = v3:FindFirstChild("BB_Box", true)
check(v3:FindFirstChild("BB_Carry", true) == nil, "colis PNJ porté : BB_Box, pas BB_Carry (L-031)")
check(
	g3 ~= nil and g3 ~= bbBox and g3.StudsOffset == bbBox.StudsOffset and g3.AlwaysOnTop == true and g3.MaxDistance == 32,
	"copie de BB_Box (décalage, AlwaysOnTop et MaxDistance de Clément gardés)"
)
local copiedPoint = vBody:FindFirstChild("LabelPoint")
check(copiedPoint ~= nil and g3.Adornee == copiedPoint and g3.Parent == copiedPoint, "BB_Box accrochée au LabelPoint livré")
check(cfClose(copiedPoint.CFrame, deliveredPoint.CFrame), "LabelPoint de Clément gardé tel quel")
local r3 = g3:FindFirstChild("Rarity", true)
check(r3.Text == Rarities.ById.Legendary.DisplayNameUpper and r3.TextColor3 == Rarities.ById.Legendary.Color, "Rarity = Légendaire en capitales, en or")
local c3 = g3:FindFirstChild("Category", true)
-- Copie a109 (vague 32, Features.ShelfOpen) : sur une caisse, la rareté seule ; la catégorie est cachée.
-- Arbre d'avant la vague 32 (pas de BOX_LABEL_RARITY_ONLY) : l'ancien contrôle.
A109_RARITY_ONLY = string.find(SOURCES["server/Services/CarryService.luau"], "BOX_LABEL_RARITY_ONLY", 1, true) ~= nil
	and string.find(SOURCES["shared/Config/Features.luau"], "ShelfOpen = true", 1, true) ~= nil
if A109_RARITY_ONLY then
	check(c3.Visible == false, "a109 : Category cachée sur le colis porté (vague 32, rareté seule)")
else
	check(c3.Visible == true and c3.Text == "Plush", "Category = catégorie de l'objet (Plush, catalogue v2)")
end
check(g3:FindFirstChild("Mutation", true).Visible == false, "Mutation cachée (MAJ 4)")
local leaked = false
for _, d in v3:GetDescendants() do
	if d:IsA("TextLabel") and (string.find(d.Text, "Giant Plush", 1, true) or string.find(d.Text, "Z2_", 1, true)) then
		leaked = true
	end
	if d:GetAttribute("ItemId") ~= nil then
		leaked = true
	end
end
check(not leaked, "ni le nom ni l'ItemId de l'objet sur le colis porté (5.7)")
check(luxe:FindFirstChildWhichIsA("LuaSourceContainer", true) ~= nil and body.Anchored, "modèle d'origine intact")
check(bb.Card.Rarity.Text == "Label" and bbBox.Lines.Rarity.Text == "COMMON", "BB_Carry et BB_Box d'origine intacts")
check(logCount("WARN", "") == 0, "aucun avertissement avec les modèles de Clément")
Carry.Consume(A)

-- Modèle mal formé : Luxe sans Tint, puis sans pièce.
band.Name = "Bande"
clearLog()
check(Carry.StartCarry(A, p3), "colis sans Tint : porté quand même")
check(logCount("WARN", "aucune pièce Tint") == 1, "colis sans Tint signalé")
Carry.Consume(A)
check(Carry.StartCarry(A, p3), "deuxième fois")
check(logCount("WARN", "aucune pièce Tint") == 1, "signalé une seule fois")
Carry.Consume(A)
band.Name = "Tint"

---------------------------------------------------------------- 7. objet volé à un joueur
section("7. Objet volé (PlayerItem, M3)")
local items = make("Folder", { Name = "Items" }, assets)
local phone = make("Model", { Name = "ITM_Z3_Smartphone" }, items)
local root = make("Part", { Name = "Root", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(50, 0.1, 50), PivotOffset = CFrame.new(0, -0.1, 0) }, phone)
local screen = make("Part", { Name = "Screen", Size = Vector3.new(0.8, 1.6, 0.1), CFrame = CFrame.new(50, 1, 50) }, phone)
phone.PrimaryPart = root
local item = { Kind = "PlayerItem", ItemUid = "uid-1", ItemId = "Z3_Smartphone", Rarity = "Rare", Income = 12400, VictimUserId = 99, SlotIndex = 3 }
clearLog()
check(Carry.StartCarry(B, item), "portage d'un objet volé")
check(Stats.modifiers[B].Fixed == Balance.Carry.StolenItemWalkSpeed and Stats.modifiers[B].Carry == nil, "objet volé : vitesse fixe (2026-11-13)")
local v4 = visualOf(charB)
check(v4:FindFirstChildWhichIsA("Highlight", true) ~= nil, "contour rouge de l'objet volé")
check(v4:FindFirstChild("Root").Color == root.Color, "objet non teint")
local w4 = v4:FindFirstChild("CarryWeld", true)
check(w4.Part1 == v4:FindFirstChild("Root") and cfClose(w4.C1, CFrame.new(0, -0.1, 0)), "objet soudé par son pivot (base)")
local g4 = v4:FindFirstChild("BB_Carry", true)
check(g4 ~= nil and v4:FindFirstChild("BB_Box", true) == nil, "objet volé : BB_Carry, pas BB_Box")
check(g4:FindFirstChild("ItemName", true).Text == "Smartphone", "nom de l'objet affiché")
check(g4:FindFirstChild("Income", true).Text == "+$12.4K/s" and g4:FindFirstChild("Income", true).Visible, "revenu affiché +$12.4K/s (Format.income)")
check(Carry.StartCarry(C, table.clone(item)) == false, "même uid dans une autre table : doublon refusé")
check(Carry.Drop(B, Vector3.new(0, 0, 0)) == nil, "Drop d'un objet volé : nil")
e = lastEnded()
check(e.result == "Failed" and e.reason == "Bat", "Drop d'un objet volé : Failed, Bat")
check(Workspace:FindFirstChild("CarryDrops") == nil, "un objet volé ne va jamais au sol")
local badItem = table.clone(item)
badItem.Income = -1
badItem.ItemUid = "uid-2"
check(Carry.StartCarry(B, badItem) == false, "revenu négatif refusé")

---------------------------------------------------------------- 8. Secret
section("8. Secret arc-en-ciel")
local p5 = npc({ Tier = "Luxe", Zone = 3, Rarity = "Secret", ItemId = "Secret_ChatPorteBonheurDore", StoreId = "STORE_Z3_Electronique", SlotId = "ShelfSlot_10" })
check(Carry.StartCarry(B, p5), "Secret : valide quelle que soit la zone")
local v5 = visualOf(charB)
check(v5:HasTag("CarryRainbow"), "tag CarryRainbow posé")
local sparkles = v5:FindFirstChildWhichIsA("ParticleEmitter", true)
check(#sparkles.Color.Keypoints == 5, "particules arc-en-ciel (5 couleurs)")
check(count(v5, "Beam") == 8, "Secret : rayons")
Carry.Consume(B)

---------------------------------------------------------------- 9. colis au sol (M3)
section("9. Drop, ramassage, expiration (M3)")
local p6 = npc({ Zone = 2, Rarity = "Epic", ItemId = "Z2_RobotJouet", StoreId = "STORE_Z2_Jouets", SlotId = "ShelfSlot_08" }) -- a22 : la Boisson énergisante est Commune en v2
check(Carry.StartCarry(A, p6), "portage avant le coup de batte")
local dropId = Carry.Drop(A, Vector3.new(10, 0, 20))
check(dropId == "Drop_1", "Drop renvoie un dropId")
e = lastEnded()
check(e.player == A and e.result == "Dropped" and e.reason == "Bat", "OnCarryEnded(…, Dropped, Bat)")
check(not Carry.IsCarrying(A) and Stats.modifiers[A].Carry == nil and A:GetAttribute("Carrying") == nil, "le porteur ne porte plus")
local folder = Workspace:FindFirstChild("CarryDrops")
local dropModel = folder and folder:FindFirstChild(dropId)
check(dropModel ~= nil and dropModel:GetAttribute("DropId") == dropId, "colis au sol dans Workspace/CarryDrops")
local dropTint = dropModel:FindFirstChild("Tint", true)
check(dropTint.Anchored and dropTint.Color == Rarities.ById.Epic.Color, "colis au sol ancré, à sa couleur")
check(math.abs(dropTint.CFrame.Position.Y - 0.8) < 1e-6 and dropTint.CFrame.Position.X == 10, "posé sur le point donné")
check(dropModel:FindFirstChild("BB_Box", true) ~= nil, "étiquette BB_Box sur le colis au sol")
local payloadOnGround, position = Carry.GetDrop(dropId)
check(payloadOnGround == p6 and position == Vector3.new(10, 0, 20), "GetDrop")
check(Carry.StartCarry(B, p6) == false, "colis au sol : StartCarry direct refusé (doublon)")
check(Carry.PickUpDrop(B, dropId) == true, "ramassage par un autre joueur")
check(Carry.GetPayload(B) == p6, "même payload (même rareté, même objet caché)")
check(isDestroyed(dropModel) and Carry.GetDrop(dropId) == nil, "colis retiré du sol")
check(Carry.PickUpDrop(A, dropId) == false, "pas de second ramassage")
local dropId2 = Carry.Drop(B, Vector3.new(30, 0, 0))
check(dropId2 == "Drop_2", "deuxième chute")
check(Carry.PickUpDrop(C, dropId2) == false and Carry.GetDrop(dropId2) == p6, "ramasseur sans personnage : refus, colis toujours au sol")
check(Carry.StartCarry(A, npc({ SlotId = "occupé" })), "A porte autre chose")
check(Carry.PickUpDrop(A, dropId2) == false, "ramasseur qui porte déjà : refus")
Carry.Consume(A)
advance(Bat.DroppedLifetime - 0.1)
check(Carry.GetDrop(dropId2) == p6 and #expired == 0, "encore au sol juste avant 15 s")
advance(0.2)
check(Carry.GetDrop(dropId2) == nil, "rendu après 15 s")
check(#expired == 1 and expired[1].dropId == dropId2 and expired[1].payload == p6, "OnDropExpired(dropId, payload)")
check(Carry.StartCarry(A, p6), "le colis rendu peut être repris")
Carry.Consume(A)
local dropId3
check(Carry.StartCarry(A, p6), "portage")
dropId3 = Carry.Drop(A, Vector3.new(0, 0, 0))
check(Carry.PickUpDrop(B, dropId3), "ramassé avant 15 s")
advance(20)
check(#expired == 1, "ramassé : pas d'expiration ensuite")
Carry.Consume(B)

---------------------------------------------------------------- 10. écouteurs
section("10. Écouteurs : erreur, déconnexion, réentrance")
local calls = 0
local off = Carry.OnCarryStarted(function()
	calls += 1
end)
QUIET_ERRORS = true
local offError = Carry.OnCarryStarted(function()
	error("écouteur en erreur (attendu)")
end)
check(Carry.StartCarry(A, npc({ SlotId = "e1" })), "StartCarry malgré un écouteur en erreur")
QUIET_ERRORS = false
offError()
check(EXPECTED_ERRORS == 1, "l'erreur de l'écouteur reste dans sa tâche")
check(calls == 1 and Carry.IsCarrying(A), "les autres écouteurs sont appelés")
off()
Carry.Consume(A)
check(Carry.StartCarry(A, npc({ SlotId = "e2" })), "portage après déconnexion")
check(calls == 1, "écouteur déconnecté plus appelé")
Carry.Consume(A)
local relaunch = npc({ SlotId = "e3" })
local offEnded
offEnded = Carry.OnCarryEnded(function(player, _payload, result)
	if player == A and result == "Failed" then
		offEnded()
		Carry.StartCarry(A, relaunch)
	end
end)
check(Carry.StartCarry(A, npc({ SlotId = "e4" })), "portage")
Carry.Fail(A, "Caught")
check(Carry.GetPayload(A) == relaunch, "StartCarry depuis OnCarryEnded : fonctionne")
Carry.Consume(A)

---------------------------------------------------------------- 11. contrôleur client
section("11. CarryController (client)")
Players.LocalPlayer = A
local Controller = requireModule(controllerModule, "client")
local Anim = requireModule(animModule, "client")
Controller.Start()
check(#Anim.calls == 0 and Controller.IsCarrying() == false, "rien au démarrage sans portage")
check(Carry.StartCarry(A, npc({ SlotId = "k1" })), "portage côté serveur")
check(#Anim.calls == 1 and Anim.calls[1] == true and Controller.IsCarrying(), "SetCarrying(true) via l'attribut")
local unequipBefore = unequipCalls(humA)
hammer.Parent = charA
flush()
check(hammer.Parent == A.Backpack and unequipCalls(humA) >= unequipBefore + 2, "outil rangé aussi par le client")
check(jumpState(humA) == nil, "saut autorisé : état de saut jamais touché")
Carry.Consume(A)
check(#Anim.calls == 2 and Anim.calls[2] == false and not Controller.IsCarrying(), "SetCarrying(false) à la fin")
check(Carry.StartCarry(A, npc({ SlotId = "k2" })), "nouveau portage")
check(#Anim.calls == 3 and Anim.calls[3] == true, "SetCarrying(true) de nouveau")
humA.Health = 0
humA.Died:Fire()
check(#Anim.calls == 4 and Anim.calls[4] == false, "mort : SetCarrying(false)")
charA, humA, headA = spawnCharacter(A, 0)
hammer.Parent = charA
flush()
check(hammer.Parent == charA, "nouveau personnage sans portage : outil libre")
hammer.Parent = A.Backpack

-- Arc-en-ciel
local p7 = npc({ Tier = "Luxe", Zone = 1, Rarity = "Secret", ItemId = "Secret_ChatPorteBonheurDore", SlotId = "k3" })
check(Carry.StartCarry(B, p7), "Secret porté par un autre joueur")
local v7 = visualOf(charB)
local tint7 = v7:FindFirstChild("Tint", true)
local light7 = v7:FindFirstChildWhichIsA("PointLight", true)
local label7 = v7:FindFirstChild("Rarity", true)
check(RENDER_STEPPED:ConnectionCount() == 1, "animation branchée tant qu'un Secret existe")
local function expectedRainbow(t)
	local colors = Rarities.ById.Secret.RainbowColors
	local position = (t / 2) % 1 * #colors -- un tour en 2 s
	local index = math.floor(position)
	return colors[index + 1]:Lerp(colors[(index + 1) % #colors + 1], position - index)
end
RENDER_STEPPED:Fire(1 / 60)
local first = expectedRainbow(now())
check(tint7.Color == first and light7.Color == first and label7.TextColor3 == first, "couleurs arc-en-ciel posées en local")
advance(0.3)
RENDER_STEPPED:Fire(1 / 60)
local second = expectedRainbow(now())
check(not (second == first) and tint7.Color == second and label7.TextColor3 == second, "couleurs qui changent avec le temps")
Carry.Consume(B)
check(RENDER_STEPPED:ConnectionCount() == 0, "animation débranchée sans Secret")
check(Carry.StartCarry(B, npc({ Tier = "Luxe", Zone = 1, Rarity = "Secret", ItemId = "Secret_ChatPorteBonheurDore", SlotId = "k4" })), "Secret au sol")
local dropSecret = Carry.Drop(B, Vector3.new(5, 0, 5))
check(RENDER_STEPPED:ConnectionCount() == 1, "colis Secret au sol animé aussi")
advance(Bat.DroppedLifetime + 1)
check(Carry.GetDrop(dropSecret) == nil and RENDER_STEPPED:ConnectionCount() == 0, "débranché à l'expiration")

---------------------------------------------------------------- 12. étiquette des colis du rayon (a17)
section("12. AttachBoxLabel : étiquette des colis du rayon (L-031)")
-- Colis du rayon façon StoreHeistService : copie ancrée de BOX_Luxe, sans script.
local function shelfCopy(name)
	local copy = luxe:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	copy.Name = name
	copy.Parent = Workspace
	return copy
end
local shelfBox = shelfCopy("ShelfBox_10")
clearLog()
local sg = Carry.AttachBoxLabel(shelfBox, "Rare", "Z1_PotDeNouilles")
check(sg ~= nil and sg.Name == "BB_Box" and sg:IsA("BillboardGui"), "AttachBoxLabel renvoie la copie de BB_Box")
local shelfPoint = shelfBox.Body:FindFirstChild("LabelPoint")
check(sg.Adornee == shelfPoint and sg.Parent == shelfPoint, "accrochée au LabelPoint du colis")
check(sg.StudsOffset == bbBox.StudsOffset and sg.AlwaysOnTop == true and sg.MaxDistance == 32, "réglages de Clément gardés")
check(
	sg.Lines.Rarity.Text == Rarities.ById.Rare.DisplayNameUpper and sg.Lines.Rarity.TextColor3 == Rarities.ById.Rare.Color,
	"rareté en capitales, à sa couleur"
)
if A109_RARITY_ONLY then
	check(sg.Lines.Category.Visible == false, "a109 : catégorie cachée sur le colis du rayon (vague 32, rareté seule)")
else
	check(sg.Lines.Category.Visible == true and sg.Lines.Category.Text == "Snack", "a22 : catégorie de l'objet dès le rayon (Snack, catalogue v2)")
end
check(sg.Lines.Mutation.Visible == false, "mutation cachée")
check(not sg:HasTag("CarryRainbow") and not shelfBox:HasTag("CarryRainbow"), "pas d'arc-en-ciel pour Rare")
check(shelfBox.Tint.Color == band.Color, "colis du rayon pas teint (aspect de son type)")
check(logCount("WARN", "") == 0, "aucun avertissement")

local shelfSecret = shelfCopy("ShelfBox_09")
local sg2 = Carry.AttachBoxLabel(shelfSecret, "Secret", "Secret_ChatPorteBonheurDore")
check(sg2:HasTag("CarryRainbow") and not shelfSecret:HasTag("CarryRainbow"), "Secret : tag CarryRainbow sur l'étiquette seule")
check(RENDER_STEPPED:ConnectionCount() == 1, "client : arc-en-ciel branché pour l'étiquette du rayon")
advance(0.1)
RENDER_STEPPED:Fire(1 / 60)
local shelfColor = expectedRainbow(now())
check(sg2.Lines.Rarity.TextColor3 == shelfColor, "client : rareté du Secret animée")
check(shelfSecret.Tint.Color == band.Color, "client : le colis Secret du rayon garde sa couleur")
shelfSecret:Destroy()
flush()
check(RENDER_STEPPED:ConnectionCount() == 0, "client : débranché quand le colis disparaît")

-- Bloc V0 sans LabelPoint : point créé au sommet.
local v0 = make("Model", { Name = "ShelfBox_01" }, Workspace)
local v0Body = make("Part", { Name = "Body", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(0, 0.6, 50), Anchored = true, PivotOffset = CFrame.new(0, -0.6, 0) }, v0)
v0.PrimaryPart = v0Body
local sg3 = Carry.AttachBoxLabel(v0, "Common", "Z1_CanetteDeSoda")
local v0Point = v0Body:FindFirstChild("LabelPoint")
check(sg3 ~= nil and v0Point ~= nil and cfClose(v0Point.CFrame, CFrame.new(0, 0.6, 0)), "sans LabelPoint : point créé au sommet du bloc")
check(sg3.Adornee == v0Point, "étiquette accrochée au point créé")

clearLog()
check(Carry.AttachBoxLabel(v0, "Shiny", "Z1_CanetteDeSoda") == nil and logCount("WARN", "inconnu") == 1, "rareté inconnue : nil et avertissement")
check(Carry.AttachBoxLabel(v0, "Common", "Z9_Rien") == nil and logCount("WARN", "inconnu") == 2, "objet inconnu : nil et avertissement")
check(Carry.AttachBoxLabel(make("Model", { Name = "Vide" }, Workspace), "Common", "Z1_CanetteDeSoda") == nil, "modèle sans pièce : nil")

---------------------------------------------------------------- bilan
print(string.format("%d vérification(s), %d échec(s)", CHECKS, FAILS))
if FAILS > 0 then
	print("Sortie des modules :")
	dumpLog()
end
