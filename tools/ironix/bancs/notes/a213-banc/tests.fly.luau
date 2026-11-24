---------------------------------------------------------------- scénario « fly » : le « +X » du tapis vole jusqu'au compteur Speed
local hud, Gain = startBanc(10, nil)
local W, Hh = 1280, 720
print("\n== F1. Un « +2 » du tapis : jaillit du joueur, jet, pause, aspiré par le nombre Speed")
check(FLY.Enabled == true and HudCfgC.TreadmillGain.ChunksPerSecond == 1, "F1a Config/Hud : TrainGainFly.Enabled, toujours un « +X » par seconde")
check(speedText(hud) == "10", `F1b Speed affiché 10 au départ ({speedText(hud)})`)
P1:SetAttribute("TrainingMachine", "Treadmill")
credit(12)
local list = flyers(hud)
local flyer = list[1]
check(#list == 1 and #childrenNamed(PLAYER_GUI, "BB_Gain") == 0, `F1c un gain qui vole dans UI_HUD, aucun BB_Gain ({#list})`)
if flyer == nil then
	summary()
	return
end
local amount = el(flyer, "Amount")
check(amount ~= nil and amount.Text == "+2 Speed/s", `F1d texte « +2 Speed/s » ({amount and amount.Text})`)
check(flyer:GetAttribute("GainKind") == "Speed", "F1e GainKind = Speed")
local scale = scaleNamed(flyer, "GainScale")
local p0 = centre(flyer)
check(near(p0.X, 640, 1) and near(p0.Y, 272, 1), `F1f départ au-dessus du joueur (640, 272) ({math.floor(p0.X)}, {math.floor(p0.Y)})`)
check(scale ~= nil and near(scale.Scale, FLY.PopFrom, 1e-6), `F1g toute petite au départ ({scale and scale.Scale})`)
check(speedText(hud) == "10", `F1h nombre Speed retenu à 10 pendant le vol ({speedText(hud)})`)
check(#SPEED_POPS == 0, `F1i pas encore de pulsation ({#SPEED_POPS})`)
step(0.05)
check(scale.Scale > 0 and scale.Scale < 1.2, `F1j grossit (t = 0,05 s : {scale.Scale})`)
step(0.03)
check(near(scale.Scale, 1, 1e-6), `F1k taille pleine à t = 0,08 s ({scale.Scale})`)
step(0.25)
local p1 = centre(flyer)
local jet = dist(p1, p0)
check(jet >= W * FLY.JetMin - 8 and jet <= W * FLY.JetMax + 1, `F1l jet de 15 à 18 % de la largeur à t = 0,33 s ({math.floor(jet)} px)`)
check(p1.Y < p0.Y - 100, `F1m le gain monte ({math.floor(p0.Y)} → {math.floor(p1.Y)})`)
check(p1.X >= W * FLY.Edge - 1 and p1.X <= W * (1 - FLY.Edge) + 1 and p1.Y >= Hh * FLY.Edge - 1, "F1n reste loin des bords")
step(0.69)
local p2 = centre(flyer)
check(flyer.Parent == hud and dist(p2, p1) < 0.5 and near(scale.Scale, 1, 1e-6), `F1o immobile jusqu'à t = 1,02 s (bougé {dist(p2, p1)})`)
check(speedText(hud) == "10" and #SPEED_POPS == 0, `F1p toujours 10, sans pulsation ({speedText(hud)})`)
step(0.08)
local target = centre(el(hud, "Speed"))
local p3 = centre(flyer)
check(flyer.Parent == hud and scale.Scale < 1 and scale.Scale > FLY.EndScale, `F1q aspiré à t = 1,10 s : rétrécit ({scale.Scale})`)
check(dist(p3, target) < dist(p2, target) - 1, `F1r se rapproche du nombre Speed ({math.floor(dist(p2, target))} → {math.floor(dist(p3, target))} px)`)
check(speedText(hud) == "10", `F1s encore 10 avant l'arrivée ({speedText(hud)})`)
step(0.1)
check(flyer.Parent == nil and #flyers(hud) == 0, "F1t arrivé et détruit à t = 1,20 s")
check(speedText(hud) == "12", `F1u le nombre monte à l'arrivée : 12 ({speedText(hud)})`)
check(#SPEED_POPS == 1 and near(SPEED_POPS[1], PULSE.Max, 1e-6), `F1v une pulsation d'a190 à l'arrivée (× {SPEED_POPS[1]})`)
check(Gain.GetActive().TrainFlies == 0, "F1w plus aucun gain en vol")

print("\n== F2. Un par seconde pendant 3 s : 3 gains qui volent, même total qu'avant (6)")
table.clear(SPEED_POPS)
local seen, total, perSecond = {}, 0, {}
local speed = 12
local function collect()
	for _, f in flyers(hud) do
		if not seen[f] then
			seen[f] = true
			local a = el(f, "Amount")
			total += tonumber(string.match(a.Text, "^%+([%d%.]+)")) or 0
			perSecond[#perSecond] += 1
		end
	end
end
for _ = 1, 3 do
	speed += 2
	table.insert(perSecond, 0)
	credit(speed)
	for _ = 1, 30 do
		collect()
		step(1 / 30)
	end
end
check(perSecond[1] == 1 and perSecond[2] == 1 and perSecond[3] == 1, `F2a un seul gain par seconde ({perSecond[1]}, {perSecond[2]}, {perSecond[3]})`)
check(near(total, 6, 1e-6), `F2b même total : 6 ({total})`)
check(#childrenNamed(PLAYER_GUI, "BB_Gain") == 0, "F2c aucun BB_Gain")
check(speedText(hud) == "16", `F2d à t = 3 s, le dernier encore en vol : le nombre montre 16 ({speedText(hud)})`)
step(0.3)
check(speedText(hud) == "18" and #flyers(hud) == 0, `F2e tous arrivés : 18 ({speedText(hud)})`)
check(#SPEED_POPS == 3, `F2f trois pulsations, une par arrivée ({#SPEED_POPS})`)

print("\n== F3. Hors du tapis : rien ne vole")
P1:SetAttribute("TrainingMachine", nil)
credit(20)
check(#flyers(hud) == 0 and #childrenNamed(PLAYER_GUI, "BB_Gain") == 0 and speedText(hud) == "20", `F3a aucun gain, nombre tout de suite ({speedText(hud)})`)

print("\n== F4. GainController.FlyGain (pour a214)")
local ok = Gain.FlyGain("+5 Speed", Vector3.new(4, 5, 0), "Speed")
local f4 = flyers(hud)[1]
check(ok == true and f4 ~= nil and el(f4, "Amount").Text == "+5 Speed", `F4a vole avec son texte ({f4 and el(f4, "Amount").Text})`)
if f4 then
	local c = centre(f4)
	check(near(c.X, 640 + 80, 1) and near(c.Y, 396 - 100, 1), `F4b part du point donné (720, 296) ({math.floor(c.X)}, {math.floor(c.Y)})`)
end
check(Gain.FlyGain("+5", Vector3.new(0, 5, 0), "Cash") == false, "F4c autre sorte : false, rien ne vole")
step(1.3)
check(#flyers(hud) == 0 and #SPEED_POPS == 4 and speedText(hud) == "20", `F4d arrivé, pulsation, nombre inchangé ({#SPEED_POPS}, {speedText(hud)})`)

print("\n== F5. Trail ×2 : « ×2 » en exposant (a196) et base retenue avec le trail")
P1:SetAttribute("TrainingMachine", "Treadmill")
P1:SetAttribute("TrailMultiplier", 2)
credit(20)
step(0.1)
local before = FormatC.short(FormulasC.ShownSpeed(20, 2))
check(speedText(hud) == before, `F5a nombre avec le trail : {before} ({speedText(hud)})`)
credit(22)
local f5 = flyers(hud)[1]
-- Petit TextLabel d'a196, ou (faux Roblox sans mesure de texte) l'exposant Unicode d'a178 de son repli.
local f5text = if f5 then el(f5, "Amount").Text else ""
check(f5 ~= nil and (labelWithText(f5, "×2") ~= nil or string.find(f5text, Gain.Superscript("×2"), 1, true) ~= nil), `F5b « ×2 » du trail sur le gain qui vole ({f5text})`)
check(speedText(hud) == before, `F5c retenu à {before} pendant le vol ({speedText(hud)})`)
step(1.3)
local after = FormatC.short(FormulasC.ShownSpeed(22, 2))
check(speedText(hud) == after, `F5d puis {after} à l'arrivée ({speedText(hud)})`)
summary()
