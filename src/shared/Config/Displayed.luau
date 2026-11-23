--!strict
-- Objets exposés : la réserve et le « +$/s » qui vole (vague 63, a206 ; liaison L-192, réponses de Clément à Q2 et Q3,
-- et L-202 point 4). Lu par DisplayService, InventoryService, DisplayedController et GainController. Sources :
--   « L-192 » / « L-202 » / « L-219 » : la ligne de liaison ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes, pixels (repère de l'écran).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Displayed = {
	-- Réserve (L-192 Q3) : un objet remplacé par « Exposer les meilleurs » y va ; elle est listée dans
	-- UI_Displayed.Panel.Reserve (DisplayedController), d'où DisplayButton le remet sur un présentoir libre.
	ReserveMax = 30, -- V0 : comme Balance.Display.InventoryMax (5.8, objets non exposés) ; au-delà, l'objet reste hors liste
	ReserveAttribute = "DisplayReserve", -- attribut du Player : uids de la réserve, dans l'ordre, séparés par « , »
	-- Vague 66 (a219, L-210 point 2 : « bloqués à vie ») : sans écran d'inventaire, un objet ni exposé ni dans la
	-- réserve ne se voyait nulle part (la barre du bas n'a que quelques cases). V0, propositions à Clément :
	--   ReserveCatchAll : tout objet libre ni exposé, ni au coffre-fort, ni en main entre dans la réserve (au bout,
	--     les plus rentables d'abord, une fois par seconde) ; un objet sous antivol pas encore posé au sol est listé
	--     aussi côté client, avec LockedButtonText sur son bouton, qui lance la pose au sol ;
	--   SwapWhenFull : DisplayButton quand tous les présentoirs sont pris : l'objet prend la place de l'exposé qui
	--     rapporte le moins, qui va dans la réserve (false : « No free display », rien ne bouge).
	ReserveCatchAll = true,
	SwapWhenFull = true,
	LockedButtonText = "PLACE", -- V0 : texte de DisplayButton.DisplayLabel d'un objet sous antivol (anglais, L-036)
	-- Vague 72 (a242, L-219 point 4 ; Cantin, L-231 : « la réserve sort de l'écran des objets exposés ») : false =
	-- UI_Displayed.Panel.Reserve caché et jamais rempli (DisplayedController). Le serveur garde la réserve telle quelle
	-- (ReserveCatchAll, SwapWhenFull, Exposer les meilleurs) : un objet en trop y reste, sans être montré, et
	-- « Exposer les meilleurs » l'en sort dès qu'il rapporte plus qu'un exposé. true : la réserve de la vague 63.
	-- Vague 73 (a255, L-241 point 4, L-248 ; décision de Cantin du 18/11 : « comme Clément ») : true, la réserve revient
	-- sous les objets exposés, titrée INVENTORY par Clément, toujours montrée (vide : son texte ReserveEmpty).
	ShowReserve = true,
	-- Vague 73 (a255, L-241 point 4) : UI_Hotbar.Bar.InventoryButton (la dernière case de la barre du bas) ouvre cet
	-- écran ; sa pastille InventoryAlert s'allume quand un objet est entré dans l'inventaire (la liste Panel.Reserve)
	-- depuis la dernière fois que l'écran était ouvert, et s'éteint à l'ouverture. V0, proposition à Clément.
	-- a293 : ce bouton du sac ouvre UI_Displayed en un seul panneau (liste unique d'a286, DisplayedController : les
	-- objets exposés puis ceux de l'inventaire dans Panel.List, dès que l'écran de Clément n'a plus Panel.Reserve) :
	-- validé par Cantin, 21/11.
	InventoryAlert = true,
	InventoryAlertGrace = 3, -- V0 (s) : à l'arrivée, ce qui entre dans la réserve pendant ce temps n'est pas « nouveau »
	-- Vague 75 (a260, L-262 point 3, Clément : « Oui ») : UI_Displayed entre dans ce ScreenGroup (attribut posé par le code
	-- si Clément n'en a pas mis) : un autre menu qui s'ouvre le ferme, et il ferme les autres menus. "" : hors groupe.
	ScreenGroup = "Menu",
	-- a314 (L-292, L-271) : bouton SellButton de chaque ligne et confirmation Confirm (YES / NO). Le prix vient du serveur
	-- (PawnShopService, même prix qu'au comptoir du receleur), écrit dans Confirm.SellPrice. Textes en anglais, comme la
	-- maquette de Clément (« for $0 »).
	Sell = {
		PriceText = "for %s", -- prix en Format.money (« for $1.2K »)
		WaitText = "for ...", -- V0 : en attendant le prix du serveur (YesButton ne vend pas encore)
	},

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
