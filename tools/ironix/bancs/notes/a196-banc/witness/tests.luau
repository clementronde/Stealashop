-- Banc a196, partie witness (vague 60, T-087, Cantin : « si le témoin est trop loin, il n'a pas le temps d'arriver vers
-- la vitre ») : vitesse d'approche = distance / (temps restant avant le « ? » plein − ApproachLead), entre ApproachSpeed
-- et ApproachMaxSpeed, revue à chaque MoveTo. Harnais a100 (copie a151) : les Humanoid avancent à leur WalkSpeed.
--   W1 près : ApproachSpeed, comme avant ; W2 loin (≈ 100 studs) : plus vite, à son poste avant le « ? » plein ;
--   W3 très loin : plafond ApproachMaxSpeed ; W4 « ? » figé (Pause) : retour à ApproachSpeed au MoveTo suivant

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local Gauge = requireShared("Shared.WitnessGauge")
local PHOTO = Witness.Photo

check("W0 réglages V0 : ApproachLead 1 s, ApproachMaxSpeed 32, Bursts 2 à 0,08 s", PHOTO.ApproachLead == 1 and PHOTO.ApproachMaxSpeed == 32 and PHOTO.Bursts == 2 and PHOTO.BurstGap == 0.08)

local map = node("Folder", "Map", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local witnesses = node("Folder", "Witnesses", zone1)
-- Vitres orientées vers +Z (la rue) ; un magasin par témoin.
local function store(name, x)
	local s = newStore(name, zone1, 1, vec(x, 5, -50))
	s.Window.CFrame = CFrame.lookAt(vec(x, 5, -50), vec(x, 5, -49))
	s.Window.Size = vec(10, 6, 0.5)
	return s
end
local sNear = store("STORE_Z1_Near", 0)
local sFar = store("STORE_Z1_Far", 400)
local sVery = store("STORE_Z1_Very", 800)
local sPause = store("STORE_Z1_Pause", 1200)
-- Poste : 8 studs devant la vitre (z = -42), décalé de 2 studs (témoin impair : x − 2).
local wNear = newWitness("NPC_Witness_Z1_01", witnesses, vec(-2, 3, -22), "STORE_Z1_Near") -- 20 studs
local wFar = newWitness("NPC_Witness_Z1_03", witnesses, vec(398, 3, 58), "STORE_Z1_Far") -- 100 studs
local wVery = newWitness("NPC_Witness_Z1_05", witnesses, vec(798, 3, 258), "STORE_Z1_Very") -- 300 studs
local wPause = newWitness("NPC_Witness_Z1_07", witnesses, vec(1198, 3, 58), "STORE_Z1_Pause") -- 100 studs
local alice = newPlayer("Alice", vec(0, 3, -45))
POLICE_TEMPLATE = nil

local Service = loadWitness()

local function stateOf(model)
	return model:GetAttribute(Gauge.StateAttribute)
end
local function infoOf(s, model)
	for _, entry in Service.GetState(s) do
		if entry.Witness == model then
			return entry
		end
	end
	return nil
end
local function speedOf(model)
	return model.Humanoid.WalkSpeed
end
local function flatDistance(a, b)
	return vec(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
-- Avance jusqu'à la fin de l'approche (au plus `limit` s) ; renvoie le temps passé.
local function untilPosted(s, model, limit)
	local t = 0
	while t < limit and infoOf(s, model).Approaching do
		advance(0.05)
		t += 0.05
	end
	return t
end

-- W1. Près : le pas pressé d'avant.
do
	hit(alice, sNear)
	check("W1 près (20 studs) : il s'approche à ApproachSpeed", infoOf(sNear, wNear).Approaching == true and speedOf(wNear) == PHOTO.ApproachSpeed, speedOf(wNear))
	check("W1 Walk joue", playing(wNear, "Walk"))
	local t = untilPosted(sNear, wNear, 8)
	check("W1 arrivé à son poste, « ? » pas encore plein", infoOf(sNear, wNear).Approaching == false and stateOf(wNear) == "Watch" and playing(wNear, "Look"), t)
end

-- W2. Loin (100 studs) : plus vite, à son poste ApproachLead s avant le « ? » plein.
do
	rootOf(alice.Character).Position = vec(400, 3, -45)
	hit(alice, sFar)
	local start = rootOf(wFar).Position
	local want = flatDistance(start, vec(398, 3, -42)) / (Witness.FillTime - PHOTO.ApproachLead)
	check("W2 loin : vitesse = distance / (FillTime − ApproachLead)", math.abs(speedOf(wFar) - want) < 1e-6 and speedOf(wFar) > PHOTO.ApproachSpeed, `{speedOf(wFar)} / {want}`)
	local t = untilPosted(sFar, wFar, Witness.FillTime + 1)
	local info = infoOf(sFar, wFar)
	check("W2 à son poste avant le « ? » plein (Watch, Look)", info.Approaching == false and stateOf(wFar) == "Watch" and playing(wFar, "Look"), `{t} s, {stateOf(wFar)}`)
	check("W2 arrivé à moins de FillTime − ApproachLead + 0,5 s", t <= Witness.FillTime - PHOTO.ApproachLead + 0.5, t)
	check("W2 posté à son poste", flatDistance(rootOf(wFar).Position, vec(398, 3, -42)) <= Witness.PointReached, flatDistance(rootOf(wFar).Position, vec(398, 3, -42)))
end

-- W3. Très loin (300 studs) : plafond.
do
	rootOf(alice.Character).Position = vec(800, 3, -45)
	hit(alice, sVery)
	check("W3 très loin : plafond ApproachMaxSpeed", speedOf(wVery) == PHOTO.ApproachMaxSpeed, speedOf(wVery))
	advance(Witness.MoveRefresh + 0.1)
	check("W3 toujours au plafond au MoveTo suivant", speedOf(wVery) == PHOTO.ApproachMaxSpeed and infoOf(sVery, wVery).Approaching == true, speedOf(wVery))
end

-- W4. « ? » figé : plus pressé, ApproachSpeed au MoveTo suivant ; il repart plus vite quand le « ? » remonte.
do
	rootOf(alice.Character).Position = vec(1200, 3, -45)
	hit(alice, sPause)
	local fast = speedOf(wPause)
	check("W4 loin : plus vite qu'ApproachSpeed", fast > PHOTO.ApproachSpeed, fast)
	Service.Pause(sPause)
	advance(Witness.MoveRefresh + 0.1)
	check("W4 « ? » figé : ApproachSpeed au MoveTo suivant", speedOf(wPause) == PHOTO.ApproachSpeed and infoOf(sPause, wPause).Approaching == true, speedOf(wPause))
	Service.Raise(sPause, alice, 3) -- plein en 3 s : il est en retard
	advance(Witness.MoveRefresh + 0.1)
	check("W4 le « ? » remonte : il presse à nouveau le pas", speedOf(wPause) > PHOTO.ApproachSpeed, speedOf(wPause))
end
check("W5 aucune erreur dans la boucle (hors avertissements de mise en place : sans circuit, sans policier)", not hasLog("erreur"))

print(`banc a196 witness : {CHECKS} vérification(s), {FAILS} échec(s)`)
