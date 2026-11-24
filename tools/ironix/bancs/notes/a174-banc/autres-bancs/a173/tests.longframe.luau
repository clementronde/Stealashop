--!nocheck
-- a173 (2026-11-15) : « bloqué sur sa ronde » à la tombée de la nuit (Play de fusion48 : le serveur gèle 1 à 8 s,
-- les 12 vigiles de nuit l'écrivaient ensemble). Une image de 3 s (puis de 8 s) ne compte pas comme une ronde sans
-- progrès ; un vigile vraiment bloqué (replacé à chaque image) l'écrit toujours.
startBanc()
local function patrol()
	Guard.StartNightPatrol({
		InCorridor = function(position)
			return position.X > 25
		end,
		Ignores = function()
			return false
		end,
		SendHome = function()
			return true
		end,
	})
end
local function nightGuards()
	local list = {}
	local folder = Workspace:FindFirstChild("ActiveGuards")
	for _, model in (if folder then folder:GetChildren() else {}) do
		if string.find(model.Name, "NightGuard", 1, true) and model:FindFirstChild("HumanoidRootPart") then
			table.insert(list, model)
		end
	end
	return list
end
local STUCK = "bloqué sur sa ronde"

section("L1 gel du serveur juste après la tombée de la nuit")
patrol()
advance(1)
local count = #nightGuards()
check(count > 0, "L1a vigiles de nuit en ronde (" .. count .. ")")
clearLog()
for _, gel in { 3, 8 } do
	FREEZE = true
	advance(gel, gel) -- une seule image de `gel` s, rien ne bouge
	FREEZE = false
	advance(1.5)
	check(logCount(STUCK) == 0, "L1b image de " .. gel .. " s : aucun « " .. STUCK .. " » (" .. logCount(STUCK) .. ")")
end
advance(2)
check(logCount(STUCK) == 0, "L1c rondes normales ensuite : aucun « " .. STUCK .. " » (" .. logCount(STUCK) .. ")")

section("L2 vigile vraiment bloqué : toujours signalé")
local stuck = nightGuards()[1]
local pinned = stuck and stuck.HumanoidRootPart.CFrame
ON_FRAME = function()
	if stuck and stuck.Parent then
		stuck.HumanoidRootPart.CFrame = pinned
	end
end
clearLog()
advance(4)
ON_FRAME = nil
check(logCount(STUCK) >= 1, "L2a replacé à chaque image : « " .. STUCK .. " » écrit (" .. logCount(STUCK) .. ")")
Guard.StopNightPatrol()
advance(2)
summary("scénario longframe")
