--!nocheck
-- Banc a408 (vague GC6, MAJ 5) : défense de la boutique. Voir run.sh.
moduleScript(SERVICES, "ShopDefenseService", "server/Services/ShopDefenseService.luau")

-- Modèle de Clément proposé (NPC_Bodyguard) : rig minimal, avec un Script à retirer ; NPC_DoorGuard absent (le garde
-- de la porte reprend NPC_Bodyguard, comme Config/ShopDefense.DoorGuard.Models).
local assets = ReplicatedStorage:FindFirstChild("Assets") or folder(ReplicatedStorage, "Assets")
local guardsFolder = folder(assets, "Guards")
do
	local m = make("Model", { Name = "NPC_Bodyguard" }, guardsFolder)
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, m)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(0, 4.6, 0) }, m)
	make("Humanoid", { Name = "Humanoid" }, m)
	make("Script", { Name = "Leftover" }, m)
	m.PrimaryPart = root
end

startSkills()
local SkillTree = sharedModule("Config/SkillTree")
local ShopDefense = sharedModule("Config/ShopDefense")
local Defense = serverModule("ShopDefenseService")

local function cmd(text)
	Workspace:SetAttribute("SkillTest", text)
	Workspace:SetAttribute("SkillTest", nil)
	advance(0.1)
end
local function guardsOf(plot)
	return Defense.GetGuards(plot)
end
local function avatarOf(plot, kind)
	local g = guardsOf(plot)[kind]
	return if g then g.Avatar else nil
end
local function spotted(to)
	return remotes("CameraSpotted", function(e)
		return to == nil or e.to == to
	end)
end

local bobData = newProfile()
for i = 1, 4 do
	addItem(bobData, "bob-" .. i, "Z1_CanetteDeSoda", i)
end
bobData.Cash = 50_000_000
local bob = join("Bob", bobData)
local eve = join("Eve", newProfile())
local tom = join("Tom", newProfile())
local shop = shopOf(bob)
local S = refsOfShop(shop)
check(shop ~= nil and S ~= nil, "Bob a une boutique")

