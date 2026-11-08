--!strict
-- ContractChecker (DEV-005) : à chaque test lancé dans Studio, vérifie que la place
-- respecte le contrat entre le code et le visuel (doc, sections 2.1, 2.2, 2.4, 10.3 et
-- 10.4 ; liaison, sections 3.2 et 3.3) et écrit un rapport lisible par Clément.
--
-- Quatre sortes de lignes, toutes préfixées « [Contrat] » (à taper dans le filtre de la
-- sortie), regroupées par catégorie :
--   - problème (warn, orange) : quelque chose de livré ne respecte pas le contrat ;
--   - avertissement (warn, orange, pas compté comme un problème) : un élément facultatif du
--     contrat manque et le code se rabat sur autre chose (InfoPoint d'un magasin, L-044) ;
--   - pas encore livré (print) : un écran, un modèle ou une animation n'existe pas encore,
--     une seule ligne pour un écran ou un modèle entièrement absent ;
--   - note (print) : ce que le vérificateur n'a pas pu contrôler.
-- Dernière ligne : « Contrat : N problème(s) » ou « Contrat : OK », suivie du nombre
-- d'avertissements et de points pas encore livrés. Zéro problème = livrable.
--
-- Ne tourne qu'en Studio, côté serveur, et ne modifie jamais rien dans la place.
-- Les noms vérifiés viennent tous de ReplicatedStorage/Shared/Contract (et du catalogue d'objets,
-- Config/Items, pour les ITM_ et leurs icônes ICON_).

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ContractFolder = Shared:WaitForChild("Contract")
local Animations = require(ContractFolder:WaitForChild("Animations"))
local Attributes = require(ContractFolder:WaitForChild("Attributes"))
local Find = require(ContractFolder:WaitForChild("Find"))
local Icons = require(ContractFolder:WaitForChild("Icons"))
local Models = require(ContractFolder:WaitForChild("Models"))
local Tags = require(ContractFolder:WaitForChild("Tags"))
local UI = require(ContractFolder:WaitForChild("UI"))
-- Catalogue d'objets : icônes attendues, une par objet, dans l'ordre du catalogue (L-055).
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))

type Anim = typeof(Animations.Player[1])
type Part = typeof(Models.Store.Parts[1])
type ModelSpec = typeof(Models.Store)
type Screen = typeof(UI.Screens[1])

type Kind = "problem" | "warning" | "pending" | "note"
type Line = { kind: Kind, text: string }
type Job = { shown: string, id: string, spec: Anim }
type ClipResult = { ok: boolean, value: any }

local ContractChecker = {}
-- Démarre avant les autres services : la place est lue telle que Clément l'a livrée.
ContractChecker.Priority = 1

local PREFIX = "[Contrat]"
local CATEGORIES = { "Tags", "Magasins PNJ", "Parcelles", "UI", "Billboards", "Animations", "Objets", "Événements", "Scripts" }
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons : vérifiées, mais pas comptées dans la map
local SANDBOX_NAME = "_SANDBOX_IRONIX" -- tests d'Ironix : ignorés

-- Lecture du contenu des animations (priorité, boucle, marqueur) par AnimationClipProvider.
-- À passer à false si cette lecture ne marche pas côté serveur.
local CHECK_ANIMATION_CONTENT = true
local CLIP_TIMEOUT = 20 -- secondes d'attente au plus pour lire toutes les animations
local LIST_MAX = 6 -- noms affichés au plus dans une liste « pas encore livrés »
local MISSING_PER_LINE = 3 -- au-delà, les manques d'un même modèle tiennent sur une ligne

-- Reconnaître un vendeur d'un vigile : nom du modèle, sinon place sous une boutique.
local VENDOR_WORDS = { "vendeur", "vendor", "seller", "shopkeeper" }
local GUARD_WORDS = { "vigile", "guard" }
local VENDOR_SHOP_TAGS = { "WeaponShop", "AuraShop", "RobuxShop" }

local CLASS_LABELS: { [string]: string } = {
	GuiButton = "bouton (TextButton ou ImageButton)",
}

local RESERVED: { [string]: boolean } = {}
for _, name in UI.ReservedNames do
	RESERVED[name] = true
end

-- État d'une vérification, remis à zéro par run().
local lines: { [string]: { Line } } = {}
local counts: { [string]: number } = { problem = 0, warning = 0, pending = 0, note = 0 }
local indexCache: { [Instance]: { [string]: { Instance } } } = {}
local contractModels: { [Instance]: boolean } = {}
local assetRoots: { Instance } = {}
local inbox: Instance? = nil
local sandbox: Instance? = nil

-- Rapport ---------------------------------------------------------------------

local function add(kind: Kind, category: string, text: string)
	local list = lines[category] or {}
	lines[category] = list
	table.insert(list, { kind = kind, text = text })
	counts[kind] += 1
end

local function problem(category: string, text: string)
	add("problem", category, text)
end

local function warning(category: string, text: string)
	add("warning", category, text)
end

local function pending(category: string, text: string)
	add("pending", category, text)
end

local function note(category: string, text: string)
	add("note", category, text)
end

local function printReport()
	print(`{PREFIX} Vérification du contrat code ↔ visuel (doc 2.1, 2.2, 2.4, 10.4 ; liaison 3.2, 3.3)`)
	for _, category in CATEGORIES do
		local list = lines[category]
		if list then
			for _, kind in { "problem", "warning", "pending", "note" } :: { Kind } do
				for _, line in list do
					if line.kind == kind then
						local text = `{PREFIX} {category} · {line.text}`
						if kind == "problem" or kind == "warning" then
							warn(text)
						else
							print(text)
						end
					end
				end
			end
		end
	end
	local warnings = if counts.warning > 0 then ` · {counts.warning} avertissement(s)` else ""
	local later = if counts.pending > 0 then ` · {counts.pending} point(s) pas encore livré(s)` else ""
	if counts.problem > 0 then
		warn(`{PREFIX} Contrat : {counts.problem} problème(s){warnings}{later}`)
	else
		print(`{PREFIX} Contrat : OK{warnings}{later}`)
	end
end

-- Outils ----------------------------------------------------------------------

