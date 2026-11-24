--!nocheck
-- Scénario « slots » (L-095 point 6, lignes 22 et 23 de la liste de Clément) : la barre s'allume, une
-- copie du Template par case (Slot_<clé>), 6 cases sur PC ; ordre : outil de casse, batte, puis colis et
-- objets de l'inventaire, du plus récent au plus ancien (objet exposé et colis posé exclus) ; KeyLabel,
-- ItemName, Icon, Income « $X/s » (objets seulement, mutation comprise), couleur de rareté dans Clip et
-- Clip.Glow (outils : fond du modèle) ; SlotCount suivi ; contrat UI.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "low", "Z1_Banane", nil, 1, 1)
addItem(data, "high", "Z3_Smartphone", nil, 3, 2)
data.Items.high.Mutation = { Size = "Big", Effect = "Gold" }
addItem(data, "shown", "Z1_Donut", 1, 1, 3)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local Inventory = clientModule("InventoryController")
local Items = sharedModule("Config/Items")
local Rarities = sharedModule("Config/Rarities")
local Formulas = sharedModule("Config/Formulas")

section("barre allumée, objets du départ")
check(HB.screen.Enabled == true and Hotbar.GetState().Bound, "UI_Hotbar branché et allumé")
check(HB.screen.Bar.Template.Visible == false, "le Template reste caché")
-- Copie a76 (vague 25) : cases vides montrées, plus de décalage ; un nouveau colis prend la 1re case vide.
check(slotOrder() == "Slot_Tool,Slot_Bat,Slot_Item_high,Slot_Item_low,Slot_Empty_5,Slot_Empty_6", `outil, batte, puis les objets (le plus rentable d'abord au départ), cases vides : {slotOrder()}`)

section("colis rapportés : chacun dans la première case vide")
local premium = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
local standard = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(0.3)
check(premium and standard, "deux colis dans l'inventaire")
check(slotOrder() == `Slot_Tool,Slot_Bat,Slot_Item_high,Slot_Item_low,Slot_Box_{premium},Slot_Box_{standard}`, `ordre : {slotOrder()}`)
local slots, n = slotsOf()
check(n == 6 and Hotbar.GetState().Count == 6, "6 cases (SlotCount)")
local tool, bat = slots.Slot_Tool, slots.Slot_Bat
local box, std, high = slots["Slot_Box_" .. premium], slots["Slot_Box_" .. standard], slots.Slot_Item_high
for i, name in { "Slot_Tool", "Slot_Bat", "Slot_Item_high", "Slot_Item_low", `Slot_Box_{premium}`, `Slot_Box_{standard}` } do
	local key = slotPart(slots[name], "KeyLabel")
	check(slots[name].LayoutOrder == i and key.Text == tostring(i) and key.Visible and slots[name].Visible, `case {i} : LayoutOrder, KeyLabel « {key.Text} », visible`)
end
check(slotPart(tool, "ItemName").Text == "Fists" and slotPart(bat, "ItemName").Text == "Bat" and slotPart(box, "ItemName").Text == "Premium Box" and slotPart(std, "ItemName").Text == "Standard Box", "ItemName des outils et des colis")
check(slotPart(high, "ItemName").Text == Items.ById.Z3_Smartphone.DisplayName, `ItemName de l'objet ({slotPart(high, "ItemName").Text})`)
check(slotPart(tool, "Icon").Image == "rbxassetid://9201" and slotPart(bat, "Icon").Image == HOTBAR_TEMPLATE_IMAGE, "ICON_TOOL_Fists ; ICON_TOOL_Bat pas livrée : l'image du Template")
check(slotPart(box, "Icon").Image == "rbxassetid://9100" and slotPart(std, "Icon").Image == HOTBAR_TEMPLATE_IMAGE, "ICON_BOX_Premium ; Standard pas livrée : l'image du Template")
check(slotPart(high, "Icon").Image == ICON_TEXTURE.Z3_Smartphone, "ICON_<ItemId> sur l'objet")

