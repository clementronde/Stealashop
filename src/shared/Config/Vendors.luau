--!strict
-- Vendeurs des comptoirs du hub (vague 39, liaison L-011 : animations Idle et Wave du vendeur, contrat 3.2
-- de la liaison et Contract/Animations.Vendor). Lu par VendorService (serveur). Toutes les valeurs sont
-- V0 proposées, absentes du doc. Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Vendors = {
	-- Début du nom d'un vendeur : un Model avec Humanoid dans la map (Vendor_Pawn, Vendor_Weapon…).
	NamePrefix = "Vendor_",
	-- V0 : un joueur vivant qui arrive à moins de cette distance (de la tête du vendeur au HumanoidRootPart)
	-- déclenche Wave ; il doit repasser au-delà de WaveDistance + WaveHysteresis pour la redéclencher.
	WaveDistance = 12,
	WaveHysteresis = 3,
	-- V0 : au plus un Wave par vendeur dans ce délai (8 joueurs dans le hub : pas un salut en boucle).
	WaveCooldown = 6,
	-- V0 : distances relues 4 fois par seconde.
	Tick = 0.25,
}

export type Vendors = typeof(Vendors)

return DeepFreeze(Vendors)