-- Nom sans casse ni ponctuation, pour reconnaître une faute de frappe.
local function normalize(name: string): string
	return (string.gsub(string.lower(name), "[^%w]", ""))
end

local function listNames(names: { string }): string
	if #names <= LIST_MAX then
		return table.concat(names, ", ")
	end
	return `{table.concat(names, ", ", 1, LIST_MAX)}… ({#names} en tout)`
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function isInside(inst: Instance, folder: Instance?): boolean
	return folder ~= nil and inst:IsDescendantOf(folder)
end

local function isCharacter(inst: Instance): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and (inst == character or inst:IsDescendantOf(character)) then
			return true
		end
	end
	return false
end

-- Fait partie de la place livrée (Workspace ou Assets), hors bac à sable et personnages.
local function isScanned(inst: Instance): boolean
	if isInside(inst, sandbox) then
		return false
	end
	if inst:IsDescendantOf(Workspace) then
		return not isCharacter(inst)
	end
	for _, root in assetRoots do
		if inst:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

-- Suit un chemin d'enfants directs depuis `root`.
local function walk(root: Instance, segments: { string }): Instance?
	local current: Instance? = root
	for _, segment in segments do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- a42 : `inst` est-il dans un personnage rangé sous `root` (un Model avec un Humanoid, comme les
-- conducteurs du camion, L-071) ? Les pièces d'un rig R15 (son Motor6D « Root »…) ne sont pas des
-- éléments du modèle qui le contient.
local function insideNestedRig(inst: Instance, root: Instance): boolean
	local parent = inst.Parent
	while parent and parent ~= root do
		if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Index nom → descendants de `root`, calculé une fois par vérification.
local function indexOf(root: Instance): { [string]: { Instance } }
	local cached = indexCache[root]
	if cached then
		return cached
	end
	local index: { [string]: { Instance } } = {}
	for _, descendant in root:GetDescendants() do
		if insideNestedRig(descendant, root) then
			continue -- a42 : pièces d'un conducteur
		end
		local list = index[descendant.Name] or {}
		index[descendant.Name] = list
		table.insert(list, descendant)
	end
	indexCache[root] = index
	return index
end

-- Une clé de `names` qui ne diffère de `name` que par la casse ou la ponctuation.
local function nearName(names: { [string]: any }, name: string): string?
	local target = normalize(name)
	for candidate in names do
		if candidate ~= name and normalize(candidate) == target then
			return candidate
		end
	end
	return nil
end

local function hint(near: string?, name: string): string
	return if near then ` (« {near} » trouvé : le renommer en {name})` else ""
end

local function hasTagInside(inst: Instance, tag: string): boolean
	if inst:HasTag(tag) then
		return true
	end
	for _, descendant in inst:GetDescendants() do
		if descendant:HasTag(tag) then
			return true
		end
	end
	return false
end

local function hasTaggedAncestor(inst: Instance, tags: { string }): boolean
	local parent = inst.Parent
	while parent and parent ~= game do
		for _, tag in tags do
			if parent:HasTag(tag) then
				return true
			end
		end
		parent = parent.Parent
	end
	return false
end

-- Tags et attributs -----------------------------------------------------------

local function checkAttributes(scanned: { Instance })
	local zone = Attributes.Zone
	local tierValues = Attributes.Tier.Values
	for _, inst in scanned do
		local zoneValue = inst:GetAttribute(zone.Name)
		if zoneValue ~= nil then
			if type(zoneValue) ~= "number" then
				problem(
					"Tags",
					`{inst:GetFullName()} : attribut Zone de type {typeof(zoneValue)}, attendu un nombre (number) de {zone.Min} à {zone.Max}`
				)
			elseif zoneValue % 1 ~= 0 or zoneValue < zone.Min or zoneValue > zone.Max then
				problem("Tags", `{inst:GetFullName()} : Zone = {zoneValue}, attendu un entier de {zone.Min} à {zone.Max}`)
			end
		end
		local tierValue = inst:GetAttribute(Attributes.Tier.Name)
		if tierValue ~= nil and (type(tierValue) ~= "string" or table.find(tierValues, tierValue) == nil) then
			problem(
				"Tags",
				`{inst:GetFullName()} : Tier = « {tostring(tierValue)} », attendu {table.concat(tierValues, ", ")}`
			)
		end
		local itemId = inst:GetAttribute(Attributes.ItemId.Name)
		if itemId ~= nil and (type(itemId) ~= "string" or itemId == "") then
			problem("Objets", `{inst:GetFullName()} : attribut ItemId vide ou qui n'est pas un texte`)
		end
	end
end

-- Parcelles : chacune porte un PlotIndex entier de 1 à 6, chaque numéro une seule fois
-- (liaison L-015 et L-017). Les parcelles rangées dans l'inbox ou hors de la map sont ignorées.
local function checkPlotIndex()
	local spec = Attributes.PlotIndex
	local byIndex: { [number]: { string } } = {}
	for _, plot in CollectionService:GetTagged("PlayerPlot") do
		if isInside(plot, sandbox) or isInside(plot, inbox) or not plot:IsDescendantOf(Workspace) then
			continue
		end
		local value = plot:GetAttribute(spec.Name)
		if value == nil then
			problem("Parcelles", `{plot:GetFullName()} : attribut {spec.Name} manquant (entier de {spec.Min} à {spec.Max}, le numéro écrit sur la parcelle)`)
		elseif type(value) ~= "number" or value % 1 ~= 0 or value < spec.Min or value > spec.Max then
			problem("Parcelles", `{plot:GetFullName()} : {spec.Name} = {tostring(value)}, attendu un entier de {spec.Min} à {spec.Max}`)
		else
			local list = byIndex[value] or {}
			table.insert(list, plot:GetFullName())
			byIndex[value] = list
		end
	end
	for index, list in byIndex do
		if #list > 1 then
			problem("Parcelles", `{spec.Name} = {index} posé sur {#list} parcelles (une seule attendue) : {table.concat(list, ", ")}`)
		end
	end
end

