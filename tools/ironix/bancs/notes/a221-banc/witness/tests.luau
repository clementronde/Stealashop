-- Banc a221, partie witness (vague 66, L-210 point 4, Clément : « il doit foncer sur le joueur dès le premier coup, arriver
-- vite et photographier avec flash »). Harnais a100 (copie a151) : les Humanoid avancent à leur WalkSpeed ; le faux
-- AnimPlayer renvoie une piste pour les noms de HAVE[modèle].
--   R0 réglages V0 ; R1 il fonce (RushSpeed) avec la course (Flee) ; R2 arrivé : TakePhoto, « ? » qui monte, flash au
--   marqueur Flash ; R3 sans TakePhoto : Look, flash tout de suite puis toutes les Interval s ; R4 la casse le fait fuir
--   (photos arrêtées) ; R5 « ? » plein : il range l'appareil, appelle, puis filme (L-172) ; R6 très loin : plafond.

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local Gauge = requireShared("Shared.WitnessGauge")
local PHOTO = Witness.Photo

check("R0 réglages V0 : Rush, RushSpeed 24, RushAnim Flee", PHOTO.Rush == true and PHOTO.RushSpeed == 24 and PHOTO.RushAnim == "Flee")

local map = node("Folder", "Map", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local witnesses = node("Folder", "Witnesses", zone1)
local function store(name, x)
	local s = newStore(name, zone1, 1, vec(x, 5, -50))
	s.Window.CFrame = CFrame.lookAt(vec(x, 5, -50), vec(x, 5, -49))
	s.Window.Size = vec(10, 6, 0.5)
	return s
end
local sA = store("STORE_Z1_A", 0)
local sB = store("STORE_Z1_B", 400)
local sC = store("STORE_Z1_C", 800)
-- Poste : 8 studs devant la vitre (z = -42), décalé de 2 studs (témoin impair : x − 2).
local wA = newWitness("NPC_Witness_Z1_01", witnesses, vec(-2, 3, -2), "STORE_Z1_A") -- 40 studs
local wB = newWitness("NPC_Witness_Z1_03", witnesses, vec(398, 3, -32), "STORE_Z1_B") -- 10 studs
local wC = newWitness("NPC_Witness_Z1_05", witnesses, vec(798, 3, 258), "STORE_Z1_C") -- 300 studs
local alice = newPlayer("Alice", vec(0, 3, -45))
POLICE_TEMPLATE = nil

local Service = loadWitness()

local HAVE = { [wA] = { Flee = true, TakePhoto = true }, [wB] = {}, [wC] = {} }
for model, names in HAVE do
	local p = ANIM_PLAYERS[model]
	local base = p.Play
	p.Play = function(self, name, ...)
		base(self, name, ...)
		if names[name] then
			return {}
		end
		return nil
	end
end

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
local function flashes(model)
	return model:GetAttribute(Gauge.FlashAttribute) or 0
end
local function untilPosted(s, model, limit)
	local t = 0
	while t < limit and infoOf(s, model).Approaching do
		advance(0.05)
		t += 0.05
	end
	return t
end

-- R1, R2. Il fonce avec la course, arrive vite, photographie (TakePhoto), flash au marqueur.
do
	local t0 = NOW
	hit(alice, sA)
	check("R1 il fonce : WalkSpeed ≥ RushSpeed", infoOf(sA, wA).Approaching == true and wA.Humanoid.WalkSpeed >= PHOTO.RushSpeed, wA.Humanoid.WalkSpeed)
	check("R1 la course (Flee) joue, pas la marche", playing(wA, "Flee") and not playing(wA, "Walk"))
	local t = untilPosted(sA, wA, 8)
	check("R2 arrivé en moins de 2,5 s (40 studs)", t <= 2.5, t)
	local info = infoOf(sA, wA)
	check("R2 à son poste : il photographie (Snapping), « ? » qui monte, course arrêtée", info.Snapping == true and stateOf(wA) == "Watch" and info.Rate > 0 and not playing(wA, "Flee"), stateOf(wA))
	check("R2 TakePhoto joue, pas Look", playing(wA, "TakePhoto") and not playing(wA, "Look"))
	local before = flashes(wA)
	fireMarker(wA, "TakePhoto", "Flash")
	check("R2 un flash au marqueur Flash", flashes(wA) == before + 1, flashes(wA))
	fireMarker(wA, "TakePhoto", "Flash")
	check("R2 pas deux flashs à moins de MinInterval", flashes(wA) == before + 1, flashes(wA))
	advance(PHOTO.Interval * 3)
	check("R2 marqueurs venus : plus de rythme de secours", flashes(wA) == before + 1, flashes(wA))
	check("R2 premier flash bien avant la casse en solo (6,5 s)", NOW - t0 < 6.5)
	-- R4. La casse le fait fuir.
	breakWindow(alice, sA)
	local after = infoOf(sA, wA)
	check("R4 vitrine cassée : il fuit, photos arrêtées", after.Snapping == false and stateOf(wA) == "Stroll" and not playing(wA, "TakePhoto") and playing(wA, "Flee"))
end

-- R3, R5. Sans TakePhoto ni course : Walk accélérée, Look et flash tout de suite, puis toutes les Interval s ; « ? » plein.
do
	rootOf(alice.Character).Position = vec(400, 3, -45)
	hit(alice, sB)
	check("R3 sans Flee : la marche, à RushSpeed", playing(wB, "Walk") and wB.Humanoid.WalkSpeed >= PHOTO.RushSpeed, wB.Humanoid.WalkSpeed)
	untilPosted(sB, wB, 4)
	advance(Witness.StepInterval + 0.05) -- le pas suivant de la boucle
	check("R3 arrivé : Look, Snapping, un flash au pas suivant", infoOf(sB, wB).Snapping == true and playing(wB, "Look") and flashes(wB) == 1, flashes(wB))
	advance(PHOTO.Interval + 0.05)
	check("R3 un flash de plus après Interval s", flashes(wB) == 2, flashes(wB))
	-- Coups répétés : la pente ne change pas, il continue.
	hit(alice, sB)
	check("R3 un coup de plus : toujours en photo", infoOf(sB, wB).Snapping == true)
	advance(Witness.FillTime)
	check("R5 « ? » plein : il appelle (Call), photos rangées", stateOf(wB) == "Call" and infoOf(sB, wB).Snapping == false and playing(wB, "CallPolice"), stateOf(wB))
	advance(Witness.CallDuration + 0.1)
	check("R5 l'appel fini : il filme (L-172)", infoOf(sB, wB).Filming == true, stateOf(wB))
end

-- R6. Très loin : plafond ApproachMaxSpeed.
do
	rootOf(alice.Character).Position = vec(800, 3, -45)
	hit(alice, sC)
	check("R6 très loin : plafond ApproachMaxSpeed", wC.Humanoid.WalkSpeed == PHOTO.ApproachMaxSpeed, wC.Humanoid.WalkSpeed)
end
check("R7 aucune erreur dans la boucle", not hasLog("erreur"))

print(`banc a221 witness : {CHECKS} vérification(s), {FAILS} échec(s)`)
