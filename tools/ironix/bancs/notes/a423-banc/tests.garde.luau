--!nocheck
-- Banc a423, scénario garde (Cantin, 24/11 : « le vigile tombe par terre dès qu'il commence à courir, puis se relève »).
-- Agent de la boutique (ShopDefenseService, a408) sur le harnais du banc a408, plus etat-humanoide.luau (ancré à la
-- pose -> FallingDown si permis ; par terre et immobile 3 s une fois désancré). Échoue avant a423 : l'agent posé ancré
-- passe en FallingDown et ne part que 3 s après la prise ; après a423 : FallingDown coupé à la pose, il part à 0,5 s.
moduleScript(SERVICES, "ShopDefenseService", "server/Services/ShopDefenseService.luau")

-- Modèle de Clément proposé (NPC_Bodyguard) : rig minimal, comme le banc a408.
local assets = ReplicatedStorage:FindFirstChild("Assets") or folder(ReplicatedStorage, "Assets")
local guardsFolder = folder(assets, "Guards")
do
	local m = make("Model", { Name = "NPC_Bodyguard" }, guardsFolder)
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, m)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(0, 4.6, 0) }, m)
	make("Humanoid", { Name = "Humanoid" }, m)
	m.PrimaryPart = root
end

startSkills()
local ShopDefense = sharedModule("Config/ShopDefense")
local Defense = serverModule("ShopDefenseService")
local FALLING_DOWN = Enum.HumanoidStateType.FallingDown

local function cmd(text)
	Workspace:SetAttribute("SkillTest", text)
	Workspace:SetAttribute("SkillTest", nil)
	advance(0.1)
end
local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local bobData = newProfile()
for i = 1, 4 do
	addItem(bobData, "bob-" .. i, "Z1_CanetteDeSoda", i)
end
bobData.Cash = 50_000_000
local bob = join("Bob", bobData)
local eve = join("Eve", newProfile())
local shop = shopOf(bob)
check(shop ~= nil, "Bob a une boutique")
local function avatarOf(kind)
	local g = Defense.GetGuards(shop)[kind]
	return if g then g.Avatar else nil
end
HUMANOID_STATE.Watch = function()
	local list = {}
	for _, kind in { "Body", "Door" } do
		local avatar = avatarOf(kind)
		local humanoid = avatar and avatar:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(list, humanoid)
		end
	end
	return list
end

section("agent posé, ancré")
buy(bob, "Bodyguards")
advance(1.2)
local avatar = avatarOf("Body")
local root = avatar and avatar:FindFirstChild("HumanoidRootPart")
local humanoid = avatar and avatar:FindFirstChildOfClass("Humanoid")
check(avatar ~= nil and root ~= nil and root.Anchored, "agent posé dans la boutique, ancré")
check(humanoid and humanoid:GetStateEnabled(FALLING_DOWN) == false, "FallingDown coupé à la pose (comme les vigiles, 9.7)")
check(humanoid and not HUMANOID_STATE.Fell[humanoid], "au repos : jamais passé en FallingDown")

section("vol : il part tout de suite, sans tomber")
check(breakDoor(eve, shop), "Eve casse la porte de Bob")
check(steal(eve, shop, 3), "Eve prend l'objet du présentoir 3")
local start = root.Position
advance(ShopDefense.Bodyguard.ReactDelay + 0.4)
local moved = flatDistance(root.Position, start)
check(not root.Anchored and moved > 3, `{ShopDefense.Bodyguard.ReactDelay + 0.4} s après la prise : il court déjà ({string.format("%.1f", moved)} studs)`)
check(HUMANOID_STATE.of(humanoid) ~= "FallingDown" and not HUMANOID_STATE.Fell[humanoid], "jamais par terre au départ")
advance(0.7)
check(not CarryService.IsCarrying(eve), "Eve attrapée 1,6 s après la prise (comme le banc a408)")

section("garde de la porte")
cmd("Bob DoorGuard 1")
advance(1.2)
local door = avatarOf("Door")
local doorHumanoid = door and door:FindFirstChildOfClass("Humanoid")
check(doorHumanoid ~= nil, "garde de la porte posé")
check(doorHumanoid and doorHumanoid:GetStateEnabled(FALLING_DOWN) == false, "garde de la porte : FallingDown coupé à la pose")
check(doorHumanoid and not HUMANOID_STATE.Fell[doorHumanoid], "garde de la porte : jamais passé en FallingDown")

section("sortie")
check(not logHas("[ShopDefenseService]", "WARN"), "aucun avertissement de ShopDefenseService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario garde")
