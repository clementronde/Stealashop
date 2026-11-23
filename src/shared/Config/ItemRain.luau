--!strict
-- Pluie d'objets (vague 58, a188 ; liaison L-170 Q7, décision de Clément du 2026-11-15 : « une pluie d'objets à la
-- place de la pluie de colis »). Lu par ItemRainService (serveur). Le format (titre, texte de la bannière, durée de
-- 15 min) est dans Config/LiveEvents (Id « ItemRain ») : c'est un événement live comme les autres, lancé par un
-- admin (StartEvent), sans date au planning.
--
-- Toutes les valeurs sont V0 proposées, absentes du doc, à régler en jeu et à faire valider par Clément.
-- Unités : studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ItemRain = {
	-- Id du format dans Config/LiveEvents : la pluie tombe tant que l'attribut LiveEvent du Workspace vaut cet Id.
	EventId = "ItemRain",

	-- Rythme : un objet toutes les DropEvery s, un seul à la fois (jamais de rattrapage : un tour manqué est perdu,
	-- rien n'est créé en rafale). 15 min = 180 objets au plus pour tout le serveur.
	DropEvery = 5,
	-- Plafond d'objets de la pluie encore au sol (jamais ramassés) : au plafond, rien ne tombe.
	MaxOnGround = 10,
	-- Un objet pas ramassé disparaît au bout de Lifetime s (chute comprise). Ramassé puis tombé (coup de batte),
	-- il suit la règle de tout objet au sol : Bat.DroppedLifetime s, puis il disparaît.
	Lifetime = 60,
	-- Zones du couloir où la pluie tombe. L'objet est tiré comme sur un rayon d'un magasin de la zone où il tombe.
	Zones = { 1, 2, 3, 4, 5, 6 },
	-- Pas de pluie la nuit : le couloir est fermé (comme les potions). L'événement continue de tourner.
	PauseAtNight = true,

	-- Chute, jouée par le serveur : l'objet part de FallHeight studs au-dessus de son point et y arrive en FallTime s.
	FallHeight = 40,
	FallTime = 1.5,

	-- Où : sur une rue du couloir (BasePart nommée StreetName, comme les potions ; relevé Studio du 2026-11-11, pas
	-- encore au contrat 10.4), à EdgeMargin studs au moins de ses bords (loin des vitrines), rien au-dessus du point
	-- ni à Clearance studs autour (lampadaire, arche, camion), à MinSpacing studs au moins d'un autre objet de la
	-- pluie encore au sol ; SpawnTries tirages par objet. Jamais en zone safe (hub compris).
	StreetName = "Street",
	EdgeMargin = 15,
	Clearance = 4,
	MinSpacing = 10,
	SpawnTries = 12,

	-- Relevé de l'événement et du rythme.
	TickInterval = 0.5,

	-- Origine écrite dans l'objet porté (NPCItemPayload). Le préfixe « Truck_ » est celui des événements : pas de
	-- magasin, donc pas de vigile de jour (GuardService), comme les objets du camion et de la Fortune Tower.
	StoreId = "Truck_ItemRain",
	SlotId = "Rain",

	-- Textes du jeu (anglais), Notify à tout le serveur. %s = temps restant (« 15:00 »).
	Messages = {
		Started = "ITEM RAIN! Items are falling in the street for %s: grab them!",
		Ended = "The item rain is over.",
	},
}

export type ItemRain = typeof(ItemRain)

return DeepFreeze(ItemRain)
