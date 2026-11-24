-- Banc a237 (vague 71, L-221) : AmbienceController, sons d'ambiance PlayAt = Day / Night, fondu au changement de phase.
-- Faux Roblox minimal et autonome (ci-dessous) ; vrais : AmbienceController, Contract/Attributes ; Config/Night lu pour
-- AmbienceFade (valeur extraite par run.sh, le module complet requiert DeepFreeze et Balance).
-- Les sources sont dans SOURCES (run.sh) ; NIGHT_FADE aussi.

local checks, fails = 0, 0
local function check(name: string, ok: boolean, detail: string?)
	checks += 1
	if ok then
		if VERBOSE then
			print("  ok " .. name)
		end
	else
		fails += 1
		print("  ÉCHEC " .. name .. (if detail then " (" .. detail .. ")" else ""))
	end
end

-- Faux Roblox ---------------------------------------------------------------------------------------------------
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	return s
end

local Instance = {}
local function newInstance(className: string, name: string?)
	local self = {
		ClassName = className,
		Name = name or className,
		Parent = nil,
		_children = {},
		_attrs = {},
		_attrSignals = {},
		DescendantAdded = newSignal(),
		Destroying = newSignal(), -- fusion66 : suivi des sons retirés (AmbienceController)
		AncestryChanged = newSignal(),
	}
	function self:IsDescendantOf(a)
		local p = self.Parent
		while p do
			if p == a then
				return true
			end
			p = p.Parent
		end
		return false
	end
	function self:IsA(c)
		return self.ClassName == c or (c == "Instance")
	end
	function self:GetAttribute(n)
		return self._attrs[n]
	end
	function self:SetAttribute(n, v)
		self._attrs[n] = v
		local s = self._attrSignals[n]
		if s then
			s:Fire()
		end
	end
	function self:GetAttributeChangedSignal(n)
		self._attrSignals[n] = self._attrSignals[n] or newSignal()
		return self._attrSignals[n]
	end
	function self:GetDescendants()
		local out = {}
		local function walk(i)
			for _, c in i._children do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end
	function self:WaitForChild(n)
		for _, c in self._children do
			if c.Name == n then
				return c
			end
		end
		error("WaitForChild : " .. n .. " absent du faux arbre")
	end
	return self
end
local function parentTo(child, parent)
	child.Parent = parent
	table.insert(parent._children, child)
	local p = parent
	while p do
		p.DescendantAdded:Fire(child)
		p = p.Parent
	end
end
local function remove(child)
	local parent = child.Parent
	if parent then
		local i = table.find(parent._children, child)
		if i then
			table.remove(parent._children, i)
		end
	end
	child.Parent = nil
	child.AncestryChanged:Fire(child, nil)
end

local function newSound(name: string, playAt: string?, playing: boolean, volume: number)
	local s = newInstance("Sound", name)
	s.Playing = playing
	s.Volume = volume
	s.Plays, s.Stops = 0, 0
	if playAt then
		s._attrs.PlayAt = playAt
	end
	function s:Play()
		self.Playing = true
		self.Plays += 1
	end
	function s:Stop()
		self.Playing = false
		self.Stops += 1
	end
	return s
end

local tweens = {}
local TweenService = {}
function TweenService:Create(object, info, props)
	local t = { Object = object, Info = info, Props = props, Completed = newSignal(), State = "Begin" }
	function t:Play()
		self.State = "Playing"
		table.insert(tweens, self)
	end
	function t:Cancel()
		if self.State == "Playing" then
			self.State = "Cancelled"
			self.Completed:Fire(Enum.PlaybackState.Cancelled)
		end
	end
	return t
end
local function finishTweens()
	local list = tweens
	tweens = {}
	for _, t in list do
		if t.State == "Playing" then
			for k, v in t.Props do
				t.Object[k] = v
			end
			t.State = "Completed"
			t.Completed:Fire(Enum.PlaybackState.Completed)
		end
	end
end
local function playingTweens(): number
	local n = 0
	for _, t in tweens do
		if t.State == "Playing" then
			n += 1
		end
	end
	return n
end

Enum = {
	PlaybackState = { Completed = "Completed", Cancelled = "Cancelled" },
	EasingStyle = { Linear = "Linear" },
}
TweenInfo = {
	new = function(time, style)
		return { Time = time, EasingStyle = style }
	end,
}

