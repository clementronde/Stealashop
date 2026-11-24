---------------------------------------------------------------- banc a230 (vague 70, L-189 : BottomRow, nuit sur téléphone, BB_HeldIncome)
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 1)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
local Menu = requireModule(MENU_MODULE, "client")
local Hud = requireModule(HUD_MODULE, "client")
local Inv = requireModule(INV_MODULE, "client")
local Held = requireModule(HELD_MODULE, "client")
local UI = requireModule(ReplicatedStorage.Shared.Contract.UI, "client")
local BONUS = HudCfgC.BottomRow

local hud = makeV3Hud()
taskLib.spawn(Hud.Start)
taskLib.spawn(Menu.Start)
step(0.2)

print("\n== B0. Ancien HUD sans BottomRow : rien ne casse")
local count = 0
for _ in Menu.GetBonuses() do
	count += 1
end
check(count == 0, "B0a aucune pastille branchée")

print("\n== B1. BottomRow de Clément : FriendBoost « +0% » visible, les autres cachés")
local row = addBottomRow(hud, true)
step(0.2)
local function pill(name)
	return el(row, name)
end
local function amount(name)
	return el(pill(name), "Amount").Text
end
local timer = el(pill("CashBoost"), "Timer")
check(BONUS.FriendAtZero == true, "B1a Config : FriendBoost montré à 0 (Clément le laisse visible)")
check(pill("FriendBoost").Visible == true and amount("FriendBoost") == "+0%", `B1b FriendBoost visible, « +0% » ({amount("FriendBoost")})`)
for _, name in { "VipBoost", "CashBoost", "TrainingBoost" } do
	check(pill(name).Visible == false, `B1c {name} caché sans son bonus`)
end
check(timer.Visible == false, "B1d Timer caché sans boost")

print("\n== B2. Bonus d'amis (attribut FriendBonus de HubService)")
P1:SetAttribute("FriendBonus", 0.3)
step(0.2)
check(amount("FriendBoost") == "+30%" and pill("FriendBoost").Visible, `B2a « +30% » ({amount("FriendBoost")})`)
P1:SetAttribute("FriendBonus", 0.6000000001)
step(0.2)
check(amount("FriendBoost") == "+60%", `B2b arrondi « +60% » ({amount("FriendBoost")})`)
P1:SetAttribute("FriendBonus", nil)
step(0.2)
check(amount("FriendBoost") == "+0%", "B2c attribut retiré : « +0% »")

print("\n== B3. VIP (PassVIP)")
P1:SetAttribute("PassVIP", true)
step(0.2)
check(pill("VipBoost").Visible and amount("VipBoost") == "+10%", `B3a montré, « +10% » ({amount("VipBoost")})`)
P1:SetAttribute("PassVIP", nil)
step(0.2)
check(pill("VipBoost").Visible == false, "B3b pass retiré : caché")

print("\n== B4. x2 Cash (PassDoubleCash) et boost x2 argent (CashBoostEndsAt)")
P1:SetAttribute("PassDoubleCash", true)
step(0.2)
check(pill("CashBoost").Visible and amount("CashBoost") == "x2" and timer.Visible == false, `B4a pass : « x2 », sans minuteur ({amount("CashBoost")})`)
P1:SetAttribute("CashBoostEndsAt", Workspace:GetServerTimeNow() + 90)
step(0.2)
check(amount("CashBoost") == "x4" and timer.Visible and timer.Text == "1:30", `B4b pass + boost : « x4 », « 1:30 » ({amount("CashBoost")}, {timer.Text})`)
step(31)
check(timer.Text == "0:59", `B4c le minuteur descend (« 0:59 » : {timer.Text})`)
step(60)
check(amount("CashBoost") == "x2" and timer.Visible == false, `B4d boost fini : « x2 », minuteur caché ({amount("CashBoost")})`)
P1:SetAttribute("PassDoubleCash", nil)
P1:SetAttribute("CashBoostEndsAt", Workspace:GetServerTimeNow() + 3600)
step(0.2)
check(pill("CashBoost").Visible and amount("CashBoost") == "x2" and timer.Text == "1:00:00", `B4e boost seul d'une heure : « x2 », « 1:00:00 » ({timer.Text})`)
P1:SetAttribute("CashBoostEndsAt", nil)
step(0.2)
check(pill("CashBoost").Visible == false and timer.Visible == false, "B4f plus rien : caché")

print("\n== B5. x2 Training (PassDoubleTraining)")
P1:SetAttribute("PassDoubleTraining", true)
step(0.2)
check(pill("TrainingBoost").Visible and amount("TrainingBoost") == "x2", `B5a montré, « x2 » ({amount("TrainingBoost")})`)
P1:SetAttribute("PassDoubleTraining", nil)
step(0.2)
check(pill("TrainingBoost").Visible == false, "B5b pass retiré : caché")

