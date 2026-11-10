--!strict
-- Contrat d'animations (doc, section 2.4 ; liaison, section 3.2) : 21 animations, plus l'Idle facultatif des
-- conducteurs du camion (Animations.Driver, L-071).
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

-- 14 animations du joueur.
Animations.Player = {
	{ Name = "HitWindow", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "HitWindowHeavy", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Grab", Loop = false, Priority = "Action", Marker = "Grab" },
	{ Name = "CarryIdle", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "CarryRun", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "Place", Loop = false, Priority = "Action", Marker = "Release" },
	{ Name = "TreadmillRun", Loop = true, Priority = "Movement" },
	{ Name = "BenchLift", Loop = false, Priority = "Action", Marker = "Top" },
	-- Assis au banc entre deux répétitions (L-020, ajout validé par Clément le 2026-11-07).
	-- Priorité Idle : BenchLift (Action) passe par-dessus pendant une répétition, sans
	-- arrêter la boucle, et le BenchIdle bat l'attente par défaut de Roblox (Core).
	{ Name = "BenchIdle", Loop = true, Priority = "Idle" },
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

-- Conducteurs du camion de l'événement (liaison L-071, point 7 ; a42) : des modèles avec un Humanoid,
-- rangés par Clément dans ENV_Event_Truck. Idle, jouée en boucle par TruckEventService tant que le
-- camion est là ; sans elle, le conducteur reste immobile. Walk, Run et Catch (livrées par Clément le
-- 2026-11-10, liaison L-083 point 3) : pour la poursuite des conducteurs à la fin du chrono du camion,
-- pas encore codée ; mêmes réglages que les vigiles.
Animations.Driver = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
} :: { Anim }

return Animations
