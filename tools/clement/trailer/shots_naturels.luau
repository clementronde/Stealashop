--!nocheck
-- Série « plans naturels » des trailers (skill trailer-tiktok), demandée par Clément le 2026-11-25 : des joueurs qui
-- jouent vraiment (casse à plusieurs ou seul, colis, vol, vigiles qui attrapent et éjectent par la vitrine, vol entre
-- joueurs, propriétaire qui frappe le voleur, boutique pleine, foule), caméra à l'épaule (M.handheld), zooms lents et
-- caméra qui suit l'action (M.operator). À charger après trailer_lib.luau (version 2026-11-25). Ordre : T.ORDER_NATUREL.
-- Repères du couloir : voir shots.luau. Boutique 03 : porte vitrée en x = -161,5 (z de 31 à 49), présentoirs le long
-- des murs z = 16 et z = 64, plaques d'encaissement devant (z = 20,9 et 59,1), tapis en (-151,7 ; 15,4).
-- Magasins PNJ : vitrine de 18 studs en z = ±54,8, porte à gauche, rayons dès 23 studs derrière la vitrine.

local T = _G.Trailer
local V = Vector3.new
local M = T.moves
local FAR = CFrame.new(0, -1000, 0)

local function store(name: string): Model
	local s = workspace.Map:FindFirstChild(name, true)
	assert(s, "magasin introuvable : " .. name)
	return s
end

local function plot(n: number): Model
	return workspace.Map.Hub.Shops:FindFirstChild(("PLOT_Shop_%02d"):format(n))
end

-- Position d'un ShelfSlot (le colis y est tourné vers l'allée)
local function shelf(st: Model, i: number): Vector3
	return st:FindFirstChild(("ShelfSlot_%02d"):format(i), true).WorldPosition
end

local function once(S, key: string, t: number, at: number, fn)
	if t >= at and not S["_" .. key] then
		S["_" .. key] = true
		fn()
	end
end

-- Acteur de la troupe, remis à zéro pour ce plan (objet et outil retirés, animations arrêtées), avec son outil et
-- l'objet qu'il porte. La troupe passe d'un plan à l'autre : bacon1-2, jean1-2, guit1-2 (les trois bacon hair),
-- lav1, blond1, tress1, brune1 (tenues gratuites de Roblox), vigiles gz1a, gz2, gz3a, gz3b, gz4, gz6, témoins wit1-2.
local function cast(S, key: string, id: string, look: string, tool: string?, item: string?, scale: number?)
	local a = T.actor(id, look)
	a:reset()
	S.actors[key] = a
	if tool then T.fx.hold(a, tool) end
	if item then T.fx.carry(a, item, scale) end
	return a
end

-- Caméra à l'épaule
local function hand(move, amp: number?, seed: number?)
	local a = amp or 0.12
	return M.handheld(move, { amp = a, look = a * 2, freq = 0.55, seed = seed or 1 })
end

-- Coup : lance l'animation à `at` ; rend true à l'image de l'impact et pose S[key] = t (le marqueur Impact n'est pas
-- lu en Edit : impact à la fraction frac de l'animation, au plus tard at + late).
local function strike(S, key: string, t: number, a, anim: string, at: number, frac: number, late: number): boolean
	once(S, key .. "_go", t, at, function()
		S[key .. "_tr"] = a:play(anim, { looped = false, fade = 0.08 })
	end)
	local tr = S[key .. "_tr"]
	if tr and not S[key] and ((tr.Length > 0 and tr.TimePosition >= tr.Length * frac) or t >= at + late) then
		S[key] = t
		return true
	end
	return false
end

-- Garde la dernière pose d'une animation non bouclée (sinon le perso se relève tout seul à la fin).
local function holdEnd(tr, at: number?)
	if tr and tr.IsPlaying and tr.Length > 0 and tr.TimePosition >= tr.Length * (at or 0.95) then tr:AdjustSpeed(0) end
end

-- L'outil pend mal pendant la course : il le lâche.
local function dropTool(a)
	if a.held then
		a.held.model:Destroy()
		a.held = nil
	end
end

local function run(a, anim: string?)
	a:stop("Idle", 0.1)
	a:stop("Walk", 0.1)
	a:play(anim or "Run", { fade = 0.12 })
	if a.carried then a:play("CarryRun", { fade = 0.12 }) end
end

local function idle(a)
	for _, n in { "Run", "Walk", "Sprint", "CarryRun" } do a:stop(n, 0.15) end
	a:play("Idle", { fade = 0.15 })
	if a.carried then a:play("CarryIdle", { fade = 0.15 }) end
end

-- Vitrine déjà cassée : la vraie vitre cachée en local, ses éclats déjà retombés au sol (sans poussière).
local function broken(st: Model, normal: Vector3?)
	local f = T.fx.breakWindow(st, { speed = 0.35, fadeAt = 1e6, noBurst = true, normal = normal })
	for _ = 1, 120 do f.step(1 / 30) end
end

-- Boutique 03 pleine : 18 objets du catalogue actif (v2), un par présentoir (07 et 08 doublent 09 et 10 : laissés vides).
local SHOP = {
	"ITM_Z5_LaJoconde", "ITM_Z5_Sarcophage", "ITM_Z6_TroneEnOr", "ITM_Z4_Couronne", "ITM_Z3_PcGamer", "ITM_Z2_PelucheGeante",
	"ITM_Z6_PyramideDeLingots", "ITM_Z5_StatueDoree", "ITM_Z3_TeleGeante", "ITM_Z4_OeufEnDiamant", "ITM_Z5_ArmureDeChevalier",
	"ITM_Z2_TrainElectrique", "ITM_Z5_Meteorite", "ITM_Z3_CarteGraphiqueEnOr", "ITM_Z4_HorlogeDeParquet", "ITM_Z6_SceptreRoyal",
	"ITM_Z5_MasqueAncien", "ITM_Z2_RobotJouet",
}
local SHOP_SLOTS = { 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }
local function fullShop(S, stolen: { number }?)
	S.shop = T.fx.fillShop(S, plot(3), SHOP, SHOP_SLOTS)
	for _, k in stolen or {} do
		S.shop[k].hidden = true
		S.shop[k].model:PivotTo(FAR)
	end
end
-- échelle montrée de l'objet n de la boutique (le voleur le porte à la même taille)
local function shopScale(S, k: number): number
	return S.shop[k].model:GetScale()
end

local BOXES = { "BOX_Legendary", "BOX_Epic", "BOX_Mythic", "BOX_Rare", "BOX_Uncommon", "BOX_Epic", "BOX_Rare", "BOX_Legendary", "BOX_Common", "BOX_Secret" }
local JV = "STORE_Z3_JeuxVideo"
local JV1 = shelf(store(JV), 1) -- (300,9 ; 2,8 ; -77,5), colis tourné vers -x
local JV2 = shelf(store(JV), 2) -- (283,1 ; 2,8 ; -77,5), colis tourné vers +x
local FLAT = V(1, 0, 1)

