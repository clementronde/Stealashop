---------------------------------------------------------------- scénario « escape » (L-095 point 4) : UI_Escape, SafeFlash
local S = UiMotionC.SafeFlash
local Definitions = requireModule(ReplicatedStorage.Shared.Net.Definitions, "client")

print("\n== E0. Valeurs (note de Clément) et remote BoxSecured")
check(S.FlashFrom == 0.05 and S.FlashTime == 0.5 and S.FovAdd == 12 and S.FovInTime == 0.08 and S.FovOutTime == 0.45 and S.BannerTime == 0.35, "E0a Flash 0,05 → 1 en 0,5 ; + 12 en 0,08, retour en 0,45 ; bannière en 0,35")
check(S.TitleFrom == -14 and S.PartsGap == 0.07 and S.Hold == 2.3 and S.OutTime == 0.15 and S.SoundGap == 0.12, "E0b Title de −14°, 0,07 s entre BoxIcon et Subtitle, 2,3 s, sortie 0,15, sons à 0,12 s")
check(S.Sounds[1] == "Heist_SafeFlash" and S.Sounds[2] == "Heist_Escape", "E0c Heist_SafeFlash puis Heist_Escape")
local def = nil
for _, entry in Definitions.List do
	if entry.Name == "BoxSecured" then
		def = entry
	end
