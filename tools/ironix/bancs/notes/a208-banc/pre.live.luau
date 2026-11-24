--!nocheck
-- Boutique ouverte (MAJ 1) : Features.RobuxShop = true et des Ids aux offres (vraies sources modifiées en
-- texte avant leur chargement, comme pre.live.luau du banc a39). Gamepasses 9001 à 9006, StarterPack 8001,
-- Cash10 8002, Cash60 8003, Cash180 8009, Cash720 8010, Ouvrir maintenant 8101 à 8104 ; Cash30, Cash300 et
-- les boosts du HUD (Config/Boosts) gardent leur Id à 0. Un remplacement introuvable arrête le banc.
function replaceSource(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
replaceSource("shared/Config/Features.luau", "RobuxShop = false,", "RobuxShop = true,")
do
	local M = "shared/Config/Monetization.luau"
	local ids = {
		DoubleCash = 9001, DoubleTraining = 9002, VIP = 9003, AutoCollect = 9004, FastOpen = 9005, ExtraStands = 9006,
		StarterPack = 8001, Cash10 = 8002, Cash60 = 8003, Cash180 = 8009, Cash720 = 8010,
	}
	for key, id in ids do
		replaceSource(M, `\{ Key = "{key}", Id = 0,`, `\{ Key = "{key}", Id = {id},`)
	end
	for index, price in { 19, 39, 59, 99 } do
		replaceSource(M, `\{ Id = 0, Price = {price}, Skip`, `\{ Id = {8100 + index}, Price = {price}, Skip`)
	end
end
