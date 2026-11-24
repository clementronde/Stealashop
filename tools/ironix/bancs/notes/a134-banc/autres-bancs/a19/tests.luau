---------------------------------------------------------------- scénarios (avec CosmeticService)
local playerGui = P1.PlayerGui

local function el(root, name)
	return root:FindFirstChild(name, true)
end

-- Copie grise de UI_WeaponShop au contrat 2.2 (cadres décoratifs autour, UIListLayout).
local function makeWeaponScreen(options)
	options = options or {}
	local screen = new("ScreenGui", { Name = "UI_WeaponShop", Enabled = true })
	local window = new("Frame", { Name = "Window" }, screen)
	new("TextButton", { Name = "CloseButton", Text = "X" }, window)
	local list = new("ScrollingFrame", { Name = "List" }, window)
	new("UIListLayout", { Name = "UIListLayout" }, list)
	if not options.noTemplate then
		local template = new("Frame", { Name = "Template", Visible = false }, list)
		new("ImageLabel", { Name = "Icon" }, template)
		new("TextLabel", { Name = "ItemName", Text = "Tool" }, template)
		new("TextLabel", { Name = "Power", Text = "Power" }, template)
		new("TextLabel", { Name = "Price", Text = "$0" }, template)
		new("TextButton", { Name = "BuyButton", Text = "Buy" }, template)
		new("TextButton", { Name = "EquipButton", Text = "Equip" }, template)
	end
	screen.Parent = playerGui
	return screen, list
end

local function rows(list)
	local out = {}
	for _, child in list:GetChildren() do
		if string.match(child.Name, "^Tool_") then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

local function row(list, toolId)
	for _, child in list:GetChildren() do
		if string.match(child.Name, "_" .. toolId .. "$") then
			return child
		end
	end
	return nil
end

local function promptsIn(root, name)
	local out = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Name == name then
			table.insert(out, d)
		end
	end
	return out
end

local function upgradePrompt(root)
	return promptsIn(root, "UpgradePrompt")[1]
end

print("\n== A. Démarrage")
check(P1:GetAttribute("OwnedTools") == "Fists" and P1:GetAttribute("EquippedTool") == "Fists", "A1 OwnedTools = Fists, EquippedTool = Fists au chargement du profil")
local levelsOk = true
for _, upgrade in Upgrades.List do
	if P1:GetAttribute(upgrade.Id .. "Level") ~= 0 or P2:GetAttribute(upgrade.Id .. "Level") ~= 0 then
		levelsOk = false
	end
end
check(levelsOk, "A2 TreadmillLevel, BenchLevel, DisplaySlotsLevel, UnboxBenchesLevel = 0 (2 joueurs)")
check(logCount("[ShopService]", "WARN") == 0, "A3 aucun avertissement de ShopService au démarrage (CosmeticService présent)")
check(heldToolId(P1) == "Fists", "A4 ToolService a donné les poings (Backpack)")