end
check(def ~= nil and def.Direction == "ServerToClient" and #def.Args == 1 and def.Args[1].Kind == "string", "E0d remote BoxSecured(tier) du serveur vers le client")
check(Definitions.List[#Definitions.List] == def, "E0e ajouté à la fin de Net/Definitions")

local escapeGui = makeEscape()
local banner, flash = escapeGui.Banner, escapeGui.Flash
local title, subtitle, icon = banner.Title, banner.Subtitle, banner.BoxIcon
local snap = snapshot(escapeGui)
local Chase = requireModule(CHASE_MODULE, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Feel.Start)
step(0.1)
local cam = Workspace.CurrentCamera
local base = cam.FieldOfView

print("\n== E1. Arrivée en zone safe (colis Premium)")
local soundsBefore = #SOUNDS_PLAYED
Feel.Escape("Premium")
check(Feel.GetEscapeState().Count == 1, "E1a une arrivée jouée")
check(escapeGui.Enabled == true, "E1b UI_Escape allumé")
check(near(flash.BackgroundTransparency, S.FlashFrom, 1e-6), `E1c Flash à {S.FlashFrom}`)
local bannerScale = scaleNamed(banner, S.ScaleName)
check(bannerScale ~= nil and bannerScale.Scale == 0, "E1d Banner à 0 (UIScale passager)")
check(title.Rotation == S.TitleFrom, `E1e Title à {S.TitleFrom}°`)
check(icon.Image == BOX_PREMIUM_TEXTURE, `E1f BoxIcon = ICON_BOX_Premium ({icon.Image})`)
check(scaleNamed(subtitle, S.ScaleName) ~= nil and scaleNamed(icon, S.ScaleName) ~= nil, "E1g BoxIcon et Subtitle à 0")
local played = soundsSince(soundsBefore)
check(played[1] == "Heist_SafeFlash" and #played == 1, `E1h Heist_SafeFlash tout de suite ({table.concat(played, ", ")})`)
check(near(cam.FieldOfView, base, 1e-6), "E1i champ de vision de départ")
step(S.FovInTime)
check(near(cam.FieldOfView, base + S.FovAdd, 0.3), `E1j + {S.FovAdd} en {S.FovInTime} s ({cam.FieldOfView})`)
step(S.SoundGap - S.FovInTime + 1 / 60)
played = soundsSince(soundsBefore)
check(played[2] == "Heist_Escape", `E1k Heist_Escape {S.SoundGap} s après ({table.concat(played, ", ")})`)
step(S.FovOutTime + 0.05)
check(near(cam.FieldOfView, base, 1e-6), `E1l retour à {base} ({cam.FieldOfView})`)
check(flash.BackgroundTransparency > 0.9, `E1m Flash presque effacé ({flash.BackgroundTransparency})`)
step(0.2)
check(near(bannerScale.Scale, 1, 0.02) and near(title.Rotation, -3, 0.3), `E1n Banner à 1, Title revenu à −3° ({bannerScale.Scale}, {title.Rotation})`)
check(countClass(subtitle, "UIScale") == 0 or near(scaleNamed(subtitle, S.ScaleName).Scale, 1, 0.02), "E1o Subtitle arrivé")
check(flash.BackgroundTransparency == 1, "E1p Flash à 1")
local spent = S.FovInTime + (S.SoundGap - S.FovInTime + 1 / 60) + (S.FovOutTime + 0.05) + 0.2
step(S.Hold + S.OutTime / 2 - spent)
check(escapeGui.Enabled == true and bannerScale.Scale < 1, `E1q au bout de {S.Hold} s, Banner rapetisse ({bannerScale.Scale})`)
step(S.OutTime / 2 + 0.05)
check(escapeGui.Enabled == false, "E1r puis l'écran s'éteint")
check(anyUIScale(escapeGui) == nil, "E1s aucun UIScale laissé")
local same, why = sameAs(snap, escapeGui, { [escapeGui] = { Enabled = true }, [icon] = { Image = true } })
check(same, `E1t UI_Escape comme Clément l'a fait (sauf l'icône du colis) ({why})`)
check(not Feel.GetEscapeState().Active and not Feel.GetEscapeState().Escaping, "E1u plus rien en cours")

print("\n== E2. Pendant une poursuite : le champ de vision revient d'un coup, puis + 12, puis la base")
Chase.chased = true
step(0.5)
check(near(cam.FieldOfView, base + UiMotionC.ChaseFov.Add, 0.05), `E2a poursuite : + {UiMotionC.ChaseFov.Add} ({cam.FieldOfView})`)
Feel.Escape("Standard")
check(near(cam.FieldOfView, base, 1e-6), `E2b revenu d'un coup à {base} ({cam.FieldOfView})`)
check(icon.Image == BOX_PREMIUM_TEXTURE, "E2c ICON_BOX_Standard pas livrée : BoxIcon garde son image")
step(1 / 30)
Chase.chased = false -- la poursuite finit pendant l'arrivée (ChaseState du serveur)
step(S.FovInTime)
check(cam.FieldOfView > base + S.FovAdd / 2, `E2d le zoom de la zone safe continue ({cam.FieldOfView})`)
step(S.FovOutTime + 0.2)
check(near(cam.FieldOfView, base, 1e-6), `E2e fini à {base}, pas à la valeur de la poursuite ({cam.FieldOfView})`)
step(1)
check(near(cam.FieldOfView, base, 1e-6), "E2f et il y reste")
step(S.Hold)
check(escapeGui.Enabled == false and anyUIScale(escapeGui) == nil, "E2g écran éteint, rien laissé")

print("\n== E3. Deux arrivées de suite : la seconde reprend tout")
Feel.Escape("Premium")
step(1)
Feel.Escape("Premium")
check(near(flash.BackgroundTransparency, S.FlashFrom, 1e-6) and title.Rotation == S.TitleFrom, "E3a Flash et Title repartent")
local scales = 0
for _, child in banner:GetChildren() do
	if child.ClassName == "UIScale" then
		scales += 1
	end
end
check(scales == 1, `E3b un seul UIScale sur Banner ({scales})`)
step(S.Hold + S.OutTime + 0.2)
check(escapeGui.Enabled == false and anyUIScale(escapeGui) == nil and title.Rotation == -3, "E3c fini proprement")

print("\n== E4. Sans UI_Escape : sons et champ de vision quand même")
escapeGui:Destroy()
soundsBefore = #SOUNDS_PLAYED
Feel.Escape("Premium")
step(S.FovInTime)
check(cam.FieldOfView > base + S.FovAdd / 2, "E4a zoom")
step(1)
check(#soundsSince(soundsBefore) == 2 and near(cam.FieldOfView, base, 1e-6), "E4b deux sons, champ de vision rendu")

print("\n== E5. Par le remote BoxSecured (UnboxService → UiFeelController)")
local count = Feel.GetEscapeState().Count
local NetServer = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
NetServer.Server.BoxSecured:Fire(P1, "Premium")
step(1 / 30)
check(Feel.GetEscapeState().Count == count + 1, "E5a le remote joue l'arrivée en zone safe")
step(2)
summary()
