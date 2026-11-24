-- Banc a289 (Cantin, 21/11 : « elle disparaît quand le vol est fini cad quand l'item est ramené ») : le vrai
-- WitnessCrowdController sur le faux Roblox du banc a240 crowd (lignes avant « -- B1. », ajoutées par crowd-run.sh).
-- Reprend le banc a288 (E0 à E10), adapté là où a288 mesurait le départ à la sortie d'un voleur (E3, E6, E7, E9),
-- puis les cas a289 (T1 à T7). Magasins du faux : vitrine en z = −50 tournée vers +Z (la rue), Bounds de z = −80 à −50.
-- Le joueur local (Alice) regarde ; les voleurs de T1 à T7 sont d'autres joueurs (la fin se voit chez tous).
--   enter (Crowd.Trigger = "Enter") :
--   E0 valeurs (Trigger, MaxStay 300, MaxCrowds 2, Duration, Cooldown et Spacing)
--   E1 entrée sans objet dans un magasin ouvert : foule formée en moins d'un contrôle, complète, côté rue, 2 côtés,
--      écart Crowd.Spacing tenu
--   E2 elle reste pendant le braquage (bien plus que Duration), opaque, tournée vers le voleur dedans
--   E3 (a289) objet pris dedans, sortie : elle le suit des yeux, reste bien après Duration, même voleur loin du
--      magasin ; elle part au dépôt (Carrying retiré), pas avant
--   E4 Cooldown compté depuis la fin ; nouvelle foule ; sortie sans objet : départ Duration s après la sortie
--   E5 magasin fermé (HeistOpen = false) : rien ; il s'ouvre pendant que le joueur est dedans : foule
--   E6 (a289) filet MaxStay : voleur qui porte encore, loin : partie au plus tard après MaxStay s
--   E7 la nuit tombe pendant le braquage (voleur qui porte) : elle s'efface ; entrée la nuit : rien
--   E8 deux joueurs sans objet dans le même magasin : une seule foule, regards sur le dernier entré ou sorti, reste
--      tant qu'un des deux est dedans, puis Duration s après la sortie du dernier
--   E9 (a289) rattrapage : pas formée à l'entrée (MaxCrowds atteint), elle se forme à la sortie avec l'objet et reste
--      jusqu'à la fin du vol
--   E10 caméra trop loin : rien
--   T1 capture dans le magasin (Carrying retiré, voleur encore dans Bounds) : partie tout de suite
--   T2 objet perdu dans la rue (chute, capture dehors) : partie tout de suite
--   T3 objet volé par un autre joueur dans la rue : partie (le nouveau porteur n'est pas un voleur de ce magasin)
--   T4 voleur qui quitte le jeu : partie
--   T5 deux joueurs : le voleur dépose, l'autre encore dedans : elle reste ; il sort sans objet : partie tout de suite
--   T6 entré en portant déjà un objet venu d'ailleurs : pas un voleur, départ Duration s après sa sortie
--   T7 deux foules : seule celle du magasin dont le vol finit s'en va
--   aucune erreur
--   exit (Crowd.Trigger = "Exit") : l'ancien moment (entrée : rien ; sortie avec l'objet : Duration s)

local GAP_SP = CROWD.Spacing
local N = 2 * CROWD.PerSide
local EPS = 1e-6
local GONE = CROWD.CheckInterval + CROWD.FadeTime + 0.15 -- fin du vol vue au contrôle suivant, puis le fondu
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
local function street(player, index, dx)
	moveTo(player, vec(xOf(index) + (dx or 2), 3, -30))
end
local function inside(player, index, dx)
	camera.CFrame = cf(vec(xOf(index), 10, 30), 0)
	moveTo(player, vec(xOf(index) + (dx or 0), 3, -65))
end
local function far(player)
	moveTo(player, vec(5000, 3, 400)) -- loin de tout magasin et de la caméra
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
local function rest()
	advance(CROWD.Cooldown + 1) -- plus aucune foule, plus aucun Cooldown
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
	check("exit partie Duration s après la formation (voleur qui porte encore)", #members() == 0 and #Controller.GetCrowds() == 0, #members())
	alice:SetAttribute("Carrying", nil)
	check("exit aucune erreur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
	print(`banc a293 crowd exit : {CHECKS} vérification(s), {FAILS} échec(s)`)
	return
end

-- E0. Valeurs -------------------------------------------------------------------------------------------------
check("E0 Trigger = Enter (Cantin, 21/11)", CROWD.Trigger == "Enter", CROWD.Trigger)
check("E0 MaxStay 300 (filet, Cantin 21/11), MaxCrowds 2", CROWD.MaxStay == 300 and CROWD.MaxCrowds == 2, `{CROWD.MaxStay} {CROWD.MaxCrowds}`)
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

-- E3. (a289) Objet pris dedans, sortie, dépôt ---------------------------------------------------------------------------
alice:SetAttribute("Carrying", "Legendary")
advance(0.5)
street(alice, 1)
advance(CROWD.CheckInterval + 0.05)
local outAt = NOW
check("E3 elle suit le voleur des yeux dans la rue", allFacing(alice.Character.HumanoidRootPart.Position))
advance(CROWD.Duration + CROWD.FadeTime + 1)
check("E3 (a289) encore là bien après Duration s (le voleur porte encore)", #members() == N and opaque(), #members())
far(alice)
advance(3 * CROWD.Duration)
check("E3 (a289) encore là, voleur loin du magasin qui porte encore", crowdAt(1) ~= nil and #members() == N and opaque(), #members())
alice:SetAttribute("Carrying", nil) -- objet déposé chez lui (rangé ou exposé : CarryService retire Carrying)
local depositAt = NOW
advance(GONE)
check("E3 (a289) partie dès le dépôt (Carrying retiré)", crowdAt(1) == nil and #members() == 0, #members())
print(`MESURE E3 : restée {string.format("%.1f", depositAt - outAt)} s après la sortie, partie {string.format("%.2f", NOW - depositAt)} s après le dépôt (fondu {CROWD.FadeTime})`)

-- E4. Cooldown depuis la fin ; sortie sans objet --------------------------------------------------------------------------
inside(alice, 1)
advance(0.5)
check("E4 de nouveau dedans dans le Cooldown : pas de foule", Controller.GetCount() == 1 and #members() == 0)
street(alice, 1)
advance(CROWD.Cooldown)
inside(alice, 1)
advance(0.3)
check("E4 après le Cooldown : nouvelle foule", Controller.GetCount() == 2 and crowdAt(1) ~= nil, Controller.GetCount())
street(alice, 1)
advance(CROWD.CheckInterval + 0.05)
advance(CROWD.Duration - 0.6)
check("E4 sortie sans objet : encore là juste avant Duration s", crowdAt(1) ~= nil and opaque())
advance(0.6 + CROWD.FadeTime + 0.3)
check("E4 sortie sans objet : partie Duration s après la sortie", crowdAt(1) == nil and #members() == 0, #members())

-- E5. Magasin fermé, puis ouvert ------------------------------------------------------------------------------------------
stores[2]:SetAttribute("HeistOpen", false)
inside(alice, 2)
advance(1)
check("E5 magasin fermé (HeistOpen = false) : pas de foule", Controller.GetCount() == 2 and crowdAt(2) == nil)
stores[2]:SetAttribute("HeistOpen", true)
advance(0.3)
local formedAt = NOW
check("E5 il s'ouvre pendant que le joueur est dedans : foule", Controller.GetCount() == 3 and crowdAt(2) ~= nil, Controller.GetCount())
stores[2]:SetAttribute("HeistOpen", false) -- le chrono de casse est fini : la foule reste quand même
advance(CROWD.Duration + 1)
check("E5 fermeture du chrono, joueur encore dedans : elle reste", crowdAt(2) ~= nil and #members() == N, #members())

-- E6. (a289) Filet MaxStay : le voleur porte toujours, loin --------------------------------------------------------------
alice:SetAttribute("Carrying", "Mythic")
advance(0.5)
far(alice)
advance(CROWD.MaxStay - (NOW - formedAt) - 1.5)
check("E6 encore là juste avant MaxStay (voleur qui porte, loin)", crowdAt(2) ~= nil and opaque())
advance(1.5 + CROWD.FadeTime + 0.5)
check("E6 partie après MaxStay s, vol pas fini (filet)", crowdAt(2) == nil and #members() == 0, #members())
alice:SetAttribute("Carrying", nil)
advance(0.5)
stores[2]:SetAttribute("HeistOpen", nil)

-- E7. Nuit -------------------------------------------------------------------------------------------------------------------
inside(alice, 3)
advance(0.3)
waitFull()
check("E7 foule au magasin 3", crowdAt(3) ~= nil and #members() == N)
alice:SetAttribute("Carrying", "Rare")
advance(0.5)
Workspace:SetAttribute("NightPhase", "Night")
advance(CROWD.CheckInterval + CROWD.FadeTime + 0.3)
check("E7 la nuit tombe pendant le vol : elle s'efface (AtNight = false)", CROWD.AtNight == false and crowdAt(3) == nil and #members() == 0, #members())
alice:SetAttribute("Carrying", nil)
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

-- E9. (a289) Rattrapage à la sortie, puis fin du vol -----------------------------------------------------------------------
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
check("E9 (a289) encore là après Duration s (Carol porte encore)", crowdAt(4) ~= nil)
carol:SetAttribute("Carrying", nil)
advance(GONE)
check("E9 (a289) partie à la fin du vol de Carol", crowdAt(4) == nil)
street(alice, 7)
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("E9 tout est parti", #Controller.GetCrowds() == 0 and #members() == 0, #members())

-- E10. Caméra trop loin ----------------------------------------------------------------------------------------------------
advance(CROWD.Cooldown)
local count10 = Controller.GetCount()
moveTo(alice, vec(xOf(3), 3, -65))
camera.CFrame = cf(vec(xOf(3), 10, 30 + CROWD.ViewDistance + 50), 0)
advance(1)
check("E10 voleur trop loin de la caméra : pas de foule", Controller.GetCount() == count10 and #members() == 0)
street(alice, 3)
advance(0.3)
far(alice) -- Alice regarde de loin à partir d'ici ; les voleurs sont les autres joueurs
rest()

-- T1. Capture dans le magasin ---------------------------------------------------------------------------------------------
local dave = newPlayer("Dave", vec(xOf(1), 3, -30), false)
inside(dave, 1)
advance(0.3)
check("T1 Dave entre en 1 : foule", crowdAt(1) ~= nil)
dave:SetAttribute("Carrying", "Legendary")
advance(CROWD.Duration + 1)
check("T1 Dave porte dans le magasin : elle reste", crowdAt(1) ~= nil and opaque())
dave:SetAttribute("Carrying", nil) -- attrapé dans le magasin : l'objet revole sur son rayon
advance(GONE)
check("T1 capturé dans le magasin, encore dans Bounds : partie tout de suite", crowdAt(1) == nil and #members() == 0, #members())
street(dave, 1)
advance(1)
check("T1 il ressort ensuite : pas de nouvelle foule (Cooldown)", crowdAt(1) == nil)
rest()

-- a293 (Cantin, 21/11, marque « validé » de Config/Witness.Crowd) ---------------------------------------------------------
-- A1. Attrapé dans le magasin : la foule part ; Cooldown passé, encore dedans ou ressorti les mains vides : rien ;
--     nouvelle foule à la prochaine entrée.
inside(dave, 1)
advance(0.3)
check("a293 A1 Dave entre en 1 : foule", crowdAt(1) ~= nil)
dave:SetAttribute("Carrying", "Epic")
advance(0.3)
dave:SetAttribute("Carrying", nil) -- attrapé dans le magasin
advance(GONE)
check("a293 A1 attrapé dans le magasin : partie tout de suite", crowdAt(1) == nil and #members() == 0, #members())
advance(CROWD.Cooldown + 1)
check("a293 A1 Cooldown passé, toujours dans Bounds : pas de nouvelle foule", crowdAt(1) == nil)
street(dave, 1)
advance(1)
check("a293 A1 il ressort les mains vides après le Cooldown : pas de foule", crowdAt(1) == nil and #members() == 0)
inside(dave, 1)
advance(0.3)
check("a293 A1 il rentre après le Cooldown : nouvelle foule", crowdAt(1) ~= nil)
street(dave, 1)
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
check("a293 A1 ressorti sans vol : partie après Duration", crowdAt(1) == nil)
rest()
-- A2. Attrapé dans la rue : la foule part et ne revient pas.
inside(dave, 2)
advance(0.3)
dave:SetAttribute("Carrying", "Epic")
advance(0.3)
street(dave, 2)
advance(1)
check("a293 A2 Dave dehors avec l'objet : foule en 2", crowdAt(2) ~= nil)
dave:SetAttribute("Carrying", nil) -- attrapé dans la rue
advance(GONE)
check("a293 A2 attrapé dans la rue : partie tout de suite", crowdAt(2) == nil and #members() == 0, #members())
advance(CROWD.Cooldown + 1)
check("a293 A2 Cooldown passé, Dave dans la rue : elle ne revient pas", crowdAt(2) == nil and #members() == 0)
rest()

-- T2. Objet perdu dans la rue ------------------------------------------------------------------------------------------------
inside(dave, 2)
advance(0.3)
dave:SetAttribute("Carrying", "Epic")
advance(0.3)
street(dave, 2)
advance(CROWD.Duration + 1)
check("T2 Dave dehors avec l'objet : elle reste", crowdAt(2) ~= nil and opaque())
check("T2 elle suit Dave des yeux", crowdAt(2) ~= nil and crowdAt(2).Thief == dave and allFacing(dave.Character.HumanoidRootPart.Position))
dave:SetAttribute("Carrying", nil) -- objet tombé (batte, capture dans la rue)
advance(GONE)
check("T2 objet perdu dans la rue : partie tout de suite", crowdAt(2) == nil and #members() == 0, #members())
rest()

-- T3. Objet volé par un autre joueur ---------------------------------------------------------------------------------------
local erin = newPlayer("Erin", vec(xOf(3) + 40, 3, -10), false)
inside(dave, 3)
advance(0.3)
dave:SetAttribute("Carrying", "Rare")
advance(0.3)
street(dave, 3)
advance(1)
check("T3 Dave dehors avec l'objet : foule en 3", crowdAt(3) ~= nil)
dave:SetAttribute("Carrying", nil)
erin:SetAttribute("Carrying", "Rare") -- Erin lui vole l'objet dans la rue
advance(GONE)
check("T3 volé par Erin : partie (Erin n'est pas une voleuse de ce magasin)", crowdAt(3) == nil and #members() == 0, #members())
erin:SetAttribute("Carrying", nil)
rest()

-- T4. Le voleur quitte le jeu ------------------------------------------------------------------------------------------------
inside(erin, 5)
advance(0.3)
erin:SetAttribute("Carrying", "Legendary")
advance(0.3)
street(erin, 5)
advance(CROWD.Duration + 1)
check("T4 Erin dehors avec l'objet : elle reste", crowdAt(5) ~= nil)
for i, p in PLAYERS do
	if p == erin then
		table.remove(PLAYERS, i)
		break
	end
end
Players.PlayerRemoving:Fire(erin)
advance(GONE)
check("T4 Erin quitte le jeu (attribut encore posé) : partie", crowdAt(5) == nil and #members() == 0, #members())
rest()

-- T5. Deux joueurs : le voleur dépose, l'autre est encore dedans ---------------------------------------------------------------
inside(dave, 6)
moveTo(bob, vec(xOf(6) + 4, 3, -60))
advance(0.3)
dave:SetAttribute("Carrying", "Mythic")
advance(0.3)
street(dave, 6)
advance(1)
check("T5 une foule en 6, Bob encore dedans", crowdAt(6) ~= nil and #Controller.GetCrowds() == 1)
far(dave)
dave:SetAttribute("Carrying", nil) -- Dave dépose chez lui
advance(CROWD.Duration + 1)
check("T5 Dave a déposé, Bob encore dedans : elle reste", crowdAt(6) ~= nil and opaque())
moveTo(bob, vec(xOf(6) - 3, 3, -30))
advance(GONE)
check("T5 Bob sort sans objet après le vol fini : partie tout de suite", crowdAt(6) == nil and #members() == 0, #members())
rest()

-- T6. Entré en portant déjà un objet venu d'ailleurs ----------------------------------------------------------------------------
local frank = newPlayer("Frank", vec(xOf(7), 3, -30), false)
frank:SetAttribute("Carrying", "Common")
inside(frank, 7)
advance(0.3)
check("T6 Frank entre en 7 en portant déjà : foule", crowdAt(7) ~= nil)
advance(2)
street(frank, 7)
advance(CROWD.CheckInterval + 0.05)
advance(CROWD.Duration - 0.6)
check("T6 encore là juste avant Duration s après sa sortie", crowdAt(7) ~= nil)
advance(0.6 + CROWD.FadeTime + 0.4)
check("T6 pas un voleur de ce magasin : partie Duration s après la sortie, il porte encore", crowdAt(7) == nil and frank:GetAttribute("Carrying") ~= nil)
frank:SetAttribute("Carrying", nil)
rest()

-- T7. Deux foules, une seule finit -------------------------------------------------------------------------------------------------
inside(dave, 1)
advance(0.3)
dave:SetAttribute("Carrying", "Epic")
advance(0.3)
street(dave, 1)
camera.CFrame = cf(vec(xOf(2), 10, 30), 0)
inside(frank, 2)
advance(0.3)
frank:SetAttribute("Carrying", "Rare")
advance(0.3)
street(frank, 2)
advance(1)
check("T7 deux foules (Dave en 1, Frank en 2)", crowdAt(1) ~= nil and crowdAt(2) ~= nil and #Controller.GetCrowds() == 2, #Controller.GetCrowds())
dave:SetAttribute("Carrying", nil)
advance(GONE)
check("T7 Dave dépose : sa foule part, celle de Frank reste", crowdAt(1) == nil and crowdAt(2) ~= nil)
frank:SetAttribute("Carrying", nil)
advance(GONE)
check("T7 Frank dépose : tout est parti", #Controller.GetCrowds() == 0 and #members() == 0, #members())

check("aucune erreur du contrôleur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
print(`banc a293 crowd enter : {CHECKS} vérification(s), {FAILS} échec(s)`)
