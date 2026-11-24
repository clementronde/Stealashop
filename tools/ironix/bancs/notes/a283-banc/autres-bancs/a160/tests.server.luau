-- Scénario server (a160) : vrai HubService sur un faux minimal. Bonus d'amis de 0 à 5 amis présents (plafond 4),
-- départ d'un ami, erreur de Roblox ; accroche de DisplayService.GetIncomeBonus ; noob : Idle, Wave à l'entrée
-- dans la zone InviteZone, une fois par entrée, délai entre deux saluts.
local Hub, HubZone = realHub()

local Players = inst("Players", "Players")
Players.PlayerAdded = signal()
Players.PlayerRemoving = signal()
function Players:GetPlayers()
	local out = {}
	for _, p in self._children do if p.Parent == self then table.insert(out, p) end end
	return out
end

local friendsOf = {} -- [userId] = { [userId] = true }
local failing = {} -- [userId] = true : IsFriendsWith lève une erreur
local function newPlayer(id, name)
	local p = inst("Player", name)
	p.UserId = id
	function p:IsFriendsWith(other)
		if failing[self.UserId] then error("HTTP 500") end
		return (friendsOf[self.UserId] or {})[other] == true or (friendsOf[other] or {})[self.UserId] == true
	end
	return p
end
local function join(p)
	parent(p, Players)
	Players.PlayerAdded:Fire(p)
end
local function leave(p)
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
	for i, c in Players._children do if c == p then table.remove(Players._children, i) break end end
end

local Workspace = inst("Workspace", "Workspace")
local tagged = {}
local CollectionService = { GetTagged = function(_, tag) return tagged[tag] or {} end }

-- Faux AnimPlayer : note les Play.
local played = {}
local playing = {}
local AnimPlayer = {
	modelFolder = function(model) return model:FindFirstChild("Animations") end,
	new = function(_, _, _, _)
		return {
			Play = function(_, name) table.insert(played, name) end,
			IsPlaying = function(_, name) return playing[name] == true end,
			Destroy = function() end,
		}
	end,
}
local DisplayService = { GetIncomeBonus = function() return 0.1 end }

local now = 0
local services = { Players = Players, Workspace = Workspace, CollectionService = CollectionService, ReplicatedStorage = {
	Shared = {
		Config = { Hub = Hub },
		HubZone = HubZone,
		Contract = { Animations = { Vendor = {} } },
		Anim = { AnimPlayer = AnimPlayer },
	},
} }
local HubService = load("server/Services/HubService.luau", {
	game = { GetService = function(_, n) return services[n] end },
	script = { Parent = { DisplayService = DisplayService } },
	require = function(m) return m end,
	task = { spawn = function(f, ...) f(...) end, wait = function() coroutine.yield() end },
	os = { clock = function() return now end },
	print = function() end,
	warn = function(...) print("ERREUR warn", ...) end,
})
HubService.Init()

