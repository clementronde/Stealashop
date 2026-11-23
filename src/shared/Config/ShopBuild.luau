--!strict
-- Construction « en mode Lego » d'une partie neuve de la boutique du joueur (liaison L-297, Clément, 2026-11-23,
-- validée sur un prototype ; fiche vidéo de Cantin docs/references/Achat-Progressif-Base.md pour ce que L-297 ne
-- dit pas). Lu par Controllers/ShopBuildController (client) et Controllers/UpgradeController (panneau caché).
--
-- Les réglages de l'animation sont lus d'abord dans les attributs du modèle de Clément
-- ReplicatedStorage/Assets/FX/FX_ShopUpgrade_Build (StartDelay, PieceDelay…) ; `Fallback` ne sert que s'il manque
-- (mêmes valeurs que L-297). Le reste est « V0 (fiche vidéo de Cantin, 23/11) » ou « V0 proposé (Cantin, 23/11) »,
-- à régler à l'œil en jeu. Unités : secondes, studs, radians.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ShopBuild = {
	Enabled = true, -- false : tout apparaît d'un coup, comme avant
	-- Effet de Clément (L-297) : Model avec Root et l'Attachment Burst, qui porte les ParticleEmitter Bills, Puff
	-- et Sparks (Rate 0, attribut EmitCount chacun).
	FxFolder = { "Assets", "FX" }, -- depuis ReplicatedStorage
	FxName = "FX_ShopUpgrade_Build",
	BurstName = "Burst",
	BillsName = "Bills",
	PuffName = "Puff",
	SparksName = "Sparks",
	EmitCountAttribute = "EmitCount",
	-- Repli quand le modèle ou un de ses attributs manque : valeurs de L-297.
	Fallback = {
		StartDelay = 0.3, -- L-297 : fontaine de billets, puis attente avant la 1re pièce
		PieceDelay = 0.09, -- L-297 : écart entre deux pièces d'un présentoir
		BrickDelay = 0.05, -- L-297 : écart entre deux pièces d'un look ou de l'étage
		DropTime = 0.2, -- L-297 : durée de la chute d'une pièce
		DropHeight = 3.5, -- L-297 : la pièce part de sa place + DropHeight
		DropJitter = 0.6, -- L-297 : ± en X et en Z au départ
		DropTilt = 0.5, -- L-297 : inclinaison au hasard ± (radians)
		BackOvershoot = 1.9, -- L-297 : courbe Back (1,70158 pour la courbe Back de Roblox)
	},
	EmitFallback = { Bills = 18, Puff = 3, Sparks = 16 }, -- L-297 : EmitCount de chaque ParticleEmitter

	-- Les trois moments de L-297 (noms de Clément, L-294 et L-295).
	StandFormat = "DisplayStand_%02d", -- présentoir acheté : la pièce et son SocleDecor
	LookFormat = "Look_%d", -- niveau de résistance : Look_n (dans la boutique et dans Floor_2), facultatif
	FloorName = "Floor_2", -- étage acheté, facultatif
	GlassSkill = "GlassThickness", -- attribut Skill_GlassThickness du propriétaire (« Reinforced Door »)
	SlotsAttribute = "DisplaySlotsLevel", -- attribut du propriétaire (ShopService)

	-- L-297 Q1 : look et étage, des centaines de pièces : V0 proposé (Cantin, 23/11), les MaxPieces plus grosses
	-- (volume de la boîte) tombent, le reste apparaît d'un coup avec la dernière ; l'écart (BrickDelay au plus) est
	-- réduit pour que la dernière pièce soit posée MaxDuration s après le départ de la première.
	MaxPieces = 60,
	MaxDuration = 2.5,
	-- Présentoir : toutes ses pièces (15 environ), au plus StandMaxPieces (même règle au-delà).
	StandMaxPieces = 40, -- V0 proposé (Cantin, 23/11)

	-- Quand : V0 (fiche vidéo de Cantin, 23/11).
	MaxDistance = 150, -- caméra plus loin que ça de la partie : rien ne s'anime (apparaît d'un coup)
	MaxStep = 2, -- niveau qui monte de plus de MaxStep d'un coup (chargement, test) : rien ne s'anime
	SettleTime = 3, -- Floor_2 arrivé moins de SettleTime s après le propriétaire ou la parcelle : chargement, pas un achat
	FindTimeout = 0.5, -- présentoir attendu jusqu'à FindTimeout s après l'achat (réplication), sinon rien

	-- Fin (L-297 : « petit tremblement de caméra, à toi ») : V0 proposé (Cantin, 23/11).
	Shake = {
		Duration = 0.25,
		Amplitude = 0.08, -- studs
		Angle = 0.004, -- radians
		Frequency = 22, -- hertz
		Range = 60, -- caméra plus loin que ça de la partie : pas de tremblement
	},

	-- Son (L-297 Q2 : un clic par pièce, monté d'un demi-ton par pièce ; facultatif, aucun ID).
	PopSound = "UI_Click", -- V0 de L-297, dans Assets/Sounds ; absent : muet
	PitchStep = 2 ^ (1 / 12), -- L-297 : un demi-ton par pièce
	PitchMax = 2, -- V0 proposé (Cantin, 23/11) : pas plus d'une octave (60 pièces feraient 5 octaves)
	MaxPopsPerSecond = 25, -- V0 (fiche vidéo de Cantin, 23/11) : au-delà, la pièce ne sonne pas

	-- Panneau d'achat des présentoirs (UpgradeSign) : caché pendant la construction, revient avec un pop.
	BusyAttribute = "ShopBuildBusy", -- attribut LOCAL (client) de la parcelle, posé par ShopBuildController
	SignReturnDelay = 0.7, -- V0 (fiche vidéo de Cantin, 23/11) : après la dernière pièce
	SignPopFrom = 0.55, -- V0 (fiche vidéo de Cantin, 23/11) : = UiMotion.Appear.Pop
	SignPopTime = 0.38,
}

return DeepFreeze(ShopBuild)
