--!strict
-- Cabine d'essayage (a411, vague GC6 ; liaison L-113, mécanique principale vue par Clément le 2026-11-12 ; feuille de
-- route MAJ 4). Derrière Features.FittingRoom. Lu par DisguiseService (serveur, qui décide tout) et DisguiseController
-- (client : invites, écran de choix de zone, chrono).
--
-- Règle (L-113) : la tuile FittingRoom de l'arbre (Config/SkillTree) débloque la cabine de sa boutique. Le joueur y
-- choisit une zone ouverte (zone n avec n − 1 renaissances) et apparaît dans cette zone avec l'apparence d'un passant,
-- sans nom, Duration s au plus ; il redevient joueur s'il quitte la zone. Déguisé, il dénonce un magasin (la police
-- NPC_Police rattrape les voleurs qui s'y trouvent) ; dès qu'il prend un objet, il redevient joueur et le vigile le
-- poursuit ; un coup de batte le démasque.
-- Propositions a à f de L-113, encore ouvertes : la V0 la plus simple qui tient est codée et marquée ci-dessous.
-- Tout ce qui est marqué « V0 proposé (Cantin, 23/11) » est absent des docs et à valider par Clément.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Disguise = {
	SkillId = "FittingRoom", -- compétence de Config/SkillTree (niveau 1 = cabine débloquée)

	Duration = 60, -- L-113 point 2 : s de déguisement au plus
	-- L-113 point 1, L-328 point 2 (Clément, 24/11 : zone 1 à 0 renaissance, zone 2 à 1) : zone n ouverte avec
	-- n − ZoneRebirthOffset renaissances ; la suite (zone N à N − 1) : V0 proposé (Cantin, 24/11).
	ZoneRebirthOffset = 1,
	-- (a) Clément, 24/11 (L-328 point 1) : s de recharge entre deux déguisements, comptées de la fin du déguisement.
	Cooldown = 120,
	-- (b) Clément, 24/11 (L-328 point 2) : autant de déguisés qu'on veut par zone (true : un seul à la fois, l'ancienne V0).
	OnePerZone = false,
	-- (c) V0 proposé (Cantin, 23/11) : déguisé, aucun outil en main (ni casse de vitrine, ni batte) ; prendre un objet,
	-- avant comme après la dénonciation, le démasque (point 4 de L-113) au lieu d'être refusé.
	NoTools = true,
	-- (d) V0 proposé (Cantin, 23/11) : la dénonciation demande de fixer le magasin DenounceTime s, avec le « ? » des
	-- témoins (BB_Witness) au-dessus du faux passant, puis le « ! » pendant CallShowTime s.
	DenounceTime = 2,
	CallShowTime = 2,
	DenounceRange = 45, -- V0 proposé (Cantin, 23/11) : studs au plus, à plat, jusqu'à la vitrine du magasin dénoncé
	-- V0 proposé (Cantin, 23/11) : « en regardant le magasin » = la vitrine est devant lui (produit scalaire minimal
	-- entre son regard et la direction de la vitrine, à plat ; 0 = le demi-plan devant lui).
	DenounceFacing = 0,
	-- (f) V0 proposé (Cantin, 23/11) : une dénonciation par déguisement ; si personne ne braque le magasin, elle ne fait
	-- rien et elle est quand même dépensée (la recharge (a) court de toute façon à la fin du déguisement).
	CallsPerDisguise = 1,
	-- L-328 point 7 (Clément, 24/11), derrière Features.DenounceRecover : le voleur attrapé par un policier de la
	-- dénonciation (renvoyé à sa base, la « prison ») donne l'objet qu'il portait au joueur qui l'a dénoncé, au lieu de
	-- le lâcher ou de le renvoyer au rayon. V0 proposé (Cantin, 24/11) : dans la main (sur la tête, comme un objet
	-- ramassé au sol ; sa réserve à l'entrée de la zone safe), où que soit le dénonciateur, tant que ce policier court.
	-- RecoverCatchRange : studs au plus entre le policier et le voleur à la capture (pour reconnaître ce policier).
	RecoverCatchRange = 12,
	-- (e) le petit défaut visible : aucun code. Le faux passant garde la silhouette et les animations du joueur et ne
	-- suit pas le circuit des témoins.

	-- V0 proposé (Cantin, 23/11) : qui est « un voleur dans ce magasin » au moment de la dénonciation. Un autre joueur,
	-- vivant, hors zone safe, qui est dans le volume Bounds du magasin (agrandi de ThiefMargin studs), ou qui a frappé
	-- sa vitrine il y a ThiefMemory s au plus, ou qui porte un objet de ce magasin à ThiefCarryRange studs au plus de
	-- sa vitrine.
	ThiefMargin = 6,
	ThiefMemory = 10,
	ThiefCarryRange = 60,

	-- V0 proposé (Cantin, 23/11) : « il quitte la zone » = le magasin PNJ le plus proche n'est plus de sa zone, ou il
	-- est en zone safe, pendant LeaveGrace s de suite.
	LeaveGrace = 1.5,
	-- V0 proposé (Cantin, 23/11) : tolérances du maintien de la dénonciation (s) : avance acceptée sur DenounceTime,
	-- et temps au bout duquel un maintien ouvert est oublié.
	HoldTolerance = 0.25,
	HoldExpiry = 3,
	Step = 0.25, -- s entre deux contrôles du serveur (chrono, zone, outil en main)

	-- La cabine (modèle de Clément, facultatif) : un enfant nommé ModelName dans la parcelle. Le joueur doit être à
	-- Range studs au plus de son pivot. Sans modèle (repli) : dans le volume Bounds de sa boutique agrandi de
	-- BoundsMargin studs (l'invite V0 est posée sur sa porte), ou à FallbackRange studs du pivot de la parcelle si
	-- elle n'a pas de Bounds. V0 proposé (Cantin, 23/11).
	Cabin = {
		ModelName = "FittingRoom",
		-- L-326 : pièce de la cabine qui porte l'invite (invisible, au milieu de l'ouverture) ; absente : sa 1re pièce.
		PromptPart = "PromptPart",
		Range = 14,
		BoundsMargin = 12,
		FallbackRange = 60,
	},

	-- Attributs du Player, posés par le serveur seul (lus par DisguiseController et par les autres clients).
	Attributes = {
		Zone = "Disguised", -- zone du déguisement (1 à 6) ; absent = pas déguisé
		Until = "DisguiseUntil", -- heure serveur de la fin du déguisement
		ReadyAt = "DisguiseReadyAt", -- heure serveur de la fin de la recharge (a)
		CanCall = "DisguiseCanCall", -- true tant qu'une dénonciation reste
	},

	-- Apparence : celle d'un témoin de la zone (NPC_Witness_Z<n>_0<k>, L-111). Si son Humanoid porte un
	-- HumanoidDescription, ses vêtements, accessoires et couleurs sont appliqués ; sinon ses Shirt, Pants, ShirtGraphic,
	-- accessoires et couleurs de peau sont copiés. Le corps du joueur (formes, tête) n'est pas remplacé. Zone sans
	-- témoin : les couleurs de repli ci-dessous, sans vêtement (V0 proposé, Cantin, 23/11).
	FallbackSkin = Color3.fromRGB(234, 184, 146),
	FallbackTorso = Color3.fromRGB(110, 110, 120),
	FallbackLegs = Color3.fromRGB(60, 70, 100),
	ExtraAttribute = "DisguisePart", -- attribut des vêtements et accessoires copiés du témoin (retirés à la fin)

	-- Textes (Notify et invites), en anglais. V0 : à valider par Clément.
	Messages = {
		NeedSkill = "Unlock the Fitting Room in the skill tree first.",
		NotAtCabin = "Go to the fitting room of your shop.",
		ZoneLocked = "Zone %d opens at Rebirth %d.",
		Cooldown = "Fitting room ready in %d:%02d.",
		Night = "The street is closed at night.",
		Busy = "You can't disguise right now.",
		ZoneTaken = "Someone is already undercover in this zone.",
		NoSpot = "This zone has no street to appear in yet.",
		Started = "You are undercover for %d s. Call the police on a store being robbed!",
		Ended = "Your disguise is over.",
		LeftZone = "You left the zone: your disguise is over.",
		Unmasked = "You have been unmasked!",
		UnmaskedBy = "You unmasked %s!",
		Took = "You took an item: your disguise is over. Run!",
		NoTools = "No tools while undercover.",
		TooFar = "Get closer to the store.",
		NotFacing = "Look at the store to call the police.",
		NoCall = "You already called the police.",
		Called = "Police called on %d thief(s)!",
		NobodyThere = "Nobody is robbing this store. Your call is wasted.",
		AlreadyChased = "The police are already after them.",
		Denounced = "A passer-by called the police on you! Run!",
		Recovered = "The police caught %s. The item is yours: bring it home!", -- L-328 point 7, V0
	},

	-- Client (DisguiseController). Écrans de Clément facultatifs (Contract/UI) ; sans eux, le repli construit par le code.
	Client = {
		Screen = "UI_FittingRoom", -- choix de la zone : ZoneList.Template (bouton, ZoneName, Locked), CloseButton
		TimerScreen = "UI_Disguise", -- chrono du déguisement : Timer (TextLabel)
		CabinPrompt = "Fitting Room",
		CabinAction = "Disguise",
		CabinActionCooldown = "Ready in %d:%02d",
		CabinPromptRange = 10, -- V0 : portée de l'invite de la cabine (studs)
		DenouncePrompt = "Call the police",
		ZoneText = "ZONE %d · %s",
		ZoneLockedText = "ZONE %d · REBIRTH %d",
		UnlockText = "UNLOCK · %s",
		TimerText = "UNDERCOVER %d:%02d",
		Title = "FITTING ROOM",
		Refresh = 0.25, -- s entre deux mises à jour (invites, chrono, masque des autres déguisés)
	},
}

export type Disguise = typeof(Disguise)

return DeepFreeze(Disguise)
