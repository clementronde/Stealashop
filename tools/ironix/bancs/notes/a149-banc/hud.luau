--!nocheck
-- Banc a149 (vague 42), scénario HUD, après la mise en place du banc a21-hud (copie a126, lignes 8 à 113, avec le
-- bouchon HeistController pilotable ci-dessous et un HeistTimer coloré par « Clément ») :
--   L-157 point 1 : Strength = arme × aura (attribut Damage) ; Damage = × potion de force (×1,5) tant qu'elle dure ;
--   L-153 / L-157 point 4 : « POLICE IN 8s » en rouge, puis la couleur de Clément revient pour « HEIST ».
local Potions = requireModule(ReplicatedStorage.Shared.Config.Potions, "server")
local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "server")
local FormatM = requireModule(ReplicatedStorage.Shared.Format, "server")
local function sameColor(a, b)
	return a ~= nil and b ~= nil and a.R == b.R and a.G == b.G and a.B == b.B
end

print("\n== A1. Strength sans potion, Damage avec")
P1:SetAttribute("Damage", 1000)
step(0.05)
check(T("Strength") == FormatM.short(1000) and T("Damage") == FormatM.short(1000), `sans potion : Strength {T("Strength")}, Damage {T("Damage")}`)
P1:SetAttribute("Potion_Strength", serverNow() + 5)
step(0.05)
check(T("Strength") == FormatM.short(1000), `potion : Strength inchangé ({T("Strength")})`)
check(T("Damage") == FormatM.short(1000 * Potions.ById.Strength.Multiplier), `potion : Damage ×1,5 ({T("Damage")})`)
P1:SetAttribute("Damage", 2000)
step(0.05)
check(T("Damage") == FormatM.short(3000) and T("Strength") == FormatM.short(2000), "nouvelle arme pendant la potion : 2K / 3K")
step(5.2)
check(T("Damage") == FormatM.short(2000), `potion finie sans nouvel attribut : Damage revient ({T("Damage")})`)
P1:SetAttribute("Potion_Strength", nil)
step(0.05)
check(T("Damage") == FormatM.short(2000), "attribut retiré : Damage inchangé")

print("\n== A2. Chrono de police en rouge")
local timer = el(hud, "HeistTimer")
local clement = CLEMENT_TIMER_COLOR
local HEIST = requireModule(controllers:FindFirstChild("HeistController"), "client")
HEIST._fire("S1", serverNow() + 8, true)
step(0.1)
check(timer.Visible and timer.Text == "POLICE IN 8s", `police : « {timer.Text} »`)
check(sameColor(timer.TextColor3, UiMotion.TimerTick.PoliceColor), "police : texte rouge (PoliceColor)")
step(5.5)
check(timer.Text == "POLICE IN 3s" or timer.Text == "POLICE IN 2s", `police à 2-3 s : « {timer.Text} »`)
check(sameColor(timer.TextColor3, UiMotion.TimerTick.PoliceColor), "police : toujours rouge")
HEIST._fire("S1", serverNow() + 6, false)
step(0.1)
check(timer.Text == "HEIST: 6s", `casse : « {timer.Text} »`)
check(timer.TextColor3 == clement, "HEIST: 6s : la couleur de Clément revient")
step(3.5)
check(sameColor(timer.TextColor3, UiMotion.TimerTick.RedColor), "HEIST à 3 s ou moins : rouge comme avant (L-092 3c)")
HEIST._fire("S1", 0, false)
step(0.1)
check(not timer.Visible and timer.TextColor3 == clement, "chrono fini : caché, couleur de Clément")
summary()
