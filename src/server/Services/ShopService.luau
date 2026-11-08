--!strict
-- ShopService (DEV-031, DEV-033) : achats en argent du jeu (Partie 1, sections 5.2, 5.9, 5.10, 7.1,
-- 7.2, 7.4, 7.5, 7.6, 9.4 et 9.5).
--
-- Rôle : seul service qui traite le remote BuyItem(catalogId). Le client n'envoie qu'un
-- identifiant ; le serveur décide tout : catalogue, prix, argent, possession, niveau, lieu.
-- L'identifiant est cherché dans les trois catalogues de Config, qui partagent le même espace
-- d'Id (un Id présent dans deux catalogues est refusé, avec un avertissement au démarrage) :
--   - outil (Config/Tools) : prix Tools[..].Price ; refusé s'il est déjà possédé ou si le joueur
--     est à plus de SHOP_REACH studs de tout comptoir taggé WeaponShop de la map (hors
--     _INBOX_CLEMENT ; 5.9 : on revient en zone safe pour dépenser son argent).
--     DataService.SpendCash, puis ToolService.Grant, puis
--     ToolService.Equip si l'outil acheté est plus puissant que l'outil équipé (choix V0 : on
--     achète presque toujours le palier suivant, plus fort, et l'équiper tout de suite évite un
--     clic ; un outil plus faible acheté après coup n'est pas équipé à la place du meilleur) ;
--   - amélioration (Config/Upgrades) : coût Formulas.UpgradeCost = C0 × g^n (n = niveau déjà
--     possédé, 7.5) ; refusé au niveau max ou hors de sa parcelle (volume Bounds, sinon l'emprise
--     de la parcelle). Niveau + 1 dans Upgrades du profil. Effet : le tapis et le banc relisent
--     leur niveau à chaque gain (TrainingService), les présentoirs à chaque pose (DisplayService,
--     qui republie DisplaySlotsUnlocked chaque seconde) ; les établis passent par
--     UnboxService.Refresh (leur attribut UnboxState change tout de suite) ;
--   - aura ou trail (Config/Cosmetics) : prix et argent gérés ici, au comptoir taggé AuraShop
--     (même portée), puis CosmeticService.Grant(player, id) (agent a20). Sans CosmeticService
--     (module absent ou sans Owns et Grant), ces achats sont refusés (« This item isn't available
--     yet. »), avec un seul avertissement en Studio, au démarrage. Si Grant échoue, l'argent est
--     rendu.
-- Remote EquipTool(toolId) (ajout de ce service, bouton EquipButton de UI_WeaponShop) : équipe un
-- outil possédé, par ToolService.Equip, où que soit le joueur (V0 : équiper un outil déjà payé ne
-- donne rien de plus ; pendant un portage, CarryService le garde hors des mains).
--
-- Refus : un envoi malhonnête (Id inconnu, outil pas possédé à équiper, profil pas chargé, pas de
-- parcelle) est ignoré sans message au joueur, avec un avertissement en Studio. Un refus honnête
-- (pas assez d'argent, déjà possédé, niveau max, pas au bon endroit) envoie un Notify « Warning »
-- en anglais (L-036). Un achat réussi envoie un Notify « Info ». Le débit et l'octroi se font
-- dans la même exécution, sans yield : pas d'achat en double ni d'argent perdu.
--
-- Attributs du Player (écrits seulement ici, posés au chargement du profil et après chaque
-- achat ou équipement ; lus par WeaponShopController et UpgradeController, pour l'affichage) :
--   OwnedTools          Id des outils possédés, dans l'ordre de Config/Tools, séparés par des
--                       virgules (« Fists,Wrench ») ;
--   EquippedTool        Id de l'outil équipé (ToolService.GetEquippedId) ;
--   TreadmillLevel, BenchLevel, DisplaySlotsLevel, UnboxBenchesLevel
--                       niveau acheté de chaque amélioration (Upgrades du profil).
--
-- API (côté serveur) :
--   ShopService.RefreshPlayer(player)
--       Republie les attributs ci-dessus. À appeler par un service qui donne ou équipe un outil,
--       ou qui change un niveau, sans passer par la boutique (tutoriel, renaissance en Partie 2) :
--       ToolService n'a pas de signal de changement.
--   ShopService.OnPurchase(listener) -> déconnexion
--       listener(player, kind, id, price, level?) après chaque achat payé et donné : kind = "Tool",
--       "Upgrade", "Aura" ou "Trail", id = Id du catalogue, price = argent retiré, level = niveau
--       atteint (amélioration seulement). L'argent est déjà retiré : DataService.Get(player).Cash
--       est le solde après l'achat. Un achat refusé, ou rendu parce que l'octroi a échoué, ne
--       prévient pas. Pour la télémétrie (TelemetryService, 14.2).
--
-- Interface attendue de CosmeticService (a20), chargé sans planter s'il manque :
--   CosmeticService.Owns(player, cosmeticId) -> boolean
--   CosmeticService.Grant(player, cosmeticId) -> boolean
--       Ajoute aux cosmétiques possédés, sans équiper ; false si le profil n'est pas chargé ou
--       l'Id inconnu. Sans yield. Ne touche pas à l'argent : ShopService a déjà débité le prix.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Cosmetics = require(Shared.Config.Cosmetics)
local Formulas = require(Shared.Config.Formulas)
local Tools = require(Shared.Config.Tools)
local Upgrades = require(Shared.Config.Upgrades)
local Find = require(Shared.Contract.Find)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ToolService = require(script.Parent.ToolService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type ToolDef = Tools.Tool
type UpgradeDef = Upgrades.Upgrade
type CosmeticDef = Cosmetics.Cosmetic

type CosmeticApi = {
	Owns: (player: Player, cosmeticId: string) -> boolean,
	Grant: (player: Player, cosmeticId: string) -> boolean,
}

type Entry = { kind: "Tool", tool: ToolDef } | { kind: "Upgrade", upgrade: UpgradeDef } | { kind: "Cosmetic", cosmetic: CosmeticDef }

export type PurchaseKind = "Tool" | "Upgrade" | "Aura" | "Trail"
export type PurchaseListener = (player: Player, kind: PurchaseKind, id: string, price: number, level: number?) -> ()

local IS_STUDIO = RunService:IsStudio()

-- Contrat (2.1 et 10.4) : comptoirs de la zone safe et volume de la parcelle.
local WEAPON_SHOP_TAG = "WeaponShop"
local AURA_SHOP_TAG = "AuraShop"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : pas un comptoir
local BOUNDS = "Bounds"
local COSMETIC_MODULE = "CosmeticService"

-- Attributs du Player (voir l'en-tête ; mêmes noms dans WeaponShopController et UpgradeController).
local OWNED_TOOLS_ATTRIBUTE = "OwnedTools"
local EQUIPPED_TOOL_ATTRIBUTE = "EquippedTool"
local LEVEL_ATTRIBUTE_FORMAT = "%sLevel"

-- V0 proposé, absent du doc : portée (studs) acceptée autour d'un comptoir, entre le
-- HumanoidRootPart et la pièce principale du comptoir. L'invite du client porte à 10 studs et
-- l'écran se ferme au-delà de 14 (WeaponShopController) : la marge couvre la gigue réseau.
local SHOP_REACH = 20

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposés, absents du doc.
local MESSAGES = {
	NotEnoughCash = "Not enough cash: %s needed.",
	ToolOwned = "You already own the %s.",
	CosmeticOwned = "You already own %s.",
	MachineMax = "Your %s is already at max level.",
	StandsMax = "All your stands are unlocked.",
	WorkbenchesMax = "All your workbenches are unlocked.",
	FarFromWeaponShop = "Go to the Weapon Shop to buy tools.",
	FarFromAuraShop = "Go to the Aura Shop to buy auras and trails.",
	NotOnPlot = "Go back to your shop to buy upgrades.",
	Unavailable = "This item isn't available yet.",
	ToolBought = "%s bought!",
	ToolBoughtEquipped = "%s bought and equipped!",
	CosmeticBought = "%s bought!",
	MachineUpgraded = "%s upgraded to level %d!",
	StandUnlocked = "New stand unlocked! (%d/%d)",
	WorkbenchUnlocked = "New workbench unlocked! (%d/%d)",
}

local ShopService = {}

local catalog: { [string]: Entry } = {}
local cosmeticApi: CosmeticApi? = nil
local purchaseListeners: { PurchaseListener } = {}

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[ShopService] {message}`)
	end
end

-- Refus d'un envoi malhonnête : rien pour le joueur, une ligne en Studio.
local function reject(player: Player, remote: string, id: string, reason: string)
	if IS_STUDIO then
		warn(`[ShopService] {player.Name} → {remote}(« {id} ») refusé : {reason}`)
	end
end

local function notify(player: Player, message: string, kind: "Info" | "Warning")
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[ShopService] Notify vers {player.Name} : {err}`)
	end
end

-- Appelle `fn` sans laisser une erreur d'un autre service casser l'achat déjà payé.
local function guarded(label: string, fn: (Player) -> (), player: Player)
	local ok, err = pcall(function()
		fn(player)
	end)
	if not ok then
		warn(`[ShopService] {label} ({player.Name}) : {err}`)
	end
end

-- Niveau d'amélioration lu dans le profil : entier ≥ 0 (une valeur abîmée compte pour 0).
local function levelOf(data: Data, upgradeId: string): number
	local value = (data.Upgrades :: any)[upgradeId]
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- HumanoidRootPart d'un personnage vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

-- Point de référence d'un comptoir taggé : sa pièce principale, sinon lui-même (pièce ou
-- Attachment), sinon sa première pièce. Même règle que WeaponShopController (où se pose l'invite).
local function anchorPosition(inst: Instance): Vector3?
	if inst:IsA("Model") then
		local primary = (inst :: Model).PrimaryPart
		if primary and primary:IsDescendantOf(inst) then
			return primary.Position
		end
	elseif inst:IsA("BasePart") then
		return (inst :: BasePart).Position
	elseif inst:IsA("Attachment") then
		return (inst :: Attachment).WorldPosition
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	return if part then (part :: BasePart).Position else nil
end

-- Comptoir posé dans la map : dans le Workspace, hors _INBOX_CLEMENT (comme WindowService).
local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- Le joueur est-il à portée d'un comptoir de la map portant `tag` ?
local function isNearShop(player: Player, tag: string): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if inMap(inst) then
			local position = anchorPosition(inst)
			if position and (position - root.Position).Magnitude <= SHOP_REACH then
				return true
			end
		end
	end
	return false
end

local function isInsidePart(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Le joueur est-il dans sa parcelle ? Volume Bounds (10.4), sinon emprise de la parcelle (même
-- règle que DisplayService pour PlaceItem).
local function isOnOwnPlot(player: Player, plot: Model): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local bounds = Find.path(plot, BOUNDS)
	if bounds and bounds:IsA("BasePart") then
		return isInsidePart(bounds :: BasePart, root.Position)
	end
	local boxCFrame, boxSize = plot:GetBoundingBox()
	local p = boxCFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= boxSize.X / 2 and math.abs(p.Z) <= boxSize.Z / 2
end

------------------------------------------------------------------------------
-- Attributs publiés
------------------------------------------------------------------------------

local function publish(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local owned: { string } = {}
	for _, tool in Tools.List do
		if table.find(data.Tools.Owned, tool.Id) then
			table.insert(owned, tool.Id)
		end
	end
	player:SetAttribute(OWNED_TOOLS_ATTRIBUTE, table.concat(owned, ","))
	player:SetAttribute(EQUIPPED_TOOL_ATTRIBUTE, ToolService.GetEquippedId(player))
	for _, upgrade in Upgrades.List do
		player:SetAttribute(string.format(LEVEL_ATTRIBUTE_FORMAT, upgrade.Id), levelOf(data, upgrade.Id))
	end
end

------------------------------------------------------------------------------
-- Achats
------------------------------------------------------------------------------

local function notEnoughCash(player: Player, price: number)
	notify(player, string.format(MESSAGES.NotEnoughCash, Format.money(price)), "Warning")
end

-- Achat payé et donné : prévient les écouteurs d'OnPurchase (voir l'en-tête).
local function emitPurchase(player: Player, kind: PurchaseKind, id: string, price: number, level: number?)
	for _, listener in table.clone(purchaseListeners) do
		task.spawn(listener, player, kind, id, price, level)
	end
end

local function buyTool(player: Player, tool: ToolDef)
	if ToolService.Owns(player, tool.Id) then
		notify(player, string.format(MESSAGES.ToolOwned, tool.DisplayName), "Warning")
		return
	end
	if not isNearShop(player, WEAPON_SHOP_TAG) then
		notify(player, MESSAGES.FarFromWeaponShop, "Warning")
		return
	end
	if not DataService.SpendCash(player, tool.Price) then
		notEnoughCash(player, tool.Price)
		return
	end
	if not ToolService.Grant(player, tool.Id) then
		DataService.AddCash(player, tool.Price) -- ne devrait pas arriver : profil chargé, Id connu
		warn(`[ShopService] {player.Name} : ToolService.Grant({tool.Id}) a échoué, {Format.money(tool.Price)} rendus`)
		return
	end
	local equippedId = ToolService.GetEquippedId(player)
	local equipped = if equippedId then Tools.ById[equippedId] else nil
	local stronger = equipped == nil or tool.Power > equipped.Power
	if stronger then
		guarded("ToolService.Equip", function(p: Player)
			ToolService.Equip(p, tool.Id)
		end, player)
	end
	publish(player)
	notify(player, string.format(if stronger then MESSAGES.ToolBoughtEquipped else MESSAGES.ToolBought, tool.DisplayName), "Info")
	log(`{player.Name} : {tool.Id} acheté {Format.money(tool.Price)}{if stronger then ", équipé" else ""}`)
	emitPurchase(player, "Tool", tool.Id, tool.Price, nil)
end

local function buyUpgrade(player: Player, data: Data, upgrade: UpgradeDef)
	local level = levelOf(data, upgrade.Id)
	local cost = Formulas.UpgradeCost(upgrade.Id, level)
	if cost == nil then
		local message = if upgrade.Id == "DisplaySlots"
			then MESSAGES.StandsMax
			elseif upgrade.Id == "UnboxBenches" then MESSAGES.WorkbenchesMax
			else string.format(MESSAGES.MachineMax, upgrade.DisplayName)
		notify(player, message, "Warning")
		return
	end
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		reject(player, "BuyItem", upgrade.Id, "pas de parcelle")
		return
	end
	if not isOnOwnPlot(player, plot) then
		notify(player, MESSAGES.NotOnPlot, "Warning")
		return
	end
	if not DataService.SpendCash(player, cost) then
		notEnoughCash(player, cost)
		return
	end
	local newLevel = level + 1
	;(data.Upgrades :: any)[upgrade.Id] = newLevel
	if upgrade.Id == "UnboxBenches" then
		guarded("UnboxService.Refresh", UnboxService.Refresh, player)
	end
	publish(player)

	-- Présentoirs et établis débloqués = départ + niveau, au plus le maximum (7.5 : 4 à 20, 1 à 4).
	local message: string
	if upgrade.Id == "DisplaySlots" then
		local display = Balance.Display
		message = string.format(MESSAGES.StandUnlocked, math.min(display.StartSlots + newLevel, display.MaxSlots), display.MaxSlots)
	elseif upgrade.Id == "UnboxBenches" then
		local unbox = Balance.Unbox
		message = string.format(MESSAGES.WorkbenchUnlocked, math.min(unbox.StartBenches + newLevel, unbox.MaxBenches), unbox.MaxBenches)
	else
		message = string.format(MESSAGES.MachineUpgraded, upgrade.DisplayName, newLevel)
	end
	notify(player, message, "Info")
	log(`{player.Name} : {upgrade.Id} niveau {level} → {newLevel} pour {Format.money(cost)}`)
	emitPurchase(player, "Upgrade", upgrade.Id, cost, newLevel)
end

local function buyCosmetic(player: Player, cosmetic: CosmeticDef)
	local api = cosmeticApi
	if api == nil then
		notify(player, MESSAGES.Unavailable, "Warning") -- déjà signalé en Studio au démarrage
		return
	end
	local okOwns, owns = pcall(api.Owns, player, cosmetic.Id)
	if not okOwns then
		warn(`[ShopService] CosmeticService.Owns({cosmetic.Id}) : {owns}`)
		return
	end
	if owns == true then
		notify(player, string.format(MESSAGES.CosmeticOwned, cosmetic.DisplayName), "Warning")
		return
	end
	if not isNearShop(player, AURA_SHOP_TAG) then
		notify(player, MESSAGES.FarFromAuraShop, "Warning")
		return
	end
	if not DataService.SpendCash(player, cosmetic.Price) then
		notEnoughCash(player, cosmetic.Price)
		return
	end
	local okGrant, granted = pcall(api.Grant, player, cosmetic.Id)
	if not okGrant or granted ~= true then
		DataService.AddCash(player, cosmetic.Price)
		warn(`[ShopService] {player.Name} : CosmeticService.Grant({cosmetic.Id}) a échoué ({granted}), {Format.money(cosmetic.Price)} rendus`)
		return
	end
	notify(player, string.format(MESSAGES.CosmeticBought, cosmetic.DisplayName), "Info")
	log(`{player.Name} : {cosmetic.Kind} {cosmetic.Id} acheté {Format.money(cosmetic.Price)}`)
	emitPurchase(player, cosmetic.Kind, cosmetic.Id, cosmetic.Price, nil)
end

local function onBuyItem(player: Player, catalogId: string)
	local entry = catalog[catalogId]
	if entry == nil then
		reject(player, "BuyItem", catalogId, "identifiant inconnu")
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		reject(player, "BuyItem", catalogId, "profil pas chargé")
		return
	end
	if entry.kind == "Tool" then
		buyTool(player, entry.tool)
	elseif entry.kind == "Upgrade" then
		buyUpgrade(player, data, entry.upgrade)
	else
		buyCosmetic(player, entry.cosmetic)
	end
end

local function onEquipTool(player: Player, toolId: string)
	if Tools.ById[toolId] == nil then
		reject(player, "EquipTool", toolId, "outil inconnu")
		return
	end
	if DataService.Get(player) == nil then
		reject(player, "EquipTool", toolId, "profil pas chargé")
		return
	end
	if not ToolService.Owns(player, toolId) then
		reject(player, "EquipTool", toolId, "outil pas possédé")
		return
	end
	ToolService.Equip(player, toolId)
	publish(player)
	log(`{player.Name} : {toolId} équipé`)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

-- Catalogue unique des trois listes de Config. Un Id présent deux fois serait ambigu : refusé.
local function buildCatalog()
	local seen: { [string]: string } = {}
	local ambiguous: { [string]: boolean } = {}
	local function add(id: string, label: string, entry: Entry)
		if seen[id] then
			ambiguous[id] = true
			warn(`[ShopService] Id « {id} » présent dans {seen[id]} et {label} : achats de cet Id refusés`)
			return
		end
		seen[id] = label
		catalog[id] = entry
	end
	for _, tool in Tools.List do
		add(tool.Id, "Config/Tools", { kind = "Tool", tool = tool })
	end
	for _, upgrade in Upgrades.List do
		add(upgrade.Id, "Config/Upgrades", { kind = "Upgrade", upgrade = upgrade })
	end
	for _, list in { Cosmetics.Auras, Cosmetics.Trails } do
		for _, cosmetic in list do
			add(cosmetic.Id, "Config/Cosmetics", { kind = "Cosmetic", cosmetic = cosmetic })
		end
	end
	for id in ambiguous do
		catalog[id] = nil
	end
end

-- CosmeticService (a20) est chargé s'il est là ; sans lui, la boutique d'armes et les
-- améliorations marchent, seuls les achats d'auras et de trails sont refusés.
local function loadCosmeticService(): CosmeticApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild(COSMETIC_MODULE) else nil
	if module == nil or not module:IsA("ModuleScript") then
		if IS_STUDIO then
			warn(`[ShopService] {COSMETIC_MODULE} absent : achats d'auras et de trails refusés`)
		end
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" or type(result.Owns) ~= "function" or type(result.Grant) ~= "function" then
		warn(`[ShopService] {COSMETIC_MODULE} inutilisable (Owns et Grant attendus) : achats d'auras et de trails refusés`)
		return nil
	end
	return result :: any
end

function ShopService.RefreshPlayer(player: Player)
	publish(player)
end

function ShopService.OnPurchase(listener: PurchaseListener): () -> ()
	table.insert(purchaseListeners, listener)
	return function()
		local index = table.find(purchaseListeners, listener)
		if index then
			table.remove(purchaseListeners, index)
		end
	end
end

function ShopService.Init()
	buildCatalog()
	cosmeticApi = loadCosmeticService()
	Net.Server.BuyItem:Connect(onBuyItem)
	Net.Server.EquipTool:Connect(onEquipTool)
	DataService.OnProfileLoaded(publish)
end

return ShopService
