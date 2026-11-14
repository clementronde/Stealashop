--!strict
-- ShelfCapService (Cantin, 2026-11-14, liaison L-140) : des murs invisibles au-dessus des rayons des magasins
-- PNJ, pour que personne ne puisse se percher sur un rayon. C'est le code qui les pose, au démarrage et pour
-- tout magasin ajouté plus tard ; les modèles de Clément ne sont pas modifiés. Valeurs : Config/ShelfCaps.
--
-- Magasin PNJ = Model taggé `NPCStore`, posé dans la map (Workspace, hors _INBOX_CLEMENT, comme
-- StoreHeistService). Le code ne connaît les rayons que par leurs emplacements de colis `ShelfSlot_01` à
-- `_10` (Attachments, contrat 10.4) : chaque rayon est retrouvé à partir de ses emplacements, par la forme
-- des pièces, sans lire aucun autre nom du modèle. Tout se calcule dans le repère du volume `Bounds` (contrat
-- 10.4), donc aussi pour un magasin tourné.
--   1. Pièces solides du magasin : ses BasePart à CanCollide vrai, sauf Bounds, les colis (tag ShelfBox),
--      les vigiles (Model avec un Humanoid) et le dossier ShelfCaps lui-même. Le petit décor (produits,
--      enseignes des rayons), sans collision, ne compte pas : on ne peut pas se tenir dessus.
--   2. Meuble d'un emplacement : en montant depuis l'emplacement, les pièces solides qui le couvrent (à
--      l'aplomb), tant que chacune commence à moins de ShelfCaps.StackGap au-dessus du haut atteint (planches,
--      dessus). Le dessus du rayon = le haut de la dernière ; la largeur et la longueur = celles de l'ensemble
--      de ces pièces. Deux emplacements du même meuble (les deux faces d'une gondole) donnent le même bloc.
--   3. Bloc (Part `ShelfCap_xx` dans le dossier `ShelfCaps` du magasin, recréé à chaque passage) : largeur et
--      longueur du meuble ; bas = dessus du rayon + Gap, ou, quand un emplacement est posé SUR le dessus (à
--      moins de OnTopTolerance), son haut + ContentHeight + Gap, au plus dessus + MaxClearance (sous 5 studs,
--      un perso R15 ne s'y glisse pas) ; haut = haut de Bounds (on ne peut pas se tenir dessus).
--      Transparency 1, Anchored, CanCollide vrai, CanTouch, CanQuery et CastShadow faux : les rayons de ligne
--      de vue du vigile, le contrôle « Fly » de l'anti-triche (rayon vers le sol) et le sol des objets
--      l'ignorent ; les invites des colis et des objets ont RequiresLineOfSight = false (HeistController).
--      Le bloc ne dépasse pas du meuble : il ne ferme aucune allée au chemin des vigiles (PathfindingService).
-- Un emplacement sans meuble solide au-dessus, ou un meuble qui monte jusqu'au haut de Bounds : pas de bloc
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
local SHELF_BOX_TAG = "ShelfBox" -- posé par StoreHeistService sur les colis
local INBOX_NAME = "_INBOX_CLEMENT"
local EPSILON = 0.05 -- studs : arrondi des contacts entre pièces

type Box = { Min: Vector3, Max: Vector3 }
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
local function localBox(frame: CFrame, part: BasePart): Box
	local rel = frame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local r, u, b = rel.RightVector, rel.UpVector, rel.LookVector
	local extent = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(b.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(b.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(b.Z) * half.Z
	)
	return { Min = rel.Position - extent, Max = rel.Position + extent }
end

local function inHumanoidModel(part: BasePart, store: Instance): boolean
	local node: Instance? = part.Parent
	while node and node ~= store do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
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
			and not CollectionService:HasTag(descendant, SHELF_BOX_TAG)
			and not inHumanoidModel(descendant, store)
		then
			table.insert(list, localBox(frame, descendant))
		end
	end
	return list
end

-- Meuble de l'emplacement placé en `p` (repère de Bounds), point 2 de l'en-tête : (coin min, coin max) de
-- son emprise et hauteur de son dessus, ou nil.
local function furnitureAt(p: Vector3, solids: { Box }, ceiling: number): (Vector3?, Vector3?, number?)
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
	for _, box in column do
		if box.Min.Y > top + ShelfCaps.StackGap then
			break
		end
		top = math.max(top, box.Max.Y)
		low = if low then low:Min(box.Min) else box.Min
		high = if high then high:Max(box.Max) else box.Max
	end
	if low == nil or high == nil then
		return nil, nil, nil
	end
	return low, high, top
end

local function round(value: number): string
	return string.format("%.1f", value)
end

-- Pose (ou repose) les blocs du magasin `store`. Renvoie le nombre de blocs posés.
function ShelfCapService.Apply(store: Model): number
	if not inMap(store) then
		return 0
	end
	local found = store:FindFirstChild(BOUNDS_NAME, true)
	if found == nil or not found:IsA("BasePart") then
		warn(`[ShelfCapService] {store:GetFullName()} : pas de volume « {BOUNDS_NAME} » (Part), aucun bloc au-dessus des rayons`)
		return 0
	end
	local bounds = found :: BasePart
	local old = store:FindFirstChild(ShelfCaps.FolderName)
	if old then
		old:Destroy()
	end
	local frame = bounds.CFrame
	local ceiling = localBox(frame, bounds).Max.Y
	local solids = solidBoxes(store, bounds, frame)

	local caps: { [string]: Cap } = {}
	local order: { string } = {}
	for number = 1, Balance.Heist.ShelfSlots do
		local name = string.format(SLOT_FORMAT, number)
		local attachment = store:FindFirstChild(name, true)
		if attachment == nil or not attachment:IsA("Attachment") then
			continue
		end
		local p = frame:PointToObjectSpace((attachment :: Attachment).WorldPosition)
		local low, high, top = furnitureAt(p, solids, ceiling)
		if low == nil or high == nil or top == nil then
			warn(`[ShelfCapService] {store.Name}/{name} : aucun meuble solide sous l'emplacement, pas de bloc`)
			continue
		end
		local bottom = top + ShelfCaps.Gap
		if p.Y >= top - ShelfCaps.OnTopTolerance then
			bottom = math.max(bottom, p.Y + ShelfCaps.ContentHeight + ShelfCaps.Gap)
		end
		local key = `{round(low.X)}:{round(low.Z)}:{round(high.X)}:{round(high.Z)}`
		local cap = caps[key]
		if cap then
			cap.Bottom = math.max(cap.Bottom, bottom)
			cap.Top = math.max(cap.Top, top)
		else
			caps[key] = { Min = low, Max = high, Bottom = bottom, Top = top }
			table.insert(order, key)
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = ShelfCaps.FolderName
	local count = 0
	for _, key in order do
		local cap = caps[key]
		local bottom = math.min(cap.Bottom, cap.Top + ShelfCaps.MaxClearance)
		if cap.Bottom > bottom + EPSILON then
			warn(`[ShelfCapService] {store.Name} : bloc ramené à {ShelfCaps.MaxClearance} studs au-dessus du rayon (il en fallait {round(cap.Bottom - cap.Top)})`)
		end
		if bottom >= ceiling - EPSILON then
			warn(`[ShelfCapService] {store.Name} : rayon qui monte jusqu'au haut de {BOUNDS_NAME}, pas de bloc`)
			continue
		end
		count += 1
		local part = Instance.new("Part")
		part.Name = string.format(ShelfCaps.CapNameFormat, count)
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(cap.Max.X - cap.Min.X, ceiling - bottom, cap.Max.Z - cap.Min.Z)
		local center = Vector3.new((cap.Min.X + cap.Max.X) / 2, (bottom + ceiling) / 2, (cap.Min.Z + cap.Max.Z) / 2)
		part.CFrame = frame * CFrame.new(center)
		part.Parent = folder
	end
	folder.Parent = store
	return count
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
	local stores, caps = 0, 0
	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		if instance:IsA("Model") and inMap(instance) then
			local ok, result = pcall(ShelfCapService.Apply, instance :: Model)
			if ok then
				stores += 1
				caps += result
			else
				warn(`[ShelfCapService] {instance:GetFullName()} : {result}`)
			end
		end
	end
	print(`[ShelfCapService] {caps} bloc(s) invisible(s) au-dessus des rayons de {stores} magasin(s)`)
end

return ShelfCapService
