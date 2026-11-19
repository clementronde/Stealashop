--!strict
-- ShelfCapService (Cantin, 2026-11-14, liaison L-140) : des murs invisibles au-dessus des rayons et des grands
-- meubles des magasins PNJ, pour que personne ne puisse s'y percher. C'est le code qui les pose, au démarrage
-- et pour tout magasin ajouté plus tard ; les modèles de Clément ne sont pas modifiés. Valeurs :
-- Config/ShelfCaps. La grimpe contre la face d'un rayon est coupée côté client (StoreClimbController).
--
-- Magasin PNJ = Model taggé `NPCStore`, posé dans la map (Workspace, hors _INBOX_CLEMENT, comme
-- StoreHeistService). Le code ne connaît les rayons que par leurs emplacements de colis `ShelfSlot_01` à
-- `_10` (Attachments, contrat 10.4), et les grands meubles que par leur forme ; il ne lit aucun autre nom du
-- modèle que ceux du contrat 10.4 (Bounds, Window, WindowFractured, Shutter, Door). Tout se calcule dans le
-- repère du volume `Bounds`, donc aussi pour un magasin tourné.
--   1. Pièces solides du magasin : ses BasePart à CanCollide vrai, sauf Bounds, les colis (tag ShelfBox) et
--      les objets sortis (tag ShelfItem), les vigiles (Model avec un Humanoid) et le dossier ShelfCaps
--      lui-même. Le petit décor (produits, enseignes des rayons), sans collision, ne compte pas : on ne peut
--      pas se tenir dessus.
--   2. Rayons. Meuble d'un emplacement : en montant depuis l'emplacement, les pièces solides qui le couvrent
--      (à l'aplomb), tant que chacune commence à moins de ShelfCaps.StackGap au-dessus du haut atteint
--      (planches, dessus). Le dessus du rayon = le haut de la dernière ; la largeur et la longueur = celles
--      de l'ensemble de ces pièces. Deux emplacements du même meuble (les deux faces d'une gondole) donnent
--      le même bloc.
--      Bloc : largeur et longueur du meuble ; bas = dessus du rayon + Gap, ou, quand un emplacement est posé
--      SUR le dessus (à moins de OnTopTolerance), son haut + ContentHeight + Gap, au plus dessus +
--      MaxClearance (sous 5 studs, un perso R15 ne s'y glisse pas).
--   3. Grands meubles (Play du 14/11 : le frigo du fond, les comptoirs, les cartons empilés) : chaque pièce
--      solide de l'étape 1 dont le dessus, dans Bounds, fait au moins FurnitureMinTop × FurnitureMinTop
--      studs, est à au moins FurnitureMinHeight studs au-dessus du sol (bas de Bounds) et à plus de
--      FurnitureCeilingMargin studs du haut de Bounds. Sont donc laissés de côté : le sol et les marches, les
--      murs, piliers et montants (trop fins), le plafond et ce qui touche le haut de Bounds, et tout ce qui
--      est dans Window, WindowFractured, Shutter ou Door (vitrine, rideau, portes). Meuble haut et étroit
--      (T-061, Play du 19/11 : la `Comtoise_Case` de l'Antiquaire, dessus 1,8 × 2,25 à 8,2 studs du sol,
--      atteinte d'un seul saut) : un dessus d'au moins FurnitureNarrowMinTop × FurnitureNarrowMinTop studs
--      suffit quand il est entre FurnitureNarrowMinHeight et FurnitureNarrowMaxHeight studs au-dessus du sol
--      (plus haut qu'un perso, encore à portée de saut) ; le petit meuble plus bas garde la règle 2 × 2.
--      Bloc : le dessus de la
--      pièce (coupé au bord de Bounds), bas = dessus + Gap. Les pièces sont prises de la plus haute à la plus
--      basse ; une pièce dont le dessus tient entièrement sous un bloc déjà posé (un rayon déjà couvert par
--      ses ShelfSlot, le corps d'un comptoir sous son plateau) n'en reçoit pas un deuxième.
--   Pour tous les blocs : Part `ShelfCap_xx` dans le dossier `ShelfCaps` du magasin (recréé à chaque
--   passage), haut = haut de Bounds (on ne peut pas se tenir dessus), Transparency 1, Anchored, CanCollide
--   vrai, CanTouch, CanQuery et CastShadow faux : les rayons de ligne de vue du vigile, le contrôle « Fly »
--   de l'anti-triche (rayon vers le sol) et le sol des objets l'ignorent ; les invites des colis et des
--   objets ont RequiresLineOfSight = false (HeistController). Le bloc ne dépasse pas du meuble : il ne ferme
--   aucune allée au chemin des vigiles (PathfindingService).
-- Exception de Clément : attribut `NoShelfCap` (vrai) sur une pièce ou sur un de ses modèles ou dossiers
-- parents dans le magasin : pas de bloc au-dessus (un rayon dont une pièce l'a n'en reçoit pas non plus).
-- Comptage : attributs OnShelves et OnFurniture sur le dossier ShelfCaps, total dans la sortie au démarrage.
-- Un emplacement sans meuble solide au-dessus, ou un rayon qui monte jusqu'au haut de Bounds : pas de bloc
-- (message dans la sortie).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local ShelfCaps = require(Shared.Config.ShelfCaps)

local STORE_TAG = "NPCStore" -- contrat 2.1 (Contract/Tags)
local BOUNDS_NAME = "Bounds" -- contrat 10.4
local SLOT_FORMAT = "ShelfSlot_%02d" -- contrat 10.4
-- Enfants du contrat 10.4 qui ne sont pas des meubles (vitrine, éclats, rideau, porte).
local NOT_FURNITURE: { [string]: boolean } = { Window = true, WindowFractured = true, Shutter = true, Door = true }
local SHELF_BOX_TAG = "ShelfBox" -- posé par StoreHeistService sur les colis
local SHELF_ITEM_TAG = "ShelfItem" -- posé par StoreHeistService sur les objets sortis (Shared/ShelfOpenState)
local INBOX_NAME = "_INBOX_CLEMENT"
local EPSILON = 0.05 -- studs : arrondi des contacts entre pièces

type Box = { Min: Vector3, Max: Vector3, NoCap: boolean, Furniture: boolean }
type Cap = { Min: Vector3, Max: Vector3, Bottom: number, Top: number }

local ShelfCapService = {}

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

-- Boîte de `part` alignée sur les axes du repère `frame` (coins min et max, dans ce repère).
local function localBox(frame: CFrame, part: BasePart): (Vector3, Vector3)
	local rel = frame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local r, u, b = rel.RightVector, rel.UpVector, rel.LookVector
	local extent = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(b.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(b.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(b.Z) * half.Z
	)
	return rel.Position - extent, rel.Position + extent
end

-- Ce que disent la pièce et ses parents jusqu'au magasin (inclus) : à ignorer (vigile, colis, objet sorti),
-- exception NoShelfCap, pièce du contrat qui n'est pas un meuble.
local function classify(part: BasePart, store: Model): (boolean, boolean, boolean)
	local skip, noCap, contract = false, false, false
	local node: Instance? = part
	while node do
		if node ~= part and node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			skip = true
		end
		if CollectionService:HasTag(node, SHELF_BOX_TAG) or CollectionService:HasTag(node, SHELF_ITEM_TAG) then
			skip = true
		end
		if node:GetAttribute(ShelfCaps.NoCapAttribute) == true then
			noCap = true
		end
		if node == store then
			break
		end
		if NOT_FURNITURE[node.Name] and node.Parent == store then
			contract = true
		end
		node = node.Parent
	end
	return skip, noCap, contract
end

-- Pièces solides du magasin (point 1 de l'en-tête), en boîtes dans le repère `frame`.
local function solidBoxes(store: Model, bounds: BasePart, frame: CFrame): { Box }
	local folder = store:FindFirstChild(ShelfCaps.FolderName)
	local list: { Box } = {}
	for _, descendant in store:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant ~= bounds
			and descendant.CanCollide
			and not (folder and descendant:IsDescendantOf(folder))
		then
			local skip, noCap, contract = classify(descendant, store)
			if not skip then
				local low, high = localBox(frame, descendant)
				table.insert(list, { Min = low, Max = high, NoCap = noCap, Furniture = not contract })
			end
		end
	end
	return list
end

-- Meuble de l'emplacement placé en `p` (repère de Bounds), point 2 de l'en-tête : (coin min, coin max) de
-- son emprise, hauteur de son dessus et exception NoShelfCap sur une de ses pièces, ou nil.
local function furnitureAt(p: Vector3, solids: { Box }, ceiling: number): (Vector3?, Vector3?, number?, boolean)
	local column: { Box } = {}
	for _, box in solids do
		if
			p.X >= box.Min.X - EPSILON
			and p.X <= box.Max.X + EPSILON
			and p.Z >= box.Min.Z - EPSILON
			and p.Z <= box.Max.Z + EPSILON
			and box.Max.Y >= p.Y - EPSILON
			and box.Min.Y < ceiling
		then
			table.insert(column, box)
		end
	end
	table.sort(column, function(a: Box, b: Box): boolean
		return a.Min.Y < b.Min.Y
	end)
	local top = p.Y
	local low: Vector3? = nil
	local high: Vector3? = nil
	local noCap = false
	for _, box in column do
		if box.Min.Y > top + ShelfCaps.StackGap then
			break
		end
		top = math.max(top, box.Max.Y)
		low = if low then low:Min(box.Min) else box.Min
		high = if high then high:Max(box.Max) else box.Max
		noCap = noCap or box.NoCap
	end
	if low == nil or high == nil then
		return nil, nil, nil, false
	end
	return low, high, top, noCap
end

-- Le dessus (x0..x1, z0..z1) à la hauteur `top` tient-il entièrement sous un bloc déjà posé ?
local function underCap(caps: { Cap }, x0: number, z0: number, x1: number, z1: number, top: number): boolean
	for _, cap in caps do
		if
			x0 >= cap.Min.X - EPSILON
			and x1 <= cap.Max.X + EPSILON
			and z0 >= cap.Min.Z - EPSILON
			and z1 <= cap.Max.Z + EPSILON
			and top <= cap.Bottom + EPSILON
		then
			return true
		end
	end
	return false
end

local function round(value: number): string
	return string.format("%.1f", value)
end

-- Blocs des rayons (point 2 de l'en-tête), puis emprises des rayons laissés sans bloc par NoShelfCap.
local function shelfCaps(store: Model, frame: CFrame, solids: { Box }, ceiling: number): ({ Cap }, { Cap })
	local caps: { [string]: Cap } = {}
	local order: { string } = {}
	local excluded: { [string]: boolean } = {}
	for number = 1, Balance.Heist.ShelfSlots do
		local name = string.format(SLOT_FORMAT, number)
		local attachment = store:FindFirstChild(name, true)
		if attachment == nil or not attachment:IsA("Attachment") then
			continue
		end
		local p = frame:PointToObjectSpace((attachment :: Attachment).WorldPosition)
		local low, high, top, noCap = furnitureAt(p, solids, ceiling)
		if low == nil or high == nil or top == nil then
			warn(`[ShelfCapService] {store.Name}/{name} : aucun meuble solide sous l'emplacement, pas de bloc`)
			continue
		end
		local bottom = top + ShelfCaps.Gap
		if p.Y >= top - ShelfCaps.OnTopTolerance then
			bottom = math.max(bottom, p.Y + ShelfCaps.ContentHeight + ShelfCaps.Gap)
		end
		local key = `{round(low.X)}:{round(low.Z)}:{round(high.X)}:{round(high.Z)}`
		if noCap then
			excluded[key] = true -- exception de Clément : ni bloc ici, ni bloc de meuble par-dessus (étape 3)
		end
		local cap = caps[key]
		if cap then
			cap.Bottom = math.max(cap.Bottom, bottom)
			cap.Top = math.max(cap.Top, top)
		else
			caps[key] = { Min = low, Max = high, Bottom = bottom, Top = top }
			table.insert(order, key)
		end
	end
	local list: { Cap } = {}
	local blocked: { Cap } = {}
	for _, key in order do
		local cap = caps[key]
		if excluded[key] then
			cap.Bottom = math.huge -- rien par-dessus : underCap le voit comme couvert
			table.insert(blocked, cap)
			continue
		end
		local bottom = math.min(cap.Bottom, cap.Top + ShelfCaps.MaxClearance)
		if cap.Bottom > bottom + EPSILON then
			warn(`[ShelfCapService] {store.Name} : bloc ramené à {ShelfCaps.MaxClearance} studs au-dessus du rayon (il en fallait {round(cap.Bottom - cap.Top)})`)
		end
		if bottom >= ceiling - EPSILON then
			warn(`[ShelfCapService] {store.Name} : rayon qui monte jusqu'au haut de {BOUNDS_NAME}, pas de bloc`)
			continue
		end
		cap.Bottom = bottom
		table.insert(list, cap)
	end
	return list, blocked
end

-- Blocs des grands meubles (point 3 de l'en-tête), en plus des blocs `placed` des rayons (et des emprises
-- `placed` à Bottom infini des rayons exclus).
local function furnitureCaps(placed: { Cap }, solids: { Box }, floor: number, ceiling: number, area: Box): { Cap }
	local candidates: { Box } = {}
	for _, box in solids do
		local top = box.Max.Y
		if
			box.Furniture
			and not box.NoCap
			and top >= floor + ShelfCaps.FurnitureMinHeight - EPSILON
			and top <= ceiling - ShelfCaps.FurnitureCeilingMargin + EPSILON
		then
			local low = box.Min:Max(area.Min)
			local high = box.Max:Min(area.Max)
			local narrow = math.min(high.X - low.X, high.Z - low.Z)
			local above = top - floor
			if
				narrow >= ShelfCaps.FurnitureMinTop - EPSILON
				or (
					narrow >= ShelfCaps.FurnitureNarrowMinTop - EPSILON
					and above >= ShelfCaps.FurnitureNarrowMinHeight - EPSILON
					and above <= ShelfCaps.FurnitureNarrowMaxHeight + EPSILON
				)
			then
				table.insert(candidates, { Min = low, Max = high, NoCap = false, Furniture = true })
			end
		end
	end
	table.sort(candidates, function(a: Box, b: Box): boolean
		if a.Max.Y ~= b.Max.Y then
			return a.Max.Y > b.Max.Y
		end
		if a.Min.X ~= b.Min.X then
			return a.Min.X < b.Min.X
		end
		return a.Min.Z < b.Min.Z
	end)
	local all = table.clone(placed)
	local list: { Cap } = {}
	for _, box in candidates do
		local top = box.Max.Y
		if underCap(all, box.Min.X, box.Min.Z, box.Max.X, box.Max.Z, top) then
			continue
		end
		local cap: Cap = { Min = box.Min, Max = box.Max, Bottom = top + ShelfCaps.Gap, Top = top }
		table.insert(all, cap)
		table.insert(list, cap)
	end
	return list
end

local function makeCap(folder: Folder, frame: CFrame, cap: Cap, ceiling: number, number: number)
	local part = Instance.new("Part")
	part.Name = string.format(ShelfCaps.CapNameFormat, number)
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(cap.Max.X - cap.Min.X, ceiling - cap.Bottom, cap.Max.Z - cap.Min.Z)
	local center = Vector3.new((cap.Min.X + cap.Max.X) / 2, (cap.Bottom + ceiling) / 2, (cap.Min.Z + cap.Max.Z) / 2)
	part.CFrame = frame * CFrame.new(center)
	part.Parent = folder
end

-- Pose (ou repose) les blocs du magasin `store`. Renvoie le nombre de blocs posés (rayons, grands meubles).
function ShelfCapService.Apply(store: Model): (number, number)
	if not inMap(store) then
		return 0, 0
	end
	local found = store:FindFirstChild(BOUNDS_NAME, true)
	if found == nil or not found:IsA("BasePart") then
		warn(`[ShelfCapService] {store:GetFullName()} : pas de volume « {BOUNDS_NAME} » (Part), aucun bloc au-dessus des rayons`)
		return 0, 0
	end
	local bounds = found :: BasePart
	local old = store:FindFirstChild(ShelfCaps.FolderName)
	if old then
		old:Destroy()
	end
	local frame = bounds.CFrame
	local boundsMin, boundsMax = localBox(frame, bounds)
	local ceiling = boundsMax.Y
	local solids = solidBoxes(store, bounds, frame)
	local area: Box = { Min = boundsMin, Max = boundsMax, NoCap = false, Furniture = false }

	local onShelves, blocked = shelfCaps(store, frame, solids, ceiling)
	local placed = table.clone(onShelves)
	for _, cap in blocked do
		table.insert(placed, cap)
	end
	local onFurniture = furnitureCaps(placed, solids, boundsMin.Y, ceiling, area)

	local folder = Instance.new("Folder")
	folder.Name = ShelfCaps.FolderName
	local count = 0
	for _, cap in onShelves do
		count += 1
		makeCap(folder, frame, cap, ceiling, count)
	end
	for _, cap in onFurniture do
		count += 1
		makeCap(folder, frame, cap, ceiling, count)
	end
	folder:SetAttribute(ShelfCaps.ShelfCountAttribute, #onShelves)
	folder:SetAttribute(ShelfCaps.FurnitureCountAttribute, #onFurniture)
	folder.Parent = store
	return #onShelves, #onFurniture
end

local function applySafe(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local ok, result = pcall(ShelfCapService.Apply, instance :: Model)
	if not ok then
		warn(`[ShelfCapService] {instance:GetFullName()} : {result}`)
	end
end

function ShelfCapService.Start()
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(applySafe)
	local stores, shelves, furniture = 0, 0, 0
	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		if instance:IsA("Model") and inMap(instance) then
			local ok, onShelves, onFurniture = pcall(ShelfCapService.Apply, instance :: Model)
			if ok then
				stores += 1
				shelves += onShelves :: number
				furniture += onFurniture :: number
			else
				warn(`[ShelfCapService] {instance:GetFullName()} : {onShelves}`)
			end
		end
	end
	print(`[ShelfCapService] {shelves + furniture} bloc(s) invisible(s) dans {stores} magasin(s) : {shelves} au-dessus des rayons, {furniture} au-dessus des grands meubles`)
end

return ShelfCapService
