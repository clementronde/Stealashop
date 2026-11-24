-- Banc a288 (Cantin, 21/11 : « la foule apparaît trop tard, elle va apparaître dès qu'on rentre dans le magasin ») :
-- le vrai WitnessCrowdController sur le faux Roblox du banc a240 crowd (lignes avant « -- B1. », ajoutées par
-- crowd-run.sh). Magasins du faux : vitrine en z = −50 tournée vers +Z (la rue), Bounds de z = −80 à −50.
--   enter (Crowd.Trigger = "Enter", V0) :
--   E0 valeurs (Trigger, MaxStay, Duration, Cooldown et Spacing inchangés)
--   E1 entrée sans objet dans un magasin ouvert : foule formée en moins d'un contrôle, complète, côté rue, 2 côtés,
--      écart Crowd.Spacing tenu
--   E2 elle reste pendant le braquage (bien plus que Duration), opaque, tournée vers le voleur dedans
--   E3 sortie avec l'objet : elle reste Duration s en le suivant des yeux, puis s'efface
--   E4 Cooldown compté depuis la fin ; ensuite, nouvelle foule
--   E5 magasin fermé (HeistOpen = false) : rien ; il s'ouvre pendant que le joueur est dedans : foule
--   E6 MaxStay : partie au plus tard après MaxStay s
--   E7 la nuit tombe pendant le braquage : elle s'efface ; entrée la nuit : rien
--   E8 deux joueurs dans le même magasin : une seule foule, regards sur le dernier entré ou sorti, reste tant qu'un
--      des deux est dedans
--   E9 rattrapage : pas formée à l'entrée (MaxCrowds atteint), elle se forme à la sortie avec l'objet
--   E10 caméra trop loin : rien ; aucune erreur
--   exit (Crowd.Trigger = "Exit") : l'ancien moment (entrée : rien ; sortie avec l'objet : Duration s)

local GAP_SP = CROWD.Spacing
local N = 2 * CROWD.PerSide
local EPS = 1e-6
local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
local function positions()
	local list = {}
	for _, m in members() do
		table.insert(list, m.HumanoidRootPart.Position)
	end
	return list
end
local function minPair(list)
	local best = math.huge
	for i = 1, #list do
		for j = i + 1, #list do
			best = math.min(best, flatDist(list[i], list[j]))
		end
	end
	return best
end
local function waitFull()
	for _ = 1, 80 do
		if (Controller.GetStats().Pending or 0) == 0 then
			return
		end
		advance(0.05)
	end
end
local function xOf(index)
	return (index - 1) * 200
end
local function street(player, index)
	moveTo(player, vec(xOf(index) + 2, 3, -30))
end
local function inside(player, index)
	camera.CFrame = cf(vec(xOf(index), 10, 30), 0)
	moveTo(player, vec(xOf(index), 3, -65))
end
local function crowdAt(index)
	for _, c in Controller.GetCrowds() do
		if c.Store == stores[index] then
			return c
		end
	end
	return nil
end
local function opaque()
	for _, m in members() do
		if m.Head.LocalTransparencyModifier > EPS then
			return false
		end
	end
	return #members() > 0
