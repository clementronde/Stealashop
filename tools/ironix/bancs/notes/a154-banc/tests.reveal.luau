---------------------------------------------------------------- scénario « reveal » (a154, vague 46) : flash et zoom de la révélation
local S = UiMotionC.SafeFlash
local V = UiMotionC.RevealFlash

print("\n== R0. Réglages V0 = ceux de l'arrivée en zone safe")
check(V ~= nil and V.FlashFrom == S.FlashFrom and V.FlashTime == S.FlashTime and V.FovAdd == S.FovAdd and V.FovInTime == S.FovInTime and V.FovOutTime == S.FovOutTime, "R0a flash 0,05 → 1 en 0,5 ; + 12 en 0,08, retour en 0,45")

local escapeGui = makeEscape()
local banner, flash = escapeGui.Banner, escapeGui.Flash
local title = banner.Title
local snap = snapshot(escapeGui)
local Chase = requireModule(CHASE_MODULE, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)
local cam = Workspace.CurrentCamera
local base = cam.FieldOfView

print("\n== R1. Révélation seule : flash et zoom, sans bannière ni son")
local soundsBefore = #SOUNDS_PLAYED
Feel.RevealFlash()
check(Feel.GetEscapeState().Reveals == 1 and Feel.GetEscapeState().Count == 0, "R1a une révélation, aucune arrivée")
check(escapeGui.Enabled == true and near(flash.BackgroundTransparency, V.FlashFrom, 1e-6), "R1b UI_Escape allumé, Flash à 0,05")
local bs = scaleNamed(banner, S.ScaleName)
check(bs ~= nil and bs.Scale == 0, "R1c Banner à l'échelle 0 (cachée)")
step(V.FovInTime)
check(near(cam.FieldOfView, base + V.FovAdd, 0.3), `R1d zoom + {V.FovAdd} ({cam.FieldOfView})`)
step(0.2)
check(bs.Scale == 0 and title.Rotation == -3, "R1e la bannière ne sort jamais")
check(#soundsSince(soundsBefore) == 0, "R1f aucun son")
step(V.FlashTime)
check(escapeGui.Enabled == false and near(cam.FieldOfView, base, 1e-6), `R1g écran éteint, caméra rendue ({cam.FieldOfView})`)
local same, why = sameAs(snap, escapeGui, { [escapeGui] = { Enabled = true } })
check(same and anyUIScale(escapeGui) == nil, `R1h rien laissé ({why})`)

print("\n== R2. Révélation puis arrivée tout de suite : l'arrivée prend l'écran, caméra pas bloquée")
Feel.RevealFlash()
step(0.05)
Feel.Escape(nil, nil, "Z3_Smartphone")
check(Feel.GetEscapeState().Kind == "Escape", "R2a l'arrivée remplace la révélation")
local bs2 = scaleNamed(banner, S.ScaleName)
step(0.3)
check(bs2 ~= nil and bs2.Scale > 0.5, `R2b la bannière sort ({bs2 and bs2.Scale})`)
step(S.FovInTime + S.FovOutTime + 0.1)
check(near(cam.FieldOfView, base, 1e-6), `R2c caméra rendue à {base} ({cam.FieldOfView})`)
step(S.Hold + S.OutTime + 0.2)
check(escapeGui.Enabled == false and anyUIScale(escapeGui) == nil and title.Text == "ESCAPED!", "R2d fini proprement")

print("\n== R3. Arrivée puis révélation : la bannière reste, le flash repart")
Feel.Escape("Premium")
step(0.5)
local bs3 = scaleNamed(banner, S.ScaleName)
Feel.RevealFlash()
check(Feel.GetEscapeState().Kind == "Escape" and bs3 ~= nil and bs3.Parent ~= nil and bs3.Scale > 0.9, "R3a la bannière de l'arrivée reste")
check(near(flash.BackgroundTransparency, V.FlashFrom, 1e-6), "R3b flash relancé")
step(S.Hold + S.OutTime + 0.2)
check(escapeGui.Enabled == false and anyUIScale(escapeGui) == nil and near(cam.FieldOfView, base, 1e-6), "R3c écran éteint, caméra rendue, rien laissé")

print("\n== R4. Deux révélations de suite : un seul écran, caméra jamais bloquée")
Feel.RevealFlash()
step(0.04)
Feel.RevealFlash()
local n = 0
for _, c in banner:GetChildren() do
	if c.ClassName == "UIScale" then
		n += 1
	end
end
check(n == 1, `R4a un seul UIScale sur Banner ({n})`)
step(V.FovInTime + V.FovOutTime + V.FlashTime)
check(escapeGui.Enabled == false and near(cam.FieldOfView, base, 1e-6) and not Feel.GetEscapeState().Escaping, `R4b fini : caméra à {base} ({cam.FieldOfView})`)

print("\n== R5. Pendant une poursuite : la caméra retrouve le ChaseFov")
Chase.chased = true
step(0.5)
local chaseFov = base + UiMotionC.ChaseFov.Add
check(near(cam.FieldOfView, chaseFov, 0.05), `R5a poursuite ({cam.FieldOfView})`)
Feel.RevealFlash()
step(V.FovInTime + V.FovOutTime + 0.6)
check(near(cam.FieldOfView, chaseFov, 0.05), `R5b revenu au ChaseFov ({cam.FieldOfView})`)
Chase.chased = false
step(1)
check(near(cam.FieldOfView, base, 1e-6), `R5c poursuite finie : base ({cam.FieldOfView})`)

print("\n== R6. Sans UI_Escape : zoom quand même")
escapeGui:Destroy()
Feel.RevealFlash()
step(V.FovInTime)
check(cam.FieldOfView > base + V.FovAdd / 2, "R6a zoom")
step(1)
check(near(cam.FieldOfView, base, 1e-6), "R6b caméra rendue")
summary()
