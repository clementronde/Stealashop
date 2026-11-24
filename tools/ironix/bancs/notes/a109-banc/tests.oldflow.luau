--!nocheck
-- F. Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé exact. Contenu et mutation tirés à la
-- mise en rayon, BB_Box complet (catégorie, rareté, mutation), aucun BoxRarity, colis porté fermé avec son
-- contenu ; OpenShelfBox sans effet.

startAll()
local Features = sharedModule("Config/Features")
check(Features.ShelfOpen == false, "F0 (banc) Features.ShelfOpen = false")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()

section("F1 mise en rayon : contenu et mutation tirés")
-- Ancien déroulé : 3 tirages par colis (rareté, taille, effet) ; 0 = taille Tiny, 1 = aucun effet.
local pattern = {}
for _ = 1, 10 do
	for _, v in { 0.1, 0, 1 } do
		table.insert(pattern, v)
	end
end
refillWith(pattern)
local boxRarity, okLabels = 0, true
for _, b in shelfBoxes(STORE_A) do
	if b:GetAttribute("BoxRarity") ~= nil then
		boxRarity += 1
	end
	local l = labelOf(b)
	okLabels = okLabels and l ~= nil and l.Rarity == "COMMON" and l.Category and l.Mutation and l.MutationText == "TINY"
end
check(boxRarity == 0, "F1a aucun attribut BoxRarity")
check(okLabels, "F1b BB_Box complet : catégorie, rareté et mutation (TINY) de l'objet tiré à la mise en rayon")

section("F2 prise du colis fermé : son contenu")
breakStore(A, STORE_A)
local label1 = labelOf(boxAt(STORE_A, 1))
check(grabShelf(A, STORE_A, 1), "F2a le colis fermé se prend par GrabItem")
local payload = Carry.GetPayload(A)
check(payload ~= nil and payload.Kind == "NPCBox" and payload.Rarity == "Common" and Items.ById[payload.ItemId] ~= nil, "F2b portage NPCBox avec son objet")
check(payload ~= nil and payload.Mutation ~= nil and payload.Mutation.Size == "Tiny" and payload.Mutation.Effect == nil, "F2c la mutation tirée à la mise en rayon")
check(payload ~= nil and label1.CategoryText == Items.ById[payload.ItemId].Category, "F2d la catégorie de l'étiquette était celle de l'objet")
local visual = A.Character and A.Character:FindFirstChild("CarryVisual")
local l = visual and labelOf(visual)
check(l ~= nil and l.Category and l.Mutation and l.MutationText == "TINY", "F2e porté : BB_Box complet")
check(logCount("tick :", "WARN", "server") == 0, "F3 aucune erreur du tick")

summary("scénario oldflow")