------------------------------------------------------------------------------------------------
-- CASSE
------------------------------------------------------------------------------------------------

-- n01. Trois joueurs cassent la vitrine du Kiosque ensemble (batte, marteau, masse), entrent ; un témoin s'enfuit.
local K01 = { c1 = V(69.5, 0.4, -50.3), c2 = V(74.5, 0.4, -50.6), c3 = V(79.5, 0.4, -50.3) }
local IN01 = {
	c1 = { { 1.15, K01.c1 }, { 2.5, V(67, 0, -68) } },
	c2 = { { 1.3, K01.c2 }, { 2.7, V(74, 0, -72) } },
	c3 = { { 1.05, K01.c3 }, { 2.4, V(82, 0, -66) } },
}
local W01 = { { 0.9, V(93, 0.4, -51) }, { 3.5, V(120, 0.4, -50.5) } }
T.shots.n01_casse_trio = {
	dur = 3.5,
	slow = 2,
	-- rapprochée au repérage (à 17 studs, les casseurs étaient trop petits)
	cam = M.shake(hand(M.operator({ keys = { { 0, V(84, 2.5, -40) }, { 3.5, V(80, 2.9, -42.5) } }, targets = { "c1", "c2", "c3" }, lookOffset = V(0, 2.6, 0), lag = 0.45, fov = 54 }), 0.12, 2), { atKey = "breakAt", dur = 0.3, amp = 0.25 }),
	setup = function(S)
		cast(S, "c1", "bacon1", "bacon", "TOOL_Batte")
		cast(S, "c2", "jean1", "bacon_jean", "TOOL_Marteau")
		cast(S, "c3", "guit1", "bacon_guitare", "TOOL_Masse")
		for k, p in K01 do
			S.actors[k]:place(p, V(0, 0, -1))
			S.actors[k]:play("Idle", { fade = 0 })
		end
		local w = cast(S, "w", "wit1", "witness:NPC_Witness_Z1_01")
		w:place(W01[1][2], V(-1, 0, 0))
		w:play("Look", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		strike(S, "h1", t, A.c1, "HitWindow", 0.1, 0.4, 0.3)
		strike(S, "h2", t, A.c2, "HitWindow", 0.3, 0.4, 0.3)
		if t > 0.55 then strike(S, "h1b", t, A.c1, "HitWindow", 0.55, 0.4, 0.3) end
		if strike(S, "h3", t, A.c3, "HitWindowHeavy", 0.35, 0.45, 0.5) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z1_Kiosque"), { speed = 0.5 }))
		end
		for k, keys in IN01 do
			if t >= keys[1][1] then
				once(S, "run_" .. k, t, keys[1][1], function()
					dropTool(A[k])
					run(A[k])
				end)
				A[k]:follow(keys, t)
			end
		end
		once(S, "flee", t, 0.9, function()
			A.w:stop("Look", 0.1)
			A.w:play("Flee", { fade = 0.1 })
		end)
		if t >= 0.9 then A.w:follow(W01, t) end
	end,
}

-- n02. Par-dessus l'épaule : un joueur court vers la vitrine de la Superette, la casse à la batte et entre ; la caméra le suit dedans.
local P02 = { { 0, V(70.5, 0, 37) }, { 0.95, V(73.5, 0.4, 49.6) } }
local IN02 = { { 1.55, V(73.5, 0.4, 49.6) }, { 3.2, V(75, 0, 70) } }
T.shots.n02_casse_epaule = {
	dur = 3.2,
	slow = 2,
	cam = M.shake(hand(M.follow({ actor = "c", offset = V(2.4, 2.4, 7.5), offsetTo = V(1.8, 2.1, 5.2), dur = 1.0, lookOffset = V(0, 2.6, 0), lag = 0.15, fov = 56 }), 0.1, 3), { atKey = "breakAt", dur = 0.3, amp = 0.22 }),
	setup = function(S)
		local c = cast(S, "c", "bacon1", "bacon", "TOOL_Batte")
		c:follow(P02, 0)
		c:play("Run", { fade = 0 })
	end,
	update = function(S, t)
		local c = S.actors.c
		if t < 0.95 then c:follow(P02, t) end
		once(S, "stop", t, 0.95, function()
			c:place(P02[2][2], V(0, 0, 1))
			idle(c)
		end)
		if strike(S, "hit", t, c, "HitWindow", 0.95, 0.4, 0.3) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z1_Superette"), { speed = 0.5 }))
		end
		once(S, "in", t, 1.55, function()
			dropTool(c)
			run(c)
		end)
		if t >= 1.55 then c:follow(IN02, t) end
	end,
}

-- n03. Coup de masse sur la Bijouterie (zone 4), caméra basse de côté qui zoome sur l'impact.
T.shots.n03_casse_masse_zoom = {
	dur = 2.8,
	slow = 2,
	cam = M.shake(M.zoom(hand(M.travelling({ from = V(428, 1.5, 44), look = V(441, 4.8, 53.5), dir = "droite", dist = 3, dur = 2.8, ease = "linear", fov = 56 }), 0.08, 4), { to = 38, at = 0.3, dur = 0.7, ease = "outQuad" }), { atKey = "breakAt", dur = 0.35, amp = 0.3 }),
	setup = function(S)
		local c = cast(S, "c", "jean1", "bacon_jean", "TOOL_Masse")
		c:place(V(440.5, 0.4, 49.6), V(0, 0, 1))
		c:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		if strike(S, "hit", t, S.actors.c, "HitWindowHeavy", 0.4, 0.45, 0.5) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z4_Bijouterie"), { speed = 0.55 }))
		end
	end,
}

-- n04. Vu de l'intérieur du Kiosque : la hache casse la vitrine, les éclats volent vers nous, le casseur entre ; un autre arrive en courant.
local P04 = { { 1.25, V(73, 0.4, -50.6) }, { 2.1, V(70.5, 0, -62) }, { 3, V(68, 0, -71) } }
local Q04 = { { 0, V(62, 0, -28) }, { 1.6, V(71.5, 0.4, -49.6) }, { 2.0, V(71.5, 0.4, -49.6) }, { 3, V(72.5, 0, -58) } }
T.shots.n04_casse_vue_dedans = {
	dur = 3,
	slow = 2,
	cam = M.shake(hand(M.travelling({ from = V(74.5, 3.8, -60.5), look = V(73.5, 4.6, -52), dir = "arriere", dist = 2.5, dur = 3, ease = "linear", fov = 54 }), 0.1, 5), { atKey = "breakAt", dur = 0.3, amp = 0.2 }),
	setup = function(S)
		local c = cast(S, "c", "brune1", "brune", "TOOL_HacheDIncendie")
		c:place(P04[1][2], V(0, 0, -1))
		c:play("Idle", { fade = 0 })
		local p = cast(S, "p", "blond1", "blond")
		p:follow(Q04, 0)
		p:play("Run", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		if strike(S, "hit", t, A.c, "HitWindowHeavy", 0.35, 0.45, 0.5) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z1_Kiosque"), { speed = 0.4, normal = V(0, 0, -1), fadeAt = 0.6, fadeDur = 0.5 }))
		end
		once(S, "in", t, 1.25, function()
			dropTool(A.c)
			run(A.c)
		end)
		if t >= 1.25 then A.c:follow(P04, t) end
		A.p:follow(Q04, t)
		once(S, "pstop", t, 1.6, function() idle(A.p) end)
		once(S, "pin", t, 2.0, function() run(A.p) end)
	end,
}

-- n05. Vol entre joueurs : un joueur casse la porte vitrée de la boutique 03 (pleine) au pied-de-biche et fonce vers un présentoir.
local P05 = { { 1.0, V(-157.6, 0, 40.5) }, { 1.6, V(-165, 0, 35) }, { 2.4, V(-168, 0, 20.5) } }
T.shots.n05_casse_porte_boutique = {
	dur = 3,
	slow = 2,
	cam = M.shake(hand(M.operator({ keys = { { 0, V(-144, 3, 52) }, { 3, V(-149, 2.8, 47.5) } }, targets = { "c" }, lookOffset = V(0, 2.4, 0), lag = 0.35, fov = 52 }), 0.12, 6), { atKey = "breakAt", dur = 0.3, amp = 0.22 }),
	setup = function(S)
		fullShop(S)
		local c = cast(S, "c", "tress1", "tresses", "TOOL_PiedDeBiche")
		c:place(P05[1][2], V(-1, 0, 0))
		c:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		local c = S.actors.c
		T.fx.bob(S.shop, t)
		if strike(S, "hit", t, c, "HitWindow", 0.3, 0.4, 0.3) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(plot(3).PlotDoor, { speed = 0.5 }))
		end
		once(S, "in", t, 1.0, function()
			dropTool(c)
			run(c)
		end)
		if t >= 1.0 then c:follow(P05, t) end
	end,
}

------------------------------------------------------------------------------------------------
-- MAGASIN PNJ : COLIS ET VOL
------------------------------------------------------------------------------------------------

-- n06. Allée des Jeux vidéo (zone 3), rayons garnis de colis : un joueur passe, deux autres ouvrent des colis.
T.shots.n06_rayons_colis = {
	dur = 3.5,
	slow = 2,
	cam = hand(M.travelling({ from = V(292, 3.6, -60), look = V(292, 3, -100), dir = "avant", dist = 9, dur = 3.5, ease = "linear", fov = 52 }), 0.1, 7),
	setup = function(S)
		T.fx.fillShelves(S, store(JV), BOXES, 1.25)
		local a = cast(S, "a", "lav1", "lavande")
		S.pa = { { 0, V(290.5, 0, -69) }, { 3.5, V(291.5, 0, -90) } } -- partait trop près de l'objectif
		a:follow(S.pa, 0)
		a:play("Walk", { fade = 0 })
		local b = cast(S, "b", "jean2", "bacon_jean")
		b:place(JV1 * FLAT + V(-2.6, 0.5, 0), V(1, 0, 0))
		b:play("Unbox_Crowbar", { fade = 0, looped = true })
		local c = cast(S, "c", "bacon2", "bacon")
		c:place(JV2 * FLAT + V(2.6, 0.5, 0), V(-1, 0, 0))
		c:play("Unbox_Kick", { fade = 0, looped = true })
	end,
	update = function(S, t)
		S.actors.a:follow(S.pa, t)
	end,
}

-- n07. Colis Légendaire ouvert au pied-de-biche, vu de profil : le PC gamer sort, le joueur le prend et part vers nous.
T.shots.n07_colis_profil = {
	dur = 3.6,
	slow = 2,
	-- de trois quarts face, le joueur décalé le long du rayon pour ne pas cacher le colis (repérage : de trois quarts dos
	-- il le cachait ; à x > 299 la caméra tombe dans le rayon)
	cam = M.zoom(hand(M.travelling({ from = JV1 + V(-4.2, 1.5, 8.5), look = JV1 + V(-1.2, 0.6, -0.6), dir = "avant", dist = 1.5, dur = 3.6, ease = "linear", fov = 50 }), 0.07, 8), { to = 42, at = 1.15, dur = 0.7, ease = "outQuad" }),
	setup = function(S)
		local boxes = T.fx.fillShelves(S, store(JV), BOXES, 1.25)
		S.box = boxes[1]
		local a = cast(S, "a", "bacon1", "bacon")
		local p = JV1 * FLAT + V(-2.4, 0.5, -1.6)
		a:place(p, V(1, 0, 0.55))
		a:play("Unbox_Crowbar", { fade = 0, looped = true })
		S.out = { { 2.9, p }, { 3.6, p + V(-3.6, 0, 8) } } -- passe à gauche de la caméra
		S.item = T.fx.prop(S, "n07_item", "Items", "ITM_Z3_PcGamer")
		S.item:PivotTo(FAR)
	end,
	update = function(S, t)
		local a = S.actors.a
		once(S, "open", t, 1.25, function()
			a:stop("Unbox_Crowbar", 0.1)
			a:play("Idle", { fade = 0.1 })
			S.box:PivotTo(FAR)
			T.fx.emit("FX_Unbox_Burst", CFrame.new(JV1 + V(0, 0.8, 0)))
			T.fx.emit("FX_Unbox_Reveal", CFrame.new(JV1 + V(0, 0.8, 0)))
		end)
		if t >= 1.25 and t < 2.3 then
			local u = math.clamp((t - 1.25) / 0.6, 0, 1)
			S.item:PivotTo(CFrame.new(JV1 + V(0, 0.4 + 1.8 * (1 - (1 - u) ^ 3), 0)) * CFrame.Angles(0, (t - 1.25) * 2.5, 0))
		end
		strike(S, "grab", t, a, "Grab", 2.0, 0.5, 0.4)
		once(S, "lift", t, 2.3, function()
			S.item:PivotTo(FAR)
			T.fx.carry(a, "ITM_Z3_PcGamer")
			a:play("CarryIdle", { fade = 0.1 })
		end)
		once(S, "go", t, 2.9, function() run(a) end)
		if t >= 2.9 then a:follow(S.out, t) end
	end,
}

-- n08. Le voleur sort en courant par la vitrine cassée des Jeux vidéo avec la télé géante, le vigile sur ses talons.
local P08 = { { 0, V(292, 0, -68) }, { 0.8, V(293, 0.4, -55) }, { 2.0, V(297, 0, -36) }, { 3.0, V(300, 0, -21) } }
local G08 = { { 0, V(290.5, 0, -78) }, { 1.45, V(292, 0.4, -55) }, { 2.6, V(296, 0, -38) }, { 3.0, V(297.5, 0, -31) } }
T.shots.n08_sortie_vitrine = {
	dur = 3,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(301.5, 2.2, -30) }, { 3, V(303.5, 2.6, -22) } }, targets = { "p", "g" }, lookOffset = V(0, 2.4, 0), lag = 0.3, fov = 54 }), 0.14, 9),
	setup = function(S)
		broken(store(JV))
		local p = cast(S, "p", "guit1", "bacon_guitare", nil, "ITM_Z3_TeleGeante", 1.4)
		p:follow(P08, 0)
		run(p)
		local g = cast(S, "g", "gz3a", "guard:Guard_Z3")
		g:follow(G08, 0)
		g:play("Sprint", { fade = 0 })
	end,
	update = function(S, t)
		S.actors.p:follow(P08, t)
		S.actors.g:follow(G08, t)
	end,
}