local Workspace = newInstance("Workspace", "Workspace")
local ReplicatedStorage = newInstance("ReplicatedStorage", "ReplicatedStorage")
local Shared = newInstance("Folder", "Shared")
parentTo(Shared, ReplicatedStorage)
local ConfigFolder = newInstance("Folder", "Config")
parentTo(ConfigFolder, Shared)
local ContractFolder = newInstance("Folder", "Contract")
parentTo(ContractFolder, Shared)
local NightModule = newInstance("ModuleScript", "Night")
NightModule._value = { AmbienceFade = NIGHT_FADE }
parentTo(NightModule, ConfigFolder)
local AttributesModule = newInstance("ModuleScript", "Attributes")
AttributesModule._value = (loadstring(SOURCES["shared/Contract/Attributes.luau"]) :: any)()
parentTo(AttributesModule, ContractFolder)

game = {
	GetService = function(_, name)
		if name == "Workspace" then
			return Workspace
		elseif name == "ReplicatedStorage" then
			return ReplicatedStorage
		elseif name == "TweenService" then
			return TweenService
		end
		error("service absent du faux Roblox : " .. name)
	end,
}
require = function(m)
	return m._value
end

-- La carte livrée par Clément -------------------------------------------------------------------------------
local Map = newInstance("Folder", "Map")
parentTo(Map, Workspace)
local birds = newSound("AMB_Z1_Birds", "Day", true, 0.4)
local crickets = newSound("AMB_Z1_Crickets", "Night", false, 0.35)
local plain = newSound("Fountain", nil, true, 0.5) -- sans PlayAt
local plainOff = newSound("Bell", nil, false, 0.6) -- sans PlayAt, arrêté
local odd = newSound("Odd", "Dusk", true, 0.3) -- valeur hors convention : ignoré
for _, s in { birds, crickets, plain, plainOff, odd } do
	parentTo(s, Map)
end
Workspace._attrs.NightPhase = "Day"

check("A0 AmbienceFade lu dans Config/Night (V0 3 s)", NIGHT_FADE == 3, tostring(NIGHT_FADE))
check("A0b Contract/Attributes.PlayAt = Day / Night", AttributesModule._value.PlayAt ~= nil
	and AttributesModule._value.PlayAt.Name == "PlayAt" and AttributesModule._value.PlayAt.Values[1] == "Day"
	and AttributesModule._value.PlayAt.Values[2] == "Night")

local Ambience = (loadstring(SOURCES["client/Controllers/AmbienceController.luau"]) :: any)()
Ambience.Start()

-- A1 : le jour, tout reste comme livré.
check("A1 jour : Birds joue à 0,4", birds.Playing and birds.Volume == 0.4)
check("A1 jour : Crickets arrêté", not crickets.Playing and crickets.Plays == 0)
check("A1 sans PlayAt : rien touché", plain.Playing and plain.Plays == 0 and plain.Stops == 0 and not plainOff.Playing and plainOff.Plays == 0)
check("A1 PlayAt hors convention : rien touché", odd.Playing and odd.Stops == 0 and odd.Plays == 0)
check("A1 état : 2 sons suivis, jour", Ambience.GetState().Count == 2 and Ambience.GetState().Night == false)
check("A1 aucun fondu au départ", playingTweens() == 0)

-- A2 : l'alerte (Warning) reste le jour.
Workspace:SetAttribute("NightPhase", "Warning")
check("A2 Warning : aucun changement", playingTweens() == 0 and birds.Playing and not crickets.Playing)

-- A3 : la nuit tombe : fondus.
Workspace:SetAttribute("NightPhase", "Night")
check("A3 nuit : deux fondus lancés", playingTweens() == 2, tostring(playingTweens()))
check("A3 Crickets démarre à 0", crickets.Playing and crickets.Volume == 0)
check("A3 Birds joue encore pendant son fondu", birds.Playing)
local fadeTime = tweens[1] and tweens[1].Info.Time
check("A3 durée du fondu = AmbienceFade", fadeTime == NIGHT_FADE, tostring(fadeTime))
finishTweens()
check("A3 fin : Birds arrêté, volume livré remis", not birds.Playing and birds.Volume == 0.4)
check("A3 fin : Crickets à 0,35", crickets.Playing and crickets.Volume == 0.35)
check("A3 sans PlayAt : toujours rien", plain.Playing and plain.Stops == 0 and not plainOff.Playing)

