--!strict
-- Config/Announce (vague 73, a254, L-240 point 3) : les annonces à tout le serveur dans l'écran UI_Announce de Clément
-- (Banner, Icon, Message en RichText, Detail ; facultatif au contrat), l'une après l'autre (AnnounceController).
-- Côté serveur, Shared/Announce construit les textes et envoie le remote Announce.
--
-- Les 4 annonces voulues par Clément (2026-11-17) :
--   1. un colis Légendaire ou plus apparu sur un rayon la nuit : seuil, délai et textes dans Config/Unbox
--      (NightBox*, a239), Detail = NightDetail ;
--   2. une caisse rare apparue sur un rayon de jour (la nuit, c'est l'annonce 1) : DayBoxMinRarity, mêmes textes,
--      Detail = DayDetail ;
--   3. un joueur qui vole un objet rare à un autre joueur et le dépose chez lui (pas le bot) : StealMinRarity,
--      StealText, Detail = revenu de l'objet ; envoyée aux autres joueurs (le voleur et la victime ont déjà leur
--      message) ;
--   4. l'achat de la chance du serveur (Config/Monetization.ServerLuck), envoyée à tous : ServerLuckText, Detail =
--      ServerLuckDetail ou ServerLuckQueuedDetail.
-- Enabled = false : tout repart par Notify comme avant (mêmes textes, sans annonce de jour ni de vol).
-- Écran absent chez le joueur : le même texte, sans balises, part dans Notify (repli du client).
-- Tout est V0 (L-240 : seuils et textes à proposer à Clément). Textes en anglais.