local function checkTags()
	local zone = Attributes.Zone
	local known: { [string]: string } = {}
	local absent: { string } = {}
	for _, spec in Tags.List do
		known[normalize(spec.Tag)] = spec.Tag
		local live: { Instance } = {}
		local inInbox = 0
		for _, inst in CollectionService:GetTagged(spec.Tag) do
			if isInside(inst, sandbox) or not inst:IsDescendantOf(Workspace) then
				continue -- un modèle rangé dans Assets n'est pas dans la map
			end
			if isInside(inst, inbox) then
				inInbox += 1
			else
				table.insert(live, inst)
			end
			if spec.NeedsZone and inst:GetAttribute(zone.Name) == nil then
				problem(
					"Tags",
					`{inst:GetFullName()} : attribut Zone manquant (tag {spec.Tag}, entier de {zone.Min} à {zone.Max})`
				)
			end
		end

		local n = #live
		local count = spec.Count
		local inboxText = if inInbox > 0 then `, + {inInbox} dans {INBOX_NAME} (non compté)` else ""
		if n == 0 and inInbox == 0 then
			table.insert(absent, if count then `{spec.Tag} ({count})` else spec.Tag)
		elseif count and n > count then
			problem("Tags", `Tag {spec.Tag} ({spec.For}) : {n} posés dans la map, {count} attendu(s)`)
		elseif count and n < count then
			pending("Tags", `Tag {spec.Tag} ({spec.For}) : {n} sur {count} posé(s) dans la map{inboxText}`)
		elseif n == 0 then
			pending("Tags", `Tag {spec.Tag} ({spec.For}) : aucun posé dans la map{inboxText}`)
		end

		local perZone = spec.PerZone
		if perZone then
			local byZone: { [number]: number } = {}
			for _, inst in live do
				local value = inst:GetAttribute(zone.Name)
				if type(value) == "number" then
					byZone[value] = (byZone[value] or 0) + 1
				end
			end
			for value = zone.Min, zone.Max do
				local c = byZone[value] or 0
				if c > perZone then
					problem("Tags", `Tag {spec.Tag} : {c} avec Zone = {value}, {perZone} attendu(s) par zone`)
				end
			end
		end
	end
	if #absent > 0 then
		pending("Tags", `Tags pas encore posés dans la map (nombre attendu) : {table.concat(absent, ", ")}`)
	end

	-- Tag mal écrit : même nom à la casse ou à la ponctuation près.
	for _, tag in CollectionService:GetAllTags() do
		local exact = known[normalize(tag)]
		if exact and exact ~= tag then
			local n = #CollectionService:GetTagged(tag)
			problem("Tags", `Tag « {tag} » posé sur {n} objet(s) : le nom exact du contrat est {exact}`)
		end
	end
end

-- Modèles (10.4) ---------------------------------------------------------------

local function seriesName(part: Part, i: number): string
	return string.format(part.Name, i)
end

local function seriesBase(part: Part): string
	return (string.gsub(part.Name, "_%%%d*d$", ""))
end

local function hasAnyPart(root: Instance, parts: { Part }): boolean
	local index = indexOf(root)
	for _, part in parts do
		local from = part.From
		if from then
			for i = from, part.To or from do
				if index[seriesName(part, i)] then
					return true
				end
			end
		elseif index[part.Name] then
			return true
		end
	end
	return false
end

local function describeTiers(byTier: { [string]: number }): string
	local parts: { string } = {}
	for _, value in Attributes.Tier.Values do
		table.insert(parts, `{byTier[value] or 0} {value}`)
	end
	return table.concat(parts, ", ")
end

local checkParts: (category: string, root: Instance, label: string, parts: { Part }) -> ()

local function checkFound(category: string, inst: Instance, shown: string, part: Part)
	local class = part.Class
	if class and not inst:IsA(class) then
		problem(category, `{shown} doit être un {class} (trouvé : {inst.ClassName})`)
	end
	if part.Tier and inst:GetAttribute(Attributes.Tier.Name) == nil then
		problem(category, `{shown} : attribut Tier manquant ({table.concat(Attributes.Tier.Values, ", ")})`)
	end
	if part.Invisible and inst:IsA("BasePart") and (inst :: BasePart).Transparency < 1 then
		problem(category, `{shown} doit être invisible (Transparency = 1)`)
	end
	local tag = part.Tag
	if tag and not hasTagInside(inst, tag) then
		problem(category, `{shown} : tag {tag} manquant (sur lui ou une de ses pièces)`)
	end
	local inside = part.Inside
	if inside then
		checkParts(category, inst, shown, inside)
	end
end

-- Série numérotée (ShelfSlot_01 à _10…). Renvoie « ShelfSlot_01 à ShelfSlot_10 » quand
-- toute la série obligatoire manque, pour le regrouper avec les autres manques du modèle.
local function checkSeries(category: string, root: Instance, label: string, part: Part): string?
	local index = indexOf(root)
	local from = part.From or 1
	local to = part.To or from
	local min = part.Min or to
	local missing: { string } = {}
	local byTier: { [string]: number } = {}
	local tiersComplete = true
	for i = from, to do
		local name = seriesName(part, i)
		local found = index[name]
		if found == nil then
			if i <= min then
				table.insert(missing, name)
			end
			tiersComplete = false
		else
			if #found > 1 then
				problem(category, `{label} : {#found} éléments nommés {name}, un seul attendu`)
			end
			checkFound(category, found[1], `{label}.{name}`, part)
			local tier = found[1]:GetAttribute(Attributes.Tier.Name)
			if type(tier) == "string" then
				byTier[tier] = (byTier[tier] or 0) + 1
			else
				tiersComplete = false
			end
		end
	end

	local noteText = if part.Note then ` ({part.Note})` else ""
	if #missing == min - from + 1 then
		return `{seriesName(part, from)} à {seriesName(part, min)}`
	elseif #missing > 0 then
		problem(category, `{label} : {listNames(missing)} introuvable(s){noteText}`)
	end

	local expected = part.TierCounts
	if expected and tiersComplete then
		for _, value in Attributes.Tier.Values do
			if (byTier[value] or 0) ~= (expected[value] or 0) then
				problem(
					category,
					`{label} : {seriesBase(part)} en {describeTiers(byTier)}, attendu {describeTiers(expected)} (5.3)`
				)
				break
			end
		end
	end
	return nil