local A, B, C, D, E, F = newPlayer(1, "A"), newPlayer(2, "B"), newPlayer(3, "C"), newPlayer(4, "D"), newPlayer(5, "E"), newPlayer(6, "F")
join(A)
check(HubService.GetFriendCount(A) == 0 and A:GetAttribute("FriendBonus") == 0, "B0 seul : 0 ami, bonus 0")
check(math.abs(DisplayService.GetIncomeBonus(A) - 0.1) < 1e-9, "B0b accroche : le bonus d'avant est gardé (0,1)")
friendsOf[1] = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true }
join(B)
check(HubService.GetFriendCount(A) == 1 and HubService.GetFriendCount(B) == 1, "B1 un ami présent : 1 de chaque côté")
check(math.abs(DisplayService.GetIncomeBonus(A) - 0.25) < 1e-9, `B1b revenu : 0,1 + 0,15 ({DisplayService.GetIncomeBonus(A)})`)
check(B:GetAttribute("FriendsInServer") == 1 and math.abs(B:GetAttribute("FriendBonus") - 0.15) < 1e-9, "B1c attributs de B")
join(C); join(D)
check(HubService.GetFriendCount(A) == 3 and math.abs(HubService.GetFriendBonus(A) - 0.45) < 1e-9, "B3 trois amis : +45 %")
check(HubService.GetFriendCount(C) == 1, "B3b C n'est ami que de A")
join(E)
check(math.abs(HubService.GetFriendBonus(A) - 0.60) < 1e-9, "B4 quatre amis : +60 %")
join(F)
check(HubService.GetFriendCount(A) == 5 and math.abs(HubService.GetFriendBonus(A) - 0.60) < 1e-9, "B5 cinq amis : plafond +60 %")
check(A:GetAttribute("FriendsInServer") == 5 and math.abs(A:GetAttribute("FriendBonus") - 0.60) < 1e-9, "B5b attributs de A")
leave(F); leave(E)
check(HubService.GetFriendCount(A) == 3 and math.abs(A:GetAttribute("FriendBonus") - 0.45) < 1e-9, "B6 deux amis partent : +45 %")
leave(B)
check(HubService.GetFriendCount(A) == 2 and HubService.GetFriendCount(B) == 0, "B7 B part : A a 2 amis, B oublié")
local G = newPlayer(7, "G")
friendsOf[7] = { [1] = true }
failing[7] = true
join(G)
check(HubService.GetFriendCount(G) == 0 and HubService.GetFriendCount(A) == 2, "B8 erreur de Roblox : pas amis, rien ne casse")

-- Noob : modèle ENV_Hub_InviteNoob avec Zone (tag InviteZone) et Noob (Humanoid, Animator, Animations).
local map = parent(inst("Folder", "Map"), Workspace)
local holder = parent(inst("Model", "ENV_Hub_InviteNoob"), map)
local zone = parent(inst("Part", "Zone", { "BasePart" }), holder)
zone.CFrame = CFrame.new(0, 0.5, 0)
zone.Size = Vector3.new(10, 1, 10)
tagged.InviteZone = { zone }
local noob = parent(inst("Model", "Noob"), holder)
local hum = parent(inst("Humanoid", "Humanoid"), noob)
parent(inst("Animator", "Animator"), hum)
parent(inst("Folder", "Animations"), noob)

local function place(p, x)
	if x == nil then p.Character = nil return end
	local char = inst("Model", p.Name)
	local h = parent(inst("Humanoid", "Humanoid"), char)
	h.Health = 100
	local root = parent(inst("Part", "HumanoidRootPart", { "BasePart" }), char)
	root.Position = Vector3.new(x, 3, 0)
	p.Character = char
end
for _, p in Players:GetPlayers() do place(p, 50) end

local co = coroutine.create(HubService.Start)
local function tick(t)
	now = t
	local ok, err = coroutine.resume(co)
	if not ok then print("ERREUR Start : " .. tostring(err)) end
end
tick(0) -- Start jusqu'au premier task.wait
tick(0.2)
check(played[1] == "Idle" and #played == 1, `N1 Idle lancée, pas de Wave sans entrée ({table.concat(played, ",")})`)
place(A, 2)
tick(0.4)
check(played[#played] == "Wave" and #played == 2, "N2 A entre : Wave")
tick(0.6)
check(#played == 2, "N3 A reste : pas d'autre Wave")
place(C, 1)
tick(1.0)
check(#played == 2, "N4 C entre pendant le délai (4 s) : pas de Wave")
place(A, 50); place(C, 50)
tick(5)
place(A, 0)
playing.Wave = true
tick(6)
check(#played == 2, "N5 Wave encore en cours : pas de nouveau salut")
playing.Wave = false
place(A, 50)
tick(7)
place(A, 0)
tick(8)
check(played[#played] == "Wave" and #played == 3, "N6 A ressort puis revient après le délai : Wave")
place(D, nil)
tick(9)
check(#played == 3, "N7 joueur sans personnage : ignoré")

print(`{checks} vérification(s), {fails} échec(s)`)