-- A4 : sons arrivés en pleine nuit (streaming, zone livrée plus tard) : état de la nuit tout de suite.
local rain = newSound("Rain_West", "Day", true, 0.45)
local rainNight = newSound("RainNight_West", "Night", false, 0.5)
local Speaker = newInstance("Part", "Speaker")
parentTo(Speaker, Map)
parentTo(rain, Speaker)
parentTo(rainNight, Speaker)
check("A4 son de jour arrivé la nuit : arrêté d'un coup", not rain.Playing and rain.Volume == 0.45 and playingTweens() == 0)
check("A4 son de nuit arrivé la nuit : joue à son volume", rainNight.Playing and rainNight.Volume == 0.5)
check("A4 état : 4 sons suivis", Ambience.GetState().Count == 4)

-- A5 : l'aube pendant un fondu (aller-retour) : pas de saut ni de coupure.
Workspace:SetAttribute("NightPhase", "Day")
check("A5 aube : fondus lancés", playingTweens() == 4, tostring(playingTweens()))
check("A5 aube : Birds repart de 0", birds.Playing and birds.Volume == 0)
crickets.Volume = 0.2 -- à mi-fondu
Workspace:SetAttribute("NightPhase", "Night") -- la nuit revient avant la fin
check("A5 retour : Crickets toujours en lecture, pas relancé", crickets.Playing and crickets.Plays == 1)
finishTweens()
check("A5 fin : Crickets à 0,35", crickets.Playing and crickets.Volume == 0.35)
check("A5 fin : Birds arrêté au volume livré", not birds.Playing and birds.Volume == 0.4)
check("A5 fin : Rain_West arrêté", not rain.Playing)
Workspace:SetAttribute("NightPhase", "Day")
finishTweens()
check("A5 jour : Birds et Rain_West jouent", birds.Playing and birds.Volume == 0.4 and rain.Playing and rain.Volume == 0.45)
check("A5 jour : Crickets et RainNight arrêtés", not crickets.Playing and not rainNight.Playing and crickets.Volume == 0.35)

-- A6 : sans attribut de phase (cycle coupé) : le jour.
Workspace:SetAttribute("NightPhase", nil)
check("A6 sans phase : le jour, rien ne bouge", playingTweens() == 0 and birds.Playing and not crickets.Playing)

-- A7 : un son retiré n'est plus suivi au changement suivant.
remove(rain)
Workspace:SetAttribute("NightPhase", "Night")
check("A7 son retiré : pas de fondu pour lui", playingTweens() == 3, tostring(playingTweens()))
finishTweens()
check("A7 état : 3 sons suivis", Ambience.GetState().Count == 3)

-- A8 (fusion66, T-245 raté au Play f66) : en vrai Roblox, l'objet Lua d'un Sound peut être ramassé quand plus rien ne
-- le tient côté Lua ; une table à clés faibles se vidait alors (17 sons, puis 0). Ici, des sons tenus seulement « côté
-- moteur » (Parent posé, hors de _children) : après un collectgarbage, ils doivent rester suivis.
local before = Ambience.GetState().Count
do
	for i = 1, 3 do
		local s = newSound("Ghost_" .. i, "Night", false, 0.3)
		s.Parent = Map
		Workspace.DescendantAdded:Fire(s)
	end
end
collectgarbage("collect")
collectgarbage("collect")
check("A8 après collectgarbage : les sons suivis le restent", Ambience.GetState().Count == before + 3,
	string.format("%d au lieu de %d", Ambience.GetState().Count, before + 3))

-- A9 : un son détruit (Destroying) ou sorti du Workspace (AncestryChanged) quitte la table tout de suite.
local gone = newSound("Gone", "Night", false, 0.3)
parentTo(gone, Map)
local out = newSound("Out", "Day", true, 0.3)
parentTo(out, Map)
local n = Ambience.GetState().Count
gone.Destroying:Fire()
check("A9 son détruit : plus suivi", Ambience.GetState().Count == n - 1)
remove(out)
check("A9 son sorti du Workspace : plus suivi", Ambience.GetState().Count == n - 2)
local marks = { gone.Plays, gone.Stops, gone.Volume, out.Plays, out.Stops, out.Volume }
Workspace:SetAttribute("NightPhase", "Day")
local touched = false
for _, tw in tweens do
	if tw.Object == gone or tw.Object == out then
		touched = true
	end
end
check("A9 aube : les sons retirés ne sont plus touchés", not touched and gone.Plays == marks[1] and gone.Stops == marks[2]
	and gone.Volume == marks[3] and out.Plays == marks[4] and out.Stops == marks[5] and out.Volume == marks[6])
finishTweens()

print(string.format("%d vérification(s), %d échec(s)", checks, fails))
