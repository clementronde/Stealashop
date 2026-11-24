--!nocheck
-- Scénario « client » du banc a118 (vague 34, L-127 de Clément) : vrais InventoryController, HotbarController et
-- UnboxController.
--   Point 4 : objet sous antivol de l'inventaire → voile AntiTheft sur sa carte (LockLabel = durée de l'antivol de
--   sa rareté) et sur sa case de la barre (LockLabel reste caché), PLACE montré et cliquable (mode pose) ; posé au
--   sol → chaînes et cadenas de FX_AntiTheft (AntiTheftChains sous l'objet : 2 boucles, maillons alternés, tout
--   ancré sans collision ni requête, cadenas devant la face avant), posés une fois ; « UNLOCKED! » → le cadenas
--   saute de 0,3 × k en 0,12 s, tout s'efface en 0,25 s puis est détruit.
--   Point 3 : CardAlert (Items, Boxes) et SlotAlert allumés quand la carte demande une action, Pulse qui bat
--   (1 → 1,15 → 1 en 0,8 s), éteints (Scale 1) quand l'action est faite.

advance(1000)
startServer()
local data = newProfile()
data.Items.locked = { Id = "Z3_TeleGeante", Source = "NPC", At = 0, Zone = 3, AntiTheft = true }
addItem(data, "free", "Z1_Banane", nil, 1, 1)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
addAlertParts()
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local Hotbar = clientModule("HotbarController")
local Unbox = clientModule("UnboxController")
local ShelfOpen = sharedModule("Config/ShelfOpen")
local ItemsConfig = sharedModule("Config/Items")

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(invItem(ada, "locked") and invItem(ada, "locked").AntiTheft == true, "objet sous antivol dans l'état de l'inventaire")

local function card(sectionName, key)
	return (cardsOf(sectionName))[key]
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end

