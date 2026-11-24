---------------------------------------------------------------- scénario « pieces » : gain du tapis en 5 morceaux (L-182 point 8)
local T = HudCfgC.TreadmillGain
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
local pops = {} -- échelles de départ des Motion.Pop sur SpeedRow (relevé par un enrobage de Motion.Pop)
local realPop = Motion.Pop
Motion.Pop = function(object, from, info)
	if object == speedRow then
		table.insert(pops, from)
	end
	return realPop(object, from, info)
end
local function gains()
	return childrenNamed(PLAYER_GUI, "BB_Gain")
end
local function amountOf(bb)
	local text = el(bb, "Amount").Text
	return tonumber(string.match(text, "^%+([%d%.]+)")), text
end

print("\n== P1. Un gain de 2 sur le tapis : 5 morceaux sur la seconde, même total")
check(T.Pieces == 5 and near(T.Life, 0.75) and near(PULSE.Min, 1.1) and near(PULSE.Max, 1.4), "P1a Config/Hud : 5 morceaux, 0,75 s, × 1,1 à × 1,4")
P1:SetAttribute("TrainingMachine", "Treadmill")
P1:SetAttribute("Speed", 12)
local seen, texts, total = {}, {}, 0
local scales = {}
local function collect()
	for _, bb in gains() do
		if not seen[bb] then
			seen[bb] = simTime
			local value, text = amountOf(bb)
			total += value or 0
			table.insert(texts, text)
			local pop = scaleNamed(speedRow, UiMotionC.PopScaleName)
			table.insert(scales, if pop then pop.Scale else false)
		end
	end
end
collect()
check(#texts == 1 and texts[1] == "+0.4 Speed", `P1b le premier tout de suite : « +0.4 Speed » ({texts[1]})`)
local firstScale = scales[1]
check(firstScale and near(firstScale, PULSE.Min, 1e-6), `P1c SpeedRow saute à × {PULSE.Min} ({firstScale})`)
for _ = 1, 30 do
	step(1 / 30)
	collect()
end
check(#texts == 5, `P1d 5 morceaux dans la seconde ({#texts})`)
check(near(total, 2, 1e-6), `P1e total = 2 ({total})`)
local okPops = #pops == 5
for rank, from in pops do
	okPops = okPops and near(from, PULSE.Min + (PULSE.Max - PULSE.Min) * (rank - 1) / 4, 1e-6)
end
check(okPops, `P1f SpeedRow pulse à chaque morceau, de × {PULSE.Min} à × {PULSE.Max} ({table.concat(pops, ", ")})`)
local alive = 0
for bb, at in seen do
	if bb.Parent ~= nil then
		alive += 1
	end
end
check(alive < 5, `P1g les premiers sont déjà partis (vie {T.Life} s ; encore là : {alive})`)
step(T.Life + 0.05)
check(#gains() == 0, "P1h chaque morceau vit environ 0,75 s : tous partis")
check(scaleNamed(speedRow, UiMotionC.PopScaleName) == nil, "P1i SpeedRow revenu à sa taille (UIScale passager retiré)")

print("\n== P2. Gain de 7 : morceaux de 1.4, total exact")
seen, texts, total, scales = {}, {}, 0, {}
P1:SetAttribute("Speed", 19)
collect()
for _ = 1, 30 do
	step(1 / 30)
	collect()
end
check(#texts == 5 and texts[1] == "+1.4 Speed" and near(total, 7, 1e-6), `P2a 5 × « +1.4 Speed » ({texts[1]}, total {total})`)
step(1)

print("\n== P3. Trail ×2 : l'exposant d'a178 reste sur chaque morceau")
P1:SetAttribute("TrailMultiplier", 2)
seen, texts, total, scales = {}, {}, 0, {}
P1:SetAttribute("Speed", 21)
collect()
local hex = (UiMotionC.FloatGain.TrailMultiplierColor :: Color3):ToHex()
check(texts[1] == `+0.4<font color="#{hex}">ˣ²</font> Speed`, `P3a « +0.4ˣ² Speed » ({texts[1]})`)
step(1.5)
P1:SetAttribute("TrailMultiplier", 1)

print("\n== P4. Hors du tapis : rien")
P1:SetAttribute("TrainingMachine", nil)
P1:SetAttribute("Speed", 30)
step(1)
check(#gains() == 0, "P4a Speed qui monte hors du tapis : aucun morceau")
check(Gain.GetActive().Gains == 0, "P4b GetActive : 0")
summary()