------------------------------------------------------------------------------------------------
-- VIGILES
------------------------------------------------------------------------------------------------

-- n09. Londres : le vigile rattrape le voleur (peluche géante), l'attrape ; l'objet tombe, le voleur est arrêté.
local P09 = { { 0, V(150, 0, -12) }, { 1.55, V(176, 0, -12) } }
local G09 = { { 0, V(134, 0, -13) }, { 1.5, V(173, 0, -12.6) } }
T.shots.n09_vigile_attrape = {
	dur = 3.4,
	slow = 2,
	cam = M.zoom(hand(M.operator({ keys = { { 0, V(151, 3, 4) }, { 3.4, V(171, 3.2, 5) } }, targets = { "p", "g" }, lookOffset = V(0, 2.2, 0), lag = 0.35, fov = 52 }), 0.12, 10), { to = 42, at = 1.45, dur = 0.9, ease = "sine" }),
	setup = function(S)
		local p = cast(S, "p", "blond1", "blond", nil, "ITM_Z2_PelucheGeante")
		p:follow(P09, 0)
		run(p)
		local g = cast(S, "g", "gz2", "guard:Guard_Z2")
		g:follow(G09, 0)
		g:play("Sprint", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		if t < 1.55 then A.p:follow(P09, t) end
		if t < 1.5 then A.g:follow(G09, t) end
		once(S, "catch", t, 1.45, function()
			A.g:stop("Sprint", 0.1)
			A.g:play("Catch", { looped = false, fade = 0.08 })
		end)
		once(S, "caught", t, 1.6, function()
			T.fx.drop(S, A.p, V(9, 12, 1))
			A.p:stop("Run", 0.1)
			A.p:stop("CarryRun", 0.1)
			S.arr = A.p:play("Arrested", { looped = false, fade = 0.1 })
		end)
		holdEnd(S.arr)
		once(S, "gidle", t, 2.75, function() A.g:play("Idle", { fade = 0.2 }) end)
	end,
}

-- n10. Los Angeles : plaquage du vigile, le voleur tombe en avant, la couronne roule ; le vigile va la ramasser.
local P10 = { { 0, V(398, 0, -9) }, { 1.3, V(421, 0, -6) } }
local G10 = { { 0, V(386, 0, -10) }, { 1.2, V(418, 0, -6.4) } }
local G10b = { { 2.0, V(418, 0, -6.4) }, { 2.6, V(426, 0, -4.8) } }
T.shots.n10_vigile_plaquage = {
	dur = 3.2,
	slow = 2,
	cam = M.shake(hand(M.operator({ keys = { { 0, V(433, 1.6, 6) }, { 3.2, V(435, 1.9, 2.5) } }, targets = { "p", "g" }, lookOffset = V(0, 1.6, 0), lag = 0.3, fov = 50 }), 0.1, 11), { atKey = "hitAt", dur = 0.3, amp = 0.2 }),
	setup = function(S)
		local p = cast(S, "p", "jean2", "bacon_jean", nil, "ITM_Z4_Couronne", 1.6)
		p:follow(P10, 0)
		run(p)
		local g = cast(S, "g", "gz4", "guard:Guard_Z4")
		g:follow(G10, 0)
		g:play("Sprint", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		if t < 1.3 then A.p:follow(P10, t) end
		if t < 1.2 then A.g:follow(G10, t) end
		once(S, "catch", t, 1.1, function()
			A.g:stop("Sprint", 0.1)
			A.g:play("Catch", { looped = false, fade = 0.08 })
		end)
		once(S, "hit", t, 1.3, function()
			S.hitAt = t
			T.fx.drop(S, A.p, V(11, 11, 2))
			A.p:stop("Run", 0.08)
			A.p:stop("CarryRun", 0.08)
			S.kd = A.p:play("Knockdown", { looped = false, fade = 0.06 })
		end)
		if S.hitAt then
			local u = (t - 1.3) / 0.45
			if u <= 1 then A.p:flyAt(V(421, 0, -6), V(426, 0, -5), 1.0, u, V(1, 0, 0.2), 0) end
		end
		holdEnd(S.kd)
		once(S, "gwalk", t, 2.0, function() A.g:play("Walk", { fade = 0.15 }) end)
		if t >= 2.0 and t < 2.6 then A.g:follow(G10b, t) end
		once(S, "pick", t, 2.6, function()
			A.g:stop("Walk", 0.1)
			A.g:play("PickUp", { looped = false, fade = 0.1 })
		end)
	end,
}

-- n11. Le vigile attrape le voleur dans l'Horlogerie et l'éjecte À TRAVERS la vitrine : il vole dans la rue, l'œuf en diamant aussi.
local P11 = { { 0, V(440, 0, -72) }, { 0.78, V(441, 0, -59) } }
local G11 = { { 0, V(439, 0, -80) }, { 0.7, V(440.5, 0, -62.5) } }
local G11b = { { 1.6, V(440.5, 0, -62.5) }, { 2.4, V(441, 0, -57) } }
local FLY11 = { V(441, 0, -59), V(443.5, 0.4, -42) }
T.shots.n11_ejecte_vitrine = {
	dur = 3.4,
	slow = 2,
	cam = M.shake(hand(M.operator({ keys = { { 0, V(450.5, 2.2, -38) }, { 3.4, V(449.5, 2.5, -40.5) } }, targets = { "p" }, lookOffset = V(0, 1.4, 0), lag = 0.16, fov = 54 }), 0.12, 12), { atKey = "breakAt", dur = 0.35, amp = 0.35 }),
	setup = function(S)
		local p = cast(S, "p", "bacon2", "bacon", nil, "ITM_Z4_OeufEnDiamant", 1.8)
		p:follow(P11, 0)
		run(p)
		local g = cast(S, "g", "gz4", "guard:Guard_Z4")
		g:follow(G11, 0)
		g:play("Sprint", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		if t < 0.78 then A.p:follow(P11, t) end
		if t < 0.7 then A.g:follow(G11, t) end
		once(S, "catch", t, 0.55, function()
			A.g:stop("Sprint", 0.08)
			A.g:play("Catch", { looped = false, fade = 0.06 })
		end)
		once(S, "launch", t, 0.78, function()
			T.fx.drop(S, A.p, V(1.5, 9, 17))
			A.p:stop("Run", 0.05)
			A.p:stop("CarryRun", 0.05)
			S.kb = A.p:play("Knockback", { looped = false, fade = 0.05 })
		end)
		if t >= 0.78 then
			local u = (t - 0.78) / 0.62
			if u <= 1 then A.p:flyAt(FLY11[1], FLY11[2], 3.2, u, V(0, 0, -1), 35) end
			if not S.breakAt and u >= 0.18 then
				S.breakAt = t
				table.insert(S.fx, T.fx.breakWindow(store("STORE_Z4_Horlogerie"), { speed = 0.9, fadeAt = 1.1, fadeDur = 0.8 }))
			end
		end
		holdEnd(S.kb)
		once(S, "gwalk", t, 1.6, function() A.g:play("Walk", { fade = 0.15 }) end)
		if t >= 1.6 and t < 2.4 then A.g:follow(G11b, t) end
		once(S, "gidle", t, 2.4, function()
			A.g:stop("Walk", 0.15)
			A.g:play("Idle", { fade = 0.15 })
		end)
	end,
}

-- n12. Tokyo : trois voleurs chargés foncent vers nous, deux vigiles derrière ; la caméra recule devant eux, au ras du sol.
local R12 = {
	t1 = { { 0, V(330, 0, -6) }, { 3.2, V(280, 0, -6) } },
	t2 = { { 0, V(335, 0, 5) }, { 3.2, V(284, 0, 4.5) } },
	t3 = { { 0, V(339, 0, -14) }, { 3.2, V(288, 0, -13) } },
	g1 = { { 0, V(346, 0, -3) }, { 3.2, V(292, 0, -3.5) } },
	g2 = { { 0, V(351, 0, 9) }, { 3.2, V(297, 0, 8) } },
}
T.shots.n12_poursuite_groupe = {
	dur = 3.2,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(314, 2.3, -1.5) }, { 3.2, V(270, 2.9, -1.5) } }, targets = { "t1", "t2", "t3", "g1" }, lookOffset = V(0, 2.4, 0), lag = 0.3, fov = 54 }), 0.14, 13),
	setup = function(S)
		cast(S, "t1", "bacon1", "bacon", nil, "ITM_Z3_PcGamer")
		cast(S, "t2", "lav1", "lavande", nil, "ITM_Z3_TeleGeante", 1.4)
		cast(S, "t3", "jean1", "bacon_jean", nil, "ITM_Z3_ConsoleDeSalon", 1.8)
		cast(S, "g1", "gz3a", "guard:Guard_Z3")
		cast(S, "g2", "gz3b", "guard:Guard_Z3")
		for k, keys in R12 do
			local a = S.actors[k]
			a:follow(keys, 0)
			if a.kind == "guard" then a:play("Sprint", { fade = 0 }) else run(a) end
		end
	end,
	update = function(S, t)
		for k, keys in R12 do S.actors[k]:follow(keys, t) end
	end,
}

