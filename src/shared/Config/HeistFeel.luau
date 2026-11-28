--!strict
-- Capture, alerte et gains qui volent (vague 59, a192 ; liaison L-184 points 1 à 4, L-182 point 9 ; analyse de
-- Clément « 2026-11-15_JeuAnimaux_C_analyse_*.md »). Lu par CatchSceneController, ChaseController,
-- ChaseFeelController, Controllers/UI/HudMask et GainController. Aucune règle de jeu ici : seulement ce que le
-- joueur voit et entend. Sources :
--   « L-184 » / « L-182 » : la ligne de liaison (durées « environ ») ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes, studs, pixels (repère de l'écran), degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a524 : module de Config chargé s'il est là (bancs à liste de modules fixe), comme Config/Outlines.
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

local HeistFeel = {
	-- 1. Capture mise en scène (CatchSceneController, remote CatchScene de GuardService, au coup du vigile :
	-- marqueur Impact de Catch, ou délai de secours). Tout tient dans l'étourdissement (Balance.Guard.CatchStunDuration).
	Catch = {
		Screen = "UI_Caught", -- V0 : écran de Clément (facultatif ; sans lui, un écran V0 du code, même noms)
		V0Screen = "UI_Caught_V0", -- V0 : nom de l'écran de repli créé par le code
		DiveTime = 0.13, -- L-184 : la caméra plonge vers le joueur
		DiveDistance = 7, -- V0 : distance de la caméra au joueur à la fin du plongeon (à l'horizontale)
		DiveHeight = -1.2, -- V0 : hauteur de la caméra par rapport au HumanoidRootPart (plan bas)
		LookHeight = 0.6, -- V0 : point visé au-dessus du HumanoidRootPart
		LowHold = 0.4, -- L-184 : plan bas
		LowDrift = 0.8, -- V0 : la caméra avance encore de 0,8 stud pendant le plan bas
		StampTime = 0.13, -- L-182 (Stamp) : « CAUGHT! » de 1,6 à 1 et de −5° à 0
		StampFrom = 1.6,
		StampTilt = -5,
		ItemFlyTime = 0.6, -- V0 : l'icône de l'objet repart vers son présentoir (ou tombe)
		ItemFlyRise = 0.35, -- V0 : en part de la hauteur de l'écran, vers le haut (retour au rayon)
		ItemDropFall = 0.25, -- V0 : en part de la hauteur de l'écran, vers le bas (objet tombé au sol)
		StampHold = 1.2, -- V0 : avec un renvoi à la base, « CAUGHT! » reste 1,2 s après l'ouverture des bandes
		SceneTime = 2.2, -- V0 : fin de la scène (caméra rendue, HUD revenu), avant la fin de l'étourdissement (2,4)
		OutTime = 0.15, -- V0 : l'écran s'efface
		SlamDelay = 0.1, -- L-184 : claquement environ 0,1 s après le contact
		SlamSound = "Catch_Slam", -- V0 : son facultatif (Assets/Sounds, sous-dossiers compris)
		Dust = "FX_Catch_Dust", -- V0 : effet facultatif de Clément (Assets/FX) : Attachment, Part ou Model avec des ParticleEmitter
		DustEmit = 24, -- V0 : particules par émetteur (attribut EmitCount d'un émetteur, s'il y en a un, passe avant)
		DustLife = 3, -- V0 : la copie de l'effet est détruite au bout de 3 s
		-- La nuit (et le policier) : bandes noires qui cachent le renvoi à la base (L-184).
		BandsClose = 0.25, -- V0 : les bandes se ferment juste avant le renvoi
		BandsHold = 0.25, -- V0 : noir après le renvoi (la caméra est rendue pendant ce temps)
		BandsOpen = 0.3, -- V0
		SafetyMax = 8, -- V0 : une scène ne dure jamais plus (renvoi très tardif, arrestation longue)
	},

	-- 2. Alerte en deux paliers (ChaseController, UI_Chase) : pendant le braquage, tant que personne ne poursuit le
	-- joueur, seul UI_Chase.HeistHint (texte jaune de Clément, facultatif) est montré ; poursuivi : RUN! et les bords.
	Alert = {
		Hint = "HeistHint", -- V0 : nom proposé à Clément, dans UI_Chase
	},

	-- 3. Poursuite (ChaseFeelController) : tout le HUD est masqué sauf ce qui suit (L-182 point 9), puis rendu.
	ChaseMask = {
		KeepScreens = { "UI_Chase" }, -- RUN!, les bords
		Hud = "UI_HUD",
		KeepHud = { "HeistTimer" }, -- le chrono (V0 : GuardMeter est caché depuis le 13/11)
	},
	-- Écrans jamais masqués (messages et alertes du serveur, tutoriel, admin) : V0.
	NeverMask = { "UI_Notify", "UI_Toast", "UI_TheftAlert", "UI_Tutorial", "UI_Admin", "UI_Loading" },
	MaskRefresh = 0.2, -- V0 : écrans revus toutes les 0,2 s (copie neuve, ResetOnSpawn)
	-- Le vigile qui poursuit en rouge (L-182 point 9) : un Highlight du client, chez ce joueur seulement.
	Highlight = {
		Name = "ChaseHighlight", -- V0
		FillColor = Color3.fromRGB(255, 40, 40), -- V0
		FillTransparency = 0.6, -- V0
		OutlineColor = Color3.fromRGB(255, 0, 0), -- V0
		OutlineTransparency = 0, -- V0
	},

	-- 4. Gains ponctuels qui volent (GainController) : récompenses (UI_Rewards ouvert) et index (UI_Index* ouvert),
	-- jamais les revenus de la base (plaques, encaissement automatique, hors ligne).
	BillFly = {
		From = { X = 0.5, Y = 0.5 }, -- V0 : départ, au centre de l'écran
		RiseTime = 0.43, -- L-184 : le « +$ » monte
		Rise = 40, -- V0 (px)
		Pause = 0.15, -- L-184 : courte pause
		FlyTime = 0.45, -- L-447 (Mouvements_UI, règle 6 ; avant 0,47, L-184) : les billets volent vers le compteur, Quad In
		Bills = 6, -- V0
		Stagger = 0.03, -- V0 : écart entre deux billets
		Spread = 36, -- V0 (px) : dispersion au départ
		EndScale = 0.5, -- V0 : taille à l'arrivée
		TargetOffsetX = 20, -- comme UiMotion.CashFly
		FadeTime = 0.25, -- V0 : le « +$ » s'efface quand les billets partent
		Sound = "Cash_Collect", -- comme UiMotion.CashFly.Sound, une fois à l'arrivée
		IndexPrefix = "UI_Index", -- écrans de l'index (UI_Index, UI_Index_v3…)
		-- a524 (L-447, Features.GainFlyToCounter / GainFlyToCounterDev) : les billets s'écartent d'abord jusqu'à leur place
		-- au hasard (Spread) en SpreadTime s (Quad Out) avant de voler ; à l'arrivée du premier, IconPop.Name de CashRow
		-- rebondit de IconPop.From à 1 en IconPop.Time s (Back Out) ; les gains hors ligne réclamés ont aussi leurs billets.
		-- Coupé : billets posés d'un coup à leur place et qui volent tout de suite, sans rebond, hors ligne sans billets.
		SpreadEnabled = Features.GainFlyToCounter == true or (Features.GainFlyToCounterDev == true and ProductIds.IsDev == true),
		SpreadTime = 0.28, -- L-447
		IconPop = {
			Name = "CashIcon", -- UI_HUD, enfant de CashRow (Frame de Clément) ; absent : pas de rebond
			From = 1.25, -- L-447
			Time = 0.15, -- L-447, Back Out
		},
	},

	-- 5. « ITEM SECURED! » en carte (CatchSceneController, remote ItemSecured, éléments facultatifs de UI_Escape).
	Card = {
		NewWindow = 3, -- V0 : objet entré dans l'index moins de 3 s avant (ou après) : « NEW! »
	},
}

export type HeistFeel = typeof(HeistFeel)

return DeepFreeze(HeistFeel)
