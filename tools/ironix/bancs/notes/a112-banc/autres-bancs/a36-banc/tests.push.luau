--!nocheck
-- P. Poussé par un autre (règle PushRadius), sanctions actives : un joueur lent (16) emporté à 70 par
-- un joueur rapide collé à lui, étourdi (vitesse 0) et poussé, ou poussé par un vigile (dossier
-- ActiveGuards) : aucun faux positif. Sans personne à côté, la même vitesse est vue.

startServer()
setStrict(true)
local fastData = newProfile()
fastData.Stats.Speed = 2000 -- 70
local A = join("Alice", fastData)
local B = join("Bob", newProfile()) -- 16
advance(1)
place(A, Vector3.new(100, 3, 0))
place(B, Vector3.new(102.5, 3, 0)) -- collé devant Alice
settle()

section("P1 Bob (16) poussé à 70 par Alice, 3 s")
walk(A, Vector3.new(400, 3, 0))
walk(B, Vector3.new(402.5, 3, 0), 70) -- emporté à la vitesse d'Alice, toujours collé
advance(3)
stop(A)
stop(B)
check(horizontal(rootOf(B).Position, rootOf(A).Position) < 4, "P1a ils sont restés collés")
check(strikes(B) == 0, "P1b aucune détection pour Bob : Alice, à 2,5 studs, pouvait le pousser à 70")
check(strikes(A) == 0, "P1c ni pour Alice")

section("P2 Bob étourdi (vitesse 0) et poussé par Alice")
Stats.SetSpeedModifier(B, "BatStun", 0)
walk(A, Vector3.new(100, 3, 0))
walk(B, Vector3.new(97.5, 3, 0), 70)
advance(3)
stop(A)
stop(B)
Stats.SetSpeedModifier(B, "BatStun", nil)
check(strikes(B) == 0, "P2a aucune détection")

section("P3 Bob poussé par un vigile (40 studs/s)")
local folder = Workspace:FindFirstChild("ActiveGuards") or folder(Workspace, "ActiveGuards")
local guard = make("Model", { Name = "FakeGuard" })
local groot = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(95, 3, 0) }, guard)
make("Humanoid", { Name = "Humanoid", WalkSpeed = 40 }, guard)
guard.PrimaryPart = groot
guard.Parent = folder
place(A, Vector3.new(-50, 3, -150)) -- Alice loin, dans le hub
place(B, Vector3.new(97, 3, 0))
settle()
walk(B, Vector3.new(300, 3, 0), 40)
for _ = 1, 90 do -- 3 s : le vigile colle à Bob
	advance(FRAME)
	local p = rootOf(B).Position
	groot.CFrame = CFrame.new(p - Vector3.new(2, 0, 0))
end
stop(B)
check(strikes(B) == 0, "P3a aucune détection")
guard:Destroy()

section("P4 Contrôle : seul, la même vitesse (40 contre 16) est détectée")
place(B, Vector3.new(100, 3, 10))
settle()
walk(B, Vector3.new(500, 3, 10), 40)
local found = false
for _ = 1, 300 do
	advance(FRAME)
	if strikes(B) > 0 then
		found = true
		break
	end
end
stop(B)
check(found and lastDetection().Kind == "Speed", "P4a détecté")

summary("scénario push")