local Announce = {
	Enabled = true, -- interrupteur ; false = comme avant (Notify)
	Screen = "UI_Announce",
	NotifyKind = "Announce", -- catégorie du Notify de repli (comme Config/Unbox.AnnounceKind)

	-- Client ------------------------------------------------------------------------------------------------------
	Hold = 4, -- V0 : s à l'écran par annonce (sauf celle du lever du jour : DawnBoxHold)
	Gap = 0.4, -- V0 : s entre deux annonces
	MaxQueue = 4, -- V0 : annonces en attente au plus (au-delà, la plus ancienne en attente part)

	-- Serveur -----------------------------------------------------------------------------------------------------
	-- Couleur d'une rareté dans Message : <font color="#hex">LEGENDARY</font> (Config/Rarities.Color).
	RarityTag = '<font color="#%s">%s</font>',
	BoxIconPrefix = "ICON_BOX_", -- icône d'un colis : ICON_BOX_<Rareté> (L-097)
	ItemIconPrefix = "ICON_", -- icône d'un objet : ICON_<ItemId>

	-- 1 et 2. Colis apparus sur un rayon. {zone} = zone du magasin du plus rare.
	NightDetail = "Zone {zone} · until dawn", -- V0
	DayBoxEnabled = true, -- interrupteur de l'annonce de jour
	DayBoxMinRarity = "Mythic", -- V0 : de jour, seulement Mythique ou plus (la nuit : Unbox.NightBoxMinRarity)
	DayDetail = "Zone {zone} · be quick!", -- V0
	-- a457 (L-335 point 2, Clément 24/11 ; Features.DawnBoxAnnounce / DawnBoxAnnounceDev) : au lever du jour (la nuit se
	-- termine), une seule phrase pour la caisse la plus rare encore sur un rayon (seuil : Unbox.NightBoxMinRarity ; à
	-- égalité, la zone la plus loin), sans Detail ; l'annonce de jour (DayBoxMinRarity) prend la même phrase, et plus
	-- rien n'est annoncé quand les colis apparaissent la nuit. {rarity} = rareté en couleur, {zone} = zone du magasin.
	DawnBoxText = "A {rarity} box is in Zone {zone}!",
	DawnBoxHold = 5, -- s à l'écran pour l'annonce du lever du jour seulement (L-335, Clément 24/11 : « seulement 5 secondes »)
	-- a457 (L-379, Clément 25/11 : « partir au bout de 5 secondes en défilement comme du texte par message ») : au bout de
	-- DawnBoxHold s, le texte Message de l'annonce de l'aube monte et s'efface (AnnounceController), puis l'écran se ferme ;
	-- Message reprend ensuite sa place et sa transparence (le bandeau n'est jamais déplacé). false = fermeture d'avant.
	DawnBoxScroll = true,
	ScrollTime = 0.6, -- V0 : s de la sortie qui défile
	ScrollShift = -1, -- V0 : déplacement vertical de Message, en hauteurs de Message (négatif = vers le haut)

	-- 3. Vol entre joueurs. {thief}, {victim}, {item} ; {rarity} = rareté en couleur, {a} = « a » ou « an ».
	StealEnabled = true,
	StealMinRarity = "Legendary", -- V0 : comme ShelfOpen.AnnounceMinRarity
	StealText = "{thief} stole {a} {rarity} {item} from {victim}!", -- V0 (exemple de Clément)

	-- 4. Chance du serveur. {buyer}, {luck} = « ×8 LUCK » en couleur, {length} = « 15 min », {current} = « ×8 ».
	ServerLuckColor = "2FBF71", -- CardColor de la carte « SERVER LUCK » de Clément (L-240 point 2)
	ServerLuckText = "{buyer} gave the whole server {luck}!", -- V0
	ServerLuckDetail = "Rarer boxes for everyone · {length}", -- V0 (exemple de Clément)
	ServerLuckQueuedDetail = "Starts after the current {current} · {length}", -- V0
	ServerLuckIcon = "UI_Icon_DP_Luck3", -- repli si l'icône du produit n'est pas livrée (L-240 point 2)

	-- 5. a475 (L-372, Clément 25/11) : objets de grande valeur (Features.ValueAnnounce ou ValueAnnounceDev ;
	-- CelebrationService). Valeur = $/s de l'objet, mutation et poids compris (celui de BB_Carry) ; {value} = « $225B/s ».
	-- {player}, {item} (nom précédé de sa mutation), {rarity} = rareté en couleur, {a} = « a » ou « an ».
	ValueMinIncome = 25_000, -- V0 : $/s à partir duquel un objet est annoncé (revenu d'un Mythique de base)
	ValueGap = 10, -- V0 : s au moins entre deux annonces du même genre (ramené ; en fuite) : anti-spam
	-- 5a. Objet ramené en zone safe (rangé par UnboxService, ou volé au bot et déposé) ; un objet volé à un joueur a déjà
	-- l'annonce 3. Envoyée aux autres joueurs (lui a la carte ITEM SECURED) ; SecuredToSelf = true : à lui aussi.
	SecuredText = "{player} got {a} {rarity} {item} worth {value}!", -- V0 (exemple de Clément)
	SecuredDetail = "", -- V0 : sans petite ligne
	SecuredToSelf = false,
	-- 5b. Objet en fuite, dès qu'il est pris (une fois par objet). Envoyée à tous sauf le porteur et sa victime.
	CarryText = "{player} is escaping with {a} {rarity} {item} worth {value}!", -- V0
	CarryDetail = "Catch them before the safe zone!", -- V0
	-- 5c. La valeur dans l'annonce 3 (vol chez un joueur) ; Detail vide (la valeur est dans la phrase).
	StealValueText = "{thief} stole {a} {rarity} {item} worth {value} from {victim}!", -- V0

	-- 6. a522 (L-455, Clément 26/11 : « mettre son dans le serveur de victoire » ; Features.ServerWinSound ou
	-- ServerWinSoundDev ; CelebrationService, ServerWinController) : un objet ramené en zone safe fait entendre aux autres
	-- joueurs un son 3D à l'endroit où le porteur passe la ligne safe (lui garde Heist_Escape, en 2D). Le son est à
	-- Clément (Sound, dans ReplicatedStorage/Assets/Sounds, sous-dossiers compris) ; absent : muet. Le code règle la
	-- portée de la copie jouée (valeurs de L-455) ; Clément règle SoundId et Volume.
	ServerWin = {
		Sound = "Heist_ServerWin", -- L-455 : ReplicatedStorage/Assets/Sounds/Heist/Heist_ServerWin
		Gap = 2, -- L-455 : au plus un son toutes les 2 s sur tout le serveur
		RollOffMode = "InverseTapered", -- L-455
		RollOffMinDistance = 30, -- L-455
		RollOffMaxDistance = 350, -- L-455
		Lifetime = 10, -- V0 : s avant de retirer le point du son, s'il ne finit jamais
	},
}

-- a486 (économie « B/T », Config/Economy ; V0 d'a486 gardé par le petit chef, 26/11) : ValueMinIncome est « le revenu
-- d'un Mythique de base » ; avec la table 2 (raretés × 60), il suit le revenu de base du Mythique de cette table
-- (a497 : celui de la zone 6, 976,6B $/s), remplacé ici, après coup : sinon un Épique (220K $/s) serait annoncé à tout le serveur. Table 1 (ou sans
-- Config/Economy) : la ligne plus haut, 25 000, comme avant.
do
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild("Economy")
	end)
	local ok, economy = false, nil
	if found and module ~= nil then
		ok, economy = pcall(require, module :: any)
	end
	local ECO: any = if ok and type(economy) == "table" then economy.Override else nil
	if type(ECO) == "table" and type(ECO.Version) == "number" then
		local mythic = ECO.Income and ECO.Income.Mythic
		assert(type(mythic) == "number" and mythic > 0, "Config/Announce : Income.Mythic absent de Config/Economy")
		-- a497 (table 2, revenus × 10 par zone) : le Mythique de base est celui de la zone 6 (rang 1 ; Formulas.ItemIncome),
		-- 9 765 625 × 10^5 = 976 562 500 000 $/s.
		local rule = ECO.IncomeRule
		if type(rule) == "table" and type(rule.ZoneFactor) == "number" and type(rule.NoZone) == "number" then
			mythic *= rule.ZoneFactor ^ (rule.NoZone - 1)
		end
		Announce.ValueMinIncome = mythic
	end
end

return Announce
