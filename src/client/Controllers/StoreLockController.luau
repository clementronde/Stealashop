--!strict
-- StoreLockController (client) : le magasin PNJ fermé pour le voleur seulement (Cantin, 2026-11-11).
--
-- Dès qu'un joueur prend un colis sur un rayon, le serveur (StoreHeistService) ferme ce magasin pour lui
-- seul, jusqu'au retour du vigile apparu pour ce vol (ou, au plus tard, jusqu'à la réouverture du
-- magasin). Le serveur décide de tout : plus de prise pour lui, et il est sorti devant la vitrine s'il
-- entre. Ici, on le montre, chez lui seul : le rideau `Shutter` du magasin (contrat 10.4) apparaît
-- baissé et solide, puis remonte à la fin. Les autres joueurs voient le magasin normal.
-- Vague 24 (a70) : le serveur ne met le magasin dans ClosedStores que si aucun vigile n'y est ni n'est
-- sur le point d'y entrer (il l'en retire le temps qu'un vigile passe) : le rideau tombe après la
-- sortie du vigile et remonte avant son retour, jamais à travers lui. Rien ne change ici.
--
-- Lu ici, posé par StoreHeistService (mêmes noms là-bas) :
--   - l'attribut ClosedStores du joueur local : les StoreId fermés pour lui, séparés par des virgules ;
--   - sur chaque magasin taggé NPCStore : StoreId, et ShutterClosedPivot (CFrame du rideau baissé).
--
-- Comment : une copie locale du rideau (jamais répliquée, jamais touchée par le serveur), rangée dans
-- Workspace/LocalShutters sous le nom « <StoreId>_LocalShutter » (jamais « Shutter » : aucune recherche
-- du contrat ne la trouve), tombe en FALL_TIME s jusqu'à ShutterClosedPivot puis devient solide. Le vrai
-- rideau est caché chez ce joueur (LocalTransparencyModifier, comme CarryController) : le serveur peut
-- le monter ou le descendre pour tout le monde sans gêner la copie. À la fin, la copie perd sa
-- collision, remonte en RISE_TIME s vers la place du vrai rideau, disparaît, et le vrai réapparaît.
-- Rien n'est ajouté aux modèles de Clément ; rien n'est envoyé au serveur.
-- Streaming : un magasin (ou son rideau) qui arrive plus tard reçoit sa copie à son arrivée ; un vrai
-- rideau qui revient du streaming est recaché.
--
-- API (client) :
--   StoreLockController.GetLocks() -> { { StoreId: string, Shown: boolean } }
--       Magasins fermés pour le joueur local, triés, et si leur rideau local est posé (test en Studio).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local STORE_TAG = "NPCStore" -- contrat 2.1
local SHUTTER_NAME = "Shutter" -- contrat 10.4
local STORE_ID_ATTRIBUTE = "StoreId"
local CLOSED_ATTRIBUTE = "ClosedStores"
local CLOSED_SEPARATOR = ","
local SHUTTER_PIVOT_ATTRIBUTE = "ShutterClosedPivot"
local FOLDER_NAME = "LocalShutters"
local CLONE_NAME = "%s_LocalShutter"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées

-- V0 proposé, absent du doc : les temps du rideau du serveur (StoreHeistService).
local FALL_TIME = 0.4
local RISE_TIME = 0.8

export type LockInfo = { StoreId: string, Shown: boolean }

type Lock = {
	id: string,
	store: Model?, -- magasin trouvé (streaming : peut manquer)
	real: PVInstance?, -- le vrai rideau, caché ici
	clone: PVInstance?, -- la copie locale baissée
	cloneParts: { BasePart },
	hidden: { [Instance]: number }, -- LocalTransparencyModifier d'avant, pièces et décalques du vrai rideau
	watch: RBXScriptConnection?, -- arrivée du rideau dans un magasin déjà là
	stopMotion: (() -> ())?,
	finish: (() -> ())?, -- pendant la remontée : la termine tout de suite
}

local StoreLockController = {}

