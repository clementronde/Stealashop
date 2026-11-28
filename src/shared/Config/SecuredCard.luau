--!strict
-- SecuredCard (a521, 28/11 ; liaison L-405, L-465, L-396) : réglages de la carte « ITEM SECURED! » spectaculaire
-- (Controllers/Escape/SecuredCard, Shared/SecuredTier), du flash de la zone safe à la couleur de la rareté
-- (UiFeelController) et des annonces entre serveurs (Services/CrossServerAnnounce).
-- Interrupteurs : Features.SecuredCardV2, SafeLineFlash, CrossServerAnnounce (et leurs …Dev).
-- Toutes les valeurs sont des V0 : celles de la liaison (chef UI et chef VFX, 25 et 26/11) sont marquées « L-405 » ou
-- « L-465 » ; les autres sont « V0 proposé (Cantin, 28/11) », absentes du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)

return DeepFreeze({
	-- Palier de la carte (Shared/SecuredTier.TierOf) : « Grand » pour une rareté d'ordre GrandOrder ou plus (Mythique,
	-- Secret, Divin), un gros objet ($/s au moins BigIncome) ou un coup de chance ; « Legendary » pour une rareté
	-- d'ordre LegendaryOrder ; « Normal » sinon.
	Tier = {
		LegendaryOrder = 5, -- L-405 : Légendaire
		GrandOrder = 6, -- L-405 : Mythique et plus
		-- V0 proposé (Cantin, 28/11) : nil = Config/Announce.ValueMinIncome (seuil des annonces de valeur, un Mythique de
		-- base) ; un nombre ici le remplace.
		BigIncome = nil :: number?,
	},
	-- Coup de chance (L-405 : « un user qui n'a pas beaucoup de chance et chope un item qui demande beaucoup de
	-- chance ») : objet de cote « 1 in N » au moins MinOneIn (Shared/ItemOdds, mutation comprise), ouvert par un joueur
	-- dont la chance achetée (personnelle × compétence × serveur, Shared/OpenLuck) ne dépasse pas MaxBoughtLuck.
	Lucky = {
		MinOneIn = 10_000, -- V0 proposé (Cantin, 28/11)
		MaxBoughtLuck = 1, -- V0 proposé (Cantin, 28/11) : aucun bonus de chance en cours
	},
	-- L'effet de chaque palier (L-405, valeurs du chef VFX). Size = multiple de la taille de Card.Preview ; Period =
	-- s pour un tour (rotation continue, sans retour à 0) ; Back = RaysBack (nil : caché), tourne en sens inverse.
	Look = {
		Normal = { Rays = { Transparency = 0.55, Size = 1.5, Period = 24 } },
		Legendary = {
			Rays = { Transparency = 0.3, Size = 1.8, Period = 16 },
			Back = { Transparency = 0.6, Size = 2.4, Period = 30 },
			Burst = true,
		},
		Grand = {
			Rays = { Transparency = 0.1, Size = 1.8, Period = 12 },
			Back = { Transparency = 0.45, Size = 2.4, Period = 30 },
			Burst = true,
			Rain = true,
		},
	},
	-- L-405 : Burst de 0,6 à 1,4 fois Preview en 0,35 s, transparence de 0 à 1.
	Burst = { From = 0.6, To = 1.4, Time = 0.35 },
	-- L-405 : environ 20 copies de SecuredFx.Rain.Template qui tombent du haut de l'écran pendant 1,5 s ; écarts V0
	-- proposés (Cantin, 28/11).
	Rain = { Count = 20, Time = 1.5, TimeJitter = 0.3, SizeJitter = 0.35, Spin = 240 },
	RainbowPeriod = 2, -- V0 proposé : s pour faire défiler une fois Config/Rarities.Secret.RainbowColors
	-- Gros paliers (version grise du chef UI, 25/11) : Card.TierScale monte à Grand ; Card.RarityTag montré et qui tremble.
	TierScale = 1.25, -- L-405 : « à monter vers 1,25 au palier grand »
	Tag = {
		Lucky = "LUCKY!", -- L-405 (exemple du chef UI)
		Big = "JACKPOT!", -- V0 proposé (Cantin, 28/11) : gros objet d'une rareté sous Mythique
		Rarity = "%s!", -- L-405 : « MYTHIC! » (DisplayNameUpper de la rareté)
		ShakeAngle = 4, -- V0 proposé : ± degrés autour de la Rotation de Clément
		ShakeRate = 7, -- V0 proposé : battements par seconde
	},
	-- L'objet en 3D dans Card.Preview (copie de Assets/Items/ITM_<ItemId>) : caméra de face, à une distance qui le
	-- montre en entier, qui tourne doucement autour de lui. V0 proposés (Cantin, 28/11).
	Preview = { FieldOfView = 40, Margin = 1.1, Lift = 0.15, Turn = 25 },
	-- L-465 (réglage du chef VFX) : Flash plein (transparence 0) sur 2 images, puis vers 1 en 0,15 s Quad Out, à la
	-- couleur de la rareté ; Card 0,1 s après ; le son d'arrivée 50 à 80 ms après le flash (V0 : 65 ms).
	LineFlash = { Hold = 2 / 60, Time = 0.15, CardDelay = 0.1, SoundDelay = 0.065 },
	-- L-396 (a) : émetteurs de FX_Escape qui ne partent plus quand les feux d'artifice du monde sont allumés
	-- (Features.SecuredFireworks ou SecuredFireworksDev) ; l'anneau au sol reste.
	EscapeSkip = { "Confetti", "Stars" },
	-- L-405 : les plus grosses annonces sur tous les serveurs (MessagingService). Un objet ramené en zone safe d'au moins
	-- MinIncome $/s (nil = Config/Announce.ValueMinIncome), ou un Secret, part aux autres serveurs, au plus un envoi
	-- toutes les Gap s par serveur. Reçu : bannière UI_Announce (Banner) avec sa rareté, son $/s et son poids ; la
	-- variante BigAnnounce avec l'objet en 3D attend Clément.
	Cross = {
		Topic = "SecuredBig", -- V0 proposé
		MinIncome = nil :: number?, -- V0 proposé (Cantin, 28/11) : celui des annonces de valeur
		Secret = true, -- V0 proposé : un Secret part toujours
		Gap = 20, -- V0 proposé : s entre deux envois d'un même serveur (limite de MessagingService : 150 + 60 × joueurs / min)
		ShowGap = 8, -- V0 proposé : s au moins entre deux annonces reçues montrées (beaucoup de serveurs : les autres sautent)
		Text = "{player} got {a} {rarity} {item} worth {value} ({weight})!", -- V0 proposé, sous 70 caractères
		Detail = "On another server", -- V0 proposé
		MaxNameLength = 40, -- V0 proposé : nom du joueur tronqué au-delà (message reçu d'un autre serveur)
	},
})
