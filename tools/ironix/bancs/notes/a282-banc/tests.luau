-- Banc a282 (vague GC3, audit a271 point 4) : SafeZone avec ses zones en cache, mises à jour par les signaux du tag
-- et par AncestryChanged ; repli sur GetTagged sans signaux. Le vrai src/shared/SafeZone.luau est collé avant ce
-- fichier sous SAFEZONE_SOURCE (avec ses dépendances : CollectionService et Workspace faux, ci-dessous).

local total, failed = 0, 0
local function check(name: string, ok: boolean)
	total += 1
	if ok then
		if VERBOSE then
			print("ok : " .. name)
		end
	else
		failed += 1
		print("ÉCHEC : " .. name)
	end
end

-- Faux Vector3 / CFrame (sans rotation, suffisant pour les boîtes alignées)
local Vec = {}
Vec.__index = Vec
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vec)
end
Vec.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
local CF = {}
CF.__index = CF
function CF:PointToObjectSpace(p)
	return p - self.p
end
local function cf(x, y, z)
	return setmetatable({ p = v3(x, y, z) }, CF)
end

-- Faux signaux et instances
local function newSignal(deferred: boolean?)
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(s.fns, fn)
		return {
			Disconnect = function()
				for i, f in s.fns do
					if f == fn then
						table.remove(s.fns, i)
						return
					end
				end
			end,
		}
	end
	function s:Fire(...)
		for _, f in table.clone(s.fns) do
			f(...)
		end
	end
	return s
end

local tags: { [any]: boolean } = {}
local addedSig, removedSig = newSignal(), newSignal()
local ancestryConnections = 0

local Inst = {}
Inst.__index = Inst
local function isDesc(self, other)
	local p = rawget(self, "_parent")
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
local Workspace
local function inGame(inst)
	return inst == Workspace or isDesc(inst, Workspace)
end
local function descendants(inst, out)
	for _, c in inst._children do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end
local function newInst(class: string, name: string, parent)
	local self = setmetatable({ ClassName = class, Name = name, _children = {}, _parent = nil }, Inst)
	local anc = newSignal()
	local origConnect = anc.Connect
	anc.Connect = function(s, fn)
		ancestryConnections += 1
		return origConnect(s, fn)
	end
	self.AncestryChanged = anc
	if parent then
		self:SetParent(parent)
	end
	return self
end
function Inst:IsA(c)
	if c == "BasePart" then
		return self.ClassName == "Part"
	end
	return self.ClassName == c
end
function Inst:IsDescendantOf(o)
	return isDesc(self, o)
end
function Inst:FindFirstChildOfClass(c)
	for _, ch in self._children do
		if ch.ClassName == c then
			return ch
		end
	end
	return nil
end
function Inst:FindFirstChild(n)
	for _, c in self._children do
		if c.Name == n then
			return c
		end
	end
	return nil
end
function Inst:SetParent(p)
	local wasIn = inGame(self)
	local old = self._parent
	if old then
		for i, c in old._children do
			if c == self then
				table.remove(old._children, i)
				break
			end
		end
	end
	self._parent = p
	if p then
		table.insert(p._children, self)
	end
	local nowIn = inGame(self)
	local all = descendants(self, { self })
	for _, d in all do
		d.AncestryChanged:Fire(self, p)
	end
	for _, d in all do
		if tags[d] and wasIn and not nowIn then
			removedSig:Fire(d)
		elseif tags[d] and nowIn and not wasIn then
			addedSig:Fire(d)
		end
	end
end
function Inst:GetBoundingBox()
	return self._cf, self._size
end

Workspace = newInst("Workspace", "Workspace")
local Storage = newInst("Folder", "ServerStorage")
local getTaggedCalls = 0
local withSignals = true
local CollectionService = {
	GetTagged = function(_, tag)
		getTaggedCalls += 1
		local out = {}
		for inst in tags do
			if inGame(inst) then
				table.insert(out, inst)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		if not withSignals then
			error("pas de signal dans ce faux")
		end
		return addedSig
	end,
	GetInstanceRemovedSignal = function(_, tag)
		if not withSignals then
			error("pas de signal dans ce faux")
		end
		return removedSig
	end,
}
local function addTag(inst)
	tags[inst] = true
	if inGame(inst) then
		addedSig:Fire(inst)
	end
end
local function removeTag(inst)
	tags[inst] = nil
	if inGame(inst) then
		removedSig:Fire(inst)
	end
end

local function box(name, parent, x, size)
	local p = newInst("Part", name, parent)
	p.CFrame = cf(x, 0, 0)
	p.Size = v3(size, size, size)
	return p
end

local function loadSafeZone()
	local game = {
		GetService = function(_, n)
			if n == "CollectionService" then
				return CollectionService
			elseif n == "Workspace" then
				return Workspace
			end
			error("service " .. n)
		end,
	}
	local src = "local game = ...\n" .. string.gsub(SAFEZONE_SOURCE, "%-%-!strict", "")
	local fn = assert(loadstring(src, "SafeZone"))
	return fn(game)
