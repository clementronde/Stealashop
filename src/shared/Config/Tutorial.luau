--!strict
-- Tutoriel de départ (Partie 1, sections 3, 5.11 et 14.2 ; TutorialService).
-- Guidage par flèche au sol et bulle courte (`UI_Tutorial`), jamais de mur de texte.
-- L'étape est sauvegardée (Tutorial.Step, 9.5 : 0 = pas commencé) : un joueur qui
-- part au milieu reprend au même endroit.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Rarities = require(script.Parent.Rarities)

export type Step = {
	Index: number,
	Id: string,
	At: number, -- moment visé depuis l'arrivée, en secondes (section 3) : repère d'équilibrage, pas un minuteur
	Goal: string, -- ce qui se passe à cette étape (section 3) ; note pour l'équipe, jamais affichée
	Bubble: string?, -- texte de la bulle, en anglais (L-036), 8 mots au plus ; V0 proposé, absent du doc
}

local Steps: { Step } = {
	{ Index = 1, Id = "ArriveAtPlot", At = 0, Goal = "Arrivée sur sa parcelle, flèche au sol vers la Supérette", Bubble = "Smash the Mini Mart window!" },
	{ Index = 2, Id = "HitWindow", At = 15, Goal = "Premiers coups aux poings sur la vitre (35 PV)", Bubble = "Hit the glass again and again!" },
	{ Index = 3, Id = "GrabBox", At = 25, Goal = "Casse et chrono de 10 s ; colis Premium, vigile lent", Bubble = "Grab a box and run!" },
	{ Index = 4, Id = "PlaceBox", At = 45, Goal = "Retour en zone safe, colis sur l'établi, attente de 5 s, objet Rare", Bubble = "Put the box on the workbench" },
	{ Index = 5, Id = "DisplayItem", At = 60, Goal = "Objet sur un présentoir (5 $/s), premier encaissement", Bubble = "Display your item to earn cash!" },
	{ Index = 6, Id = "Train", At = 2 * 60, Goal = "Le tapis et le banc s'allument, 30 s d'entraînement guidé", Bubble = "Train on the treadmill and bench" },
	{ Index = 7, Id = "BuyTool", At = 3 * 60, Goal = "Flèche vers la boutique d'armes, clé à molette (300 $)", Bubble = "Buy the Wrench!" },
	{ Index = 8, Id = "BuyAura", At = 4 * 60, Goal = "Flèche vers la boutique d'auras, première aura (500 $)", Bubble = "An aura multiplies your damage!" },
	{ Index = 9, Id = "GoToZone2", At = 5 * 60, Goal = "Objectif affiché : la zone 2 (vitesse 22, dégâts 10)", Bubble = "Next goal: Zone 2!" },
	-- Étape 10 : message de fin du bouclier débutant (texte du doc, voir ShieldEndMessage)
	{ Index = 10, Id = "ShieldEnd", At = 10 * 60, Goal = "Fin du bouclier débutant, la boutique devient braquable", Bubble = nil },
}

local Tutorial = {
	Steps = Steps,
	SkipFromStep = 5, -- bouton Passer à partir de l'étape 5 (TutorialSkip, 9.4)
	BubbleMaxWords = 8,
	FirstStoreDistance = 60, -- flèche vers la Supérette, à 60 studs

	-- 5.11 : résultats garantis
	FirstBoxTier = "Premium" :: Balance.BoxTier,
	GuardSpeed = 12, -- vigile lent du tuto
	OpenDelay = 5, -- attente raccourcie du premier colis
	GuaranteedRarity = "Rare" :: Rarities.RarityId,
	-- Objet du premier colis (catalogue v2, L-045) : le Pot de nouilles, Rare de la zone 1, marqué
	-- TutorialOnly dans Config/Items : il ne sort d'aucun tirage, Items.Pick(1, "Rare") ne le donne
	-- pas. TutorialService le passe en ItemId à StoreHeistService.SetContentOverride (une Rarity
	-- seule tirerait dans la zone, où aucun Rare n'est tirable).
	GuaranteedItemId = "Z1_PotDeNouilles",

	-- Textes écrits dans le doc, traduits en anglais (L-036)
	ShieldEndMessage = "Your shop can now be robbed: keep your bat close!",
	NightBubble = "Night is falling: hurry home!", -- 5.12, pour les nouveaux joueurs

	-- 14.2 : étapes du funnel d'onboarding, envoyées une seule fois par joueur avec
	-- AnalyticsService:LogOnboardingFunnelStepEvent (index = numéro d'étape). En français : l'équipe
	-- les lit dans le Creator Dashboard, le joueur ne les voit pas (L-036)
	FunnelSteps = {
		"Arrivée sur sa parcelle",
		"Premier coup sur une vitrine",
		"Première vitrine cassée",
		"Premier colis volé",
		"Arrivée en zone safe avec le colis",
		"Colis posé sur l'établi",
		"Premier objet révélé",
		"Premier objet exposé",
		"Premier encaissement",
		"Premier achat d'outil",
	},
}

export type Tutorial = typeof(Tutorial)

return DeepFreeze(Tutorial)
