--!nocheck
-- Scénario « settingsoff » (a67, 2026-11-11, L-095 point 2) : Features.Settings à false. Le bouton reste
-- caché et l'écran n'est pas branché, mais les réglages sauvegardés s'appliquent (attributs, groupe SFX,
-- son de clic).

setFeature("Settings", false)
moduleScript(SERVICES, "SettingsService", "server/Services/SettingsService.luau")
moduleScript(CONTROLLERS, "SettingsController", "client/Controllers/SettingsController.luau")
buildClickSounds()
advance(1000)
startServer()
local Settings = sharedModule("Config/Settings")
local SoundService = games.client:GetService("SoundService")
local data = newProfile()
data.Settings = { Music = 0.2, Sfx = 0.4, Vfx = false, Click = "Tick" }
local ada = join("Ada", data, 1)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildSettingsGui(playerGui)
local hud = buildHud67(playerGui)
advance(1.5)
startClient(ada)

check(sharedModule("Config/Features").Settings == false, "Features.Settings coupé")
check(ada:GetAttribute("MusicVolume") == 0.2 and ada:GetAttribute("SfxVolume") == 0.4 and ada:GetAttribute("VfxEnabled") == false and ada:GetAttribute("ClickSound") == "Tick", "réglages sauvegardés posés au chargement")
check(hud.SocialRow.SettingsButton.Visible == false, "SettingsButton reste caché")
click(hud.SocialRow.SettingsButton)
check(gui.Enabled == false, "l'écran ne s'ouvre pas")
local group = SoundService:FindFirstChild(Settings.SfxGroup)
check(group ~= nil and near(group.Volume, 0.4), "groupe SFX au volume sauvegardé")
PLAYED = {}
click(hud.LeftRail.IndexButton)
check(#PLAYED == 1 and PLAYED[1].name == "UI_Click_Tick" and PLAYED[1].group == "SFX", "le son de clic sauvegardé (TICK) joue quand même")
check(#serverCalls("SaveSettings") == 0, "rien n'est envoyé")

summary("scénario settingsoff")
