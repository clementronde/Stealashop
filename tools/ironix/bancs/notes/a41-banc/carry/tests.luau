--!nocheck
-- Banc a41 (2026-11-08, liaison L-071, point 4), partie portage : avec le vrai CarryService, tout ce
-- qui se porte est soudé à la tête, Balance.Carry.HeadGap au-dessus (colis du rayon, modèle de
-- Clément avec CarryAttachment, objet volé, colis tombé après un coup de batte, colis du camion) ;
-- avec le vrai CarryController, le colis du porteur reste caché tant que Grab ne l'a pas posé
-- (AnimationController.AfterGrab, ici un bouchon piloté). HEAD_GAP_OVERRIDE (posé par run.sh) :
-- deuxième passe avec une autre hauteur dans Config/Balance, pour prouver qu'elle est lue.

if HEAD_GAP_OVERRIDE then
	local source, n = string.gsub(SOURCES["shared/Config/Balance.luau"], "HeadGap = [%d%.]+", "HeadGap = " .. HEAD_GAP_OVERRIDE)
	assert(n == 1, "HeadGap introuvable dans Config/Balance")
	SOURCES["shared/Config/Balance.luau"] = source
end

---------------------------------------------------------------- bouchons
SOURCES["stub/StatsService"] = [[
local StatsService = { calls = {}, modifiers = {} }
function StatsService.SetSpeedModifier(player, key, multiplier)
	table.insert(StatsService.calls, { player = player, key = key, multiplier = multiplier })
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player][key] = multiplier
end
function StatsService.SetFixedSpeed(player, walkSpeed) -- vitesse fixe (objet volé, Cantin 2026-11-13)
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player].Fixed = walkSpeed
end
return StatsService
]]
-- AnimationController : SetCarrying noté ; AfterGrab différé si deferNext (release() le termine).
SOURCES["stub/AnimationController"] = [[
local A = { calls = {}, deferNext = false, pending = {} }
function A.SetCarrying(on)
	table.insert(A.calls, on)
end
function A.AfterGrab(callback)
	if A.deferNext then
		table.insert(A.pending, callback)
		return true
	end
	callback(false)
	return false
end
function A.release()
	local list = A.pending
	A.pending = {}
	for _, callback in list do
		callback(true)
	end
end
return A
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
moduleScript(services, "StatsService", "stub/StatsService")
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = make("Folder", { Name = "Client" }, sps)
local controllers = make("Folder", { Name = "Controllers" }, clientFolder)
local controllerModule = moduleScript(controllers, "CarryController", "client/Controllers/CarryController.luau")
local animModule = moduleScript(controllers, "AnimationController", "stub/AnimationController")

local Carry = requireModule(carryModule, "server")
local Balance = requireModule(shared.Config.Balance, "server")
Carry.Init()
local GAP = Balance.Carry.HeadGap
print(`== HeadGap = {GAP}`)
if HEAD_GAP_OVERRIDE then
	check(math.abs(GAP - tonumber(HEAD_GAP_OVERRIDE)) < 1e-9 and math.abs(GAP - 0.25) > 1e-6, `hauteur modifiée dans Config/Balance : {GAP}`)
end

---------------------------------------------------------------- aides
local userIds = 0
local function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	return player
end
local function spawnCharacter(player, x)
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
		Tier = "Standard",
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
local function section(name)
	print("--- " .. name)
end
-- Le visuel porté par `character` est-il soudé à sa tête, son point d'accroche GAP au-dessus du haut
-- de la tête ? Renvoie aussi le visuel.
local function weldedOnHead(character, head)
	local visual = character:FindFirstChild("CarryVisual")
	local weld = visual and visual:FindFirstChild("CarryWeld", true)
	if weld == nil then
		return false, visual
	end
	local anchor = weld.Part1
	local okC0 = cfClose(weld.C0, CFrame.new(0, head.Size.Y / 2 + GAP, 0))
	local okPlace = cfClose(anchor.CFrame * weld.C1, head.CFrame * CFrame.new(0, head.Size.Y / 2 + GAP, 0))
	return weld.Part0 == head and okC0 and okPlace, visual
end

local A = newPlayer("Alice")
local charA, humA, headA = spawnCharacter(A, 0)
local B = newPlayer("Bob")
local charB, humB, headB = spawnCharacter(B, 20)
local C = newPlayer("Chloe")
local charC, humC, headC = spawnCharacter(C, 40)

---------------------------------------------------------------- H1 à H5 : hauteur sur la tête
section("H1 Colis du rayon (bloc V0) : soudé à la tête, HeadGap au-dessus")
local p1 = npc({ SlotId = "h1" })
check(Carry.StartCarry(A, p1), "portage")
local ok1, v1 = weldedOnHead(charA, headA)
check(ok1, `soudé à la tête, dessous du colis {GAP} stud au-dessus`)
local block = v1 and v1:FindFirstChild("Tint", true)
check(block and math.abs((block.CFrame.Position.Y - block.Size.Y / 2) - (4.6 + 0.6 + GAP)) < 1e-6, "dessous du bloc au bon niveau")
Carry.Consume(A)

section("H2 Modèle de Clément (BOX_Luxe) : par son CarryAttachment")
local assets = make("Folder", { Name = "Assets" }, ReplicatedStorage)
local boxes = make("Folder", { Name = "Boxes" }, assets)
local luxe = make("Model", { Name = "BOX_Luxe" }, boxes)
local body = make("Part", { Name = "Body", Size = Vector3.new(2, 1.5, 2), CFrame = CFrame.new(100, 0.75, 100), Anchored = true }, luxe)
make("Part", { Name = "Lid", Size = Vector3.new(2.1, 0.2, 2.1), CFrame = CFrame.new(100, 1.6, 100), Anchored = true }, luxe)
make("Part", { Name = "Tint", Size = Vector3.new(2.05, 0.4, 2.05), CFrame = CFrame.new(100, 0.75, 100), Anchored = true }, luxe)
local outlineBox = make("Part", { Name = "Outline", Size = Vector3.new(2.2, 1.7, 2.2), CFrame = CFrame.new(100, 0.85, 100), Anchored = true, Transparency = 1 }, luxe)
make("SelectionBox", { Name = "Edges", Adornee = outlineBox }, outlineBox)
make("Highlight", { Name = "OutlineHighlight" }, luxe)
make("Attachment", { Name = "CarryAttachment", CFrame = CFrame.new(0, -0.75, 0) }, body)
make("Attachment", { Name = "LabelPoint", CFrame = CFrame.new(0, 1.1, -1) }, body)
luxe.PrimaryPart = body
local p2 = npc({ Tier = "Luxe", Zone = 2, Rarity = "Legendary", ItemId = "Z2_PelucheGeante", StoreId = "STORE_Z2_Jouets", SlotId = "h2" })
check(Carry.StartCarry(A, p2), "portage d'un colis Luxe")
local ok2, v2 = weldedOnHead(charA, headA)
local vBody = v2 and v2:FindFirstChild("Body")
check(ok2 and vBody and v2:FindFirstChild("CarryWeld", true).Part1 == vBody, "soudé par le CarryAttachment du modèle, HeadGap au-dessus de la tête")
Carry.Consume(A)

section("H3 Objet volé à un joueur (PvP) : soudé de même")
local p3 = { Kind = "PlayerItem", ItemUid = "uid-h3", ItemId = "Z1_CanetteDeSoda", Rarity = "Common", Income = 1, VictimUserId = 99, SlotIndex = 1 }
check(Carry.StartCarry(B, p3), "portage d'un objet volé")
check((weldedOnHead(charB, headB)), "objet volé soudé à la tête, HeadGap au-dessus")
Carry.Consume(B)

section("H4 Colis tombé après un coup de batte, ramassé par un autre : soudé à sa tête")
local p4 = npc({ SlotId = "h4" })
check(Carry.StartCarry(A, p4), "Alice porte")
local dropId = Carry.Drop(A, Vector3.new(5, 0, 0))
check(dropId ~= nil and not Carry.IsCarrying(A), "coup de batte : colis au sol")
check(Carry.PickUpDrop(B, dropId), "Bob le ramasse")
check((weldedOnHead(charB, headB)), "sur la tête de Bob, HeadGap au-dessus")
Carry.Consume(B)

section("H5 Colis du camion posé au sol, ramassé : soudé de même")
local p5 = npc({ StoreId = "Truck_1", SlotId = "h5", Zone = 3, ItemId = "Z3_PcGamer", Rarity = "Legendary", Tier = "Premium" })
local truckDrop = Carry.PlaceDrop(p5, Vector3.new(60, 0, 0), 30)
check(truckDrop ~= nil, "colis du camion au sol")
check(Carry.PickUpDrop(C, truckDrop), "Chloé le ramasse")
check((weldedOnHead(charC, headC)), "sur la tête de Chloé, HeadGap au-dessus")
Carry.Consume(C)

---------------------------------------------------------------- H6 colis caché jusqu'au geste de Grab
section("H6 CarryController : colis du porteur caché pendant Grab, rendu au marqueur")
Players.LocalPlayer = A
local Controller = requireModule(controllerModule, "client")
local Anim = requireModule(animModule, "client")
Controller.Start()
local function hiddenState(visual)
	local parts, partsHidden, switches, switchesOff = 0, 0, 0, 0
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.LocalTransparencyModifier == 1 then
				partsHidden += 1
			end
		elseif d:IsA("LayerCollector") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Highlight") then
			switches += 1
			if d.Enabled == false then
				switchesOff += 1
			end
		elseif d:IsA("GuiBase3d") then
			switches += 1
			if d.Visible == false then
				switchesOff += 1
			end
		end
	end
	return parts, partsHidden, switches, switchesOff
end
Anim.deferNext = true
local p6 = npc({ Tier = "Luxe", Zone = 2, Rarity = "Legendary", ItemId = "Z2_PelucheGeante", StoreId = "STORE_Z2_Jouets", SlotId = "h6" })
check(Carry.StartCarry(A, p6), "Alice soulève un colis Luxe Légendaire pendant son Grab")
local v6 = charA:FindFirstChild("CarryVisual")
local parts, partsHidden, switches, switchesOff = hiddenState(v6)
check(parts >= 4 and partsHidden == parts, `toutes les pièces cachées en local ({partsHidden}/{parts})`)
check(switches >= 12 and switchesOff == switches, `étiquette BB_Box, halo (lumière, particules, 8 rayons), contours éteints ({switchesOff}/{switches})`)
check((weldedOnHead(charA, headA)), "le serveur l'a déjà soudé à la tête (rien n'attend côté serveur)")
check(A:GetAttribute("Carrying") == "Legendary" and #Anim.calls > 0 and Anim.calls[#Anim.calls] == true, "SetCarrying(true) appelé")
-- Bob soulève aussi pendant ce temps : son colis n'est pas celui du joueur local, jamais caché.
local p6b = npc({ SlotId = "h6b" })
check(Carry.StartCarry(B, p6b), "Bob porte aussi")
local _, bobHidden = hiddenState(charB:FindFirstChild("CarryVisual"))
check(bobHidden == 0, "le colis d'un autre joueur n'est jamais caché")
Anim.release() -- marqueur Grab
parts, partsHidden, switches, switchesOff = hiddenState(v6)
check(partsHidden == 0 and switchesOff == 0, "au marqueur Grab : tout réapparaît")
Carry.Consume(A)
Carry.Consume(B)
-- Sans Grab en cours : jamais caché.
Anim.deferNext = false
check(Carry.StartCarry(A, npc({ SlotId = "h6c" })), "portage sans Grab en cours")
local _, hidden2, _, off2 = hiddenState(charA:FindFirstChild("CarryVisual"))
check(hidden2 == 0 and off2 == 0, "rien de caché")
Carry.Consume(A)
-- Portage fini pendant l'attente : le visuel part, rien ne reste en attente.
Anim.deferNext = true
check(Carry.StartCarry(A, npc({ SlotId = "h6d" })), "portage pendant Grab")
Carry.Fail(A, "Caught")
check(charA:FindFirstChild("CarryVisual") == nil and not Controller.IsCarrying(), "rattrapée : colis retiré")
Anim.release()
Anim.deferNext = false
check(Carry.StartCarry(A, npc({ SlotId = "h6e" })), "portage suivant")
local _, hidden3 = hiddenState(charA:FindFirstChild("CarryVisual"))
check(hidden3 == 0, "le portage suivant n'est pas caché")
Carry.Consume(A)

print(string.format("%d vérification(s), %d échec(s)", CHECKS, FAILS))
if FAILS > 0 then
	print("Sortie des modules :")
	dumpLog()
end
