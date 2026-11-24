---------------------------------------------------------------- scénarios a258 (vague 74, L-259 : fenêtres de la vidéo E, voile et flou)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Tweens simulés (TIMED_TWEENS d'ext-a189).
PROPS.ScreenGui.DisplayOrder = PROPS.ScreenGui.DisplayOrder or 0 -- a258 : faux Roblox, DisplayOrder des écrans
-- Modules montés à part (Controllers258) : Motion, Appear, HudMask, UiMotionController.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers258")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local hudMaskModule = moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseController258"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController258")
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

local function screen(name, enabled, order, attrs)
	local gui = new("ScreenGui", { Name = name, Enabled = enabled, DisplayOrder = order })
	for k, v in attrs or {} do
		gui:SetAttribute(k, v)
	end
	gui.Parent = playerGui
	return gui
end
local function blurEffect()
	local inLighting = LightingService:FindFirstChild("UiBlur")
	if inLighting then
		return inLighting
	end
	local ok, camera = pcall(function()
		return Workspace.CurrentCamera
	end)
	return if ok and camera then camera:FindFirstChild("UiBlur") else nil
end
local function scaleOf(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	return if s then s.Scale else 1
end

---------------------------------------------------------------- 0. Valeurs
print("-- Valeurs")
check(UiMotion.WindowE == true, "V1 interrupteur WindowE allumé")
local o, c = UiMotion.Open, UiMotion.Close
check(o.From == 0.5 and o.Peak == 1.055 and o.PeakTime == 0.17 and o.PeakStyle == Enum.EasingStyle.Quad and o.PeakDirection == Enum.EasingDirection.Out and o.Time == 0.16 and o.Style == Enum.EasingStyle.Quad and o.Direction == Enum.EasingDirection.InOut, "V2 ouverture 0,5 → 1,055 (0,17 Quad Out) → 1 (0,16 Quad InOut)")
check(c.Peak == 1.04 and c.PeakTime == 0.06 and c.PeakDirection == Enum.EasingDirection.Out and c.To == 0.5 and c.Time == 0.1 and c.Style == Enum.EasingStyle.Quad and c.Direction == Enum.EasingDirection.In, "V3 fermeture 1 → 1,04 (0,06 Quad Out) → 0,5 (0,1 Quad In)")
local b = UiMotion.Blur
check(b.Size == 10 and b.InTime == 0.2 and b.OutTime == 0.13 and b.OutDelay == 0 and b.Direction == Enum.EasingDirection.Out and b.UnderCamera == true, "V4 flou 10, entrée 0,2, sortie 0,13 sans délai, sous la caméra")
check(table.find(b.Screens, "UI_Displayed") == nil and table.find(b.Screens, "UI_Offline") ~= nil and table.find(b.Screens, "UI_RobuxShop_v2") ~= nil, "V5 fenêtres centrales : pas UI_Displayed, UI_Offline oui")
local v = UiMotion.Veil
check(v.Enabled and v.Screen == "UI_Veil" and v.Frame == "Veil" and v.Offset == -1 and v.InTime == 0.2 and v.OutTime == 0.13 and v.CloseOnClick == true, "V6 voile : UI_Veil.Veil, fenêtre − 1, 0,2 s / 0,13 s, clic qui ferme")

---------------------------------------------------------------- 1. Sans UI_Veil : flou seul
print("-- Repli")
local shop = screen("UI_WeaponShop", false, 7, { ScreenGroup = "Menu" })
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, shop)
local aura = screen("UI_AuraShop", false, 5, { ScreenGroup = "Menu" })
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, aura)
step(0.05)
Motion.Open(shop)
step(0.3)
check(blurEffect() ~= nil and near(blurEffect().Size, 10), "R1 sans UI_Veil : flou à 10, pas d'erreur")
Motion.Close(shop)
step(0.6)
check(not shop.Enabled and blurEffect() == nil, "R2 fermé : flou parti")

