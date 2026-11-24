--!nocheck
-- Scénario « stand » (a49, DEV-131) : la mutation du colis porté passe dans le colis posé (Boxes), puis
-- dans l'objet ouvert (Items[uid].Mutation), sans changer la version du profil ; UnboxReveal la porte ;
-- le revenu de l'objet exposé est multiplié (présentoir, attribut Income, BB_Item, GetExposed, Income et
-- ExposedIncome du joueur), les bonus globaux restent par-dessus ; le modèle exposé est mis à l'échelle
-- (Model:ScaleTo) et porte MutationSize / MutationEffect ; BB_Item écrit la mutation devant le nom (ou
-- dans un texte Mutation s'il existe). Colis amélioré : la mutation reste. Objet TutorialOnly : jamais.

advance(1000)
startServer()
local Mutations = sharedModule("Config/Mutations")
local Format = sharedModule("Format")
-- Version du profil attendue : v5, ou v6 si les gains hors ligne d'a48 (Offline) sont dans l'arbre. Les
-- mutations ne la changent pas.
-- a51 (L-089) : v7 quand Types/Profile a Spot (colis rangés par uid dans l'inventaire).
local VERSION = if string.find(SOURCES["shared/Types/Profile.luau"], "Spot: Spot?", 1, true) then (if string.find(SOURCES["shared/Types/Profile.luau"], "Rewards: Rewards", 1, true) then 8 else 7) elseif string.find(SOURCES["shared/Types/Profile.luau"], "Offline: Offline", 1, true) then 6 else 5

local function payload(rarity, itemId, tier, zone, mutation)
	local p = npcBox(rarity, itemId, tier, zone)
	p.Mutation = mutation
	return p
end
-- a51 (L-089) : le colis rentre dans l'inventaire puis se pose au sol (compat51 : placePayload) ; l'objet
-- ouvert va dans l'inventaire, puis sur le présentoir n° slot (PlaceItem), pour garder les contrôles de
-- l'objet exposé.
local function place(player, slot, p)
	return placePayload(player, slot, p)
end
local baseOpenPlaced = openPlaced
openPlaced = function(player, slot)
	local uid = baseOpenPlaced(player, slot)
	if uid then
		DisplayService.PlaceItem(player, uid, slot)
	end
	return uid
end
local function exposedModel(player, uid)
	local f = shopOf(player):FindFirstChild("DisplayItems")
	for _, child in (f and f:GetChildren() or {}) do
		if child:GetAttribute("ItemUid") == uid then
			return child
		end
	end
	return nil
end
local function bbText(model, name)
	local bb = model and model:FindFirstChild("BB_Item", true)
	local el = bb and bb:FindFirstChild(name, true)
	return if el then el.Text else nil
end
local function lastReveal(player)
	local list = remotes("UnboxReveal", function(e)
		return e.to == player
	end)
	return list[#list]
end

section("colis porté avec mutation → colis posé → objet")
local ada = join("Ada", nil)
advance(1.5)
local base = Formulas.ItemIncome(2, "Common")
local box = place(ada, 1, payload("Common", "Z2_CanardEnPlastique", "Standard", 2, { Size = "Big", Effect = "Gold" }))
check(box ~= nil and type(box.Mutation) == "table" and box.Mutation.Size == "Big" and box.Mutation.Effect == "Gold", "colis posé (Boxes[uid]).Mutation = { Size = Big, Effect = Gold }")
check(dataOf(ada).Version == VERSION, `profil en v{VERSION} : aucun changement de version pour les mutations ({dataOf(ada).Version})`)
local uid = openPlaced(ada, 1)
local entry = uid and dataOf(ada).Items[uid]
check(entry ~= nil and entry.Mutation ~= nil and entry.Mutation.Size == "Big" and entry.Mutation.Effect == "Gold", "Items[uid].Mutation = { Size = Big, Effect = Gold }")
local r = lastReveal(ada)
check(r ~= nil and r.args.n == 9 and r.args[8] == "Big" and r.args[9] == "Gold", `UnboxReveal : 9 arguments, mutationSize Big, mutationEffect Gold ({r and r.args.n})`)
check(logHas("mutation BIG · GOLD", "PRINT", "server"), "ligne d'ouverture avec la mutation")
advance(1.2)
local model = exposedModel(ada, uid)
check(model ~= nil and model:GetAttribute("MutationSize") == "Big" and model:GetAttribute("MutationEffect") == "Gold", "objet exposé : attributs MutationSize = Big, MutationEffect = Gold")
check(model ~= nil and near(model:GetAttribute("Income"), base * 4), `attribut Income = base × 2 × 2 ({model and model:GetAttribute("Income")} pour {base * 4})`)
local exposed = DisplayService.GetExposed(ada)[1]
check(exposed ~= nil and near(exposed.Income, base * 4), "GetExposed : revenu ×4 (anti-racket, vol)")
check(near(ada:GetAttribute("ExposedIncome"), base * 4) and near(DisplayService.GetIncome(ada), base * 4), "ExposedIncome et GetIncome du joueur : ×4")
check(bbText(model, "ItemName") == "Big Gold Rubber Duck", `BB_Item V0 : ItemName « Big Gold Rubber Duck » ({tostring(bbText(model, "ItemName"))})`)
check(bbText(model, "Income") == Format.income(base * 4), `BB_Item : Income {Format.income(base * 4)} ({tostring(bbText(model, "Income"))})`)
check(model ~= nil and model:GetScale() == 1.5, `modèle exposé à l'échelle 1,5 (Model:ScaleTo, {model and model:GetScale()})`)
local root = model and model.PrimaryPart
check(root ~= nil and near(root.Size.Y, 1.6 * 1.5, 1e-4), `bloc V0 : 1,6 × 1,5 stud de haut ({root and root.Size.Y})`)
local slotAt = standPos(ada, 1)
check(model ~= nil and (model:GetPivot().Position - slotAt).Magnitude < 1e-4, "pivot (en bas au centre) toujours sur le présentoir après la mise à l'échelle")
local halo = model and model:FindFirstChild("RarityHalo")
check(halo == nil, "Commun : pas de halo (inchangé)")

section("sans mutation : rien de changé")
local box2 = place(ada, 2, payload("Common", "Z2_CanardEnPlastique", "Standard", 2, nil))
check(box2 ~= nil and box2.Mutation == nil, "colis sans mutation : pas de champ Mutation")
local uid2 = openPlaced(ada, 2)
local entry2 = uid2 and dataOf(ada).Items[uid2]
check(entry2 ~= nil and entry2.Mutation == nil, "objet sans mutation : pas de champ Mutation dans Items[uid]")
local r2 = lastReveal(ada)
check(r2 ~= nil and r2.args[8] == nil and r2.args[9] == nil, "UnboxReveal sans mutation : nil, nil")
advance(1.2)
local model2 = exposedModel(ada, uid2)
check(model2 ~= nil and model2:GetAttribute("MutationSize") == nil and model2:GetAttribute("MutationEffect") == nil, "pas d'attribut MutationSize / MutationEffect")
check(model2 ~= nil and model2:GetScale() == 1 and near(model2:GetAttribute("Income"), base) and bbText(model2, "ItemName") == "Rubber Duck", "échelle 1, revenu de base, nom seul")
check(near(DisplayService.GetIncome(ada), base * 5), `revenu total : 4 + 1 fois la base ({DisplayService.GetIncome(ada)})`)

section("bonus globaux par-dessus")
local before = DisplayService.GetGlobalMultiplier(ada)
local baseMultiplier = DisplayService.GetIncomeMultiplier
DisplayService.GetIncomeMultiplier = function(player)
	return baseMultiplier(player) * 2
end
advance(1.2)
local global = DisplayService.GetGlobalMultiplier(ada)
check(near(global, before * 2), `le ×2 double le M global ({before} → {global})`)
check(near(ada:GetAttribute("ExposedIncome"), base * 5), "ExposedIncome : sans bonus, mutations comprises")
check(near(ada:GetAttribute("Income"), base * 5 * global), `Income = exposé (mutations comprises) × M global ({ada:GetAttribute("Income")})`)
DisplayService.GetIncomeMultiplier = baseMultiplier
leave(ada)

section("profil chargé : objets déjà mutés, mutation inconnue")
local data = newProfile()
addItem(data, "m1", "Z2_CanardEnPlastique", 1, 2)
data.Items.m1.Mutation = { Effect = "Rainbow" }
addItem(data, "m2", "Z2_CanardEnPlastique", 2, 2)
data.Items.m2.Mutation = { Size = "Mega", Effect = 7 }
addItem(data, "m3", "Z2_CanardEnPlastique", 3, 2)
data.Items.m3.Mutation = { Size = "Tiny" }
addItem(data, "m4", "Z2_CanardEnPlastique", 4, 2)
data.Items.m4.Mutation = { Size = "Colossal", Effect = "Rainbow" }
local bob = join("Bob", data)
advance(1.5)
local e = DisplayService.GetExposed(bob)
check(e[1] and near(e[1].Income, base * 10), "Rainbow : ×10")
check(e[2] and near(e[2].Income, base), "mutation illisible : ×1, objet gardé")
check(e[3] and near(e[3].Income, base * 0.5), "Tiny : ×0,5")
check(e[4] and near(e[4].Income, base * 100), "Colossal Rainbow : ×100")
local mm2 = exposedModel(bob, "m2")
check(mm2 ~= nil and mm2:GetScale() == 1 and mm2:GetAttribute("MutationSize") == nil and mm2:GetAttribute("MutationEffect") == nil and bbText(mm2, "ItemName") == "Rubber Duck", "mutation illisible : ni échelle, ni attribut, nom seul")
local mm3 = exposedModel(bob, "m3")
check(mm3 ~= nil and mm3:GetScale() == 0.6 and mm3:GetAttribute("MutationSize") == "Tiny" and mm3:GetAttribute("MutationEffect") == nil, "Tiny : échelle 0,6, MutationSize = Tiny seul")
local mm4 = exposedModel(bob, "m4")
check(mm4 ~= nil and mm4:GetScale() == 3 and bbText(mm4, "ItemName") == "Colossal Rainbow Rubber Duck", "Colossal Rainbow : échelle 3, « Colossal Rainbow Rubber Duck »")
check(dataOf(bob).Version == VERSION and dataOf(bob).Items.m1.Mutation.Effect == "Rainbow", "migration depuis la v4 : le champ Mutation des objets est gardé")
leave(bob)

section("BB_Item de Clément avec un texte Mutation (nom proposé)")
local ui = ASSETS:FindFirstChild("UI") or folder(ASSETS, "UI")
local bb = make("BillboardGui", { Name = "BB_Item" }, ui)
local lines = make("Frame", { Name = "Lines" }, bb)
make("TextLabel", { Name = "ItemName", Text = "" }, lines)
make("TextLabel", { Name = "Rarity", Text = "" }, lines)
make("TextLabel", { Name = "Income", Text = "" }, lines)
make("TextLabel", { Name = "Mutation", Text = "", Visible = false }, lines)
local data3 = newProfile()
addItem(data3, "n1", "Z2_CanardEnPlastique", 1, 2)
data3.Items.n1.Mutation = { Size = "Huge", Effect = "Diamond" }
addItem(data3, "n2", "Z2_CanardEnPlastique", 2, 2)
local cy = join("Cy", data3)
advance(1.5)
local n1 = exposedModel(cy, "n1")
local n1Mut = n1 and n1:FindFirstChild("Mutation", true)
check(bbText(n1, "ItemName") == "Rubber Duck" and n1Mut ~= nil and n1Mut.Text == "HUGE · DIAMOND" and n1Mut.Visible == true, `texte Mutation : « HUGE · DIAMOND » visible, ItemName = nom seul ({tostring(bbText(n1, "ItemName"))}, {n1Mut and n1Mut.Text})`)
local n2 = exposedModel(cy, "n2")
local n2Mut = n2 and n2:FindFirstChild("Mutation", true)
check(n2Mut ~= nil and n2Mut.Visible == false and bbText(n2, "ItemName") == "Rubber Duck", "sans mutation : texte Mutation caché")
check(n1 ~= nil and near(n1:GetAttribute("Income"), base * 15) and bbText(n1, "Income") == Format.income(base * 15), "Huge Diamond : ×15 sur le présentoir et le billboard")
local p1 = n1 and n1:FindFirstChild("BillboardPoint", true)
local p2 = n2 and n2:FindFirstChild("BillboardPoint", true)
local at1, at2 = standPos(cy, 1), standPos(cy, 2)
check(p1 ~= nil and near(p1.WorldPosition.Y - at1.Y, 1.6, 1e-3), `BB_Item de Clément sur un objet Huge : point monté de ce que l'objet a gagné (1,6 stud ; {p1 and string.format("%.3f", p1.WorldPosition.Y - at1.Y)})`)
check(p2 ~= nil and near(p2.WorldPosition.Y - at2.Y, 0, 1e-3), "sans taille : point au pied de l'objet, comme avant (L-027)")
leave(cy)
bb:Destroy()

section("modèle ITM_ de Clément mis à l'échelle")
local itemsFolder = ASSETS:FindFirstChild("Items") or folder(ASSETS, "Items")
local itm = make("Model", { Name = "ITM_Z2_CanardEnPlastique" }, itemsFolder)
local itmRoot = make("Part", { Name = "Root", Anchored = true, Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(0, 1, 0), PivotOffset = CFrame.new(0, -1, 0) }, itm)
make("Part", { Name = "Spin_Head", Anchored = true, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(0, 2.25, 0) }, itm)
itm.PrimaryPart = itmRoot
local data4 = newProfile()
addItem(data4, "q1", "Z2_CanardEnPlastique", 1, 2)
data4.Items.q1.Mutation = { Size = "Huge" }
local dee = join("Dee", data4)
advance(1.5)
local q1 = exposedModel(dee, "q1")
local head = q1 and q1:FindFirstChild("Spin_Head")
local qRoot = q1 and q1:FindFirstChild("Root")
local at = standPos(dee, 1)
check(q1 ~= nil and q1:GetAttribute("Placeholder") == false and q1:GetScale() == 2, "copie du modèle ITM_ à l'échelle 2 (Huge)")
check(qRoot ~= nil and near(qRoot.Size.Y, 4, 1e-4) and head ~= nil and near(head.Size.X, 1, 1e-4), "pièces deux fois plus grandes")
check(head ~= nil and near(head.Position.Y - at.Y, 4.5, 1e-3) and (q1:GetPivot().Position - at).Magnitude < 1e-4, `pièces écartées du pivot × 2, pivot sur le présentoir (tête à {head and string.format("%.2f", head.Position.Y - at.Y)} au-dessus)`)
check(q1 ~= nil and near(q1:GetAttribute("Income"), base * 5), "Huge : ×5")
check(itm:GetScale() == 1, "le modèle de Clément dans Assets n'est pas touché")
leave(dee)
itm:Destroy()

section("colis amélioré : la mutation reste ; objet TutorialOnly : jamais")
local eve = join("Eve", nil)
advance(1.5)
UnboxService.GetLuck = function()
	return 1000
end
place(eve, 1, payload("Common", "Z2_CanardEnPlastique", "Premium", 2, { Effect = "Neon" }))
local up = openPlaced(eve, 1)
local upEntry = up and dataOf(eve).Items[up]
local upDef = upEntry and Items.ById[upEntry.Id]
local rUp = lastReveal(eve)
check(rUp ~= nil and rUp.args[7] > 0 and upDef ~= nil and upDef.Rarity ~= "Common", `crans réussis : objet changé ({upDef and upDef.Rarity}, {rUp and rUp.args[7]} cran(s))`)
check(upEntry ~= nil and upEntry.Mutation ~= nil and upEntry.Mutation.Effect == "Neon" and upEntry.Mutation.Size == nil, "la mutation du colis passe à l'objet amélioré (Neon)")
UnboxService.GetLuck = function()
	return 0
end
place(eve, 2, payload("Rare", "Z1_PotDeNouilles", "Premium", 1, { Size = "Big" }))
local tuto = openPlaced(eve, 2)
local tutoEntry = tuto and dataOf(eve).Items[tuto]
check(tutoEntry ~= nil and tutoEntry.Id == "Z1_PotDeNouilles" and tutoEntry.Mutation == nil, "Pot de nouilles (TutorialOnly) : aucune mutation, même si le colis en portait une")
check(lastReveal(eve).args[8] == nil and lastReveal(eve).args[9] == nil, "UnboxReveal du Pot de nouilles : sans mutation")

section("colis de l'ancienne file (BoxQueue, v5) : dans l'inventaire en v7, la mutation reste")
local data5 = newProfile(5)
data5.BoxQueue = { { Tier = "Standard", Zone = 2, ItemId = "Z2_CanardEnPlastique", Rarity = "Common", ReadyAt = 0, Mutation = { Size = "Big" } } }
for i = 1, 4 do
	addItem(data5, `f{i}`, "Z1_Donut", i, 1)
end
local fay = join("Fay", data5)
advance(1.5)
DisplayService.Unplace(fay, "f1")
advance(2.5)
local queuedUid, queued = next(dataOf(fay).Boxes)
check(queued ~= nil and queued.Spot == nil and queued.Mutation ~= nil and queued.Mutation.Size == "Big", "colis de la file dans l'inventaire : Mutation gardée")
placeStored(fay, 1, queuedUid)
local fq = openPlaced(fay, 1)
check(fq ~= nil and dataOf(fay).Items[fq].Mutation.Size == "Big", "ouvert : l'objet est Big")

summary("scénario stand")
