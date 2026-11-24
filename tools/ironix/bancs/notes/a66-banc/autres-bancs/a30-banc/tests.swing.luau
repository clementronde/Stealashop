--!nocheck
-- S. Le coup (BatService, SwingBat), à 3 joueurs : portée 7, recharge 0,8 s, angle, mur, une seule
-- cible (le voleur du frappeur d'abord), refus (zone safe, bouclier, immunité de 3 s, rien porté,
-- batte pas en main, frappeur qui porte ou étourdi), usage 1 en zone safe (Fail « Bat »), tiers hors
-- zone safe, usage 2 (colis au sol au point du coup, knockback, étourdissement de 2 s).

local Carry = serverModule("CarryService")
local BatS = serverModule("BatService")
local Bat = sharedModule("Config/Bat")
local Rarities = sharedModule("Config/Rarities")
startServer()

local A = newPlayer("Alice") -- frappeuse
local B = newPlayer("Bob") -- porteur
local C = newPlayer("Chloe") -- troisième joueuse
spawnCharacter(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
spawnCharacter(B, Vector3.new(85, 3, 0))
spawnCharacter(C, Vector3.new(120, 3, 20))
flush()

local uid = 0
-- Colis d'un magasin qui n'existe pas : pas de vigile, rien ne revient sur un rayon.
local function npcBox()
	uid += 1
	return { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Donut", StoreId = "STORE_TEST", SlotId = `STORE_TEST/{uid}` }
end
local function stolenFrom(victim)
	uid += 1
	return { Kind = "PlayerItem", ItemUid = `uid-{uid}`, ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = victim.UserId, SlotIndex = 1 }
end
local function carry(player, payload)
	assert(Carry.StartCarry(player, payload), "StartCarry refusé")
	flush()
	return payload
end
local function drop(player)
	if Carry.IsCarrying(player) then
		Carry.Consume(player, "Test")
		flush()
	end
end
local ended = {}
Carry.OnCarryEnded(function(p, payload, result, reason)
	table.insert(ended, { player = p, payload = payload, result = result, reason = reason, t = now() })
end)
local hits = {}
BatS.OnHit(function(hitter, target, usage, payload)
	table.insert(hits, { hitter = hitter, target = target, usage = usage, payload = payload })
end)
local function lastEnded(player)
	for i = #ended, 1, -1 do
		if ended[i].player == player then
			return ended[i]
		end
	end
	return nil
end
-- Pose le frappeur en `from`, regard vers `look`, batte en main ; la cible en `at`.
local function place(player, at, look)
	moveTo(player, at, look)
end
local function swing(player)
	fireAs(player, "SwingBat")
	flush()
end
-- Attend la fin de la recharge et de l'immunité de tout le monde.
local function rest()
	advance(3.2)
end
equipBat(A)
flush()

section("S1 Portée : 7 studs entre les HumanoidRootPart")
place(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
place(B, Vector3.new(87.5, 3, 0))
carry(B, npcBox())
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("trop loin (7.5 studs)"), "S1a à 7,5 studs : coup dans le vide, Bob porte toujours")
advance(0.9)
place(B, Vector3.new(86.9, 3, 0))
swing(A)
check(not Carry.IsCarrying(B) and lastEnded(B).result == "Dropped" and lastEnded(B).reason == "Bat", "S1b à 6,9 studs : touché, colis tombé (Dropped, Bat)")
check(#hits == 1 and hits[1].hitter == A and hits[1].target == B and hits[1].usage == "Box", "S1c OnHit(Alice, Bob, « Box »)")
rest()

section("S2 Recharge : 0,8 s, un coup refusé ne la relance pas")
place(B, Vector3.new(84, 3, 0))
local t0 = now()
swing(A) -- dans le vide : Bob ne porte rien
check(not Carry.IsCarrying(B), "S2a coup dans le vide (Bob ne porte rien)")
carry(B, npcBox())
advance(0.65)
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("recharge", "WARN"), "S2b 0,65 s après : refusé (recharge)")
advance(0.2) -- 0,85 s après le premier, 0,2 après le refusé
swing(A)
check(not Carry.IsCarrying(B), "S2c 0,85 s après le premier : touché (le refus n'a pas relancé la recharge)")
rest()
carry(B, npcBox())
swing(A)
advance(0.72) -- tolérance réseau de 0,1 s
place(C, Vector3.new(83, 3, 2))
carry(C, npcBox())
swing(A)
check(not Carry.IsCarrying(C), "S2d 0,72 s après : accepté (tolérance de 0,1 s)")
drop(B)
rest()

section("S3 Devant le frappeur : 60° au plus, sauf corps contre corps")
local function at(angle, distance)
	local r = math.rad(angle)
	return Vector3.new(80 + math.cos(r) * distance, 3, math.sin(r) * distance)
end
place(B, at(70, 5))
carry(B, npcBox())
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("pas devant le frappeur"), "S3a à 70° : refusé")
advance(0.9)
place(B, at(55, 5))
swing(A)
check(not Carry.IsCarrying(B), "S3b à 55° : touché")
rest()
place(B, at(180, 2.5))
carry(B, npcBox())
swing(A)
check(not Carry.IsCarrying(B), "S3c derrière elle, à 2,5 studs (corps contre corps) : touché")
rest()
place(B, at(180, 3.5))
carry(B, npcBox())
swing(A)
check(Carry.IsCarrying(B), "S3d derrière elle, à 3,5 studs : refusé")
drop(B)
rest()

section("S4 Pas à travers un mur")
local wall = make("Part", { Name = "TestWall", Anchored = true, Size = Vector3.new(0.5, 10, 10), CFrame = CFrame.new(82.5, 5, 0) }, MAP)
place(B, Vector3.new(85, 3, 0))
carry(B, npcBox())
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("un mur entre eux"), "S4a un mur entre eux : refusé")
advance(0.9)
wall.CanCollide = false -- ne bloque plus (comme une vitre cassée)
swing(A)
check(not Carry.IsCarrying(B), "S4b mur sans collision : touché")
wall:Destroy()
rest()

