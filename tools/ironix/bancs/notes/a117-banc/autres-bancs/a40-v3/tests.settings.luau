--!nocheck
-- Scénario « settings » (a67, 2026-11-11, L-095 point 2) : vrai SettingsService (profil, remote
-- SaveSettings contrôlé par Net) et vrai SettingsController sur une copie de UI_Settings et du HUD
-- (SocialRow.SettingsButton caché) : curseurs à la souris et au doigt, bascule des effets visuels, son de
-- clic, groupe SFX, sauvegarde puis rechargement, valeurs refusées par le serveur.
-- Un seul Player pour le serveur et le client (faux Roblox) : les attributs posés par l'un sont lus par
-- l'autre tout de suite.

moduleScript(SERVICES, "SettingsService", "server/Services/SettingsService.luau")
moduleScript(CONTROLLERS, "SettingsController", "client/Controllers/SettingsController.luau")
buildClickSounds()
advance(1000)
startServer()
local Settings = sharedModule("Config/Settings")
local SoundService = games.client:GetService("SoundService")
local sounds = watchPops()

local ada = join("Ada", newProfile(), 1)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildSettingsGui(playerGui)
local hud = buildHud67(playerGui)
advance(1.5)

section("chargement : réglages par défaut")
check(ada:GetAttribute("MusicVolume") == 0.8 and ada:GetAttribute("SfxVolume") == 1 and ada:GetAttribute("VfxEnabled") == true and ada:GetAttribute("ClickSound") == "Classic", "profil sans réglages : attributs par défaut (80 %, 100 %, ON, CLASSIC)")
check(dataOf(ada).Settings == nil, "le profil n'est pas réécrit au chargement")

startClient(ada)
local rows = gui.Root.Window.Rows
local music, sound, toggle, clickRow = rows.MusicRow, rows.SoundRow, rows.VfxRow.Toggle, rows.ClickRow
local settingsButton = hud.SocialRow.SettingsButton
check(logHas("[Loader Client] 2 module(s) démarré(s)", "PRINT", "client") and not logHas("[Loader Client]", "WARN"), "SettingsController démarré sans erreur")
check(settingsButton.Visible == true, "Features.Settings : SettingsButton montré")
check(gui.Enabled == false, "UI_Settings fermé jusqu'au bouton")
local group = SoundService:FindFirstChild(Settings.SfxGroup)
check(group ~= nil and group.ClassName == "SoundGroup" and group.Volume == 1, "groupe SFX créé dans SoundService, Volume 1")

section("ouverture")
click(settingsButton)
check(gui.Enabled == true, "SettingsButton ouvre UI_Settings")
check(textOf(music, "ValueLabel") == "80%" and near(music.Slider.Track.Fill.Size.X.Scale, 0.8) and near(music.Slider.Knob.Position.X.Scale, 0.8), "MUSIC : 80 %, Fill et Knob à 0,8")
check(textOf(sound, "ValueLabel") == "100%" and near(sound.Slider.Track.Fill.Size.X.Scale, 1) and sound.Slider.Track.Fill.Size.Y.Scale == 1, "SOUND EFFECTS : 100 %")
check(toggle.OnFill.Visible and not toggle.OffFill.Visible and toggle.ToggleLabel.Text == "ON" and toggle.ToggleKnob.Position == TOGGLE_KNOB_POS, "VISUAL EFFECTS : ON, à la place de Clément")
check(clickRow.ChoiceLabel.Text == "CLASSIC", "CLICK SOUND : CLASSIC")
local knobScale = music.Slider.Knob:FindFirstChild(Settings.Motion.KnobGrab.ScaleName)
check(knobScale ~= nil and knobScale.Scale == 1, "UIScale KnobScale posé à 1 sur le bouton rond")

