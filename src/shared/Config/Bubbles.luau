--!strict
-- Bulles ×N du tapis (vague 64, a214). Décisions de Cantin du 2026-11-16 ; rythme et tweens mesurés dans la vidéo de
-- référence (docs/claude/notes/2026-11-16_video-bulles-multiplicateur.md, sections 2, 3 et 6).
--
-- Pendant une séance sur le tapis, le serveur (BubbleService) fait apparaître des bulles « ×N » autour du joueur ; un
-- clic sur l'une donne tout de suite le gain d'une seconde de tapis × N (même calcul que le tapis, boosts compris :
-- TrainingService.GainPerSecond), une seule fois. Le rythme du tapis ne change pas : pas de minuteur, pas de cumul.
-- Le client (BubbleController) les dessine : modèle BB_TrainBubble de Clément s'il existe, sinon un repli construit
-- par le code.
--
-- Origine des valeurs : « Cantin » = décision du 16/11 ; « fiche » = mesuré dans la vidéo ; « V0 » = V0 proposé,
-- absent du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Bubbles = {
	-- V0 : interrupteur (false : aucune bulle, ni serveur ni client).
	Enabled = true,

	-- Cantin : chances de chaque multiplicateur, en % (total 100).
	Chances = {
		{ Multiplier = 2, Percent = 55 },
		{ Multiplier = 3, Percent = 22 },
		{ Multiplier = 4, Percent = 11 },
		{ Multiplier = 5, Percent = 6 },
		{ Multiplier = 7, Percent = 3.5 },
		{ Multiplier = 10, Percent = 2 },
		{ Multiplier = 20, Percent = 0.5 },
	},
	-- Cantin : une bulle toutes les SpawnMin à SpawnMax s (tiré au hasard à chaque fois), MaxAtOnce au plus à la fois ;
	-- une bulle que personne ne prend disparaît après Lifetime s. Bulle due alors qu'il y en a déjà MaxAtOnce : elle
	-- est sautée (V0), la suivante est tirée de nouveau dans SpawnMin à SpawnMax s.
	SpawnMin = 2,
	SpawnMax = 3,
	MaxAtOnce = 2,
	Lifetime = 6,
	-- V0 : écart minimal (s) entre deux ClaimBubble d'un même joueur (en plus du débit de Net/Definitions).
	ClaimMinGap = 0.1,

	-- Client (BubbleController).
	Client = {
		-- Modèle de Clément dans ReplicatedStorage/Assets/UI (noms proposés : Button, MultiplierLabel, Shine ; contrat
		-- UI facultatif). Absent : repli construit par le code.
		Template = "BB_TrainBubble",
		-- Taille à l'écran (Offset, la même à toute distance) : fiche « 127 px sur 1080, soit 11,8 % de la hauteur » ;
		-- V0 : au moins 48 px (doigt, 44 px au moins), au plus 140 px.
		ScreenFraction = 0.118,
		MinPixels = 48,
		MaxPixels = 140,
		-- V0 (fiche : « au hasard dans un rayon de quelques studs autour du tapis, à hauteur de poitrine ou un peu
		-- au-dessus ») : décalage autour du HumanoidRootPart (immobile sur le tapis), en studs ; deux bulles à la fois
		-- sont écartées d'au moins MinAngleGap degrés autour du joueur.
		RadiusMin = 3,
		RadiusMax = 5,
		HeightMin = 0.5,
		HeightMax = 2.5,
		MinAngleGap = 70,
		-- Fiche : apparition 0,35 → 1 en 0,25 s Back Out, sans fondu, sans son.
		Appear = { From = 0.35, Time = 0.25, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		-- Fiche : prise, gonfle à 1,2 en 0,1 s Quad Out, puis s'écrase à 0 en 0,05 s Quad In (son à l'écrasement).
		Claim = { To = 1.2, Time = 0.1, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
		Squash = { Time = 0.05, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In },
		-- Fiche : expiration, gonfle à 1,1 en 0,1 s Quad Out, puis rétrécit à 0 en 0,1 s Back In, sans son.
		Expire = { To = 1.1, Time = 0.1, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
		Shrink = { Time = 0.1, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.In },
		-- V0 : sans réponse du serveur à un clic après ClaimTimeout s (refus de débit…), la bulle redevient cliquable.
		ClaimTimeout = 1.5,
		-- Texte de gain (fiche : « vie environ 1,0 s, fondu d'entrée 0,1 s, montée d'environ 3 % de l'écran qui
		-- ralentit, fondu de sortie 0,15 s », hauteur 2,8 % de l'écran). Le nôtre, pas celui de GainController.
		-- V0 : texte en anglais comme celui du tapis (Config/Hud.TreadmillGain.Text), au moins 20 px de haut ;
		-- couleur de la Vitesse (UiMotion.FloatGain.Colors.Speed) et contour sombre.
		GainText = {
			Text = "+%s Speed",
			Life = 1,
			FadeIn = 0.1,
			FadeOut = 0.15,
			RiseFraction = 0.03,
			HeightFraction = 0.028,
			MinPixels = 20,
			StrokeColor = Color3.fromHex("0B2346"),
		},
		-- V0 : son de la prise, dans ReplicatedStorage/Assets/Sounds (nom proposé à Clément) ; absent : muet.
		Sound = "Bubble_Pop",
		-- Éclat des grosses valeurs (brief de la vague 64 : en V0, ×10 et ×20 ont un éclat simple) : à partir de
		-- ShineFrom, Shine de Clément visible ; sur le repli, couleurs dorées. Le dégradé de la bulle tourne de
		-- ShineDegreesPerSecond (fiche : « environ 80° par seconde ») ; rien ne tourne en « animations réduites ».
		ShineFrom = 10,
		ShineDegreesPerSecond = 80,
		-- Repli construit par le code (V0, nos couleurs, pas le violet de la vidéo) : disque à dégradé vertical clair en
		-- haut, saturé en bas (bleu de la Vitesse), anneau sombre d'environ 3 % du diamètre (au moins 2 px), « ×N »
		-- blanc à contour noir en bas à droite, penché de LabelRotation degrés.
		Fallback = {
			Top = Color3.fromHex("BFF0FF"),
			Bottom = Color3.fromHex("1E8FE8"),
			Stroke = Color3.fromHex("0B3A6B"),
			ShineTop = Color3.fromHex("FFF4B0"),
			ShineBottom = Color3.fromHex("F5A300"),
			ShineStroke = Color3.fromHex("8A4B00"),
			StrokeFraction = 0.03,
			LabelColor = Color3.fromHex("FFFFFF"),
			LabelStroke = Color3.fromHex("000000"),
			LabelFraction = 0.3, -- hauteur du « ×N » / diamètre (fiche : 30 px pour 127, soit 0,24 ; un peu plus gros pour le téléphone)
			LabelRotation = -10,
		},
	},
}

export type Bubbles = typeof(Bubbles)

return DeepFreeze(Bubbles)