section("S5 Une seule cible : le voleur de la frappeuse d'abord, sinon la plus proche")
place(B, Vector3.new(83, 3, 0))
place(C, Vector3.new(85, 3, 1))
carry(B, npcBox())
carry(C, npcBox())
swing(A)
check(not Carry.IsCarrying(B) and Carry.IsCarrying(C), "S5a deux porteurs : seul le plus proche (Bob) est touché")
rest()
drop(C)
carry(B, npcBox())
carry(C, stolenFrom(A))
swing(A)
check(Carry.IsCarrying(B) and not Carry.IsCarrying(C), "S5b Bob (colis, 3 studs) et Chloé (objet d'Alice, 5 studs) : Chloé, la voleuse, d'abord")
check(hits[#hits].usage == "Defend" and lastEnded(C).result == "Failed" and lastEnded(C).reason == "Bat", "S5c usage 1 : Fail(Chloé, « Bat »)")
drop(B)
rest()

section("S6 Refus")
place(B, Vector3.new(84, 3, 0))
local hitCount = #hits
swing(A)
check(#hits == hitCount and not Carry.IsCarrying(B), "S6a Bob ne porte rien : rien")
advance(0.9)
-- Zone safe (x < 25) : ni la frappeuse ni la cible dedans, hors usage 1.
place(A, Vector3.new(19, 3, 0), Vector3.new(1, 0, 0))
place(B, Vector3.new(23, 3, 0))
carry(B, npcBox())
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("zone safe"), "S6b tous deux en zone safe : refusé")
advance(0.9)
place(A, Vector3.new(21, 3, 0), Vector3.new(1, 0, 0))
place(B, Vector3.new(27, 3, 0))
swing(A)
check(Carry.IsCarrying(B), "S6c frappeuse en zone safe, porteur dehors : refusé")
advance(0.9)
place(A, Vector3.new(28, 3, 0), Vector3.new(-1, 0, 0))
place(B, Vector3.new(23, 3, 0))
swing(A)
check(Carry.IsCarrying(B), "S6d frappeuse dehors, porteur en zone safe : refusé")
advance(0.9)
-- Bouclier débutant : son colis ne tombe pas, Notify à la frappeuse (au plus toutes les 3 s).
place(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
place(B, Vector3.new(84, 3, 0))
SHIELDED[B] = true
local notices = #notifies(Bat.Messages.TargetShielded, A)
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("bouclier débutant"), "S6e porteur sous bouclier débutant : refusé")
check(#notifies(Bat.Messages.TargetShielded, A) == notices + 1, "S6f Notify « Beginner shield… » à la frappeuse")
advance(0.9)
swing(A)
check(#notifies(Bat.Messages.TargetShielded, A) == notices + 1, "S6g second coup 0,9 s après : pas de second Notify")
advance(2.2)
swing(A)
check(#notifies(Bat.Messages.TargetShielded, A) == notices + 2 and Carry.IsCarrying(B), "S6h 3 s après : de nouveau un Notify, toujours refusé")
SHIELDED[B] = nil
drop(B)
-- Le bouclier ne protège pas un voleur (usage 1, voir le rapport).
advance(0.9)
SHIELDED[C] = true
place(C, Vector3.new(84, 3, 0))
place(B, Vector3.new(120, 3, 20))
carry(C, stolenFrom(A))
swing(A)
check(not Carry.IsCarrying(C) and lastEnded(C).reason == "Bat", "S6i voleuse sous bouclier : la victime la frappe quand même (usage 1)")
SHIELDED[C] = nil
-- Immunité de 3 s.
advance(0.9)
place(C, Vector3.new(120, 3, 20))
place(B, Vector3.new(84, 3, 0))
carry(B, npcBox())
swing(A)
local hitAt = now()
check(not Carry.IsCarrying(B), "S6j Bob touché")
advance(2.1)
place(B, Vector3.new(84, 3, 0)) -- revenu après la poussée
carry(B, npcBox()) -- il reprend un colis à la fin de son étourdissement
advance(0.1)
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("immunité de 3 s"), `S6k {string.format("%.1f", now() - hitAt)} s après le coup : immunisé`)
advance(0.85)
swing(A)
check(not Carry.IsCarrying(B), `S6l {string.format("%.1f", now() - hitAt)} s après : de nouveau frappable`)
rest()
-- Batte pas en main, frappeuse qui porte, frappeuse étourdie.
carry(B, npcBox())
equipCasse(A)
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("batte pas en main"), "S6m outil de casse en main : refusé")
equipBat(A)
advance(1.1) -- les refus sont notés au plus une fois par seconde
carry(A, npcBox())
check(not serverModule("ToolService").IsHoldingBat(A), "S6n en portant, la batte quitte la main")
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("batte pas en main"), "S6o frappeuse qui porte : refusé")
drop(A)
equipBat(A)
advance(1.1)
-- Alice étourdie par Chloé (Alice porte un colis), puis elle essaie de frapper Bob.
place(C, Vector3.new(76, 3, 0), Vector3.new(1, 0, 0))
equipBat(C)
carry(A, npcBox())
swing(C)
check(BatS.IsStunned(A) and A:GetAttribute("BatStun") == "Knockback", "S6p Alice touchée par Chloé : étourdie")
equipBat(A)
place(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
clearLog()
swing(A)
check(Carry.IsCarrying(B) and logHas("étourdi"), "S6q frappeuse étourdie : refusé")
drop(B)
rest()

section("S7 Usage 1 : la victime frappe son voleur, même en zone safe")
place(A, Vector3.new(-40, 3, 0), Vector3.new(1, 0, 0))
place(C, Vector3.new(-35, 3, 0))
local item = carry(C, stolenFrom(A))
local dropsBefore = #batDrops()
local pushedBefore = PUSHED[C] or 0
swing(A)
check(not Carry.IsCarrying(C), "S7a en zone safe : touchée")
local e = lastEnded(C)
check(e.result == "Failed" and e.reason == "Bat" and e.payload == item, "S7b Fail(Chloé, « Bat ») : PvPService rend l'objet à son présentoir")
check(#batDrops() == dropsBefore, "S7c rien au sol (un objet volé ne tombe jamais)")
check(C:GetAttribute("BatStun") == "Stun" and humanoidOf(C).WalkSpeed == 0, "S7d étourdie (Stun, vitesse 0), sans knockback")
advance(0.3)
check((PUSHED[C] or 0) == pushedBefore and rootOf(C):FindFirstChild("BatKnockback") == nil, "S7e pas poussée")
check(hits[#hits].usage == "Defend", "S7f OnHit « Defend »")
advance(1.8)
check(C:GetAttribute("BatStun") == nil and humanoidOf(C).WalkSpeed == 16, "S7g 2 s après : plus étourdie, vitesse 16")
rest()

section("S8 Un tiers frappe un voleur : hors zone safe seulement")
equipBat(B)
place(B, Vector3.new(-40, 3, 0), Vector3.new(1, 0, 0))
place(C, Vector3.new(-35, 3, 0))
carry(C, stolenFrom(A))
clearLog()
swing(B)
check(Carry.IsCarrying(C) and logHas("zone safe"), "S8a Bob frappe la voleuse d'Alice en zone safe : refusé")
advance(0.9)
place(B, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
place(C, Vector3.new(85, 3, 0))
dropsBefore = #batDrops()
swing(B)
check(not Carry.IsCarrying(C) and lastEnded(C).reason == "Bat" and hits[#hits].usage == "Thief", "S8b dans le couloir : touchée, l'objet revole (Fail « Bat », OnHit « Thief »)")
check(#batDrops() == dropsBefore, "S8c rien au sol")
rest()

section("S9 Usage 2 : colis au sol au point du coup, knockback, étourdissement de 2 s")
place(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
place(B, Vector3.new(85, 3, 0))
equipBat(A)
local box = carry(B, npcBox())
local before = #batDrops()
pushedBefore = PUSHED[B] or 0
local notes = #notifies(Bat.Messages.BoxKnockedDown, B)
swing(A)
check(lastEnded(B).result == "Dropped" and lastEnded(B).payload == box, "S9a Dropped, même payload")
local drops = batDrops()
check(#drops == before + 1, "S9b un colis de plus au sol")
local model = drops[#drops]
local dropId = model:GetAttribute("DropId")
local payload, position = Carry.GetDrop(dropId)
check(payload == box, "S9c au sol : la même table (même rareté, même objet caché)")
check(position and near(position.X, 85, 1e-6) and near(position.Y, 0, 1e-6) and near(position.Z, 0, 1e-6), `S9d posé au sol sous Bob, au point du coup ({position})`)
check(model:GetAttribute("Tier") == "Standard" and model:GetAttribute("BatDrop") == true and model.Parent == dropsFolder(), "S9e attributs Tier et BatDrop, dans Workspace/CarryDrops")
local tint = model:FindFirstChild("Tint", true)
check(tint and tint.Color == Rarities.ById.Common.Color and tint.Anchored == true, "S9f teint à la couleur de sa rareté, ancré")
local label = model:FindFirstChild("BB_Box", true)
local rarityLabel = label and label:FindFirstChild("Rarity", true)
check(rarityLabel and rarityLabel.Text == Rarities.ById.Common.DisplayNameUpper, "S9g étiquette BB_Box : la rareté")
local knock = rootOf(B):FindFirstChild("BatKnockback")
local mover = knock and knock:FindFirstChildOfClass("LinearVelocity")
check(mover ~= nil, "S9h knockback : LinearVelocity dans le HumanoidRootPart")
if mover then
	local v = mover.VectorVelocity
	check(near(v.X, Bat.KnockbackHorizontalSpeed, 1e-6) and near(v.Y, Bat.KnockbackVerticalSpeed, 1e-6) and near(v.Z, 0, 1e-6), `S9i vitesse {v} : 40 dans le sens du coup, 20 vers le haut`)
end
check(B:GetAttribute("BatStun") == "Knockback" and humanoidOf(B).WalkSpeed == 0, "S9j étourdi (Knockback, vitesse 0)")
check(#notifies(Bat.Messages.BoxKnockedDown, B) == notes + 1, "S9k Notify « You got hit! Your box fell to the ground. » à Bob")
GOALS[B] = Vector3.new(85, 3, 40)
advance(0.3)
check(rootOf(B):FindFirstChild("BatKnockback") == nil, "S9l poussée retirée après 0,15 s")
local pushed = (PUSHED[B] or 0) - pushedBefore
check(pushed > 5 and pushed < 7.5, `S9m poussé de {string.format("%.1f", pushed)} studs`)
local stunnedAt = rootOf(B).Position
advance(1.5)
check((rootOf(B).Position - stunnedAt).Magnitude < 1e-6, "S9n étourdi : il ne bouge pas, même en voulant courir")
advance(0.3)
check(B:GetAttribute("BatStun") == nil and humanoidOf(B).WalkSpeed == 16 and not BatS.IsStunned(B), "S9o 2 s après le coup : plus étourdi")
advance(0.5)
check((rootOf(B).Position - stunnedAt).Magnitude > 5, "S9p il repart")
GOALS[B] = nil

summary("scénario swing")
