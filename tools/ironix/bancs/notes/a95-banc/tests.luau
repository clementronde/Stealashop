--!nocheck
-- Scénario « pawn » : le receleur côté serveur (DEV-034). Offre (objet tenu = dernier obtenu, objets exposés et
-- coffre-fort exclus, prix 120 × $/s, mutation comprise), ventes acceptées et refusées, distance, portage,
-- copie de présentation ignorée, remotes mal formés, contrat.

startServer()
local Formulas = sharedModule("Config/Formulas")
local Mutations = sharedModule("Config/Mutations")
local Pawn = sharedModule("Config/Pawn")
local UI = sharedModule("Contract/UI")
local Models = sharedModule("Contract/Models")
local Definitions = sharedModule("Net/Definitions")
local function price(zone, rarity, mutation)
	return math.floor(120 * Formulas.ItemIncome(zone, rarity) * Mutations.IncomeMultiplier(mutation))
end

section("contrat et valeurs")
check(Pawn.PriceFactor == 120, "Config/Pawn.PriceFactor = 120 (DEV-034)")
local names = {}
for _, def in Definitions.List do
	names[def.Name] = def
end
for _, name in { "PawnAsk", "PawnOffer", "PawnSellHeld", "PawnSellAll", "PawnSold" } do
	check(names[name] ~= nil, `remote {name} déclaré`)
end
local function screenNamed(list, name)
	for _, s in list do
		if s.Name == name then
			return s
		end
	end
	return nil
end
local pawnScreen = screenNamed(UI.Screens, "UI_PawnShop")
check(pawnScreen ~= nil, "Contract/UI : UI_PawnShop")
if pawnScreen then
	local paths = {}
	for _, e in pawnScreen.Elements do
		paths[e.Path] = true
	end
	check(paths["Dialog.Choices.SellHeldButton.Price"] and paths["Dialog.Choices.DealButton.Price"] and paths["Dialog.Choices.NoDealButton.ChoiceLabel"] and not paths["Dialog.Choices.LeaveButton.Price"], "UI_PawnShop : boutons, KeyLabel, ChoiceLabel, Price des choix à prix")
end
check(screenNamed(UI.Billboards, "BB_PawnTalk") ~= nil, "Contract/UI : BB_PawnTalk")
check(Models.PawnShopStall ~= nil and Models.PawnShopStall.Tag == "PawnShop" and table.find(Models.List, Models.PawnShopStall) ~= nil, "Contract/Models : stand taggé PawnShop dans le rapport")

-- Ada : soda (Commun, plus ancien), nouilles (Rare, dernier obtenu), carte holo (Épique, exposée), robot
-- (Épique, au coffre-fort), chips doré (Commun, mutation Gold).
local data = newProfile()
data.Items["ada-soda"] = { Id = "Z1_CanetteDeSoda", Source = "NPC", At = 100, Zone = 1 }
data.Items["ada-chips"] = { Id = "Z1_PaquetDeChips", Source = "NPC", At = 200, Zone = 1, Mutation = { Effect = "Gold" } }
data.Items["ada-noodles"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 300, Zone = 1 }
data.Items["ada-holo"] = { Id = "Z2_CarteHolographique", Source = "NPC", At = 900, Zone = 2 }
data.Display["1"] = "ada-holo"
data.Items["ada-robot"] = { Id = "Z2_RobotJouet", Source = "NPC", At = 950, Zone = 2 }
data.Vault["1"] = "ada-robot"
local ada = join("Ada", data)
local bob = join("Bob", newProfile())
advance(1)
local p = DataService.Get(ada)
check(p.Display["1"] == "ada-holo", "installation : la carte holo est exposée")

