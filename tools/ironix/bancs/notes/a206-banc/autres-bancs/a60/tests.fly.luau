---------------------------------------------------------------- scénario « fly » (a206, vague 63, L-202 point 4) : le « +$X/s » qui vole
-- Un objet qui arrive sur un présentoir (attribut InventoryState du joueur, champ Slot) fait voler son revenu du
-- présentoir (modèle tagué DisplayItem) jusqu'au Cash du HUD : copie de UI_HUD.CashFly.GainPop, sinon de CounterPop,
-- sinon un texte simple. Un vol par pose ; rien à la première lecture ; rien pendant une poursuite.
local Motion = requireModule(MOTION_MODULE, "client")
local PLAYED = {}
Motion.SetSoundPlayer(function(name)
	table.insert(PLAYED, name)
end)
local State = requireModule(ReplicatedStorage.Shared.InventoryState, "client")
local Spec = requireModule(ReplicatedStorage.Shared.Config.Displayed, "client").IncomeFly
local Chase = requireModule(CHASE_MODULE, "client")
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
local gainPop = new("TextLabel", { Name = "GainPop", Text = "+$0/s", Visible = false, Size = UDim2.fromOffset(120, 30) }, el(hud, "CashFly"))
new("UIStroke", { Thickness = 2 }, gainPop)

local items = {}
local function setState()
	local list = {}
	for _, it in items do
		table.insert(list, { Uid = it.uid, ItemId = "ITM_Test", Income = it.income, Slot = it.slot })
	end
	P1:SetAttribute(State.Attribute, State.Encode({ Items = list }))
end
local function put(uid, income, slot)
	table.insert(items, { uid = uid, income = income, slot = slot })
end
local function slotOf(uid, slot)
	for _, it in items do
		if it.uid == uid then
			it.slot = slot
		end
	end
end
local function model(uid, x)
	local m = new("Model", { Name = "Display_" .. uid })
	local p = new("Part", { Name = "Root", CFrame = CFrame.new(x, 0, 0) }, m)
	m.PrimaryPart = p
	m:SetAttribute("ItemUid", uid)
	m:SetAttribute("OwnerUserId", 101)
	m.Parent = Workspace
	addTag(m, "DisplayItem")
	return m
end
local function copies(name)
	return childrenNamed(hud, name)
end
local function soundCount(name)
	local n = 0
	for _, s in PLAYED do
		if s == name then
			n += 1
		end
	end
	return n
end
local TOTAL = Spec.PopTime + Spec.Hold + Spec.FlyTime

put("a", 5, 1) -- déjà exposé à l'arrivée
put("b", 12, nil) -- dans l'inventaire
setState()
local Hud = requireModule(HUD_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
step(0.1)

print("\n== F1. Première lecture : rien ne vole")
check(#copies("GainPop") == 0, "F1a l'objet déjà exposé ne vole pas")
setState()
P1:SetAttribute(State.Attribute, P1:GetAttribute(State.Attribute) .. "") -- même texte : pas de signal
step(0.1)
check(#copies("GainPop") == 0, "F1b état inchangé : rien")

print("\n== F2. Un objet posé : un « +$X/s » part du présentoir et vole jusqu'au Cash")
local sounds = soundCount("Cash_Collect")
model("b", 10)
slotOf("b", 2)
setState()
local scale0 = (function() local p = copies("GainPop")[1]; local s = p and scaleNamed(p, "GainScale"); return s and s.Scale end)()
step(0.02)
local list = copies("GainPop")
check(#list == 1, `F2a une copie de GainPop dans UI_HUD ({#list})`)
local pop = list[1]
check(pop and pop.Text == FormatC.income(12), `F2b texte « {pop and pop.Text} » = Format.income(12)`)
check(pop and pop.Visible == true and gainPop.Visible == false, "F2c la copie se montre, le modèle de Clément reste caché")
local scale = pop and scaleNamed(pop, "GainScale")
check(scale0 ~= nil and near(scale0, Spec.PopFrom, 1e-6) and scale ~= nil and scale.Scale > Spec.PopFrom, `F2d sursaut depuis PopFrom ({scale0} puis {scale and scale.Scale})`)
local start = pop and pop.Position
check(start and near(start.X.Offset, 640 + 20 * 10, 1) and near(start.Y.Offset, 396 - 20 * Spec.Lift, 1), `F2e départ au-dessus du présentoir ({start})`)
step(TOTAL * 0.5 + Spec.Hold)
check(#copies("GainPop") == 1, "F2f toujours en vol")
step(TOTAL)
check(#copies("GainPop") == 0, "F2g arrivé au Cash : copie détruite")
check(Gain.GetActive().IncomeFlies == 0, "F2h plus aucun vol en cours")
check(soundCount("Cash_Collect") == sounds + 1, "F2i Cash_Collect à l'arrivée")

print("\n== F3. L'état se répète (toutes les 0,5 s) : un seul vol par pose")
put("c", 3, nil)
setState()
step(0.1)
setState()
step(TOTAL + 0.2)
check(#copies("GainPop") == 0 and soundCount("Cash_Collect") == sounds + 1, "F3a rien de plus")

print("\n== F4. Deux poses d'un coup (Exposer les meilleurs) : deux vols, décalés")
put("d", 7, nil)
model("c", -5)
model("d", 0)
slotOf("c", 3)
slotOf("d", 4)
setState()
step(0.02)
check(#copies("GainPop") == 1, "F4a le premier part tout de suite")
step(Spec.Stagger + 0.02)
check(#copies("GainPop") == 2, "F4b le second après Stagger")
step(TOTAL + 0.3)
check(#copies("GainPop") == 0 and soundCount("Cash_Collect") == sounds + 3, "F4c les deux arrivent")

print("\n== F5. Retiré puis reposé : il revole ; pendant une poursuite : rien")
slotOf("b", nil)
setState()
step(0.1)
slotOf("b", 2)
setState()
step(0.02)
check(#copies("GainPop") == 1, "F5a reposé : un vol")
step(TOTAL + 0.2)
Chase.chased = true
slotOf("b", nil)
setState()
step(0.1)
slotOf("b", 2)
setState()
step(TOTAL + 0.2)
check(#copies("GainPop") == 0 and Gain.GetActive().IncomeFlies == 0, "F5b poursuivi : aucun vol")
Chase.chased = false

print("\n== F6. Sans GainPop : copie de CounterPop ; sans les deux : texte simple ; sans modèle : départ du joueur")
gainPop:Destroy()
put("e", 2, 5)
setState()
step(Spec.ModelWait + 0.15) -- sans modèle : attend ModelWait
local counter = copies("CounterPop")
check(#counter == 1 and counter[1].Text == FormatC.income(2), `F6a copie de CounterPop ({#counter})`)
step(TOTAL + 0.2)
check(#copies("CounterPop") == 0, "F6b arrivée")
el(hud, "CounterPop"):Destroy()
put("f", 4, 6)
setState()
step(Spec.ModelWait + 0.15)
local plain = copies("IncomeFly")
check(#plain == 1 and plain[1].Text == FormatC.income(4), `F6c texte simple « IncomeFly » ({#plain})`)
step(TOTAL + 0.2)
check(#copies("IncomeFly") == 0 and Gain.GetActive().IncomeFlies == 0, "F6d arrivée, rien en cours")

print("\n== F7. Sans UI_HUD : rien, sans erreur")
hud:Destroy()
put("g", 1, 7)
setState()
step(Spec.ModelWait + TOTAL + 0.2)
check(Gain.GetActive().IncomeFlies == 0, "F7a aucun vol en cours")

summary()