-- n13. New York : le vigile abandonne, essoufflé, pendant que le voleur file au loin avec la pyramide de lingots.
local G13 = { { 0, V(756, 0, -4) }, { 1.0, V(776, 0, -4.5) } }
local P13 = { { 0, V(782, 0, -4) }, { 3.4, V(842, 0, -2) } }
T.shots.n13_vigile_essouffle = {
	dur = 3.4,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(748, 2.4, 2.5) }, { 1.2, V(764, 2.8, 3.5) }, { 3.4, V(768, 3, 3.6) } }, targets = { "g", "p" }, lookOffset = V(0, 2.2, 0), lag = 0.3, fov = 48 }), 0.1, 14),
	setup = function(S)
		local g = cast(S, "g", "gz6", "guard:Guard_Z6")
		g:follow(G13, 0)
		g:play("Sprint", { fade = 0 })
		local p = cast(S, "p", "tress1", "tresses", nil, "ITM_Z6_PyramideDeLingots")
		p:follow(P13, 0)
		run(p)
	end,
	update = function(S, t)
		local A = S.actors
		if t < 1.0 then A.g:follow(G13, t) end
		A.p:follow(P13, t)
		once(S, "tired", t, 1.0, function()
			A.g:stop("Sprint", 0.2)
			A.g:play("Tired", { looped = false, fade = 0.2 })
		end)
	end,
}