---------------------------------------------------------------- 2. Ouverture en deux temps, voile
print("-- Ouverture et voile")
local veilGui = screen("UI_Veil", false, 2)
local veilFrame = new("Frame", { Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.62, Active = true }, veilGui)
step(0.05)
Motion.Open(shop)
check(near(scaleOf(root), 0.5), "O1 départ à 0,5")
check(veilGui.Enabled and veilGui.DisplayOrder == 6 and near(veilFrame.BackgroundTransparency, 1), "O2 voile allumé à l'image même, DisplayOrder 7 − 1, transparent")
step(0.17)
check(scaleOf(root) > 1.03, "O3 à 0,17 s : la fenêtre dépasse (≈ 1,055) : " .. tostring(scaleOf(root)))
step(0.1)
check(near(veilFrame.BackgroundTransparency, 0.62), "O4 voile à 0,62 après 0,2 s")
step(0.2)
check(root:FindFirstChildOfClass("UIScale") == nil and Motion.GetState(shop) == "Open", "O5 à 0,47 s : ouverte, UIScale retiré")
check(blurEffect() ~= nil and near(blurEffect().Size, 10), "O6 flou à 10")

---------------------------------------------------------------- 3. Une fenêtre en remplace une autre
print("-- Remplacement")
Motion.Open(aura) -- ferme shop (même groupe)
step(0.02)
check(veilGui.Enabled and veilGui.DisplayOrder == 4 and veilFrame.BackgroundTransparency < 0.7, "W1 voile gardé, sous la nouvelle fenêtre (5 − 1)")
step(0.5)
check(veilGui.Enabled and near(veilFrame.BackgroundTransparency, 0.62) and not shop.Enabled, "W2 toujours là, l'ancienne fenêtre éteinte")

---------------------------------------------------------------- 4. Fermeture en deux temps
print("-- Fermeture")
local auraRoot = aura:FindFirstChild("Root")
Motion.Close(aura)
step(0.05)
check(scaleOf(auraRoot) > 1.01, "C1 à 0,05 s : la fenêtre gonfle (vers 1,04)")
step(0.08)
check(scaleOf(auraRoot) < 1, "C2 à 0,13 s : elle rapetisse vers 0,5")
step(0.5)
check(not aura.Enabled and not veilGui.Enabled, "C3 fenêtre et voile éteints")
check(near(veilFrame.BackgroundTransparency, 0.62) and veilGui.DisplayOrder == 2, "C4 valeurs de Clément remises (0,62, DisplayOrder 2)")
check(blurEffect() == nil, "C5 flou retiré")

---------------------------------------------------------------- 5. Panneau de côté et poursuite
print("-- Sans voile")
local displayed = screen("UI_Displayed", false, 5)
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, displayed)
step(0.05)
Motion.Open(displayed)
step(0.3)
check(not veilGui.Enabled and blurEffect() == nil, "S1 UI_Displayed : ni voile ni flou")
Motion.Close(displayed)
step(0.5)
CHASED = true
Motion.Open(shop)
step(0.3)
check(shop.Enabled and not veilGui.Enabled, "S2 poursuite : pas de voile")
CHASED = false
step(0.3)
check(veilGui.Enabled and near(veilFrame.BackgroundTransparency, 0.62), "S3 poursuite finie : voile revenu")

---------------------------------------------------------------- 6. Clic sur le voile
print("-- Clic")
local closed = 0
Motion.SetCloser(shop, function()
	closed += 1
	Motion.Close(shop)
end)
veilFrame.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseMovement })
step(0.05)
check(closed == 0 and Motion.GetState(shop) == "Open", "K1 souris qui passe : rien")
veilFrame.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
check(closed == 1 and Motion.GetState(shop) == "Closing", "K2 clic : la fenêtre se ferme par son contrôleur")
step(0.6)
check(not shop.Enabled and not veilGui.Enabled, "K3 tout est éteint")
Motion.SetCloser(shop, nil)
step(1)
summary()
