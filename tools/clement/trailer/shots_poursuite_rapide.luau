--!nocheck
-- Poursuites à la vraie vitesse du jeu (Clément, 27/11 : « ça doit être une vraie poursuite rapide, on dirait qu'ils sont
-- au ralenti »). Remplace poursuite_z4, B_poursuite_face et B_mythique (même scène : rue de la Banque, zone 6, vers -x).
-- Charger après shots_banque.luau (et shots_pieds.luau pour le contrôle des pieds).
--   - vitesses lues dans Config/Zones, zone 4 (demande du Chef de projet) : joueur AdvisedSpeed (~68 studs/s),
--     vigile GuardSpeed (~63 studs/s) ; le vigile perd donc ~5 studs/s sur le héros, comme en jeu ;
--   - Run lue à v / (20 × échelle du modèle), la référence des vigiles en jeu (GuardService, GAIT_REFERENCE.Run = 20) :
--     la foulée suit la vitesse et les pieds ne glissent pas ;
--   - caméra qui suit de près (lissage court : à 68 studs/s, un lag de 0,1 s laisserait 7 studs de retard), secousse
--     d'épaule rapide (M.handheld) ; aucun ralenti : 60 états par seconde de plan, lecture à ×1.
-- Trajet : 3,6 s × 68 ≈ 245 studs, de x = 806 (devant la Banque) à x ≈ 561 ; rue dégagée à hauteur d'homme
-- (vérifié au rayon le 27/11, sol à y = 0), on passe la porte ouverte de la zone 6 (x = 718).
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def and L.BANQUE, "charger trailer_lib, shots_lancement, shots_inspi_allees puis shots_banque d'abord")
local V = Vector3.new
local M = T.moves
local def = L.def
local RS = game:GetService("ReplicatedStorage")
local Zones = require(RS.Shared.Config.Zones)

local ZONE = 4
local HERO_V = Zones[ZONE].AdvisedSpeed -- 67,9
local GUARD_V = Zones[ZONE].GuardSpeed -- 63,2
local RUN_REF = 20 -- studs/s pour lesquels Run est faite (échelle 1)
local DUR = 3.6
local D6 = V(376, 0, 0)
local GUARD6 = "guard:Guard_Z6"
local X0, ZH, ZG, GAP = 430, 44, 40.5, 6 -- départ du héros (avant décalage D6), couloirs du héros et du vigile, avance

local P = { { 0, V(X0, 0, ZH) + D6 }, { DUR, V(X0 - HERO_V * DUR, 0, ZH) + D6 } }
local G = { { 0, V(X0 + GAP, 0, ZG) + D6 }, { DUR, V(X0 + GAP - GUARD_V * DUR, 0, ZG) + D6 } }
L.CHASE_SPEEDS = { hero = HERO_V, guard = GUARD_V, zone = ZONE }

local function runSpeed(a, v)
	local s = 1
	pcall(function() s = a.model:GetScale() end)
	return v / (RUN_REF * s)
end

local function setup(itemId, scale)
	return function(S)
		for _, z in workspace.Map:GetChildren() do
			local w = z:FindFirstChild("Witnesses")
			if w and (z.Name == "Zone_6") then L.hide(w) end
		end
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		if itemId then
			L.carry(p, "ITM_" .. itemId, scale)
			L.itemLabelFor(p.carried.model, itemId, false)
		else
			L.carry(p, "ITM_Z4_Couronne", 2.4)
			L.itemLabel(p.carried.model, false)
		end
		p:follow(P, 0)
		p:play("Run", { fade = 0, speed = runSpeed(p, HERO_V) })
		p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z6", GUARD6)
		S.actors.g1 = g
		g:follow(G, 0)
		g:play("Run", { fade = 0, speed = runSpeed(g, GUARD_V) })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
		-- vitesse mesurée pendant la prise (studs/s au sol), rendue par L.chaseReport
		S.chase = { p0 = nil, g0 = nil }
	end
