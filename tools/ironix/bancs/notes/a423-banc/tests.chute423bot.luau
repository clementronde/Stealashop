--!nocheck
-- Banc a423, scénario bot : l'avatar du bot (BotService), posé ancré comme l'agent de la boutique, sur la copie a175
-- du banc a124 (prélude d'a177), plus etat-humanoide.luau. Échoue avant a423 : l'avatar passe en FallingDown à la
-- pose et reste immobile 3 s au début de sa première poursuite ; après a423 : FallingDown coupé, il part tout de suite.

startBotServer()
HUMANOID_STATE.Watch = function()
	local humanoid = botHumanoid()
	return if humanoid then { humanoid } else {}
end
local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local bob = join("Bob", newProfile())
local plot, S = botArrives()

section("1. avatar du bot posé, ancré")
check(plot ~= nil, "le bot est là")
local humanoid = botHumanoid()
local root = botRoot()
check(humanoid ~= nil and root ~= nil and root.Anchored, "avatar posé, ancré")
check(humanoid and humanoid:GetStateEnabled(Enum.HumanoidStateType.FallingDown) == false, "FallingDown coupé à la pose")
advance(0.5)
check(humanoid and not HUMANOID_STATE.Fell[humanoid], "au repos : jamais passé en FallingDown")

section("2. vol : il part tout de suite, sans tomber")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
enterShop(bob, S)
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
exitShop(bob, S, 12)
check(waitFor(function()
	return BotService.IsChasing(bob)
end, 3), "Bob sort avec l'objet : poursuivi")
local start = root.Position
advance(0.5)
local moved = flatDistance(root.Position, start)
check(not root.Anchored and moved > 3, `0,5 s après le départ : il court déjà ({string.format("%.1f", moved)} studs)`)
check(humanoid and not HUMANOID_STATE.Fell[humanoid], "jamais par terre pendant la poursuite")
summary("scénario chute423bot")