end

-- 1. Avec signaux : cache, zone ajoutée après, déplacée, passée dans l'inbox, tag retiré, zone détruite.
do
	local SafeZone = loadSafeZone()
	local zoneA = box("ZoneA", Workspace, 0, 10)
	addTag(zoneA)
	check("A1 point dans la zone A", SafeZone.Contains(v3(1, 0, 0)) == true)
	check("A2 point hors zone", SafeZone.Contains(v3(100, 0, 0)) == false)
	local calls = getTaggedCalls
	for _ = 1, 50 do
		SafeZone.Contains(v3(1, 0, 0))
	end
	check("A3 aucun GetTagged après le premier appel", getTaggedCalls == calls)
	local zoneB = box("ZoneB", Workspace, 100, 10)
	addTag(zoneB)
	check("A4 zone ajoutée après coup vue (signal Added)", SafeZone.Contains(v3(100, 0, 0)) == true)
	check("A5 Shares dans la même zone", SafeZone.Shares(v3(99, 0, 0), v3(101, 0, 0)) == true)
	check("A6 Shares entre deux zones = false", SafeZone.Shares(v3(1, 0, 0), v3(100, 0, 0)) == false)
	local inbox = newInst("Folder", "_INBOX_CLEMENT", Workspace)
	zoneB:SetParent(inbox)
	check("A7 zone passée dans _INBOX_CLEMENT ignorée", SafeZone.Contains(v3(100, 0, 0)) == false)
	zoneB:SetParent(Workspace)
	check("A8 zone revenue dans la map revue", SafeZone.Contains(v3(100, 0, 0)) == true)
	local folder = newInst("Folder", "Map", Workspace)
	zoneB:SetParent(folder)
	folder:SetParent(Storage)
	check("A9 dossier parent sorti de Workspace : zone ignorée", SafeZone.Contains(v3(100, 0, 0)) == false)
	folder:SetParent(Workspace)
	check("A10 dossier parent revenu : zone revue", SafeZone.Contains(v3(100, 0, 0)) == true)
	removeTag(zoneB)
	check("A11 tag retiré : zone ignorée", SafeZone.Contains(v3(100, 0, 0)) == false)
	addTag(zoneB)
	check("A12 tag remis : zone revue", SafeZone.Contains(v3(100, 0, 0)) == true)
	zoneB:SetParent(nil)
	check("A13 zone sortie du jeu : ignorée", SafeZone.Contains(v3(100, 0, 0)) == false)
	zoneB:SetParent(Workspace)
	check("A14 zone remise dans le jeu : revue (Added)", SafeZone.Contains(v3(100, 0, 0)) == true)
	-- Bounds et modèle
	local model = newInst("Model", "Lobby", Workspace)
	local bounds = box("Bounds", model, 200, 10)
	addTag(model)
	check("A15 modèle avec Bounds", SafeZone.Contains(v3(200, 0, 0)) == true)
	bounds:SetParent(nil)
	model._cf, model._size = cf(300, 0, 0), v3(4, 4, 4)
	check("A16 modèle sans Bounds : boîte englobante", SafeZone.Contains(v3(300, 0, 0)) == true)
	-- A : 1, B : suivie 4 fois (A4, A10, A12, A14), modèle : 1 ; une seule connexion encore active par zone
	check("A17 une connexion AncestryChanged par suivi de zone", ancestryConnections == 6)
	check("A17b anciennes connexions coupées (une seule active sur la zone B)", #zoneB.AncestryChanged.fns == 1)
	-- ContainsPlayer
	local char = newInst("Model", "Char", Workspace)
	local hum = newInst("Humanoid", "Humanoid", char)
	hum.Health = 100
	local root = box("HumanoidRootPart", char, 1, 2)
	root.Position = v3(1, 0, 0)
	check("A18 ContainsPlayer vivant dans la zone A", SafeZone.ContainsPlayer({ Character = char } :: any) == true)
	hum.Health = 0
	check("A19 ContainsPlayer mort = false", SafeZone.ContainsPlayer({ Character = char } :: any) == false)
end

-- 2. Sans signaux (faux Roblox des anciens bancs) : repli sur GetTagged à chaque appel.
do
	withSignals = false
	local SafeZone = loadSafeZone()
	local calls = getTaggedCalls
	check("B1 point dans la zone A sans signaux", SafeZone.Contains(v3(1, 0, 0)) == true)
	check("B2 repli : GetTagged appelé", getTaggedCalls == calls + 1)
	local zoneC = box("ZoneC", Workspace, 500, 10)
	addTag(zoneC)
	check("B3 repli : zone ajoutée vue", SafeZone.Contains(v3(500, 0, 0)) == true)
	zoneC:SetParent(Storage)
	check("B4 repli : zone sortie ignorée", SafeZone.Contains(v3(500, 0, 0)) == false)
end

print(`SafeZone : {total} vérification(s), {failed} échec(s)`)
