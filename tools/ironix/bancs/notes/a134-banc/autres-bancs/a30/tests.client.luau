--!nocheck
-- K. BatController (client) : coup au marqueur Impact de SwingBat (ou au clic, ou au plus tard
-- 0,3 s après), recharge locale, rien en portant ou étourdi ; invite des colis tombés (textes,
-- maintien, portée, activation) et ramassage ; Knockback puis Stunned ; batte équipée à l'alerte de
-- vol. TruckController ne pose pas d'invite sur un colis tombé d'un coup de batte.

local Carry = serverModule("CarryService")
local Bat = sharedModule("Config/Bat")
local NetServer = sharedModule("Net/Net")
startServer()
local A = newPlayer("Alice") -- joueuse locale
local B = newPlayer("Bob")
local C = newPlayer("Chloe")
spawnCharacter(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
spawnCharacter(B, Vector3.new(120, 3, 20))
spawnCharacter(C, Vector3.new(120, 3, -20))
flush()
startClient(A)
local Anim = clientModule("AnimationController")

local function played(name, since)
	local n = 0
	for _, e in Anim.played do
		if e.name == name and e.t >= (since or -math.huge) then
			n += 1
		end
	end
	return n
end
local function stopped(name, since)
	local n = 0
	for _, e in Anim.stopped do
		if e.name == name and e.t >= (since or -math.huge) then
			n += 1
		end
	end
	return n
end
local function swings()
	return #serverCalls("SwingBat")
end
local uid = 0
local function npcBox()
	uid += 1
	return { Kind = "NPCBox", Tier = "Premium", Zone = 1, Rarity = "Common", ItemId = "Z1_Donut", StoreId = "STORE_TEST", SlotId = `STORE_TEST/{uid}` }
end

local bat = equipBat(A)
flush()

section("K1 Coup au marqueur Impact de SwingBat")
ANIM_DELIVERED.SwingBat = true
SWING_IMPACT_AT = 0.2
local t0 = now()
local before = swings()
bat.Activated:Fire()
flush()
check(played("SwingBat", t0) == 1, "K1a SwingBat jouée au clic")
advance(0.1)
check(swings() == before, "K1b 0,1 s : pas encore envoyé")
advance(0.15)
check(swings() == before + 1, "K1c au marqueur Impact (0,2 s) : SwingBat envoyé")
advance(0.3)
check(swings() == before + 1, "K1d une seule fois")

section("K2 Recharge locale de 0,8 s")
t0 = now()
before = swings()
bat.Activated:Fire() -- 0,55 s après le précédent
advance(0.5)
check(played("SwingBat", t0) == 0 and swings() == before, "K2a 0,55 s après le clic précédent : rien")
advance(0.3)
bat.Activated:Fire()
advance(0.3)
check(played("SwingBat", t0) == 1 and swings() == before + 1, "K2b 0,8 s passées : coup")

section("K3 Marqueur absent : le coup part 0,3 s après le clic")
SWING_IMPACT_AT = nil
advance(0.9)
t0 = now()
before = swings()
bat.Activated:Fire()
advance(0.25)
check(swings() == before, "K3a 0,25 s : pas encore")
advance(0.1)
check(swings() == before + 1, `K3b {Bat.ImpactMaxWait} s : envoyé`)

section("K4 SwingBat pas livrée : le coup part au clic")
ANIM_DELIVERED.SwingBat = nil
advance(0.9)
before = swings()
bat.Activated:Fire()
flush()
check(swings() == before + 1, "K4 envoyé tout de suite")

section("K5 Batte rangée avant le marqueur : rien n'est envoyé")
ANIM_DELIVERED.SwingBat = true
SWING_IMPACT_AT = 0.2
advance(0.9)
before = swings()
bat.Activated:Fire()
advance(0.05)
humanoidOf(A):UnequipTools()
advance(0.5)
check(swings() == before, "K5 rien envoyé")
bat = equipBat(A)
flush()

section("K6 Rien en portant, rien étourdie")
advance(0.9)
before = swings()
A:SetAttribute("Carrying", "Common")
t0 = now()
bat.Activated:Fire()
advance(0.4)
check(played("SwingBat", t0) == 0 and swings() == before, "K6a attribut Carrying : rien")
A:SetAttribute("Carrying", nil)
A:SetAttribute("BatStun", "Stun")
flush()
bat.Activated:Fire()
advance(0.4)
check(played("SwingBat", t0) == 0 and swings() == before, "K6b attribut BatStun : rien")
A:SetAttribute("BatStun", nil)
flush()

section("K7 Invite d'un colis tombé")
-- Chloé frappe Bob, qui porte un colis Premium, devant Alice.
moveTo(B, Vector3.new(90, 3, 0))
moveTo(C, Vector3.new(95, 3, 0), Vector3.new(-1, 0, 0))
local box = npcBox()
Carry.StartCarry(B, box)
equipBat(C)
flush()
fireAs(C, "SwingBat")
flush()
local drops = batDrops()
local model = drops[#drops]
local dropId = model:GetAttribute("DropId")
local _, position = Carry.GetDrop(dropId)
local prompts = {}
for _, d in model:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		table.insert(prompts, d)
	end
end
check(#prompts == 1, "K7a une seule invite (TruckController n'en pose pas sur un colis de batte)")
local prompt = prompts[1]
check(prompt and prompt.Name == "GrabPrompt" and prompt.ActionText == "Grab" and prompt.ObjectText == "Premium Box", `K7b « {prompt and prompt.ActionText} » / « {prompt and prompt.ObjectText} »`)
check(prompt and prompt.HoldDuration == Bat.DroppedGrabTime and prompt.MaxActivationDistance == Bat.DroppedGrabMaxDistance - 0.5 and prompt.RequiresLineOfSight == false, "K7c maintien 0,5 s, portée 7,5, sans ligne de vue")
check(prompt and prompt.Enabled == true, "K7d active, mains vides")
A:SetAttribute("Carrying", "Common")
flush()
check(prompt.Enabled == false, "K7e mains pleines : inactive")
A:SetAttribute("Carrying", nil)
flush()
check(prompt.Enabled == true, "K7f mains vides : active de nouveau")
A:SetAttribute("BatStun", "Knockback")
flush()
check(prompt.Enabled == false, "K7g étourdie : inactive")
A:SetAttribute("BatStun", nil)
flush()
check(prompt.Enabled == true, "K7h plus étourdie : active")
moveTo(A, Vector3.new(position.X - 2, 3, position.Z))
local calls = #serverCalls("GrabDropped")
t0 = now()
prompt.PromptButtonHoldBegan:Fire()
advance(Bat.DroppedGrabTime)
prompt.Triggered:Fire()
flush()
check(#serverCalls("GrabDropped") == calls + 2, "K7i deux GrabDropped : début et fin du maintien")
check(played("Grab", t0) == 1, "K7j animation Grab à la fin du maintien")
check(Carry.GetPayload(A) == box, "K7k le serveur lui donne le colis")
check(isDestroyed(prompt), "K7l invite partie avec le colis du sol")

section("K8 Knockback puis Stunned ; Stunned seule")
ANIM_DELIVERED.Knockback = true
ANIM_DELIVERED.Stunned = true
ANIM_LENGTH.Knockback = 0.6
advance(2.5)
moveTo(C, Vector3.new(position.X - 7, 3, position.Z), Vector3.new(1, 0, 0))
moveTo(A, Vector3.new(position.X - 2, 3, position.Z))
t0 = now()
fireAs(C, "SwingBat")
flush()
check(A:GetAttribute("BatStun") == "Knockback" and played("Knockback", t0) == 1 and played("Stunned", t0) == 0, "K8a frappée en portant : Knockback")
advance(0.7)
check(played("Stunned", t0) == 1, "K8b à la fin de Knockback : Stunned")
advance(1.5)
check(A:GetAttribute("BatStun") == nil and stopped("Stunned", t0) >= 1, "K8c fin de l'étourdissement : Stunned s'arrête")
-- Knockback pas livrée : Stunned tout de suite.
ANIM_DELIVERED.Knockback = nil
advance(1.5)
moveTo(A, Vector3.new(position.X - 2, 3, position.Z)) -- revenue après la poussée
Carry.StartCarry(A, npcBox())
flush()
t0 = now()
fireAs(C, "SwingBat")
flush()
check(played("Stunned", t0) == 1, "K8d Knockback pas livrée : Stunned tout de suite")
advance(2.1)
-- Usage 1 : Alice vole Chloé, Chloé la frappe : « Stun », sans Knockback.
ANIM_DELIVERED.Knockback = true
advance(1)
moveTo(A, Vector3.new(position.X - 2, 3, position.Z))
Carry.StartCarry(A, { Kind = "PlayerItem", ItemUid = "uid-x", ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = C.UserId, SlotIndex = 1 })
flush()
t0 = now()
fireAs(C, "SwingBat")
flush()
check(A:GetAttribute("BatStun") == "Stun" and played("Knockback", t0) == 0 and played("Stunned", t0) == 1, "K8e usage 1 (Stun) : Stunned seule")
advance(2.1)
check(stopped("Stunned", t0) >= 1, "K8f puis arrêtée")

section("K9 Alerte de vol : la batte s'équipe toute seule")
humanoidOf(A):UnequipTools()
flush()
check(not serverModule("ToolService").IsHoldingBat(A), "K9a batte rangée")
NetServer.Server.TheftAlert:Fire(A, true, B, "Z1_Donut")
flush()
check(serverModule("ToolService").IsHoldingBat(A), "K9b TheftAlert(true) : batte en main")
humanoidOf(A):UnequipTools()
NetServer.Server.TheftAlert:Fire(A, false)
flush()
check(not serverModule("ToolService").IsHoldingBat(A), "K9c TheftAlert(false) : rien")
Carry.StartCarry(A, npcBox())
flush()
NetServer.Server.TheftAlert:Fire(A, true, B, "Z1_Donut")
flush()
check(not serverModule("ToolService").IsHoldingBat(A), "K9d en portant : la batte ne s'équipe pas")

summary("scénario client")
