---------------------------------------------------------------- scénarios f70c1 (correctif f70 : B2 et B5)
-- Après setup.luau du banc a50. Modules montés à part (ControllersF70) : Motion, Appear, HudMask, UiMotionController.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "ControllersF70")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local hudMaskModule = moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseControllerF70"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseControllerF70")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local HelpInvite = requireModule(ReplicatedStorage.Shared.Config.HelpInvite, "client")
local Motion = requireModule(motionModule, "client")
local HudMask = requireModule(hudMaskModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
Motion.SetSoundPlayer(function()
	return true
end)
step(0.1)

local function screen(name, enabled)
	local gui = new("ScreenGui", { Name = name, Enabled = enabled })
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
local keep = UiMotion.HudHide.Keep
check(keep.UI_Displayed ~= nil and table.find(keep.UI_Displayed, "UI_Hotbar") ~= nil and table.find(keep.UI_Displayed, "UI_HUD") == nil, "V1 UI_Displayed garde UI_Hotbar (pas UI_HUD)")
local others = 0
for _, name in UiMotion.Windows do
	if name ~= "UI_Displayed" and keep[name] == nil then
		others += 1
	end
end
check(others == #UiMotion.Windows - 1 and others == 16, "V2 les 16 autres grandes fenêtres ne gardent rien")
check(table.find(UiMotion.Blur.Screens, "UI_Displayed") ~= nil, "V3 UI_Displayed floute toujours")
check(HelpInvite.Night == true, "V4 HelpInvite.Night = true (B5, Cantin le 18/11)")

---------------------------------------------------------------- 1. UI_Displayed seul
print("-- UI_Displayed")
local hud = screen("UI_HUD", true)
local hotbar = screen("UI_Hotbar", true)
local displayed = screen("UI_Displayed", false)
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.36, 0.64) }, displayed)
local shop = screen("UI_WeaponShop", false)
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, shop)
step(0.05)
Motion.Open(displayed)
check(displayed.Enabled and not hud.Enabled, "D1 ouvert : UI_HUD éteint à l'image même")
check(hotbar.Enabled and not HudMask.IsMasked(hotbar), "D2 UI_Hotbar gardée allumée (InventoryButton cliquable)")
check(HudMask.IsMasked(hud), "D3 HudMask.IsMasked(UI_HUD) vrai")
step(0.3)
local effect = blurEffect()
check(effect ~= nil and near(effect.Size, 16), "D4 flou monté à 16 (inchangé)")

---------------------------------------------------------------- 2. Une autre grande fenêtre par-dessus
print("-- Deux fenêtres")
Motion.Open(shop)
check(not hotbar.Enabled and not hud.Enabled, "W1 boutique ouverte en plus : barre cachée aussi")
check(HudMask.IsMasked(hotbar), "W2 HudMask.IsMasked(UI_Hotbar) vrai")
Motion.Close(shop)
step(0.5)
check(not shop.Enabled and hotbar.Enabled and not hud.Enabled, "W3 boutique fermée : barre rendue, HUD toujours caché")
check(HudMask.IsActive("WindowHud"), "W4 masque WindowHud toujours là (UI_Displayed ouvert)")

---------------------------------------------------------------- 3. Poursuite, puis fermeture
print("-- Fin")
CHASED = true
step(0.1)
check(hud.Enabled and hotbar.Enabled, "C1 poursuite : HUD rendu (comme avant)")
CHASED = false
step(0.1)
check(not hud.Enabled and hotbar.Enabled, "C2 poursuite finie : HUD recaché, barre gardée")
Motion.Close(displayed)
step(0.5)
check(not displayed.Enabled and hud.Enabled and hotbar.Enabled, "F1 UI_Displayed fermé : tout est rendu")
check(HudMask.IsActive("WindowHud") == false, "F2 masque WindowHud retiré")
step(0.3)
check(blurEffect() == nil, "F3 flou parti")

---------------------------------------------------------------- 4. Autre grande fenêtre seule : inchangé
Motion.Open(shop)
check(not hud.Enabled and not hotbar.Enabled, "O1 boutique seule : HUD et barre cachés (comme avant)")
Motion.Close(shop)
step(0.5)
check(hud.Enabled and hotbar.Enabled, "O2 fermée : tout est rendu")
step(1)
summary()
