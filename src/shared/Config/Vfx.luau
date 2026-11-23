--!strict
-- Effets visuels livrés par Clément et branchés par VfxController (vague 26, liaison L-097 points 6 et 7) :
-- contour du vigile en poursuite, billets et pièces du ramassage, victoire en zone safe, poussière du
-- camion, billboard BB_Rarest du socle de chaque boutique. Notes de Clément : docs/claude/notes/
-- case-ramassage.md, ui-feel-sons-victoire-camion.md, ui-bb-rarest.md.
--
-- Origine des valeurs :
--   « Clément »  écrit dans une de ses notes ou porté par ses modèles (attributs EmitCount, FadeTime,
--                Duration : le code lit d'abord l'attribut, la valeur ici n'est qu'un repli) ;
--   « V0 »       V0 proposé, absent du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Vfx = {
	-- Dossiers des modèles de Clément, depuis ReplicatedStorage (cherchés aussi dans les sous-dossiers).
	FxFolder = { "Assets", "FX" },
	UiFolder = { "Assets", "UI" },

	-- Attributs portés par les modèles de Clément.
	EmitCountAttribute = "EmitCount", -- Clément : sur chaque ParticleEmitter
	FadeTimeAttribute = "FadeTime", -- Clément : sur la lumière de FX_Escape
	DurationAttribute = "Duration", -- Clément : sur le modèle (FX_Escape 2, FX_TruckDust 2,5)
	DefaultEmitCount = 10, -- V0 : émetteur sans EmitCount
	DefaultDuration = 2, -- V0 : modèle sans Duration

	-- VISUAL EFFECTS sur OFF (Config/Settings.VfxReduced) : part des particules gardée pour la victoire et
	-- la poussière du camion (0 = aucune) ; billets et pièces du ramassage coupés. Le contour rouge du
	-- vigile et BB_Rarest restent : ils servent au jeu.
	OffEmitFactor = 0, -- V0, comme Settings.VfxOff.BurstFactor

	-- 1. Contour rouge du vigile qui poursuit le joueur local (L-071), vu de lui seul.
	Chase = {
		Highlight = "FX_ChaseHighlight", -- Clément
		CopyName = "ChaseHighlight", -- V0 : nom de la copie posée dans le vigile
		-- Roblox n'affiche que 31 Highlight : ShelfBoxController garde autant de places en moins pour les
		-- contours des colis tant que le contour du vigile est là (ShelfBoxController.Reserve).
		ReserveKey = "ChaseHighlight",
		Reserve = 1,
	},

	-- 2. Billets et pièces qui jaillissent de la plaque au ramassage (case-ramassage.md, point 3).
	Collect = {
		Bill = "FX_Collect_Bill", -- Clément
		Coin = "FX_Collect_Coin", -- Clément
		MinCount = 5, -- Clément : « 5 à 12 billets ou pièces selon le montant »
		MaxCount = 12, -- Clément
		-- V0 : MinCount + 1 par puissance de 10 au-delà de 10 $ (10 $ → 5, 1 K → 7, 1 M → 10), au plus MaxCount.
		CountBase = 10,
		CoinShare = 0.5, -- V0 : une pièce sur deux (billet, pièce, billet…)
		PopTime = 0.2, -- Clément : jaillit en 0,2 s, vers le haut, au hasard
		PopHeight = { 2, 3.5 }, -- V0 : hauteur du jaillissement (studs)
		PopSpread = 1.5, -- V0 : écart à l'horizontale (studs)
		FlyTime = { 0.4, 0.5 }, -- Clément : 0,4 à 0,5 s, Quad In
		Stagger = 0.04, -- Clément : 0,04 s d'écart
		TargetDepth = 3, -- Clément : point à 3 studs devant la caméra, sous le compteur Cash
		CashLabel = "Cash", -- contrat UI_HUD
		HudScreen = "UI_HUD",
		EndScale = 0.25, -- V0 : taille à l'arrivée (le billet rapetisse)
		-- Sans compteur Cash à l'écran : le billet monte de RiseHeight et s'efface.
		RiseHeight = 4, -- V0
		Spin = 720, -- V0 : degrés par seconde de rotation en vol
		-- a401 (vague GC4), V0 (fiche vidéo de Cantin, 23/11 : docs/references/Encaissement-Base.md, section 6) : billets
		-- en fontaine. Le billet n sort à (n - 1) × Stagger s, jaillit en PopTime s (Quad Out), flotte HoverTime s en
		-- dérivant de Drift studs vers le haut et l'extérieur (Sine Out), puis vole FlyTime ± FlyJitter s (Quad In) vers
		-- le compteur : un billet arrive toutes les Stagger s, dans l'ordre ; chaque arrivée est signalée
		-- (VfxController.OnCollectArrive). Enabled = false : jaillissement de tous ensemble, comme avant (PopTime, FlyTime
		-- de Clément plus haut).
		Fountain = {
			Enabled = true, -- a401 : interrupteur (false = comme avant)
			PopTime = 0.13,
			HoverTime = 0.2,
			Drift = { 0.3, 0.5 },
			FlyTime = 0.35,
			FlyJitter = 0.02,
		},
	},

	-- a401 (vague GC4), V0 (fiche vidéo de Cantin, 23/11, section 4 ; note de Clément case-ramassage.md pour
	-- l'enfoncement) : la plaque CollectPad_xx au ramassage (DisplayController, chez tous les joueurs). Plate passe au
	-- blanc (FlashColor) en FlashIn s (Quad Out) puis revient à sa couleur en FlashOut s (Linear) ; Glow monte à sa
	-- Brightness en FlashIn s puis descend à 0 en FlashOut s ; la plaque descend de SinkDepth (attribut de Clément) en
	-- SinkDown s (Quad Out) en s'élargissant de Squash sur ses deux grands côtés, puis remonte en SinkUp s (Back Out).
	-- Tout revient à l'état d'origine à la fin. Enabled = false : Glow allumé 0,35 s et enfoncement sec, comme avant.
	CollectPad = {
		Enabled = true, -- a401 : interrupteur (false = comme avant)
		FlashColor = Color3.new(1, 1, 1),
		FlashIn = 0.05,
		FlashOut = 0.3,
		SinkDown = 0.06,
		SinkUp = 0.25,
		Squash = 1.08,
	},

	-- 3. Arrivée en zone safe avec un colis (remote BoxSecured, UiFeelController.Escape).
	Escape = {
		Model = "FX_Escape", -- Clément
		FootOffset = 3, -- V0 : du HumanoidRootPart au sol (personnage R15)
	},

	-- 4. Poussière du camion de l'événement à son arrivée et à son départ.
	TruckDust = {
		Model = "FX_TruckDust", -- Clément
		TruckTag = "EventTruck", -- tag de code de TruckEventService
		SpawnedAtAttribute = "SpawnedAt", -- heure serveur de l'apparition (TruckEventService)
		LeftAtAttribute = "LeftAt", -- heure serveur du départ sans explosion (TruckEventService)
		ExplodedAtAttribute = "ExplodedAt", -- TruckEventService : pas de poussière après l'explosion
		ArriveEndsAtAttribute = "ArriveEndsAt", -- a97 : heure serveur de l'impact au sol du camion qui arrive en roulant
		ArriveWindow = 2, -- V0 : un camion vu plus de 2 s après son apparition (streaming) ne soulève rien
	},

	-- 5. BB_Rarest au-dessus du socle de chaque boutique (ui-bb-rarest.md, L-085).
	Rarest = {
		Billboard = "BB_Rarest", -- Clément
		Pedestal = "RarestPedestal", -- Clément (Map/Hub, chaque boutique)
		Plate = "TopPlate",
		Point = "RarestLabelPoint", -- Clément : Attachment du socle
		CopyName = "RarestLabel", -- V0 : nom de la copie posée sur le point
		Slot = "RarestSlot", -- Clément : Attachment du socle où l'objet lui-même est posé (L-118 point 6)
		ItemName = "RarestItem", -- V0 : nom de la copie de l'objet, rangée dans le socle (chez chaque client)
		-- a178 : tag local de cette copie (même nom dans MutationFxController et DisplayController) : effet de
		-- mutation et halo de rareté animés comme sur un présentoir.
		CopyTag = "RarestItem",
		DisplayTag = "DisplayItem", -- tag de code de DisplayService
		ItemsFolder = "DisplayItems", -- dossier de DisplayService dans la parcelle
		Refresh = 1, -- V0 : objet le plus rare revu toutes les secondes
		RaysSpeed = 40, -- V0 (même vitesse que les rayons de UI_Escape, note de Clément) : degrés/s
		CrownSwing = 6, -- V0 : la couronne penche de ± 6°
		CrownPeriod = 2, -- V0 : en 2 s
		MaxDistance = 220, -- V0 : au-delà (caméra), rien n'est animé (MaxDistance de Clément : 200)
		-- a196 (Cantin, T-096) : « BEST ITEM », l'objet exposé qui rapporte le plus (attribut Income de DisplayService :
		-- revenu de l'objet, mutation comprise, sans le M global ni les boosts du moment) ; même revenu : le plus rare.
		-- V0 : "Rarity" = avant a196 (le plus rare, puis le plus gros revenu), Title nil = le texte de Clément.
		Pick = "Income",
		Title = "BEST ITEM", -- Cantin : écrit dans TitleFields (Header de BB_RarestDisplay, Title de BB_Rarest)
		TitleFields = { "Header", "Title" },
		IncomeField = "Income", -- nom proposé à Clément (TextLabel facultatif) : « +$1.2K/s » (Format.income)
		-- V0 : sans Income dans le billboard, le revenu s'écrit dans Odds à la place de la chance (nil : pas de revenu).
		IncomeFallback = "Odds",
	},

	-- 6. Grand socle de l'objet le plus rare devant la boutique (vague 50, a161, L-165 point 5 ; noms proposés
	-- par Clément, pas encore livrés). Présent dans la parcelle, il remplace RarestPedestal ; absent, l'ancien
	-- socle (Rarest, plus haut) marche comme avant. Mêmes réglages de rafraîchissement et d'animation que Rarest.
	RarestDisplay = {
		Model = "RarestDisplay", -- Clément : dans PLOT_Shop
		ItemPoint = "ItemPoint", -- Attachment où l'objet est posé, à sa taille réelle (pivot en bas au centre)
		LabelPoint = "LabelPoint", -- Attachment du billboard
		Billboard = "BB_RarestDisplay", -- Clément (Assets/UI) ; absent : BB_Rarest sur LabelPoint
	},
}

return DeepFreeze(Vfx)
