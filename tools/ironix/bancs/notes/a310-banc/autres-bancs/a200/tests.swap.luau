-- Scénarios « swap » du banc a200 (Cantin, 2026-11-15 : le tapis amélioré pendant qu'on court ne doit plus arrêter
-- la séance). Vrais TrainingService, MachineVariantService, TrainingController et Shared/TrainingZone, règle d'a180
-- (entrée par un grand côté) ALLUMÉE. Tapis d'Alice à l'origine (bande X ±1,5, Z ±3,25, dessus à 1,2).
-- Variantes dans Assets/Plots : Silver (même géométrie), Gold (bande et UsePoint décalés de +1 en Z).
-- Chaque vérification regarde le serveur (TrainingMachine, crédits) ET le client (place, TreadmillRun).

local FRAME = 1 / 60
local assets = newInst("Folder", "Assets", ReplicatedStorage)
local plotsFolder = newInst("Folder", "Plots", assets)
local FAR = Vector3.new(500, 0, 500)
buildTreadmill(plotsFolder, FAR, { name = "PLOT_Treadmill_Silver" })
buildTreadmill(plotsFolder, FAR + Vector3.new(0, 0, 50), { name = "PLOT_Treadmill_Gold", tag = false, beltShift = Vector3.new(0, 0, 1) })

local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
local plotA, baseA = newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
local _plotB, baseB = newPlot("PLOT_Shop_02", bob, Vector3.new(0, 0, 100))
TrainingService.Init()
local mvs = coroutine.create(MachineVariantService.Start)
assert(coroutine.resume(mvs))
startClient(alice)

local STAND_T = Vector3.new(0, 4.2, 0)
local STAND_GOLD = Vector3.new(0, 4.2, 1)
local function treadmillOf(plot)
	for _, o in CollectionService:GetTagged("Treadmill") do
		if o:IsDescendantOf(plot) then
			return o
		end
	end
	return nil
end
local function away(p)
	setMove(p, 0, 0)
	moveTo(p, Vector3.new(p.UserId * 10, 3, -400))
	step(0.6, FRAME)
end
local function walk(p, from, to)
	local d = to - from
	local length = math.sqrt(d.X * d.X + d.Y * d.Y + d.Z * d.Z)
	local n = math.max(1, math.ceil(length / (16 * FRAME)))
	for i = 0, n do
		if machineOf(p) ~= nil or (p == alice and ANIM.playing.TreadmillRun) then
			break
		end
		moveTo(p, from + d * (i / n))
		step(FRAME, FRAME)
	end
end
local function onBoth(at)
	return machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true and rootPos(alice) == (at or STAND_T)
end
local function offBoth()
	return machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil
end
-- Changements de TrainingMachine et arrêts de TreadmillRun pendant un échange.
local machineChanges = 0
alice:GetAttributeChangedSignal("TrainingMachine"):Connect(function()
	machineChanges += 1
end)
local stops = 0
do
	local anim = requireModule(game.Controllers.AnimationController)
	local realStop = anim.StopPlayer
	anim.StopPlayer = function(name)
		if name == "TreadmillRun" then
			stops += 1
		end
		realStop(name)
	end
end
local function upgrade(p, level)
	DATA[p].Upgrades.Treadmill = level
	p:SetAttribute("TreadmillLevel", level) -- ShopService publie le niveau après l'achat
end
-- Gagné en `seconds` s, image par image.
local function gained(p, seconds)
	local s0 = SPEED[p] or 0
	step(seconds, FRAME)
	return (SPEED[p] or 0) - s0
end
local Training = requireModule(ReplicatedStorage.Shared.Config.Training)

-- S1 : monté par le côté, gain 1/s ; amélioration au niveau affiché 3 (Silver, même géométrie) : rien ne s'arrête.
away(alice)
walk(alice, Vector3.new(5, 3, 0.5), Vector3.new(0.5, 3, 0.5))
check("S1 monté par le côté (serveur et client)", onBoth(), tostring(machineOf(alice)))
step(0.5, FRAME)
local g0 = gained(alice, 2)
check("S1 gain du niveau 1 : 2 en 2 s", near(g0, 2), g0)
machineChanges, stops = 0, 0
local leavesBefore = SENT.TrainLeave
local base = treadmillOf(plotA)
upgrade(alice, 2)
check("S1 variante Silver posée (ancien tapis retiré)", MachineVariantService.GetVariant(plotA) == "Silver" and treadmillOf(plotA) ~= base and base.Parent == nil)
check("S1 à l'instant de l'échange : toujours en séance", machineOf(alice) == "Treadmill" and SPEEDMOD[alice] == 0)
step(FRAME, FRAME)
check("S1 image suivante : la séance est sur le nouveau tapis", hasLog("Alice reste en séance sur le nouveau tapis"))
local g1 = gained(alice, 3)
check("S1 les crédits continuent, au gain du niveau 3 : 12 en 3 s", near(g1, 12), g1)
check("S1 TrainingMachine jamais retiré (serveur)", machineChanges == 0, machineChanges)
check("S1 TreadmillRun jamais arrêté (client)", stops == 0 and ANIM.playing.TreadmillRun == true, stops)
check(
	"S1 aucun TrainLeave envoyé, joueur pas déplacé, vitesse 0 gardée",
	SENT.TrainLeave == leavesBefore and rootPos(alice) == STAND_T and SPEEDMOD[alice] == 0 and humOf(alice).WalkSpeed == 0
)
check("S1 pas de « quitte le tapis »", not hasLog("Alice quitte le tapis"))

