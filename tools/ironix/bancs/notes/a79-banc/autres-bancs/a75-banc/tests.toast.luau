---------------------------------------------------------------- scénario « toast » (L-095 point 3) : UI_Toast
local T = UiMotionC.Toast
local Notify = requireModule(NOTIFY_MODULE, "client")
requireModule(MOTION_MODULE, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server") -- les remotes, pour que Start (Net côté client) ne bloque pas
taskLib.spawn(Notify.Start)
step(0.1)

print("\n== T0. Valeurs du tableau de Clément (Config/UiMotion.Toast)")
check(T.From == 0.6 and T.Time == 0.2 and T.Hold == 2.4 and T.FadeTime == 0.25 and T.MaxShown == 3, "T0a pop 0,6 → 1 en 0,2 ; 2,4 s ; effacement 0,25 ; 3 au plus")
check(sameColor(T.Colors.Success, GREEN) and sameColor(T.Other, Color3.new(1, 1, 1)), "T0b réussite en vert 5DFF3A, le reste en blanc")

local toastGui, stack, template = makeToast()
local notifyGui = makeNotify()
local templateSnap = snapshot(template)

print("\n== T1. Un message de réussite")
Notify.Show("Crown equipped!", "Success")
local shown = childrenStartingWith(stack, "Toast_")
local first = shown[1]
check(#shown == 1 and toastGui.Enabled == true, "T1a une copie de Stack.Template, UI_Toast allumé")
check(first and first.Visible == true and first.Text == "Crown equipped!" and first.Parent == stack, "T1b visible, texte du message, rangée à côté du Template")
check(first and sameColor(first.TextColor3, GREEN), "T1c texte vert (Success)")
local pop = first and scaleNamed(first, UiMotionC.PopScaleName)
check(pop ~= nil and near(pop.Scale, T.From, 1e-6), `T1d entre à {T.From} (UIScale {UiMotionC.PopScaleName})`)
step(T.Time + 1 / 30)
check(first and countClass(first, "UIScale") == 0, "T1e puis 1 : UIScale passager retiré")
check(notifyGui.Enabled == false and #childrenStartingWith(notifyGui.Stack, "Template_") == 0, "T1f UI_Notify pas utilisé")
local list = Notify.GetShown()
check(#list == 1 and list[1].Toast == true and list[1].Fallback == false and sameColor(list[1].Color, GREEN), "T1g GetShown : Toast, couleur verte")

print("\n== T2. Informations en blanc (Info, Warning, sans kind)")
Notify.Show("Too far from the window.", "Warning")
Notify.Show("Night is coming.")
shown = childrenStartingWith(stack, "Toast_")
check(#shown == 3, `T2a trois messages ({#shown})`)
check(shown[2] and sameColor(shown[2].TextColor3, Color3.new(1, 1, 1)) and shown[3] and sameColor(shown[3].TextColor3, Color3.new(1, 1, 1)), "T2b Warning et sans kind : blanc")
check(shown[1] == first and shown[2].LayoutOrder > shown[1].LayoutOrder and shown[3].LayoutOrder > shown[2].LayoutOrder, "T2c rangés par ordre d'arrivée (LayoutOrder)")

print("\n== T3. Un 4e message : le plus ancien part tout de suite (3 au plus)")
Notify.Show("Box secured!", "Success")
shown = childrenStartingWith(stack, "Toast_")
check(#shown == 3 and first.Parent == nil, `T3a toujours 3, le premier détruit ({#shown})`)
check(shown[3].Text == "Box secured!" and sameColor(shown[3].TextColor3, GREEN), "T3b le nouveau en bas, vert")

print("\n== T4. Le même message encore affiché : compté, pas répété")
Notify.Show("Night is coming.")
shown = childrenStartingWith(stack, "Toast_")
check(#shown == 3 and shown[2].Text == "Night is coming. ×2", `T4a « … ×2 » ({shown[2] and shown[2].Text})`)

print("\n== T5. Au bout de 2,4 s : effacement en 0,25 s, puis détruit")
for _, child in shown do
	child:Destroy()
end
step(0.1) -- les entrées dont la copie a disparu sont oubliées
Notify.Show("Item placed!", "Success")
local one = childrenStartingWith(stack, "Toast_")[1]
local stroke = one and one:FindFirstChildOfClass("UIStroke")
step(T.Hold - 0.1)
check(one and one.Parent == stack and one.TextTransparency == 0, "T5a encore là, opaque, juste avant 2,4 s")
step(0.1 + T.FadeTime / 2)
check(one and one.Parent == stack and one.TextTransparency > 0.2 and one.TextTransparency < 1, `T5b en train de s'effacer ({one and one.TextTransparency})`)
check(stroke and stroke.Transparency > 0.2, "T5c son contour aussi")
step(T.FadeTime / 2 + 0.1)
check(one and one.Parent == nil, "T5d détruit à la fin de l'effacement")
check(#Notify.GetShown() == 0, "T5e plus rien d'affiché")
local same, why = sameAs(templateSnap, template)
check(same, `T5f Stack.Template de Clément intact ({why})`)

print("\n== T6. Sans UI_Toast : repli sur UI_Notify (Template, Label)")
toastGui:Destroy()
Notify.Show("Shop upgraded", "Success")
local copies = childrenStartingWith(notifyGui.Stack, "Template_")
check(#copies == 1 and copies[1].Label.Text == "Shop upgraded" and notifyGui.Enabled == true, "T6a une copie du Template de UI_Notify")
list = Notify.GetShown()
check(#list == 1 and list[1].Toast == false and list[1].Fallback == false, "T6b GetShown : pas un Toast")

step(T.Hold + 1) -- la copie de UI_Notify part
-- (Le bandeau de secours NotifyV0 lui-même est couvert par le banc a42 : ce faux Roblox n'a pas
-- toutes ses classes, UIPadding, UITextSizeConstraint.)
print("\n== T8. UI_Toast revient : il reprend la main sur UI_Notify")
local back, backStack = makeToast()
step(0.1)
Notify.Show("Welcome back", "Success")
check(#childrenStartingWith(notifyGui.Stack, "Template_") == 0, "T8a rien de plus dans UI_Notify")
check(#childrenStartingWith(backStack, "Toast_") == 1 and back.Enabled == true, "T8b le message va dans UI_Toast")
summary()
