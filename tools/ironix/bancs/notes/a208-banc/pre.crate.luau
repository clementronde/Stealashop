--!nocheck
-- Caisse allumée (après pre.live.luau) : Features.RobuxCrate = true, chances posées, Ids aux trois lots
-- (7001 à 7003). Crate.Ready reste false : contenu pas codé, « Soon » au clic, aucune fenêtre d'achat.
replaceSource("shared/Config/Features.luau", "RobuxCrate = false,", "RobuxCrate = true,")
do
	local M = "shared/Config/Monetization.luau"
	replaceSource(M, "Odds = {} :: { number },", "Odds = { 50, 30, 12.5, 5, 2, 0.5 } :: { number },")
	for index, spec in { { 1, 99 }, { 3, 249 }, { 10, 799 } } do
		replaceSource(M, `\{ Count = {spec[1]}, Price = {spec[2]}, Id = 0 }`, `\{ Count = {spec[1]}, Price = {spec[2]}, Id = {7000 + index} }`)
	end
end
CRATE_ODDS_TEXT = { "50%", "30%", "12.5%", "5%", "2%", "0.5%" }
