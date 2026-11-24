---------------------------------------------------------------- statues du n° 1 (a430, L-331) : vrai LeaderboardStatueService
local workspace = new("Workspace", { Name = "Workspace" })
local storage = new("ServerStorage", { Name = "ServerStorage" })
local applies, descCalls = 0, 0
function Inst.ApplyDescription(self, desc)
	applies += 1
	if desc.Fail then
		error("ApplyDescription refusé (faux)")
	end
	local rig = self.Parent
	local root = rig:FindFirstChild("HumanoidRootPart")
	for _, d in rig:GetDescendants() do
		if d.ClassName == "Attachment" then
			local p = d.CFrame.Position
			d.CFrame = cf(p.X, p.Y * desc.Tall, p.Z)
		end
	end
	for _, child in rig:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			child.Size = v3(child.Size.X, child.Size.Y * desc.Tall, child.Size.Z)
			child.CFrame = root.CFrame -- membres tassés, comme les AnimationConstraint avant la physique
		end
	end
	local hat = new("Accessory", { Name = "Hat" }, rig)
	new("Part", { Name = "Handle", CFrame = root.CFrame, Size = v3(1, 1, 1), Material = "Neon" }, hat)
	new("Script", { Name = "Animate" }, rig)
end
local Players = {
	GetHumanoidDescriptionFromUserId = function(_, id)
		descCalls += 1
		if id == 666 then
			error("HTTP 400 (faux)")
		end
		return new("HumanoidDescription", { Tall = if id == 4321 then 0.8 else 1.4, Fail = id == 777 })
	end,
	GetPlayerByUserId = function()
		return nil
	end,
	GetNameFromUserIdAsync = function(_, id)
		return "User" .. id
	end,
}
local studioPrints = {}
local function freshStatues()
	return load(STATUE_SOURCE, "LeaderboardStatueService", {
		game = { GetService = function(_, n)
			if n == "CollectionService" then
				return CollectionService
			elseif n == "Players" then
				return Players
			elseif n == "ReplicatedStorage" then
				return { Shared = { Config = { WeeklyLeaderboard = W } } }
			elseif n == "RunService" then
				return { IsStudio = function()
					return true
				end, Heartbeat = signal() }
			elseif n == "Workspace" then
				return workspace
			end
			error("service " .. n)
		end },
		require = function(m)
			return m
		end,
		typeof = fakeTypeof,
		Vector3 = { new = v3 },
		Enum = { Material = { Plastic = "Plastic" } },
		task = { spawn = function(fn, ...)
			fn(...)
		end },
		print = function(m)
			table.insert(studioPrints, m)
		end,
		warn = function(m)
			table.insert(studioPrints, m)
		end,
	})
end

-- Statue de Clément : socle, plaque, Rig doré R15 (ici 5 pièces) agrandi ×3,5, pieds à y = 40.
local function statue(stat, x, z, parent, withRig)
	local model = new("Model", { Name = "ENV_Hub_LeaderboardStatue" }, parent)
	model:SetAttribute("Stat", stat)
	local ped = new("Model", { Name = "Pedestal" }, model)
	local body = new("Part", { Name = "Body", CFrame = cf(x, 38, z), Size = v3(8, 4, 8) }, ped)
	local plate = new("SurfaceGui", { Name = "Plate" }, body)
	new("TextLabel", { Name = "Title", Text = "#1" }, plate)
	new("TextLabel", { Name = "PlayerName", Text = "???" }, plate)
	if withRig ~= false then
		local rig = new("Model", { Name = "Rig" }, model)
		local root = new("Part", { Name = "HumanoidRootPart", Size = v3(2, 2, 1), CFrame = cf(0, 3, 0), Material = "Foil" }, rig)
		local torso = new("Part", { Name = "UpperTorso", Size = v3(2, 2, 1), CFrame = cf(0, 3, 0), Material = "Foil" }, rig)
		local head = new("Part", { Name = "Head", Size = v3(1, 1, 1), CFrame = cf(0, 4.5, 0), Material = "Foil" }, rig)
		local ll = new("Part", { Name = "LeftLeg", Size = v3(1, 2, 1), CFrame = cf(-0.5, 1, 0), Material = "Foil" }, rig)
		local rl = new("Part", { Name = "RightLeg", Size = v3(1, 2, 1), CFrame = cf(0.5, 1, 0), Material = "Foil" }, rig)
		local function joint(p0, l0, p1, l1)
			local a0 = new("Attachment", { CFrame = cf(l0[1], l0[2], l0[3]) }, p0)
			local a1 = new("Attachment", { CFrame = cf(l1[1], l1[2], l1[3]) }, p1)
			new("AnimationConstraint", { Attachment0 = a0, Attachment1 = a1 }, p1)
		end
		joint(root, { 0, 0, 0 }, torso, { 0, 0, 0 })
		joint(torso, { 0, 1, 0 }, head, { 0, -0.5, 0 })
		joint(torso, { -0.5, -1, 0 }, ll, { 0, 1, 0 })
		joint(torso, { 0.5, -1, 0 }, rl, { 0, 1, 0 })
		local hum = new("Humanoid", {}, rig)
		new("Animator", {}, hum)
		rig:ScaleTo(3.5)
		rig:PivotTo(cf(x, 40 + 3 * 3.5, z))
	end
	tagged.LeaderboardStatue = tagged.LeaderboardStatue or {}
	table.insert(tagged.LeaderboardStatue, model)
	return model