------------------------------------------------------------------------------------------------
-- ENTRE JOUEURS (boutique 03 pleine, porte cassée)
------------------------------------------------------------------------------------------------

-- n14. Le voleur entre par la porte cassée, prend La Joconde sur le présentoir 01 et ressort en courant.
local P14a = { { 0, V(-163.5, 0, 33) }, { 0.8, V(-168, 0, 19.8) } }
local P14b = { { 1.5, V(-168, 0, 19.8) }, { 2.1, V(-164, 0, 30) }, { 2.7, V(-158, 0, 41) }, { 3.0, V(-151, 0, 45) } }
T.shots.n14_vol_presentoir = {
	dur = 3,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(-177, 3.4, 30) }, { 3, V(-173, 3.1, 33) } }, targets = { "p" }, lookOffset = V(0, 1.8, 0), lag = 0.3, fov = 54 }), 0.1, 15),
	setup = function(S)
		fullShop(S)
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "jean1", "bacon_jean")
		p:follow(P14a, 0)
		run(p)
	end,
	update = function(S, t)
		local p = S.actors.p
		T.fx.bob(S.shop, t)
		if t < 0.8 then p:follow(P14a, t) end
		once(S, "stop", t, 0.8, function()
			p:place(P14a[2][2], V(0, 0, -1))
			idle(p)
		end)
		strike(S, "grab", t, p, "Grab", 0.8, 0.5, 0.4)
		once(S, "lift", t, 1.1, function()
			local e = S.shop[1]
			e.hidden = true
			e.model:PivotTo(FAR)
			T.fx.carry(p, SHOP[1], e.model:GetScale())
			p:play("CarryIdle", { fade = 0.1 })
		end)
		once(S, "go", t, 1.5, function() run(p) end)
		if t >= 1.5 then p:follow(P14b, t) end
	end,
}

