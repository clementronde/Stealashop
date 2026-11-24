---------------------------------------------------------------- scénario « banner » (L-092 3a) : RunBanner de UI_Chase
local B, PULSE = UiMotionC.RunBanner, UiMotionC.ChasePulse
local Motion = requireModule(MOTION_MODULE, "client")

local chaseGui = new("ScreenGui", { Name = "UI_Chase", Enabled = false }, PLAYER_GUI)
local edges = new("ImageLabel", { Name = "ScreenEdges", ImageTransparency = 0.3, Size = UDim2.fromScale(1, 1) }, chaseGui)
local banner = new("TextLabel", { Name = "RunBanner", Text = "RUN!", Rotation = 2, Size = UDim2.fromScale(0.4, 0.15) }, chaseGui)
local panel = new("Frame", { Name = "Panel", Size = UDim2.fromScale(0.3, 0.1) }, chaseGui)
local snap = snapshot(chaseGui)

local Chase = requireModule(CHASE_MODULE, "client")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)

print("\n== B1. Entrée : 0 → Peak → 1, son propre UIScale")
Motion.Open(chaseGui) -- comme ChaseController
Chase.chased = true
step(1 / 60)
local own = scaleNamed(banner, B.ScaleName)
check(own ~= nil, `B1a RunBanner reçoit son UIScale {B.ScaleName}`)
check(countClass(banner, "UIScale") == 1, "B1b un seul UIScale sur RunBanner (Motion.Open ne le met pas à l'échelle)")
check(scaleNamed(panel, UiMotionC.ScaleName) ~= nil, "B1c les autres cadres racine s'ouvrent toujours avec Motion.Open")
check(own and own.Scale < 0.5, `B1d il part de 0 ({own and own.Scale})`)
step(B.InTime)
check(own and near(own.Scale, B.Peak, 0.03), `B1e au bout de InTime : × {B.Peak} ({own and own.Scale})`)
step(B.SettleTime + 1 / 60)
check(own and own.Scale >= 1 - 1e-6 and own.Scale <= 1 + B.Beat + 1e-6, `B1f puis 1 ({own and own.Scale})`)

print("\n== B2. Battement et inclinaison au rythme des bords")
local minS, maxS, minR, maxR = 10, 0, 10, -10
local agree = 0
for _ = 1, 60 do
	step(1 / 30)
	minS = math.min(minS, own.Scale)
	maxS = math.max(maxS, own.Scale)
	minR = math.min(minR, banner.Rotation)
	maxR = math.max(maxR, banner.Rotation)
	-- Plus gros quand les bords sont le plus visibles (transparence basse).
	local edgesStrong = edges.ImageTransparency < (PULSE.Min + PULSE.Max) / 2
	if edgesStrong == (own.Scale > 1 + B.Beat / 2) then
		agree += 1
	end
end
check(minS >= 1 - 1e-6 and maxS <= 1 + B.Beat + 1e-6 and maxS - minS > B.Beat * 0.8, `B2a il bat de 1 à {1 + B.Beat} ({minS} à {maxS})`)
check(minR >= 2 - B.Tilt - 1e-6 and maxR <= 2 + B.Tilt + 1e-6 and maxR - minR > B.Tilt, `B2b il penche de ± {B.Tilt}° autour de sa Rotation ({minR} à {maxR})`)
check(agree >= 56, `B2c le battement suit les bords ({agree} images sur 60)`)

print("\n== B3. Fin de la poursuite : rien n'est laissé")
Chase.chased = false
step(1 / 30)
check(countClass(banner, "UIScale") == 0, "B3a UIScale détruit")
check(banner.Rotation == 2, `B3b Rotation d'origine remise ({banner.Rotation})`)
Motion.Close(chaseGui)
step(0.5)

print("\n== B4. Nouvelle poursuite, puis coupée pendant l'entrée")
Motion.Open(chaseGui)
Chase.chased = true
step(B.InTime / 2)
check(scaleNamed(banner, B.ScaleName) ~= nil, "B4a nouvelle entrée")
Chase.chased = false
step(B.InTime + B.SettleTime + 0.1)
check(countClass(banner, "UIScale") == 0 and banner.Rotation == 2, "B4b coupée : rien n'est laissé")
Motion.Close(chaseGui)
step(0.5)

print("\n== B5. RunBanner avec un UIScale de Clément : jamais touché")
local clement = new("UIScale", { Name = "UIScale", Scale = 0.9 }, banner)
Chase.chased = true
step(B.InTime + B.SettleTime + 0.5)
check(clement.Scale == 0.9 and countClass(banner, "UIScale") == 1, "B5a son UIScale reste à 0,9, aucun autre")
Chase.chased = false
step(0.1)
check(banner.Rotation == 2, "B5b Rotation remise")
clement:Destroy()

local same, why = sameAs(snap, chaseGui)
check(same, `B6 UI_Chase comme au départ ({why})`)
summary()
