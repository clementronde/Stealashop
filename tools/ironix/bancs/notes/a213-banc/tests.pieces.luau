---------------------------------------------------------------- scénario « pieces » : 4 morceaux par seconde, chacun vole
local hud = startBanc(10, nil)
print("\n== P1. ChunksPerSecond = 4 : 4 « +0.5 Speed » qui volent, le nombre monte morceau par morceau")
check(HudCfgC.TreadmillGain.ChunksPerSecond == 4, "P1a copie des sources à 4 morceaux")
P1:SetAttribute("TrainingMachine", "Treadmill")
credit(12)
local seen, total, shownDuring = {}, 0, {}
for _ = 1, 75 do
	for _, f in flyers(hud) do
		if not seen[f] then
			seen[f] = true
			total += tonumber(string.match(el(f, "Amount").Text, "^%+([%d%.]+)")) or 0
		end
	end
	shownDuring[speedText(hud)] = true
	step(1 / 30)
end
local count = 0
for _ in seen do
	count += 1
end
check(count == 4 and #childrenNamed(PLAYER_GUI, "BB_Gain") == 0, `P1b 4 gains qui volent ({count})`)
check(near(total, 2, 1e-6), `P1c même total : 2 ({total})`)
check(shownDuring["10"] and shownDuring["10.5"] and shownDuring["11"] and shownDuring["11.5"], "P1d nombre 10, 10.5, 11, 11.5 en chemin")
check(speedText(hud) == "12" and #flyers(hud) == 0, `P1e tous arrivés : 12 ({speedText(hud)})`)
check(#SPEED_POPS == 4 and near(SPEED_POPS[1], PULSE.Min, 1e-6) and near(SPEED_POPS[4], PULSE.Max, 1e-6), `P1f 4 pulsations de Min à Max ({#SPEED_POPS})`)
summary()
