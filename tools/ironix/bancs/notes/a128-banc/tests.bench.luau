-- Banc a128 (vague 39, 2026-11-14), scénario « bench » : BenchBarController, faux Roblox d'a72 (bar/harness.luau).
-- Un banc sans Bar n'est plus fouillé à chaque image (au plus toutes les BAR_RETRY = 1 s) ; la Bar trouvée est
-- gardée ; mains absentes : rien n'est fouillé ; une nouvelle séance cherche tout de suite.
local realOs = os
local fakeClock = 0
os = setmetatable({ clock = function() return fakeClock end }, { __index = realOs })
local Ctl = loadController(SOURCE)
Ctl.Start()
local function frame()
	fakeClock += 1 / 60
	HEARTBEAT:Fire(1 / 60)
end
-- Compte les recherches de Bar (FindFirstChild récursif) dans `bench`.
local function countSearches(bench)
	local counter = { n = 0 }
	rawset(bench, "FindFirstChild", function(self, name, recursive)
		if recursive then
			counter.n += 1
		end
		return I_FindFirstChild(self, name, recursive)
	end)
	return counter
end
I_FindFirstChild = newInst("Folder", "probe").FindFirstChild

-- 1. Banc sans Bar, joueur installé, mains là ------------------------------------------------------
do
	newPlayer(11, Vector3.new(-2, 5, 1), Vector3.new(2, 5, 1))
	local bench = newInst("Model", "PLOT_Bench", workspace)
	CollectionService:AddTag(bench, "Bench")
	local searches = countSearches(bench)
	bench:SetAttribute("BenchUserId", 11)
	for _ = 1, 60 do
		frame()
	end
	check("1 sans Bar : fouillé au plus 2 fois en 1 s (avant : 60)", searches.n <= 2 and searches.n >= 1, searches.n)
	check("1 sans Bar : rien suivi", not Ctl.IsFollowing(bench))
	-- La Bar arrive (streaming) : suivie au plus BAR_RETRY s plus tard.
	local bar = newInst("Part", "Bar", bench)
	bar.CFrame = CFrame.new(0, 4, 0)
	bar.Size = Vector3.new(6, 0.3, 0.3)
	local waited = 0
	while not Ctl.IsFollowing(bench) and waited < 120 do
		frame()
		waited += 1
	end
	check("1 Bar arrivée : suivie en 1 s au plus", Ctl.IsFollowing(bench) and waited <= 61, waited)
	check("1 Bar suivie : au milieu des mains", nearV(bar.Position, Vector3.new(0, 5, 1)), bar.Position)
	local before = searches.n
	bench:SetAttribute("BenchUserId", nil)
	frame()
	bench:SetAttribute("BenchUserId", 11)
	frame()
	check("1 nouvelle séance : Bar gardée, pas de nouvelle fouille", Ctl.IsFollowing(bench) and searches.n == before, searches.n - before)
	bench:SetAttribute("BenchUserId", nil)
	frame()
end

-- 2. Mains absentes : la Bar n'est pas fouillée à chaque image ; mains arrivées : suivie à l'image même ----
do
	local _p, _l, _r, character = newPlayer(12, nil, nil)
	local bench = newInst("Model", "PLOT_Bench", workspace)
	local bar = newInst("Part", "Bar", bench)
	bar.CFrame = CFrame.new(30, 4, 0)
	bar.Size = Vector3.new(6, 0.3, 0.3)
	CollectionService:AddTag(bench, "Bench")
	local searches = countSearches(bench)
	bench:SetAttribute("BenchUserId", 12)
	for _ = 1, 60 do
		frame()
	end
	check("2 mains absentes : Bar jamais fouillée (avant : 60 fois)", searches.n == 0, searches.n)
	local l = newInst("Part", "LeftHand", character)
	l.CFrame = CFrame.new(28, 5, 0)
	local r = newInst("Part", "RightHand", character)
	r.CFrame = CFrame.new(32, 5, 0)
	frame()
	check("2 mains arrivées : suivie à l'image même", Ctl.IsFollowing(bench) and nearV(bar.Position, Vector3.new(30, 5, 0)), bar.Position)
	bench:SetAttribute("BenchUserId", nil)
	frame()
end

-- 3. Nouvelle séance sur un banc noté « sans Bar » : recherche tout de suite ------------------------------
do
	newPlayer(13, Vector3.new(48, 5, 0), Vector3.new(52, 5, 0))
	newPlayer(14, Vector3.new(48, 6, 0), Vector3.new(52, 6, 0))
	local bench = newInst("Model", "PLOT_Bench", workspace)
	CollectionService:AddTag(bench, "Bench")
	bench:SetAttribute("BenchUserId", 13)
	frame()
	check("3 sans Bar : rien suivi", not Ctl.IsFollowing(bench))
	local bar = newInst("Part", "Bar", bench)
	bar.CFrame = CFrame.new(50, 4, 0)
	bar.Size = Vector3.new(6, 0.3, 0.3)
	bench:SetAttribute("BenchUserId", 14) -- un autre joueur s'installe aussitôt
	frame()
	check("3 autre joueur : Bar cherchée tout de suite, suivie", Ctl.IsFollowing(bench) and nearV(bar.Position, Vector3.new(50, 6, 0)), bar.Position)
end

os = realOs
print("scénario bench : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
