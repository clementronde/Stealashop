--!strict
-- Hub façon « Steal a … » (L-165 points 1, 2 et 6, vague 50, a160) : cadeau gratuit, noob « invite un ami »,
-- bonus d'amis, étiquettes BB_ZoneLabel des stands et des zones. Lu par HubService (serveur), HubController
-- (client) et Shared/HubZone (calculs communs). Noms de Clément proposés en L-165, pas encore validés (V0).
-- Unités : secondes, studs, degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Bonus d'amis (L-165 point 2, décision de Clément : +15 % d'argent par ami). Par ami Roblox du joueur présent
-- dans le même serveur ; plafond V0 proposé, absent du doc : 4 amis (+60 %). Ajouté aux autres bonus en pour cent
-- (DisplayService.GetIncomeBonus : Premium, index…), donc au revenu des objets exposés.
local PER_FRIEND = 0.15
local MAX_FRIENDS = 4 -- V0

local Hub = {
	-- Tags de Clément (L-165) : la pièce Zone (invisible, sans collision) de chaque modèle du hub.
	RewardsZoneTag = "RewardsZone", -- ENV_Hub_FreeGift : entrer ouvre UI_Rewards
	InviteZoneTag = "InviteZone", -- ENV_Hub_InviteNoob : entrer ouvre l'invitation de Roblox
	-- Enfants des modèles (L-165) : le cadeau qui flotte, le rig du noob.
	GiftName = "Gift",
	NoobName = "Noob",
	-- Billboard des étiquettes (L-165 point 6) : BB_ZoneLabel, son TextLabel Label, attribut texte LabelKey.
	LabelBillboard = "BB_ZoneLabel",
	LabelElement = "Label",
	LabelKeyAttribute = "LabelKey",
	LabelColorAttribute = "LabelColor", -- Color3 sur le LabelPoint (Clément, L-165) : posé sur Label.TextColor3

	-- Zone d'entrée (V0 proposés, absents du doc) : la boîte de la pièce Zone, à l'horizontale ; en hauteur, de
	-- ZoneBelow sous son bas à ZoneAbove au-dessus de son haut (une Zone peut être un disque plat au sol, et le
	-- HumanoidRootPart d'un R15 est à environ 3 studs du sol). On en sort une fois à plus de ExitMargin studs de
	-- la boîte (on ne « rentre » pas en marchant sur le bord). Position relue toutes les Tick s.
	ZoneBelow = 2,
	ZoneAbove = 8,
	ExitMargin = 2,
	Tick = 0.2,

	-- Cadeau (V0 proposés) : il monte et descend de FloatHeight studs autour de sa place (une période de
	-- FloatPeriod s) et tourne de SpinSpeed degrés par seconde sur l'axe Y de son pivot. Côté client seulement.
	Gift = {
		FloatHeight = 0.75,
		FloatPeriod = 2.5,
		SpinSpeed = 60,
	},

	-- Noob (V0 proposé) : Wave au plus une fois toutes les WaveCooldown s, quand un joueur entre dans sa zone.
	Noob = {
		WaveCooldown = 4,
	},

	FriendBonus = {
		PerFriend = PER_FRIEND,
		MaxFriends = MAX_FRIENDS,
		-- Attributs du Player posés par HubService, pour le HUD ou un écran qui voudra l'afficher.
		CountAttribute = "FriendsInServer", -- amis présents, plafond non appliqué
		BonusAttribute = "FriendBonus", -- fraction (0,3 = +30 %), plafond appliqué
	},

	-- Textes anglais des étiquettes, par LabelKey (V0 proposés, absents du doc ; prêts pour la traduction).
	-- Une clé inconnue : le texte de Clément reste, un avertissement en Studio.
	Labels = {
		WeaponShop = "WEAPONS",
		AuraShop = "AURAS",
		RobuxShop = "ROBUX SHOP",
		PawnShop = "PAWN SHOP",
		FreeGift = "FREE!",
		-- L-169 (Q2, Clément) : « +15 % MONEY PER FRIEND » est dans sa sous-ligne SubLabel, gardée telle quelle.
		InviteFriend = "INVITE A FRIEND",
		Wheel = "SPIN THE WHEEL",
		Leaderboard = "LEADERBOARD",
		Rewards = "REWARDS",
	} :: { [string]: string },
}

export type Hub = typeof(Hub)

return DeepFreeze(Hub)
