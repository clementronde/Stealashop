--!strict
-- Leaderboards du hub (vague 50, a161 ; L-165 point 4, demande de Clément du 2026-11-14) : deux grands
-- panneaux ENV_Hub_Leaderboard (tag Leaderboard, attribut texte Stat), remplis par LeaderboardService.
-- Noms proposés par Clément, pas encore livrés (facultatifs au contrat). Toutes les valeurs sont des V0
-- proposés, absents du doc, à régler en jeu.
--
-- Codage des valeurs dans l'OrderedDataStore (entiers seulement, 2^53 au plus sans perte) :
--   Income : un revenu peut dépasser 2^53 (Format va jusqu'à Dc = 1e33) : on range
--            round(log10(1 + revenu) × LogScale), croissant comme le revenu ; relu à 1e-12 près ;
--   Speed  : la Vitesse entraînée (Stats.Speed), arrondie vers le bas.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type StatId = "Income" | "Speed"

export type StatSpec = {
	Title: string, -- texte écrit dans Board.Title (anglais, L-036)
	Store: string, -- nom de l'OrderedDataStore (suffixe DEV ajouté dans le jeu DEV, comme les profils)
	Log: boolean, -- codage logarithmique (voir plus haut)
}

local LOG_SCALE = 1e13 -- V0 : log10(1e36) × 1e13 = 3,6e14 < 2^53

local Leaderboard = {
	Tag = "Leaderboard", -- L-165 : tag des panneaux
	StatAttribute = "Stat", -- L-165 : attribut texte du panneau, Income ou Speed
	Gui = "Board", -- L-165 : SurfaceGui du panneau
	TitleLabel = "Title",
	List = "List",
	Template = "Template", -- L-165 : List.Template invisible (Rank, Avatar, PlayerName, Value)
	RowName = "Row_%02d", -- V0 : nom des copies de Template
	Stats = {
		Income = { Title = "Most money/s", Store = "Leaderboard_Income", Log = true },
		Speed = { Title = "Fastest", Store = "Leaderboard_Speed", Log = false },
	} :: { [string]: StatSpec },
	DevSuffix = "_DEV", -- V0 : ajouté au nom des stores quand les profils sont ceux du jeu DEV
	Rows = 10, -- V0 : lignes affichées par panneau
	WriteInterval = 120, -- V0 : secondes entre deux écritures des joueurs du serveur
	ReadInterval = 120, -- V0 : secondes entre deux lectures du classement
	FirstReadDelay = 5, -- V0 : première lecture peu après le démarrage
	MinBudget = 5, -- V0 : sous ce budget de requêtes DataStore, l'écriture ou la lecture attend le tour suivant
	LogScale = LOG_SCALE,
	ThumbnailSize = "Size150x150", -- Enum.ThumbnailSize (GetUserThumbnailAsync, HeadShot)
}

-- Valeur d'un joueur -> entier rangé dans l'OrderedDataStore (0 pour une valeur invalide ou négative).
function Leaderboard.Encode(stat: string, value: number): number
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	if value == math.huge then
		value = 1e36
	end
	local spec = Leaderboard.Stats[stat]
	if spec and spec.Log then
		return math.round(math.log10(1 + value) * LOG_SCALE)
	end
	return math.min(math.floor(value), 2 ^ 53)
end

-- Entier relu -> valeur à afficher.
function Leaderboard.Decode(stat: string, stored: number): number
	if type(stored) ~= "number" or stored ~= stored or stored <= 0 then
		return 0
	end
	local spec = Leaderboard.Stats[stat]
	if spec and spec.Log then
		return math.max(0, 10 ^ (stored / LOG_SCALE) - 1)
	end
	return stored
end

-- Nom de l'OrderedDataStore d'une stat ; `dev` = profils du jeu DEV (DataService.GetStoreName ≠ StoreName).
function Leaderboard.StoreName(stat: string, dev: boolean): string?
	local spec = Leaderboard.Stats[stat]
	if spec == nil then
		return nil
	end
	return if dev then spec.Store .. Leaderboard.DevSuffix else spec.Store
end

return DeepFreeze(Leaderboard)
