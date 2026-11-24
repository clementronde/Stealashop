--!nocheck
-- G. Capture (a146, audit du 2026-11-14, shared/CatchReach), Studio sans AntiCheatStrict (détections
-- seulement) : le vrai GuardService poursuit Bob, le banc tient le vigile à un point choisi à chaque image.
-- Attrapé : perché sur un meuble bas, le HumanoidRootPart dans un mur, en l'air juste au-dessus du vigile.
-- Jamais : à travers un mur, à travers un plancher, ni à plus de CatchVerticalReach studs au-dessus.

startServer()
local strong = newProfile()
strong.Stats.Strength = 10000
local B = join("Bob", strong)
advance(1)
local catches = {}
Guard.OnCatch(function(player)
	table.insert(catches, player)
end)

-- Le vigile est tenu en PIN_AT (après son déplacement simulé, avant le Heartbeat du serveur).
local PIN_AT = nil
local baseFrame = BEFORE_FRAME
local function activeGuard()
	local folder = Workspace:FindFirstChild("ActiveGuards")
	for _, model in (if folder then folder:GetChildren() else {}) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			return model, root
		end
	end
	return nil, nil
end
BEFORE_FRAME = function(dt)
	baseFrame(dt)
	if PIN_AT then
		local _, root = activeGuard()
		if root then
			root.CFrame = CFrame.new(PIN_AT)
		end
	end
end

-- Braquage de `store`, sortie sur la chaussée ; attend que son vigile poursuive Bob.
local function chased(store)
	advance(8) -- fin du braquage d'avant (chrono HEIST)
	local box = heist(B, store, Vector3.new(150, 3, 0))
	if box == nil then
		return false
	end
	for _ = 1, 150 do
		advance(FRAME)
		if activeGuard() then
			break
		end
	end
	advance(1) -- délai de réaction, puis poursuite
	return activeGuard() ~= nil and Carry.IsCarrying(B)
end
local parts = {}
local function solid(name, size, at)
	local part = make("Part", { Name = name, Anchored = true, Size = size, CFrame = CFrame.new(at) }, MAP)
	table.insert(parts, part)
	return part
end
local function clearParts()
	for _, part in parts do
		part:Destroy()
	end
	table.clear(parts)
end
-- Bob en `bob`, le vigile tenu en `guard`, pendant `seconds` s : attrapé ?
local function trial(bob, guard, seconds)
	local n = #catches
	PIN_AT = guard
	place(B, bob)
	for _ = 1, math.floor((seconds or 1.5) / FRAME) do
		advance(FRAME)
		if #catches > n then
			break
		end
	end
	PIN_AT = nil
	return #catches > n
end

section("G1 Pas à travers un mur (même hauteur, 3 studs)")
check(chased(STORE_A), "G1a le vigile poursuit Bob, qui porte un colis")
solid("TestWall", Vector3.new(1, 10, 10), Vector3.new(151.5, 5, 0))
check(not trial(Vector3.new(153, 3, 0), Vector3.new(150, 3, 0)) and Carry.IsCarrying(B), "G1b pas attrapé")
clearParts()

section("G2 Pas à travers un plancher (Bob à l'étage, 8 studs au-dessus, 2 studs à côté)")
solid("TestSlab", Vector3.new(20, 1, 20), Vector3.new(150, 7.5, 0))
check(not trial(Vector3.new(152, 11, 0), Vector3.new(150, 3, 0)) and Carry.IsCarrying(B), "G2a pas attrapé")
clearParts()

section("G3 En l'air à 14 studs au-dessus du vigile (plus de CatchVerticalReach) : pas attrapé")
check(Config.CatchVerticalReach < 14, `G3a CatchVerticalReach = {Config.CatchVerticalReach}`)
check(not trial(Vector3.new(152, 17, 0), Vector3.new(150, 3, 0)) and Carry.IsCarrying(B), "G3b pas attrapé")

section("G4 Perché sur un meuble de 6 studs (L-140), le vigile en bas à 3,5 studs : attrapé")
solid("TestPillar", Vector3.new(4, 6, 4), Vector3.new(153, 3, 0))
clearLog()
check(trial(Vector3.new(153, 9, 0), Vector3.new(149.5, 3, 0)), "G4a attrapé (avant : 6,9 studs en 3D et le meuble cachait Bob)")
check(not Carry.IsCarrying(B), "G4b le colis lui est retiré")
check(logHas("attrapé (perché)", "PRINT", "server"), "G4c ligne « attrapé (perché) »")
clearParts()

section("G5 Le HumanoidRootPart dans un mur : attrapé")
check(chased(STORE_B), "G5a nouvelle poursuite (l'autre magasin)")
solid("TestWall", Vector3.new(2, 10, 10), Vector3.new(153, 5, 0))
clearLog()
check(trial(Vector3.new(153, 3, 0), Vector3.new(150, 3, 0)), "G5b attrapé (avant : le mur cachait Bob)")
check(logHas("attrapé (dans une pièce)", "PRINT", "server"), "G5c ligne « attrapé (dans une pièce) »")
clearParts()

section("G6 En l'air à 8 studs juste au-dessus du vigile : attrapé")
advance(12) -- le vigile du premier magasin est rentré
check(chased(STORE_A), "G6a nouvelle poursuite")
check(trial(Vector3.new(151, 11, 0), Vector3.new(150, 3, 0)), "G6b attrapé (avant : 8,1 studs en 3D)")

summary("scénario catch")