-- n15. Devant la boutique : le propriétaire surgit et frappe le voleur à la batte ; le voleur est projeté, La Joconde vole.
local P15 = { { 0, V(-163, 0, 39) }, { 1.0, V(-148.5, 0, 43) } }
local O15 = { { 0, V(-141, 0, 29) }, { 0.75, V(-147.2, 0, 39.2) } }
local LAND15 = V(-151.5, 0, 51)
T.shots.n15_proprio_frappe = {
	dur = 3,
	slow = 2,
	cam = M.shake(M.zoom(hand(M.operator({ keys = { { 0, V(-136, 1.8, 40) }, { 3, V(-138, 2.0, 43) } }, targets = { "p", "o" }, lookOffset = V(0, 2, 0), lag = 0.25, fov = 52 }), 0.12, 16), { to = 44, at = 0.9, dur = 0.4, ease = "outQuad" }), { atKey = "hitAt", dur = 0.3, amp = 0.28 }),
	setup = function(S)
		fullShop(S, { 1 })
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "jean1", "bacon_jean", nil, SHOP[1], shopScale(S, 1))
		p:follow(P15, 0)
		run(p)
		local o = cast(S, "o", "bacon1", "bacon", "TOOL_Batte")
		o:follow(O15, 0)
		run(o)
	end,
	update = function(S, t)
		local A = S.actors
		T.fx.bob(S.shop, t)
		if t < 1.0 then A.p:follow(P15, t) end
		if t < 0.75 then A.o:follow(O15, t) end
		once(S, "ostop", t, 0.75, function()
			A.o:place(O15[2][2], V(-0.3, 0, 1))
			idle(A.o)
		end)
		if strike(S, "hitAt", t, A.o, "SwingBat", 0.72, 0.5, 0.35) then
			T.fx.drop(S, A.p, V(-2, 13, 7))
			A.p:stop("Run", 0.05)
			A.p:stop("CarryRun", 0.05)
			S.kb = A.p:play("Knockback", { looped = false, fade = 0.05 })
			S.flyFrom = A.p.cf.Position * FLAT
		end
		if S.hitAt then
			local u = (t - S.hitAt) / 0.55
			if u <= 1 then A.p:flyAt(S.flyFrom, LAND15, 2.6, u, V(0.3, 0, -1), 30) end
		end
		holdEnd(S.kb)
	end,
}

-- n16. Le propriétaire poursuit le voleur sur la place du hub, batte en l'air ; la caméra recule devant eux.
local P16 = { { 0, V(-150, 0, 44) }, { 3, V(-108, 0, 20) } }
local O16 = { { 0, V(-159, 0, 49) }, { 3, V(-114.5, 0, 23.5) } }
T.shots.n16_poursuite_hub = {
	dur = 3,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(-138, 2.4, 33) }, { 3, V(-100, 2.8, 14) } }, targets = { "p", "o" }, lookOffset = V(0, 2.2, 0), lag = 0.3, fov = 54 }), 0.14, 17),
	setup = function(S)
		fullShop(S, { 1 })
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "lav1", "lavande", nil, SHOP[1], shopScale(S, 1))
		p:follow(P16, 0)
		run(p)
		local o = cast(S, "o", "bacon1", "bacon", "TOOL_Batte")
		o:follow(O16, 0)
		run(o)
	end,
	update = function(S, t)
		local A = S.actors
		T.fx.bob(S.shop, t)
		A.p:follow(P16, t)
		A.o:follow(O16, t)
		strike(S, "s1", t, A.o, "SwingBat", 1.4, 0.5, 0.3)
		strike(S, "s2", t, A.o, "SwingBat", 2.4, 0.5, 0.3)
	end,
}

-- n17. Coup de batte qui envoie le voleur en l'air : salto arrière, il retombe plus loin, le sarcophage avec lui.
local P17 = { { 0, V(-151, 0, 42) }, { 0.75, V(-139, 0, 39.5) } }
local LAND17 = V(-150, 0, 47)
T.shots.n17_ejecte_air = {
	dur = 3,
	slow = 2,
	-- de côté (dans l'axe, le propriétaire cachait le voleur au repérage)
	cam = M.shake(hand(M.operator({ keys = { { 0, V(-137, 2.2, 25) }, { 3, V(-139.5, 3.0, 26.5) } }, targets = { "p" }, lookOffset = V(0, 1.5, 0), lag = 0.22, fov = 56 }), 0.12, 18), { atKey = "hitAt", dur = 0.35, amp = 0.3 }),
	setup = function(S)
		fullShop(S, { 2 })
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "blond1", "blond", nil, SHOP[2], shopScale(S, 2))
		p:follow(P17, 0)
		run(p)
		local o = cast(S, "o", "bacon1", "bacon", "TOOL_Batte")
		o:place(V(-136.5, 0, 37.5), V(-1, 0, 0.3))
		o:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		T.fx.bob(S.shop, t)
		if t < 0.75 then A.p:follow(P17, t) end
		if strike(S, "hitAt", t, A.o, "SwingBat", 0.45, 0.5, 0.35) then
			T.fx.drop(S, A.p, V(-4, 16, 3))
			A.p:stop("Run", 0.05)
			A.p:stop("CarryRun", 0.05)
			S.kb = A.p:play("Knockback", { looped = false, fade = 0.05 })
			S.flyFrom = A.p.cf.Position * FLAT
		end
		if S.hitAt then
			local u = math.clamp((t - S.hitAt) / 1.0, 0, 1)
			A.p:flyAt(S.flyFrom, LAND17, 7, u, V(1, 0, -0.4), 0)
			if u < 1 then A.p:setCF(A.p.cf * CFrame.Angles(math.rad(360) * (1 - (1 - u) ^ 2), 0, 0)) end
		end
		holdEnd(S.kb)
	end,
}

-- n18. Contre-plongée : le propriétaire ramasse La Joconde et la lève au-dessus de sa tête, le voleur sonné derrière.
-- le propriétaire face à la caméra (de dos, on voyait le dos du tableau au repérage)
local ITEM18 = V(-142.8, 0, 40.2)
local O18 = { { 1.7, V(-145.2, 0, 41.2) }, { 3, V(-142.5, 0, 40.1) } }
T.shots.n18_reprise_objet = {
	dur = 3,
	slow = 2,
	cam = hand(M.travelling({ from = V(-136.5, 1.2, 37.5), look = V(-144.5, 3.6, 41.2), dir = "avant", dist = 2.5, dur = 3, ease = "sine", fov = 48 }), 0.07, 19),
	setup = function(S)
		fullShop(S, { 1 })
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "jean1", "bacon_jean")
		p:place(V(-151, 0, 46.5), V(1, 0, -0.4))
		p:play("Stunned", { fade = 0, looped = true })
		local o = cast(S, "o", "bacon1", "bacon")
		o:place(O18[1][2], V(1, 0, -0.3))
		o:play("Idle", { fade = 0 })
		S.it = T.fx.prop(S, "n18_item", "Items", SHOP[1])
		S.it:ScaleTo(shopScale(S, 1))
		T.fx.setOn(S.it, ITEM18, V(1, 0, 0.3))
	end,
	update = function(S, t)
		local A = S.actors
		T.fx.bob(S.shop, t)
		strike(S, "grab", t, A.o, "Grab", 0.5, 0.5, 0.4)
		once(S, "lift", t, 0.8, function()
			S.it:PivotTo(FAR)
			T.fx.carry(A.o, SHOP[1], shopScale(S, 1))
			A.o:play("CarryIdle", { fade = 0.12 })
		end)
		once(S, "turn", t, 1.7, function() run(A.o, "Walk") end)
		if t >= 1.7 then A.o:follow(O18, t) end
	end,
}