end
local function updater(name)
return function(S, t)
	S.actors.p1:follow(P, t)
	S.actors.g1:follow(G, t)
	local c = S.chase
	local pp, gp = S.actors.p1.model:GetPivot().Position, S.actors.g1.model:GetPivot().Position
	if t >= 0.2 and not c.p0 then c.p0, c.g0, c.t0 = pp, gp, t end
	if c.p0 and t > c.t0 then
		c.hero = ((pp - c.p0) * V(1, 0, 1)).Magnitude / (t - c.t0)
		c.guard = ((gp - c.g0) * V(1, 0, 1)).Magnitude / (t - c.t0)
		L.chaseMeasured = L.chaseMeasured or {}
		L.chaseMeasured[name] = { hero = c.hero, guard = c.guard }
	end
end
end
local function shaky(move, seed)
	return M.handheld(move, { amp = 0.16, look = 0.32, freq = 2.4, seed = seed })
end

-- de face, bas, devant le héros (comme avant, plus près)
def("poursuite_z4", {
	dur = DUR,
	cam = function() return shaky(M.follow({ actor = "p1", offset = V(5.5, -0.6, -10.5), offsetTo = V(4.5, -0.8, -8), dur = DUR, ease = "sine", lookOffset = V(3, 2.4, 3), lag = 0.03, fov = 60 }), 3) end,
	setup = setup(nil), update = updater("poursuite_z4"),
})
for _, f in { "h", "v" } do
	local sh = T.shots["L_poursuite_z4_" .. f]
	if sh then sh.tilt = function(t) return 4.5 * math.sin(math.pi * t / 1.8) end end
end
-- de trois-quarts face côté rue, le vigile visible derrière
def("B_poursuite_face", {
	dur = DUR,
	cam = function() return shaky(M.follow({ actor = "p1", offset = V(-7, 2.0, -4.5), offsetTo = V(-5.5, 1.8, -3.5), dur = DUR, ease = "sine", lookOffset = V(4, 2.8, -1), lag = 0.03, fov = 58 }), 5) end,
	setup = setup(nil), update = updater("B_poursuite_face"),
})
def("B_mythique", {
	dur = DUR,
	cam = function() return shaky(M.follow({ actor = "p1", offset = V(4.5, 1.0, -9), offsetTo = V(3.5, 0.9, -7), dur = DUR, ease = "sine", lookOffset = V(1, 3.4, 2), lag = 0.03, fov = 58 }), 8) end,
	setup = setup("Z6_CerveauDore", 2.4), update = updater("B_mythique"),
})

------------------------------------------------------------------------------------------------
-- La sortie de la Bijouterie et la hola (zone 4, Los Angeles) à la vitesse du jeu. Le héros sort par la porte
-- (461,5 ; 57), rejoint la chaussée (z = 38,5) en 0,5 s, puis file vers -x à 68 studs/s ; le vigile Guard_Z4 sort
-- 0,4 s après lui et court à 63 studs/s. Foule plus dense (24 personnes sur deux rangs, x = 452 à 375) : à cette
-- vitesse le héros la longe en un peu plus d'une seconde ; chacun lève les bras quand il arrive à 8 studs.
-- Rue et trottoir dégagés de x = 457 à 270 (rayons du 27/11), sol à y = 0.
------------------------------------------------------------------------------------------------
local Assets = RS.Assets
local function store(name) local x = workspace.Map:FindFirstChild(name, true) assert(x, "introuvable : " .. name) return x end
local function hideAllWitnesses()
	for _, z in workspace.Map:GetChildren() do
		local w = z:FindFirstChild("Witnesses")
		if w then L.hide(w) end
	end