print("\n== B6. Visible écrit seulement au changement (masque de poursuite qui cache une pastille)")
pill("FriendBoost").Visible = false
step(0.5)
check(pill("FriendBoost").Visible == false, "B6a pastille cachée par un autre code : pas rallumée tant que rien ne change")
local got = Menu.GetBonuses()
check(got.FriendBoost and got.FriendBoost.Amount == "+0%" and got.CashBoost and got.CashBoost.Shown == false, "B6b GetBonuses")
hud:Destroy()

print("\n== N. NightCountdown sur téléphone (PhonePosition, PhoneAnchorPoint)")
local PC_POS = UDim2.new(1, -72, 1, -20)
local PC_ANCHOR = Vector2.new(1, 1)
local PHONE_POS = UDim2.fromScale(0.5, 0.985)
local PHONE_ANCHOR = Vector2.new(0.5, 1)
local function nightHud(attrs)
	local h = makeHud()
	h.Parent = nil
	local night = new("TextLabel", { Name = "NightCountdown", Text = "Night in", Position = PC_POS, AnchorPoint = PC_ANCHOR }, h)
	if attrs == "good" then
		night:SetAttribute("PhonePosition", PHONE_POS)
		night:SetAttribute("PhoneAnchorPoint", PHONE_ANCHOR)
	elseif attrs == "bad" then
		night:SetAttribute("PhonePosition", "0.5, 0.985")
		night:SetAttribute("PhoneAnchorPoint", 1)
	end
	h.Parent = PLAYER_GUI
	step(0.1)
	return h, night
end
INPUTS.TouchEnabled, INPUTS.KeyboardEnabled = false, true
local h1, n1 = nightHud("good")
check(n1.Position == PC_POS and n1.AnchorPoint == PC_ANCHOR, "N1 PC : la place de Clément")
h1:Destroy()
INPUTS.TouchEnabled, INPUTS.KeyboardEnabled = true, true
local h2, n2 = nightHud("good")
check(n2.Position == PC_POS, "N2 tactile avec clavier (tablette, PC tactile) : la place de Clément")
h2:Destroy()
INPUTS.TouchEnabled, INPUTS.KeyboardEnabled = true, false
local h3, n3 = nightHud("good")
check(n3.Position == PHONE_POS and n3.AnchorPoint == PHONE_ANCHOR, "N3 téléphone : PhonePosition et PhoneAnchorPoint")
h3:Destroy()
local h4, n4 = nightHud(nil)
check(n4.Position == PC_POS and n4.AnchorPoint == PC_ANCHOR, "N4 téléphone sans attributs : la place de Clément")
h4:Destroy()
local h5, n5 = nightHud("bad")
check(n5.Position == PC_POS and n5.AnchorPoint == PC_ANCHOR, "N5 attributs d'un autre type : ignorés")
h5:Destroy()
INPUTS.TouchEnabled, INPUTS.KeyboardEnabled = false, true

print("\n== H. BB_HeldIncome au-dessus de l'objet tenu en main")
Inv.state = { Items = { { Uid = "u1", Income = 1234 }, { Uid = "u2", Income = 50 } } }
taskLib.spawn(Held.Start)
step(0.1)
local character = P1.Character
local function makeTool(uid, parts)
	local tool = new("Tool", { Name = "Gold Watch" })
	if uid then
		tool:SetAttribute("HeldItemUid", uid)
	end
	local handle = new("Part", { Name = "Handle", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 5, 0) }, tool)
	local model = new("Model", { Name = "HeldItem" }, tool)
	for _, spec in parts do
		new("Part", { Name = spec.name or "Body", Size = spec.size, CFrame = spec.cf }, model)
	end
	return tool, handle, model
end
local tool, handle = makeTool("u1", {
	{ size = Vector3.new(2, 3, 2), cf = CFrame.new(0, 5, 0) },
	{ name = "RarityHalo", size = Vector3.new(8, 8, 8), cf = CFrame.new(0, 5, 0) },
})
tool.Parent = character
step(0.1)
local gui = tool:FindFirstChild(HudCfgC.HeldIncome.Name)
check(gui ~= nil and gui.ClassName == "BillboardGui", "H1a repli (BB_HeldIncome absent) : billboard dans le Tool")
check(gui and gui.Adornee == handle, "H1b Adornee = la poignée")
check(gui and math.abs(gui.StudsOffsetWorldSpace.Y - 1.5) < 1e-6, `H1c haut de l'objet : 1,5 stud au-dessus de la poignée, halo exclu ({gui and gui.StudsOffsetWorldSpace.Y})`)
check(gui and gui.StudsOffset.Y == 0.6, "H1d repli : StudsOffset 0,6 (comme le billboard de Clément)")
local label = gui and el(gui, "Income")
check(label and label.Text == "$1.2K/s" and gui.Enabled, `H1e « $1.2K/s » ({label and label.Text})`)
check(logHas("BB_HeldIncome absent"), "H1f une ligne dans la sortie pour le repli")
local state = Held.GetState()
check(state.Shown and state.Uid == "u1" and state.Text == "$1.2K/s", "H1g GetState")

