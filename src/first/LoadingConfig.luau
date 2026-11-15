--!strict
-- Réglages de l'écran de chargement (ReplicatedFirst, liaison L-177), lus par LoadingScreen (même dossier).
-- Ce module ne dépend pas de ReplicatedStorage/Shared : il tourne avant que Shared soit arrivé chez le client.
-- Valeurs sans mention : celles de L-177. « V0 » : V0 proposé, absent du doc et de la liaison.
-- Textes du joueur en anglais, comme le reste de l'UI (L-036).

export type LoadingConfig = {
	ScreenName: string,
	ScreenWait: number,
	SkipDelay: number,
	MaxDuration: number,
	FadeTime: number,
	TipIntervalMin: number,
	TipIntervalMax: number,
	BarTweenTime: number,
	TipPrefix: string,
	Weights: { Screen: number, Game: number, Assets: number },
	BatchSize: number,
	Preload: { { string } },
	PreloadClasses: { string },
	Tips: { string },
}

local LoadingConfig: LoadingConfig = {
	ScreenName = "UI_Loading", -- ReplicatedFirst/UI_Loading, l'écran de Clément
	ScreenWait = 1, -- V0 : secondes d'attente de UI_Loading dans ReplicatedFirst ; sans lui, écran Roblox par défaut
	SkipDelay = 5, -- SkipButton visible après 5 s
	MaxDuration = 20, -- fermeture au plus tard 20 s après le départ, même si un chargement bloque
	FadeTime = 0.4, -- fondu de sortie
	TipIntervalMin = 4, -- une astuce au hasard toutes les 4 à 5 s
	TipIntervalMax = 5,
	BarTweenTime = 0.25, -- V0 : tween court de la barre (évite les sauts) ; à 100 %, l'écran attend sa fin
	-- Début gardé devant chaque astuce : repris du texte de Clément (Root.Tip) s'il en a un, sinon celui-ci.
	TipPrefix = '<font color="#FFD23A">TIP:</font> ',
	-- Part de la barre de chaque étape (somme 1), V0 : l'écran lui-même (illustration et logo), le jeu
	-- (game:IsLoaded), puis les assets préchargés en lots.
	Weights = { Screen = 0.1, Game = 0.4, Assets = 0.5 },
	BatchSize = 20, -- V0 : assets par appel à PreloadAsync
	-- Dossiers préchargés après game:IsLoaded(), depuis ReplicatedStorage (absents : sautés).
	Preload = {
		{ "Assets", "UI" },
		{ "Assets", "Icons" },
		{ "Assets", "Animations", "Player" },
	},
	-- Classes préchargées dans ces dossiers (un seul objet par image ou animation), V0.
	PreloadClasses = { "ImageLabel", "ImageButton", "Decal", "Texture", "Animation" },
	-- Astuces de Clément (L-177), corrigées pour le jeu d'aujourd'hui (rééquilibrage v2 : plus de banc ni de
	-- coffre-fort ; vague 58, a187) : 115 caractères au plus.
	Tips = {
		"At night a wall closes the street. Rob the shops before it rises!",
		"Run on your treadmill to get faster. Buy better tools to smash windows faster!",
		"Shops further down the street hold rarer items.",
		"Display stolen items in your shop to earn cash every second.",
		"Guards never enter the safe zone. Reach it before they catch you!",
		"Auras boost your power, trails boost your speed.",
		"Other players can rob your shop too. Lock it and hit thieves with your bat!",
	},
}

table.freeze(LoadingConfig.Weights)
for _, path in LoadingConfig.Preload do
	table.freeze(path)
end
table.freeze(LoadingConfig.Preload)
table.freeze(LoadingConfig.PreloadClasses)
table.freeze(LoadingConfig.Tips)

return table.freeze(LoadingConfig)
