---------------------------------------------------------------- scénario « chunk1 » (a200, Cantin 2026-11-15) : un seul « +X » par seconde
local PULSE = HudCfgC.SpeedPulse
local Motion = requireModule(MOTION_MODULE, "client")
Motion.SetSoundPlayer(function() end)
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
local Hud = requireModule(HUD_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
step(0.1)
local speedRow = el(hud, "SpeedRow")
local pops = {}
local realPop = Motion.Pop
Motion.Pop = function(object, from, info)
	if object == speedRow then
		table.insert(pops, from)
	end
	return realPop(object, from, info)
end
local seen, texts, total = {}, {}, 0
local function collect()
	for _, bb in childrenNamed(PLAYER_GUI, "BB_Gain") do
		if not seen[bb] then
			seen[bb] = true
			local text = el(bb, "Amount").Text
			table.insert(texts, text)
			total += tonumber(string.match(text, "^%+([%d%.]+)")) or 0
		end
	end
end

print("\n== K1. Tapis à +2 par seconde pendant 3 s (le serveur crédite chaque seconde) : 3 « +2 Speed/s », un par seconde")
check(HudCfgC.TreadmillGain.ChunksPerSecond == 1, "K1a Config/Hud : ChunksPerSecond = 1")
P1:SetAttribute("TrainingMachine", "Treadmill")
local speed = 10
local perSecond = {}
for second = 1, 3 do
	speed += 2
	P1:SetAttribute("Speed", speed)
	local before = #texts
	for _ = 1, 30 do
		collect()
		step(1 / 30)
	end
	collect()
	perSecond[second] = #texts - before
end
check(perSecond[1] == 1 and perSecond[2] == 1 and perSecond[3] == 1, `K1b un seul BB_Gain par seconde ({perSecond[1]}, {perSecond[2]}, {perSecond[3]})`)
check(texts[1] == "+2 Speed/s" and texts[2] == "+2 Speed/s" and texts[3] == "+2 Speed/s", `K1c le gain entier : « +2 Speed/s » ({texts[1]})`)
check(near(total, 6, 1e-6), `K1d même total qu'avant : 6 ({total})`)
local okPops = #pops == 3
for _, from in pops do
	okPops = okPops and near(from, PULSE.Max, 1e-6)
end
check(okPops, `K1e le compteur Speed pulse une fois par seconde, à × {PULSE.Max} ({table.concat(pops, ", ")})`)
check(not string.find(table.concat(texts, " "), "0.4", 1, true), "K1f plus aucun morceau « +0.4 »")

print("\n== K2. Trail ×2 : l'exposant (a178 / a196) reste sur le « +X » de la seconde")
P1:SetAttribute("TrailMultiplier", 2)
seen, texts, total = {}, {}, 0
P1:SetAttribute("Speed", speed + 4)
collect()
check(#texts == 1 and string.find(texts[1], "+4", 1, true) == 1 and string.find(texts[1], "Speed/s", 1, true) ~= nil, `K2a un seul « +4 … Speed/s » ({texts[1]})`)
local bb = childrenNamed(PLAYER_GUI, "BB_Gain")[1]
local amount = bb and el(bb, "Amount")
local exponent = false
if amount then
	for _, d in amount:GetDescendants() do
		if d:IsA("TextLabel") then
			exponent = true
		end
	end
	exponent = exponent or string.find(amount.Text, "ˣ²", 1, true) ~= nil
end
check(exponent, "K2b « ×2 » en exposant présent (petit TextLabel d'a196 ou Unicode d'a178)")
step(1.5)
P1:SetAttribute("TrailMultiplier", 1)

print("\n== K3. Hors du tapis : rien")
P1:SetAttribute("TrainingMachine", nil)
P1:SetAttribute("Speed", speed + 30)
step(1)
check(#childrenNamed(PLAYER_GUI, "BB_Gain") == 0, "K3a Speed qui monte hors du tapis : aucun BB_Gain")
summary()
