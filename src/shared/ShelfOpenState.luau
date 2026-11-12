--!strict
-- État d'ouverture d'un colis sur son rayon (liaison L-112, Features.ShelfOpen) : ce que le serveur
-- (StoreHeistService) pose sur le colis et sur l'objet sorti, et la façon de le lire, commun au serveur et au
-- client (ShelfOpenController). Même principe que Shared/WitnessGauge : aucun remote vers le client et aucun
-- flux réseau pendant que la chance monte ; le serveur écrit les attributs une fois, chaque client calcule
-- (heure du serveur : Workspace:GetServerTimeNow des deux côtés). Valeurs : Config/ShelfOpen.
--
-- Posé par le serveur sur le Model du colis du rayon (tag ShelfBox), jamais enregistré dans la place :
--   ShelfOpenState (texte)    absent = fermé ; "Opening" = rabats puis chance qui monte ; "Revealed" = l'objet
--                             est sorti (le colis disparaît alors, l'objet prend sa place).
--   ShelfOpenBy (nombre)      UserId de l'ouvreur.
--   ShelfOpenAt (nombre)      heure du serveur du lancement de l'ouverture.
--   ShelfLuck (nombre ≥ 1)    chance tirée par le serveur (la valeur finale du compteur « ×N LUCK »).
--   ShelfRevealAt (nombre)    heure du serveur de la sortie de l'objet = ShelfOpenAt + revealDelay(ShelfLuck).
--                             Le serveur peut l'avancer (police appelée pendant la montée) : le client
--                             relit l'attribut à chaque changement, la chance affichée s'arrête alors là.
--
-- L'objet sorti : un Model créé par le serveur à la place du colis, tourné comme le ShelfSlot, avec le tag
-- ItemTag et ces attributs (le contenu n'est jamais visible avant ShelfRevealAt : 5.7) :
--   ItemId, Rarity (texte)    rareté finale, crans de chance compris ;
--   MutationSize, MutationEffect (texte, absents sans mutation) ;
--   Income (nombre)           $/s de l'objet, pour BB_Item ;
--   ShelfLuck (nombre)        la chance tirée, recopiée ;
--   ShelfReservedBy (nombre)  UserId de l'ouvreur ;
--   ShelfReservedUntil (nombre) heure du serveur jusqu'à laquelle seul l'ouvreur peut le prendre.

local ShelfOpen = require(script.Parent:WaitForChild("Config"):WaitForChild("ShelfOpen"))

local ShelfOpenState = {}

ShelfOpenState.ItemTag = "ShelfItem"
ShelfOpenState.StateAttribute = "ShelfOpenState"
ShelfOpenState.ByAttribute = "ShelfOpenBy"
ShelfOpenState.AtAttribute = "ShelfOpenAt"
ShelfOpenState.LuckAttribute = "ShelfLuck"
ShelfOpenState.RevealAtAttribute = "ShelfRevealAt"
ShelfOpenState.ReservedByAttribute = "ShelfReservedBy"
ShelfOpenState.ReservedUntilAttribute = "ShelfReservedUntil"

export type State = "Opening" | "Revealed"

-- Nombre de tics pour monter de ×1 à `luck` (0 pour ×1 ou moins).
function ShelfOpenState.ticksTo(luck: number): number
	if not (luck > 1) then
		return 0
	end
	return math.ceil(math.log(luck) / math.log(ShelfOpen.LuckStep) - 1e-9)
end

-- Durée de la montée de la chance, rabats non compris.
function ShelfOpenState.riseTime(luck: number): number
	return ShelfOpenState.ticksTo(luck) * ShelfOpen.LuckTick
end

-- Délai entre le lancement et la sortie de l'objet : rabats, puis montée.
function ShelfOpenState.revealDelay(luck: number): number
	return ShelfOpen.FlapsTime + ShelfOpenState.riseTime(luck)
end

-- Chance affichée à l'instant `now` (heure du serveur) pour une ouverture lancée à `openAt` avec la chance
-- tirée `luck` : ×1 pendant les rabats, puis × LuckStep à chaque tic, sans jamais dépasser `luck`.
function ShelfOpenState.luckAt(openAt: number, luck: number, now: number): number
	local elapsed = now - openAt - ShelfOpen.FlapsTime
	if not (elapsed > 0) or not (luck > 1) then
		return 1
	end
	local ticks = math.floor(elapsed / ShelfOpen.LuckTick)
	return math.min(ShelfOpen.LuckStep ^ ticks, luck)
end

return ShelfOpenState
