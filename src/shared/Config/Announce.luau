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
	Hold = 4, -- V0 : s à l'écran par annonce
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
}

-- a486 (économie « B/T », Config/Economy ; V0 d'a486 gardé par le petit chef, 26/11) : ValueMinIncome est « le revenu
-- d'un Mythique de base » ; avec la table 2 (raretés × 60), il suit le revenu de base du Mythique de cette table
-- (800M $/s), remplacé ici, après coup : sinon un Épique (220K $/s) serait annoncé à tout le serveur. Table 1 (ou sans
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
		Announce.ValueMinIncome = mythic
	end
end

return Announce
