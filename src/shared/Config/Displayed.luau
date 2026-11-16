--!strict
-- Objets exposés : la réserve et le « +$/s » qui vole (vague 63, a206 ; liaison L-192, réponses de Clément à Q2 et Q3,
-- et L-202 point 4). Lu par DisplayService, InventoryService, DisplayedController et GainController. Sources :
--   « L-192 » / « L-202 » : la ligne de liaison ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes, pixels (repère de l'écran).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Displayed = {
	-- Réserve (L-192 Q3) : un objet remplacé par « Exposer les meilleurs » y va ; elle est listée dans
	-- UI_Displayed.Panel.Reserve (DisplayedController), d'où DisplayButton le remet sur un présentoir libre.
	ReserveMax = 30, -- V0 : comme Balance.Display.InventoryMax (5.8, objets non exposés) ; au-delà, l'objet reste hors liste
	ReserveAttribute = "DisplayReserve", -- attribut du Player : uids de la réserve, dans l'ordre, séparés par « , »

	-- « +$X/s » de l'objet qui vole de son présentoir jusqu'à l'argent du HUD (L-192 Q2), une fois par pose
	-- (à la main, « Exposer les meilleurs », depuis la réserve), jamais pendant une poursuite (GainController).
	IncomeFly = {
		PopFrom = 0.4, -- V0 : taille au départ (UIScale), comme UiMotion.CounterPop.From
		PopTime = 0.22, -- V0 : il surgit, comme UiMotion.CashFly.PopTime
		Hold = 0.35, -- V0 : il reste au-dessus du présentoir
		FlyTime = 0.55, -- V0 : il vole jusqu'au nombre Cash
		EndScale = 0.5, -- V0 : taille à l'arrivée
		TargetOffsetX = 20, -- comme UiMotion.CashFly.TargetOffsetX
		Lift = 3, -- V0 (studs) : départ au-dessus du point de pose (pivot de l'objet)
		Stagger = 0.12, -- V0 : écart entre deux vols d'un même « Exposer les meilleurs »
		ModelWait = 0.5, -- V0 : attente du modèle de l'objet sur son présentoir (réplication), sinon départ du joueur
		Color = Color3.fromHex("#35C93B"), -- vert « acheter / OK » de la planche 10.6, pour le repli sans GainPop
		Sound = "Cash_Collect", -- comme UiMotion.CashFly.Sound, une fois à l'arrivée
	},
}

return DeepFreeze(Displayed)
