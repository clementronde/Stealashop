---------------------------------------------------------------- scénarios a256 (vague 73, L-230 : fenêtres comme Throw a Seed)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Tweens simulés (TIMED_TWEENS d'ext-a189).
-- Modules montés à part (Controllers256) : Motion, Appear, HudMask, UiMotionController.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers256")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local hudMaskModule = moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseController256"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController256")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local HudMask = requireModule(hudMaskModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
Motion.SetSoundPlayer(function()
	return true
end)
step(0.1)

local function screen(name, enabled, attrs)
	local gui = new("ScreenGui", { Name = name, Enabled = enabled })
	for k, v in attrs or {} do
		gui:SetAttribute(k, v)
	end
	gui.Parent = playerGui
	return gui
end
local function blurEffect()
	local found = LightingService:FindFirstChild("UiBlur")
	if found then
		return found
	end
	local ok, camera = pcall(function()
		return Workspace.CurrentCamera
	end)
	return if ok and camera then camera:FindFirstChild("UiBlur") else nil
end

---------------------------------------------------------------- 0. Valeurs
print("-- Valeurs")
check(UiMotion.WindowTas == true, "V1 interrupteur WindowTas allumé")
check(UiMotion.Open.From == 0.84 and UiMotion.Open.Time == 0.26 and UiMotion.Open.Style == Enum.EasingStyle.Back and UiMotion.Open.Direction == Enum.EasingDirection.Out, "V2 ouverture : 0,84 → 1 en 0,26 s, Back Out")
check(UiMotion.Close.To == 0.9 and UiMotion.Close.Time == 0.13, "V3 fermeture : vers 0,9 en 0,13 s")
local blur = UiMotion.Blur
check(blur.Size == 16 and blur.InTime == 0.2 and blur.OutTime == 0.15 and blur.OutDelay == 0.07 and blur.Style == Enum.EasingStyle.Quad and blur.Direction == Enum.EasingDirection.InOut and blur.UnderCamera == true, "V4 flou : 16, entrée 0,2 s, sortie 0,15 s 70 ms après, Quad InOut, sous la caméra")
check(UiMotion.HudAway.Enabled == false and UiMotion.HudHide.Enabled == true, "V5 barre qui s'écarte coupée, HUD caché allumé")
check(table.find(UiMotion.HudHide.Hide, "UI_HUD") ~= nil and table.find(UiMotion.HudHide.Hide, "UI_Hotbar") ~= nil, "V6 HUD caché : UI_HUD et UI_Hotbar")
check(table.find(UiMotion.Blur.Screens, "UI_Rebirth") ~= nil and table.find(UiMotion.Blur.Screens, "UI_Offline") == nil, "V7 flou : grandes fenêtres (renaissance), pas les petites (hors ligne)")

---------------------------------------------------------------- 1. HUD caché à l'image même
print("-- HUD")
local hud = screen("UI_HUD", true)
local hotbar = screen("UI_Hotbar", true)
local notify = screen("UI_Notify", true)
local small = screen("UI_Offline", false)
local shop = screen("UI_WeaponShop", false)
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, shop)
step(0.05)
small.Enabled = true
step(0.01)
check(hud.Enabled and hotbar.Enabled and blurEffect() == nil, "H1 petite fenêtre : HUD gardé, pas de flou")
small.Enabled = false
step(0.05)
Motion.Open(shop) -- allume l écran (Enabled) et joue l ouverture
check(not hud.Enabled and not hotbar.Enabled, "H2 grande fenêtre : HUD éteint à l'image même (sans attendre)")
check(notify.Enabled, "H3 messages (UI_Notify) gardés")
step(0.3)
local effect = blurEffect()
check(effect ~= nil and near(effect.Size, 16), "H4 flou monté à 16")
hud.Enabled = true -- un autre code le rallume
step(0.3)
check(not hud.Enabled, "H5 HUD rallumé par un autre code : recaché")
CHASED = true
step(0.1)
check(hud.Enabled and hotbar.Enabled, "H6 poursuite : HUD rendu")
CHASED = false
step(0.1)
check(not hud.Enabled, "H7 poursuite finie, boutique ouverte : HUD recaché")
Motion.Close(shop)
step(0.05)
check(not hud.Enabled and shop.Enabled, "H8 fermeture en cours : HUD toujours caché")
step(0.5)
check(not shop.Enabled and hud.Enabled and hotbar.Enabled, "H9 fenêtre éteinte : HUD rendu (avec la valeur rallumée)")
step(0.3)
check(blurEffect() == nil, "H10 flou parti et détruit")
check(HudMask.IsActive("WindowHud") == false, "H11 masque WindowHud retiré")

---------------------------------------------------------------- 2. Attribut HideHud, HideScreens avec un autre masque
print("-- Attribut et masques")
local marked = screen("UI_T256Marked", false, { HideHud = true })
step(0.05)
marked.Enabled = true
check(not hud.Enabled, "A1 ScreenGui avec HideHud = true : HUD caché")
marked.Enabled = false
step(0.05)
check(hud.Enabled, "A2 éteint : HUD rendu")
local other = screen("UI_T256Other", true)
HudMask.Push("T256", { HideScreens = { "UI_HUD" } })
check(not hud.Enabled and other.Enabled and hotbar.Enabled, "A3 HideScreens : seul l'écran listé est masqué")
HudMask.Push("T256b", { KeepScreens = { "UI_HUD" } })
check(not hud.Enabled and not other.Enabled, "A4 avec un masque KeepScreens : les deux s'additionnent")
HudMask.Pop("T256b")
HudMask.Pop("T256")
check(hud.Enabled and other.Enabled and hotbar.Enabled, "A5 masques retirés : tout est rendu")
step(1)
summary()
