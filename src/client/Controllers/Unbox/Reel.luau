--!strict
-- Rouleau de l'ouverture des colis v2 (DEV-050 ; spec ouverture-colis, étapes 2 à 4), module
-- d'aide d'UnboxController (client) :
--   Reel.rollPos(t, T, Ta, p, L)   position du défilement (en objets) au temps t : formule de la spec ;
--   Reel.compose(zone, tier, winner, full, rng) -> Composition
--       les objets du rouleau : raretés tirées avec les probabilités du colis dans sa zone
--       (ShelfBoxes.OddsFor), puis un objet au hasard parmi ceux de (zone, rareté) ; le gagnant
--       (l'objet choisi par le serveur, UnboxReveal) à l'index W = ReelLead + ReelCount ; dans 40 %
--       des cas, frôlement : en W − 1, un objet d'une rareté plus haute que ce colis peut donner ;
--   Reel.newStrip(viewport, items, icons?) -> Strip
--       rendu dans un ViewportFrame (ReelView de UI_Unbox, ou l'aperçu de ItemPreview) : trois
--       objets à la fois au plus (le visible, celui qui entre, celui qui sort), caméra fixe ; les
--       objets arrivent par le haut et ressortent par le bas. Chaque objet est un clone ITM_*,
--       sans ses scripts, qui tourne sur lui-même ; avec `icons` (le rouleau ReelView, liaison
--       L-055), un objet dont l'icône ICON_<ItemId> est livrée (Contract/Icons) est montré en 2D :
--       un ImageLabel immobile, dans un cadre ReelIcons posé par le code sur la vue (mêmes cases,
--       même taille que le modèle, et la teinte de la vue : ImageColor3 et ImageTransparency de
--       ReelView, donc les mêmes silhouettes noires puis les couleurs). Sans icône, le clone 3D (ou
--       le cube V0) comme avant. Les icônes du rouleau sont téléchargées dès sa création ;
--   Reel.cloneModel(item) -> Model
--       copie de l'ITM_* de l'objet (ReplicatedStorage/Assets/Items, sous-dossiers permis), sans
--       scripts ; tant qu'il n'est pas livré, un cube V0 de la couleur de sa rareté.
-- Aucune règle de jeu ici : le serveur a déjà choisi l'objet ; le reste du rouleau n'est que du
-- spectacle, tiré côté client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local ShelfBoxes = require(Config:WaitForChild("ShelfBoxes"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons"))

type Item = Items.Item

export type Composition = {
	Items: { Item }, -- de 1 à Winner + ReelTail
	Winner: number, -- W = ReelLead + ReelCount (24 en version complète, 10 en courte)
	Start: number, -- index de l'objet au centre au début du défilement (ReelLead)
	NearMiss: boolean, -- frôlement : Items[Winner − 1] est d'une rareté plus haute
	Stop: number, -- position où le défilement s'arrête, avant le dernier cran
}

export type Strip = {
	-- Montre les objets autour de la position `pos` (index fractionnaire de l'objet au centre),
	-- tournés de `angle` radians sur eux-mêmes ; `drop` (en cases, 0 par défaut) les décale vers
	-- le bas, pour leur sortie du colis.
	Set: (self: Strip, pos: number, angle: number, drop: number?) -> (),
	Destroy: (self: Strip) -> (),
}

-- Modèles ITM_ de Clément, depuis ReplicatedStorage (contrat 10.3, sous-dossiers permis).
local ITEMS_FOLDER = { "Assets", "Items" }
local V0_BLOCK = 1.2 -- V0 proposé, absent du doc : cube (studs) d'un ITM_* pas encore livré
local VISIBLE_AROUND = 1 -- objets gardés de part et d'autre de l'objet au centre (3 en tout)
local ICON_LAYER = "ReelIcons" -- cadre des icônes, posé par le code sur la vue (détruit avec le rouleau)

local Reel = {}

------------------------------------------------------------------------------
-- Défilement et composition (fonctions pures)
------------------------------------------------------------------------------

-- Position (en objets) au temps t d'un défilement de durée T ; Ta = accélération, p = freinage,
-- L = distance. Formule de la spec, telle quelle : pic d'environ 28 objets/s, moins de 3 objets/s
-- pendant les 1,4 dernières secondes (version complète).
function Reel.rollPos(t: number, T: number, Ta: number, p: number, L: number): number
	Ta = math.min(Ta, T * 0.5)
	local Td = T - Ta
	if t <= 0 then
		return 0
	end
	if t >= T then
		return L
	end
	local D = L / (1 + 0.5 * p * Ta / Td)
	if t < Ta then
		return 0.5 * (D * p / (Td * Ta)) * t * t
	end
	return 0.5 * D * p * Ta / Td + D * (1 - (1 - (t - Ta) / Td) ^ p)
end

-- Objets tirables de (zone, rareté) : Items.AllZones pour un Secret ou un Divin (toutes zones), sinon
-- Items.ByZone (catalogue v2, une liste par case).
local function itemsOf(zone: number, rarityId: string): { Item }
	local allZones = Items.AllZones[rarityId]
	if allZones ~= nil then
		return allZones
	end
	local byZone = Items.ByZone[zone]
	local list = if byZone then byZone[rarityId] else nil
	return list or {}
end

type Choice = { Weight: number, List: { Item } }

-- Raretés au-dessus de l'ordre `above` (0 : toutes) que ce colis peut donner dans sa zone
-- (probabilité > 0) et qui ont au moins un objet, avec leur poids (pourcentage).
local function choices(zone: number, tier: string, above: number): { Choice }
	local odds = ShelfBoxes.OddsFor(zone, tier) or {}
	local out: { Choice } = {}
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if rarity.Order > above and weight > 0 then
			local list = itemsOf(zone, rarity.Id)
			if #list > 0 then
				table.insert(out, { Weight = weight, List = list })
			end
		end
	end
	return out
end

-- Une rareté tirée selon les poids, puis un objet au hasard parmi les siens ; nil si `list` est vide.
local function draw(list: { Choice }, rng: Random): Item?
	local total = 0
	for _, choice in list do
		total += choice.Weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local picked = list[#list] -- arrondi des nombres à virgule : la dernière rareté
	for _, choice in list do
		if roll < choice.Weight then
			picked = choice
			break
		end
		roll -= choice.Weight
	end
	return picked.List[rng:NextInteger(1, #picked.List)]
end

-- Le rouleau d'un colis `tier` de la zone `zone` dont le serveur a tiré `winner` (version complète
-- ou courte). Sans objet tirable dans la zone, les cases prennent le gagnant.
function Reel.compose(zone: number, tier: string, winner: Item, full: boolean, rng: Random): Composition
	local count = if full then Unbox.ReelCount.Full else Unbox.ReelCount.Short
	local winnerIndex = Unbox.ReelLead + count
	local all = choices(zone, tier, 0)
	local list: { Item } = {}
	for index = 1, winnerIndex + Unbox.ReelTail do
		list[index] = if index == winnerIndex then winner else (draw(all, rng) or winner)
	end
	-- Frôlement : seulement vers une rareté plus haute que ce colis peut donner (spec, étape 3).
	local nearMiss = false
	local winnerRarity = Rarities.ById[winner.Rarity]
	local higher = choices(zone, tier, if winnerRarity then winnerRarity.Order else math.huge)
	if #higher > 0 and rng:NextNumber() < Unbox.NearMissChance then
		local item = draw(higher, rng)
		if item then
			list[winnerIndex - 1] = item
			nearMiss = true
		end
	end
	return {
		Items = list,
		Winner = winnerIndex,
		Start = Unbox.ReelLead,
		NearMiss = nearMiss,
		Stop = winnerIndex - (if nearMiss then Unbox.NearMissStop else Unbox.StopShort),
	}
end

------------------------------------------------------------------------------
-- Modèles et rendu
------------------------------------------------------------------------------

local function findTemplate(asset: string): Instance?
	local folder: Instance? = ReplicatedStorage
	for _, name in ITEMS_FOLDER do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	return if folder then folder:FindFirstChild(asset, true) else nil
end

function Reel.cloneModel(item: Item): Model
	local template = findTemplate(item.Asset)
	local copy: Instance? = nil
	if template ~= nil and (template:IsA("Model") or template:IsA("BasePart")) then
		copy = template:Clone() -- nil si Archivable = false
	end
	local model: Model
	if copy ~= nil and copy:IsA("Model") then
		model = copy :: Model
	else
		model = Instance.new("Model")
		if copy ~= nil then
			copy.Parent = model
			model.PrimaryPart = copy :: BasePart
		else
			-- V0 : objet pas encore livré dans Assets/Items.
			local rarity = Rarities.ById[item.Rarity]
			local block = Instance.new("Part")
			block.Name = "V0Block"
			block.Size = Vector3.new(V0_BLOCK, V0_BLOCK, V0_BLOCK)
			block.Color = if rarity then rarity.Color else Color3.new(1, 1, 1)
			block.Material = Enum.Material.SmoothPlastic
			block.Parent = model
			model.PrimaryPart = block
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	model.Name = item.Asset
	return model
end

-- Met `model` à l'échelle de sa case (hauteur `height`, largeur `width` même en tournant) et
-- renvoie son pivot vu depuis le centre de sa boîte (pour le faire tourner autour de ce centre).
local function fit(model: Model, height: number, width: number): CFrame
	local box, size = model:GetBoundingBox()
	local spin = math.sqrt(size.X * size.X + size.Z * size.Z)
	local factor = math.min(height / math.max(size.Y, 1e-3), width / math.max(spin, 1e-3))
	if math.abs(factor - 1) > 1e-3 then
		local ok = pcall(function()
			model:ScaleTo(model:GetScale() * factor)
		end)
		if ok then
			box = model:GetBoundingBox()
		end
	end
	return (box:ToObjectSpace(model:GetPivot()))
end

-- Une case montrée : le clone 3D (model, offset) ou l'icône 2D (icon).
type Built = { model: Model?, offset: CFrame, icon: ImageLabel? }

type StripFields = {
	viewport: ViewportFrame,
	items: { Item },
	textures: { [number]: string }, -- [index] = icône de l'objet (mode icônes, icône livrée)
	camera: Camera,
	width: number,
	layer: Frame?, -- cadre des icônes (créé à la première)
	built: { [number]: Built },
	destroyed: boolean,
}

local StripClass = {}
StripClass.__index = StripClass

-- Icône de chaque case (une recherche par objet différent), et la liste des textures à télécharger.
local function iconsOf(items: { Item }): ({ [number]: string }, { string })
	local textures: { [number]: string } = {}
	local byId: { [string]: string } = {}
	local missing: { [string]: boolean } = {}
	local distinct: { string } = {}
	for index, item in items do
		local texture: string? = byId[item.Id]
		if texture == nil and not missing[item.Id] then
			texture = Icons.get(item.Id)
			if texture ~= nil then
				byId[item.Id] = texture
				table.insert(distinct, texture)
			else
				missing[item.Id] = true
			end
		end
		if texture ~= nil then
			textures[index] = texture
		end
	end
	return textures, distinct
end

-- Rendu d'une liste d'objets dans `viewport` ; `icons` : les objets dont l'icône est livrée sont
-- montrés en 2D. La caméra fixe est posée comme CurrentCamera du ViewportFrame : à l'appelant de
-- garder l'ancienne valeur s'il doit la remettre.
function Reel.newStrip(viewport: ViewportFrame, items: { Item }, icons: boolean?): Strip
	local slot = Unbox.ReelSlot
	local camera = Instance.new("Camera")
	camera.FieldOfView = Unbox.ReelFov
	-- Une case remplit la hauteur de la vue : on ne voit qu'un objet à la fois (spec, étape 2).
	local distance = (slot / 2) / math.tan(math.rad(Unbox.ReelFov / 2))
	-- Face avant d'un objet vers −Z de son pivot (10.1) : la caméra se tient de ce côté.
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local size = viewport.AbsoluteSize
	local aspect = if size.Y > 0 then size.X / size.Y else 1
	local textures: { [number]: string } = {}
	if icons then
		local distinct: { string }
		textures, distinct = iconsOf(items)
		if #distinct > 0 then
			-- Les icônes se téléchargent pendant que le colis s'ouvre : au plus vite, chaque case
			-- ne reste que quelques centièmes de seconde au centre.
			task.spawn(Icons.preload, distinct)
		end
	end
	local fields: StripFields = {
		viewport = viewport,
		items = items,
		textures = textures,
		camera = camera,
		width = math.min(Unbox.ReelFit, slot * aspect * 0.85),
		layer = nil,
		built = {},
		destroyed = false,
	}
	return (setmetatable(fields, StripClass) :: any) :: Strip
end

-- Cadre des icônes, de la taille de la vue : il coupe ce qui sort de la fenêtre du rouleau, comme
-- la vue coupe les modèles. Créé par le code, il ne touche à aucune propriété de ReelView.
local function iconLayer(self: StripFields): Frame
	local existing = self.layer
	if existing ~= nil then
		return existing
	end
	local layer = Instance.new("Frame")
	layer.Name = ICON_LAYER
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = self.viewport.ZIndex
	layer.Parent = self.viewport
	self.layer = layer
	return layer
end

-- Icône d'une case : carrée, de la taille que prendrait le modèle (self.width sur une case de
-- ReelSlot : la hauteur de la vue), centrée sur sa case.
local function newIcon(self: StripFields, item: Item, texture: string): ImageLabel
	local share = self.width / Unbox.ReelSlot
	local icon = Instance.new("ImageLabel")
	icon.Name = Icons.name(item.Id)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Size = UDim2.fromScale(share, share)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = texture
	icon.ZIndex = self.viewport.ZIndex
	icon.Parent = iconLayer(self)
	return icon
end

-- Une case : l'icône si elle est livrée (mode icônes), sinon le clone 3D de l'objet.
local function build(self: StripFields, item: Item, texture: string?): Built
	if texture ~= nil then
		return { model = nil, offset = CFrame.identity, icon = newIcon(self, item, texture) }
	end
	local model = Reel.cloneModel(item)
	local offset = fit(model, Unbox.ReelFit, self.width)
	model.Parent = self.viewport
	return { model = model, offset = offset, icon = nil }
end

local function destroyBuilt(entry: Built)
	if entry.model then
		entry.model:Destroy()
	end
	if entry.icon then
		entry.icon:Destroy()
	end
end

function StripClass.Set(self: StripFields, pos: number, angle: number, drop: number?)
	if self.destroyed then
		return
	end
	local slot = Unbox.ReelSlot
	local center = math.floor(pos + (drop or 0) + 0.5)
	for index, entry in self.built do
		if math.abs(index - center) > VISIBLE_AROUND then
			self.built[index] = nil
			destroyBuilt(entry)
		end
	end
	local viewport = self.viewport
	for index = center - VISIBLE_AROUND, center + VISIBLE_AROUND do
		local item = self.items[index]
		if item ~= nil then
			local entry = self.built[index]
			if entry == nil then
				local made = build(self, item, self.textures[index])
				self.built[index] = made
				entry = made
			end
			-- Écart à la case du centre, en cases (vers le haut) : une case = la hauteur de la vue.
			local rise = index - pos - (drop or 0)
			local model = entry.model
			local icon = entry.icon
			if model ~= nil then
				model:PivotTo(CFrame.new(0, rise * slot, 0) * CFrame.Angles(0, angle, 0) * entry.offset)
			elseif icon ~= nil then
				icon.Position = UDim2.fromScale(0.5, 0.5 - rise)
				-- La teinte de la vue ne s'applique qu'au rendu 3D : l'icône la reprend.
				icon.ImageColor3 = viewport.ImageColor3
				icon.ImageTransparency = viewport.ImageTransparency
			end
		end
	end
end

function StripClass.Destroy(self: StripFields)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, entry in self.built do
		destroyBuilt(entry)
	end
	table.clear(self.built)
	local layer = self.layer
	if layer ~= nil then
		layer:Destroy()
		self.layer = nil
	end
	self.camera:Destroy()
end

return Reel