section("distance")
fireAs(ada, "PawnAsk")
advance(0.3)
check(#offers(ada) == 0, "loin du stand : PawnAsk ignoré")
onPad(ada, SHOWROOM_PAD)
fireAs(ada, "PawnAsk")
advance(0.3)
check(#offers(ada) == 0, "sur la copie de _SHOWROOM_CLEMENT : ignoré")

section("offre")
onPad(ada)
fireAs(ada, "PawnAsk")
advance(0.3)
local o = lastOffer(ada)
local pSoda, pChips, pNoodles = price(1, "Common"), price(1, "Common", { Effect = "Gold" }), price(1, "Rare")
check(o ~= nil, "sur la plaque : PawnOffer reçu")
if o then
	-- L-117 point 1 (Clément, 2026-11-13) : seulement l'objet en main ; aucun ne se tient en main dans le jeu.
	check(o[1] == "" and o[2] == "" and o[3] == 0, `aucun objet tenu en main (trouvé « {o[1]} »)`)
	check(o[4] == 3, `3 objets vendables (trouvé {o[4]})`)
	check(o[5] == pSoda + pChips + pNoodles, `prix de tout l'inventaire = {pSoda + pChips + pNoodles}, mutation Gold comprise (trouvé {o[5]})`)
	check(pChips > pSoda, "la mutation Gold monte le prix")
end
check(#offers(bob) == 0, "l'offre ne va qu'au joueur qui demande")

section("vendre l'objet tenu")
local cash0 = p.Cash
fireAs(ada, "PawnSellHeld", "ada-soda")
advance(0.6)
local s = lastSold(ada)
check(s and s[1] == 0 and s[2] == 0, "aucun objet en main : PawnSold(0, 0)")
check(p.Items["ada-soda"] ~= nil and p.Cash == cash0, "refus : rien ne change")
fireAs(ada, "PawnSellHeld", "ada-holo")
advance(0.6)
check(p.Items["ada-holo"] ~= nil and p.Display["1"] == "ada-holo" and p.Cash == cash0, "objet exposé : jamais vendu")
fireAs(ada, "PawnSellHeld", "ada-noodles")
advance(0.6)
s = lastSold(ada)
check(s and s[2] == 0 and p.Items["ada-noodles"] ~= nil and p.Cash == cash0, "même le dernier obtenu ne se vend pas « tenu » (L-117)")
o = lastOffer(ada)
check(o and o[1] == "" and o[4] == 3, "nouvelle offre : toujours rien en main, 3 objets")

section("portage")
ada:SetAttribute("Carrying", "Rare")
fireAs(ada, "PawnAsk")
advance(0.3)
o = lastOffer(ada)
check(o and o[1] == "" and o[4] == 3, "pendant un portage : aucun objet tenu, tout l'inventaire reste vendable")
fireAs(ada, "PawnSellHeld", "ada-chips")
advance(0.6)
s = lastSold(ada)
check(s and s[2] == 0 and p.Items["ada-chips"] ~= nil, "pendant un portage : l'objet tenu ne se vend pas")
ada:SetAttribute("Carrying", nil)

section("tout vendre")
local cash1 = p.Cash
fireAs(ada, "PawnSellAll", 5)
advance(0.6)
s = lastSold(ada)
check(s and s[2] == 0 and p.Cash == cash1, "nombre confirmé différent : refusé")
local soldCount = #solds(ada)
fireAs(ada, "PawnSellAll", 0)
advance(0.6)
check(#solds(ada) == soldCount, "PawnSellAll(0) : refusé par Net (forme), pas de réponse")
fireAs(ada, "PawnSellAll", 3)
advance(0.6)
s = lastSold(ada)
check(s and s[1] == pSoda + pChips + pNoodles and s[2] == 3, `vendus : PawnSold({pSoda + pChips + pNoodles}, 3)`)
check(p.Items["ada-soda"] == nil and p.Items["ada-chips"] == nil and p.Items["ada-noodles"] == nil, "inventaire vidé")
local state = ada:GetAttribute("InventoryState")
check(type(state) == "string" and not string.find(state, "ada-noodles", 1, true), "InventoryState remis à jour tout de suite")
check(p.Items["ada-holo"] ~= nil and p.Items["ada-robot"] ~= nil, "objet exposé et coffre-fort gardés")
check(p.Cash == cash1 + pSoda + pChips + pNoodles, "argent crédité")
fireAs(ada, "PawnSellAll", 3)
advance(0.6)
s = lastSold(ada)
check(s and s[2] == 0 and p.Cash == cash1 + pSoda + pChips + pNoodles, "revendre : refusé, pas d'argent en double")
o = lastOffer(ada)
check(o and o[1] == "" and o[4] == 0 and o[5] == 0, "offre vide ensuite")
fireAs(ada, "PawnSellAll", 1)
advance(0.6)
s = lastSold(ada)
check(s and s[2] == 0, "plus rien à vendre : refusé")

section("loin du stand")
p.Items["ada-late"] = { Id = "Z1_CanetteDeSoda", Source = "NPC", At = 1000, Zone = 1 }
moveTo(ada, PAD.Position + Vector3.new(0, 3, Pawn.Reach + 5))
advance(0.6)
local before = #solds(ada)
fireAs(ada, "PawnSellHeld", "ada-late")
advance(0.6)
check(#solds(ada) == before and p.Items["ada-late"] ~= nil, "à plus de Pawn.Reach studs : vente ignorée")

if VERBOSE then
	dumpLog()
end
summary("scénario pawn")
