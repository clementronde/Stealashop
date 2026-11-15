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

-- 14 animations du joueur (15 avant le retrait d'Unbox et de Celebrate, vague 52 ; BenchLift et BenchIdle
-- retirés en v2 ; HoldItem ajoutée en vague 56).
Animations.Player = {
	{ Name = "HitWindow", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "HitWindowHeavy", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Grab", Loop = false, Priority = "Action", Marker = "Grab" },
	{ Name = "CarryIdle", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "CarryRun", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "Place", Loop = false, Priority = "Action", Marker = "Release" },
	{ Name = "TreadmillRun", Loop = true, Priority = "Movement" },
	-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc. BenchLift (marqueur Top) et BenchIdle sortent du
	-- contrat : le code ne les charge plus ; les objets Animation de Clément peuvent rester dans le dossier.
	-- Vague 52 (a170) : Unbox (marqueur Open) et Celebrate sortent du contrat avec l'ouverture des colis en base
	-- (écran UI_Unbox) : le code ne les joue plus (Animations.Retired).
	{ Name = "SwingBat", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Stunned", Loop = true, Priority = "Action" },
	{ Name = "Knockback", Loop = false, Priority = "Action", Marker = "Land" },
	-- Chute et arrestation (Clément, liaison L-076, livrées le 2026-11-10 ; réglages relevés dans Studio) :
	-- pas encore jouées par le code.
	{ Name = "Knockdown", Loop = false, Priority = "Action", Marker = "Land" },
	{ Name = "GetUp", Loop = false, Priority = "Action" },
	{ Name = "Arrested", Loop = false, Priority = "Action", Marker = "Grab" },
	-- Vague 56 (a181, L-162, Clément) : objet Big, Huge ou Colossal tenu à deux mains (HeldItemService), haut du
	-- corps seulement. Pas encore livrée : orange au ContractChecker, la pose « outil » de Roblox reste.
	{ Name = "HoldItem", Loop = true, Priority = "Action", UpperBodyOnly = true },
} :: { Anim }

-- 5 animations dans chaque modèle de vigile, de jour comme de nuit (mêmes noms).
Animations.Guard = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Tired", Loop = false, Priority = "Action" },
} :: { Anim }

-- Vigile de nuit (modèle NightGuard) : celles des vigiles, plus Arrest (L-076, livrée le 2026-11-10 ;
-- pas encore jouée par le code).
Animations.NightGuard = table.clone(Animations.Guard)
table.insert(Animations.NightGuard, { Name = "Arrest", Loop = false, Priority = "Action", Marker = "Grab" })

-- 2 animations dans chaque vendeur (Vendor_* des comptoirs du hub). Jouées par VendorService (vague 39) :
-- Idle en boucle, Wave quand un joueur approche (Config/Vendors).
Animations.Vendor = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Wave", Loop = false, Priority = "Action" },
} :: { Anim }

-- Témoins NPC_Witness_Z<n>_0<k> (Clément, liaison L-111, publiées le 2026-11-12 ; réglages relevés dans Studio) :
-- pas encore jouées par le code. CallPolice revient en boucle, le code ne réagira qu'au premier marqueur Call.
Animations.Witness = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Look", Loop = true, Priority = "Action" },
	{ Name = "CallPolice", Loop = true, Priority = "Action", Marker = "Call" },
	-- L-118 point 10 (Clément, en cours) : course paniquée à la casse. Boucle et priorité V0, comme Run des vigiles.
	{ Name = "Flee", Loop = true, Priority = "Movement" },
	-- L-172 (Clément, 2026-11-15, pas encore publiée : orange tant qu'elle manque) : photos au flash après l'appel ;
	-- à chaque marqueur Flash, WitnessService fait partir le flash de FX_Witness_Flash. Sans elle, le témoin garde
	-- sa pose et le flash part toutes les Witness.Photo.Interval s.
	{ Name = "TakePhoto", Loop = true, Priority = "Action", Marker = "Flash" },
} :: { Anim }

-- Conducteurs du camion de l'événement (liaison L-071, point 7 ; a42) : des modèles avec un Humanoid,
-- rangés par Clément dans ENV_Event_Truck. Idle, jouée en boucle par TruckEventService tant que le
-- camion est là ; sans elle, le conducteur reste immobile. Walk, Run et Catch (livrées par Clément le
-- 2026-11-10, liaison L-083 point 3) : pour la poursuite des conducteurs à la fin du chrono du camion
-- (GuardService.StartDriverChase : Run en poursuite, Catch et son marqueur Impact à la capture ; Walk
-- n'est pas jouée en V0) ; mêmes réglages que les vigiles.
Animations.Driver = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
} :: { Anim }

-- Animations du joueur sorties du contrat : le code ne les lit plus. Laissées dans le dossier de Clément, le
-- ContractChecker les signale en note, pas en problème ; il peut les retirer quand il veut (liaison L-157).
Animations.Retired = {
	BenchLift = "banc retiré du jeu (rééquilibrage v2, 2026-11-14)",
	BenchIdle = "banc retiré du jeu (rééquilibrage v2, 2026-11-14)",
	Unbox = "ouverture des colis en base retirée (fin du colis porté, 2026-11-15)",
	Celebrate = "ouverture des colis en base retirée (fin du colis porté, 2026-11-15)",
} :: { [string]: string }

-- Vague 62 (a204, L-198 ; noms proposés à Clément, tous facultatifs) : la cinématique d'ouverture d'un colis, jouée
-- par RevealController sur une copie locale du rig de caméra ReplicatedStorage/Assets/Cinematics/CAM_Reveal (un
-- AnimationController et son Animator, les pièces CameraPart et ItemAnchor, son dossier Animations ; Config/Reveal).
-- D'abord Open<Rareté> (une par Id de Config/Rarities : OpenCommon … OpenSecret, OpenDivine ; une rareté ajoutée =
-- une ligne ici), puis Grow<Classe>
-- (classe de taille du serveur). Marqueurs, chacun sur son image clé : Open (le colis s'ouvre), Reveal (l'objet
-- apparaît), Grow et Top (début et fin de la croissance : le code agrandit l'objet entre les deux), Explode (le plafond
-- saute : GrowLarge et GrowColossal), Land (fin). Un marqueur absent tombe à la fin de son animation (Explode : à Top) ;
-- une animation absente = repli codé, mêmes étapes. La caméra est animée pour un objet de taille 1 : le code multiplie
-- l'écart CameraPart ↔ ItemAnchor par la taille de l'objet. Priorité Action, sans boucle.
Animations.RigPath = { "Assets", "Cinematics", "CAM_Reveal" }
Animations.RevealMarkers = { "Open", "Reveal", "Grow", "Top", "Explode", "Land" }
Animations.Reveal = {
	{ Name = "OpenCommon", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenUncommon", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenRare", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenEpic", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenLegendary", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenMythic", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenSecret", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenDivine", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "GrowSmall", Loop = false, Priority = "Action", Marker = "Land" },
	{ Name = "GrowLarge", Loop = false, Priority = "Action", Marker = "Explode" },
	{ Name = "GrowColossal", Loop = false, Priority = "Action", Marker = "Explode" },
} :: { Anim }

return Animations
