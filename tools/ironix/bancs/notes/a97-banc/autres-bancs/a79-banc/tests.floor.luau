--!nocheck
-- a79, scénario « floor » (L-097 point 3) sur le faux Roblox et la mise en place du banc a74 (a51, a53, a61) :
--   I. icône des cartes de colis (InventoryController) et des cases de la barre du bas (HotbarController) :
--      ICON_BOX_<Rareté>, sinon ICON_BOX_<Tier>, sinon l'image du Template ;
--   G. colis posé au sol de la boutique (UnboxService, FloorBox) : BOX_<Rareté> pas reteint, sinon
--      BOX_<Tier> teint à la couleur de la rareté.
-- Livrés ici : ICON_BOX_Rare (en plus d'ICON_BOX_Premium du banc a51), BOX_Rare, BOX_Premium et BOX_Standard.

local Rarities = sharedModule("Config/Rarities")
local BOXES = make("Folder", { Name = "Boxes" }, ASSETS)
local MODEL_COLOR = Color3.new(0.11, 0.22, 0.33)
local function boxModel(name, mark)
	local m = make("Model", { Name = name })
	local tint = make("Part", {
		Name = "Tint",
		Anchored = true,
		Size = Vector3.new(1.8, 1.2, 1.8),
		CFrame = CFrame.new(0, 0.6, 0),
		PivotOffset = CFrame.new(0, -0.6, 0),
		Color = MODEL_COLOR,
	}, m)
	m.PrimaryPart = tint
	make("Part", { Name = "Mark_" .. mark, Anchored = true, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 1.3, 0) }, m)
	m.Parent = BOXES
	return m
end
boxModel("BOX_Rare", "Rare")
boxModel("BOX_Premium", "Tier_Premium")
boxModel("BOX_Standard", "Tier_Standard")
make("Decal", { Name = "ICON_BOX_Rare", Texture = "rbxassetid://9300" }, ICONS)

local function markOf(model)
	for _, child in model:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Mark_" then
			return string.sub(child.Name, 6)
		end
	end
	return nil
end

advance(1000)
startServer()
local ada = join("Ada", newProfile())
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local rare = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
local commonPremium = bringBox(ada, "Common", "Z1_Banane", "Premium", 1)
local commonStandard = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(0.3)
check(rare and commonPremium and commonStandard, "trois colis dans l'inventaire")

section("I. Icônes de colis")
local slots = slotsOf()
local sr, sp, ss = slots["Slot_Box_" .. tostring(rare)], slots["Slot_Box_" .. tostring(commonPremium)], slots["Slot_Box_" .. tostring(commonStandard)]
check(sr and slotPart(sr, "Icon").Image == "rbxassetid://9300", "I1 barre : Rare → ICON_BOX_Rare")
check(sp and slotPart(sp, "Icon").Image == "rbxassetid://9100", "I2 barre : Commun en Premium, ICON_BOX_Common pas livrée → ICON_BOX_Premium")
check(ss and slotPart(ss, "Icon").Image == HOTBAR_TEMPLATE_IMAGE, "I3 barre : ni ICON_BOX_Common ni ICON_BOX_Standard → l'image du Template")
check(sr and slotPart(sr, "ItemName").Text == "Premium Box", "I4 barre : le nom reste celui du type (« Premium Box »)")
click(INV.invButton)
click(INV.tabs.Boxes.button)
local cards = cardsOf("Boxes")
local cr, cp, cs = cards["Box_" .. tostring(rare)], cards["Box_" .. tostring(commonPremium)], cards["Box_" .. tostring(commonStandard)]
check(cr and cardPart(cr, "Icon").Image == "rbxassetid://9300", "I5 inventaire : Rare → ICON_BOX_Rare")
check(cp and cardPart(cp, "Icon").Image == "rbxassetid://9100", "I6 inventaire : Commun en Premium → ICON_BOX_Premium")
check(cs and cardPart(cs, "Icon").Image == TEMPLATE_IMAGE.Boxes, "I7 inventaire : rien de livré → l'image du Template")
check(cr and cardPart(cr, "BoxName").Text == "PREMIUM BOX", "I8 inventaire : « PREMIUM BOX » (le type reste la règle de jeu)")
click(INV.invButton)

section("G. Colis posé au sol de la boutique")
local placedRare = placeAt(ada, rare, 6, 20)
local fr = floorBoxOf(ada, rare)
check(placedRare and placedRare.Spot and fr ~= nil and markOf(fr) == "Rare", `G1 FloorBox d'un Rare : BOX_Rare ({fr and markOf(fr)})`)
check(fr and fr:FindFirstChild("Tint", true).Color == MODEL_COLOR, "G2 BOX_Rare pas reteint")
check(fr and fr:GetAttribute("Rarity") == "Rare", "G3 attribut Rarity du FloorBox inchangé")
local placedCommon = placeAt(ada, commonPremium, 12, 20)
local fc = floorBoxOf(ada, commonPremium)
check(placedCommon and placedCommon.Spot and fc ~= nil and markOf(fc) == "Tier_Premium", `G4 Commun sans BOX_Common : BOX_Premium ({fc and markOf(fc)})`)
check(fc and fc:FindFirstChild("Tint", true).Color == Rarities.ById.Common.Color, "G5 repli BOX_Premium teint en Commun")

summary("scénario floor")