end

-- Écrit les manques d'un même modèle ou écran : une ligne chacun, ou une seule ligne
-- quand ils sont nombreux. Un manque au pluriel est une série entière.
type Missing = { name: string, detail: string, plural: boolean }

local function reportMissing(category: string, label: string, missing: { Missing })
	if #missing > MISSING_PER_LINE then
		local texts: { string } = {}
		for _, entry in missing do
			table.insert(texts, entry.name .. entry.detail)
		end
		problem(category, `{label} : {#missing} éléments introuvables : {table.concat(texts, ", ")}`)
	else
		for _, entry in missing do
			local word = if entry.plural then "introuvables" else "introuvable"
			problem(category, `{label}.{entry.name} {word}{entry.detail}`)
		end
	end
end

checkParts = function(category: string, root: Instance, label: string, parts: { Part })
	local index = indexOf(root)
	local missing: { Missing } = {}
	for _, part in parts do
		if part.From then
			local whole = checkSeries(category, root, label, part)
			if whole then
				table.insert(missing, { name = whole, detail = if part.Note then ` ({part.Note})` else "", plural = true })
			end
		else
			local found = index[part.Name]
			if found == nil then
				local noteText = if part.Note then ` ({part.Note})` else ""
				local near = nearName(index, part.Name)
				if part.Optional and near == nil then
					-- Facultatif et vraiment absent : le code a un repli, ce n'est pas un problème.
					warning(category, `{label}.{part.Name} introuvable{noteText}`)
				else
					table.insert(missing, { name = part.Name, detail = `{hint(near, part.Name)}{noteText}`, plural = false })
				end
			else
				if #found > 1 then
					problem(category, `{label} : {#found} éléments nommés {part.Name}, un seul attendu`)
				end
				checkFound(category, found[1], `{label}.{part.Name}`, part)
			end
		end
	end
	reportMissing(category, label, missing)
end

-- Préfixe de nommage, sur le modèle le plus haut (pas sur ses sous-modèles).
local function isPrefixed(inst: Instance, prefix: string): boolean
	if not startsWith(inst.Name, prefix) then
		return false
	end
	if not (inst:IsA("PVInstance") or inst:IsA("Accoutrement")) then
		return false -- une image ou un son nommé ITM_… n'est pas un modèle
	end
	local parent = inst.Parent
	while parent and parent ~= game do
		if startsWith(parent.Name, prefix) then
			return false
		end
		parent = parent.Parent
	end
	return true
end

-- Vérifie un modèle. Renvoie false s'il n'a aucun élément du contrat (bloc de greybox).
local function checkModel(spec: ModelSpec, inst: Instance): boolean
	local category = spec.Category
	local label = inst:GetFullName()
	contractModels[inst] = true
	if spec.Tag and #spec.Parts > 0 and not hasAnyPart(inst, spec.Parts) then
		return false
	end

	local class = spec.Class
	if class and not inst:IsA(class) then
		problem(category, `{label} doit être un {class} (trouvé : {inst.ClassName})`)
	end
	local tag = spec.Tag
	if tag and spec.Prefix and inst:IsDescendantOf(Workspace) and not inst:HasTag(tag) then
		problem(category, `{label} : tag {tag} manquant (le code ne trouve ces modèles que par leur tag)`)
	end
	local primary = spec.PrimaryPart
	if primary and inst:IsA("Model") then
		local current = (inst :: Model).PrimaryPart
		if current == nil then
			problem(category, `{label} : PrimaryPart vide, choisir la pièce {primary}`)
		elseif current.Name ~= primary then
			problem(category, `{label} : PrimaryPart = {current.Name}, attendu la pièce {primary}`)
		end
	end
	local attributes = spec.Attributes
	if attributes then
		for _, name in attributes do
			if inst:GetAttribute(name) == nil then
				problem(category, `{label} : attribut {name} manquant`)
			end
		end
	end
	checkParts(category, inst, label, spec.Parts)
	if spec.BodyAttachment then
		local handle = inst:FindFirstChild("Handle")
		if handle and handle:FindFirstChildWhichIsA("Attachment") == nil then
			problem(category, `{label}.Handle : attachment de corps manquant (HatAttachment, BodyFrontAttachment…)`)
		end
	end
	return true
end