local localPlayer = Players.LocalPlayer
local locks: { [string]: Lock } = {}
local releasing: { [string]: Lock } = {} -- copies qui remontent
local folder: Folder? = nil
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[StoreLockController] {message}`)
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

-- Les StoreId fermés pour le joueur local.
local function readClosed(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local value = localPlayer:GetAttribute(CLOSED_ATTRIBUTE)
	if type(value) == "string" then
		for id in string.gmatch(value, `[^{CLOSED_SEPARATOR}]+`) do
			set[id] = true
		end
	end
	return set
end

local function findStore(id: string): Model?
	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		if instance:IsA("Model") and inMap(instance) and instance:GetAttribute(STORE_ID_ATTRIBUTE) == id then
			return instance :: Model
		end
	end
	return nil
end

local function findShutter(store: Model): PVInstance?
	local object = store:FindFirstChild(SHUTTER_NAME, true)
	if object and object:IsA("PVInstance") then
		return object :: PVInstance
	end
	return nil
end

-- Toutes les pièces d'un rideau (lui-même s'il est une pièce, et ses descendants).
local function partsOf(object: Instance): { BasePart }
	local parts: { BasePart } = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Déplace `target` sur path(alpha), alpha de 0 à 1 en `duration` s ; renvoie de quoi l'arrêter.
local function animate(target: PVInstance, path: (alpha: number) -> CFrame, duration: number, done: () -> ()): () -> ()
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		if target.Parent == nil then
			stop()
			return
		end
		local alpha = if duration > 0 then math.min((os.clock() - started) / duration, 1) else 1
		target:PivotTo(path(alpha))
		if alpha >= 1 then
			stop()
			done()
		end
	end)
	return stop
end

local function stopMotion(lock: Lock)
	local stop = lock.stopMotion
	if stop then
		lock.stopMotion = nil
		stop()
	end
end

local function setSolid(lock: Lock, solid: boolean)
	for _, part in lock.cloneParts do
		part.CanCollide = solid
	end
end

-- Cache le vrai rideau chez ce joueur (sa valeur d'avant est gardée pour la fin).
local function hideReal(lock: Lock, real: PVInstance)
	lock.real = real
	local function hide(instance: Instance)
		if instance:IsA("BasePart") then
			local part = instance :: BasePart
			if lock.hidden[part] == nil then
				lock.hidden[part] = part.LocalTransparencyModifier
			end
			part.LocalTransparencyModifier = 1
		elseif instance:IsA("Decal") then -- Texture compris
			local decal = instance :: Decal
			if lock.hidden[decal] == nil then
				lock.hidden[decal] = decal.LocalTransparencyModifier
			end
			decal.LocalTransparencyModifier = 1
		end
	end
	hide(real)
	for _, descendant in real:GetDescendants() do
		hide(descendant)
	end
end

local function showReal(lock: Lock)
	for instance, value in lock.hidden do
		if instance:IsA("BasePart") then
			(instance :: BasePart).LocalTransparencyModifier = value
		elseif instance:IsA("Decal") then
			(instance :: Decal).LocalTransparencyModifier = value
		end
	end
	table.clear(lock.hidden)
end

-- La copie locale du vrai rideau : sans script, ancrée, sans collision tant qu'elle tombe.
local function makeClone(lock: Lock, real: PVInstance): PVInstance?
	local ok, copy = pcall(function(): Instance?
		return real:Clone()
	end)
	if not ok or copy == nil or not copy:IsA("PVInstance") then
		warnOnce(`clone:{lock.id}`, `{lock.id} : rideau impossible à copier (Archivable ?), pas de rideau local (le serveur garde la fermeture)`)
		return nil
	end
	local clone = copy :: PVInstance
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("Decal") then
			(descendant :: Decal).LocalTransparencyModifier = 0
		end
	end
	local parts = partsOf(clone)
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.LocalTransparencyModifier = 0
	end
	clone.Name = string.format(CLONE_NAME, lock.id)
	lock.cloneParts = parts
	return clone
end

-- Pose le rideau local du magasin `lock.id` s'il est là (sinon à son arrivée).
local function attach(lock: Lock)
	local store = lock.store
	if store == nil or store.Parent == nil then
		store = findStore(lock.id)
		lock.store = store
		local old = lock.watch
		if old then
			old:Disconnect()
			lock.watch = nil
		end
	end
	if store == nil then
		return -- pas encore arrivé (streaming) : GetInstanceAddedSignal
	end
	local real = findShutter(store)
	if real == nil then
		if lock.watch == nil then
			local watched: Model = store
			lock.watch = watched.DescendantAdded:Connect(function(descendant: Instance)
				if descendant.Name == SHUTTER_NAME and locks[lock.id] == lock then
					task.defer(attach, lock)
				end
			end)
		end
		return
	end
	if lock.clone then
		if lock.real ~= real then
			hideReal(lock, real) -- revenu du streaming : un nouvel objet à cacher
		end
		return
	end
	local closed = store:GetAttribute(SHUTTER_PIVOT_ATTRIBUTE)
	if typeof(closed) ~= "CFrame" then
		warnOnce(`pivot:{lock.id}`, `{lock.id} : attribut {SHUTTER_PIVOT_ATTRIBUTE} absent, pas de rideau local`)
		return
	end
	local clone = makeClone(lock, real)
	if clone == nil then
		return
	end
	local from = real:GetPivot()
	local to: CFrame = closed
	clone:PivotTo(from)
	clone.Parent = getFolder()
	lock.clone = clone
	hideReal(lock, real)
	lock.stopMotion = animate(clone, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end, FALL_TIME, function()
		lock.stopMotion = nil
		if locks[lock.id] == lock then
			setSolid(lock, true) -- solide une fois en bas, comme le rideau du serveur
		end
	end)
end

-- Fin de la fermeture : la copie remonte vers la place du vrai rideau, puis disparaît.
local function release(lock: Lock)
	local watch = lock.watch
	if watch then
		watch:Disconnect()
		lock.watch = nil
	end
	stopMotion(lock)
	local clone = lock.clone
	lock.clone = nil
	if clone == nil then
		showReal(lock)
		return
	end
	setSolid(lock, false)
	local real = lock.real
	local from = clone:GetPivot()
	local to = if real and real.Parent then real:GetPivot() else from
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		stopMotion(lock)
		lock.finish = nil
		if releasing[lock.id] == lock then
			releasing[lock.id] = nil
		end
		clone:Destroy()
		showReal(lock)
	end
	lock.finish = finish
	releasing[lock.id] = lock
	lock.stopMotion = animate(clone, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end, RISE_TIME, finish)
end

local function refresh()
	local closed = readClosed()
	for id, lock in locks do
		if not closed[id] then
			locks[id] = nil
			release(lock)
		end
	end
	for id in closed do
		if locks[id] == nil then
			-- Refermé pendant que l'ancienne copie remonte : elle finit tout de suite (vrai rideau
			-- rendu visible), avant que la nouvelle le recache.
			local old = releasing[id]
			local finishOld = if old then old.finish else nil
			if finishOld then
				finishOld()
			end
			local lock: Lock = {
				id = id,
				store = nil,
				real = nil,
				clone = nil,
				cloneParts = {},
				hidden = {},
				watch = nil,
				stopMotion = nil,
				finish = nil,
			}
			locks[id] = lock
			attach(lock)
		end
	end
end

function StoreLockController.GetLocks(): { LockInfo }
	local list: { LockInfo } = {}
	for id, lock in locks do
		table.insert(list, { StoreId = id, Shown = lock.clone ~= nil })
	end
	table.sort(list, function(a: LockInfo, b: LockInfo): boolean
		return a.StoreId < b.StoreId
	end)
	return list
end

function StoreLockController.Start()
	localPlayer:GetAttributeChangedSignal(CLOSED_ATTRIBUTE):Connect(refresh)
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(function(instance: Instance)
		task.defer(function()
			local id = instance:GetAttribute(STORE_ID_ATTRIBUTE)
			local lock = if type(id) == "string" then locks[id] else nil
			if lock then
				lock.store = nil -- revenu du streaming : on le recherche
				attach(lock)
			end
		end)
	end)
	refresh()
end

return StoreLockController
