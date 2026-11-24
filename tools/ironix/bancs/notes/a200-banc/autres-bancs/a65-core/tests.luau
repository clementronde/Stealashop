-- Scénarios du banc a65 (vague 22, L-093 points 1 et 3).
--   Z : entrée par zone (TrainingService) : tapis et banc, sortie, pas de remontée en boucle,
--       non-propriétaire refusé, UseZone, Stop, profil pas chargé, plus d'invite ;
--   V : variantes du tapis (MachineVariantService avec le vrai TrainingService) : au chargement,
--       après un achat, joueur sur le tapis pendant l'échange, variante absente ou invalide, retour au
--       tapis de base au départ, paliers de Config/Upgrades.

local REFUSAL = "You can only train in your own shop."

-- Assets/Plots : variantes rangées loin (pivot en bas au centre), comme dans Studio.
local assets = newInst("Folder", "Assets", ReplicatedStorage)
local plotsFolder = newInst("Folder", "Plots", assets)
local FAR = Vector3.new(500, 0, 500)
-- Silver porte déjà le tag Treadmill (copiée d'une parcelle), Gold non ; Gold décale sa bande de 1 en Z.
buildTreadmill(plotsFolder, FAR, { name = "PLOT_Treadmill_Silver", attrs = { Theme = "Silver" } })
buildTreadmill(plotsFolder, FAR + Vector3.new(0, 0, 50), { name = "PLOT_Treadmill_Gold", tag = false, beltShift = Vector3.new(0, 0, 1) })
buildTreadmill(plotsFolder, FAR + Vector3.new(0, 0, 100), { name = "PLOT_Treadmill_CashRegister", noUpgradePoint = true })
buildTreadmill(plotsFolder, FAR + Vector3.new(0, 0, 150), { name = "PLOT_Treadmill_LaserVault", noUsePoint = true })
buildTreadmill(plotsFolder, FAR + Vector3.new(0, 0, 200), { name = "PLOT_Treadmill_Void" })
-- Police, Fire, Toxic, Candy, CashRegister : absentes.

local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
local plotA, baseA, benchA = newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
local plotB, baseB, _benchB = newPlot("PLOT_Shop_02", bob, Vector3.new(0, 0, 100))

TrainingService.Init()
local mvs = coroutine.create(MachineVariantService.Start)
local function reconcile()
	local ok, err = coroutine.resume(mvs)
	assert(ok, err)
end
reconcile() -- démarrage : tapis suivis, abonnements, puis attente du premier contrôle

local O = Vector3.new(0, 0, 0)
local USE_A = Vector3.new(0, 1.2, 0) -- UsePoint du tapis d'Alice (dessus de la bande)
local STAND = Vector3.new(0, 3, 0) -- HumanoidRootPart debout au-dessus du point
local BENCH_USE = Vector3.new(20, 0.2, 0)
local function away(p)
	moveTo(p, Vector3.new(0, 3, -400) + Vector3.new(p.UserId * 10, 0, 0))
	step(0.2)
end
local function treadmillOf(plot)
	for _, o in CollectionService:GetTagged("Treadmill") do
		if o:IsDescendantOf(plot) then
			return o
		end
	end
	return nil
end

------------------------------------------------------------------------ Z1 tapis par la zone
do
	away(alice)
	-- À côté de la bande (X = 2,6 : hors de la bande, dans la zone qui va jusqu'à 3), en marchant.
	moveTo(alice, Vector3.new(2.6, 3, 1), Vector3.new(-12, 0, 0))
	step(0.05)
	-- a115 : START_DWELL = 0, contrôle à chaque Heartbeat : monté dès la première image dans la zone.
	check("Z1 monte sur le tapis en entrant dans la zone, même en marchant", machineOf(alice) == "Treadmill", machineOf(alice))
	check("Z1 placé sur le UsePoint, debout", rootPos(alice) == USE_A + Vector3.new(0, 3, 0), tostring(rootPos(alice)))
	check("Z1 a115 : figé au tapis aussi (vitesse 0)", SPEEDMOD[alice] == 0, SPEEDMOD[alice])
	-- Zone : X ±3 ; à 3,4 de l'axe : hors de la zone.
	away(alice)
	moveTo(alice, Vector3.new(3.4, 3, 0))
	step(1)
	check("Z1 hors de la zone (marge 1 stud dépassée) : rien", machineOf(alice) == nil)
	-- Trop haut au-dessus de la machine (haut 4 + ZONE_ABOVE 4 = 8) : rien.
	moveTo(alice, Vector3.new(0, 9, 0))
	step(1)
	check("Z1 au-dessus de la zone : rien", machineOf(alice) == nil)
end

------------------------------------------------------------------------ Z2 sortir, pas de boucle
do
	away(alice)
	moveTo(alice, Vector3.new(0, 3, 2))
	step(0.5)
	check("Z2 sur le tapis", machineOf(alice) == "Treadmill")
	-- Pas de côté hors de la bande (bord 1,5 + LEAVE_MARGIN 1 → 2,6), encore dans la zone (3).
	moveTo(alice, Vector3.new(2.7, 3, 0))
	step(0.6)
	check("Z2 descendu de la bande : séance finie", machineOf(alice) == nil)
	step(2)
	check("Z2 resté dans la zone : ne remonte pas", machineOf(alice) == nil)
	-- Saut sur place très haut (au-dessus de la zone) : toujours au-dessus de son emprise, pas débloqué.
	moveTo(alice, Vector3.new(2.7, 14, 0))
	step(0.2)
	moveTo(alice, Vector3.new(2.7, 3, 0))
	step(1)
	check("Z2 saut au-dessus de la zone puis retour à côté de la bande : ne remonte pas", machineOf(alice) == nil)
	-- a115 : revenu sur la bande (le cœur du tapis) après l'avoir quittée : remonte, sans sortir de la zone.
	moveTo(alice, Vector3.new(1, 3, 0))
	step(0.05)
	check("Z2 a115 : revenu sur la bande : remonte tout de suite", machineOf(alice) == "Treadmill")
	moveTo(alice, Vector3.new(2.7, 3, 0))
	step(0.6)
	check("Z2 a115 : redescendu de la bande", machineOf(alice) == nil)
	-- Sortie de la zone puis retour : remonte.
	moveTo(alice, Vector3.new(4, 3, 0))
	step(0.2)
	moveTo(alice, Vector3.new(1, 3, 0))
	step(0.5)
	check("Z2 sorti puis revenu : remonte", machineOf(alice) == "Treadmill")
	-- Saut sur place au tapis : ne coupe pas (logique L-071 gardée).
	setState(alice, "Jumping")
	moveTo(alice, USE_A + Vector3.new(0, 9, 0))
	step(0.3)
	moveTo(alice, USE_A + Vector3.new(0, 3, 0))
	setState(alice, "Landed")
	step(0.3)
	check("Z2 saut sur place au tapis : toujours dessus", machineOf(alice) == "Treadmill")
	-- Saut hors du tapis, retombé dans la zone : descendu, pas de remontée.
	setState(alice, "Jumping")
	moveTo(alice, Vector3.new(0, 4, 4.6)) -- bande jusqu'à 3,25 + 1 ; zone jusqu'à 5
	step(0.3)
	setState(alice, "Landed")
	step(1.5)
	check("Z2 sauté hors de la bande, retombé dans la zone : descendu, ne remonte pas", machineOf(alice) == nil)
end

------------------------------------------------------------------------ Z3 banc par la zone
do
	away(alice)
	local mat = benchA:FindFirstChild("GymMat")
	local clementPrompt = mat:FindFirstChild("ProximityPrompt")
	check("Z3 plus d'invite créée par le code (TrainingPrompt)", benchA:FindFirstChild("TrainingPrompt", true) == nil)
	check("Z3 invite « Lift » du modèle de Clément désactivée", clementPrompt ~= nil and clementPrompt.Enabled == false)
	check("Z3 une ligne dans la sortie pour l'invite désactivée", hasLog("invite désactivée"))
	clementPrompt.Triggered:Fire(alice)
	step(0.3)
	check("Z3 l'invite ne fait plus rien", machineOf(alice) == nil)
	-- Copie a134 (rééquilibrage v2) : plus de banc. Dans sa zone (X 16 à 24), rien ne se passe ; seule l'invite
	-- « Lift » du modèle reste coupée par le code, pour ne pas proposer un banc qui ne fait plus rien.
	moveTo(alice, Vector3.new(23.5, 3, 1))
	step(0.4)
	check("Z3 a134 : dans la zone du banc : aucune séance", machineOf(alice) == nil, machineOf(alice))
	check("Z3 a134 : pas immobilisé", SPEEDMOD[alice] == nil)
	step(1.6)
	check("Z3 a134 : aucune répétition (BenchReps n'est plus posé)", alice:GetAttribute("BenchReps") == nil)
	check("Z3 a134 : aucune Force gagnée", (STRENGTH and STRENGTH[alice] or 0) == 0)
	away(alice)
end

------------------------------------------------------------------------ Z4 non-propriétaire
do
	away(bob)
	local before = notifyCount(bob)
	moveTo(bob, Vector3.new(1, 3, 1)) -- tapis d'Alice
	step(1.5)
	check("Z4 Bob refusé sur le tapis d'Alice", machineOf(bob) == nil)
	check("Z4 un message", notifyCount(bob) == before + 1, notifyCount(bob) - before)
	check("Z4 le message de refus", NOTIFIES[#NOTIFIES][2] == REFUSAL)
	moveTo(bob, Vector3.new(21, 3, 0)) -- banc d'Alice, 1,5 s après : pas de nouveau message
	step(1.5)
	check("Z4 refusé au banc d'Alice", machineOf(bob) == nil)
	check("Z4 pas de second message avant NOT_OWNER_COOLDOWN", notifyCount(bob) == before + 1, notifyCount(bob) - before)
	away(bob)
	step(10)
	moveTo(bob, Vector3.new(1, 3, 1))
	step(0.5)
	check("Z4 après 10 s : un nouveau message", notifyCount(bob) == before + 2, notifyCount(bob) - before)
	check("Z4 toujours refusé", machineOf(bob) == nil)
	-- Son propre tapis : accepté.
	moveTo(bob, Vector3.new(0, 3, 101))
	step(0.5)
	check("Z4 Bob sur son tapis : accepté", machineOf(bob) == "Treadmill")
	away(bob)
end

------------------------------------------------------------------------ Z5 Stop, profil, TrainTap
do
	away(alice)
	moveTo(alice, Vector3.new(1, 3, 1))
	step(0.1)
	TrainingService.Stop(alice)
	step(1)
	check("Z5 Stop avant la montée : pas de séance tant qu'il reste dans la zone", machineOf(alice) == nil)
	away(alice)
	moveTo(alice, Vector3.new(1, 3, 1))
	step(0.5)
	check("Z5 sorti puis revenu : monte", machineOf(alice) == "Treadmill")
	TrainingService.Stop(alice)
	step(1)
	check("Z5 Stop en séance : descendu, ne remonte pas dans la zone", machineOf(alice) == nil)
	away(alice)
	NOT_LOADED[alice] = true
	moveTo(alice, Vector3.new(1, 3, 1))
	step(1)
	check("Z5 profil pas chargé : rien", machineOf(alice) == nil)
	NOT_LOADED[alice] = nil
	step(0.3)
	check("Z5 profil chargé : monte sans ressortir", machineOf(alice) == "Treadmill")
	away(alice)
	TAP:Fire(alice)
	step(0.3)
	check("Z5 TrainTap hors machine : rien", machineOf(alice) == nil)
end

------------------------------------------------------------------------ Z6 UseZone
do
	local carl = newPlayer("Carl")
	local plotC = newInst("Model", "PLOT_Shop_03", nil)
	plotC._tags.PlayerPlot = true
	plotC:SetAttribute("OwnerUserId", carl.UserId)
	plotC.Parent = workspace
	local origin = Vector3.new(0, 0, 300)
	-- UseZone 2 × 1 × 2 posée devant la console (centre Z = -3) seulement.
	buildTreadmill(plotC, origin, { useZone = { size = Vector3.new(2, 1, 2), offset = Vector3.new(0, 0.5, -3) } })
	moveTo(carl, origin + Vector3.new(1.5, 3, 2)) -- dans la boîte du modèle, hors de UseZone
	step(1)
	check("Z6 avec UseZone : la boîte du modèle ne compte plus", machineOf(carl) == nil)
	moveTo(carl, origin + Vector3.new(0.5, 3, -3))
	step(0.5)
	check("Z6 dans UseZone : monte", machineOf(carl) == "Treadmill")
	check("Z6 placé sur le UsePoint", rootPos(carl) == origin + Vector3.new(0, 4.2, 0), tostring(rootPos(carl)))
	away(carl)
end

------------------------------------------------------------------------ V variantes
check("V0 a134 : VariantFor (niveau enregistré, lu sur le niveau affiché + 1) : 0 → Base, 1 et 2 → Silver", MachineVariantService.VariantFor(0) == "Base" and MachineVariantService.VariantFor(1) == "Silver" and MachineVariantService.VariantFor(2) == "Silver")
check("V0 VariantFor : 2 → Silver, 4 → Gold, 5 et 6 → CashRegister, 12 → Ice", MachineVariantService.VariantFor(2) == "Silver" and MachineVariantService.VariantFor(4) == "Gold" and MachineVariantService.VariantFor(5) == "CashRegister" and MachineVariantService.VariantFor(6) == "CashRegister" and MachineVariantService.VariantFor(12) == "Ice")
check("V0 a134 : VariantFor : 18 → Fire, 19 → Void (niveau affiché 20), 25 → Void (dernier)", MachineVariantService.VariantFor(18) == "Fire" and MachineVariantService.VariantFor(19) == "Void" and MachineVariantService.VariantFor(25) == "Void")
do
	local Upgrades = requireModule(ReplicatedStorage.Shared.Config.Upgrades)
	local expected = { "Base", "Silver", "Gold", "CashRegister", "Police", "LaserVault", "Ice", "Toxic", "Candy", "Fire", "Void" }
	local same = #Upgrades.TreadmillVariants == #expected
	for i, n in expected do
		same = same and Upgrades.TreadmillVariants[i] == n
	end
	check("V0 Config : ordre validé par Clément (L-097), 11 tapis", same)
	check("V0 Config : un palier toutes les 2 améliorations, Void au MaxLevel 20", Upgrades.TreadmillTierEvery == 2 and (#expected - 1) * Upgrades.TreadmillTierEvery == 20)
end

-- V1 : au démarrage, niveau 0 : le tapis de Clément reste.
check("V1 niveau 0 : tapis de base gardé", treadmillOf(plotA) == baseA and MachineVariantService.GetVariant(plotA) == "Base")

-- V2 : chargement du profil au niveau 5 (Bob) : Gold posé.
do
	away(bob)
	releasePlot(bob, plotB)
	DATA[bob].Upgrades.Treadmill = 4 -- a134 : niveau enregistré 4 = niveau affiché 5 : Gold
	assignPlot(bob, plotB)
	local t = treadmillOf(plotB)
	check("V2 chargement niveau 5 : variante Gold", MachineVariantService.GetVariant(plotB) == "Gold")
	check("V2 une copie de PLOT_Treadmill_Gold", t ~= nil and t ~= baseB and t._cloneOf == plotsFolder:FindFirstChild("PLOT_Treadmill_Gold"))
	check("V2 nom Treadmill, tag Treadmill ajouté", t.Name == "Treadmill" and CollectionService:HasTag(t, "Treadmill"))
	check("V2 même parent et même pivot que le tapis de base", t.Parent == plotB and t:GetPivot() == CFrame.new(0, 0, 100))
	check("V2 attributs du tapis de base repris", t:GetAttribute("Theme") == "PLOT_Shop_02")
	check("V2 tapis de base mis de côté, pas détruit", baseB.Parent == nil and not rawget(baseB, "_destroyed"))
	check("V2 un seul tapis dans la parcelle", #(function()
		local r = {}
		for _, o in CollectionService:GetTagged("Treadmill") do
			if o:IsDescendantOf(plotB) then
				table.insert(r, o)
			end
		end
		return r
	end)() == 1)
	check("V2 modèle des Assets intact", plotsFolder:FindFirstChild("PLOT_Treadmill_Gold") ~= nil and plotsFolder:FindFirstChild("PLOT_Treadmill_Gold"):GetPivot() == CFrame.new(FAR + Vector3.new(0, 0, 50)))
	-- TrainingService a pris le nouveau tapis : UsePoint décalé de 1 en Z (bande Gold).
	moveTo(bob, Vector3.new(0, 3, 101))
	step(0.5)
	check("V2 Bob s'entraîne sur le tapis Gold", machineOf(bob) == "Treadmill")
	check("V2 placé sur le UsePoint de Gold", rootPos(bob) == Vector3.new(0, 4.2, 101), tostring(rootPos(bob)))
	check("V2 a134 : gain au niveau affiché 5 : 2^4 = 16 par seconde", (function()
		local s0 = SPEED[bob] or 0
		step(1.0)
		return near((SPEED[bob] or 0) - s0, 16)
	end)())
end

-- V3 : achat pendant qu'il court : CashRegister posé (sans UpgradePoint : une ligne) ; a200 : la séance continue
-- sur le nouveau tapis, sans descendre (replacé sur son UsePoint, la bande de Gold était décalée).
do
	check("V3 Bob en séance avant l'achat", machineOf(bob) == "Treadmill")
	local gold = treadmillOf(plotB)
	DATA[bob].Upgrades.Treadmill = 6
	bob:SetAttribute("TreadmillLevel", 6) -- ShopService publie le niveau après l'achat
	local register = treadmillOf(plotB)
	check("V3 achat niveau 6 : variante CashRegister", MachineVariantService.GetVariant(plotB) == "CashRegister" and register ~= gold)
	check("V3 l'ancienne copie (Gold) est détruite", rawget(gold, "_destroyed") == true)
	check("V3 CashRegister sans UpgradePoint : une ligne dans la sortie", hasLog("PLOT_Treadmill_CashRegister : pas d'UpgradePoint"))
	check("V3 a200 : toujours en séance pendant l'échange", machineOf(bob) == "Treadmill")
	step(0.5)
	check("V3 a200 : toujours en séance sur le nouveau tapis", machineOf(bob) == "Treadmill" and hasLog("Bob reste en séance sur le nouveau tapis") and not hasLog("Bob quitte le tapis (machine retirée)"))
	check("V3 placé sur le UsePoint de CashRegister", rootPos(bob) == Vector3.new(0, 4.2, 100), tostring(rootPos(bob)))
end

-- V4 : variante absente (Police, niveau 8) : CashRegister reste, une seule ligne malgré les contrôles.
do
	DATA[bob].Upgrades.Treadmill = 8
	bob:SetAttribute("TreadmillLevel", 8)
	reconcile()
	reconcile()
	check("V4 Police absente : CashRegister reste", MachineVariantService.GetVariant(plotB) == "CashRegister")
	check("V4 une seule ligne dans la sortie", logCount("PLOT_Treadmill_Police absent") == 1, logCount("PLOT_Treadmill_Police absent"))
	check("V4 Bob toujours sur son tapis", machineOf(bob) == "Treadmill")
	-- Variante sans UsePoint (LaserVault, niveau 10) : refusée, CashRegister reste.
	DATA[bob].Upgrades.Treadmill = 10
	reconcile()
	check("V4 LaserVault sans UsePoint : CashRegister reste", MachineVariantService.GetVariant(plotB) == "CashRegister")
	check("V4 LaserVault : une ligne dans la sortie", logCount("PLOT_Treadmill_LaserVault : pas d'Attachment UsePoint") == 1)
	-- Niveau changé sans la boutique (contrôle d'une seconde) : Void au niveau 20.
	DATA[bob].Upgrades.Treadmill = 20
	reconcile()
	check("V4 contrôle périodique : Void au niveau 20", MachineVariantService.GetVariant(plotB) == "Void")
	step(0.5)
	check("V4 Bob remis sur Void", machineOf(bob) == "Treadmill")
end

-- V5 : départ : la parcelle retrouve le tapis de base, le suivant part de là.
do
	local voidCopy = treadmillOf(plotB)
	TrainingService.Stop(bob)
	bob.Parent = nil
	Players.PlayerRemoving:Fire(bob)
	releasePlot(bob, plotB)
	check("V5 départ : tapis de base revenu (même instance)", treadmillOf(plotB) == baseB and baseB.Parent == plotB)
	check("V5 à son pivot d'origine", baseB:GetPivot() == CFrame.new(0, 0, 100))
	check("V5 la copie Void est détruite", rawget(voidCopy, "_destroyed") == true)
	check("V5 GetVariant = Base", MachineVariantService.GetVariant(plotB) == "Base")
	reconcile()
	check("V5 parcelle libre : reste Base", MachineVariantService.GetVariant(plotB) == "Base")
	-- Nouveau joueur sur la parcelle, niveau 3 : Silver (déjà taggée dans les Assets).
	local dana = newPlayer("Dana")
	DATA[dana].Upgrades.Treadmill = 2 -- a134 : niveau enregistré 2 = niveau affiché 3 : Silver
	assignPlot(dana, plotB)
	local silver = treadmillOf(plotB)
	check("V5 joueur suivant niveau 3 : Silver", MachineVariantService.GetVariant(plotB) == "Silver" and silver ~= baseB)
	check("V5 Silver : attribut de la variante gardé (pas écrasé)", silver:GetAttribute("Theme") == "Silver")
	moveTo(dana, Vector3.new(0, 3, 101))
	step(0.5)
	check("V5 Dana s'entraîne sur Silver", machineOf(dana) == "Treadmill")
	-- Achat qui ramène au niveau 0 (renaissance) : retour au tapis de base.
	DATA[dana].Upgrades.Treadmill = 0
	dana:SetAttribute("TreadmillLevel", 0)
	check("V5 niveau 0 : tapis de base", treadmillOf(plotB) == baseB and rawget(silver, "_destroyed") == true)
	step(0.5)
	check("V5 Dana remise sur le tapis de base", machineOf(dana) == "Treadmill")
end

-- V6 : la parcelle d'Alice n'a jamais bougé ; aucune erreur.
check("V6 parcelle d'Alice : toujours son tapis de base", treadmillOf(plotA) == baseA and baseA.Parent == plotA)
check("V6 aucune erreur dans la sortie", not hasLog("ERREUR"))

print("banc a65 : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
