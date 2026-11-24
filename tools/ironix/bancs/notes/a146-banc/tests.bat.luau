--!nocheck
-- B. Coup de batte (a146, audit du 2026-11-14, shared/CatchReach), Studio sans AntiCheatStrict : Alice frappe
-- Bob qui porte un colis PNJ sur la chaussée. Touché : perché sur un meuble de 6 studs, le HumanoidRootPart
-- dans un mur. Jamais à travers un mur. (Même règle de portée et de mur pour le propriétaire et le bot :
-- candidateFor.) Le vigile du magasin est tenu loin pendant les essais.

startServer()
local strong = newProfile()
strong.Stats.Strength = 10000
local A = join("Alice", strong)
local B = join("Bob", newProfile())
advance(1)

local baseFrame = BEFORE_FRAME
local HOLD_GUARDS = false
BEFORE_FRAME = function(dt)
	baseFrame(dt)
	if HOLD_GUARDS then
		local folder = Workspace:FindFirstChild("ActiveGuards")
		for _, model in (if folder then folder:GetChildren() else {}) do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(65, 3, 20) -- devant son magasin, loin des essais
			end
		end
	end
end
local parts = {}
local function solid(name, size, at)
	table.insert(parts, make("Part", { Name = name, Anchored = true, Size = size, CFrame = CFrame.new(at) }, MAP))
end
local function clearParts()
	for _, part in parts do
		part:Destroy()
	end
	table.clear(parts)
end
-- Bob reprend un colis (Alice casse la vitrine), puis Alice en `alice` frappe Bob en `bob`. Touché ?
local function trial(store, bob, alice)
	HOLD_GUARDS = false
	advance(8) -- fin du braquage d'avant, immunité de 3 s finie
	ensureOpen(A, store)
	local ok = grabShelf(B, store, fullSlot(store))
	HOLD_GUARDS = true
	place(B, bob)
	place(A, alice)
	face(A, bob)
	settle()
	equipBat(A)
	clearLog()
	fireAs(A, "SwingBat")
	flush()
	advance(0.2)
	unequip(A)
	return ok, not Carry.IsCarrying(B)
end

section("B1 Pas à travers un mur (même hauteur, 3,5 studs)")
solid("TestWall", Vector3.new(1, 10, 10), Vector3.new(121.75, 5, 0))
local ok, hit = trial(STORE_A, Vector3.new(123.5, 3, 0), Vector3.new(120, 3, 0))
check(ok and not hit, "B1a pas touché")
check(logHas("un mur entre eux", nil, "server"), "B1b refus « un mur entre eux » dans la sortie")
clearParts()
Carry.Fail(B, "Bat")
flush()

section("B2 Perché sur un meuble de 6 studs, Alice en bas à 3,5 studs : touché")
solid("TestPillar", Vector3.new(4, 6, 4), Vector3.new(123.5, 3, 0))
ok, hit = trial(STORE_B, Vector3.new(123.5, 9, 0), Vector3.new(120, 3, 0))
check(ok and hit, "B2a touché, le colis tombe (avant : le meuble cachait Bob)")
clearParts()

section("B3 Le HumanoidRootPart dans un mur : touché")
solid("TestWall", Vector3.new(2, 10, 10), Vector3.new(123.5, 5, 0))
ok, hit = trial(STORE_A, Vector3.new(123.5, 3, 0), Vector3.new(120, 3, 0))
check(ok and hit, "B3a touché (avant : le mur cachait Bob)")
clearParts()

section("B4 En l'air à 8 studs au-dessus d'Alice, 2 studs devant : touché")
ok, hit = trial(STORE_B, Vector3.new(122, 11, 0), Vector3.new(120, 3, 0))
check(ok and hit, "B4a touché (avant : 8,2 studs en 3D, plus que Bat.Range)")

summary("scénario bat")
