---------------------------------------------------------------- scénario « gainkind » (L-092 3e) : un seul BB_Gain, GainKind et couleur
local F = UiMotionC.FloatGain
local Motion = requireModule(MOTION_MODULE, "client")
Motion.SetSoundPlayer(function() end)
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
local templateColor = Color3.new(1, 1, 1)
el(BB_GAIN, "Amount").TextColor3 = templateColor
local gainSnap = snapshot(BB_GAIN)
local Hud = requireModule(HUD_MODULE, "client")
local Rewards = requireModule(REWARDS_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
step(0.1)
local function gains()
	return childrenNamed(PLAYER_GUI, "BB_Gain")
end

print("\n== K1. Couleurs du prototype de Clément")
check(F.KindAttribute == "GainKind", "K1a attribut GainKind")
check(sameColor(F.Colors.Speed, Color3.fromHex("4FD2FF")) and sameColor(F.Colors.Power, Color3.fromHex("FF7A3A")) and sameColor(F.Colors.Cash, Color3.fromHex("5CFF4A")), "K1b Speed #4FD2FF, Power #FF7A3A, Cash #5CFF4A")

print("\n== K2. Tapis : Speed")
P1:SetAttribute("TrainingMachine", "Treadmill")
P1:SetAttribute("Speed", 12)
local list = gains()
local bb = list[1]
check(#list == 1 and bb:GetAttribute("GainKind") == "Speed", `K2a GainKind = Speed ({bb and bb:GetAttribute("GainKind")})`)
check(bb and sameColor(el(bb, "Amount").TextColor3, F.Colors.Speed), "K2b Amount en #4FD2FF")
step(F.Time + 0.5)

print("\n== K3. Banc : Power")
P1:SetAttribute("TrainingMachine", "Bench")
P1:SetAttribute("Strength", 9)
list = gains()
bb = list[1]
check(#list == 0, "K3a a134 : au banc, Strength qui monte : plus de BB_Gain Power (plus de banc ni de Force)")
P1:SetAttribute("TrainingMachine", nil)
step(F.Time + 0.5)

print("\n== K4. Ramassage : Cash")
P1:SetAttribute("Cash", 1300)
P1:SetAttribute("CashCollected", 1200)
step(1 / 30)
list = gains()
bb = list[1]
check(#list == 1 and bb:GetAttribute("GainKind") == "Cash", "K4a GainKind = Cash")
check(bb and sameColor(el(bb, "Amount").TextColor3, F.Colors.Cash), "K4b Amount en #5CFF4A")
step(3)

local same, why = sameAs(gainSnap, BB_GAIN)
check(same, `K5 le modèle BB_Gain de Clément n'est pas touché ({why})`)
check(el(BB_GAIN, "Amount").TextColor3 == templateColor and BB_GAIN:GetAttribute("GainKind") == nil, "K6 ni sa couleur ni d'attribut sur le modèle")
summary()
