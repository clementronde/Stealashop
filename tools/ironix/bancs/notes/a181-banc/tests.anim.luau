-- Scénario anim (a181, vague 56, L-162) : vrai AnimationController sur un faux minimal. Objet tenu Big, Huge ou
-- Colossal (Tool HeldItemUid, modèle HeldItem, MutationSize) : HoldItem jouée, arrêtée quand il sort de la main ;
-- petit objet, outil de casse ou pas de taille : rien ; HoldItem au contrat (Contract/Animations, facultative).
local deepFreeze = load("shared/Config/DeepFreeze.luau", { script = {} })
local Animations = load("shared/Contract/Animations.luau", { script = { Parent = { DeepFreeze = deepFreeze } }, require = function(m) return m end })
local hold
for _, spec in Animations.Player do if spec.Name == "HoldItem" then hold = spec end end
check(hold ~= nil and hold.Loop == true and hold.Priority == "Action" and hold.UpperBodyOnly == true, "A1 HoldItem au contrat : boucle, Action, haut du corps")

local function folder(map) return { WaitForChild = function(_, n) return map[n] end } end
local played, stopped = {}, {}
local AnimPlayer = {
	waitForAnimator = function(character) return character:FindFirstChild("Humanoid"):FindFirstChild("Animator") end,
	playerFolder = function() return nil end,
	preload = function() return 0 end,
	new = function()
		return {
			LoadAll = function() end,
			Play = function(_, name) table.insert(played, name) return nil end,
			Stop = function(_, name) table.insert(stopped, name) end,
			OnMarker = function() return function() end end,
			IsPlaying = function() return false end,
			Destroy = function() end,
		}
	end,
}
local MarkerSounds = { Player = {}, check = function() end, play = function() end }
local Shared = folder({ Anim = folder({ AnimPlayer = AnimPlayer, MarkerSounds = MarkerSounds }), Contract = folder({ Animations = Animations }) })
local me = inst("Player", "Me")
me.CharacterAdded = signal()
me.CharacterRemoving = signal()
local services = { Players = { LocalPlayer = me }, ReplicatedStorage = folder({ Shared = Shared }), RunService = { IsStudio = function() return false end } }
local AC = load("client/Controllers/AnimationController.luau", {
	game = { GetService = function(_, n) return services[n] end, IsLoaded = function() return true end },
	script = { Parent = folder({}) },
	require = function(m) return m end,
	warn = function() end,
	print = function() end,
	task = { defer = function(f, ...) f(...) end, spawn = function(f, ...) f(...) end, delay = function() end },
	Vector3 = Vector3,
})
AC.Start()

local char = inst("Model", "Me")
char.ChildAdded = signal()
char.ChildRemoved = signal()
local humanoid = parent(inst("Humanoid", "Humanoid", { "Humanoid" }), char)
humanoid.Running = signal()
parent(inst("Animator", "Animator"), humanoid)
local function count(list, name) local n = 0 for _, v in list do if v == name then n += 1 end end return n end
me.CharacterAdded:Fire(char)
check(count(played, "HoldItem") == 0, "H1 rien en main : HoldItem pas jouée")

local function heldTool(size)
	local tool = inst("Tool", "Big Soda Can", { "Tool" })
	tool:SetAttribute("HeldItemUid", "u1")
	local model = parent(inst("Model", "HeldItem"), tool)
	model:SetAttribute("MutationSize", size)
	return tool
end
local function equip(tool) parent(tool, char); char.ChildAdded:Fire(tool) end
local function unequip(tool)
	for i, c in char._children do if c == tool then table.remove(char._children, i) break end end
	tool.Parent = nil
	char.ChildRemoved:Fire(tool)
end

local big = heldTool("Big")
equip(big)
check(count(played, "HoldItem") == 1 and AC.NeedsTwoHands(char), "H2 objet Big en main : HoldItem jouée")
char.ChildAdded:Fire(inst("Part", "Other"))
check(count(played, "HoldItem") == 1, "H3 autre enfant : pas rejouée")
unequip(big)
check(count(stopped, "HoldItem") == 1 and not AC.NeedsTwoHands(char), "H4 rangé : HoldItem arrêtée")
for _, size in { "Huge", "Colossal" } do
	local t = heldTool(size)
	equip(t)
	check(AC.NeedsTwoHands(char), `H5 {size} : deux mains`)
	unequip(t)
end
check(count(played, "HoldItem") == 3 and count(stopped, "HoldItem") == 3, "H6 Huge et Colossal : jouée puis arrêtée")
local small = heldTool("Tiny")
equip(small)
local plain = heldTool(nil)
check(not AC.NeedsTwoHands(char) and count(played, "HoldItem") == 3, "H7 Tiny ou sans taille : pose de Roblox")
unequip(small)
local tool = inst("Tool", "TOOL_Pied", { "Tool" })
equip(tool)
check(not AC.NeedsTwoHands(char) and count(played, "HoldItem") == 3, "H8 outil de casse : rien")
unequip(tool)
local colossal = heldTool("Colossal")
equip(colossal)
me.CharacterRemoving:Fire(char)
local char2 = inst("Model", "Me")
char2.ChildAdded = signal(); char2.ChildRemoved = signal()
local h2 = parent(inst("Humanoid", "Humanoid", { "Humanoid" }), char2)
h2.Running = signal()
parent(inst("Animator", "Animator"), h2)
local before = count(played, "HoldItem")
me.CharacterAdded:Fire(char2)
check(count(played, "HoldItem") == before, "H9 nouvelle vie sans objet : HoldItem pas jouée")
local _ = plain
print(`{checks} vérification(s), {fails} échec(s)`)