end
local function crowdActor(id, modelName)
	local existing = T.cast[id]
	if existing and existing.model.Parent then return existing end
	local src = Assets.Crowd.Models:FindFirstChild(modelName)
	assert(src, modelName)
	local folder = T.root():FindFirstChild("Actors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Actors"
		folder.Parent = T.root()
	end
	local m = src:Clone()
	m.Name = id
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	m.Parent = folder
	return T.actor(id, "witness:" .. modelName)
end
local SEQ_END = 6
local HZ4 = { { 0, V(461.5, 0.5, 57) }, { 0.45, V(461.5, 0.5, 57) }, { 0.7, V(460.5, 0, 47) }, { 0.95, V(457.5, 0, 38.5) },
	{ SEQ_END, V(457.5 - HERO_V * (SEQ_END - 0.95), 0, 38.5) } }
local GZ4 = { { 0, V(461.5, 0.5, 62) }, { 0.85, V(461.5, 0.5, 60) }, { 1.1, V(461, 0.5, 52) }, { 1.3, V(460.5, 0, 45) },
	{ 1.45, V(457.5, 0, 40) }, { SEQ_END, V(457.5 - GUARD_V * (SEQ_END - 1.45), 0, 40) } }
local function heroX(t)
	local k = HZ4
	for i = 1, #k - 1 do
		if t <= k[i + 1][1] then
			local u = (t - k[i][1]) / (k[i + 1][1] - k[i][1])
			return k[i][2]:Lerp(k[i + 1][2], u).X
		end
	end
	return k[#k][2].X
end
local function z4Setup(S)
	hideAllWitnesses()
	local door = store("STORE_Z4_Bijouterie"):FindFirstChild("Door", true)
	if door then L.hide(door) end
	local p = L.fresh("voleur", "bacon")
	S.actors.p1 = p
	L.carry(p, "ITM_Z4_Couronne", 2.4)
	L.itemLabel(p.carried.model, false)
	p:follow(HZ4, 0)
	p:play("Run", { fade = 0, speed = runSpeed(p, HERO_V) })
	p:play("CarryRun", { fade = 0 })
	local g = L.fresh("vigile_z4", "guard:Guard_Z4")
	S.actors.g1 = g
	g:follow(GZ4, 0)
	g:play("Run", { fade = 0, speed = runSpeed(g, GUARD_V) })
	L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	S.crowd = {}
	for i = 1, 24 do
		local row = i % 2
		local x = 452 - (i - 1) * 3.3 + row * 1.1
		local c = crowdActor("hola" .. i, ("NPC_Crowd_%02d"):format((i - 1) % 12 + 1))
		c:stopAll()
		c:place(V(x, 0, 44.3 + row * 1.6 + ((i // 2) % 2) * 0.4), V(0, 0, -1))
		L.toVisibleGround(c)
		S.crowd[i] = { a = c, x = x }
		S.actors["h" .. i] = c -- déclarée dans le plan, sinon le moteur la range sous la carte
	end
	S.chase = {}
end
local function z4Updater(name, offset)
	return function(S, t)
		local tt = t + offset
		S.actors.p1:follow(HZ4, tt)
		S.actors.g1:follow(GZ4, tt)
		local hx = heroX(tt)
		for _, c in S.crowd do
			if not c.up and hx <= c.x + 8 then
				c.up = true
				c.a:play("Cheer", { fade = 0.08, looped = true })
			end
		end
		-- mesure pendant la course en ligne droite seulement
		local cc = S.chase
		local pp, gp = S.actors.p1.model:GetPivot().Position, S.actors.g1.model:GetPivot().Position
		if tt >= 1.0 and not cc.p0 then cc.p0, cc.t0 = pp, tt end
		if tt >= 1.5 and not cc.g0 then cc.g0, cc.tg = gp, tt end
		L.chaseMeasured = L.chaseMeasured or {}
		local m = L.chaseMeasured[name] or {}
		if cc.p0 and tt > cc.t0 then m.hero = ((pp - cc.p0) * V(1, 0, 1)).Magnitude / (tt - cc.t0) end
		if cc.g0 and tt > cc.tg then m.guard = ((gp - cc.g0) * V(1, 0, 1)).Magnitude / (tt - cc.tg) end
		L.chaseMeasured[name] = m
	end
end
-- 2a. la sortie : la caméra glisse à gauche devant la porte ; le héros jaillit et file, le vigile derrière
def("S_z4_sortie", {
	dur = 3,
	cam = function() return shaky(M.travelling({ from = V(476, 5.2, 26), look = V(459, 6.2, 50), dir = "gauche", dist = 4, dur = 3, ease = "linear", fov = 60 }), 11) end,
	setup = z4Setup, update = z4Updater("S_z4_sortie", 0),
})
-- 2b. vue de la rue, la foule derrière qui lève les bras sur son passage
def("S_z4_hola_cote", {
	dur = 3,
	cam = function() return shaky(M.follow({ actor = "p1", offset = V(13, 1.8, -3), offsetTo = V(13, 1.8, -1.5), dur = 3, ease = "linear", lookOffset = V(0, 2.6, 0), lag = 0.03, fov = 56 }), 12) end,
	setup = z4Setup, update = z4Updater("S_z4_hola_cote", 0.8),
})
-- 2c. de face, en reculant devant le héros : le vigile derrière, la vague de la foule qui le suit
def("S_z4_hola_face", {
	dur = 3,
	cam = function() return shaky(M.follow({ actor = "p1", offset = V(3, 1.4, -11), offsetTo = V(2.5, 1.2, -8.5), dur = 3, ease = "sine", lookOffset = V(1.5, 3.4, 6), lag = 0.03, fov = 60 }), 13) end,
	setup = z4Setup, update = z4Updater("S_z4_hola_face", 0.9),
})

------------------------------------------------------------------------------------------------
-- Le vigile surgit du fond de la Banque (zone 6) : il crie au fond, puis fonce vers la caméra à 63 studs/s et pile
-- devant la vitrine.
------------------------------------------------------------------------------------------------
local G12 = { { 0, V(445, 0, 96) + D6 }, { 0.9, V(445, 0, 95) + D6 }, { 0.9 + 36 / GUARD_V, V(443, 0, 59) + D6 }, { 1.75, V(443, 0, 56.5) + D6 } }
def("vigile_surgit", {
	dur = 2.6,
	cam = function() return shaky(M.travelling({ from = V(441, 2.6, 40) + D6, look = V(443, 4.5, 75) + D6, dir = "avant", dist = 3, dur = 2.6, ease = "linear", fov = 48 }), 14) end,
	setup = function(S)
		local bank = store("STORE_Z6_Banque")
		L.hide(bank:FindFirstChild("Window"))
		local z = workspace.Map:FindFirstChild("Zone_6")
		if z and z:FindFirstChild("Witnesses") then L.hide(z.Witnesses) end
		local g = L.fresh("vigile_z6", GUARD6)
		S.actors.g1 = g
		g:follow(G12, 0)
		g:play("Idle", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
		S.chase = {}
	end,
	update = function(S, t)
		local g = S.actors.g1
		g:follow(G12, t)
		if t >= 0.85 and not S._run then S._run = true g:stop("Idle", 0.05) g:play("Run", { fade = 0.05, speed = runSpeed(g, GUARD_V) }) end
		if t >= 1.7 and not S._halt then S._halt = true g:stop("Run", 0.12) g:play("Idle", { fade = 0.12 }) end
		local gp = g.model:GetPivot().Position
		if t >= 1.0 and not S.chase.g0 then S.chase.g0, S.chase.t0 = gp, t end
		if S.chase.g0 and t <= 1.45 and t > S.chase.t0 then
			L.chaseMeasured = L.chaseMeasured or {}
			L.chaseMeasured.vigile_surgit = { guard = ((gp - S.chase.g0) * V(1, 0, 1)).Magnitude / (t - S.chase.t0) }
		end
	end,
})

------------------------------------------------------------------------------------------------
-- B v2, l'arrivée avec la couronne à la ligne safe (x ≈ 24) à la vitesse du héros : il arrive du couloir à 68 studs/s,
-- freine sur 8 studs, s'arrête à x = 10 et fait la joie ; le vigile (×1,5) le talonne à 63 studs/s et pile à la ligne.
-- Chemin dégagé de x = 181 à 10 (seule la SafeZone, un volume transparent).
------------------------------------------------------------------------------------------------
do
	local CDUR = 5
	local TB, XB = 2.25, 18 -- fin de la course à pleine vitesse
	local HX0 = XB + HERO_V * TB
	local HP = { { 0, V(HX0, 0, 3) }, { TB, V(XB, 0, 3) }, { TB + 0.2, V(10, 0, 3) } }
	local GX0 = HX0 + 10
	local TG = (GX0 - 30) / GUARD_V
	local GP = { { 0, V(GX0, 0, 4.5) }, { TG, V(30, 0, 4.5) }, { TG + 0.15, V(28.5, 0, 4.5) } }
	local TFX = (HX0 - 24) / HERO_V -- passage de la ligne
	local function once(S, key, t, at, fn) if t >= at and not S["_" .. key] then S["_" .. key] = true fn() end end
	def("B2_couronne", {
		dur = CDUR,
		cam = function() return M.path({ keys = { { 0, V(-6, 4.2, 12), V(40, 4.6, 3) }, { CDUR, V(-4, 5.2, 13), V(16, 5.6, 2) } }, ease = "sine", fov = 54 }) end,
		setup = function(S)
			L.hideHumans()
			local p = L.fresh("voleur", "bacon")
			S.actors.p1 = p
			local pl = Assets.Animations:FindFirstChild("Player")
			if L.JOY_ANIM and not (pl and pl:FindFirstChild(L.JOY_ANIM)) and not p.model:FindFirstChild("Animations") then
				local src = Assets.Crowd.Models.NPC_Crowd_01.Animations:FindFirstChild("Cheer")
				if src then
					local f = Instance.new("Folder")
					f.Name = "Animations"
					local c = src:Clone()
					c.Name = L.JOY_ANIM
					c.Parent = f
					f.Parent = p.model
				end
			end
			L.carry(p, "ITM_Z4_Couronne", 2.4)
			L.itemLabel(p.carried.model, false)
			p:follow(HP, 0)
			p:play("Run", { fade = 0, speed = runSpeed(p, HERO_V) })
			p:play("CarryRun", { fade = 0 })
			local g = L.fresh("vigile_z1", "guard:Guard_Z1")
			S.actors.g1 = g
			if L.GUARD_SCALE and L.GUARD_SCALE ~= 1 and not g._scaled then
				g.model:ScaleTo(g.model:GetScale() * L.GUARD_SCALE)
				g._scaled = true
			end
			g:follow(GP, 0)
			g:play("Run", { fade = 0, speed = runSpeed(g, GUARD_V) })
			L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
			S.chase = {}
		end,
		update = function(S, t)
			local p, g = S.actors.p1, S.actors.g1
			p:follow(HP, math.min(t, TB + 0.2))
			g:follow(GP, math.min(t, TG + 0.15))
			once(S, "fx", t, TFX, function()
				local name = if Assets.FX:FindFirstChild(L.ARRIVAL_FX, true) then L.ARRIVAL_FX else "FX_Escape"
				local m = L.prop("FX", name)
				m:PivotTo(CFrame.new(V(24, 3, 3)))
				for _, e in m:GetDescendants() do
					if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 10) end
				end
			end)
			once(S, "stop", t, TB + 0.2, function()
				p:stop("Run", 0.12)
				p:stop("CarryRun", 0.12)
				if L.JOY_ANIM then p:play(L.JOY_ANIM, { fade = 0.12, looped = true }) else p:play("CarryIdle", { fade = 0.12 }) end
			end)
			once(S, "gstop", t, TG + 0.15, function() g:stop("Run", 0.12) g:play("Idle", { fade = 0.12 }) end)
			local pp, gp = p.model:GetPivot().Position, g.model:GetPivot().Position
			if t >= 0.3 and not S.chase.p0 then S.chase.p0, S.chase.g0, S.chase.t0 = pp, gp, t end
			if S.chase.p0 and t <= 1.9 and t > S.chase.t0 then
				L.chaseMeasured = L.chaseMeasured or {}
				L.chaseMeasured.B2_couronne = { hero = ((pp - S.chase.p0) * V(1, 0, 1)).Magnitude / (t - S.chase.t0), guard = ((gp - S.chase.g0) * V(1, 0, 1)).Magnitude / (t - S.chase.t0) }
			end
		end,
	})
	L.B2_COURONNE_ARRIVEE = TB + 0.2
end

L.RAPIDE = { "L_poursuite_z4_h", "L_B_poursuite_face_h", "L_B_mythique_h", "L_S_z4_sortie_h", "L_S_z4_hola_cote_h", "L_S_z4_hola_face_h", "L_vigile_surgit_h", "L_B2_couronne_h" }
return ("poursuites rapides : héros %.1f studs/s, vigile %.1f studs/s (zone %d), %d plans"):format(HERO_V, GUARD_V, ZONE, #L.RAPIDE)