local function checkModels(scanned: { Instance })
	for _, spec in Models.List do
		local seen: { [Instance]: boolean } = {}
		local list: { Instance } = {}
		local function push(inst: Instance)
			if not seen[inst] then
				seen[inst] = true
				table.insert(list, inst)
			end
		end
		local tag = spec.Tag
		if tag then
			for _, inst in CollectionService:GetTagged(tag) do
				if isScanned(inst) then
					push(inst)
				end
			end
		end
		local prefix = spec.Prefix
		if prefix then
			for _, inst in scanned do
				if isPrefixed(inst, prefix) then
					push(inst)
				end
			end
		end
		-- Noms exacts (camion de l'événement, sa traînée : L-049) : le modèle lui-même, pas une pièce
		-- ou une image qui porterait le même nom.
		local exactNames = spec.Names
		if exactNames then
			for _, inst in scanned do
				if (inst:IsA("PVInstance") or inst:IsA("Folder")) and table.find(exactNames, inst.Name) then
					push(inst)
				end
			end
		end

		local empty: { string } = {}
		local names: { [string]: boolean } = {}
		for _, inst in list do
			names[inst.Name] = true
			if not checkModel(spec, inst) then
				table.insert(empty, inst.Name)
			end
		end
		if #empty > 0 then
			pending(
				spec.Category,
				`{spec.Label} sans aucun élément du contrat 10.4 ({#empty}, blocs de greybox ?) : {listNames(empty)}`
			)
		end

		local expected = spec.Expected
		local expectedCount = spec.ExpectedCount
		if expected then
			local missing: { string } = {}
			for _, name in expected do
				if not names[name] then
					table.insert(missing, name)
				end
			end
			if #missing > 0 then
				pending(spec.Category, `{spec.Label} pas encore livrés : {listNames(missing)}`)
			end
		elseif expectedCount then
			-- Noms différents seulement (un objet livré dans l'inbox et rangé dans Assets compte une
			-- fois), et, si le contrat les donne, seulement les noms acceptés (checkItems signale les autres).
			local known = spec.Known
			local delivered = 0
			for name in names do
				if known == nil or known[name] then
					delivered += 1
				end
			end
			if delivered < expectedCount then
				pending(spec.Category, `{spec.Label} {prefix or ""}* : {delivered} sur {expectedCount} livrés`)
			end
		elseif tag == nil and #list == 0 then
			pending(spec.Category, `{spec.Label} {prefix or ""}* : aucun livré`)
		end
	end
end

-- Objets ITM_ (catalogue v2 et animation idle, liaisons L-045 et L-055) -------------------------

-- Préfixe de pièce mobile (Spin_, Wave_) par lequel commence le nom de `inst`, ou nil.
local function moverPrefix(inst: Instance, prefixes: { string }): string?
	for _, prefix in prefixes do
		if startsWith(inst.Name, prefix) then
			return prefix
		end
	end
	return nil
end

-- Premier ancêtre de `inst`, sous `model`, qui est une pièce mobile (Spin_ ou Wave_).
local function moverAncestor(inst: Instance, model: Instance, prefixes: { string }): Instance?
	local parent = inst.Parent
	while parent and parent ~= model do
		if moverPrefix(parent, prefixes) then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

local function isInsideOrSelf(inst: Instance?, root: Instance): boolean
	return inst ~= nil and (inst == root or inst:IsDescendantOf(root))
end

-- Pièces d'une soudure (Weld, Motor6D, WeldConstraint…), nil si ce n'en est pas une.
local function jointParts(inst: Instance): (Instance?, Instance?)
	if inst:IsA("JointInstance") then
		local joint = inst :: JointInstance
		return joint.Part0, joint.Part1
	elseif inst:IsA("WeldConstraint") then
		local weld = inst :: WeldConstraint
		return weld.Part0, weld.Part1
	end
	return nil, nil
end

-- Modèle ITM_ qui contient `inst` (pas lui-même), ou nil.
local function itemAncestor(inst: Instance, prefix: string): Instance?
	local parent = inst.Parent
	while parent and parent ~= game do
		if isPrefixed(parent, prefix) then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

-- Pour chaque modèle ITM_ : nom du catalogue (Config/Items, par Contract/Models), anciens noms du
-- catalogue v1 refusés, ItemId = nom sans ITM_, un seul Root, ni pièce mobile (Spin_, Wave_) ni
-- dans une pièce mobile, pièces mobiles = BasePart ou Model, sans soudure vers le reste du modèle,
-- attribut Idle à une valeur connue. Un attribut Idle posé sur une pièce d'un ITM_ est signalé (le
-- code ne le lit que sur le modèle) ; ailleurs, il n'est pas regardé (les copies exposées le gardent).
local function checkItems(scanned: { Instance })
	local spec = Models.Item
	local prefix = spec.Prefix or "ITM_"
	local movers = { spec.SpinPrefix or "Spin_", spec.WavePrefix or "Wave_" }
	local known = spec.Known or {}
	local renamed = spec.Renamed or {}
	local retired = spec.Retired or {}
	local idleSpec = Attributes.Idle
	local idleValues = `{table.concat(idleSpec.Values, ", ")} ou rien`
	for _, inst in scanned do
		local isItem = isPrefixed(inst, prefix)
		local idle = inst:GetAttribute(idleSpec.Name)
		if idle ~= nil and not isItem then
			local holder = itemAncestor(inst, prefix)
			if holder then
				problem(
					"Objets",
					`{inst:GetFullName()} : attribut Idle ignoré par le code ici, le poser sur le modèle {holder.Name} lui-même (L-045)`
				)
			end
		end
		if not isItem then
			continue
		end
		if idle ~= nil and (type(idle) ~= "string" or table.find(idleSpec.Values, idle) == nil) then
			problem("Objets", `{inst:GetFullName()} : Idle = « {tostring(idle)} », attendu {idleValues} (L-045)`)
		end

		local label = inst:GetFullName()
		local name = inst.Name
		if not known[name] then
			local newName = renamed[name]
			if newName then
				problem("Objets", `{label} : objet renommé au catalogue v2 (L-045), le renommer {newName} (ItemId compris)`)
			elseif retired[name] then
				problem("Objets", `{label} : objet retiré du catalogue v2 (L-045), le jeu ne l'utilise plus`)
			else
				local near = nearName(known, name)
				local fix = if near then ` : le renommer {near}` else ""
				problem("Objets", `{label} : {name} n'est pas au catalogue d'objets (Config/Items){fix}`)
			end
		end

		local itemId = inst:GetAttribute(Attributes.ItemId.Name)
		local expectedId = string.sub(name, #prefix + 1)
		if type(itemId) == "string" and itemId ~= "" and itemId ~= expectedId then
			problem("Objets", `{label} : ItemId = « {itemId} », attendu « {expectedId} » (le nom du modèle sans {prefix}, 10.3)`)
		end

		local primary = spec.PrimaryPart or "Root"
		local roots: { Instance } = indexOf(inst)[primary] or {}
		if #roots > 1 then
			problem("Objets", `{label} : {#roots} éléments nommés {primary}, un seul attendu (la pièce PrimaryPart)`)
		end
		for _, root in roots do
			local holder = moverAncestor(root, inst, movers)
			if holder then
				problem(
					"Objets",
					`{label}.{primary} est dans {holder.Name} : une pièce {moverPrefix(holder, movers)} bouge, le pivot du modèle bougerait avec elle (L-045)`
				)
			end
		end

		local pieces: { Instance } = {}
		for _, descendant in inst:GetDescendants() do
			local moverName = moverPrefix(descendant, movers)
			if moverName then
				if descendant:IsA("BasePart") or descendant:IsA("Model") then
					table.insert(pieces, descendant)
				else
					problem(
						"Objets",
						`{label}.{descendant.Name} : une pièce {moverName} doit être une pièce (BasePart) ou un Model (trouvé : {descendant.ClassName})`
					)
				end
			end
		end
		if #pieces > 0 then
			for _, descendant in inst:GetDescendants() do
				local part0, part1 = jointParts(descendant)
				if part0 and part1 then
					for _, piece in pieces do
						if isInsideOrSelf(part0, piece) ~= isInsideOrSelf(part1, piece) then
							problem(
								"Objets",
								`{label}.{piece.Name} : soudée au reste du modèle par {descendant.Name} ({descendant.ClassName}), elle ne pourrait pas bouger seule : retirer la soudure (L-045)`
							)
						end
					end
				end
			end
		end
	end
end

-- Icônes ICON_<ItemId> (liaison L-055, doc 10.3) : une par objet du catalogue, trouvée par le code
-- (Contract/Icons : un Decal à Texture non vide, dans ReplicatedStorage/Assets). Pas encore livrées :
-- une ligne « pas encore livré » avec les noms qui manquent. Un nom ICON_ hors catalogue (faute de
-- frappe, ancien objet) ou qui n'est pas un Decal, dans la place ou les assets : un problème.
local function checkIcons(scanned: { Instance })
	local iconPrefix = Icons.Prefix
	local missing: { string } = {}
	local names: { [string]: boolean } = {}
	for _, item in Items.List do
		local name = Icons.name(item.Id)
		names[name] = true
		if Icons.find(item.Id) == nil then
			table.insert(missing, name)
		end
	end
	for _, inst in scanned do
		local name = inst.Name
		if not startsWith(name, iconPrefix) then
			continue
		end
		local label = inst:GetFullName()
		if not inst:IsA("Decal") then
			problem("Objets", `{label} : une icône d'objet doit être un Decal (trouvé : {inst.ClassName}, 10.3)`)
		elseif not names[name] then
			local near = nearName(names, name)
			local fix = if near then ` : la renommer {near}` else ""
			problem("Objets", `{label} : {string.sub(name, #iconPrefix + 1)} n'est pas au catalogue d'objets (Config/Items){fix}`)
		end
	end
	if #missing > 0 then
		local folder = `ReplicatedStorage.{table.concat(Icons.Folder, ".")}`
		pending("Objets", `icônes ICON_* : {#Items.List - #missing} sur {#Items.List} livrées dans {folder} (manquent : {listNames(missing)})`)
	end
end

-- UI (2.2) ---------------------------------------------------------------------

local function checkScreen(category: string, gui: Instance, screen: Screen)
	local reported: { [string]: boolean } = {}
	local missing: { Missing } = {}
	for _, element in screen.Elements do
		local current: Instance = gui
		local walked = ""
		local found = true
		for segment in string.gmatch(element.Path, "[^%.]+") do
			walked = if walked == "" then segment else `{walked}.{segment}`
			local matches = Find.all(current, segment)
			if #matches == 0 then
				-- Un parent manquant compte une fois, pas une fois par élément qu'il contient.
				if not reported[walked] then
					reported[walked] = true
					local detail = hint(nearName(indexOf(current), segment), segment)
					table.insert(missing, { name = walked, detail = detail, plural = false })
				end
				found = false
				break
			end
			if #matches > 1 and not reported[walked .. "*"] then
				reported[walked .. "*"] = true
				problem(category, `{screen.Name}.{walked} : {#matches} éléments portent ce nom, le code n'en prendra qu'un`)
			end
			current = matches[1]
		end
		if found then
			local shown = `{screen.Name}.{element.Path}`
			local class = element.Class
			if class and not current:IsA(class) then
				problem(category, `{shown} doit être un {CLASS_LABELS[class] or class} (trouvé : {current.ClassName})`)
			end
			if element.Template and current:IsA("GuiObject") and (current :: GuiObject).Visible then
				problem(category, `{shown} doit être caché (Visible = false) : le code le clone`)
			end
		end
	end
	reportMissing(category, screen.Name, missing)

	for _, descendant in gui:GetDescendants() do
		if RESERVED[descendant.Name] then
			problem(
				category,
				`{descendant:GetFullName()} : « {descendant.Name} » est aussi une propriété Roblox, le renommer (Label, ItemName…) (2.2)`
			)
		end
	end
end

-- Un écran rangé ailleurs que là où le code le cherche.
local function findElsewhere(name: string): Instance?
	for _, root in { StarterGui, ReplicatedStorage, ServerStorage, Workspace } :: { Instance } do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("LayerCollector") then
			return found
		end
	end
	return nil
end

-- `deep` : l'écran peut être rangé dans un sous-dossier du conteneur.
local function checkGuiSet(
	category: string,
	screens: { Screen },
	container: Instance?,
	containerPath: string,
	what: string,
	deep: boolean
)
	local known: { [string]: string } = {}
	for _, screen in screens do
		known[normalize(screen.Name)] = screen.Name
		local gui = if container then container:FindFirstChild(screen.Name, deep) else nil
		if gui == nil then
			local elsewhere = findElsewhere(screen.Name)
			local parent = if elsewhere then elsewhere.Parent else nil
			if parent then
				problem(category, `{screen.Name} trouvé dans {parent:GetFullName()}, attendu dans {containerPath}`)
			else
				pending(category, `{screen.Name} absent : {what} pas encore livré`)
			end
		elseif not gui:IsA(screen.Class) then
			problem(category, `{screen.Name} doit être un {screen.Class} (trouvé : {gui.ClassName})`)
		else
			checkScreen(category, gui, screen)
		end
	end

	-- Écran mal nommé : même nom qu'un écran du contrat, à la casse ou à la ponctuation près.
	for _, name in UI.Later do
		known[normalize(name)] = name
	end
	if container then
		local children = if deep then container:GetDescendants() else container:GetChildren()
		for _, child in children do
			local exact = known[normalize(child.Name)]
			if exact and exact ~= child.Name and child:IsA("LayerCollector") then
				problem(category, `{child:GetFullName()} : le nom exact du contrat est {exact}`)
			end
		end
	end
end

-- Animations (2.4) -------------------------------------------------------------

local function checkAnimFolder(folder: Instance, specs: { Anim }, jobs: { Job })
	local label = folder:GetFullName()
	local byName: { [string]: boolean } = {}
	local expectedNames: { string } = {}
	for _, spec in specs do
		byName[spec.Name] = true
		table.insert(expectedNames, spec.Name)
	end

	local seen: { [string]: number } = {}
	for _, child in folder:GetChildren() do
		seen[child.Name] = (seen[child.Name] or 0) + 1
		if not byName[child.Name] then
			local near = nearName(byName, child.Name)
			if near then
				problem("Animations", `{label}.{child.Name} : le nom exact du contrat est {near}`)
			else
				problem(
					"Animations",
					`{label}.{child.Name} : animation hors contrat 2.4 (nom mal écrit ? attendus : {table.concat(expectedNames, ", ")})`
				)
			end
		end
	end

	local missing: { string } = {}
	for _, spec in specs do
		local inst = folder:FindFirstChild(spec.Name)
		local shown = `{label}.{spec.Name}`
		if inst == nil then
			table.insert(missing, spec.Name)
		elseif not inst:IsA("Animation") then
			problem("Animations", `{shown} doit être un objet Animation (trouvé : {inst.ClassName})`)
		else
			if (seen[spec.Name] or 0) > 1 then
				problem("Animations", `{shown} : {seen[spec.Name]} objets portent ce nom, un seul attendu`)
			end
			local id = (inst :: Animation).AnimationId
			if string.match(id, "%d+") == nil then
				problem("Animations", `{shown} : AnimationId vide, y coller l'ID publié au nom du groupe`)
			else
				table.insert(jobs, { shown = shown, id = id, spec = spec })
			end
		end
	end
	if #missing > 0 then
		pending("Animations", `{label} : pas encore livrée(s) : {table.concat(missing, ", ")}`)
	end
end

local function checkPlayerAnimations(jobs: { Job })
	local folder = walk(ReplicatedStorage, Animations.PlayerFolder)
	if folder == nil then
		local path = `ReplicatedStorage.{table.concat(Animations.PlayerFolder, ".")}`
		pending("Animations", `{path} absent : les {#Animations.Player} animations du joueur ne sont pas encore livrées`)
	else
		checkAnimFolder(folder, Animations.Player, jobs)
	end
end

local function containsWord(name: string, words: { string }): boolean
	local lower = string.lower(name)
	for _, word in words do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- Noms propres aux vendeurs (Wave), absents des vigiles.
local function vendorOnlyNames(): { string }
	local guard: { [string]: boolean } = {}
	for _, spec in Animations.Guard do
		guard[spec.Name] = true
	end
	local only: { string } = {}
	for _, spec in Animations.Vendor do
		if not guard[spec.Name] then
			table.insert(only, spec.Name)
		end
	end
	return only
end

local function isVendor(model: Instance, folder: Instance?): boolean
	if containsWord(model.Name, VENDOR_WORDS) then
		return true
	end
	if containsWord(model.Name, GUARD_WORDS) then
		return false
	end
	if hasTaggedAncestor(model, VENDOR_SHOP_TAGS) then
		return true
	end
	if folder then
		for _, name in vendorOnlyNames() do
			if folder:FindFirstChild(name) then
				return true
			end
		end
	end
	return false
end

-- Conducteur du camion de l'événement (L-071, point 7 ; a42) : un Model avec Humanoid rangé dans le
-- camion de Clément (ou dans sa copie posée par TruckEventService). Son seul contrat : Idle, facultatif.
local DRIVER_HOLDERS = { "ENV_Event_Truck", "EventTruck" }

local function isDriver(model: Instance): boolean
	local parent = model.Parent
	while parent and parent ~= game do
		if table.find(DRIVER_HOLDERS, parent.Name) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Modèle animé = Model avec un Humanoid, rangé dans Assets ou livré dans _INBOX_CLEMENT,
-- ou posé dans la map avec un dossier Animations (un mannequin d'échelle est ignoré).
local function checkAnimatedModels(scanned: { Instance }, jobs: { Job })
	local models = 0
	for _, inst in scanned do
		if not inst:IsA("Model") then
			continue
		end
		local humanoid = inst:FindFirstChildOfClass("Humanoid")
		local folder = inst:FindFirstChild(Animations.FolderName)
		local inMap = inst:IsDescendantOf(Workspace) and not isInside(inst, inbox)
		if humanoid == nil or (inMap and folder == nil) then
			continue
		end
		models += 1
		contractModels[inst] = true
		local label = inst:GetFullName()
		local vendor = isVendor(inst, folder)
		local driver = isDriver(inst) -- a42 : conducteur du camion, Idle seulement
		if humanoid:FindFirstChildOfClass("Animator") == nil then
			problem("Animations", `{label}.Humanoid : Animator manquant (10.4)`)
		end
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			problem("Animations", `{label}.Humanoid : rig {humanoid.RigType.Name}, attendu R15 (2.4)`)
		end
		if folder == nil then
			local specs = if driver then Animations.Driver elseif vendor then Animations.Vendor else Animations.Guard
			local names: { string } = {}
			for _, spec in specs do
				table.insert(names, spec.Name)
			end
			local kind = if driver then "conducteur" elseif vendor then "vendeur" else "vigile"
			pending(
				"Animations",
				`{label}.{Animations.FolderName} absent : animations de {kind} pas encore livrées ({table.concat(names, ", ")})`
			)
		else
			checkAnimFolder(
				folder,
				if driver then Animations.Driver elseif vendor then Animations.Vendor else Animations.Guard,
				jobs
			)
		end
	end
	if models == 0 then
		pending("Animations", "Vigiles et vendeurs (modèles avec Humanoid) : aucun livré")
	end
end

local function readClip(id: string): ClipResult
	local ok, value = pcall(function()
		return AnimationClipProvider:GetAnimationClipAsync(id)
	end)
	return { ok = ok, value = value }
end

local function isEmptyClip(clip: any): boolean
	if typeof(clip) ~= "Instance" then
		return false
	end
	local instance = clip :: Instance
	return instance:IsA("KeyframeSequence") and #instance:GetChildren() == 0
end

local function compareClip(job: Job, clip: AnimationClip)
	local spec = job.spec
	if clip.Loop ~= spec.Loop then
		local got = if clip.Loop then "en boucle" else "sans boucle"
		local want = if spec.Loop then "en boucle" else "sans boucle"
		problem("Animations", `{job.shown} : {got}, attendu {want} (2.4)`)
	end
	if clip.Priority.Name ~= spec.Priority then
		problem("Animations", `{job.shown} : priorité {clip.Priority.Name}, attendu {spec.Priority} (2.4)`)
	end
	local marker = spec.Marker
	if marker == nil then
		return
	end
	local markers: { [string]: boolean } = {}
	local keyframes: { [string]: boolean } = {}
	for _, descendant in clip:GetDescendants() do
		if descendant:IsA("KeyframeMarker") or descendant:IsA("MarkerCurve") then
			markers[descendant.Name] = true
		elseif descendant:IsA("Keyframe") then
			keyframes[descendant.Name] = true
		end
	end
	if markers[marker] then
		return
	end
	if clip:IsA("KeyframeSequence") then
		local extra = if keyframes[marker]
			then ` (« {marker} » est le nom d'une image clé : poser plutôt un marqueur, Add Animation Event)`
			else ""
		problem("Animations", `{job.shown} : marqueur {marker} absent{extra} (2.4)`)
	else
		note("Animations", `{job.shown} : animation en courbes, marqueur {marker} à vérifier dans l'éditeur`)
	end
end

-- Lit le contenu de chaque animation (une fois par ID), en parallèle, puis compare
-- boucle, priorité et marqueur au contrat. Peut attendre jusqu'à CLIP_TIMEOUT secondes.
local function checkClips(jobs: { Job })
	if not CHECK_ANIMATION_CONTENT or #jobs == 0 then
		return
	end
	local results: { [string]: ClipResult } = {}
	local started: { [string]: boolean } = {}
	local remaining = 0
	for _, job in jobs do
		local id = job.id
		if not started[id] then
			started[id] = true
			remaining += 1
			task.spawn(function()
				local result = readClip(id)
				if result.ok and isEmptyClip(result.value) then
					result = readClip(id) -- une 1re lecture rend parfois une animation vide
				end
				results[id] = result
				remaining -= 1
			end)
		end
	end
	local deadline = os.clock() + CLIP_TIMEOUT
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.2)
	end

	for _, job in jobs do
		local result = results[job.id]
		if result == nil then
			note("Animations", `{job.shown} : contenu non lu en {CLIP_TIMEOUT} s ; boucle, priorité et marqueur non vérifiés`)
		elseif not result.ok then
			local reason = string.match(tostring(result.value), "[^\n]+") or "erreur inconnue"
			problem(
				"Animations",
				`{job.shown} : animation illisible ({reason}) ; ID faux, ou publiée sur un compte perso au lieu du groupe (2.4)`
			)
		elseif isEmptyClip(result.value) then
			note("Animations", `{job.shown} : contenu vide à la lecture ; boucle, priorité et marqueur non vérifiés`)
		else
			compareClip(job, result.value)
		end
	end
end

-- Scripts (2.2, liaison 3.3) ---------------------------------------------------

local function ownerOf(inst: Instance): Instance?
	local parent = inst.Parent
	while parent and parent ~= game do
		if contractModels[parent] then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

local function checkScript(inst: Instance)
	local path = inst:GetFullName()
	if inst:IsDescendantOf(StarterGui) then
		problem("Scripts", `{path} : aucun script dans l'UI (2.2), même un FX_ (liaison 3.3)`)
		return
	end
	local owner = ownerOf(inst)
	if owner then
		problem("Scripts", `{path} : aucun script dans {owner.Name}, modèle répété ou animé (liaison 3.3, règle 7)`)
	elseif not inst:IsDescendantOf(Workspace) then
		problem("Scripts", `{path} : aucun script dans les assets ; un FX_ ne vit que dans le décor unique (liaison 3.3)`)
	elseif not startsWith(inst.Name, "FX_") then
		problem(
			"Scripts",
			`{path} : script hors du code d'Ironix (venu du Creator Store ?) ; seuls les FX_ du décor sont permis (liaison 3.3)`
		)
	elseif inst.ClassName ~= "Script" or (inst :: Script).RunContext ~= Enum.RunContext.Client then
		problem("Scripts", `{path} : un FX_ doit être un Script avec RunContext = Client (liaison 3.3, règle 3)`)
	end
end

local function checkScripts(scanned: { Instance })
	for _, inst in scanned do
		if inst:IsA("LuaSourceContainer") then
			checkScript(inst)
		end
	end
	for _, inst in StarterGui:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			checkScript(inst)
		end
	end
end

-- Vérification complète ----------------------------------------------------------

local function run()
	lines = {}
	counts = { problem = 0, warning = 0, pending = 0, note = 0 }
	indexCache = {}
	contractModels = {}
	inbox = Workspace:FindFirstChild(INBOX_NAME)
	sandbox = Workspace:FindFirstChild(SANDBOX_NAME)
	assetRoots = {}
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild("Assets")
		if assets then
			table.insert(assetRoots, assets)
		end
	end

	local scanned: { Instance } = {}
	for _, inst in Workspace:GetDescendants() do
		if not isInside(inst, sandbox) and not isCharacter(inst) then
			table.insert(scanned, inst)
		end
	end
	for _, root in assetRoots do
		for _, inst in root:GetDescendants() do
			table.insert(scanned, inst)
		end
	end

	checkAttributes(scanned)
	checkTags()
	checkPlotIndex()
	checkModels(scanned)
	checkItems(scanned)
	checkIcons(scanned)
	checkGuiSet("UI", UI.Screens, StarterGui, "StarterGui", "écran", false)
	local billboardPath = `ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")}`
	checkGuiSet("Billboards", UI.Billboards, walk(ReplicatedStorage, UI.BillboardFolder), billboardPath, "billboard", true)
	local jobs: { Job } = {}
	checkPlayerAnimations(jobs)
	checkAnimatedModels(scanned, jobs)
	checkScripts(scanned)
	checkClips(jobs) -- seule étape qui attend
	printReport()
end

function ContractChecker.Start()
	if not RunService:IsStudio() then
		return
	end
	run()
end

return ContractChecker
