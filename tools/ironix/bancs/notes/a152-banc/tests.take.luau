--!nocheck
-- Scénario « take » du banc a152 (point 1) : invite « Take » (E) sur un objet exposé de SA boutique ; l'objet va
-- dans l'inventaire et dans une case libre de la barre du bas ; barre pleine : inventaire seulement ; inventaire
-- plein : message, rien de perdu ; refus du serveur (loin, autre joueur, tenu par un voleur).
advance(1000)
startServer()
local data = newProfile()
addItem(data, "shown", "Z1_Banane", 1, 1, 1)
addItem(data, "other", "Z3_Smartphone", 2, 3, 2)
addItem(data, "third", "Z1_Banane", 3, 1, 3)
local ada = join("Ada", data)
local bobData = newProfile()
addItem(bobData, "bobshown", "Z1_Banane", 1, 1, 1)
local bob = join("Bob", bobData)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(1)
local Display = clientModule("DisplayController")

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
local prompts = Display.GetOwnerPrompts()
check(prompts.Take.shown == true and prompts.Take.other == true and prompts.Take.third == true, "« Take » allumée sur ses trois objets exposés")
check(prompts.Take.bobshown == nil, "aucune invite « Take » sur l'objet exposé de Bob")
local prompt = takePromptOf(ada, "shown")
check(prompt and prompt.ActionText == "Take" and prompt.HoldDuration == 0 and prompt.MaxActivationDistance == Unbox.PromptDistance, "ActionText « Take », sans maintien, portée Unbox.PromptDistance")
check(prompt and prompt.ObjectText == "Banana", `ObjectText = nom de l'objet ({prompt and prompt.ObjectText})`)
local incomeBefore = DisplayService.GetIncome(ada)

section("trop loin : refusé")
moveTo(ada, refsOfShop(shopOf(ada)).center + Vector3.new(0, 0, 30))
advance(0.3)
trigger(prompt)
check(displayedAt(ada, "shown") == 1, "toujours exposé")
check(logHas("TakeDisplayItem(shown) refusé : trop loin"), "une ligne en Studio")

section("à portée : dans l'inventaire et la barre du bas")
standBySlot(ada, 1)
advance(0.3)
trigger(prompt)
check(displayedAt(ada, "shown") == nil and dataOf(ada).Items.shown ~= nil, "retiré du présentoir, gardé dans Items")
check(invItem(ada, "shown") and invItem(ada, "shown").Slot == nil, "dans l'inventaire")
advance(0.5)
check(hotbarHas("shown"), `case libre de la barre du bas ({slotOrder()})`)
check(#notifies(ada, "removed from its display") == 1, "Notify « Banana removed from its display »")
check(DisplayService.GetIncome(ada) < incomeBefore, `ses $/s s'arrêtent ({incomeBefore} → {DisplayService.GetIncome(ada)})`)
check(Display.GetOwnerPrompts().Take.shown == nil, "l'invite part avec le modèle")
fireAs(ada, "TakeDisplayItem", "shown")
flush()
check(logHas("TakeDisplayItem(shown) ignoré : pas exposé"), "re-envoi : ignoré")

section("autre joueur, objet tenu par un voleur : refusé")
advance(0.3)
fireAs(bob, "TakeDisplayItem", "other")
flush()
check(displayedAt(ada, "other") == 2, "Bob ne prend pas l'objet d'Ada")
check(logHas("TakeDisplayItem(other) refusé : objet absent de son profil"), "une ligne en Studio")
DisplayService.Hold(ada, "other")
standBySlot(ada, 2)
advance(0.3)
fireAs(ada, "TakeDisplayItem", "other")
flush()
check(DisplayService.IsHeld(ada, "other") and dataOf(ada).Display["2"] == "other", "tenu par un voleur : rien ne bouge")
check(#notifies(ada, "being stolen") == 1, "Notify « being stolen »")
DisplayService.Release(ada, "other")
flush()

section("barre pleine : inventaire seulement")
for i = 1, 3 do
	addItem(dataOf(ada), "fill" .. i, "Z1_Banane", nil, 1, 10 + i)
end
InventoryService.Refresh(ada)
advance(0.6)
local free = 0
for _, slot in Hotbar and Hotbar.GetState().Slots or clientModule("HotbarController").GetState().Slots do
	if slot.Kind == "Empty" then
		free += 1
	end
end
check(free == 0, `barre pleine ({slotOrder()})`)
standBySlot(ada, 2)
advance(0.3)
trigger(takePromptOf(ada, "other"))
advance(0.5)
check(displayedAt(ada, "other") == nil and invItem(ada, "other") ~= nil, "repris dans l'inventaire")
check(not hotbarHas("other"), "pas de case : seulement dans l'inventaire")

section("inventaire plein : message, rien de perdu")
local n = 0
for _ in dataOf(ada).Items do
	n += 1
end
local stored = n - 1 -- « third » est exposé
for i = 1, Balance.Display.InventoryMax - stored do
	addItem(dataOf(ada), "pad" .. i, "Z1_Banane", nil, 1, 100 + i)
end
InventoryService.Refresh(ada)
advance(0.3)
check(not DisplayService.HasInventoryRoom(ada), "inventaire plein (30 objets non exposés)")
local before = snapshot(ada)
standBySlot(ada, 3)
advance(0.3)
trigger(takePromptOf(ada, "third"))
check(displayedAt(ada, "third") == 3, "toujours exposé")
check(snapshot(ada) == before, "profil inchangé")
check(#notifies(ada, "Your inventory is full") == 1, "Notify « Your inventory is full… »")

summary("scénario take")
