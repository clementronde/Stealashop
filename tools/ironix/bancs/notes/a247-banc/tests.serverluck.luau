--!nocheck
-- Scénario « serverluck » (a247, vague 72, L-216 point 8, L-229) : chance du serveur en Robux.
-- Ids du banc : ServerLuck2 8201, ServerLuck4 8202, ServerLuck8 8203 (posés en texte avant le chargement).

local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
local M = "shared/Config/Monetization.luau"
replace(M, "local SERVER_LUCK = false", "local SERVER_LUCK = true") -- éteint en V0 : le banc l'allume
local IDS = { ServerLuck2 = 8201, ServerLuck4 = 8202, ServerLuck8 = 8203 }
for key, id in IDS do
	replace(M, `\{ Key = "{key}", Id = 0,`, `\{ Key = "{key}", Id = {id},`)
end

startServer()

local function attr(name)
	return Workspace:GetAttribute(name)
end
local function near(a, b, tolerance)
	return type(a) == "number" and math.abs(a - b) <= (tolerance or 1.5)
end
local function luckNotifies(player)
	return remotes("Notify", function(e)
		return e.to == player and type(e.args[1]) == "string" and string.find(e.args[1], "LUCK", 1, true) ~= nil
	end)
end

section("config et démarrage")
local config = Monetization.ServerLuck
check(config ~= nil and config.Enabled == true, "Monetization.ServerLuck présent, interrupteur à true")
for key, luck in { ServerLuck2 = 2, ServerLuck4 = 4, ServerLuck8 = 8 } do
	local product = Monetization.ProductByKey[key]
	check(product ~= nil and product.Ready and product.Tab == "Boosts" and product.Luck == luck and product.LuckMinutes == 15, `{key} : prêt, onglet Boosts, ×{luck}, 15 min`)
end
check(logHas("[MonetizationService] boutique Robux branchée : 6 gamepass(es) et 14 produit(s) en vente", "PRINT", "server"), "3 produits de plus en vente (11 + 3)")
check(attr("ServerLuck") == nil and attr("ServerLuckEndsAt") == nil and attr("ServerLuckBy") == nil, "aucune chance au démarrage")

local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
advance(1.5)