end
local function rigsOf(model)
	local n, building = 0, 0
	for _, c in model:GetChildren() do
		if c.Name == "Rig" then
			n += 1
		elseif c.Name == "RigBuilding" then
			building += 1
		end
	end
	return n, building
end
local function body(model)
	local rig = model:FindFirstChild("Rig")
	local root = rig:FindFirstChild("HumanoidRootPart")
	local low, high = math.huge, -math.huge
	for _, c in rig:GetChildren() do
		if c:IsA("BasePart") and c ~= root then
			low = math.min(low, c.Position.Y - c.Size.Y / 2)
			high = math.max(high, c.Position.Y + c.Size.Y / 2)
		end
	end
	return low, high, root
end
local function materials(model)
	local set = {}
	for _, d in model:FindFirstChild("Rig"):GetDescendants() do
		if d:IsA("BasePart") then
			set[d.Material] = true
		end
	end
	return set
end
local function hasScript(model)
	for _, d in model:FindFirstChild("Rig"):GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			return true
		end
	end
	return false
end
local function nameOf(model)
	return model:FindFirstChild("PlayerName", true).Text
end

local income = statue("WeeklyIncome", -281, 44.5, workspace)
local steals = statue("WeeklySteals", -281, -44.5, workspace)
local backup = statue("WeeklyIncome", 0, 0, storage) -- copie de ServerStorage/MapBackups
local bare = statue("WeeklySteals", 50, 50, workspace, false) -- sans Rig
local g0low, g0high = body(income)
check(near(g0low, 40) and near(g0high - g0low, 17.5), `G0 faux Rig doré : pieds à 40, 17,5 studs ({g0low}, {g0high - g0low})`)

local St = freshStatues()
St.Start()
local ok, problem = pcall(St.Show, "WeeklyIncome", 1234)
check(ok, `T1a Show sans erreur ({tostring(problem)})`)
local low, high, root = body(income)
local n, building = rigsOf(income)
check(n == 1 and building == 0, `T1b un seul Rig, aucun en cours d'habillage ({n}, {building})`)
check(near(high - low, W.Statue.Height), `T1c avatar ramené à {W.Statue.Height} studs ({high - low})`)
check(near(low, 40), `T1d pieds sur le socle, à la hauteur de ceux du Rig doré ({low})`)
check(near(root.Position.X, -281) and near(root.Position.Z, 44.5), "T1e même place en X et Z que le Rig doré")
local mats = materials(income)
check(mats.Plastic and not mats.Foil and not mats.Neon, "T1f Material = Plastic sur toutes les pièces, accessoires compris")
check(not hasScript(income), "T1g aucun script laissé dans le Rig")
check(nameOf(income) == "User1234" and St.Shown("WeeklyIncome") == 1234, "T1h PlayerName = nom du n° 1, Shown")
check(applies == 1 and nameOf(steals) == "???" and materials(steals).Foil, "T1i l'autre classement n'est pas touché")
check(nameOf(backup) == "???" and materials(backup).Foil, "T1j statue de ServerStorage ignorée")
local head = income:FindFirstChild("Rig"):FindFirstChild("Head")
local torso = income:FindFirstChild("Rig"):FindFirstChild("UpperTorso")
check(head.Position.Y > torso.Position.Y and near(head.Position.Y - head.Size.Y / 2, torso.Position.Y + torso.Size.Y / 2), "T1k membres recalés sur leurs articulations (tête posée sur le torse)")
St.Show("WeeklyIncome", 1234)
check(applies == 1 and descCalls == 1, "T2 même n° 1 : rien de refait")
St.Show("WeeklyIncome", 4321) -- avatar plus petit (0,8)
low, high = body(income)
check(near(high - low, W.Statue.Height) and near(low, 40) and nameOf(income) == "User4321", `T3 autre taille d'avatar : même hauteur, mêmes pieds ({high - low})`)
St.Show("WeeklyIncome", 0)
low, high = body(income)
check(nameOf(income) == W.Statue.EmptyName and materials(income).Foil and near(high - low, 17.5) and near(low, 40) and St.Shown("WeeklyIncome") == 0, "T4 semaine vide : statue dorée et « ??? »")
n, building = rigsOf(income)
check(n == 1 and building == 0, "T4b toujours un seul Rig")
ok = pcall(St.Show, "WeeklySteals", 666)
check(ok and nameOf(steals) == "User666" and materials(steals).Foil and St.Shown("WeeklySteals") == 0, "T5 avatar illisible : statue dorée, nom du n° 1")
St.Show("WeeklySteals", 777)
n, building = rigsOf(steals)
check(n == 1 and building == 0 and materials(steals).Foil and nameOf(steals) == "User777", "T6 ApplyDescription raté : copie retirée, statue dorée")
St.Show("WeeklySteals", 2468)
check(St.Shown("WeeklySteals") == 2468 and materials(steals).Plastic, "T7a nouvel essai réussi")
St.Show("WeeklySteals", 666)
check(materials(steals).Foil and nameOf(steals) == "User666", "T7b avatar du nouveau n° 1 illisible : jamais l'ancien avatar sous son nom")
check(nameOf(bare) == "???", "T8 statue sans Rig ignorée, sans erreur")
workspace:SetAttribute(W.Statue.TestAttribute, 2222)
check(St.Shown("WeeklyIncome") == 2222 and St.Shown("WeeklySteals") == 2222, "T9a crochet de test (Studio) : toutes les statues")
workspace:SetAttribute(W.Statue.TestAttribute, nil)
check(St.Shown("WeeklyIncome") == 0 and nameOf(steals) == "User666", "T9b crochet retiré : retour au vrai n° 1")