if SCENARIO == "off" then
	section("interrupteurs coupés")
	check(SkillTree.ById.Bodyguards.Coded == 0, `Bodyguards « Soon » (Coded {SkillTree.ById.Bodyguards.Coded})`)
	check(SkillTree.ById.DoorGuard.Coded == 0, `DoorGuard « Soon » (Coded {SkillTree.ById.DoorGuard.Coded})`)
	check(SkillTree.ById.Cameras.Coded == 2, `Cameras : 2 niveaux (Coded {SkillTree.ById.Cameras.Coded})`)
	buy(bob, "Bodyguards")
	check(bob:GetAttribute("Skill_Bodyguards") == 0 and #notifies(bob, "coming soon") >= 1, "achat de Guards refusé (« coming soon »)")
	cmd("Bob Bodyguards 3")
	cmd("Bob DoorGuard 1")
	advance(1.5)
	check(shop:FindFirstChild("ShopDefense") == nil and next(guardsOf(shop)) == nil, "niveaux posés par SkillTest : aucun agent")
	cmd("Bob Cameras 3")
	check(breakDoor(eve, shop), "Eve casse la porte de Bob")
	local before = #spotted(bob)
	check(steal(eve, shop, 3), "Eve prend l'objet du présentoir 3")
	advance(2)
	check(CarryService.IsCarrying(eve), "personne ne poursuit Eve : elle porte toujours l'objet")
	check(#spotted(bob) == before, "radar coupé : pas de CameraSpotted de plus à la prise")
	check(not logHas("[ShopDefenseService]", "WARN"), "aucun avertissement de ShopDefenseService")
	summary("scénario off")
	return
end

section("tuiles achetables")
local body = SkillTree.ById.Bodyguards
local door = SkillTree.ById.DoorGuard
check(body.Coded == 5 and body.MaxLevel == 5, `Bodyguards : 5 niveaux achetables (Coded {body.Coded})`)
check(door.Coded == 1 and door.Prices[1] == 530_000 and door.Effects[1] == 4, "DoorGuard : 1 niveau, 530 000 $, une poussée toutes les 4 s")
check(SkillTree.ById.Cameras.Coded == 3, "Cameras : 3 niveaux achetables")
local cash0 = bobData.Cash
buy(bob, "Bodyguards")
check(bob:GetAttribute("Skill_Bodyguards") == 1 and bobData.Cash == cash0 - body.Prices[1], `Bob achète Guards 1 ({body.Prices[1]} $)`)
buy(bob, "DoorGuard")
check(bob:GetAttribute("Skill_DoorGuard") == 0, "DoorGuard refusé sans 3 renaissances")
bob:SetAttribute("Rebirths", 3)
local cash1 = bobData.Cash
buy(bob, "DoorGuard")
check(bob:GetAttribute("Skill_DoorGuard") == 1 and bobData.Cash == cash1 - 530_000, "3 renaissances : Bob achète Door Guard (530 000 $)")
cmd("Bob DoorGuard 0") -- le garde de la porte est testé plus loin
advance(1.2)

section("agent posé dans la boutique")
local avatar = avatarOf(shop, "Body")
check(avatar ~= nil and avatar.Parent and avatar.Parent.Name == "ShopDefense" and avatar.Parent.Parent == shop, "agent « Bodyguard » dans le dossier ShopDefense de la boutique")
local root = avatar and avatar:FindFirstChild("HumanoidRootPart")
local humanoid = avatar and avatar:FindFirstChildOfClass("Humanoid")
check(avatar and avatar:FindFirstChild("Leftover") == nil, "script du modèle retiré")
check(root and root.Anchored and not root.CanCollide and not root.CanQuery, "au repos : ancré, sans collision ni requête")
check(humanoid and humanoid.DisplayName == "Security", "nom affiché « Security »")
local home = root and root.Position
check(home and insideBox(boundsOf(shop), home), "posté dans Bounds")
check(home and math.abs(home.Z - (S.door.Z + ShopDefense.Bodyguard.PostInset)) < 0.2 and math.abs(home.X - S.door.X) < 0.2, `à {ShopDefense.Bodyguard.PostInset} studs à l'intérieur de la porte`)
check(guardsOf(shop).Door == nil, "Door Guard 0 : pas de garde à la porte")
check(avatarOf(shopOf(eve), "Body") == nil, "pas d'agent chez Eve (Guards 0)")

section("vol : poursuite et capture")
check(breakDoor(eve, shop), "Eve casse la porte de Bob")
check(steal(eve, shop, 3), "Eve prend l'objet du présentoir 3")
local g = guardsOf(shop).Body
check(g.Phase == "Chase" and g.Target == eve, "l'agent poursuit Eve")
check(root.Anchored, `départ après {ShopDefense.Bodyguard.ReactDelay} s : encore ancré tout de suite`)
advance(0.6)
check(not root.Anchored and humanoid.WalkSpeed == body.Effects[1] * ShopDefense.Bodyguard.SpeedScale, `il court à {body.Effects[1]} × {ShopDefense.Bodyguard.SpeedScale} (WalkSpeed {humanoid.WalkSpeed})`)
advance(1.0)
check(not CarryService.IsCarrying(eve), "attrapée : Eve ne porte plus rien")
check(bobData.Display["3"] == "bob-3" and displayModel(shop, 3) ~= nil, "l'objet est revenu sur le présentoir 3")
check(bobData.Items["bob-3"] ~= nil, "l'objet est toujours à Bob")
check(type(eve:GetAttribute("RobCooldown_" .. shop:GetAttribute("PlotIndex"))) == "number", "Eve interdite de voler Bob (RobCooldown)")
check(not insideBox(boundsOf(shop), rootOf(eve).Position), "Eve sortie de la boutique")
check(#notifies(bob, "Your guard caught Eve!") == 1, "Bob : « Your guard caught Eve! »")
advance(1.5)
g = guardsOf(shop).Body
check(g.Phase == "Idle" and root.Anchored and (root.Position - home).Magnitude < 0.5, "l'agent est revenu à son poste, ancré")

section("niveau 3 : plus rapide")
cmd("Bob Bodyguards 3")
advance(1.2)
check(avatarOf(shop, "Body") == avatar, "même agent après la montée de niveau")

section("laisse : voleur loin de la boutique")
check(breakDoor(tom, shop), "Tom casse la porte de Bob")
check(steal(tom, shop, 4), "Tom prend l'objet du présentoir 4")
moveTo(tom, S.door + S.front * 45 + Vector3.new(0, 2.4, 0)) -- 45 studs devant la porte
advance(0.3)
g = guardsOf(shop).Body
check(g.Phase ~= "Chase" and CarryService.IsCarrying(tom), `plus de {ShopDefense.Bodyguard.LeashDistance} studs : l'agent le lâche, Tom garde l'objet`)
moveTo(tom, S.door + S.front * 3 + Vector3.new(0, 2.4, 0))
advance(1)
check(guardsOf(shop).Body.Phase ~= "Chase", "lâché : il ne repart pas quand Tom repasse devant (il faut un nouveau vol)")
kill(tom)
advance(0.5)
check(bobData.Display["4"] == "bob-4", "Tom mort : l'objet revient")

section("garde de la porte")
advance(6) -- Tom réapparaît
-- Porte refaite : StealDuration + RebuildDelay après la dernière casse (PvP, Balance.Window), personne dedans.
for _ = 1, 120 do
	if not WindowService.IsBroken(windowIdOf(shop)) then
		break
	end
	advance(0.5)
end
cmd("Bob DoorGuard 1")
advance(1.2)
local doorAvatar = avatarOf(shop, "Door")
local doorRoot = doorAvatar and doorAvatar:FindFirstChild("HumanoidRootPart")
check(doorAvatar ~= nil and doorAvatar.Name == "DoorGuard", "garde « DoorGuard » posé (modèle NPC_Bodyguard en repli)")
check(doorRoot and not insideBox(boundsOf(shop), doorRoot.Position) and (Vector3.new(doorRoot.Position.X, 0, doorRoot.Position.Z) - Vector3.new(S.door.X, 0, S.door.Z)).Magnitude < 6, "debout dehors, à côté de la porte")
spawnCharacter(tom, S.outside)
advance(0.2)
local function pushesOn(player)
	local n = 0
	local r = rootOf(player)
	for _, child in (if r then r:GetChildren() else {}) do
		if child.Name == "DoorGuardPush" then
			n += 1
		end
	end
	return n
end
local hp0 = WindowService.IsBroken(windowIdOf(shop))
check(not hp0, "porte de Bob refaite")
hitDoor(tom, shop, 1)
advance(0.5)
check(pushesOn(tom) == 1, "Tom frappe la porte : repoussé une fois")
local r = rootOf(tom)
local push = r and r:FindFirstChild("DoorGuardPush")
local mover = push and push:FindFirstChildWhichIsA("LinearVelocity")
check(mover and mover.VectorVelocity:Dot(S.front) > 50, "poussée vers la rue (plus forte qu'un coup de batte)")
check(#notifies(tom, "door guard pushed") == 1, "Tom : « The door guard pushed you back! »")
hitDoor(tom, shop, 2)
advance(0.5)
check(pushesOn(tom) == 1, "pas de 2e poussée avant 4 s")
advance(3.5)
hitDoor(tom, shop, 1)
advance(0.5)
check(pushesOn(tom) == 2, "4 s plus tard : 2e poussée")
moveTo(bob, S.outside + S.front * -3)
advance(5)
check(pushesOn(bob) == 0, "jamais le propriétaire")

section("caméras 3 : rouge vif et radar")
startClient(bob)
advance(0.5)
local MarkerSounds = requireModule(SHARED:FindFirstChild("Anim"):FindFirstChild("MarkerSounds"), "client")
local beeps = 0
MarkerSounds.play = function(name)
	if name == ShopDefense.CameraRadar.Sound then
		beeps += 1
	end
	return nil
end
cmd("Bob DoorGuard 0")
cmd("Bob Cameras 2")
advance(31)
hitDoor(tom, shop, 1)
advance(0.5)
local glow = tom.Character:FindFirstChild("CameraHighlight")
check(glow ~= nil and glow.FillColor.B > 0.8, "Cameras 2 : Tom surligné en bleu")
advance(1)
check(beeps == 0, "Cameras 2 : pas de radar")
cmd("Bob Cameras 3")
advance(0.5)
glow = tom.Character:FindFirstChild("CameraHighlight")
check(glow ~= nil and glow.FillColor.R > 0.9 and glow.FillColor.G < 0.2, "Cameras 3 : rouge vif")
local bobPos = rootOf(bob).Position
moveTo(tom, bobPos + Vector3.new(5, 0, 0))
beeps = 0
advance(1.5)
local nearBeeps = beeps
moveTo(tom, bobPos + Vector3.new(0, 0, -260))
advance(0.1)
beeps = 0
advance(2.5)
local farBeeps = beeps
check(nearBeeps >= 8, `Tom à 5 studs : bips rapides ({nearBeeps} en 1,5 s)`)
check(farBeeps >= 1 and farBeeps <= 3, `Tom à 260 studs : bips lents ({farBeeps} en 2,5 s)`)
-- Prise d'un objet : CameraSpotted relancé jusqu'à la fin de la fuite.
cmd("Bob Bodyguards 0")
advance(1.2)
check(avatarOf(shop, "Body") == nil and shop:FindFirstChild("ShopDefense") and #shop.ShopDefense:GetChildren() == 0, "Guards 0 : agent retiré")
advance(61) -- fin de l'interdiction d'Eve
check(breakDoor(eve, shop), "Eve casse la porte de Bob")
local n0 = #spotted(bob)
local t0 = Workspace:GetServerTimeNow()
check(steal(eve, shop, 2), "Eve prend l'objet du présentoir 2")
local list = spotted(bob)
local e = list[#list]
check(#list == n0 + 1 and e.args[1] == eve and math.abs(e.args[2] - (t0 + 31)) < 1.5, `prise : CameraSpotted(Eve, + 30 s) à Bob ({#list - n0} de plus)`)

section("départ du propriétaire")
cmd("Bob Bodyguards 2")
cmd("Bob DoorGuard 1")
advance(1.2)
check(avatarOf(shop, "Body") ~= nil and avatarOf(shop, "Door") ~= nil, "les deux agents posés")
local a1, a2 = avatarOf(shop, "Body"), avatarOf(shop, "Door")
leave(bob)
advance(1.5)
check(isDestroyed(a1) and isDestroyed(a2) and next(guardsOf(shop)) == nil, "Bob parti : agents retirés")

section("sortie")
check(not logHas("[ShopDefenseService]", "WARN"), "aucun avertissement de ShopDefenseService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("CameraAlertController]", "WARN"), "aucune erreur du client")
summary("scénario on")