section("×2 acheté par Ada : tout le serveur, annoncé à tous, idempotent")
local r1 = receipt(ada, IDS.ServerLuck2, "SL-1")
check(settle(r1) == GRANTED, "PurchaseGranted après la sauvegarde")
check(type(dataOf(ada).Purchases["SL-1"]) == "number", "PurchaseId noté chez l'acheteur")
check(attr("ServerLuck") == 2 and attr("ServerLuckBy") == "Ada", "Workspace : ServerLuck = 2, ServerLuckBy = Ada")
local ends1 = attr("ServerLuckEndsAt")
check(near(ends1, serverTime() + 900, 2), "fin dans 15 min (heure du serveur)")
check(#luckNotifies(ada) == 1 and #luckNotifies(bob) == 1, "annonce à tous les joueurs (Ada et Bob)")
local msg = luckNotifies(bob)[1]
check(msg.args[1] == "Ada gave the whole server ×2 LUCK for 15 min!" and msg.args[2] == "Announce", `texte et genre : « {msg.args[1]} » ({tostring(msg.args[2])})`)
check(settle(receipt(ada, IDS.ServerLuck2, "SL-1")) == GRANTED, "reçu rejoué : PurchaseGranted")
check(#luckNotifies(bob) == 1 and near(attr("ServerLuckEndsAt"), ends1, 1), "reçu rejoué : rien de plus (ni annonce, ni temps)")
advance(60, 0.5)
check(attr("ServerLuck") == 2 and near(attr("ServerLuckEndsAt"), ends1, 1), "1 min plus tard : même fin, toujours ×2")

section("×8 de Bob pendant le ×2 : le ×8 tourne, le ×2 attend")
check(settle(receipt(bob, IDS.ServerLuck8, "SL-2")) == GRANTED, "×8 accepté")
check(attr("ServerLuck") == 8 and attr("ServerLuckBy") == "Bob" and near(attr("ServerLuckEndsAt"), serverTime() + 900, 2), "×8 de Bob, 15 min")
check(#luckNotifies(ada) == 2 and luckNotifies(ada)[2].args[1] == "Bob gave the whole server ×8 LUCK for 15 min!", "annonce du ×8")

section("×4 d'Ada pendant le ×8 : en file, annoncé comme tel")
check(settle(receipt(ada, IDS.ServerLuck4, "SL-3")) == GRANTED, "×4 accepté")
check(attr("ServerLuck") == 8, "le ×8 continue")
check(luckNotifies(bob)[3].args[1] == "Ada gave the whole server ×4 LUCK for 15 min! It starts after the current ×8.", `annonce en file : « {luckNotifies(bob)[3].args[1]} »`)

section("fin du ×8 → ×4, puis le ×2 avec son temps restant (14 min)")
advance(901, 0.5)
check(attr("ServerLuck") == 4 and attr("ServerLuckBy") == "Ada" and near(attr("ServerLuckEndsAt"), serverTime() + 899, 3), `×4 d'Ada, ~15 min (fin dans {math.floor((attr("ServerLuckEndsAt") or 0) - serverTime())} s)`)
advance(900, 0.5)
local left = (attr("ServerLuckEndsAt") or 0) - serverTime()
check(attr("ServerLuck") == 2 and attr("ServerLuckBy") == "Ada" and math.abs(left - 840) <= 3, `×2 repris avec ses ~14 min (reste {math.floor(left)} s)`)

section("deux tranches de même facteur : les durées s'ajoutent")
check(settle(receipt(bob, IDS.ServerLuck2, "SL-4")) == GRANTED, "2e ×2 accepté")
local left2 = (attr("ServerLuckEndsAt") or 0) - serverTime()
check(attr("ServerLuck") == 2 and attr("ServerLuckBy") == "Ada" and math.abs(left2 - 1740) <= 4, `fin repoussée de 15 min (reste {math.floor(left2)} s), acheteur affiché : le premier`)
check(luckNotifies(ada)[4].args[1] == "Bob gave the whole server ×2 LUCK for 15 min!", "même facteur : annonce normale")

section("acheteur parti : la chance continue ; fin : attributs retirés")
leave(bob)
advance(30, 0.5)
check(attr("ServerLuck") == 2, "Bob parti : ×2 toujours là")
advance(1720, 0.5)
check(attr("ServerLuck") == nil and attr("ServerLuckEndsAt") == nil and attr("ServerLuckBy") == nil, "tout fini : les 3 attributs retirés")

section("StoreHeistService lit ServerLuck dans les deux déroulés")
local _, count = string.gsub(HEIST_SOURCE, 'GetAttribute%("ServerLuck"%)', "")
check(count == 2, `deux lectures de ServerLuck (startOpening et startReveal) : {count}`)
check(string.find(HEIST_SOURCE, 'luck *= finiteOr(Workspace:GetAttribute("ServerLuck"), 1, 1)', 1, true) ~= nil, "startReveal : facteur ≥ 1, hors de Reveal.EventLuck (toujours compté)")
local revealAt = string.find(HEIST_SOURCE, "local function startReveal", 1, true)
local readAt = string.find(HEIST_SOURCE, 'luck *= finiteOr(Workspace:GetAttribute("ServerLuck")', 1, true)
local forcedAt = revealAt and string.find(HEIST_SOURCE, "local forced = luckOverride", revealAt, true)
check(revealAt ~= nil and readAt ~= nil and forcedAt ~= nil and revealAt < readAt and readAt < forcedAt, "lue avant l'accroche du tuto (qui garde le dernier mot)")

section("client : Shop_Buy à la fin d'un achat fait")
local motion = requireModule(CONTROLLERS:FindFirstChild("UI"):FindFirstChild("Motion"), "client")
local played = {}
motion.PlaySound = function(name)
	table.insert(played, name)
end
startClient(ada)
MarketplaceStub.PromptProductPurchaseFinished:Fire(ada.UserId, IDS.ServerLuck8, true)
flush()
check(#played == 1 and played[1] == "Shop_Buy", "produit acheté : Shop_Buy")
MarketplaceStub.PromptProductPurchaseFinished:Fire(ada.UserId, IDS.ServerLuck8, false)
MarketplaceStub.PromptProductPurchaseFinished:Fire(4242, IDS.ServerLuck8, true)
flush()
check(#played == 1, "fenêtre fermée sans achat, ou achat d'un autre joueur : rien")
MarketplaceStub.PromptGamePassPurchaseFinished:Fire(ada, 9001, true)
flush()
check(#played == 2 and played[2] == "Shop_Buy", "gamepass acheté : Shop_Buy")

summary("scénario serverluck")
