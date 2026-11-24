---------------------------------------------------------------- a238 (vague 71, L-213 point 8) : PurchaseGlow sur téléphone
-- Après setup.luau du banc a50 (P1 et son PlayerGui), faux Roblox d'a209 (FAKE_UIS, FAKE_MARKET, UIStroke.Transparency).
local playerGui = P1.PlayerGui
local ctrl = folder(StarterPlayerScripts.Client, "Controllers238")
local ui = folder(ctrl, "UI")
moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
local glowModule = moduleScript(ui, "PurchaseGlow", "client/Controllers/UI/PurchaseGlow.luau")
local PurchaseGlow = requireModule(glowModule, "client")
step(0.1)

local glowGui = new("ScreenGui", { Name = "UI_PurchaseGlow", Enabled = false }, playerGui)
local border = new("Frame", { Name = "RainbowBorder", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, glowGui)
local stroke = new("UIStroke", { Thickness = 8, Transparency = 0 }, border)
new("UIGradient", { Rotation = 0 }, stroke)
border:SetAttribute("PhoneThickness", 5)
step(0.05)

local function finish()
	FAKE_MARKET.PromptProductPurchaseFinished:Fire(P1.UserId, 1, true)
	step(0.3)
end

-- PC : Thickness de Clément.
PurchaseGlow.Show()
check(stroke.Thickness == 8, `P1 PC : contour de 8 px gardé ({stroke.Thickness})`)
finish()
check(PurchaseGlow.GetState() == "Idle" and stroke.Thickness == 8, "P2 PC : effacée, 8 px")

-- Téléphone : PhoneThickness de RainbowBorder, remis à la fin ; Transparency du UIStroke effacée avec le reste.
FAKE_UIS.TouchEnabled = true
FAKE_UIS.KeyboardEnabled = false
PurchaseGlow.Show()
check(stroke.Thickness == 5, `P3 téléphone : contour de 5 px ({stroke.Thickness})`)
FAKE_MARKET.PromptProductPurchaseFinished:Fire(P1.UserId, 1, true)
step(0.05)
check(stroke.Transparency > 0.2 and stroke.Transparency < 0.8 and stroke.Thickness == 5, `P4 téléphone, à mi-effacement : UIStroke.Transparency qui monte ({stroke.Transparency}), toujours 5 px`)
step(0.3)
check(PurchaseGlow.GetState() == "Idle" and stroke.Thickness == 8 and stroke.Transparency == 0, `P5 téléphone, effacée : 8 px et transparence de Clément remis ({stroke.Thickness}, {stroke.Transparency})`)

-- Attribut sur le UIStroke : il passe avant celui de RainbowBorder.
stroke:SetAttribute("PhoneThickness", 4)
PurchaseGlow.Show()
check(stroke.Thickness == 4, `P6 attribut sur le UIStroke : 4 px ({stroke.Thickness})`)
finish()
stroke:SetAttribute("PhoneThickness", nil)
border:SetAttribute("PhoneThickness", nil)

-- Sans attribut : rien ne change sur téléphone.
PurchaseGlow.Show()
check(stroke.Thickness == 8, `P7 téléphone sans PhoneThickness : 8 px ({stroke.Thickness})`)
finish()
check(stroke.Thickness == 8, "P8 remis : 8 px")
FAKE_UIS.TouchEnabled = false
FAKE_UIS.KeyboardEnabled = true

summary()
