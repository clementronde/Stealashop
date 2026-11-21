--!strict
-- Pièges de boutique (vague 72, a243 ; liaison L-218, L-216 point 11, L-229 partie Pièges). Tout est V0 proposé,
-- absent du doc, à valider par Clément ; interrupteur Features.Traps (false : aucun piège posé, tuile « Soon »).
--
-- Contrat partagé entre le serveur (TrapService) et le client (TrapController) :
--   - modèles de Clément : ReplicatedStorage/Assets/Traps/TRAP_<Id> (Id = GlueMat, NetBox, AlarmGate ; L-218 ; a286 : BananaPeel, TrapDoor, L-268) :
--     PrimaryPart Base, pivot en bas au centre, TriggerZone (volume invisible), Armed (visible), Triggered (caché :
--     pièces en Transparency 1, attribut ShownTransparency facultatif ; ParticleEmitter, Beam et lumières éteints ;
--     attribut EmitCount sur les gerbes). Absent : un modèle de repli construit par le code (TrapService) ;
--   - le niveau de la tuile Traps de l'arbre (Config/SkillTree) = nombre de pièges posés (TrapSlot_01 à _0n de la
--     boutique, Attachment ou pièce), chacun du genre donné par SlotLayout ;
--   - le serveur pose une copie par emplacement, nommée Trap_0n, dans le dossier Folder de la boutique, avec le tag
--     Tag (posé en jeu, pas par Clément) et les attributs TrapId et StateAttribute (« Armed » ou « Triggered ») ;
--   - le joueur pris porte l'attribut EffectAttribute = Id du piège tant que l'effet dure (son client joue
--     l'animation) ;
--   - déclenchement : un joueur vivant, qui n'est pas le propriétaire, dont le HumanoidRootPart est dans TriggerZone.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type TrapId = "GlueMat" | "NetBox" | "AlarmGate" | "BananaPeel" | "TrapDoor"

export type Trap = {
	Id: TrapId,
	Model: string, -- nom du modèle dans Assets/Traps
	DisplayName: string, -- texte du jeu (Notify), en anglais
	Sound: string, -- son 3D sur la Base au déclenchement (L-229, dossier Assets/Sounds/Traps)
	Animation: string, -- animation du joueur pris (Assets/Animations/Player) ; absente : Fallback
	StopTime: number, -- s à vitesse 0 (immobile) dès le déclenchement
	SlowTime: number, -- s ralenti ensuite (0 : aucun)
	SlowMultiplier: number, -- × la vitesse pendant SlowTime
	Spot: number, -- s de surlignage du voleur chez le propriétaire (CameraSpotted ; 0 : aucun)
	FallbackColor: Color3, -- couleur du modèle de repli
	-- a286 : true = le voleur est sorti devant la porte de la boutique au déclenchement (PlotService.PutOutside) ;
	-- l'objet qu'il volait à cette boutique revient sur son présentoir (CarryService.FailNoDrop, raison « Trap »).
	Eject: boolean,
}

local List: { Trap } = {
	{
		-- Colle : pieds collés un instant, puis ralenti. Un voleur qui porte un objet volé (vitesse fixe,
		-- StatsService) ne sent que l'arrêt : la vitesse fixe ignore tout modificateur sauf 0.
		Id = "GlueMat",
		Model = "TRAP_GlueMat",
		DisplayName = "Glue Trap",
		Sound = "Trap_Glue",
		Animation = "TrapStuck",
		StopTime = 1,
		SlowTime = 4,
		SlowMultiplier = 0.5,
		Spot = 0,
		FallbackColor = Color3.fromRGB(240, 200, 60),
		Eject = false,
	},
	{
		-- Filet : immobile sous le filet.
		Id = "NetBox",
		Model = "TRAP_NetBox",
		DisplayName = "Net Trap",
		Sound = "Trap_Net",
		Animation = "TrapNetted",
		StopTime = 3,
		SlowTime = 0,
		SlowMultiplier = 1,
		Spot = 0,
		FallbackColor = Color3.fromRGB(150, 110, 70),
		Eject = false,
	},
	{
		-- Portique : arrêt net au passage, et le voleur est surligné chez le propriétaire (comme Cameras 2).
		Id = "AlarmGate",
		Model = "TRAP_AlarmGate",
		DisplayName = "Alarm Gate",
		Sound = "Trap_Alarm",
		Animation = "Stunned",
		StopTime = 1.5,
		SlowTime = 0,
		SlowMultiplier = 1,
		Spot = 15,
		FallbackColor = Color3.fromRGB(220, 50, 50),
		Eject = false,
	},
	-- a286 (L-218, L-231, L-268 ; Features.NewTraps) : les deux pièges de plus de Clément. Effets de la Partie 2
	-- (ligne Pièges : « peau de banane (glissade 1,5 s) », « trappe (éjecte dehors) ») ; le reste est V0 du
	-- 2026-11-21 (nom affiché, son, durée de l'arrêt de la trappe, couleur du repli).
	{
		-- Peau de banane : glissade de 1,5 s sur place (Partie 2), animation TrapSlip de Clément (L-268, facultative).
		Id = "BananaPeel",
		Model = "TRAP_BananaPeel",
		DisplayName = "Banana Peel", -- V0 (21/11)
		Sound = "Trap_Slip", -- V0 (21/11) : son facultatif d'Assets/Sounds/Traps, absent = muet
		Animation = "TrapSlip",
		StopTime = 1.5, -- Partie 2
		SlowTime = 0,
		SlowMultiplier = 1,
		Spot = 0,
		FallbackColor = Color3.fromRGB(255, 225, 53), -- V0 (21/11)
		Eject = false,
	},
	{
		-- Trappe : le voleur tombe et ressort devant la porte de la boutique (Partie 2 : « éjecte dehors »), sonné
		-- un instant ; l'objet qu'il volait à cette boutique revient sur son présentoir.
		Id = "TrapDoor",
		Model = "TRAP_TrapDoor",
		DisplayName = "Trap Door", -- V0 (21/11)
		Sound = "Trap_Door", -- V0 (21/11) : son facultatif d'Assets/Sounds/Traps, absent = muet
		Animation = "Stunned", -- V0 (21/11) : aucune animation propre proposée par Clément
		StopTime = 1, -- V0 (21/11) : sonné 1 s devant la porte
		SlowTime = 0,
		SlowMultiplier = 1,
		Spot = 0,
		FallbackColor = Color3.fromRGB(90, 60, 40), -- V0 (21/11)
		Eject = true,
	},
}

local ById: { [string]: Trap } = {}
for _, trap in List do
	ById[trap.Id] = trap
end

local Traps = {
	List = List,
	ById = ById,
	-- Genre du piège de chaque emplacement : SlotLayout[n] pour TrapSlot_0n (V0 ; le propriétaire ne choisit pas).
	SlotLayout = { "GlueMat", "NetBox", "AlarmGate", "GlueMat" } :: { TrapId },
	-- a286 (Features.NewTraps) : disposition avec les deux pièges de plus. TrapService choisit l'une ou l'autre
	-- (a296, validé par Cantin, 21/11 : allumée dans le jeu DEV seulement, Features.NewTrapsDev et Config/ProductIds.IsDev ;
	-- coupée en PROD, Features.NewTraps = false ; en Studio, workspace:SetAttribute("NewTrapsTest", true)).
	-- a293 (Cantin, 21/11 : la colle est gardée) : une boutique n'a que 4 emplacements (TrapSlot_01 à _04, Partie 1
	-- 10.4 ; tuile Traps de 4 niveaux), donc pas les 5 pièges à la fois. V0 proposé (a293, 21/11), au plus près
	-- de SlotLayout : la colle reste au 1er niveau et le portique au 3e ; la peau de banane prend la place du filet
	-- (2e, un arrêt sur place comme lui, plus court) ; la trappe, la plus forte, prend celle de la colle en double (4e).
	-- Le filet (TRAP_NetBox) ne se pose plus. Même nombre d'emplacements que SlotLayout.
	SlotLayoutNew = { "GlueMat", "BananaPeel", "AlarmGate", "TrapDoor" } :: { TrapId },
	SlotName = "TrapSlot_%02d", -- emplacements de la boutique (Contract/Models, Plot)
	PlacedName = "Trap_%02d", -- copie posée par le serveur
	Folder = "PlacedTraps", -- dossier des copies dans la boutique
	AssetsFolder = { "Assets", "Traps" }, -- depuis ReplicatedStorage
	Tag = "PlotTrap", -- tag posé en jeu sur chaque copie (pas un tag du contrat de Clément)
	TrapIdAttribute = "TrapId",
	StateAttribute = "TrapState",
	Armed = "Armed",
	Triggered = "Triggered",
	EffectAttribute = "TrapEffect", -- attribut du Player pris
	FallbackAnimation = "Stunned",
	Recharge = 15, -- s en Triggered avant de se réarmer
	Immunity = 8, -- s : un joueur pris ne l'est plus par les pièges de cette boutique pendant ce temps
	CheckInterval = 0.1, -- s entre deux contrôles des volumes
	-- Vague 81 (a268) : chaque contrôle teste le TRAJET du HumanoidRootPart depuis le contrôle d'avant (segment contre
	-- le TriggerZone), pas seulement sa position : à 40 studs/s, 3,2 studs se traversent en 0,08 s. Un trajet plus
	-- long que SweepMax studs (téléportation, réapparition) n'est pas testé, seule la position du moment compte.
	SweepMax = 30, -- V0 proposé (a268, 20/11) : 300 studs/s à 0,1 s par contrôle, au-dessus de toute course du jeu
	SyncInterval = 2, -- s entre deux remises à jour des pièges posés (niveau de la boutique, emplacements)
	SpareFriends = false, -- aucune règle d'amis au vol (PvPService) : les amis du propriétaire sont pris aussi
	-- Messages (Notify), en anglais.
	Messages = {
		Thief = "You walked into a %s!",
		Owner = "%s walked into your %s!",
	},
}

export type Traps = typeof(Traps)

return DeepFreeze(Traps)