------------------------------------------------------------------------------------------------
-- BOUTIQUE PLEINE
------------------------------------------------------------------------------------------------

-- n19. La caméra remonte l'allée de la boutique 03 pleine en regardant de biais la rangée du mur z = 64 (dans l'axe de
-- l'allée, les présentoirs des murs sortaient du cadre 9:16 au repérage) ; le propriétaire marche, une amie regarde un objet.
T.shots.n19_boutique_allee = {
	dur = 4,
	slow = 2,
	-- au ras de la rangée, presque dans son axe : les objets se chevauchent en enfilade (repérage : de loin et de biais,
	-- la boutique paraissait vide, les présentoirs sont à 10 studs les uns des autres)
	cam = hand(M.path({ keys = { { 0, V(-162.5, 3.2, 57.5), V(-232, 2.8, 64.5) }, { 4, V(-176, 3.4, 57.5), V(-246, 2.8, 64.5) } }, ease = "sine", fov = 44 }), 0.08, 20),
	setup = function(S)
		fullShop(S)
		local o = cast(S, "o", "bacon1", "bacon")
		S.po = { { 0, V(-170, 0, 56) }, { 4, V(-197, 0, 57) } }
		o:follow(S.po, 0)
		o:play("Walk", { fade = 0 })
		local f = cast(S, "f", "lav1", "lavande")
		f:place(V(-188, 0, 21.5), V(0, 0, -1))
		f:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
		S.actors.o:follow(S.po, t)
	end,
}

-- n20. Travelling de trois quarts le long de la rangée du mur z = 16 : les objets défilent l'un après l'autre ; un joueur
-- en regarde un. (Repérage : de face un seul présentoir tient dans le cadre ; dans l'axe et bas, les plaques vertes
-- d'encaissement bouchent le bas de l'image.)
T.shots.n20_boutique_rayon = {
	dur = 4,
	slow = 2,
	cam = hand(M.path({ keys = { { 0, V(-164, 4.2, 27), V(-176, 2.4, 16) }, { 4, V(-200, 4.2, 27), V(-212, 2.4, 16) } }, ease = "linear", fov = 48 }), 0.06, 21),
	setup = function(S)
		fullShop(S)
		local f = cast(S, "f", "brune1", "brune")
		f:place(V(-196.5, 0, 19.8), V(0, 0, -1))
		f:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
	end,
}

-- n21. Encaissement : le propriétaire marche sur la plaque 01, billets et pièces jaillissent, l'objet exposé fait son tour.
local PAD21 = V(-168, 0.6, 20.9)
T.shots.n21_boutique_encaisse = {
	dur = 3,
	slow = 2,
	cam = M.shake(hand(M.travelling({ from = V(-166.5, 1.5, 29.5), look = V(-168, 2.8, 19), dir = "arriere", dist = 2, dur = 3, ease = "linear", fov = 50 }), 0.07, 22), { atKey = "cashAt", dur = 0.25, amp = 0.12 }),
	setup = function(S)
		fullShop(S)
		local o = cast(S, "o", "bacon1", "bacon")
		S.po = { { 0, V(-177, 0, 25.5) }, { 1.0, PAD21 } }
		o:follow(S.po, 0)
		o:play("Walk", { fade = 0 })
	end,
	update = function(S, t)
		local o = S.actors.o
		T.fx.bob(S.shop, t)
		if t < 1.0 then o:follow(S.po, t) end
		once(S, "cash", t, 1.0, function()
			S.cashAt = t
			o:place(PAD21, V(0.2, 0, 1))
			idle(o)
			T.fx.emit("FX_Collect_Bill", CFrame.new(PAD21 + V(0, 1, 0)))
			T.fx.emit("FX_Collect_Coin", CFrame.new(PAD21 + V(0, 1, 0)))
		end)
		-- tour de l'objet du présentoir 01 à l'encaissement (DisplayMotion : 0,7 s, deux sauts de 0,9 puis 0,4 stud)
		if S.cashAt then
			local e = S.shop[1]
			local u = math.clamp((t - S.cashAt) / 0.7, 0, 1)
			local k = u * 2
			local i = math.min(math.floor(k), 1)
			local f = k - i
			local hop = if u < 1 then 0.9 * 0.45 ^ i * 4 * f * (1 - f) else 0
			e.hidden = true
			e.model:PivotTo(e.base * CFrame.new(0, hop, 0) * CFrame.Angles(0, 2 * math.pi * (1 - (1 - u) ^ 2), 0))
		end
	end,
}

------------------------------------------------------------------------------------------------
-- FOULE ET AMBIANCE
------------------------------------------------------------------------------------------------

