--!strict
-- Codes cadeaux et compte à rebours de la prochaine MAJ (MAJ 0, docs/claude/notes/feuille-de-route-maj.md ;
-- agent a162, vague 50). Lu par CodeService (serveur : codes) et CodeController (client : compte à rebours,
-- messages). Tout est V0 proposé, absent du doc, sauf le 1er code (MAJ 0 : boost ×2 argent 15 min).
--
-- Un code : Code (insensible à la casse et aux espaces autour), Reward, EndsAt facultatif (os.time() UTC
-- après lequel le code est expiré ; absent = sans fin). Chaque code ne se prend qu'une fois par profil
-- (Data.Codes). Récompenses :
--   Boost   ×2 argent pendant Minutes minutes (MonetizationService.AddCashBoost, comme le J5 du calendrier) ;
--   Cash    Amount $ (DataService.AddCash) ;
--   Potion  Count potion(s) PotionId dans l'inventaire des potions (PotionService.AddStock, plafond MaxStock) ;
--   Item    l'objet d'un colis Tier (UnboxService.GiveItem, comme les colis du calendrier), zone = la plus
--           haute des objets du joueur, au moins MinZone ; MinRarity facultatif.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type CodeRewardKind = "Boost" | "Cash" | "Potion" | "Item"
export type CodeReward = {
	Kind: CodeRewardKind,
	Minutes: number?, -- Boost
	Amount: number?, -- Cash
	PotionId: string?, -- Potion (Id de Config/Potions)
	Count: number?, -- Potion (1 par défaut)
	Tier: string?, -- Item : Standard, Premium, Luxe
	MinZone: number?, -- Item
	MinRarity: string?, -- Item
}
export type GiftCode = {
	Code: string,
	Reward: CodeReward,
	EndsAt: number?, -- os.time() UTC de fin (facultatif)
}

local Codes = {
	List = {
		-- MAJ 0 : boost ×2 argent 15 min. Le nom du code et l'absence de date de fin : V0.
		{ Code = "LAUNCH", Reward = { Kind = "Boost", Minutes = 15 } },
	} :: { GiftCode },

	-- V0 : longueur maximale d'un code saisi (au-delà : refusé par Net et par CodeService).
	MaxLength = 20,

	-- V0 : prochaine MAJ, os.time() UTC. 1797696000 = samedi 2026-12-19 16:00 UTC (MAJ 0). 0 ou passée :
	-- le compte à rebours est caché.
	NextUpdateAt = 1797696000,
	-- V0 : texte du compte à rebours (%s = Codes.FormatCountdown).
	CountdownFormat = "NEXT UPDATE IN %s",

	-- Réponses au joueur (remote CodeResult et Notify), en anglais. V0.
	Messages = {
		Redeemed = "Code redeemed!",
		Invalid = "Invalid code",
		AlreadyUsed = "Already used",
		Expired = "Expired",
		Unavailable = "This code can't be redeemed right now. Try again later.",
	},
}

export type Codes = typeof(Codes)

-- Forme comparée : sans espaces autour, en majuscules.
function Codes.Normalize(text: string): string
	return string.upper((string.gsub(text, "^%s*(.-)%s*$", "%1")))
end


-- « 2d 04h », « 3h 12m » sous un jour, « 45m » sous une heure (minute entamée comptée) ; nil si fini.
function Codes.FormatCountdown(seconds: number): string?
	if seconds ~= seconds or seconds <= 0 then
		return nil
	end
	local minutes = math.ceil(seconds / 60)
	local days, hours = minutes // 1440, (minutes % 1440) // 60
	if days > 0 then
		return string.format("%dd %02dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes % 60)
	end
	return string.format("%dm", minutes)
end

return DeepFreeze(Codes)