-- S2 : niveau affiché 4 (Gold : UsePoint décalé de 1) : la séance continue, replacé sur le nouveau UsePoint
-- (serveur et client à la même place).
machineChanges, stops = 0, 0
upgrade(alice, 3)
step(FRAME, FRAME)
check("S2 variante Gold posée", MachineVariantService.GetVariant(plotA) == "Gold")
check("S2 toujours en séance, replacé sur le UsePoint de Gold", onBoth(STAND_GOLD), tostring(rootPos(alice)))
local g2 = gained(alice, 2)
check("S2 crédits au niveau 4 : 16 en 2 s", near(g2, 16), g2)
check("S2 ni TrainingMachine retiré ni TreadmillRun arrêté", machineChanges == 0 and stops == 0, `{machineChanges}, {stops}`)

-- S3 : après l'échange, il bouge : descend (serveur et client) ; la règle d'a180 vaut toujours pour une nouvelle
-- montée : par l'avant, rien ; par le côté, il remonte sur Gold.
setMove(alice, 0, 1)
step(FRAME, FRAME)
setMove(alice, 0, 0)
check("S3 il bouge : descendu (serveur et client)", offBoth())
walk(alice, STAND_GOLD, Vector3.new(0, 3, -4.5))
walk(alice, Vector3.new(0, 3, -4.5), Vector3.new(0, 3, 0))
check("S3 revenu par l'avant sur la bande de Gold : ne remonte pas", offBoth())
walk(alice, Vector3.new(0, 3, 0), Vector3.new(-3.5, 3, 0)) -- a310 : -2,6 → -3,5 (hors de l'emprise élargie, X ±3)
walk(alice, Vector3.new(-3.5, 3, 0), Vector3.new(-0.5, 3, 0))
check("S3 revenu par le côté : remonte sur Gold", onBoth(STAND_GOLD), tostring(rootPos(alice)))

-- S4 : retour au tapis de base (renaissance : l'ancien part AVANT l'arrivée du nouveau) : la séance continue.
machineChanges, stops = 0, 0
upgrade(alice, 0)
check("S4 tapis de base revenu", treadmillOf(plotA) == baseA and MachineVariantService.GetVariant(plotA) == "Base")
step(FRAME, FRAME)
check("S4 toujours en séance, replacé sur le tapis de base", onBoth(STAND_T), tostring(rootPos(alice)))
check("S4 ni TrainingMachine retiré ni TreadmillRun arrêté", machineChanges == 0 and stops == 0, `{machineChanges}, {stops}`)
local g4 = gained(alice, 2)
check("S4 crédits au niveau 1 : 2 en 2 s", near(g4, 2), g4)

-- S5 : resté sur la bande après une descente, le tapis est amélioré : il ne remonte pas tout seul (serveur et
-- client d'accord) ; il ressort par le côté et revient : il remonte.
setMove(alice, 1, 0)
step(FRAME, FRAME)
setMove(alice, 0, 0)
check("S5 descendu, resté sur la bande", offBoth())
upgrade(alice, 2)
step(0.5, FRAME)
check("S5 Silver posée pendant qu'il est debout dessus : ne remonte pas (serveur et client)", offBoth())
walk(alice, rootPos(alice), Vector3.new(3.5, 3, 0)) -- a310 : 2,6 → 3,5 (hors de l'emprise élargie)
walk(alice, Vector3.new(3.5, 3, 0), Vector3.new(0.5, 3, 0))
check("S5 ressorti et revenu par le côté : remonte sur Silver", onBoth(), tostring(rootPos(alice)))

-- S6 : Bob (serveur seul) : son tapis retiré sans remplaçant : la séance tient SwapGrace s, puis s'arrête.
away(bob)
walk(bob, Vector3.new(5, 3, 100), Vector3.new(0.5, 3, 100))
check("S6 Bob monté", machineOf(bob) == "Treadmill")
local grace = Training.Treadmill.SwapGrace
check("S6 Config/Training : SwapGrace = 0,5 s", grace == 0.5, grace)
baseB.Parent = nil
step(grace / 2, FRAME)
check("S6 tapis retiré : encore en séance pendant l'attente", machineOf(bob) == "Treadmill")
step(grace, FRAME)
check("S6 sans remplaçant : la séance s'arrête (machine retirée)", machineOf(bob) == nil and SPEEDMOD[bob] == nil and hasLog("Bob quitte le tapis (machine retirée)"))

check("aucune erreur dans la sortie", not hasLog("ERREUR"))
print("banc a200 (tapis amélioré pendant la séance) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