-- n22. Rue de la zone 1 vue à hauteur d'homme : ça court partout (casseur, voleur poursuivi, passante, voleuse du donut),
-- une témoin appelle la police ; à la fin le casseur frappe la vitrine du Kiosque.
local R22 = {
	f2 = { { 0, V(78, 0, -47) }, { 3.8, V(104, 0, 12) } },
	f3 = { { 0, V(74, 0, -54) }, { 3.8, V(100, 0, 6) } },
	f4 = { { 0, V(50, 0, 23) }, { 4, V(80, 0, 26) } },
	f5 = { { 0, V(70, 0, 47) }, { 2.8, V(40, 0, 14) } },
}
local F1 = { { 0, V(44, 0, -6) }, { 2.4, V(70, 0.4, -49.5) } }
T.shots.n22_foule_couloir = {
	dur = 4,
	slow = 2,
	cam = hand(M.pan({ pos = V(66, 5, 32), from = V(48, 4, -30), to = V(98, 4, -30), dur = 4, ease = "sine", fov = 58 }), 0.15, 23),
	setup = function(S)
		local f1 = cast(S, "f1", "bacon2", "bacon", "TOOL_Batte")
		f1:follow(F1, 0)
		run(f1)
		cast(S, "f2", "jean2", "bacon_jean", nil, "ITM_Z1_Pasteque", 1.6)
		cast(S, "f3", "gz1a", "guard:Guard_Z1")
		cast(S, "f4", "lav1", "lavande")
		cast(S, "f5", "guit2", "bacon_guitare", nil, "ITM_Z1_Donut", 2)
		for k, keys in R22 do
			local a = S.actors[k]
			a:follow(keys, 0)
			if k == "f3" then
				a:play("Sprint", { fade = 0 })
			elseif k == "f4" then
				a:play("Walk", { fade = 0 })
			else
				run(a)
			end
		end
		local w = cast(S, "w", "wit2", "witness:NPC_Witness_Z1_02")
		w:place(V(95, 0.4, -51), V(-1, 0, 0))
		w:play("CallPolice", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		for k, keys in R22 do A[k]:follow(keys, t) end
		if t < 2.4 then A.f1:follow(F1, t) end
		once(S, "f1stop", t, 2.4, function()
			A.f1:place(F1[2][2], V(0, 0, -1))
			idle(A.f1)
		end)
		if strike(S, "f1hit", t, A.f1, "HitWindow", 2.6, 0.4, 0.3) then
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z1_Kiosque"), { speed = 0.5 }))
		end
	end,
}

-- n23. Zoom lent sur la Galerie d'art (zone 5) : trois joueurs armés marchent vers la vitrine ; le coup de masse finit le plan.
local R23 = {
	g1 = { { 0, V(609, 0, 22) }, { 3.0, V(613, 0.4, 49.5) } },
	g2 = { { 0, V(618, 0, 19) }, { 3.2, V(618, 0.4, 49.6) } },
	g3 = { { 0, V(627, 0, 23) }, { 3.1, V(623, 0.4, 49.5) } },
}
T.shots.n23_zoom_galerie = {
	dur = 4,
	slow = 2,
	cam = M.shake(M.zoom(hand(M.travelling({ from = V(618, 3.2, 6), look = V(618, 7, 54.8), dir = "avant", dist = 6, dur = 4, ease = "linear", fov = 50 }), 0.06, 24), { to = 34, at = 0, dur = 4, ease = "sine" }), { atKey = "breakAt", dur = 0.3, amp = 0.25 }),
	setup = function(S)
		cast(S, "g1", "bacon1", "bacon", "TOOL_Batte")
		cast(S, "g2", "jean1", "bacon_jean", "TOOL_Masse")
		cast(S, "g3", "lav1", "lavande", "TOOL_Marteau")
		for k, keys in R23 do
			S.actors[k]:follow(keys, 0)
			S.actors[k]:play("Walk", { fade = 0, speed = 1.25 })
		end
	end,
	update = function(S, t)
		local A = S.actors
		for k, keys in R23 do
			if t < keys[2][1] then A[k]:follow(keys, t) end
			once(S, "stop" .. k, t, keys[2][1], function()
				A[k]:place(keys[2][2], V(0, 0, 1))
				idle(A[k])
			end)
		end
		if strike(S, "hit", t, A.g2, "HitWindowHeavy", 3.25, 0.45, 0.5) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z5_GalerieDArt"), { speed = 0.5 }))
		end
		strike(S, "hit1", t, A.g1, "HitWindow", 3.35, 0.4, 0.3)
	end,
}

-- n24. Vie du hub devant la boutique 03 : un joueur sur le tapis, d'autres passent, un voleur rentre avec le train électrique.
local R24 = {
	h2 = { { 0, V(-120, 0, 54) }, { 4, V(-150, 0, 44) } },
	h3 = { { 0, V(-112, 0, 2) }, { 4, V(-152, 0, 37) } },
	h4 = { { 0, V(-140, 0, 62) }, { 4, V(-124, 0, 32) } },
}
T.shots.n24_hub_vie = {
	dur = 4,
	slow = 2,
	cam = hand(M.travelling({ from = V(-128, 4.2, 4), look = V(-152, 4, 24), dir = "droite", dist = 14, dur = 4, ease = "sine", fov = 54 }), 0.1, 25),
	setup = function(S)
		fullShop(S)
		local h1 = cast(S, "h1", "blond1", "blond")
		h1:place(V(-151.7, 0, 15.4), V(1, 0, 0))
		h1:play("TreadmillRun", { fade = 0, looped = true })
		cast(S, "h2", "brune1", "brune")
		cast(S, "h3", "jean2", "bacon_jean", nil, "ITM_Z2_TrainElectrique", 1.4)
		cast(S, "h4", "tress1", "tresses")
		for k, keys in R24 do
			local a = S.actors[k]
			a:follow(keys, 0)
			if k == "h3" then run(a) else a:play("Walk", { fade = 0 }) end
		end
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
		for k, keys in R24 do S.actors[k]:follow(keys, t) end
	end,
}

T.ORDER_NATUREL = {
	"n01_casse_trio", "n02_casse_epaule", "n03_casse_masse_zoom", "n04_casse_vue_dedans", "n05_casse_porte_boutique",
	"n06_rayons_colis", "n07_colis_profil", "n08_sortie_vitrine", "n09_vigile_attrape", "n10_vigile_plaquage",
	"n11_ejecte_vitrine", "n12_poursuite_groupe", "n13_vigile_essouffle", "n14_vol_presentoir", "n15_proprio_frappe",
	"n16_poursuite_hub", "n17_ejecte_air", "n18_reprise_objet", "n19_boutique_allee", "n20_boutique_rayon",
	"n21_boutique_encaisse", "n22_foule_couloir", "n23_zoom_galerie", "n24_hub_vie",
}

-- Instant clé de chaque plan (repérage : T.stillAt(nom, 0) puis T.stillAt(nom, T.KEY_NATUREL[nom]))
T.KEY_NATUREL = {
	n01_casse_trio = 1.0, n02_casse_epaule = 1.25, n03_casse_masse_zoom = 0.9, n04_casse_vue_dedans = 0.9,
	n05_casse_porte_boutique = 0.8, n06_rayons_colis = 1.8, n07_colis_profil = 1.6, n08_sortie_vitrine = 1.5,
	n09_vigile_attrape = 1.8, n10_vigile_plaquage = 1.6, n11_ejecte_vitrine = 1.0, n12_poursuite_groupe = 1.6,
	n13_vigile_essouffle = 2.0, n14_vol_presentoir = 1.3, n15_proprio_frappe = 1.25, n16_poursuite_hub = 1.5,
	n17_ejecte_air = 1.1, n18_reprise_objet = 1.2, n19_boutique_allee = 2.0, n20_boutique_rayon = 2.0,
	n21_boutique_encaisse = 1.2, n22_foule_couloir = 2.0, n23_zoom_galerie = 2.6, n24_hub_vie = 2.0,
}

-- Construit d'avance toute la troupe et les décors (une fois, avant le repérage ou le tournage), puis remet tout.
function T.prebuildNaturel()
	for _, name in T.ORDER_NATUREL do
		local S = { actors = {}, fx = {}, props = {}, t = 0, dt = 0 }
		local ok, err = pcall(T.shots[name].setup, S)
		if not ok then return name .. " : " .. tostring(err) end
	end
	for _, f in T._restore do pcall(f) end
	T._restore = {}
	local fx = T.root():FindFirstChild("FX")
	if fx then fx:Destroy() end
	local far = CFrame.new(0, -1000, 0)
	for _, a in T.cast do
		a.model:PivotTo(far)
		if a.carried then a.carried.model:PivotTo(far) end
		if a.held then a.held.model:PivotTo(far) end
	end
	for _, m in T.props do if m.Parent then m:PivotTo(far) end end
	return "troupe prête"
end

return "plans naturels chargés : " .. #T.ORDER_NATUREL
