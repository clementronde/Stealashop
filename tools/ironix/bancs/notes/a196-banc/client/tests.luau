-- Banc a196, partie client (vague 60, T-087 : « le flash se voit mal ») : chaque flash émet Photo.Bursts fois, à
-- Photo.BurstGap s d'écart ; la lumière reste allumée LightTime s après la dernière émission. Après le monde d'a182.

local w1 = newWitness("NPC_Witness_Z1_01", vec(10, 3, 0), "point")
local Controller = requireModule(controllerScript)
Controller.Start()
local function bump(model)
	model:SetAttribute(Gauge.FlashAttribute, (model:GetAttribute(Gauge.FlashAttribute) or 0) + 1)
end
local function emitted(point, name)
	local e = point and point:FindFirstChild(name)
	return e and (rawget(e, "_emitted") or 0) or 0
end
local point1 = w1.ACC_Temoin_Telephone.Handle.FlashPoint
check("B0 réglages V0 : 2 émissions à 0,08 s", PHOTO.Bursts == 2 and PHOTO.BurstGap == 0.08)
bump(w1)
check("B1 première émission tout de suite : Glare 1, Specks 6", emitted(point1, "Glare") == 1 and emitted(point1, "Specks") == 6)
advance(0.1) -- pas de 0,05 s du faux task.delay
check("B2 seconde émission BurstGap s plus tard : Glare 2, Glint 2, Specks 12", emitted(point1, "Glare") == 2 and emitted(point1, "Glint") == 2 and emitted(point1, "Specks") == 12)
check("B3 un seul flash compté", (select(1, Controller.GetFlashes())) == 1)
advance(0.05)
check("B4 lumière encore allumée à 0,15 s (LightTime 0,1 s après la dernière émission, à 0,08 s)", point1.Light.Enabled == true)
advance(0.05)
check("B5 éteinte à 0,2 s (après 0,08 + LightTime)", point1.Light.Enabled == false)
advance(1)
check("B6 pas d'autre émission sans flash", emitted(point1, "Specks") == 12)

print(`banc a196 client : {CHECKS} vérification(s), {FAILS} échec(s)`)
