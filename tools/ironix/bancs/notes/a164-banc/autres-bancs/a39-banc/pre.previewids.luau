--!nocheck
-- Vitrine avec des Ids (scénario « previewids ») : Features.RobuxShop reste à false, mais les offres ont
-- leurs Ids, comme le jour où Clément les aura créées sur le Creator Hub avant la MAJ 1 (L-066). Les
-- vraies sources, modifiées en texte avant leur chargement.
local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
local M = "shared/Config/Monetization.luau"
local passes = { DoubleCash = 9001, DoubleTraining = 9002, VIP = 9003, AutoCollect = 9004, FastOpen = 9005, ExtraStands = 9006 }
for key, id in passes do
	replace(M, `\{ Key = "{key}", Id = 0,`, `\{ Key = "{key}", Id = {id},`)
end
local products = { StarterPack = 8001, Cash10 = 8002, Cash60 = 8003, Cash300 = 8004, Revenge = 8005, InstantShutter = 8006, Luck3 = 8007, Shield30 = 8008 }
for key, id in products do
	replace(M, `\{ Key = "{key}", Id = 0,`, `\{ Key = "{key}", Id = {id},`)
end
for index, price in { 19, 39, 59, 99 } do
	replace(M, `\{ Id = 0, Price = {price}, Skip`, `\{ Id = {8100 + index}, Price = {price}, Skip`)
end
