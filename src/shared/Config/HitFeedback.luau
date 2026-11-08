--!strict
-- Retours de frappe (DEV-053 ; Partie 1, sections 5.2 et 5.4) : chiffres de dégâts flottants
-- (DamageNumberController) et son du coup sur le camion de l'événement (TruckController ; liaison
-- L-052, point 3). Les fissures, le son du coup sur les vitres et sa montée avec les dégâts sont dans
-- Config/Shatter (DEV-016). C'est le fichier à ouvrir pendant la bêta : tout se règle ici.
--
-- Toutes les valeurs ci-dessous sont des V0 proposés, absents du doc, à régler à l'œil et à
-- l'oreille. Unités : studs, secondes, pixels (taille à l'écran, la même de près comme de loin).

local DeepFreeze = require(script.Parent.DeepFreeze)

local HitFeedback = {
	-- Chiffre de dégâts flottant (5.4) : à chaque coup validé par le serveur (WindowHit et ses
	-- dégâts), sur une vitrine de magasin PNJ, une porte de boutique de joueur ou le camion.
	Damage = {
		-- V0 : modèle proposé à Clément, un BillboardGui rangé dans ReplicatedStorage/Assets/UI (ou un
		-- sous-dossier) avec un TextLabel Label (contrat 2.2). Tant qu'il manque, le code affiche son
		-- propre chiffre, réglé par les valeurs Height à StrokeThickness.
		Template = "BB_Damage",
		Label = "Label",
		Prefix = "-", -- V0 : « -4.5 » ; le nombre lui-même suit Shared/Format, comme les dégâts du HUD
		Height = 44, -- V0 : hauteur du chiffre du code à l'écran, en pixels (lisible sur téléphone)
		Width = 200, -- V0 : largeur de son cadre, en pixels (« -12.4K » y tient)
		Font = Enum.Font.GothamBlack, -- V0 : même police que le « SMASHED! » du code
		Color = Color3.fromRGB(255, 255, 255), -- V0 : chiffre blanc…
		StrokeColor = Color3.fromRGB(27, 27, 36), -- V0 : … cerclé de sombre, lisible sur le verre et le ciel
		StrokeThickness = 2.5, -- V0 : pixels
		Lift = 0.5, -- V0 : il part un demi-stud au-dessus du point de frappe…
		Rise = 3.5, -- V0 : … jaillit de 3,5 studs vers le haut…
		Drift = 1.2, -- V0 : … et de 1,2 stud au plus sur le côté (vu de la caméra), au hasard
		Lifetime = 0.9, -- V0 : durée de vie d'un chiffre
		PopFrom = 0.4, -- V0 : il apparaît à 40 % de sa taille…
		PopTime = 0.15, -- V0 : … et prend sa taille en 0,15 s, avec un petit rebond
		FadeTime = 0.35, -- V0 : il s'efface pendant ses 0,35 dernières secondes
		OtherScale = 0.7, -- V0 : coups des autres joueurs : chiffre à 70 % de la taille…
		OtherMaxDistance = 60, -- V0 : … et seulement si la caméra est à moins de 60 studs du point de frappe
		MaxAlive = 16, -- V0 : au plus 16 chiffres à la fois ; au-delà, le plus ancien disparaît
	},

	-- Son du coup sur le camion (L-052, point 3), cherché par son nom dans SoundsFolder (sous-dossiers
	-- permis), comme les sons de la casse et des marqueurs. Absent : le coup reste muet.
	Truck = {
		-- Nom de Clément (L-071, point 7), à la place de « Truck_Hit », proposé en L-052 (un Sound publié
		-- au nom du groupe).
		HitSound = "SFX_TruckHit",
		SoundsFolder = { "Assets", "Sounds" }, -- depuis ReplicatedStorage : le dossier des sons validé en L-021
		PitchMin = 0.9, -- V0 : hauteur du son à PV pleins…
		PitchMax = 1.3, -- V0 : … et à 0 PV : il monte avec les dégâts, comme celui des vitres
		PitchJitter = 0.03, -- V0 : ± 3 % à chaque coup
		FxRadius = 100, -- V0 : coups des autres joueurs : son seulement si la caméra est plus près que ça
	},
}

export type HitFeedback = typeof(HitFeedback)

return DeepFreeze(HitFeedback)
