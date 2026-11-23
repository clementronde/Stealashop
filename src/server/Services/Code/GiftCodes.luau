--!strict
-- Liste des codes cadeaux, côté serveur seulement (a274, audit a272 M2) : avant, elle était dans
-- Shared/Config/Codes (ReplicatedStorage), lisible par tout client, et un code préparé pour une MAJ se lisait dès la
-- publication de la place. Lue par CodeService seul ; le client garde dans Config/Codes ce dont il a besoin
-- (MaxLength, messages, compte à rebours). Sous-dossier de Services : pas chargé comme un service par le Loader.
--
-- Un code : Code (insensible à la casse et aux espaces autour), Reward (types et récompenses : Config/Codes),
-- StartsAt facultatif (os.time() UTC avant lequel le code répond « Invalid », comme un code inconnu : préparer
-- le code d'une MAJ à l'avance), EndsAt facultatif (os.time() UTC après lequel le code est expiré ; absent = sans
-- fin).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Config.Codes)

local List: { Codes.GiftCode } = {
	-- MAJ 0 : boost ×2 argent 15 min. Le nom du code et l'absence de date de fin : V0.
	{ Code = "LAUNCH", Reward = { Kind = "Boost", Minutes = 15 } },
}

return table.freeze(List)
