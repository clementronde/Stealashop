-- a416 : mesure côté CLIENT de ce que le joueur voit pendant une poursuite (recette T-1560). À coller dans la barre de
-- commande de Studio en Play, vue « Client » (ou à lancer côté client par le MCP). Aucun require, rien n'est envoyé au
-- serveur, rien n'est changé dans le jeu. Écrit dans la sortie du client, lignes « [a416] » :
--   - chaque seconde, quand je cours à pleine vitesse devant un vigile : la distance moyenne où je le vois (à comparer à
--     la distance prévue du serveur, 14 studs au-dessus du minimum de vitesse : ligne « prévue » de ChaseDebug) ;
--   - à l'annonce de la capture (ma WalkSpeed passe à 0) : la distance où je vois le vigile à cet instant, la plus
--     petite distance de la seconde d'avant, ma vitesse ; puis 0,15, 0,30 et 0,60 s après ; et au coup (poussée).
-- a420 (copie, recette a420-banc/consigne-play.txt) : en plus, lignes « [a420] arrêt net » : quand je m'arrête net
-- après au moins 0,5 s de course devant le vigile, la position du vigile le long de ma course pendant les 2 s qui
-- suivent : « au plus près » (positif = derrière moi, NÉGATIF = il m'a traversé de tant de studs) et « à la fin ».
-- _G.A416Stop() arrête la mesure ; relancer le script remplace la mesure en cours.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local me = Players.LocalPlayer
if _G.A416Stop then
	_G.A416Stop()
end

local guard = nil -- dernier vigile qui me poursuivait (gardé après la capture : sa cible repasse à 0)
local guardSeenAt = 0
local samples = {} -- { t, d, speed } des 2 dernières secondes
local holdSum, holdCount, holdNext = 0, 0, 0
local lastWalk = nil
local connections = {}
-- a420 : arrêt net (voir l'en-tête)
local runDir, runSince, runLast = nil, nil, nil
local stopAt, stopDir, stopMin, stopSpeed = nil, nil, math.huge, nil

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function rootOf(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end
-- Le vigile qui me poursuit : Workspace/ActiveGuards, attribut TargetUserId (posés par GuardService).
local function findGuard()
	local folder = workspace:FindFirstChild("ActiveGuards")
	for _, model in (if folder then folder:GetChildren() else {}) do
		if model:GetAttribute("TargetUserId") == me.UserId then
			return model
		end
	end
	return nil
end
local function distance()
	local mine, theirs = rootOf(me.Character), rootOf(guard)
	if mine and theirs then
		return flat(mine.Position - theirs.Position).Magnitude
	end
	return nil
end
local function report(label)
	local d = distance()
	print(string.format("[a416] %s : vigile vu à %s studs", label, if d then string.format("%.1f", d) else "?"))
end

table.insert(connections, RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local found = findGuard()
	if found then
		guard = found
		guardSeenAt = now
	end
	local character = me.Character
	local root = rootOf(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		return
	end
	local d = distance()
	local speed = flat(root.AssemblyLinearVelocity).Magnitude
	local walk = humanoid.WalkSpeed
	if d then
		table.insert(samples, { t = now, d = d, speed = speed })
		while samples[1] and samples[1].t < now - 2 do
			table.remove(samples, 1)
		end
		if found and walk > 0 and speed > 0.8 * walk then
			holdSum += d
			holdCount += 1
		end
		if now >= holdNext then
			if holdCount >= 30 then
				print(string.format("[a416] poursuite : vigile vu à %.1f studs en moyenne ; je cours à %.0f studs/s (marche %.0f)", holdSum / holdCount, speed, walk))
			end
			holdSum, holdCount, holdNext = 0, 0, now + 1
		end
	end
	-- a420 : arrêt net. Sens de course retenu tant que je cours (au moins la moitié de ma marche) ; arrêt = moins de
	-- 2 studs/s alors que je courais il y a 0,3 s au plus, après 0,5 s de course au moins.
	local guardRoot = rootOf(guard)
	if walk > 0 and speed > 0.5 * walk then
		runDir = flat(root.AssemblyLinearVelocity).Unit
		runSince = runSince or now
		runLast = now
	elseif runLast and now - runLast >= 0.3 then
		runSince, runLast = nil, nil
	end
	if stopAt == nil and runDir and runLast and runSince and speed < 2 and now - runLast < 0.3 and runLast - runSince > 0.5 and guardRoot and now - guardSeenAt < 1 then
		stopAt, stopDir, stopMin, stopSpeed = now, runDir, math.huge, nil
		for _, s in samples do
			if s.t <= runLast then
				stopSpeed = s.speed
			end
		end
		runSince, runLast = nil, nil
	end
	if stopAt and guardRoot then
		local along = flat(root.Position - guardRoot.Position):Dot(stopDir)
		stopMin = math.min(stopMin, along)
		if now - stopAt >= 2 then
			print(string.format("[a420] arrêt net (je courais à %.0f studs/s) : vigile au plus près à %.1f studs %s, à la fin à %.1f studs %s",
				stopSpeed or 0, math.abs(stopMin), if stopMin >= 0 then "derrière moi" else "DEVANT moi (il m'a traversé)",
				math.abs(along), if along >= 0 then "derrière" else "devant"))
			stopAt = nil
		end
	elseif stopAt then
		stopAt = nil
	end
	-- Annonce de la capture : ma marche passe à 0 alors qu'un vigile me poursuivait il y a moins d'1 s.
	if lastWalk and lastWalk > 0 and walk == 0 and now - guardSeenAt < 1 and d then
		local closest, before = d, speed
		for _, s in samples do
			if s.t >= now - 1 then
				closest = math.min(closest, s.d)
			end
			if s.t <= now - 0.1 then
				before = s.speed
			end
		end
		print(string.format("[a416] CAPTURE annoncée : vigile vu à %.1f studs (au plus près dans la seconde d'avant : %.1f) ; je courais à %.0f studs/s", d, closest, before))
		for _, delay in { 0.15, 0.3, 0.6 } do
			task.delay(delay, function()
				report(string.format("%.2f s après l'annonce", delay))
			end)
		end
	end
	lastWalk = walk
end))

local function watch(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		table.insert(connections, root.ChildAdded:Connect(function(child)
			if child.Name == "GuardKnockback" then
				report("au coup du vigile (poussée)")
			end
		end))
	end
end
if me.Character then
	task.spawn(watch, me.Character)
end
table.insert(connections, me.CharacterAdded:Connect(watch))

_G.A416Stop = function()
	for _, connection in connections do
		connection:Disconnect()
	end
	_G.A416Stop = nil
	print("[a416] mesure arrêtée")
end
print("[a416] mesure lancée : cours devant un vigile ; _G.A416Stop() pour arrêter")