Inv.state = { Items = { { Uid = "u1", Income = 5e6 } } }
Inv.Fire()
check(label.Text == "$5M/s", `H2a inventaire changé : « $5M/s » ({label.Text})`)
Inv.state = { Items = {} }
Inv.Fire()
check(gui.Enabled == false, "H2b objet absent de l'inventaire : billboard éteint")
Inv.state = { Items = { { Uid = "u1", Income = 5e6 }, { Uid = "u2", Income = 50 } } }
Inv.Fire()
check(gui.Enabled == true, "H2c revenu retrouvé : rallumé")

tool.Parent = nil
step(0.1)
check(tool:FindFirstChild(HudCfgC.HeldIncome.Name) == nil and Held.GetState().Shown == false, "H3 objet rangé : billboard retiré")

-- Billboard de Clément : StudsOffset 0,6, texte Income.
local template = new("BillboardGui", { Name = "BB_HeldIncome", StudsOffset = Vector3.new(0, 0.6, 0), MaxDistance = 80 }, ReplicatedStorage.Assets.UI)
new("TextLabel", { Name = "Income", Text = "$1.2K/s" }, template)
local tool2, _, model2 = makeTool("u2", {
	{ size = Vector3.new(4, 2, 1), cf = CFrame.new(0, 5.5, 0) * CFrame.Angles(0, math.pi / 2, 0) },
})
tool2.Parent = character
step(0.1)
local gui2 = tool2:FindFirstChild(HudCfgC.HeldIncome.Name)
check(gui2 and gui2.MaxDistance == 80 and gui2.StudsOffset.Y == 0.6, "H4a copie du billboard de Clément (ses réglages gardés)")
check(gui2 and math.abs(gui2.StudsOffsetWorldSpace.Y - 1.5) < 1e-6, `H4b objet tourné, décalé : haut à 1,5 ({gui2 and gui2.StudsOffsetWorldSpace.Y})`)
check(gui2 and el(gui2, "Income").Text == "$50/s", `H4c « $50/s » ({gui2 and el(gui2, "Income").Text})`)
new("Part", { Name = "Top", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 8, 0) }, model2)
step(0.1)
check(gui2 and math.abs(gui2.StudsOffsetWorldSpace.Y - 3.5) < 1e-6, `H4d pièce arrivée après : hauteur recalculée (3,5 : {gui2 and gui2.StudsOffsetWorldSpace.Y})`)

local other = new("Tool", { Name = "Hammer" })
new("Part", { Name = "Handle" }, other)
other.Parent = character
step(0.1)
check(other:FindFirstChild(HudCfgC.HeldIncome.Name) == nil and Held.GetState().Uid == "u2", "H5 un outil (sans HeldItemUid) : rien")

local fresh = new("Model", { Name = "Alice" })
fresh.Parent = Workspace
P1.Character = fresh
P1.CharacterAdded:Fire(fresh)
step(0.1)
check(tool2:FindFirstChild(HudCfgC.HeldIncome.Name) == nil and Held.GetState().Shown == false, "H6 nouveau personnage : l'ancien billboard retiré")
local tool3 = makeTool("u1", { { size = Vector3.new(1, 1, 1), cf = CFrame.new(0, 5, 0) } })
tool3.Parent = fresh
step(0.1)
check(tool3:FindFirstChild(HudCfgC.HeldIncome.Name) ~= nil, "H6b objet en main sur le nouveau personnage : billboard")

print("\n== C. Contract/UI")
check(table.find(UI.Twins.UI_HUD.Names, "InventoryButton") == nil, "C1 InventoryButton sorti des doublons (UI.Twins)")
check(#UI.Twins.UI_HUD.Names == 4, "C1b les 4 autres doublons gardés")
local found = {}
for _, s in UI.Screens do
	if s.Name == "UI_HUD" then
		for _, e in s.Elements do
			found[e.Path] = { e = e, s = s }
		end
	end
end
for _, path in { "FriendBoost", "FriendBoost.Amount", "VipBoost", "VipBoost.Amount", "CashBoost", "CashBoost.Amount", "CashBoost.Timer", "TrainingBoost", "TrainingBoost.Amount" } do
	local f = found[path]
	check(f ~= nil and f.e.Optional == true and f.s.Optional == true, `C2 {path} facultatif`)
end
local bb = nil
for _, b in UI.Billboards do
	if b.Name == "BB_HeldIncome" then
		bb = b
	end
end
check(bb and bb.Optional == true and bb.Elements[1].Path == "Income", "C3 BB_HeldIncome facultatif, Income")

check(not logHas("ERREUR"), "Z aucune erreur")
summary()