section("curseur MUSIC à la souris")
SERVER_CALLS = {}
music.Slider.Knob.InputBegan:Fire(inputObject("MouseButton1", 150))
check(near(ada:GetAttribute("MusicVolume"), 0.25) and textOf(music, "ValueLabel") == "25%", "appui sur le bouton rond à x = 150 : 25 %")
check(knobScale.Scale == Settings.Motion.KnobGrab.To, "T.47 KnobGrab : × 1,18 pendant le glisser")
USER_INPUT.InputChanged:Fire(inputObject("MouseMovement", 250))
check(near(ada:GetAttribute("MusicVolume"), 0.75) and near(music.Slider.Knob.Position.X.Scale, 0.75) and music.Slider.Knob.Position.Y.Scale == 0.5, "glissé à x = 250 : 75 %, le bouton suit (Y gardé)")
USER_INPUT.InputChanged:Fire(inputObject("MouseMovement", 900))
check(ada:GetAttribute("MusicVolume") == 1 and textOf(music, "ValueLabel") == "100%", "au-delà de la barre : 100 %")
USER_INPUT.InputChanged:Fire(inputObject("MouseMovement", 160))
USER_INPUT.InputEnded:Fire(inputObject("MouseButton1", 160))
check(knobScale.Scale == 1 and near(ada:GetAttribute("MusicVolume"), 0.3), "relâché : retour à 1, 30 %")
USER_INPUT.InputChanged:Fire(inputObject("MouseMovement", 300))
check(near(ada:GetAttribute("MusicVolume"), 0.3), "après le relâché, la souris ne bouge plus rien")
check(#serverCalls("SaveSettings") == 0, "rien n'est envoyé pendant le glisser")
advance(0.6)
local calls = serverCalls("SaveSettings")
check(#calls == 1, `un seul envoi SaveSettings ({#calls})`)
local saved = dataOf(ada).Settings
check(saved ~= nil and near(saved.Music, 0.3) and saved.Sfx == 1 and saved.Vfx == true and saved.Click == "Classic", "profil : Settings enregistré")

section("curseur SOUND EFFECTS au doigt, groupe SFX")
local finger = inputObject("Touch", 200)
sound.Slider.Track.InputBegan:Fire(finger)
check(near(ada:GetAttribute("SfxVolume"), 0.5) and near(group.Volume, 0.5), "appui sur la barre à x = 200 : 50 %, groupe SFX à 0,5")
local other = inputObject("Touch", 280)
USER_INPUT.InputChanged:Fire(other)
check(near(ada:GetAttribute("SfxVolume"), 0.5), "un autre doigt (joystick) ne bouge pas le curseur")
finger.Position = Vector3.new(120, 0, 0)
USER_INPUT.InputChanged:Fire(finger)
check(near(ada:GetAttribute("SfxVolume"), 0.1) and textOf(sound, "ValueLabel") == "10%", "le doigt glisse à x = 120 : 10 %")
USER_INPUT.InputEnded:Fire(other)
check(sound.Slider.Knob:FindFirstChild("KnobScale").Scale == Settings.Motion.KnobGrab.To, "l'autre doigt levé : le glisser continue")
USER_INPUT.InputEnded:Fire(finger)
check(sound.Slider.Knob:FindFirstChild("KnobScale").Scale == 1, "le doigt levé : fin du glisser")
local part = make("Part", { Name = "Glass" }, Workspace)
local hit = make("Sound", { Name = "Glass_Hit" }, part)
local hub = make("Sound", { Name = "MUS_Hub" }, SoundService)
local own = make("SoundGroup", { Name = "Ambience" }, SoundService)
local fountain = make("Sound", { Name = "Fountain", SoundGroup = own }, Workspace)
check(hit.SoundGroup == group and hub.SoundGroup == nil and fountain.SoundGroup == own, "sons du Workspace dans SFX ; musique (MUS_) et son déjà rangé laissés")

section("son de clic")
PLAYED = {}
click(hud.LeftRail.IndexButton)
check(#PLAYED == 1 and PLAYED[1].name == "UI_Click_Classic" and PLAYED[1].group == "SFX", "un bouton du HUD : UI_Click_Classic, dans le groupe SFX")
PLAYED = {}
click(clickRow.NextButton)
check(clickRow.ChoiceLabel.Text == "SHARP" and ada:GetAttribute("ClickSound") == "Sharp", "NextButton : SHARP")
check(#PLAYED == 1 and PLAYED[1].name == "UI_Click_Sharp", "le nouveau son joue tout de suite, une seule fois")
click(clickRow.PrevButton)
click(clickRow.PrevButton)
check(clickRow.ChoiceLabel.Text == "SOFT" and ada:GetAttribute("ClickSound") == "Soft", "PrevButton deux fois : SOFT (en boucle)")
PLAYED = {}
click(gui.Root.Window.CloseButton)
check(#PLAYED == 1 and PLAYED[1].name == "UI_Click_Soft" and gui.Enabled == false, "CloseButton : UI_Click_Soft, l'écran se ferme")
click(settingsButton)
check(gui.Enabled == true and clickRow.ChoiceLabel.Text == "SOFT", "réouverture : SOFT")

section("effets visuels")
click(toggle)
check(ada:GetAttribute("VfxEnabled") == false and Settings.VfxReduced(ada), "Toggle : VfxEnabled = false")
check(not toggle.OnFill.Visible and toggle.OffFill.Visible and toggle.ToggleLabel.Text == "OFF", "OffFill visible, « OFF »")
check(near(toggle.ToggleKnob.Position.X.Scale, 0.03) and toggle.ToggleKnob.Position.Y.Scale == 0.5 and toggle.ToggleKnob.AnchorPoint.X == 0, "T.48 ToggleSlide : le bouton rond de l'autre côté")
check(near(toggle.ToggleLabel.Position.X.Scale, 0.92) and toggle.ToggleLabel.AnchorPoint.X == 1, "ToggleLabel de l'autre côté")
advance(0.6)
saved = dataOf(ada).Settings
check(#serverCalls("SaveSettings") == 2 and saved.Vfx == false and saved.Click == "Soft" and near(saved.Sfx, 0.1), "un 2e envoi pour tous ces changements : SOFT, OFF, 10 %")

section("sauvegarde et rechargement")
leave(ada)
local ada2 = join("Ada", nil, 1)
advance(1.5)
check(near(ada2:GetAttribute("MusicVolume"), 0.3) and near(ada2:GetAttribute("SfxVolume"), 0.1) and ada2:GetAttribute("VfxEnabled") == false and ada2:GetAttribute("ClickSound") == "Soft", "retour : réglages relus du profil")

section("valeurs refusées par le serveur")
local before = table.clone(dataOf(ada2).Settings)
local function same()
	local now = dataOf(ada2).Settings
	return near(now.Music, before.Music) and near(now.Sfx, before.Sfx) and now.Vfx == before.Vfx and now.Click == before.Click
end
fireAs(ada2, "SaveSettings", 2, 0.5, true, "Classic")
check(same(), "musique à 2 : refusé (Net, 0 à 1)")
fireAs(ada2, "SaveSettings", 0.5, -0.1, true, "Classic")
check(same(), "effets à −0,1 : refusé")
fireAs(ada2, "SaveSettings", 0 / 0, 0.5, true, "Classic")
check(same(), "NaN : refusé")
fireAs(ada2, "SaveSettings", 0.5, 0.5, "yes", "Classic")
check(same(), "effets visuels pas booléens : refusé")
advance(1.1) -- débit : 4 appels par seconde
fireAs(ada2, "SaveSettings", 0.5, 0.5, true, "Loud")
check(same() and logHas("son de clic « Loud » inconnu", "PRINT", "server"), "son de clic inconnu : refusé par SettingsService")
fireAs(ada2, "SaveSettings", 0.5, 0.5, true, string.rep("x", 40))
check(same(), "texte trop long : refusé")
fireAs(ada2, "SaveSettings", 0.5, 0.5, true)
check(same(), "argument manquant : refusé")
check(ada2:GetAttribute("ClickSound") == "Soft" and near(ada2:GetAttribute("MusicVolume"), 0.3), "attributs inchangés")
advance(1.1)
fireAs(ada2, "SaveSettings", 0, 1, true, "Bubble")
check(dataOf(ada2).Settings.Click == "Bubble" and dataOf(ada2).Settings.Music == 0 and ada2:GetAttribute("ClickSound") == "Bubble" and ada2:GetAttribute("MusicVolume") == 0, "valeurs bonnes (0 et 1 compris) : acceptées, attributs à jour")
advance(2)
for _ = 1, 8 do
	fireAs(ada2, "SaveSettings", 0.5, 0.5, true, "Tick")
end
fireAs(ada2, "SaveSettings", 0.9, 0.5, true, "Tick")
check(near(dataOf(ada2).Settings.Music, 0.5), `débit : au-delà de {Settings.SaveRate} envois par seconde, ignoré`)

section("profil abîmé")
leave(ada2)
SAVED["Player_1"].Settings = { Music = "loud", Sfx = 5, Vfx = "no", Click = "Bogus" }
local ada3 = join("Ada", nil, 1)
advance(1.5)
check(ada3:GetAttribute("MusicVolume") == 0.8 and ada3:GetAttribute("SfxVolume") == 1 and ada3:GetAttribute("VfxEnabled") == true and ada3:GetAttribute("ClickSound") == "Classic", "champs invalides : valeurs par défaut")
leave(ada3)
SAVED["Player_1"].Settings = { Music = 0.4, Vfx = false }
local ada4 = join("Ada", nil, 1)
advance(1.5)
check(ada4:GetAttribute("MusicVolume") == 0.4 and ada4:GetAttribute("SfxVolume") == 1 and ada4:GetAttribute("VfxEnabled") == false and ada4:GetAttribute("ClickSound") == "Classic", "champs absents : valeur par défaut, les autres gardés")

summary("scénario settings")
