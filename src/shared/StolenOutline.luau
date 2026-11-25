--!strict
-- StolenOutline (a483, décision de Cantin du 25/11, remplace la règle 6.1 « contour rouge visible par tous ») : qui voit
-- le contour rouge d'un objet volé à un joueur.
--
-- Interrupteur allumé (Features.StolenOutlineVictimOnly partout, StolenOutlineVictimOnlyDev dans le jeu DEV,
-- Config/ProductIds.IsDev) : le serveur ne pose plus de Highlight `StolenOutline` sur l'objet porté (CarryService), il
-- n'est donc répliqué à personne. Seule la victime le voit : son client le pose lui-même (TheftAlertController), sur
-- l'objet porté par chaque voleur que le serveur lui annonce par le remote ciblé TheftAlert (envoyé à elle seule ; un
-- vol chez le bot n'est annoncé à personne : aucun rouge). Rien ne dit à un autre joueur qui vole qui.
-- Interrupteur coupé : la règle 6.1 d'avant, contour posé par le serveur et vu de tous.
--
--   StolenOutline.VictimOnly() -> boolean
--   StolenOutline.LocalName : nom du Highlight posé par le client de la victime (distinct de `StolenOutline` du serveur)
--   StolenOutline.Color : couleur du contour (la même que celle du serveur)

local Features = require(script.Parent.Config.Features) :: any

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD).
local isDev = (function(): boolean
	local module = script.Parent.Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local victimOnly = Features.StolenOutlineVictimOnly == true or (Features.StolenOutlineVictimOnlyDev == true and isDev)

local StolenOutline = {
	LocalName = "StolenOutlineVictim",
	Color = Color3.fromHex("#E8413C"), -- rouge « fermer » de la planche 10.6 (CarryService OUTLINE_COLOR)
}

function StolenOutline.VictimOnly(): boolean
	return victimOnly
end

return StolenOutline
