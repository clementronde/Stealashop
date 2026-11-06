--!strict
-- Contrat d'animations (doc, section 2.4 ; liaison, section 3.2) : 20 animations.
-- Le code cherche chaque objet Animation par son nom, jamais par un ID.
--
-- Où : joueur dans ReplicatedStorage/Assets/Animations/Player/<Nom> ; modèle animé
-- (vigile, vigile de nuit, vendeur) dans <Modèle>/Animations/<Nom>.
-- Priority = nom d'un Enum.AnimationPriority. Marker = marqueur posé par Clément sur
-- l'image clé concernée, auquel le code accroche sons et effets.

export type Anim = {
	Name: string,
	Loop: boolean,
	Priority: string,
	Marker: string?,
	UpperBodyOnly: boolean?, -- n'anime que le haut du corps
}

local Animations = {}

-- Dossier d'un modèle animé, et chemin du dossier du joueur depuis ReplicatedStorage.
Animations.FolderName = "Animations"
Animations.PlayerFolder = { "Assets", "Animations", "Player" }

-- 13 animations du joueur.
Animations.Player = {
	{ Name = "HitWindow", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "HitWindowHeavy", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Grab", Loop = false, Priority = "Action", Marker = "Grab" },
	{ Name = "CarryIdle", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "CarryRun", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "Place", Loop = false, Priority = "Action", Marker = "Release" },
	{ Name = "TreadmillRun", Loop = true, Priority = "Movement" },
	{ Name = "BenchLift", Loop = false, Priority = "Action", Marker = "Top" },
	{ Name = "Unbox", Loop = false, Priority = "Action", Marker = "Open" },
	{ Name = "Celebrate", Loop = false, Priority = "Action" },
	{ Name = "SwingBat", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Stunned", Loop = true, Priority = "Action" },
	{ Name = "Knockback", Loop = false, Priority = "Action", Marker = "Land" },
} :: { Anim }

-- 5 animations dans chaque modèle de vigile, de jour comme de nuit (mêmes noms).
Animations.Guard = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Tired", Loop = false, Priority = "Action" },
} :: { Anim }

-- 2 animations dans chaque vendeur.
Animations.Vendor = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Wave", Loop = false, Priority = "Action" },
} :: { Anim }

return Animations
