--!strict
-- DisplayedController (vague 59, a191 ; L-182 point 6, L-183 ; vague 63, a206 : L-192 Q3 et Q4, L-202 point 4 ;
-- client) : panneau « Mes objets exposés » et sa réserve, écran UI_Displayed de Clément (nom gardé, L-192 Q4). Sans
-- l'écran, rien ne se passe (une ligne dans la sortie en Studio). Il glisse depuis le bord droit : attribut Appear =
-- SlideRight de Dock (L-202), joué par le module d'animations d'UI, pas ici.
--
-- Rôle :
--   - ouverture : DisplayedController.Toggle() (appelé par le HUD, UI_HUD.RightRail.DisplayedButton, a190) allume
--     et éteint l'ÉCRAN ENTIER (Enabled) ; CloseButton l'éteint. Vague 63 : plus d'OpenButton (L-202 point 4) ;
--   - Panel.List : une ligne par objet exposé de la base, clonée depuis List.Template (Row_<nn>_<uid>, rangées
--     du meilleur revenu au moins bon, puis par présentoir) : Icon = ICON_<ItemId>, IconBack à la couleur de la
--     rareté, RarityChip.RarityLabel = sa rareté (« LEGENDARY »), ItemName, Income « +$1.2K/s » (revenu de l'objet,
--     mutation comprise, sans les bonus du joueur), attribut Rarity sur la ligne (dégradés du module d'animations).
--     Vague 63 : ItemName et RarityChip.RarityLabel à la couleur de la rareté (TextColor3, puis Controllers/UI/
--     RarityFx : dégradé, reflet du Légendaire, arc-en-ciel du Mythique et plus) ; le fond de RarityChip n'est plus
--     touché (transparent chez Clément). RemoveButton → remote UnplaceItem(uid) : l'objet quitte son présentoir et
--     revient DANS LA MAIN, ou dans la réserve si les mains sont prises (InventoryService, règle de Clément) ;
--   - Panel.DisplayCount.CountLabel « 3/8 » (exposés / présentoirs débloqués) ;
--   - DisplayBestButton → remote EquipBest (« Exposer les meilleurs ») : le SERVEUR remplit les présentoirs
--     débloqués avec les objets possédés qui rapportent le plus (DisplayService.EquipBest) ; un objet exposé
--     moins bon va dans la réserve. Un appel par seconde au plus (Net, et ici pour ne rien perdre) ;
--   - vague 63, réserve (L-192 Q3, noms de L-202) : Panel.Reserve, caché quand la réserve est vide ;
--     Reserve.ReserveCount.ReserveCountLabel = le nombre d'objets en réserve ; Reserve.ReserveList.Template cloné
--     par objet (Reserve_<nn>_<uid>, du meilleur revenu au moins bon) : IconBack à la couleur de la rareté, Icon,
--     ItemName (couleur de la rareté), Income, attribut Rarity ; DisplayButton → remote PlaceFromReserve(uid) :
--     le serveur le pose sur un présentoir libre (sinon « No free display », rien ne bouge). Sans Reserve dans
--     l'écran : la réserve n'est pas montrée, rien ne casse.
--   - vague 66 (a219, L-210 point 2, Config/Displayed) : le serveur met dans la réserve tout objet ni exposé ni en
--     main (ReserveCatchAll) et échange avec l'exposé le moins rentable quand tout est pris (SwapWhenFull) ; ici, un
--     objet sous antivol pas encore posé au sol est listé à la suite, DisplayButton.DisplayLabel = LockedButtonText
--     (« PLACE ») : le bouton ferme le panneau et lance la pose au sol (InventoryController.PlaceItem).
--   - vague 72 (a242, L-219 point 4, L-231) : le bouton inventaire du HUD (toujours UI_HUD.DisplayedButton) ouvre cet
--     écran ; la réserve en sort (Config/Displayed.ShowReserve = false : Panel.Reserve caché, jamais rempli ; le serveur
--     la garde). CloseArrowButton (la flèche vers la droite, facultative) ferme comme CloseButton (la croix, repli).
--     Les lignes ne sont refaites que si ce qu'elles montrent change : un clic n'est plus perdu sur une ligne refaite
--     entre l'appui et le relâché.
--   - vague 73 (a255, L-241 point 4, L-248 ; décision de Cantin du 18/11) : la réserve revient sous les objets exposés
--     (ShowReserve = true ; Clément l'a titrée INVENTORY) et reste montrée même vide (L-213 point 4) : Panel.Reserve
--     n'est plus caché, seul son texte Reserve.ReserveEmpty (facultatif) est montré quand elle est vide et caché sinon.
--     UI_Hotbar.Bar.InventoryButton (la dernière case de la barre du bas, facultatif) ouvre et ferme l'écran comme le
--     bouton du HUD ; sa pastille InventoryAlert (UI/AlertBadge) s'allume quand un objet est entré dans la réserve
--     depuis la dernière ouverture (Config/Displayed.InventoryAlert). Toggle suit l'écran réel : un écran éteint par
--     un autre code s'ouvre au clic au lieu de demander un second clic.
--   - vague 75 (a260, L-262 point 3) : l'écran est du groupe « Menu » (attribut ScreenGroup, posé ici si Clément n'en a
--     pas mis ; Config/Displayed.ScreenGroup) : un autre menu qui s'ouvre le ferme, et il ferme les autres menus.
--   - a286 (Clément, 19/11 : « on fait tout à la ligne ») : liste unique, quand Panel.Reserve n'existe plus et que
--     List.Template porte un DisplayButton (tools/clement/ui_displayed_une_liste.luau) : les objets exposés d'abord
--     (Row_<nn>_<uid>, RemoveButton montré, DisplayButton caché), puis ceux de la réserve dans la même Panel.List
--     (Reserve_<nn>_<uid>, LayoutOrder à la suite, DisplayButton montré, RemoveButton caché, mêmes clics qu'avant) ;
--     Panel.ListEmpty (facultatif) montré quand il n'y a aucun objet. Avec Panel.Reserve, rien ne change.
--   - a314 (L-292, L-271 ; maquette de Clément du 23/11) : vendre depuis la ligne. SellButton (facultatif, dans
--     Template.Buttons comme RemoveButton et DisplayButton : les noms sont cherchés parmi les descendants, l'ancien
--     emplacement marche aussi) est montré sur CHAQUE ligne, objet exposé comme objet de la réserve (sous antivol
--     compris : le serveur applique la règle du receleur). Un clic remplit Dock.Confirm (facultatif, caché) :
--     ItemSlot.ItemIcon = icône de l'objet, ItemRarity et ItemName à la couleur de la rareté (comme la ligne),
--     SellPrice = « for ... » puis « for $X » quand le serveur a donné le prix (remote DisplayedSellAsk →
--     DisplayedSellPrice, PawnShopService : le prix du comptoir du receleur), et le montre. YesButton (seulement une
--     fois le prix reçu) → remote DisplayedSell ; à la réponse DisplayedSold, Confirm se cache et, vendu, la ligne
--     disparaît (puis la liste suit l'état de l'inventaire). NoButton, CloseButton, la fermeture de l'écran ou un
--     refus du serveur : Confirm se cache, rien ne change. Survol et clic : UiFeelController et Motion, comme les
--     autres boutons.
--   - a478 (L-380, Clément 25/11 : « le bouton inventaire n'ouvre pas le display ») : avec Config/Displayed.InventoryScreen
--     (Features.InventoryScreen, ou InventoryScreenDev dans le jeu DEV) et l'écran UI_Inventory dans PlayerGui,
--     UI_Hotbar.Bar.InventoryButton ouvre et ferme l'inventaire (InventoryController.Toggle) au lieu de cet écran, qui
--     s'ouvre alors par RightRail.DisplayedButton seul (L-364). Sans UI_Inventory, ou interrupteur coupé : comme avant.
--     La pastille InventoryAlert du bouton compte alors comme vu ce qui entre pendant que l'inventaire est ouvert.
-- Tout vient des attributs du Player posés par le serveur : InventoryState (Shared/InventoryState,
-- InventoryService), DisplaySlotsUnlocked et DisplayReserve (DisplayService). Le client ne décide rien.
-- Seuls sont touchés : Enabled de l'écran, son attribut ScreenGroup s'il n'en a pas (vague 75), Visible de
-- Panel.Reserve, les lignes clonées (taille du Template gardée), leurs textes (a286 : et, en liste unique, Visible de
-- leurs RemoveButton et DisplayButton et de Panel.ListEmpty), la couleur de leurs textes
-- ItemName et RarityLabel, l'image de leur icône et la couleur de fond d'IconBack ; a314 : Visible de leur SellButton et
-- de Confirm, l'image de Confirm.ItemIcon, le texte et la couleur de Confirm.ItemRarity, ItemName et SellPrice.
--
-- API (client) :
--   DisplayedController.Open() / Close() / Toggle()
--   DisplayedController.IsOpen() -> boolean
--   DisplayedController.DisplayBest()          comme DisplayBestButton
--   DisplayedController.Remove(itemUid)        comme le RemoveButton d'une ligne
--   DisplayedController.Display(itemUid)       comme le DisplayButton d'une ligne de la réserve (vague 63)
--   DisplayedController.GetReserve() -> { string }   uids de la réserve, dans l'ordre du serveur (bancs)
--   DisplayedController.IsAlertOn() -> boolean       pastille InventoryAlert de la barre du bas allumée (vague 73)
--   DisplayedController.Sell(itemUid)          a314 : comme le SellButton d'une ligne (ouvre la confirmation)
--   DisplayedController.ConfirmSell()          a314 : comme YesButton ; CancelSell() : comme NoButton
--   DisplayedController.GetSellState() -> { Uid: string?, Price: number?, Sending: boolean, Shown: boolean }   (bancs)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local DisplayedConfig = require(Config:WaitForChild("Displayed"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion")) -- vague 75 : groupe « Menu »

type Entry = InventoryState.ItemEntry
type RarityFxApi = { Apply: (target: GuiObject, rarityId: string?) -> string? }

type Screen = {
	gui: ScreenGui,
	countLabel: Instance?,
	template: GuiObject?,
	rows: { GuiObject },
	reserve: GuiObject?, -- Panel.Reserve (vague 63)
	reserveCount: Instance?,
	reserveTemplate: GuiObject?,
	reserveRows: { GuiObject },
	reserveEmpty: GuiObject?, -- vague 73 : Reserve.ReserveEmpty, montré seulement quand la réserve est vide
	-- a286 : liste unique (script de Clément du 19/11) : pas de Panel.Reserve, List.Template porte DisplayButton ; la
	-- réserve suit les objets exposés dans Panel.List, Panel.ListEmpty montré quand il n'y a aucun objet.
	single: boolean,
	listEmpty: GuiObject?,
	rowsKey: string?, -- vague 72 : ce que montrent les lignes (refaites seulement s'il change)
	reserveKey: string?,
	confirm: GuiObject?, -- a314 : Dock.Confirm, la confirmation de vente (facultative)
	connections: { RBXScriptConnection },
}

-- a314 : vente en cours de confirmation (uid de l'objet, prix donné par le serveur, demande de vente partie).
type SellState = {
	uid: string,
	price: number?,
	sending: boolean,
}

local SCREEN = "UI_Displayed"
local ROW_FORMAT = "Row_%02d_%s" -- nom des lignes clonées (jamais « Template »)
local RESERVE_ROW_FORMAT = "Reserve_%02d_%s" -- vague 63 : lignes de la réserve
local COUNT_TEXT = "%d/%d" -- V0 proposé, absent du doc : « 3/8 »
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked" -- DisplayService
local RESERVE_ATTRIBUTE = DisplayedConfig.ReserveAttribute -- DisplayService (vague 63)
local SHOW_RESERVE = DisplayedConfig.ShowReserve ~= false -- vague 72 (a242, L-231) : réserve montrée dans l'écran
local CLOSE_ARROW = "CloseArrowButton" -- vague 72 (L-219 point 4) : la flèche vers la droite, nom proposé à Clément
-- Vague 73 (a255, L-241 point 4) : la case Inventory de la barre du bas et sa pastille.
local HOTBAR = "UI_Hotbar"
local GROUP_ATTRIBUTE = "ScreenGroup" -- vague 75 : même nom que Controllers/UI/Motion
local HOTBAR_BUTTON = "InventoryButton"
local HOTBAR_ALERT = "InventoryAlert"
local RESERVE_EMPTY = "ReserveEmpty"
local LIST_EMPTY = "ListEmpty" -- a286 : texte de la liste unique vide
-- a314 (L-292) : noms de la maquette de Clément.
local SELL_BUTTON = "SellButton"
local CONFIRM = "Confirm"
local SELL_TEXTS = DisplayedConfig.Sell or { PriceText = "for %s", WaitText = "for ..." }
-- V0 proposé, absent du doc : attente minimale entre deux demandes (Net en accepte une par seconde pour
-- EquipBest ; quatre par seconde pour UnplaceItem et PlaceFromReserve).
local BEST_COOLDOWN = 1
local REMOVE_COOLDOWN = 0.3

local IS_STUDIO = RunService:IsStudio()

local DisplayedController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local net: any = nil
local lastBest = -math.huge
local lastSend: { [string]: number } = {}
local reported: { [string]: boolean } = {}
-- Vague 73 : boutons Inventory de la barre du bas, leurs pastilles, et les objets de la réserve déjà vus (nil tant que
-- l'inventaire et la réserve ne sont pas arrivés du serveur ; jusqu'à seenUntil, tout ce qui y entre est vu).
local hotbarConnections: { RBXScriptConnection } = {}
local hotbarAlerts: { GuiObject } = {}
local seen: { [string]: boolean }? = nil
local seenUntil = 0
local selling: SellState? = nil -- a314

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

-- Vague 63 : Controllers/UI/RarityFx (module d'aide, facultatif : sans lui, la couleur unie de la rareté).
local rarityFx: RarityFxApi? = nil
do
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("RarityFx") else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			rarityFx = result :: any
		end
	end
end

local function guiObject(root: Instance, path: string): GuiObject?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function setText(element: Instance?, text: string)
	if element == nil then
		return
	end
	local holder: Instance? = element
	if not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		holder = element:FindFirstChildWhichIsA("TextLabel", true)
	end
	if holder and (holder :: any).Text ~= text then
		(holder :: any).Text = text
	end
end

-- Vague 63 (L-202) : texte à la couleur de la rareté, puis son effet (RarityFx), comme dans Figma.
local function paintText(element: Instance?, rarityId: string, color: Color3)
	if element == nil or not (element:IsA("TextLabel") or element:IsA("TextButton")) then
		return
	end
	(element :: any).TextColor3 = color
	local fx = rarityFx
	if fx then
		pcall(fx.Apply, element :: GuiObject, rarityId)
	end
end

local function onClick(element: Instance?, handler: () -> ()): RBXScriptConnection?
	if element and element:IsA("GuiButton") then
		return Motion.Activated(element :: GuiButton):Connect(function()
			handler()
		end)
	end
	return nil
end

local function inventory(): { Entry }
	return InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute)).Items
end

-- Objets exposés, du meilleur revenu au moins bon (puis par présentoir).
local function exposed(items: { Entry }): { Entry }
	local list: { Entry } = {}
	for _, entry in items do
		if entry.Slot ~= nil and Items.ById[entry.ItemId] ~= nil then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return (a.Slot or 0) < (b.Slot or 0)
	end)
	return list
end

-- Uids de la réserve (attribut DisplayReserve, dans l'ordre du serveur).
local function reserveUids(): { string }
	local list: { string } = {}
	local text = localPlayer:GetAttribute(RESERVE_ATTRIBUTE)
	if type(text) == "string" then
		for uid in string.gmatch(text, "[^,]+") do
			if InventoryState.IsSafeId(uid) then
				table.insert(list, uid)
			end
		end
	end
	return list
end

-- Objets de la réserve connus de l'état de l'inventaire (pas exposés), du meilleur revenu au moins bon, puis dans
-- l'ordre du serveur.
local function reserved(items: { Entry }): { Entry }
	local byUid: { [string]: Entry } = {}
	for _, entry in items do
		if entry.Slot == nil and Items.ById[entry.ItemId] ~= nil then
			byUid[entry.Uid] = entry
		end
	end
	local rank: { [string]: number } = {}
	local list: { Entry } = {}
	local count = 0
	for _, uid in reserveUids() do
		local entry = byUid[uid]
		if entry and rank[uid] == nil then
			count += 1
			rank[uid] = count
			table.insert(list, entry)
		end
	end
	-- Vague 66 (a219, L-210 point 2, Config/Displayed.ReserveCatchAll) : un objet sous antivol pas encore posé au sol
	-- (seul cas où l'état le montre) est listé aussi : son bouton lance la pose au sol (plus haut, buildReserve).
	if DisplayedConfig.ReserveCatchAll == true then
		for _, entry in items do
			if entry.AntiTheft == true and rank[entry.Uid] == nil and byUid[entry.Uid] ~= nil then
				count += 1
				rank[entry.Uid] = count
				table.insert(list, entry)
			end
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return rank[a.Uid] < rank[b.Uid]
	end)
	return list
end

local function unlockedSlots(): number
	local value = localPlayer:GetAttribute(SLOTS_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

local function clearRows(rows: { GuiObject })
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
end

local function clearAll(current: Screen)
	clearRows(current.rows)
	clearRows(current.reserveRows)
	current.rowsKey = nil
	current.reserveKey = nil
end

-- Vague 72 : ce que montrent les lignes de `list` (ordre, objet, revenu, antivol).
local function keyOf(list: { Entry }): string
	local parts = table.create(#list)
	for _, entry in list do
		table.insert(parts, `{entry.Uid}:{entry.ItemId}:{entry.Income}:{entry.AntiTheft == true}`)
	end
	return table.concat(parts, ",")
end

-- Une demande au serveur (remote `name`, un uid), au plus une par REMOVE_COOLDOWN s et par uid.
local function send(name: string, uid: string)
	local key = name .. ":" .. uid
	local now = os.clock()
	if now - (lastSend[key] or -math.huge) < REMOVE_COOLDOWN then
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	lastSend[key] = now
	net.Client[name]:Fire(uid)
end

-- Une copie de `template` pour `entry` (nom, ordre, icône, couleurs, textes), ou nil.
local function cloneRow(template: GuiObject, format: string, rank: number, entry: Entry): GuiObject?
	local found = Items.ById[entry.ItemId]
	if found == nil then
		return nil
	end
	local item: Items.Item = found
	local clone: Instance? = template:Clone()
	if clone == nil then
		return nil -- Archivable = false : rien à cloner
	end
	local row = clone :: GuiObject
	row.Name = string.format(format, rank, entry.Uid)
	row.LayoutOrder = rank
	row:SetAttribute("Rarity", item.Rarity)
	local rarity = Rarities.ById[item.Rarity]
	local color = if rarity then rarity.Color else Color3.new(1, 1, 1)
	local icon = Find.path(row, "Icon")
	local texture = Icons.get(item.Id)
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and texture then
		(icon :: any).Image = texture
	end
	local back = guiObject(row, "IconBack")
	if back then
		back.BackgroundColor3 = color
	end
	setText(Find.path(row, "RarityChip.RarityLabel"), if rarity then rarity.DisplayNameUpper else item.Rarity)
	setText(Find.path(row, "ItemName"), item.DisplayName)
	setText(Find.path(row, "Income"), Format.income(entry.Income))
	paintText(Find.path(row, "ItemName"), item.Rarity, color)
	paintText(Find.path(row, "RarityChip.RarityLabel"), item.Rarity, color)
	return row
end

-- a286 (liste unique) : une ligne montre RemoveButton (objet exposé, `exposedRow`) ou DisplayButton (réserve).
local function showButtons(row: GuiObject, exposedRow: boolean)
	local remove = guiObject(row, "RemoveButton")
	if remove then
		remove.Visible = exposedRow
	end
	local display = guiObject(row, "DisplayButton")
	if display then
		display.Visible = not exposedRow
	end
end

------------------------------------------------------------------------------
-- a314 : vente depuis la ligne, avec la confirmation Confirm (YES / NO)
------------------------------------------------------------------------------

local function confirmShown(): boolean
	local current = screen
	local confirm = if current then current.confirm else nil
	return confirm ~= nil and confirm.Visible
end

-- Confirm se cache, la vente en cours est oubliée (rien n'est demandé au serveur).
local function hideConfirm()
	selling = nil
	local current = screen
	local confirm = if current then current.confirm else nil
	if confirm and confirm.Visible then
		confirm.Visible = false
	end
end

local function writePrice(price: number?)
	local current = screen
	local confirm = if current then current.confirm else nil
	if confirm == nil then
		return
	end
	local text = if price then string.format(SELL_TEXTS.PriceText, Format.money(price)) else SELL_TEXTS.WaitText
	setText(Find.path(confirm, "SellPrice"), text)
end

-- SellButton d'une ligne : Confirm rempli pour `entry` et montré ; le prix est demandé au serveur.
local function openConfirm(entry: Entry)
	local current = screen
	local found = Items.ById[entry.ItemId]
	if current == nil or found == nil then
		return
	end
	local confirm = current.confirm
	if confirm == nil then
		reportOnce("confirm", `[Displayed] {SCREEN}.Confirm introuvable : un objet ne se vend pas depuis le panneau`)
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	local item: Items.Item = found
	local rarity = Rarities.ById[item.Rarity]
	local color = if rarity then rarity.Color else Color3.new(1, 1, 1)
	local icon = Find.path(confirm, "ItemIcon")
	local texture = Icons.get(item.Id)
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and texture then
		(icon :: any).Image = texture
	end
	local rarityLabel = Find.path(confirm, "ItemRarity")
	local nameLabel = Find.path(confirm, "ItemName")
	setText(rarityLabel, if rarity then rarity.DisplayNameUpper else item.Rarity)
	setText(nameLabel, item.DisplayName)
	paintText(rarityLabel, item.Rarity, color)
	paintText(nameLabel, item.Rarity, color)
	selling = { uid = entry.Uid, price = nil, sending = false }
	writePrice(nil)
	if not confirm.Visible then
		confirm.Visible = true
		pcall(Motion.Show, confirm)
	end
	net.Client.DisplayedSellAsk:Fire(entry.Uid)
end

-- YesButton : la vente part, une fois le prix du serveur reçu (et une seule fois).
local function confirmSell()
	local state = selling
	if state == nil or state.price == nil or state.sending or net == nil then
		return
	end
	state.sending = true
	net.Client.DisplayedSell:Fire(state.uid)
end

-- Réponse à DisplayedSellAsk : le prix s'écrit ; objet invendable : Confirm se cache.
local function onSellPrice(uid: string, price: number, sellable: boolean)
	local state = selling
	if state == nil or state.uid ~= uid then
		return
	end
	if not sellable then
		hideConfirm()
		return
	end
	state.price = price
	writePrice(price)
end

-- La ligne de l'objet `uid` (exposé ou de la réserve), cachée tout de suite ; la liste suit ensuite l'inventaire.
local function hideRow(uid: string)
	local current = screen
	if current == nil then
		return
	end
	for _, rows in { current.rows, current.reserveRows } do
		for _, row in rows do
			local name = row.Name
			if string.sub(name, -#uid - 1) == "_" .. uid then
				row.Visible = false
			end
		end
	end
end

-- Réponse à DisplayedSell : Confirm se cache ; vendu, la ligne disparaît.
local function onSold(uid: string, _amount: number, sold: boolean)
	local state = selling
	if state == nil or state.uid ~= uid then
		return
	end
	hideConfirm()
	if sold then
		hideRow(uid)
	end
end

local function wireSell(row: GuiObject, entry: Entry)
	local button = guiObject(row, SELL_BUTTON)
	if button == nil then
		return
	end
	button.Visible = true
	local _ = onClick(button, function()
		openConfirm(entry) -- détruite avec la ligne
	end)
end

local function buildRows(current: Screen, list: { Entry })
	local key = keyOf(list)
	if key == current.rowsKey then
		return -- rien de changé : les lignes (et leurs boutons) restent
	end
	current.rowsKey = key
	clearRows(current.rows)
	local template = current.template
	if template == nil then
		return
	end
	for rank, entry in list do
		local row = cloneRow(template, ROW_FORMAT, rank, entry)
		if row == nil then
			continue
		end
		if current.single then
			showButtons(row, true) -- a286 : objet exposé, RemoveButton seul
		end
		local uid = entry.Uid
		local _ = onClick(Find.path(row, "RemoveButton"), function()
			send("UnplaceItem", uid) -- détruite avec la ligne
		end)
		wireSell(row, entry) -- a314
		row.Visible = true
		row.Parent = template.Parent
		table.insert(current.rows, row)
	end
end

local closePanel: () -> () -- défini plus bas (DisplayedController.Close)

-- Vague 66 (a219) : objet sous antivol de la réserve : le panneau se ferme et la pose au sol commence
-- (InventoryController.PlaceItem, comme la barre du bas ; le serveur revérifie tout à PlaceBox).
local function placeOnFloor(uid: string)
	local module = script.Parent:FindFirstChild("InventoryController")
	local ok, result = pcall(function(): any
		return if module and module:IsA("ModuleScript") then (require(module) :: any).PlaceItem else nil
	end)
	if not ok or type(result) ~= "function" then
		reportOnce("placeOnFloor", `[Displayed] InventoryController.PlaceItem introuvable : objet sous antivol pas posé ({result})`)
		return
	end
	closePanel()
	local placed, err = pcall(result, uid)
	if not placed then
		reportOnce("placeOnFloorError", `[Displayed] InventoryController.PlaceItem : {err}`)
	end
end

-- a478 (L-380) : InventoryController (facultatif), chargé au premier besoin.
type InventoryApi = { HasScreen: () -> boolean, IsOpen: () -> boolean, Toggle: () -> () }
local inventoryApi: InventoryApi? = nil
local function inventoryModule(): InventoryApi?
	if inventoryApi then
		return inventoryApi
	end
	local module = script.Parent:FindFirstChild("InventoryController")
	local ok, result = pcall(function(): any
		return if module and module:IsA("ModuleScript") then require(module) else nil
	end)
	if ok and type(result) == "table" and type(result.HasScreen) == "function" and type(result.IsOpen) == "function" and type(result.Toggle) == "function" then
		inventoryApi = result :: any
	end
	return inventoryApi
end

-- a478 : le bouton du sac ouvre-t-il l'écran d'inventaire (interrupteur allumé et UI_Inventory dans PlayerGui) ?
local function inventoryTakesButton(): InventoryApi?
	if DisplayedConfig.InventoryScreen ~= true then
		return nil
	end
	local api = inventoryModule()
	if api and api.HasScreen() then
		return api
	end
	reportOnce("inventoryScreen", "[Displayed] InventoryScreen allumé mais UI_Inventory absent de PlayerGui : le bouton du sac ouvre encore les objets exposés")
	return nil
end

-- a478 : l'écran d'inventaire est ouvert (pastille : ce qui entre pendant ce temps est vu).
local function inventoryOpen(): boolean
	local api = inventoryApi
	if DisplayedConfig.InventoryScreen ~= true or api == nil then
		return false
	end
	return api.IsOpen()
end

-- `offset` (a286, liste unique) : nombre de lignes d'objets exposés au-dessus, ajouté au LayoutOrder (0 sinon).
local function buildReserve(current: Screen, list: { Entry }, offset: number)
	local key = `{offset}|{keyOf(list)}`
	if key == current.reserveKey then
		return
	end
	current.reserveKey = key
	clearRows(current.reserveRows)
	local template = current.reserveTemplate
	if template == nil then
		return
	end
	for rank, entry in list do
		local row = cloneRow(template, RESERVE_ROW_FORMAT, rank, entry)
		if row == nil then
			continue
		end
		if current.single then
			row.LayoutOrder = offset + rank -- a286 : sous les objets exposés
			showButtons(row, false)
		end
		local uid = entry.Uid
		local locked = entry.AntiTheft == true
		local button = Find.path(row, "DisplayButton")
		if locked and button then
			setText(button:FindFirstChild("DisplayLabel"), DisplayedConfig.LockedButtonText) -- vague 66 : « PLACE »
		end
		local _ = onClick(button, function()
			if locked then
				placeOnFloor(uid)
			else
				send("PlaceFromReserve", uid) -- détruite avec la ligne
			end
		end)
		wireSell(row, entry) -- a314
		row.Visible = true
		row.Parent = template.Parent
		table.insert(current.reserveRows, row)
	end
end

-- Vague 73 : pastille InventoryAlert de la barre du bas. Allumée si un objet de `stock` n'a pas encore été vu ; tout
-- est vu quand l'écran est ouvert (`open`), et pendant la grâce d'arrivée.
local function updateAlert(stock: { Entry }, open: boolean)
	if DisplayedConfig.InventoryAlert ~= true then
		AlertBadge.SetAll(hotbarAlerts, false)
		return
	end
	if seen == nil then
		-- Rien n'est « nouveau » avant l'arrivée de l'inventaire et de la réserve (attributs posés par le serveur).
		if localPlayer:GetAttribute(InventoryState.Attribute) == nil or localPlayer:GetAttribute(RESERVE_ATTRIBUTE) == nil then
			AlertBadge.SetAll(hotbarAlerts, false)
			return
		end
		seen = {}
		seenUntil = os.clock() + (DisplayedConfig.InventoryAlertGrace or 0)
	end
	local known: { [string]: boolean } = seen or {}
	local all = open or os.clock() < seenUntil
	local fresh = false
	for _, entry in stock do
		if all then
			known[entry.Uid] = true
		elseif not known[entry.Uid] then
			fresh = true
		end
	end
	AlertBadge.SetAll(hotbarAlerts, fresh)
end

-- Compteurs (écran ouvert ou pas) et lignes (écran ouvert seulement).
local function refresh()
	local current = screen
	local items = inventory()
	local stock = reserved(items)
	updateAlert(stock, (isOpen and current ~= nil and current.gui.Enabled) or inventoryOpen())
	if current == nil then
		return
	end
	local list = exposed(items)
	setText(current.countLabel, string.format(COUNT_TEXT, #list, unlockedSlots()))
	setText(current.reserveCount, tostring(#stock))
	-- Vague 73 (L-213 point 4, L-241) : Panel.Reserve toujours montré ; seul son texte « vide » suit la réserve.
	local empty = current.reserveEmpty
	if empty and empty.Visible ~= (#stock == 0) then
		empty.Visible = #stock == 0
	end
	-- a286 (liste unique) : Panel.ListEmpty quand il n'y a ni objet exposé ni objet en réserve.
	local listEmpty = current.listEmpty
	local nothing = #list == 0 and #stock == 0
	if listEmpty and listEmpty.Visible ~= nothing then
		listEmpty.Visible = nothing
	end
	if isOpen then
		buildRows(current, list)
		buildReserve(current, stock, if current.single then #list else 0)
	end
end

local function apply(current: Screen)
	current.gui.Enabled = isOpen
end

-- Définies plus bas (elles rebranchent l'écran au besoin).
local displayBest: () -> ()

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearAll(old)
	end
	isOpen = false
	local best = guiObject(gui, "DisplayBestButton")
	local template = guiObject(gui, "List.Template")
	if template == nil then
		reportOnce("template", `[Displayed] {SCREEN}.Panel.List.Template introuvable : panneau vide`)
	else
		template.Visible = false
	end
	if best == nil then
		reportOnce("best", `[Displayed] {SCREEN}.DisplayBestButton introuvable : pas d'« Exposer les meilleurs »`)
	end
	local reserve = guiObject(gui, "Reserve")
	if reserve and not SHOW_RESERVE then
		reserve.Visible = false -- vague 72 (L-231) : la réserve sort de l'écran, jamais remplie
		reserve = nil
	end
	local reserveTemplate = if reserve then guiObject(reserve, "ReserveList.Template") else nil
	-- a286 : liste unique (script de Clément du 19/11) : pas de Panel.Reserve et un DisplayButton dans List.Template ;
	-- le même gabarit sert aux deux, la réserve sous les objets exposés.
	local single = reserve == nil and SHOW_RESERVE and template ~= nil and guiObject(template, "DisplayButton") ~= nil
	if single then
		reserveTemplate = template -- rien à signaler : la réserve est dans Panel.List
	elseif reserve == nil then
		if SHOW_RESERVE then -- sinon rien à signaler : la réserve n'est pas montrée (Config/Displayed.ShowReserve)
			reportOnce("reserve", `[Displayed] {SCREEN}.Panel.Reserve introuvable : la réserve n'est pas montrée`)
		end
	elseif reserveTemplate == nil then
		reportOnce("reserveTemplate", `[Displayed] {SCREEN}.Panel.Reserve.ReserveList.Template introuvable : réserve vide`)
	else
		reserveTemplate.Visible = false
	end
	local current: Screen = {
		gui = gui,
		countLabel = Find.path(gui, "DisplayCount.CountLabel"),
		template = template,
		rows = {},
		reserve = reserve,
		reserveCount = if reserve then Find.path(reserve, "ReserveCount.ReserveCountLabel") else nil,
		reserveTemplate = reserveTemplate,
		reserveRows = {},
		reserveEmpty = if reserve then guiObject(reserve, RESERVE_EMPTY) else nil,
		single = single,
		listEmpty = if single then guiObject(gui, LIST_EMPTY) else nil,
		rowsKey = nil,
		reserveKey = nil,
		confirm = guiObject(gui, CONFIRM),
		connections = {},
	}
	-- a314 : la confirmation de vente reste cachée tant qu'aucun SellButton n'est cliqué.
	selling = nil
	local confirm = current.confirm
	if confirm then
		confirm.Visible = false
	end
	-- Vague 75 (a260, L-262 point 3) : l'écran entre dans le groupe DisplayedConfig.ScreenGroup (« Menu ») si Clément ne
	-- lui en a pas donné : un autre menu qui s'ouvre le ferme (Motion.SetCloser), et il ferme les autres à l'ouverture.
	local group = DisplayedConfig.ScreenGroup
	if type(group) == "string" and group ~= "" and gui:GetAttribute(GROUP_ATTRIBUTE) == nil then
		gui:SetAttribute(GROUP_ATTRIBUTE, group)
	end
	Motion.SetCloser(gui, function()
		closePanel()
	end)
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), function()
		closePanel()
	end))
	keep(onClick(Find.path(gui, CLOSE_ARROW), function() -- vague 72 : la flèche, si Clément l'a livrée
		closePanel()
	end))
	keep(onClick(best, function()
		displayBest()
	end))
	if confirm then -- a314
		keep(onClick(Find.path(confirm, "YesButton"), function()
			confirmSell()
		end))
		keep(onClick(Find.path(confirm, "NoButton"), function()
			hideConfirm()
		end))
	end
	apply(current)
	refresh()
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return screen
	end
	return nil
end

function DisplayedController.IsOpen(): boolean
	return isOpen
end

function DisplayedController.Open()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Displayed] écran {SCREEN} absent de PlayerGui : le panneau ne s'ouvre pas`)
		return
	end
	Motion.CloseGroup(current.gui) -- vague 75 : les autres menus du groupe se ferment
	isOpen = true
	apply(current)
	refresh()
end

function DisplayedController.Close()
	isOpen = false
	hideConfirm() -- a314 : fermer l'écran annule la vente en attente
	local current = screen
	if current and current.gui.Parent ~= nil then
		apply(current)
		clearAll(current)
	end
end

function DisplayedController.Toggle()
	-- Vague 73 : l'écran réel compte (éteint par un autre code : il s'ouvre au lieu d'attendre un second clic).
	local current = screen
	if isOpen and current ~= nil and current.gui.Parent ~= nil and current.gui.Enabled then
		DisplayedController.Close()
	else
		DisplayedController.Open()
	end
end

function DisplayedController.DisplayBest()
	local now = os.clock()
	if now - lastBest < BEST_COOLDOWN then
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	lastBest = now
	net.Client.EquipBest:Fire()
end

function DisplayedController.Remove(itemUid: string)
	if type(itemUid) == "string" then
		send("UnplaceItem", itemUid)
	end
end

function DisplayedController.Display(itemUid: string)
	if type(itemUid) == "string" then
		send("PlaceFromReserve", itemUid)
	end
end

function DisplayedController.GetReserve(): { string }
	return reserveUids()
end

-- Vague 73 : la pastille InventoryAlert de la barre du bas est allumée (bancs, barre de commande).
function DisplayedController.IsAlertOn(): boolean
	for _, badge in hotbarAlerts do
		if AlertBadge.IsOn(badge) then
			return true
		end
	end
	return false
end

-- a314 : vente depuis l'écran (bancs, barre de commande en Studio).
function DisplayedController.Sell(itemUid: string)
	if type(itemUid) ~= "string" then
		return
	end
	for _, entry in inventory() do
		if entry.Uid == itemUid then
			openConfirm(entry)
			return
		end
	end
end

function DisplayedController.ConfirmSell()
	confirmSell()
end

function DisplayedController.CancelSell()
	hideConfirm()
end

function DisplayedController.GetSellState(): { Uid: string?, Price: number?, Sending: boolean, Shown: boolean }
	local state = selling
	return {
		Uid = if state then state.uid else nil,
		Price = if state then state.price else nil,
		Sending = state ~= nil and state.sending,
		Shown = confirmShown(),
	}
end

closePanel = DisplayedController.Close
displayBest = DisplayedController.DisplayBest

-- Vague 73 (a255, L-241 point 4) : UI_Hotbar.Bar.InventoryButton (facultatif) ouvre et ferme l'écran ; sa pastille
-- InventoryAlert suit updateAlert. Écran recréé : rebranché, les anciennes connexions coupées.
local function bindHotbar(gui: ScreenGui)
	for _, connection in hotbarConnections do
		connection:Disconnect()
	end
	table.clear(hotbarConnections)
	AlertBadge.SetAll(hotbarAlerts, false)
	hotbarAlerts = {}
	for _, inst in Find.all(gui, HOTBAR_BUTTON) do
		if inst:IsA("GuiButton") then
			table.insert(hotbarConnections, Motion.Activated(inst :: GuiButton):Connect(function()
				local api = inventoryTakesButton() -- a478 (L-380) : l'inventaire, s'il est allumé et livré
				if api then
					if isOpen then
						DisplayedController.Close()
					end
					api.Toggle()
					refresh() -- pastille : inventaire ouvert, tout est vu
					return
				end
				DisplayedController.Toggle()
			end))
			for _, badge in AlertBadge.Find(inst, HOTBAR_ALERT) do
				table.insert(hotbarAlerts, badge)
			end
		end
	end
	if #hotbarConnections == 0 then
		reportOnce("hotbarButton", `[Displayed] {HOTBAR}.Bar.{HOTBAR_BUTTON} introuvable : l'écran s'ouvre par le HUD seulement`)
	end
	refresh()
end

function DisplayedController.Start()
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(SLOTS_ATTRIBUTE):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(RESERVE_ATTRIBUTE):Connect(refresh)
	-- Les remotes attendent le serveur : sans bloquer le reste.
	task.spawn(function()
		local ok, result = pcall(function(): any
			return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
		end)
		if ok then
			net = result
			-- a314 : réponses du serveur à la vente depuis l'écran.
			local connected, err = pcall(function()
				result.Client.DisplayedSellPrice:Connect(onSellPrice)
				result.Client.DisplayedSold:Connect(onSold)
			end)
			if not connected then
				reportOnce("sellRemotes", `[Displayed] remotes de vente absents : un objet ne se vend pas depuis le panneau ({err})`)
			end
		else
			reportOnce("netRequire", `[Displayed] Net introuvable : les demandes ne partent pas ({result})`)
		end
	end)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui) -- écran recréé (ResetOnSpawn) : rebranché, fermé
		elseif child.Name == HOTBAR and child:IsA("ScreenGui") then
			bindHotbar(child :: ScreenGui) -- vague 73
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	local hotbar = playerGui:FindFirstChild(HOTBAR)
	if hotbar and hotbar:IsA("ScreenGui") then
		bindHotbar(hotbar :: ScreenGui)
	end
end

return DisplayedController
