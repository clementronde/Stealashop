---------------------------------------------------------------- montage commun du banc a37
-- Arbre de la place (Shared depuis SOURCES, Client/Controllers/UI/Motion), joueur local, outils
-- de vérification : instantané des propriétés d'un écran (pour « aucun changement durable »),
-- relevé des textes d'un label image par image.
TIMED_TWEENS = true -- les tweens avancent avec le temps simulé (ext-motion.luau)

local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end
CLIENT_FOLDER = folder(StarterPlayerScripts, "Client")
CONTROLLERS = folder(CLIENT_FOLDER, "Controllers")
UI_FOLDER = folder(CONTROLLERS, "UI")
MOTION_MODULE = moduleScript(UI_FOLDER, "Motion", "client/Controllers/UI/Motion.luau")

function new(class, props, parent)
	local inst = InstanceAPI.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
function el(root, name)
	return root:FindFirstChild(name, true)
end

P1 = new("Player", { Name = "Alice", UserId = 101, DisplayName = "Alice" })
local character = new("Model", { Name = "Alice" })
new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 0) }, character)
character.Parent = Workspace
P1.Character = character
PLAYER_GUI = new("PlayerGui", { Name = "PlayerGui" }, P1)
P1.Parent = Players
CLIENT_PLAYER = P1
Players.LocalPlayer = P1

FormatC = requireModule(ReplicatedStorage.Shared.Format, "client")
UiMotionC = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")

-- Le UIScale ajouté par Motion sur `object`, ou nil.
function motionScale(object)
	for _, child in object:GetChildren() do
		if child.ClassName == "UIScale" and child.Name == UiMotionC.ScaleName then
			return child
		end
	end
	return nil
end
function countClass(object, class)
	local n = 0
	for _, child in object:GetChildren() do
		if child.ClassName == class then
			n += 1
		end
	end
	return n
end

-- Instantané de `root` et de ses descendants : classe, parent, toutes les propriétés (par
-- référence : une valeur réécrite, même égale, compte comme un changement si c'est une autre table).
function snapshot(root)
	local snap = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, inst in list do
		snap[inst] = { parent = inst.Parent, props = table.clone(rawget(inst, "_props")) }
	end
	return snap
end
-- true si `root` est comme dans `snap` : mêmes instances (aucune en plus, aucune en moins), mêmes
-- parents, mêmes propriétés, sauf celles de `allowed` ({ [instance] = { Propriété = true } }).
-- Sinon false et la première différence.
function sameAs(snap, root, allowed)
	local now = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, inst in list do
		now[inst] = true
		if snap[inst] == nil then
			return false, `en plus : {inst.Name} ({inst.ClassName})`
		end
	end
	for inst, saved in snap do
		if not now[inst] then
			return false, `disparu : {saved.props.Name}`
		end
		if inst.Parent ~= saved.parent then
			return false, `parent changé : {inst.Name}`
		end
		local props = rawget(inst, "_props")
		local skip = allowed and allowed[inst] or {}
		for k, v in saved.props do
			if not skip[k] and props[k] ~= v then
				return false, `{inst.Name}.{k} changé`
			end
		end
		for k in props do
			if saved.props[k] == nil then
				return false, `{inst.Name}.{k} ajouté`
			end
		end
	end
	return true, "identique"
end

-- Relève le texte de `label` à chaque image pendant `seconds` : liste des textes différents vus.
function watchTexts(label, seconds)
	local seen = { label.Text }
	local frames = math.ceil(seconds * 30 - 1e-6)
	for _ = 1, frames do
		step(1 / 30)
		if label.Text ~= seen[#seen] then
			table.insert(seen, label.Text)
		end
	end
	return seen
end
-- Relève l'échelle du UIScale de Motion sur `object` à chaque image (nil si absent).
function watchScale(object, seconds)
	local values = {}
	local frames = math.ceil(seconds * 30 - 1e-6)
	for _ = 1, frames do
		step(1 / 30)
		local scale = motionScale(object)
		table.insert(values, if scale then scale.Scale else false)
	end
	return values
end
-- « $1.5K » → 1500, « +$12/s » → 12 (lecture des textes du format du HUD, pour comparer).
function parseMoney(text)
	local sign, number, suffix = string.match(text, "^([%+%-]?)%$([%d%.]+)(%a*)")
	if number == nil then
		return nil
	end
	local mult = ({ [""] = 1, K = 1e3, M = 1e6, B = 1e9, T = 1e12 })[suffix] or 1
	local value = tonumber(number) * mult
	return if sign == "-" then -value else value
end
function countLog(pattern)
	local n = 0
	for _, line in LOG do
		if string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