print("\n== G. WeaponShopController (écran UI_WeaponShop)")
local shopPrompts = promptsIn(WEAPON_SHOP, "WeaponShopPrompt")
local prompt = shopPrompts[1]
check(#shopPrompts == 1 and prompt.Parent == WEAPON_COUNTER, "G1 une invite sur la pièce principale du comptoir WeaponShop")
check(prompt.ActionText == "Shop" and prompt.ObjectText == "Weapon Shop" and prompt.MaxActivationDistance == 10 and prompt.RequiresLineOfSight == false, "G2 invite « Shop » / « Weapon Shop », 10 studs, sans ligne de vue")
check(prompt.Enabled == false, "G3 invite cachée tant que l'écran manque")
check(#promptsIn(INBOX, "WeaponShopPrompt") == 0 and #promptsIn(AURA_SHOP, "WeaponShopPrompt") == 0, "G4 pas d'invite au comptoir de _INBOX_CLEMENT ni à la boutique d'auras")
check(logCount("pas encore livré", nil, "client") == 0, "G5 rien dans la sortie avant le délai de copie de StarterGui")
step(10.5)
check(logCount("[WeaponShop] écran UI_WeaponShop pas encore livré (UI-002)", "PRINT", "client") == 1, "G6 une ligne dans la sortie quand l'écran manque")
step(20)
check(logCount("pas encore livré", nil, "client") == 1 and logCount("[WeaponShop]", "WARN", "client") == 0, "G7 toujours une seule ligne, aucun avertissement")
prompt.Triggered:Fire(P1)
step(0.05)
check(FAILS == 0, "G8 déclencher l'invite sans écran : pas d'erreur")

local screen, list = makeWeaponScreen()
step(0.05)
local template = el(screen, "Template")
check(logCount("[WeaponShop] UI_WeaponShop branché : 7 outil(s)", "PRINT", "client") == 1, "G9 écran branché : 7 outils")
check(screen.Enabled == false and prompt.Enabled == true, "G10 écran fermé au branchement, invite visible")
local r = rows(list)
local namesOk, orderOk, visibleOk, parentOk = #r == 7, true, true, true
for i, tool in Tools.List do
	local rr = r[i]
	if rr == nil or rr.Name ~= string.format("Tool_%02d_%s", tool.Order, tool.Id) then
		namesOk = false
	end
	if rr and rr.LayoutOrder ~= tool.Order then
		orderOk = false
	end
	if rr and rr.Visible ~= true then
		visibleOk = false
	end
	if rr and rr.Parent ~= template.Parent then
		parentOk = false
	end
end
check(namesOk and orderOk, "G11 7 lignes Tool_01_Fists à Tool_07_AngleGrinder, LayoutOrder = rang")
check(visibleOk and parentOk, "G12 lignes visibles, rangées à côté du Template")
check(template.Visible == false and el(template, "ItemName").Text == "Tool" and el(template, "Price").Text == "$0", "G13 Template invisible et intact")
local expectedPrice = { Fists = "Free", Wrench = "$300", Crowbar = "$40K", Hammer = "$1M", Sledgehammer = "$20M", FireAxe = "$250M", AngleGrinder = "$5B" } -- a134 : armes v2
local expectedPower = { Fists = "Power: 1", Wrench = "Power: 5", Crowbar = "Power: 40", Hammer = "Power: 300", Sledgehammer = "Power: 2.5K", FireAxe = "Power: 20K", AngleGrinder = "Power: 100K" }
local textsOk = true
for _, tool in Tools.List do
	local rr = row(list, tool.Id)
	if el(rr, "ItemName").Text ~= tool.DisplayName or el(rr, "Price").Text ~= expectedPrice[tool.Id] or el(rr, "Power").Text ~= expectedPower[tool.Id] then
		textsOk = false
		print(`    {tool.Id} : {el(rr, "ItemName").Text} | {el(rr, "Power").Text} | {el(rr, "Price").Text}`)
	end
end
check(textsOk, "G14 ItemName, Power (« Power: 20 ») et Price (Format.money, « Free ») de chaque outil")
check(el(row(list, "Fists"), "BuyButton").Visible == false and el(row(list, "Fists"), "EquipButton").Visible == true, "G15 poings possédés : BuyButton caché, EquipButton visible")
check(el(row(list, "Fists"), "EquipButton").Text == "Equipped", "G16 l'outil équipé affiche « Equipped »")
local othersOk = true
for _, tool in Tools.List do
	if tool.Id ~= "Fists" then
		local rr = row(list, tool.Id)
		if el(rr, "BuyButton").Visible ~= true or el(rr, "EquipButton").Visible ~= false then
			othersOk = false
		end
	end
end
check(othersOk, "G17 outils pas possédés : BuyButton visible, EquipButton caché")

prompt.Triggered:Fire(P1)
step(0.05)
check(screen.Enabled == true, "G18 l'invite ouvre l'écran")
local m = mark()
local buys = FIRE_SERVER.BuyItem or 0
el(row(list, "Wrench"), "BuyButton").Activated:Fire()
step(0.05)
local n = onlyNotify(P1, m)
check((FIRE_SERVER.BuyItem or 0) == buys + 1 and n and n.text == "Not enough cash: $300 needed." and n.kind == "Warning", "G19 Buy sans argent : BuyItem envoyé, Notify « Not enough cash: $300 needed. »")
check(el(row(list, "Wrench"), "BuyButton").Visible == true and not owned(P1, "Wrench"), "G20 ligne inchangée après un refus")
step(1.1)
setCash(P1, 10000)
m = mark()
el(row(list, "Wrench"), "BuyButton").Activated:Fire()
step(0.05)
n = onlyNotify(P1, m)
check(owned(P1, "Wrench") and cash(P1) == 9700 and n and n.text == "Wrench bought and equipped!" and n.kind == "Info", "G21 Buy Wrench : 300 $ débités, Notify « Wrench bought and equipped! »")
check(el(row(list, "Wrench"), "BuyButton").Visible == false and el(row(list, "Wrench"), "EquipButton").Visible == true and el(row(list, "Wrench"), "EquipButton").Text == "Equipped", "G22 la ligne suit l'achat : Equip visible, « Equipped »")
check(el(row(list, "Fists"), "EquipButton").Text == "Equip" and P1:GetAttribute("EquippedTool") == "Wrench" and heldToolId(P1) == "Wrench", "G23 les poings repassent à « Equip », la clé à molette est donnée")
buys = FIRE_SERVER.BuyItem or 0
setCash(P1, 9700 + 32000) -- a134 : Crowbar à 40K (8K avant) ; même argent qu'avant après l'achat (1 700)
el(row(list, "Crowbar"), "BuyButton").Activated:Fire()
el(row(list, "Crowbar"), "BuyButton").Activated:Fire()
step(0.05)
check((FIRE_SERVER.BuyItem or 0) == buys + 1 and owned(P1, "Crowbar") and cash(P1) == 1700, "G24 double clic sur Buy : un seul BuyItem, un seul débit")
buys = FIRE_SERVER.BuyItem or 0
m = mark()
el(row(list, "Hammer"), "BuyButton").Activated:Fire()
el(row(list, "Hammer"), "BuyButton").Activated:Fire()
step(0.5)
el(row(list, "Hammer"), "BuyButton").Activated:Fire()
step(0.05)
check((FIRE_SERVER.BuyItem or 0) == buys + 1 and #notifies(P1, m) == 1, "G24b clics répétés sur un achat refusé : un seul BuyItem par seconde")
step(1.1)
local equips = FIRE_SERVER.EquipTool or 0
el(row(list, "Fists"), "EquipButton").Activated:Fire()
step(0.05)
check((FIRE_SERVER.EquipTool or 0) == equips + 1 and P1:GetAttribute("EquippedTool") == "Fists" and heldToolId(P1) == "Fists", "G25 Equip sur les poings : EquipTool envoyé, poings équipés")
check(el(row(list, "Fists"), "EquipButton").Text == "Equipped" and el(row(list, "Crowbar"), "EquipButton").Text == "Equip", "G26 « Equipped » suit l'outil équipé")
el(row(list, "Fists"), "EquipButton").Activated:Fire()
el(row(list, "Hammer"), "EquipButton").Activated:Fire()
step(0.05)
check((FIRE_SERVER.EquipTool or 0) == equips + 1, "G27 rien n'est envoyé pour l'outil déjà équipé ni pour un outil pas possédé")
el(screen, "CloseButton").Activated:Fire()
step(0.05)
check(screen.Enabled == false, "G28 CloseButton ferme l'écran")
prompt.Triggered:Fire(P1)
step(0.05)
at(ROOT1, Vector3.new(-14, 3, 10.5)) -- 13,5 studs du comptoir
step(0.2)
check(screen.Enabled == true, "G29 reste ouvert à 13,5 studs du comptoir")
at(ROOT1, Vector3.new(-14, 3, 9)) -- 15 studs
step(0.2)
check(screen.Enabled == false, "G30 se ferme au-delà de 14 studs")
at(ROOT1, SHOP_SPOT)
prompt.Triggered:Fire(P1)
step(0.05)
ROOT1.Parent = nil -- mort ou réapparition : plus de HumanoidRootPart
step(0.1)
check(screen.Enabled == false, "G31 se ferme quand le personnage n'a plus de HumanoidRootPart")
ROOT1.Parent = P1.Character
-- Écran recréé (ResetOnSpawn) : l'ancien est détruit, le nouveau est rebranché.
screen:Destroy()
step(0.05)
check(prompt.Enabled == false, "G32 écran détruit : invite cachée")
local screen2, list2 = makeWeaponScreen()
step(0.05)
check(#rows(list2) == 7 and screen2.Enabled == false and prompt.Enabled == true, "G33 nouvel écran rebranché (7 lignes, fermé), invite visible")
check(el(row(list2, "Crowbar"), "BuyButton").Visible == false and el(row(list2, "Fists"), "EquipButton").Text == "Equipped", "G34 le nouvel écran reprend la possession et l'équipement")
screen2:Destroy()
step(0.05)
local broken = makeWeaponScreen({ noTemplate = true })
step(0.05)
check(logCount("List.Template absent", "WARN", "client") == 1 and prompt.Enabled == false, "G35 écran sans List.Template : un avertissement, pas branché")
broken:Destroy()
local screen3, list3 = makeWeaponScreen()
step(0.05)
check(#rows(list3) == 7 and prompt.Enabled == true and FAILS == 0, "G36 écran conforme rebranché, aucune erreur")
-- Streaming : la pièce principale disparaît puis revient, l'invite suit.
local oldPrompt = prompt
WEAPON_COUNTER.Parent = nil
step(0.05)
local moved = promptsIn(WEAPON_SHOP, "WeaponShopPrompt")
check(#moved == 1 and moved[1].Parent.Name == "SignPart", "G37 pièce principale retirée (streaming) : l'invite passe sur une autre pièce")
WEAPON_COUNTER.Parent = WEAPON_SHOP
step(0.05)
moved = promptsIn(WEAPON_SHOP, "WeaponShopPrompt")
check(#moved == 1 and moved[1].Parent == WEAPON_COUNTER and moved[1] ~= oldPrompt, "G38 pièce revenue : l'invite revient sur elle")
prompt = moved[1]

-- a37 (DEV-052) : ouverture et fermeture animées par UI/Motion, tweens dans le temps (Window, cadre
-- racine de l'écran, prend un UIScale passager).
-- Sauté si le module UI/Motion manque (arbre d'avant la fusion de DEV-052).
if SOURCES["client/Controllers/UI/Motion.luau"] then
	TIMED_TWEENS = true
	local windowZ = el(screen3, "Window")
	at(ROOT1, SHOP_SPOT)
	step(0.05)
	prompt.Triggered:Fire(P1)
	step(0.05)
	check(screen3.Enabled and windowZ:FindFirstChildOfClass("UIScale") ~= nil, "Z1 (a37) invite : écran allumé tout de suite, entrée animée (UIScale passager sur Window)")
	step(0.3)
	check(screen3.Enabled and windowZ:FindFirstChildOfClass("UIScale") == nil, "Z2 (a37) ouvert : UIScale retiré")
	el(screen3, "CloseButton").Activated:Fire()
	step(0.05)
	check(screen3.Enabled and windowZ:FindFirstChildOfClass("UIScale") ~= nil, "Z3 (a37) CloseButton : sortie en cours (0,12 s), écran encore allumé")
	prompt.Triggered:Fire(P1)
	step(0.3)
	check(screen3.Enabled and windowZ:FindFirstChildOfClass("UIScale") == nil, "Z4 (a37) invite pendant la sortie : l'écran reste ouvert")
	el(screen3, "CloseButton").Activated:Fire()
	step(0.2)
	check(screen3.Enabled == false and windowZ:FindFirstChildOfClass("UIScale") == nil and #rows(list3) == 7, "Z5 (a37) éteint au bout de la sortie, UIScale retiré, les 7 lignes restent")
	TIMED_TWEENS = false
end

print("\n== U. UpgradeController (invites de la parcelle)")
at(ROOT1, PLOT1_SPOT)
step(0.1)
local tp = upgradePrompt(TREADMILL1)
local point = tp and tp.Parent
check(tp ~= nil and point.Name == "UpgradePointV0" and point.ClassName == "Attachment" and point.Parent.Name == "Base", "U1 tapis : invite sur un point UpgradePointV0 créé dans la machine")
check(point and near(point.WorldPosition.X, 78) and near(point.WorldPosition.Y, 5) and near(point.WorldPosition.Z, 5.75), "U2 point au-dessus du sommet du tapis (+0,5 stud)")
check(tp and tp.ActionText == "Upgrade ($150)" and tp.ObjectText == "Treadmill Lv 1/20", "U3 a134 : « Upgrade ($150) » / « Treadmill Lv 1/20 » (niveau affiché = niveau enregistré + 1)")
check(tp and tp.KeyboardKeyCode == Enum.KeyCode.F and tp.GamepadKeyCode == Enum.KeyCode.ButtonY and tp.HoldDuration == 0.5 and tp.MaxActivationDistance == 8 and tp.RequiresLineOfSight == false and tp.Enabled, "U4 touche F / bouton Y, maintien 0,5 s, 8 studs")
local use1 = TREADMILL1:FindFirstChild("UsePoint", true)
check(#use1:GetChildren() == 1 and use1.TrainingPrompt.ActionText == "Run", "U5 le UsePoint garde seulement l'invite Run de TrainingService")
local bp = upgradePrompt(BENCH1)
check(bp == nil, "U6 a134 : plus d'invite d'amélioration sur le banc (plus de banc)")
local sp = upgradePrompt(PLOT1)
local function promptOn(name)
	local a = PLOT1:FindFirstChild(name, true)
	return a and a:FindFirstChild("UpgradePrompt")
end
sp = promptOn("DisplaySlot_05")
check(sp and sp.ActionText == "Unlock stand ($500)" and sp.ObjectText == "Stands 4/20", "U7 « Unlock stand ($500) » / « Stands 4/20 » sur DisplaySlot_05")
-- Copie a46 (L-086) : plus d'établis ni d'amélioration « Workbenches » : aucune invite sur les UnboxBench_xx.
check(promptOn("UnboxBench_02") == nil, "U8 plus d'invite « Unlock workbench » (L-086)")
check(#promptsIn(PLOT1, "UpgradePrompt") == 2 and #promptsIn(PLOT2, "UpgradePrompt") == 0, "U9 a134 : 2 invites sur sa parcelle (tapis, présentoir), aucune sur celle d'un autre")

setCash(P1, 100000)
buys = FIRE_SERVER.BuyItem or 0
tp.Triggered:Fire(P1)
check(tp.Enabled == false, "U10 invite coupée dès le déclenchement")
step(0.1)
tp = upgradePrompt(TREADMILL1)
check((FIRE_SERVER.BuyItem or 0) == buys + 1 and P1:GetAttribute("TreadmillLevel") == 1 and cash(P1) == 99850, "U11 Upgrade : BuyItem(Treadmill), niveau 1, 150 $ débités (a134)")
check(tp and tp.Enabled and tp.ActionText == "Upgrade ($570)" and tp.ObjectText == "Treadmill Lv 2/20", "U12 l'invite affiche le niveau suivant : « Upgrade ($570) » / « Lv 2/20 » (a134)")
-- Entre deux achats, plus d'une seconde : le débit de BuyItem (4 par seconde) n'est pas en jeu ici.
step(1.1)
sp.Triggered:Fire(P1)
step(0.1)
check(P1:GetAttribute("DisplaySlotsLevel") == 1 and promptOn("DisplaySlot_05") == nil, "U13 présentoir débloqué : plus d'invite sur DisplaySlot_05")
sp = promptOn("DisplaySlot_06")
check(sp and sp.ActionText == "Unlock stand ($1.2K)" and sp.ObjectText == "Stands 5/20", "U14 invite sur DisplaySlot_06 : « Unlock stand ($1.2K) » / « Stands 5/20 »")
step(1.1)
m = mark()
send(P1, "BuyItem", "UnboxBenches")
check(cash(P1) == 100000 - 150 - 500 and P1:GetAttribute("UnboxBenchesLevel") == nil and #notifies(P1, m) == 0, "U15 BuyItem(UnboxBenches) : Id inconnu, refus muet, rien débité")
setCash(P1, 12000) -- même argent qu'avant la copie (fin des achats d'établis)
local given = attachment("UpgradePoint", BENCH1.Bar, Vector3.new(122, 5, 3))
step(0.1)
bp = upgradePrompt(BENCH1)
check(bp == nil and given.Parent ~= nil and #promptsIn(BENCH1, "UpgradePrompt") == 0, "U21 a134 : UpgradePoint livré dans le banc : aucune invite (plus de banc)")
DataService.Get(P1).Upgrades.Treadmill = 20
ShopService.RefreshPlayer(P1)
step(0.1)
check(upgradePrompt(TREADMILL1) == nil and P1:GetAttribute("TreadmillLevel") == 20, "U22 tapis au niveau max : plus d'invite")
PLOT1:SetAttribute("OwnerUserId", 0)
step(0.1)
check(#promptsIn(PLOT1, "UpgradePrompt") == 0 and TREADMILL1:FindFirstChild("UpgradePointV0", true) == nil, "U23 parcelle libérée : invites et points créés retirés")
PLOT1:SetAttribute("OwnerUserId", 101)
step(0.1)
check(#promptsIn(PLOT1, "UpgradePrompt") == 1 and upgradePrompt(BENCH1) == nil and promptOn("DisplaySlot_06") ~= nil, "U24 a134 : parcelle rendue : invite des présentoirs revenue (tapis au niveau max, plus de banc)")
check(FAILS == 0, "U25 aucune erreur côté client")

print("\n== B. Boutique d'armes (serveur), joueur Bob")
at(ROOT2, SHOP_SPOT)
local toolLoop = { refused = true, debit = true, equipped = true, messages = true, again = true }
for _, tool in Tools.List do
	if tool.Price > 0 then
		setCash(P2, tool.Price - 1)
		m = mark()
		send(P2, "BuyItem", tool.Id)
		n = onlyNotify(P2, m)
		if not (n and n.text == `Not enough cash: {Format.money(tool.Price)} needed.` and n.kind == "Warning" and cash(P2) == tool.Price - 1 and not owned(P2, tool.Id)) then
			toolLoop.refused = false
			print(`    refus {tool.Id} : {n and n.text}`)
		end
		setCash(P2, tool.Price)
		m = mark()
		send(P2, "BuyItem", tool.Id)
		n = onlyNotify(P2, m)
		if not (cash(P2) == 0 and owned(P2, tool.Id)) then
			toolLoop.debit = false
		end
		if not (P2:GetAttribute("EquippedTool") == tool.Id and heldToolId(P2) == tool.Id and P2:GetAttribute("Damage") == tool.Power) then
			toolLoop.equipped = false
		end
		if not (n and n.text == `{tool.DisplayName} bought and equipped!` and n.kind == "Info") then
			toolLoop.messages = false
			print(`    succès {tool.Id} : {n and n.text}`)
		end
		setCash(P2, tool.Price)
		m = mark()
		send(P2, "BuyItem", tool.Id)
		n = onlyNotify(P2, m)
		if not (n and n.text == `You already own the {tool.DisplayName}.` and cash(P2) == tool.Price) then
			toolLoop.again = false
		end
	end
end
check(toolLoop.refused, "B1 6 outils : refus avec 1 $ de moins (Notify « Not enough cash: <prix> needed. », rien de débité)")
check(toolLoop.debit, "B2 6 outils : prix exact de Config débité, outil possédé")
check(toolLoop.equipped, "B3 chaque outil acheté (plus fort) est équipé : EquippedTool, Tool donné, Damage = puissance")
check(toolLoop.messages, "B4 Notify « <outil> bought and equipped! » (Info)")
check(toolLoop.again, "B5 racheter un outil possédé : « You already own the <outil>. », rien de débité")
check(P2:GetAttribute("OwnedTools") == "Fists,Wrench,Crowbar,Hammer,Sledgehammer,FireAxe,AngleGrinder", "B6 OwnedTools dans l'ordre de la boutique")
setCash(P2, 5)
m = mark()
send(P2, "BuyItem", "Fists")
n = onlyNotify(P2, m)
check(n and n.text == "You already own the Fists." and cash(P2) == 5, "B7 les poings (gratuits) sont déjà possédés")
-- Outil plus faible acheté après un plus fort : pas équipé à sa place (joueur 3, profil neuf).
local P3, ROOT3 = joinLater("Chloe", 303, SHOP_SPOT)
step(0.1)
check(P3:GetAttribute("OwnedTools") == "Fists" and heldToolId(P3) == "Fists", "B7b joueur arrivé après le démarrage : profil chargé, attributs publiés")
setCash(P3, 1000300) -- a134 : Hammer à 1M
send(P3, "BuyItem", "Hammer")
m = mark()
send(P3, "BuyItem", "Wrench")
n = onlyNotify(P3, m)
check(owned(P3, "Wrench") and P3:GetAttribute("EquippedTool") == "Hammer" and cash(P3) == 0, "B8 outil plus faible acheté après : possédé mais pas équipé")
check(n and n.text == "Wrench bought!" and n.kind == "Info", "B9 Notify « Wrench bought! »")
setCash(P3, 40000) -- a134 : Crowbar à 40K
at(ROOT3, FAR_SPOT)
m = mark()
send(P3, "BuyItem", "Crowbar")
n = onlyNotify(P3, m)
check(n and n.text == "Go to the Weapon Shop to buy tools." and cash(P3) == 40000 and not owned(P3, "Crowbar"), "B10 loin du comptoir (26 studs) : refusé, Notify, rien de débité")
at(ROOT3, Vector3.new(500, 3, 494))
send(P3, "BuyItem", "Crowbar")
check(not owned(P3, "Crowbar"), "B11 le comptoir de _INBOX_CLEMENT ne compte pas")
at(ROOT3, Vector3.new(-14, 3, 5)) -- 19 studs
send(P3, "BuyItem", "Crowbar")
check(owned(P3, "Crowbar") and cash(P3) == 0, "B12 accepté jusqu'à 20 studs du comptoir (marge réseau)")
P3.Character.Humanoid.Health = 0
setCash(P3, 120000)
at(ROOT3, SHOP_SPOT)
send(P3, "BuyItem", "Hammer")
check(cash(P3) == 120000, "B13 personnage mort : refusé")
P3.Character.Humanoid.Health = 100

print("\n== C. EquipTool")
m = mark()
send(P2, "EquipTool", "Wrench")
check(P2:GetAttribute("EquippedTool") == "Wrench" and heldToolId(P2) == "Wrench" and P2:GetAttribute("Damage") == 5 and #notifies(P2, m) == 0, "C1 EquipTool(Wrench) : équipé, Damage = 5 (a134), sans message")
at(ROOT2, FAR_SPOT)
send(P2, "EquipTool", "AngleGrinder")
check(P2:GetAttribute("EquippedTool") == "AngleGrinder", "C2 EquipTool marche hors de la boutique (outil possédé)")
clearLog()
m = mark()
send(P3, "EquipTool", "AngleGrinder")
check(P3:GetAttribute("EquippedTool") == "Hammer" and #notifies(P3, m) == 0 and logCount("Chloe → EquipTool(« AngleGrinder ») refusé : outil pas possédé", "WARN") == 1, "C3 outil pas possédé : refus muet, avertissement en Studio")
send(P3, "EquipTool", "Banana")
check(logCount("refusé : outil inconnu", "WARN") == 1 and #notifies(P3, m) == 0, "C4 outil inconnu : refus muet")
send(P3, "EquipTool", 5)
send(P3, "EquipTool", string.rep("x", 65))
send(P3, "EquipTool")
check(logCount("[Net] Chloe → EquipTool refusé", "WARN") == 3 and P3:GetAttribute("EquippedTool") == "Hammer", "C5 EquipTool mal formé (nombre, 65 caractères, rien) : refusé par Net")

print("\n== D. Améliorations jusqu'au niveau max, joueur Bob sur sa parcelle")
at(ROOT2, PLOT2_SPOT)
local costLines = {}
for _, upgrade in Upgrades.List do
	local ok = { refused = true, cost = true, level = true, message = true }
	local refreshBefore = UNBOX_REFRESH[P2] or 0
	for level = 0, upgrade.MaxLevel - 1 do
		local expected = math.round(upgrade.BaseCost * upgrade.Growth ^ level)
		if Formulas.UpgradeCost(upgrade.Id, level) ~= expected then
			ok.cost = false
		end
		if level < 4 then
			table.insert(costLines, `{upgrade.Id} n={level} : {expected}`)
		end
		setCash(P2, expected - 1)
		m = mark()
		send(P2, "BuyItem", upgrade.Id)
		n = onlyNotify(P2, m)
		if not (n and n.text == `Not enough cash: {Format.money(expected)} needed.` and cash(P2) == expected - 1 and DataService.Get(P2).Upgrades[upgrade.Id] == level) then
			ok.refused = false
		end
		setCash(P2, expected)
		m = mark()
		send(P2, "BuyItem", upgrade.Id)
		n = onlyNotify(P2, m)
		if cash(P2) ~= 0 then
			ok.cost = false
		end
		if not (DataService.Get(P2).Upgrades[upgrade.Id] == level + 1 and P2:GetAttribute(upgrade.Id .. "Level") == level + 1) then
			ok.level = false
		end
		local wanted = if upgrade.Id == "DisplaySlots"
			then `New stand unlocked! ({4 + level + 1}/20)`
			elseif upgrade.Id == "UnboxBenches" then `New workbench unlocked! ({1 + level + 1}/4)`
			else `{upgrade.DisplayName} upgraded to level {level + 2}!` -- a134 : tapis, niveau affiché = niveau enregistré + 1
		if not (n and n.text == wanted and n.kind == "Info") then
			ok.message = false
			print(`    {upgrade.Id} niveau {level + 1} : {n and n.text}`)
		end
	end
	check(ok.refused, `D {upgrade.Id} : refus à chaque niveau avec 1 $ de moins`)
	check(ok.cost, `D {upgrade.Id} : {upgrade.MaxLevel} niveaux, coût débité = C0 × g^n arrondi (C0 = {upgrade.BaseCost}, g = {upgrade.Growth})`)
	check(ok.level, `D {upgrade.Id} : niveau + 1 dans le profil et dans l'attribut {upgrade.Id}Level`)
	check(ok.message, `D {upgrade.Id} : Notify de réussite à chaque niveau`)
	setCash(P2, 1e15)
	m = mark()
	send(P2, "BuyItem", upgrade.Id)
	n = onlyNotify(P2, m)
	local maxText = if upgrade.Id == "DisplaySlots"
		then "All your stands are unlocked."
		elseif upgrade.Id == "UnboxBenches" then "All your workbenches are unlocked."
		else `Your {upgrade.DisplayName} is already at max level.`
	check(n and n.text == maxText and cash(P2) == 1e15 and DataService.Get(P2).Upgrades[upgrade.Id] == upgrade.MaxLevel, `D {upgrade.Id} : au max ({upgrade.MaxLevel}), « {maxText} », rien de débité`)
	if upgrade.Id == "UnboxBenches" then
		check((UNBOX_REFRESH[P2] or 0) - refreshBefore == 3, "D UnboxBenches : UnboxService.Refresh appelé à chacun des 3 achats, jamais sur un refus")
	end
end
print("    coûts relevés : " .. table.concat(costLines, " · "))
check(Formulas.UpgradeCost("Treadmill", 3) == 8231 and Formulas.UpgradeCost("Treadmill", 19) == nil and not pcall(Formulas.UpgradeCost, "Bench", 0) and Formulas.UpgradeCost("DisplaySlots", 15) == math.round(500 * 2.5 ^ 15) and not pcall(Formulas.UpgradeCost, "UnboxBenches", 2), "D coûts témoins : tapis n=3 1 372 $, présentoirs n=15 ; UnboxBenches inconnu (L-086)")
-- Hors de sa parcelle, sur celle d'un autre, sans parcelle, niveau abîmé, Refresh en panne.
setCash(P3, 1000)
at(ROOT3, PLOT2_SPOT)
PLOTS[P3] = PLOT1
m = mark()
send(P3, "BuyItem", "Treadmill")
n = onlyNotify(P3, m)
check(n and n.text == "Go back to your shop to buy upgrades." and cash(P3) == 1000, "D hors de sa parcelle (sur celle d'un autre) : refusé, Notify")
at(ROOT3, PLOT1_SPOT)
send(P3, "BuyItem", "Treadmill")
check(cash(P3) == 850 and DataService.Get(P3).Upgrades.Treadmill == 1, "D dans le volume Bounds de sa parcelle : accepté")
PLOTS[P3] = nil
clearLog()
m = mark()
send(P3, "BuyItem", "Treadmill") -- a134 : le banc n'est plus vendu, ces scénarios passent par le tapis
check(cash(P3) == 850 and #notifies(P3, m) == 0 and logCount("Chloe → BuyItem(« Treadmill ») refusé : pas de parcelle", "WARN") == 1, "D sans parcelle : refus muet, avertissement en Studio")
PLOTS[P3] = PLOT1
m = mark()
send(P3, "BuyItem", "Bench")
check(cash(P3) == 850 and #notifies(P3, m) == 0 and DataService.Get(P3).Upgrades.Bench == 0, "D a134 : BuyItem(Bench) : Id inconnu, refus muet, rien débité, niveau du profil inchangé")
DataService.Get(P3).Upgrades.Treadmill = "abc"
send(P3, "BuyItem", "Treadmill")
check(cash(P3) == 700 and DataService.Get(P3).Upgrades.Treadmill == 1, "D niveau abîmé (« abc ») : compté 0, coût 150 $, niveau 1")
DataService.Get(P3).Upgrades.Treadmill = 2.7
setCash(P3, 2166)
send(P3, "BuyItem", "Treadmill")
check(cash(P3) == 0 and DataService.Get(P3).Upgrades.Treadmill == 3, "D niveau non entier (2,7) : compté 2, coût 2 166 $, niveau 3")
UNBOX_REFRESH_ERROR = true
setCash(P3, 500)
clearLog()
send(P3, "BuyItem", "DisplaySlots") -- copie a46 : Refresh suit l achat d un présentoir (L-086)
UNBOX_REFRESH_ERROR = false
check(cash(P3) == 0 and DataService.Get(P3).Upgrades.DisplaySlots == 1 and P3:GetAttribute("DisplaySlotsLevel") == 1 and logCount("[ShopService] UnboxService.Refresh (Chloe)", "WARN") == 1, "D UnboxService.Refresh en panne : achat gardé, attribut publié, avertissement")
FAILS_BEFORE_E = FAILS

print("\n== E. Auras et trails (CosmeticService bouchonné)")
at(ROOT3, AURA_SPOT)
setCash(P3, 499)
m = mark()
send(P3, "BuyItem", "Spark")
n = onlyNotify(P3, m)
check(n and n.text == "Not enough cash: $500 needed." and #GRANT_CALLS == 0, "E1 Spark sans assez d'argent : refusé, Grant pas appelé")
setCash(P3, 500)
m = mark()
send(P3, "BuyItem", "Spark")
n = onlyNotify(P3, m)
check(cash(P3) == 0 and #GRANT_CALLS == 1 and GRANT_CALLS[1].player == P3 and GRANT_CALLS[1].id == "Spark", "E2 Spark : 500 $ débités, CosmeticService.Grant(joueur, « Spark »)")
check(n and n.text == "Spark bought!" and n.kind == "Info", "E3 Notify « Spark bought! »")
setCash(P3, 500)
m = mark()
send(P3, "BuyItem", "Spark")
n = onlyNotify(P3, m)
check(n and n.text == "You already own Spark." and cash(P3) == 500 and #GRANT_CALLS == 1, "E4 déjà possédé (Owns) : refusé, rien de débité")
setCash(P3, 300)
send(P3, "BuyItem", "Dust")
check(cash(P3) == 0 and COSMETIC_OWNED[P3].Dust == true, "E5 trail Dust : 300 $, accordé")
setCash(P3, 60000) -- a134 : Flame à 60K
at(ROOT3, SHOP_SPOT)
m = mark()
send(P3, "BuyItem", "Flame")
n = onlyNotify(P3, m)
check(n and n.text == "Go to the Aura Shop to buy auras and trails." and cash(P3) == 60000, "E6 loin du comptoir d'auras : refusé")
at(ROOT3, AURA_SPOT)
GRANT_MODE = "fail"
clearLog()
m = mark()
send(P3, "BuyItem", "Flame")
check(cash(P3) == 60000 and #notifies(P3, m) == 0 and logCount("CosmeticService.Grant(Flame) a échoué", "WARN") == 1, "E7 Grant renvoie false : argent rendu, avertissement")
GRANT_MODE = "error"
send(P3, "BuyItem", "Flame")
check(cash(P3) == 60000 and logCount("CosmeticService.Grant(Flame) a échoué", "WARN") == 2 and FAILS == FAILS_BEFORE_E, "E8 Grant lève une erreur : argent rendu, pas d'erreur qui remonte")
GRANT_MODE = "ok"
setCash(P3, 8e9)
send(P3, "BuyItem", "Royal")
check(cash(P3) == 0 and COSMETIC_OWNED[P3].Royal == true, "E9 Royal : 8 Md$ débités (prix de Config, a134)")

print("\n== F. Envois malformés, débit, profil pas chargé")
at(ROOT3, SHOP_SPOT)
setCash(P3, 1e6)
clearLog()
m = mark()
send(P3, "BuyItem", "Banana")
send(P3, "BuyItem", "wrench")
check(cash(P3) == 1e6 and #notifies(P3, m) == 0 and logCount("refusé : identifiant inconnu", "WARN") == 2, "F1 Id inconnu (« Banana », « wrench ») : refus muet, avertissement en Studio")
send(P3, "BuyItem", 42)
send(P3, "BuyItem", "")
send(P3, "BuyItem", string.rep("a", 65))
send(P3, "BuyItem", nil)
send(P3, "BuyItem", {})
send(P3, "BuyItem", "Wrench", "encore")
send(P3, "BuyItem")
check(cash(P3) == 1e6 and #notifies(P3, m) == 0 and logCount("[Net] Chloe → BuyItem refusé", "WARN") == 7, "F2 7 envois mal formés : refusés par Net, rien de débité, aucun message")
step(1.1)
m = mark()
for _ = 1, 6 do
	ReplicatedStorage.Remotes.BuyItem.OnServerEvent:Fire(P3, "Fists")
end
step(0.05)
check(#notifies(P3, m) == 4, "F3 6 BuyItem dans la même seconde : 4 traités (débit de Definitions)")
step(1.1)
SLOW_PROFILES["Player_404"] = true
local P4 = joinLater("Dan", 404, SHOP_SPOT)
step(0.2)
clearLog()
m = mark()
send(P4, "BuyItem", "Wrench")
send(P4, "EquipTool", "Fists")
check(#notifies(P4, m) == 0 and logCount("Dan → BuyItem(« Wrench ») refusé : profil pas chargé", "WARN") == 1 and logCount("Dan → EquipTool(« Fists ») refusé : profil pas chargé", "WARN") == 1, "F4 profil pas chargé : refus muets")
check(P4:GetAttribute("OwnedTools") == nil, "F5 pas d'attribut avant le profil")
SLOW_PROFILES["Player_404"] = nil
step(0.3)
check(P4:GetAttribute("OwnedTools") == "Fists" and P4:GetAttribute("TreadmillLevel") == 0, "F6 attributs publiés au chargement du profil")
check(FAILS == 0, "F7 aucune erreur dans une tâche")

summary()
