--!strict
-- Tension pendant un braquage (a465 ; liaison L-340, retours de Clément après sa session de jeu, points 7 et 8 ; test
-- T-303). Lu par TensionController, Controllers/Tension/Path, VfxController, ChaseFeelController, UiFeelController et
-- Controllers/UI/HudMask. Interrupteur : Features.HeistTension (partout) ou HeistTensionDev (jeu DEV), Shared/HeistTension.
-- Aucune règle de jeu ici : seulement ce que le joueur voit, chez lui. Sources :
--   « L-340 » : la ligne de liaison (V0 de Clément, « à régler en jeu ») ;
--   « V0 »    : V0 proposé, absent du doc.
-- Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local HeistTension = {
	-- 1. Chevrons au sol, du joueur à la porte de SA boutique, tant qu'il porte un objet volé (attribut Carrying du
	-- Player, posé par CarryService) : copies de ReplicatedStorage/Assets/FX/FX_ChaseChevron (Clément ; pointe vers −Z).
	Chevrons = {
		Template = "FX_ChaseChevron", -- L-340, dans Config/Vfx.FxFolder
		Lit = { "Left", "Right" }, -- L-340 : les deux barres néon qui s'allument
		Spacing = 6, -- L-340 : « tous les ~6 studs »
		Max = 40, -- V0 : 240 studs de chemin au plus, les plus proches du joueur
		FirstAt = 4, -- V0 : premier chevron à 4 studs devant le joueur, sur le chemin
		EndMargin = 2, -- V0 : pas de chevron à moins de 2 studs de la porte
		-- Chemin : PathfindingService (contourne les rayons et les murs), sinon la ligne droite. Refait quand le joueur
		-- s'éloigne du chemin de plus de OffPath studs, ou quand la porte bouge de plus de TargetMoved studs ; au plus
		-- une fois toutes les RecomputeEvery s.
		OffPath = 8, -- V0
		TargetMoved = 4, -- V0
		RecomputeEvery = 1, -- V0
		Agent = { Radius = 2, Height = 5, CanJump = true }, -- V0 : un perso R15 (~5 studs)
		PassedMargin = 1, -- V0 : un chevron dépassé de plus d'1 stud (le long du chemin) est caché
		-- Collés au sol par un rayon vertical (pièces CanQuery seulement, ni le perso ni les chevrons).
		RayUp = 4, -- V0 : départ du rayon au-dessus du point du chemin
		RayDown = 14, -- V0 : longueur du rayon vers le bas
		GroundGap = 0.03, -- V0 : écart au sol (pas de scintillement)
		-- Vague vers la boutique (L-340) : transparence de Left et Right de From à Peak puis From, Step s de décalage
		-- d'un chevron au suivant (du joueur vers la boutique) ; une vague repart toutes les Period s.
		From = 0.45, -- L-340
		Peak = 0, -- L-340
		Step = 0.08, -- L-340 : « ~0,08 s de décalage »
		PulseTime = 0.3, -- V0 : durée de l'allumage d'un chevron (montée puis descente, moitié chacune)
		Period = 1.6, -- V0 : une nouvelle vague toutes les 1,6 s
		Refresh = 0.25, -- V0 : chemin et place des chevrons revus toutes les 0,25 s (la vague, à chaque image)
		Folder = "ChaseChevrons", -- V0 : dossier local du Workspace, créé et vidé par TensionController
	},

	-- 2. Le vigile qui poursuit le joueur, en rouge à travers les murs (L-340) : copie de Assets/FX/HL_ChaseGuard
	-- (Clément) à la place de FX_ChaseHighlight (VfxController) ; le Highlight V0 du code (HeistFeel.Highlight,
	-- ChaseFeelController) n'est plus posé, pour n'en avoir qu'un.
	GuardHighlight = "HL_ChaseGuard", -- L-340

	-- 3. HUD vidé pendant la poursuite (HeistFeel.ChaseMask) : ce qui reste en plus de KeepHud (L-340).
	ExtraKeepHud = { "DropButton" }, -- L-340 (aucun code ne le montre encore : il garde la visibilité de Clément)

	-- 4. Phase discrète (chrono du braquage en cours, pas encore poursuivi) : ces éléments restent à l'écran même sous
	-- un masque du HUD qui les cacherait (écran de révélation de RevealController, lueur d'achat). L-340 : « HeistTimer
	-- visible pendant toute la phase discrète ».
	SpareKey = "HeistTension", -- V0 : clé de HudMask.SetSpare
	DiscreetKeep = { UI_HUD = { "HeistTimer" } }, -- L-340

	-- 5. Flash d'arrivée en zone sûre avec l'objet (UiFeelController, UI_Escape.Flash, jaune chez Clément) : sa
	-- transparence passe par Keys, chaque pas en Times s (L-340 : « 0 → 0,6 → 1 en 0,35 s » ; partage 0,1 + 0,25 : V0).
	Flash = {
		Keys = { 0, 0.6, 1 }, -- L-340
		Times = { 0.1, 0.25 }, -- V0 (total 0,35 s, L-340)
		Style = "Quad", -- V0 : nom d'Enum.EasingStyle (texte : ce fichier se lit aussi hors de Roblox)
	},
}

export type HeistTension = typeof(HeistTension)

return DeepFreeze(HeistTension)
