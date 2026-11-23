--!strict
-- Défense de la boutique d'un joueur (MAJ 5, vague GC6, a408) : les tuiles « Soon » de l'arbre devenues jouables.
-- Serveur : ShopDefenseService ; client : CameraAlertController (Cameras niveau 3). Prix et niveaux : Config/SkillTree.
-- Interrupteurs : Features.Bodyguards, Features.DoorGuard, Features.CameraRadar.
-- Tout ce qui n'est ni dans la Partie 2 (section 2) ni dans la liaison est « V0 proposé (Cantin, 23/11) ».

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Bat = require(script.Parent.Bat)

local ShopDefense = {
	-- Modèles proposés à Clément (facultatifs, Contract/Models.ShopGuards) : dossier Guards de ReplicatedStorage/Assets
	-- (puis de ServerStorage/Assets), rig R15 avec Humanoid, HumanoidRootPart et Animations (Idle, Run, Catch), sans
	-- script. Essayés dans l'ordre ; aucun : l'avatar R15 par défaut de Roblox.
	GuardsFolder = "Guards",

	-- Tuile Bodyguards (Partie 2 : « un vigile PNJ posté dans ta boutique ; dès qu'un voleur prend un objet, il le
	-- poursuit comme les vigiles des magasins PNJ ; s'il le touche, l'objet revient » ; vitesse 20, 28, 36, 44, 52 =
	-- SkillTree Effects, à l'échelle 1, × Balance.Stats.RealSpeedScale comme tous les poursuivants).
	Bodyguard = {
		Models = { "NPC_Bodyguard", "Guard" }, -- Guard : le look commun des vigiles de magasin (L-048)
		DisplayName = "Security", -- V0 proposé (Cantin, 23/11) : nom au-dessus de lui
		SpeedScale = Balance.Stats.RealSpeedScale,
		-- V0 proposé (Cantin, 23/11) : poste à PostInset studs à l'intérieur de la porte (PlotDoor/Window), face à elle,
		-- sauf si la boutique a un repère BodyguardSpot (Attachment ou pièce, facultatif, nom proposé à Clément).
		PostInset = 6,
		SpotName = "BodyguardSpot",
		-- V0 proposés (Cantin, 23/11) : jamais d'invulnérabilité (L-163, règle 2) :
		ReactDelay = 0.5, -- s entre la prise de l'objet et son départ
		LeashDistance = 30, -- studs hors de l'emprise au sol de Bounds : au-delà, il lâche ce voleur
		GiveUpTime = Balance.Guard.IntruderChaseTime, -- s de poursuite au plus (10, l'abandon du vigile qui chasse un intrus)
		CatchDistance = Balance.Guard.CatchDistance, -- 4 studs, comme les vigiles (contrôle serveur)
		CatchTolerance = 1.5, -- studs de plus acceptés au marqueur Impact de Catch (la cible a bougé pendant le geste)
		ImpactMaxWait = 0.4, -- s : la capture part au marqueur Impact de Catch, au plus tard ce temps après le geste
		HomeDistance = Balance.Guard.CatchDistance / 2, -- ré-ancré à 2 studs de son poste
		ReturnTimeout = Balance.Guard.IntruderChaseTime, -- pas rentré en 10 s : replacé d'un coup
		ReturnSpeed = 16, -- à l'échelle 1 (× SpeedScale), V0 proposé (Cantin, 23/11)
		DoorPassDistance = Bat.PointBlankRange, -- point de passage de la porte atteint à 3 studs (comme le bot)
	},

	-- Tuile DoorGuard (L-163 : « un garde à la porte qui repousse le voleur toutes les X s » ; X = SkillTree Effects[1]).
	DoorGuard = {
		Models = { "NPC_DoorGuard", "NPC_Bodyguard", "Guard" },
		DisplayName = "Door Guard", -- V0 proposé (Cantin, 23/11)
		-- V0 proposés (Cantin, 23/11) : debout dehors, à Outset studs devant la porte et Side studs à sa droite (il ne
		-- bouche pas l'entrée), face à la rue ; repère DoorGuardSpot (facultatif, nom proposé à Clément) prioritaire.
		Outset = 3,
		Side = 4,
		SpotName = "DoorGuardSpot",
		Range = 10, -- studs de la porte : il repousse celui qui casse la porte, ou qui entre par la porte cassée
		-- Même poussée qu'un coup de batte (L-163, règle 3 : le même effet pour tous) : Bat.Knockback*, ici ×
		-- PushFactor (V0 proposé, Cantin, 23/11 : plus fort, pour l'éloigner de la vitre).
		PushFactor = 1.5,
		ImpactMaxWait = 0.3,
	},

	-- Tuile Cameras niveau 3 (L-163 ; V0 de L-175 : voleur surligné en rouge vif et son de radar, sans flèche).
	CameraRadar = {
		Level = 3,
		Color = Color3.fromRGB(255, 30, 30), -- V0 proposé (Cantin, 23/11) : rouge vif (niveau 2 : bleu caméra)
		FillTransparency = 0.35,
		Sound = "CameraRadar_Beep", -- son proposé à Clément (MarkerSounds.find ; absent : radar muet)
		-- V0 proposés (Cantin, 23/11) : un bip toutes les MaxInterval s à FarDistance studs ou plus, de plus en plus
		-- vite en approchant, jusqu'à MinInterval s à NearDistance studs ou moins (comme un radar de recul).
		NearDistance = 15,
		FarDistance = 200,
		MinInterval = 0.15,
		MaxInterval = 1.2,
	},

	Tick = 0.1, -- poursuite et poussées contrôlées 10 fois par seconde
	SyncInterval = 1, -- agents posés ou retirés selon l'arbre, chaque seconde

	-- Messages (anglais, V0 proposés, Cantin, 23/11).
	Messages = {
		OwnerCaught = "Your guard caught %s!",
		DoorPushed = "The door guard pushed you back!",
	},
}

export type ShopDefense = typeof(ShopDefense)

return DeepFreeze(ShopDefense)