section("Income : objets seulement, mutation comprise")
local def = Items.ById.Z3_Smartphone
local expected = Formulas.ItemIncome(def.Zone or 3, def.Rarity) * Mutations.IncomeMultiplier({ Size = "Big", Effect = "Gold" })
local entry
for _, e in Inventory.GetInventory().Items do
	if e.Uid == "high" then
		entry = e
	end
end
check(entry and math.abs(entry.Income - expected) < 1e-6, `revenu de l'état = Formulas.ItemIncome × mutation ({entry and entry.Income} / {expected})`)
check(slotPart(high, "Income").Visible and slotPart(high, "Income").Text == Format.money(expected) .. "/s", `Income « {slotPart(high, "Income").Text} »`)
check(not slotPart(tool, "Income").Visible and not slotPart(bat, "Income").Visible and not slotPart(box, "Income").Visible, "pas d'Income sur les outils ni les colis")

section("couleur de rareté")
local rare = Rarities.ById.Rare.Color
local common = Rarities.ById.Common.Color
check(near(slotPart(high, "Clip").BackgroundColor3, Color3.new(rare.R * 0.55, rare.G * 0.55, rare.B * 0.55)) and near(slotPart(high, "Glow").ImageColor3, rare), "objet Rare : Clip assombri de 45 %, Glow à la couleur")
check(near(slotPart(std, "Clip").BackgroundColor3, Color3.new(common.R * 0.55, common.G * 0.55, common.B * 0.55)) and near(slotPart(box, "Glow").ImageColor3, rare), "colis : couleur de sa rareté")
check(near(slotPart(tool, "Clip").BackgroundColor3, TEMPLATE_CLIP) and near(slotPart(bat, "Glow").ImageColor3, TEMPLATE_GLOW), "outils : fond du modèle")
check(not slotPart(tool, "Equipped").Visible and not slotPart(high, "Equipped").Visible, "rien en main : pas d'Equipped")

section("un colis de plus : barre pleine, il reste dans l'inventaire")
local third = bringBox(ada, "Epic", "Z3_PcGamer", "Luxe", 3)
advance(0.3)
check(slotOrder() == `Slot_Tool,Slot_Bat,Slot_Item_high,Slot_Item_low,Slot_Box_{premium},Slot_Box_{standard}`, `rien ne bouge : {slotOrder()}`)
check(slots.Slot_Item_low.Parent ~= nil, "aucune case détruite")
placeAt(ada, premium, 6, 20)
advance(0.5)
check(slotOrder() == `Slot_Tool,Slot_Bat,Slot_Item_high,Slot_Item_low,Slot_Empty_5,Slot_Box_{standard}` and select(2, slotsOf()) == 6, `colis posé au sol : sa case est vide, rien ne bouge : {slotOrder()}`)

section("SlotCount suivi")
HB.screen.Bar:SetAttribute("SlotCount", 4)
advance(0.1)
check(slotOrder() == `Slot_Tool,Slot_Bat,Slot_Item_high,Slot_Item_low`, `SlotCount = 4 : {slotOrder()}`)
HB.screen.Bar:SetAttribute("SlotCount", 6)
advance(0.1)
check(select(2, slotsOf()) == 6, "SlotCount = 6 : 6 cases")

section("contrat UI")
local spec
for _, screen in UIContract.Screens do
	if screen.Name == "UI_Hotbar" then
		spec = screen
	end
end
local paths = {}
for _, element in (spec and spec.Elements or {}) do
	paths[element.Path] = element
end
check(spec and spec.Class == "ScreenGui", "UI_Hotbar au contrat") -- fusion vague 24 : a75 ajoute UI_Toast et UI_Escape après lui
check(paths.Bar and paths["Bar.Template"] and paths["Bar.Template"].Template == true and paths["Bar.Template"].Class == "GuiButton", "Bar et Bar.Template (bouton modèle)")
local all = true
for _, p in { "Clip", "Clip.Glow", "Icon", "KeyLabel", "ItemName", "Income", "Equipped", "HoverOutline" } do
	all = all and paths["Bar.Template." .. p] ~= nil and Find.path(HB.screen, "Bar.Template." .. p) ~= nil
end
check(all, "les 8 éléments du Template, trouvés dans l'écran du relevé")

summary("scénario slots")