end
local function facing(m, target)
	local root = m.HumanoidRootPart
	local look = vec(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	return root.CFrame.LookVector:Dot(look.Unit) > 0.99
end
local function allFacing(target)
	for _, m in members() do
		if not facing(m, target) then
			return false
		end
	end
	return #members() > 0
end

-- Tout le monde dans la rue avant le premier contrôle (Alice démarre dans le magasin 1).
street(alice, 1)
advance(0.3)

if CROWD.Trigger == "Exit" then
	-- exit : l'ancien moment ---------------------------------------------------------------------------------
	inside(alice, 1)
	advance(1)
	check("exit entrée sans objet : pas de foule", Controller.GetCount() == 0 and #members() == 0, Controller.GetCount())
	alice:SetAttribute("Carrying", "Legendary")
	advance(1)
	check("exit dedans avec l'objet : toujours pas de foule", Controller.GetCount() == 0)
	street(alice, 1)
	advance(0.25)
	waitFull()
	check("exit sortie avec l'objet : la foule", Controller.GetCount() == 1 and #members() == N, #members())
	advance(CROWD.Duration + CROWD.FadeTime + 0.3)
	check("exit partie Duration s après la formation", #members() == 0 and #Controller.GetCrowds() == 0, #members())
	alice:SetAttribute("Carrying", nil)
	check("exit aucune erreur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
	print(`banc a288 crowd exit : {CHECKS} vérification(s), {FAILS} échec(s)`)
	return
end

-- E0. Valeurs -------------------------------------------------------------------------------------------------
check("E0 Trigger = Enter (Cantin, 21/11), MaxStay V0 60", CROWD.Trigger == "Enter" and CROWD.MaxStay == 60, `{CROWD.Trigger} {CROWD.MaxStay}`)
check("E0 Duration, Cooldown, PerSide inchangés", CROWD.Duration == 6 and CROWD.Cooldown == 15 and CROWD.PerSide == 12 and CROWD.PerSideLow == 10)
check(
	"E0 Spacing inchangé (a269)",
	GAP_SP ~= nil and GAP_SP.Enabled == true and GAP_SP.Margin == 0.5 and GAP_SP.WidthFallback == 4 and GAP_SP.WidthMax == 6 and GAP_SP.Step == 0.5 and GAP_SP.MaxPush == 20 and GAP_SP.Witnesses == true
)
check("E0 personne au départ (Alice dans la rue)", Controller.GetCount() == 0 and #members() == 0)

-- E1. Entrée sans objet ---------------------------------------------------------------------------------------------
check("E1 Alice ne porte rien", alice:GetAttribute("Carrying") == nil)
inside(alice, 1)
advance(CROWD.CheckInterval + 0.05)
local formedAfter = Controller.GetCount()
check("E1 foule formée au premier contrôle après l'entrée", formedAfter == 1 and crowdAt(1) ~= nil, formedAfter)
waitFull()
local list = positions()
local cx = xOf(1)
local left, right, streetSide, farthest = 0, 0, true, 0
for _, p in list do
	if p.X < cx then
		left += 1
	else
		right += 1
	end
	if p.Z <= -50 then
		streetSide = false
	end
	farthest = math.max(farthest, p.Z + 50)
end
local gapNow = Controller.GetStats().Gap
local m = minPair(list)
print(`MESURE E1 : {#list} personnes ({left} + {right}), paire la plus proche {string.format("%.2f", m)} studs (écart {gapNow}), la plus loin à {string.format("%.1f", farthest)} studs de la vitrine`)
check(`E1 {N} personnes`, #list == N, #list)
check("E1 toutes côté rue (devant la vitrine, jamais dans le magasin)", streetSide)
check("E1 au moins 10 de chaque côté", left >= 10 and right >= 10, `{left} {right}`)
check("E1 écart Crowd.Spacing tenu", gapNow > 0 and m >= gapNow - EPS, `{m} {gapNow}`)
check("E1 au plus Start + Length + MaxPush + Jitter de la vitrine", farthest <= CROWD.Start + CROWD.Length + GAP_SP.MaxPush + CROWD.Jitter + EPS, farthest)
check("E1 voleur noté", crowdAt(1) ~= nil and crowdAt(1).Thief == alice)

-- E2. Elle reste pendant le braquage ----------------------------------------------------------------------------------
advance(3 * CROWD.Duration)
check("E2 encore là après 3 × Duration (Alice toujours dedans)", #members() == N and opaque(), #members())
local aliceAt = alice.Character.HumanoidRootPart.Position
check("E2 tournée vers le voleur dans le magasin", allFacing(aliceAt))

-- E3. Sortie avec l'objet ----------------------------------------------------------------------------------------------
alice:SetAttribute("Carrying", "Legendary")
advance(0.5)
street(alice, 1)
advance(CROWD.CheckInterval + 0.05)
local outAt = NOW
advance(CROWD.Duration - 0.6)
check("E3 encore là juste avant Duration s après la sortie", #members() == N and opaque(), #members())
check("E3 elle suit le voleur des yeux dans la rue", allFacing(alice.Character.HumanoidRootPart.Position))
advance(0.6 + CROWD.FadeTime + 0.3)
check("E3 partie après Duration + FadeTime", #members() == 0 and #Controller.GetCrowds() == 0, #members())
print(`MESURE E3 : partie {string.format("%.2f", NOW - outAt)} s après la sortie (Duration {CROWD.Duration})`)
alice:SetAttribute("Carrying", nil)

-- E4. Cooldown depuis la fin --------------------------------------------------------------------------------------------
inside(alice, 1)
advance(0.5)
check("E4 de nouveau dedans dans le Cooldown : pas de foule", Controller.GetCount() == 1 and #members() == 0)
street(alice, 1)
advance(CROWD.Cooldown)
inside(alice, 1)
advance(0.3)
check("E4 après le Cooldown : nouvelle foule", Controller.GetCount() == 2 and crowdAt(1) ~= nil, Controller.GetCount())
street(alice, 1)
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("E4 partie", #members() == 0)

-- E5. Magasin fermé, puis ouvert ------------------------------------------------------------------------------------------
stores[2]:SetAttribute("HeistOpen", false)
inside(alice, 2)
advance(1)
check("E5 magasin fermé (HeistOpen = false) : pas de foule", Controller.GetCount() == 2 and crowdAt(2) == nil)
stores[2]:SetAttribute("HeistOpen", true)
advance(0.3)
check("E5 il s'ouvre pendant que le joueur est dedans : foule", Controller.GetCount() == 3 and crowdAt(2) ~= nil, Controller.GetCount())
stores[2]:SetAttribute("HeistOpen", false) -- le chrono de casse est fini : la foule reste quand même
advance(CROWD.Duration + 1)
check("E5 fermeture du chrono, joueur encore dedans : elle reste", crowdAt(2) ~= nil and #members() == N, #members())

-- E6. MaxStay ---------------------------------------------------------------------------------------------------------------
local formedAt = NOW - CROWD.Duration - 1.3
advance(CROWD.MaxStay - (NOW - formedAt) - 1)
check("E6 encore là juste avant MaxStay", crowdAt(2) ~= nil and opaque())
advance(1 + CROWD.FadeTime + 0.5)
check("E6 partie après MaxStay, joueur toujours dedans", crowdAt(2) == nil and #members() == 0, #members())
street(alice, 2)
advance(0.5)
stores[2]:SetAttribute("HeistOpen", nil)

-- E7. Nuit -------------------------------------------------------------------------------------------------------------------
inside(alice, 3)
advance(0.3)
waitFull()
check("E7 foule au magasin 3", crowdAt(3) ~= nil and #members() == N)
Workspace:SetAttribute("NightPhase", "Night")
advance(CROWD.CheckInterval + CROWD.FadeTime + 0.3)
check("E7 la nuit tombe pendant le braquage : elle s'efface (AtNight = false)", CROWD.AtNight == false and crowdAt(3) == nil and #members() == 0, #members())
street(alice, 3)
advance(0.3)
local countNight = Controller.GetCount()
inside(alice, 4)
advance(1)
check("E7 entrée la nuit : pas de foule", Controller.GetCount() == countNight and crowdAt(4) == nil)
street(alice, 4)
advance(0.3)
Workspace:SetAttribute("NightPhase", "Day")

-- E8. Deux joueurs dans le même magasin ------------------------------------------------------------------------------------
local bob = newPlayer("Bob", vec(xOf(5), 3, -30), false)
inside(alice, 5)
advance(0.3)
local before8 = Controller.GetCount()
moveTo(bob, vec(xOf(5) + 3, 3, -62))
advance(0.3)
check("E8 Bob entre aussi : toujours une seule foule", Controller.GetCount() == before8 and #Controller.GetCrowds() == 1, Controller.GetCount())
check("E8 regards sur le dernier entré (Bob)", crowdAt(5) ~= nil and crowdAt(5).Thief == bob)
street(alice, 5)
advance(CROWD.Duration + CROWD.FadeTime + 1)
check("E8 Alice sort, Bob encore dedans : elle reste au-delà de Duration", crowdAt(5) ~= nil and opaque())
check("E8 regards sur la dernière sortie (Alice)", crowdAt(5) ~= nil and crowdAt(5).Thief == alice)
moveTo(bob, vec(xOf(5) - 3, 3, -30))
advance(CROWD.Duration - 0.6)
check("E8 Bob sort : encore là juste avant Duration", crowdAt(5) ~= nil)
advance(0.6 + CROWD.FadeTime + 0.4)
check("E8 partie Duration s après la sortie du dernier", crowdAt(5) == nil and #members() == 0)

-- E9. Rattrapage à la sortie ---------------------------------------------------------------------------------------------------
moveTo(bob, vec(xOf(6), 3, -65))
camera.CFrame = cf(vec(xOf(6), 10, 30), 0)
advance(0.3)
inside(alice, 7)
advance(0.3)
check("E9 deux foules (Bob en 6, Alice en 7) : MaxCrowds atteint", #Controller.GetCrowds() == CROWD.MaxCrowds, #Controller.GetCrowds())
local carol = newPlayer("Carol", vec(xOf(4), 3, -30), false)
camera.CFrame = cf(vec(xOf(4), 10, 30), 0) -- caméra près d'elle : seul MaxCrowds refuse
moveTo(carol, vec(xOf(4), 3, -65))
advance(0.3)
check("E9 Carol entre en 4 : pas de troisième foule", crowdAt(4) == nil and #Controller.GetCrowds() == CROWD.MaxCrowds)
moveTo(bob, vec(xOf(6), 3, -30))
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("E9 Bob sorti : sa foule est partie", crowdAt(6) == nil)
carol:SetAttribute("Carrying", "Epic")
camera.CFrame = cf(vec(xOf(4), 10, 30), 0)
moveTo(carol, vec(xOf(4) + 2, 3, -40))
advance(0.3)
check("E9 Carol sort avec l'objet : la foule se forme à la sortie", crowdAt(4) ~= nil and crowdAt(4).Thief == carol)
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("E9 partie Duration s après", crowdAt(4) == nil)
carol:SetAttribute("Carrying", nil)
street(alice, 7)
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("E9 tout est parti", #Controller.GetCrowds() == 0 and #members() == 0, #members())

-- E10. Caméra trop loin, erreurs ------------------------------------------------------------------------------------------------
advance(CROWD.Cooldown)
local count10 = Controller.GetCount()
moveTo(alice, vec(xOf(3), 3, -65))
camera.CFrame = cf(vec(xOf(3), 10, 30 + CROWD.ViewDistance + 50), 0)
advance(1)
check("E10 voleur trop loin de la caméra : pas de foule", Controller.GetCount() == count10 and #members() == 0)
street(alice, 3)
advance(0.3)
check("E10 aucune erreur du contrôleur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
print(`banc a288 crowd enter : {CHECKS} vérification(s), {FAILS} échec(s)`)