section("point 4 : voile AntiTheft de la carte, LockLabel, PLACE")
Inventory.Open()
advance(0.2)
local lockedCard = card("Items", "Item_locked")
local freeCard = card("Items", "Item_free")
check(lockedCard ~= nil and freeCard ~= nil, "cartes des deux objets")
local seconds = ShelfOpen.AntiTheft[ItemsConfig.ById.Z3_TeleGeante.Rarity]
local lockText = cardPart(lockedCard, "AntiTheft.LockLabel").Text
check(shown(cardPart(lockedCard, "AntiTheft")), "AntiTheft montré sur l'objet sous antivol")
check(lockText == string.format("%d:%02d", seconds // 60, seconds % 60), `LockLabel = durée de l'antivol ({lockText})`)
check(not shown(cardPart(freeCard, "AntiTheft")), "pas de voile sur un objet libre")
check(shown(cardPart(lockedCard, "PlaceButton")), "PLACE reste montré")
check(INV.templates.Items:FindFirstChild("AntiTheft").Visible == false, "le Template garde son voile caché")

section("point 3 : CardAlert allumés, Pulse qui bat")
check(shown(cardPart(lockedCard, "CardAlert")), "objet sous antivol (à poser) : CardAlert")
check(shown(cardPart(freeCard, "CardAlert")), "objet libre, présentoir libre (à exposer) : CardAlert")
local pulse = cardPart(lockedCard, "CardAlert.Pulse")
local lo, hi = math.huge, -math.huge
for _ = 1, 30 do
	advance(1 / 30)
	lo = math.min(lo, pulse.Scale)
	hi = math.max(hi, pulse.Scale)
end
check(hi > 1.14 and hi <= 1.15 + 1e-6 and lo < 1.02 and lo >= 1 - 1e-6, `Pulse entre 1 et 1,15 sur une période ({lo} à {hi})`)
advance(0.8)
local before = pulse.Scale
advance(0.8)
check(near(before, pulse.Scale, 0.02), "période de 0,8 s")

section("points 3 et 4 : la case de la barre du bas")
local slots = slotsOf()
local lockedSlot = slots.Slot_Item_locked
local freeSlot = slots.Slot_Item_free
check(lockedSlot ~= nil and freeSlot ~= nil, "cases des deux objets")
check(shown(slotPart(lockedSlot, "AntiTheft")) and not shown(slotPart(freeSlot, "AntiTheft")), "AntiTheft sur la case de l'objet sous antivol seulement")
check(not shown(slotPart(lockedSlot, "AntiTheft.LockLabel")), "LockLabel reste caché dans la barre")
check(shown(slotPart(lockedSlot, "SlotAlert")) and shown(slotPart(freeSlot, "SlotAlert")), "SlotAlert allumés")
check(not shown(slotPart(slots.Slot_Tool, "SlotAlert")), "pas de pastille sur l'outil")
local found = nil
for _, s in Hotbar.GetState().Slots do
	if s.Uid == "locked" then
		found = s
	end
end
check(found and found.AntiTheft == true and found.Alert == true, "GetState : AntiTheft et Alert")
local slotPulse = slotPart(freeSlot, "SlotAlert.Pulse")
local moved = false
for _ = 1, 12 do
	advance(1 / 30)
	if slotPulse.Scale > 1.01 then
		moved = true
	end
end
check(moved, "Pulse de la case qui bat")

section("pastille éteinte quand l'action est faite (présentoirs pleins, objet exposé)")
local slotsUnlocked = ada:GetAttribute("DisplaySlotsUnlocked")
ada:SetAttribute("DisplaySlotsUnlocked", 0) -- plus de présentoir libre
advance(0.2)
check(not shown(slotPart(slotsOf().Slot_Item_free, "SlotAlert")), "plus de présentoir libre : SlotAlert de l'objet libre éteint")
check(slotPart(slotsOf().Slot_Item_free, "SlotAlert.Pulse").Scale == 1, "Pulse remis à 1")
check(shown(slotPart(slotsOf().Slot_Item_locked, "SlotAlert")), "l'objet sous antivol reste à poser")
ada:SetAttribute("DisplaySlotsUnlocked", slotsUnlocked)
advance(0.2)
check(shown(slotPart(slotsOf().Slot_Item_free, "SlotAlert")), "présentoir libre de nouveau : rallumé")
click(cardPart(card("Items", "Item_free"), "PlaceButton"))
advance(0.6)
local displayed = card("Items", "Item_free")
check(displayed ~= nil and shown(cardPart(displayed, "DisplayedBadge")), "objet libre exposé (PlaceItemAuto)")
check(displayed ~= nil and not shown(cardPart(displayed, "CardAlert")) and cardPart(displayed, "CardAlert.Pulse").Scale == 1, "CardAlert éteint, Scale 1")
Inventory.Close()
advance(0.5)

section("colis : à poser, puis posé (éteint), puis prêt (allumé)")
local boxUid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(0.3)
Inventory.Open()
Inventory.SelectTab("Boxes")
advance(0.3)
local boxCard = card("Boxes", "Box_" .. tostring(boxUid))
check(boxUid ~= nil and boxCard ~= nil and shown(cardPart(boxCard, "CardAlert")), "colis de l'inventaire : CardAlert")
local boxSlot = slotsOf()["Slot_Box_" .. tostring(boxUid)]
check(boxSlot ~= nil and shown(slotPart(boxSlot, "SlotAlert")), "colis de l'inventaire : SlotAlert")
Inventory.Close()
advance(0.5)
placeAt(ada, boxUid, 6, 6)
advance(0.3)
Inventory.Open()
Inventory.SelectTab("Boxes")
advance(0.3)
boxCard = card("Boxes", "Box_" .. tostring(boxUid))
check(boxCard ~= nil and shown(cardPart(boxCard, "TimerPill")) and not shown(cardPart(boxCard, "CardAlert")), "posé, en attente : éteint")
local box = invBox(ada, boxUid)
advance(math.max(0, ((box and box.ReadyAt) or 0) - serverTime()) + 0.5)
boxCard = card("Boxes", "Box_" .. tostring(boxUid))
check(boxCard ~= nil and shown(cardPart(boxCard, "ReadyPill")) and shown(cardPart(boxCard, "CardAlert")), "prêt (à ouvrir) : rallumé")
Inventory.Close()
advance(0.5)

section("point 4 : PLACE de l'objet sous antivol, mode pose")
Inventory.Open()
Inventory.SelectTab("Items")
advance(0.2)
click(cardPart(card("Items", "Item_locked"), "PlaceButton"))
advance(0.1)
check(Inventory.GetState().Placing == "locked", "PLACE cliquable : mode pose de l'objet")
Inventory.StopPlacing()
advance(0.5)

section("point 4 : chaînes et cadenas posés au sol")
local entry = placeItemAt(ada, "locked", -6, 0)
advance(0.3)
check(entry ~= nil and entry.Spot ~= nil, "objet posé au sol (PlaceBox)")
check(slotsOf().Slot_Item_locked == nil, "au sol : plus de case dans la barre")
local model = floorItemOf(ada, "locked")
local chains = model and model:FindFirstChild("AntiTheftChains")
check(chains ~= nil, "AntiTheftChains sous l'objet")
local view = model and Unbox.GetFloorView(model)
check(view ~= nil and view.Chains == true, "GetFloorView : Chains")
check(model:FindFirstChild("BB_AntiTheft", true) ~= nil, "BB_AntiTheft reste au-dessus")
local loops, bad = { 0, 0 }, {}
for _, d in chains:GetDescendants() do
	if d:IsA("BasePart") then
		if not (d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch) then
			table.insert(bad, d.Name)
		end
		local loop = tonumber(string.match(d.Name, "^Link_(%d)_"))
		if loop then
			loops[loop] += 1
		end
	end
end
check(loops[1] >= 8 and loops[2] >= 8 and loops[1] % 2 == 0 and loops[2] % 2 == 0, `deux boucles, maillons en nombre pair ({loops[1]}, {loops[2]})`)
check(#bad == 0, `tout ancré, sans collision, requête ni contact ({table.concat(bad, ", ")})`)
local padlock = chains:FindFirstChild("Padlock")
check(padlock ~= nil, "cadenas")
local link = chains:FindFirstChild("Link_1_01")
local k = link.Size.Z / FX_KIT.Link.Size.Z
check(k > 0 and near(link.Size.X / FX_KIT.Link.Size.X, k), `maillons à l'échelle k = {string.format("%.3f", k)}`)
local link2 = chains:FindFirstChild("Link_1_02")
check(near(math.abs(link.CFrame.XVector:Dot(link2.CFrame.XVector)), 0, 1e-3), "maillons alternés (à plat, puis de chant)")
-- Boîte de l'objet (pièces visibles) dans le repère de son pivot : cadenas devant la face avant (−Z).
local pivot = model:GetPivot()
local minZ = math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 and not d:IsDescendantOf(chains) then
		minZ = math.min(minZ, pivot:PointToObjectSpace(d.Position).Z - d.Size.Z / 2)
	end
end
local padlockLocal = pivot:PointToObjectSpace(padlock:GetPivot().Position)
check(padlockLocal.Z < minZ, `cadenas devant la face avant ({string.format("%.2f", padlockLocal.Z)} < {string.format("%.2f", minZ)})`)
advance(3)
check(model:FindFirstChild("AntiTheftChains") == chains and #chains:GetChildren() == loops[1] + loops[2] + 1, "posées une fois : mêmes chaînes après 3 s")

section("point 4 : UNLOCKED! : saut du cadenas, effacement, destruction")
local unlockAt = model:GetAttribute("UnlockAt")
advance(math.max(0, unlockAt - serverTime() - 0.3))
check(chains.Parent == model and Unbox.GetFloorView(model).Chains == true, "encore sous antivol : chaînes là")
local y0 = padlock:GetPivot().Position.Y
local frames = 0
while Unbox.GetFloorView(model).TimeText ~= "UNLOCKED!" and frames < 30 do
	advance(1 / 30)
	frames += 1
end
check(Unbox.GetFloorView(model).TimeText == "UNLOCKED!", "UNLOCKED!")
check(Unbox.GetFloorView(model).Chains == false and chains.Parent == model, "chaînes en train de partir")
advance(0.13)
local lift = padlock:GetPivot().Position.Y - y0
check(near(lift, 0.3 * k, 0.02), `le cadenas a sauté de 0,3 × k ({string.format("%.3f", lift)} pour {string.format("%.3f", 0.3 * k)})`)
advance(0.12)
local t = chains:FindFirstChild("Link_2_01").Transparency
check(t > 0.2 and t < 0.9, `effacement en cours ({string.format("%.2f", t)})`)
advance(0.2)
check(chains.Parent == nil and model:FindFirstChild("AntiTheftChains") == nil, "détruites après 0,12 + 0,25 s")
check(model:FindFirstChild("BB_AntiTheft", true) ~= nil and Unbox.GetFloorView(model).OwnerPrompt == true, "BB_AntiTheft et l'invite Display restent")

summary("scénario client")
