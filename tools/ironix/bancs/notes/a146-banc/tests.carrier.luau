--!nocheck
-- P. Porteur poussé (a146, audit du 2026-11-14), sanctions actives : un porteur collé à un complice rapide
-- n'a plus sa vitesse (au plus la sienne × CarrierPushFactor) ; un vigile le pousse toujours à la sienne ;
-- sans porter, la règle PushRadius ne change pas.

startServer()
setStrict(true)
local fastData = newProfile()
fastData.Stats.Speed = 1e30 -- 70
local A = join("Alice", fastData)
local strong = newProfile()
strong.Stats.Strength = 10000
local B = join("Bob", strong)
advance(1)
local FACTOR = Config.CarrierPushFactor

-- Bob prend un colis et ressort sur la chaussée, Alice collée devant lui ; 2,5 s pour que sa vitesse
-- d'avant la prise (16) sorte de la mémoire (SpeedMemory).
local function loaded(z, store)
	advance(8) -- fin du braquage d'avant (chrono HEIST) : un seul braquage à la fois
	local box = heist(B, store or STORE_A, Vector3.new(150, 3, z))
	place(A, Vector3.new(152.5, 3, z))
	advance(2.5)
	return box ~= nil and Carry.IsCarrying(B)
end

section("P1 Porteur emporté à 70 par Alice collée à lui : détecté")
check(loaded(10), "P1a Bob porte un colis")
local own = humanoidOf(B).WalkSpeed
check(own < 16, `P1b WalkSpeed du porteur : {own}`)
local s0 = strikes(B)
walk(A, Vector3.new(450, 3, 10))
walk(B, Vector3.new(447.5, 3, 10), 70)
local caught = false
for _ = 1, 120 do
	advance(FRAME)
	if strikes(B) > s0 then
		caught = true
		break
	end
end
stop(A)
stop(B)
local d = lastDetection()
check(caught and d.Kind == "Speed" and d.Carrying, `P1c détection « Speed » en portant ({d and d.Detail})`)
check(not Carry.IsCarrying(B), "P1d le colis lui est retiré")
check(strikes(A) == 0, "P1e rien pour Alice")

section("P2 Porteur poussé par Alice à sa vitesse × 1,4 pendant 3 s : rien")
check(loaded(-10, STORE_B), "P2a Bob reprend un colis (l'autre magasin : le vigile du premier n'est pas rentré)")
own = humanoidOf(B).WalkSpeed
s0 = strikes(B)
walk(A, Vector3.new(450, 3, -10), own * 1.4)
walk(B, Vector3.new(447.5, 3, -10), own * 1.4)
advance(3)
stop(A)
stop(B)
check(strikes(B) == s0 and Carry.IsCarrying(B), `P2b aucune détection (plafond {own} × {FACTOR})`)

section("P3 Contrôle : le même porteur seul à × 1,4 est détecté")
s0 = strikes(B)
place(A, Vector3.new(-50, 3, -150)) -- Alice loin, dans le hub
local p = rootOf(B).Position
walk(B, p + Vector3.new(300, 0, 0), own * 1.4)
caught = false
for _ = 1, 600 do
	advance(FRAME)
	if strikes(B) > s0 then
		caught = true
		break
	end
end
stop(B)
check(caught and lastDetection().Kind == "Speed", "P3a détecté")

section("P4 Porteur poussé par un vigile (40 studs/s) : rien")
check(loaded(10), "P4a Bob reprend un colis")
place(A, Vector3.new(-50, 3, -150))
local folder = Workspace:FindFirstChild("ActiveGuards") or folder(Workspace, "ActiveGuards")
local guard = make("Model", { Name = "FakeGuard" })
local groot = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(148, 3, 10) }, guard)
make("Humanoid", { Name = "Humanoid", WalkSpeed = 40 }, guard)
guard.PrimaryPart = groot
guard.Parent = folder
s0 = strikes(B)
walk(B, Vector3.new(350, 3, 10), 40)
for _ = 1, 90 do
	advance(FRAME)
	groot.CFrame = CFrame.new(rootOf(B).Position - Vector3.new(2, 0, 0))
end
stop(B)
guard:Destroy()
check(strikes(B) == s0, "P4b aucune détection")

section("P5 Sans porter : Alice emporte toujours Bob à 70 sans détection (règle PushRadius inchangée)")
Carry.Fail(B, "Bat")
flush()
place(B, Vector3.new(150, 3, -10))
place(A, Vector3.new(152.5, 3, -10))
settle()
advance(2.5)
s0 = strikes(B)
walk(A, Vector3.new(450, 3, -10))
walk(B, Vector3.new(452.5, 3, -10), 70)
advance(3)
stop(A)
stop(B)
check(strikes(B) == s0, "P5a aucune détection")

summary("scénario carrier")
