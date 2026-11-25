--!nocheck
-- Plans des trailers TikTok (skill trailer-tiktok). À charger APRÈS trailer_lib.luau, en Edit.
-- Chaque plan : T.shots[nom] = { dur, slow, cam, setup(S), update(S, t, dt) }.
-- Repères du couloir (mesurés le 2026-11-24) : rue de z = -48 à 48 (sol y = 0), trottoirs y = 0,4 de |z| = 48 à 54,
-- façades à |z| ≈ 54,75, magasins au sud (z < 0) et au nord (z > 0). Portes de zone à x = 30, 118, 230, 368, 530, 718.
-- Le champ (fov) d'un plan tourné (roll) est l'angle HORIZONTAL de l'image 9:16 finale.

local T = _G.Trailer
local V = Vector3.new
local M = T.moves

local function store(name: string): Model
	local s = workspace.Map:FindFirstChild(name, true)
	assert(s, "magasin introuvable : " .. name)
	return s
end

-- Lance fn une seule fois, au premier passage de t après at.
local function once(S, key: string, t: number, at: number, fn)
	if t >= at and not S["_" .. key] then
		S["_" .. key] = true
		fn()
	end
end

------------------------------------------------------------------------------------------------
-- 1. Casse de vitrine en orbite : le joueur frappe la vitrine du Kiosque (zone 1), les éclats volent vers nous.
------------------------------------------------------------------------------------------------
local IN1 = { { 1.25, V(74, 0.4, -49.2) }, { 2.6, V(73, 0, -66) } } -- il entre par la vitrine cassée
T.shots.vitrine_orbite = {
	dur = 3.2,
	slow = 2,
	cam = M.shake(M.orbit({ center = V(74, 4.5, -50), radius = 10, height = -1.2, from = -130, to = -60, dur = 3.2, ease = "sine", fov = 48, lookUp = 0.5 }), { atKey = "breakAt", dur = 0.3, amp = 0.25 }),
	setup = function(S)
		local p = T.actor("casseur", "bacon")
		S.actors.p1 = p
		if not p.held then T.fx.hold(p, "TOOL_Batte") end
		p:place(V(74, 0.4, -49.2), V(0, 0, -1))
		p:play("Idle", { fade = 0 })
	end,
	-- frappe à 0,3 s, éclats lancés moins loin (speed 0,5) et effacés après 0,9 s, puis le casseur entre dans le magasin
	update = function(S, t, dt)
		local p = S.actors.p1
		once(S, "hit", t, 0.3, function()
			S.hitTrack = p:play("HitWindow", { looped = false, fade = 0.1 })
		end)
		local tr = S.hitTrack
		-- le marqueur Impact n'est pas lu pendant StepAnimations : impact à 40 % de l'animation
		if tr and not S.breakAt and ((tr.Length > 0 and tr.TimePosition >= tr.Length * 0.4) or t > 1.0) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z1_Kiosque"), { speed = 0.5 }))
		end
		if t >= 1.25 then
			once(S, "run", t, 1.25, function()
				p:stop("Idle", 0.1)
				p:play("Run", { fade = 0.12 })
				-- la batte pend mal pendant la course : il la lâche (une nouvelle est prise à la prise suivante)
				if p.held then
					p.held.model:Destroy()
					p.held = nil
				end
			end)
			p:follow(IN1, t)
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 2. Poursuite en travelling arrière : le joueur court vers nous avec l'objet sur la tête, le vigile derrière.
------------------------------------------------------------------------------------------------
local P2 = { { 0, V(86, 0, -20) }, { 3.6, V(144, 0, -20) } }
local G2 = { { 0, V(74, 0, -15.5) }, { 3.6, V(136, 0, -16) } } -- du côté de la caméra : on le voit derrière le voleur (repérage)
T.shots.poursuite_arriere = {
	dur = 3.6,
	slow = 2,
	-- lookOffset est en repère monde : visée entre le voleur et le vigile, assez haute pour laisser peu de sol
	cam = M.follow({ actor = "p1", offset = V(5, -1.4, -13), offsetTo = V(4, -1.6, -9.5), dur = 3.6, ease = "sine", lookOffset = V(-4, 2.6, 1.5), lag = 0.12, fov = 50 }),
	setup = function(S)
		local p = T.actor("voleur", "bacon")
		S.actors.p1 = p
		if not p.carried then T.fx.carry(p, "ITM_Z3_TeleGeante", 2) end
		local g = T.actor("vigile", "guard:Guard_Z1")
		S.actors.g1 = g
		p:follow(P2, 0)
		g:follow(G2, 0)
		p:play("Run", { fade = 0 })
		p:play("CarryRun", { fade = 0 })
		g:play("Run", { fade = 0 })
	end,
	update = function(S, t, dt)
		S.actors.p1:follow(P2, t)
		S.actors.g1:follow(G2, t)
	end,
}

------------------------------------------------------------------------------------------------
-- 3. Travelling latéral vers la droite le long des façades de Londres (zone 2), deux joueurs qui courent.
------------------------------------------------------------------------------------------------
local P3a = { { 0, V(140, 0, -14) }, { 3, V(190, 0, -14) } } -- au premier plan, la façade derrière
local P3b = { { 0, V(128, 0, -21) }, { 3, V(176, 0, -21) } }
T.shots.londres_lateral = {
	dur = 3,
	slow = 2,
	cam = M.travelling({ from = V(146, 4, 2), look = V(146, 9, -54), dir = "droite", dist = 40, dur = 3, ease = "sine", fov = 48 }),
	setup = function(S)
		local a = T.actor("coureur1", "bacon_jean")
		local b = T.actor("coureur2", "bacon_guitare")
		S.actors.p2, S.actors.p3 = a, b
		a:follow(P3a, 0)
		b:follow(P3b, 0)
		a:play("Run", { fade = 0 })
		b:play("Run", { fade = 0 })
	end,
	update = function(S, t, dt)
		S.actors.p2:follow(P3a, t)
		S.actors.p3:follow(P3b, t)
	end,
}

------------------------------------------------------------------------------------------------
-- 4. Plan large en montée : de l'entrée du couloir, la caméra monte et avance pour montrer les 6 zones en enfilade.
------------------------------------------------------------------------------------------------
local P4 = {
	p1 = { { 0, V(52, 0, -6) }, { 4, V(116, 0, -6) } },
	p2 = { { 0, V(40, 0, 9) }, { 4, V(104, 0, 9) } },
	p3 = { { 0, V(30, 0, -16) }, { 4, V(90, 0, -16) } },
}
T.shots.couloir_drone = {
	dur = 4,
	slow = 2,
	-- départ après le texte SAFE ZONE du sol (x de 12,5 à 19,5), qui sortait coupé du cadre
	cam = M.path({ keys = { { 0, V(24, 10, 0), V(220, 6, 0) }, { 4, V(46, 58, 0), V(330, 0, 0) } }, ease = "sine", fov = 48 }),
	setup = function(S)
		S.actors.p1 = T.actor("foule1", "bacon")
		S.actors.p2 = T.actor("foule2", "bacon_jean")
		S.actors.p3 = T.actor("foule3", "bacon_guitare")
		for id, keys in P4 do
			local a = S.actors[id]
			a:follow(keys, 0)
			a:play("Run", { fade = 0 })
		end
	end,
	update = function(S, t, dt)
		for id, keys in P4 do S.actors[id]:follow(keys, t) end
	end,
}

-- NOUVEAUX SUJETS (2026-11-24) : écrits d'après les repères relevés, PAS ENCORE REPÉRÉS en image.
-- Au premier tournage, faire un T.peek de la première image de chacun et corriger avant de filmer.
-- Chaque prise dure 2,5 à 3 s ; le montage n'en garde que 10 à 30 images autour du sommet (plans d'environ 0,8 s).

-- Un coureur sur un chemin, avec ses animations (Run par défaut).
local function runner(S, key: string, id: string, look: string, keys, anims)
	local a = T.actor(id, look)
	S.actors[key] = a
	a:follow(keys, 0)
	for _, name in anims or { "Run" } do a:play(name, { fade = 0 }) end
	return a
end
local function follow(S, list)
	for key, keys in list do S.actors[key]:follow(keys, S.t or 0) end
end

------------------------------------------------------------------------------------------------
-- 5. Zone 1 : travelling avant rapide au ras du trottoir vers la vitrine de la Superette (nord), un joueur passe.
------------------------------------------------------------------------------------------------
local R5 = { s1 = { { 0, V(60, 0.4, 47) }, { 2.5, V(90, 0.4, 47) } } }
T.shots.z1_superette_avant = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(74, 2.5, 20), look = V(74, 7, 55), dir = "avant", dist = 14, dur = 2.5, ease = "linear", fov = 45 }),
	setup = function(S) runner(S, "s1", "passant1", "bacon_guitare", R5.s1, { "Walk" }) end,
	update = function(S, t) follow(S, R5) end,
}

------------------------------------------------------------------------------------------------
-- 6. Zone 3 (Tokyo) : travelling gauche au ras du sol devant le magasin de jeux vidéo, un joueur court dans le même sens.
------------------------------------------------------------------------------------------------
local R6 = { s1 = { { 0, V(312, 0.4, -44) }, { 2.5, V(272, 0.4, -44) } } }
T.shots.z3_tokyo_gauche = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(306, 3.5, -28), look = V(306, 8, -55), dir = "gauche", dist = 26, dur = 2.5, ease = "linear", fov = 45 }),
	setup = function(S) runner(S, "s1", "tokyo1", "bacon_jean", R6.s1) end,
	update = function(S, t) follow(S, R6) end,
}

------------------------------------------------------------------------------------------------
-- 7. Zone 4 (Los Angeles) : travelling haut qui révèle la rue, deux joueurs qui courent devant.
------------------------------------------------------------------------------------------------
local R7 = {
	s1 = { { 0, V(392, 0, -3) }, { 2.5, V(432, 0, -3) } }, -- rapprochés de l'axe (repérage : coupés au bord)
	s2 = { { 0, V(386, 0, 4.5) }, { 2.5, V(424, 0, 4.5) } },
}
T.shots.z4_la_montee = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(378, 2.5, 0), look = V(530, 14, 0), dir = "haut", dist = 24, dur = 2.5, ease = "inQuad", keepLook = true, fov = 45 }),
	setup = function(S)
		runner(S, "s1", "la1", "bacon", R7.s1)
		runner(S, "s2", "la2", "bacon_guitare", R7.s2)
	end,
	update = function(S, t) follow(S, R7) end,
}

------------------------------------------------------------------------------------------------
-- 8. Zone 5 (Paris) : orbite basse autour d'un joueur qui tient La Joconde devant la galerie d'art.
------------------------------------------------------------------------------------------------
T.shots.z5_paris_orbite = {
	dur = 2.5,
	slow = 2,
	cam = M.orbit({ center = V(618, 4, 42), radius = 9, height = -1, from = 55, to = 100, dur = 2.5, ease = "linear", fov = 45, lookUp = 0.8 }),
	setup = function(S)
		local a = T.actor("paris1", "bacon")
		S.actors.s1 = a
		if not a.carried then T.fx.carry(a, "ITM_Z5_LaJoconde", 2) end
		a:place(V(618, 0, 42), V(0, 0, -1))
		a:play("Idle", { fade = 0 })
		a:play("CarryIdle", { fade = 0 })
	end,
}

------------------------------------------------------------------------------------------------
-- 9. Zone 6 : la vitrine de la Banque cassée à la hache, travelling avant qui freine sur l'impact.
------------------------------------------------------------------------------------------------
T.shots.z6_banque_casse = {
	dur = 2.5,
	slow = 2,
	cam = M.shake(M.travelling({ from = V(818, 3, 33), look = V(818, 6.5, 54), dir = "avant", dist = 7, dur = 2.5, ease = "outQuad", fov = 45 }), { atKey = "breakAt", dur = 0.35, amp = 0.3 }),
	setup = function(S)
		local a = T.actor("banque1", "bacon")
		S.actors.s1 = a
		if not a.held then T.fx.hold(a, "TOOL_HacheDIncendie") end
		a:place(V(818, 0.4, 49.5), V(0, 0, 1))
		a:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		local a = S.actors.s1
		once(S, "hit", t, 0.6, function() S.hitTrack = a:play("HitWindowHeavy", { looped = false, fade = 0.1 }) end)
		local tr = S.hitTrack
		if tr and not S.breakAt and ((tr.Length > 0 and tr.TimePosition >= tr.Length * 0.45) or t > 1.4) then
			S.breakAt = t
			table.insert(S.fx, T.fx.breakWindow(store("STORE_Z6_Banque"), { speed = 0.5 }))
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 10. Porte de zone : la caméra suit un joueur de dos à travers la porte de la zone 3 (x = 230).
------------------------------------------------------------------------------------------------
local R10 = { s1 = { { 0, V(204, 0, 4) }, { 2.5, V(256, 0, 4) } } }
T.shots.porte_zone3 = {
	dur = 2.5,
	slow = 2,
	cam = M.follow({ actor = "s1", offset = V(2, 2.5, 10), offsetTo = V(1.5, 2.2, 8), dur = 2.5, lookOffset = V(0, 2, 0), lag = 0.12, fov = 48 }),
	setup = function(S) runner(S, "s1", "porte1", "bacon", R10.s1) end,
	update = function(S, t) follow(S, R10) end,
}

------------------------------------------------------------------------------------------------
-- 11. Colis ouvert : dans le Kiosque, un joueur frappe un colis Légendaire sur le rayon, l'objet en sort.
-- À REPÉRER : le côté ouvert du rayon (le joueur est posé côté +x du ShelfSlot_02).
------------------------------------------------------------------------------------------------
local SLOT11 = V(65.1, 2.8, -77.5)
T.shots.colis_ouvert = {
	dur = 3,
	slow = 2,
	-- en plongée au-dessus du joueur : à hauteur d'homme, le joueur ou la marchandise des rayons cachaient le colis (repérage)
	cam = M.travelling({ from = V(72.5, 9.5, -79.8), look = V(65.4, 3.2, -77.5), dir = "avant", dist = 2, dur = 3, ease = "outQuad", fov = 50 }),
	setup = function(S)
		local a = T.actor("colis1", "bacon")
		S.actors.s1 = a
		a:place(V(67.8, 0, -77.5), V(-1, 0, 0))
		a:play("Unbox_Hammer", { fade = 0, looped = true })
		local box = T.fx.prop(S, "colis_box", "Boxes", "BOX_Legendary")
		if not box:GetAttribute("_Scaled") then
			box:ScaleTo(box:GetScale() * 1.4)
			box:SetAttribute("_Scaled", true)
		end
		T.fx.setOn(box, SLOT11, V(1, 0, 0))
		S.item = T.fx.prop(S, "colis_item", "Items", "ITM_Z1_Donut")
		S.item:PivotTo(CFrame.new(0, -1000, 0))
	end,
	update = function(S, t)
		local a = S.actors.s1
		once(S, "open", t, 1.6, function()
			a:stop("Unbox_Hammer", 0.1)
			a:play("Idle", { fade = 0.1 })
			S.props.colis_box:PivotTo(CFrame.new(0, -1000, 0))
			T.fx.emit("FX_Unbox_Burst", CFrame.new(SLOT11 + V(0, 0.6, 0)))
			T.fx.emit("FX_Unbox_Reveal", CFrame.new(SLOT11 + V(0, 0.6, 0)))
		end)
		if t >= 1.6 then
			local u = math.clamp((t - 1.6) / 0.6, 0, 1)
			local up = 1 - (1 - u) ^ 3
			S.item:PivotTo(CFrame.new(SLOT11 + V(0, 0.5 + 2.2 * up, 0)) * CFrame.Angles(0, (t - 1.6) * 3, 0))
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 12. Vol : le joueur attrape l'objet (Grab), le lève au-dessus de sa tête et part en courant (CarryRun).
------------------------------------------------------------------------------------------------
local R12 = { { 0.9, V(67.8, 0, -77.5) }, { 3, V(70, 0, -56) } }
T.shots.vol_grab = {
	dur = 3,
	slow = 2,
	cam = M.travelling({ from = V(74, 2.5, -66), look = V(67.8, 3.5, -76), dir = "droite", dist = 5, dur = 3, ease = "sine", fov = 45 }),
	setup = function(S)
		local a = T.actor("voleur2", "bacon_jean")
		S.actors.s1 = a
		if a.carried then
			a.carried.model:Destroy()
			a.carried = nil
		end
		a:place(V(67.8, 0, -77.5), V(-1, 0, 0))
		a:play("Grab", { fade = 0, looped = false })
	end,
	update = function(S, t)
		local a = S.actors.s1
		once(S, "lift", t, 0.6, function()
			T.fx.carry(a, "ITM_Z1_Donut", 2)
			a:play("CarryIdle", { fade = 0.1 })
		end)
		once(S, "run", t, 0.9, function()
			a:play("Run", { fade = 0.12 })
			a:play("CarryRun", { fade = 0.12 })
		end)
		if t >= 0.9 then a:follow(R12, t) end
	end,
}

------------------------------------------------------------------------------------------------
-- 13. Objets exposés : travelling au ras des présentoirs de la boutique 03, objets copiés qui tournent.
------------------------------------------------------------------------------------------------
local STANDS13 = {
	{ "expo1", "ITM_Z6_DragonDeDiamant", V(-168, 1.6, 16) },
	{ "expo2", "ITM_Z5_TourEiffelEnBronze", V(-178, 1.6, 16) },
	{ "expo3", "ITM_Z6_TaxiEnOr", V(-168, 1.6, 64) },
	{ "expo4", "ITM_Z4_ChihuahuaEnDiamants", V(-178, 1.6, 64) },
}
T.shots.boutique_exposes = {
	dur = 3,
	slow = 2,
	-- dans la boutique (à x = -161, la caméra était dans la vitre de la porte), tournée vers les présentoirs
	cam = M.travelling({ from = V(-163, 3, 9), look = V(-174, 2.4, 16), dir = "gauche", dist = 10, dur = 3, ease = "linear", fov = 45 }),
	setup = function(S)
		for _, e in STANDS13 do
			local m = T.fx.prop(S, e[1], "Items", e[2])
			if not m:GetAttribute("_Scaled") then
				m:ScaleTo(m:GetScale() * 1.5)
				m:SetAttribute("_Scaled", true)
			end
			T.fx.setOn(m, e[3] + V(0, 0.4, 0), V(1, 0, 0))
		end
	end,
	update = function(S, t)
		for _, e in STANDS13 do
			local m = S.props[e[1]]
			m:PivotTo(m:GetPivot() * CFrame.Angles(0, (S.dt or 0) * 1.2, 0))
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 14. Plaque d'argent : le joueur marche sur la plaque du présentoir 01, billets et pièces jaillissent.
------------------------------------------------------------------------------------------------
local PAD14 = V(-168, 0.6, 20.9)
local R14 = { s1 = { { 0, V(-176, 0, 27) }, { 1.2, PAD14 }, { 2.5, PAD14 + V(0.5, 0, -0.3) } } } -- arrive face à la caméra
T.shots.plaque_argent = {
	dur = 2.5,
	slow = 2,
	cam = M.shake(M.orbit({ center = PAD14 + V(0, 2.5, 0), radius = 8, height = -1, from = -20, to = 15, dur = 2.5, ease = "linear", fov = 45 }), { atKey = "cashAt", dur = 0.25, amp = 0.15 }),
	setup = function(S) runner(S, "s1", "proprio1", "bacon", R14.s1, { "Walk" }) end,
	update = function(S, t)
		follow(S, R14)
		once(S, "cash", t, 1.2, function()
			S.cashAt = t
			S.actors.s1:stop("Walk", 0.2)
			S.actors.s1:play("Idle", { fade = 0.2 })
			T.fx.emit("FX_Collect_Bill", CFrame.new(PAD14 + V(0, 1, 0)))
			T.fx.emit("FX_Collect_Coin", CFrame.new(PAD14 + V(0, 1, 0)))
		end)
	end,
}

------------------------------------------------------------------------------------------------
-- 15. Tapis : orbite serrée autour d'un joueur qui court sur le tapis de la boutique 03.
-- À REPÉRER : le sens du tapis (le joueur regarde vers +x, comme le tapis).
------------------------------------------------------------------------------------------------
local TM15 = V(-151.7, 0, 15.4)
T.shots.tapis_orbite = {
	dur = 2.5,
	slow = 2,
	cam = M.orbit({ center = TM15 + V(0, 4, 0), radius = 10, height = 1.5, from = 20, to = 65, dur = 2.5, ease = "linear", fov = 45 }), -- au-dessus de la rambarde
	setup = function(S)
		local a = T.actor("tapis1", "bacon_guitare")
		S.actors.s1 = a
		a:place(TM15, V(1, 0, 0))
		a:play("TreadmillRun", { fade = 0, looped = true })
	end,
}

------------------------------------------------------------------------------------------------
-- 16. Camion : un camion Légendaire passe dans la rue de Tokyo, caméra basse qui glisse moins vite que lui.
------------------------------------------------------------------------------------------------
local TR16 = { { 0, V(250, 0, 8) }, { 2.5, V(330, 0, 8) } }
T.shots.camion_lateral = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(262, 4.5, -36), look = V(262, 7, 8), dir = "gauche", dist = 34, dur = 2.5, ease = "linear", fov = 48 }), -- assez loin pour que le camion tienne dans le cadre
	setup = function(S)
		local m = T.fx.prop(S, "camion", "Events", "ENV_Event_Truck_Legendary")
		local p, d = T.along(TR16, 0)
		m:PivotTo(CFrame.lookAt(p, p + d))
	end,
	update = function(S, t)
		local p, d = T.along(TR16, t)
		S.props.camion:PivotTo(CFrame.lookAt(p, p + d))
	end,
}

------------------------------------------------------------------------------------------------
-- 17. Fourgon blindé : il fonce vers la caméra dans la rue de Paris, deux joueurs le poursuivent.
------------------------------------------------------------------------------------------------
local VAN17 = { { 0, V(668, 0, 0) }, { 2.5, V(616, 0, 0) } }
local R17 = {
	s1 = { { 0, V(694, 0, -6) }, { 2.5, V(648, 0, -6) } },
	s2 = { { 0, V(700, 0, 7) }, { 2.5, V(656, 0, 7) } },
}
T.shots.fourgon_arriere = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(600, 4, 9), look = V(660, 7, 0), dir = "arriere", dist = 22, dur = 2.5, ease = "linear", fov = 48 }),
	setup = function(S)
		local m = T.fx.prop(S, "fourgon", "Events", "ENV_Event_ArmoredVan")
		local p, d = T.along(VAN17, 0)
		m:PivotTo(CFrame.lookAt(p, p + d))
		runner(S, "s1", "fourgon1", "bacon", R17.s1)
		runner(S, "s2", "fourgon2", "bacon_jean", R17.s2)
	end,
	update = function(S, t)
		local p, d = T.along(VAN17, t)
		S.props.fourgon:PivotTo(CFrame.lookAt(p, p + d))
		follow(S, R17)
	end,
}

------------------------------------------------------------------------------------------------
-- 18. Fortune Tower : le coffre de l'événement à son point d'apparition, contre-plongée qui monte, joueurs qui accourent.
------------------------------------------------------------------------------------------------
local FV18 = V(856, 0, 0)
local R18 = {
	s1 = { { 0, V(812, 0, -10) }, { 2.5, V(840, 0, -6) } },
	s2 = { { 0, V(806, 0, 6) }, { 2.5, V(836, 0, 4) } },
}
T.shots.fortune_tower = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(818, 2, -4), look = V(856, 16, 0), dir = "haut", dist = 12, dur = 2.5, ease = "sine", keepLook = true, fov = 48 }),
	setup = function(S)
		local m = T.fx.prop(S, "fortune", "Events", "ENV_Event_FortuneVault")
		m:PivotTo(CFrame.lookAt(FV18, FV18 + V(-1, 0, 0)))
		runner(S, "s1", "fortune1", "bacon", R18.s1)
		runner(S, "s2", "fortune2", "bacon_guitare", R18.s2)
	end,
	update = function(S, t) follow(S, R18) end,
}

------------------------------------------------------------------------------------------------
-- 19. Hub : révélation par-dessus le jardin, des joueurs marchent vers les boutiques.
-- À REPÉRER : les murs et les dalles surélevées entre la caméra et le jardin.
------------------------------------------------------------------------------------------------
local R19 = {
	s1 = { { 0, V(-70, 0, -8) }, { 3, V(-100, 0, -30) } },
	s2 = { { 0, V(-64, 0, 10) }, { 3, V(-96, 0, 34) } },
	s3 = { { 0, V(-80, 0, 2) }, { 3, V(-118, 0, 4) } },
}
T.shots.hub_revelation = {
	dur = 3,
	slow = 2,
	cam = M.reveal({ from = V(-40, 3, 0), to = V(-36, 38, 0), look = V(-140, 4, 0), dur = 3, ease = "outQuint", fov = 48 }),
	setup = function(S)
		runner(S, "s1", "hub1", "bacon", R19.s1, { "Walk" })
		runner(S, "s2", "hub2", "bacon_jean", R19.s2, { "Walk" })
		runner(S, "s3", "hub3", "bacon_guitare", R19.s3)
	end,
	update = function(S, t) follow(S, R19) end,
}

------------------------------------------------------------------------------------------------
-- 20. Hub : travelling latéral le long des stands d'armes et de Robux (x = 12), un joueur qui passe.
------------------------------------------------------------------------------------------------
local R20 = { s1 = { { 0, V(2, 0, 72) }, { 3, V(2, 0, 112) } } }
T.shots.hub_stands = {
	dur = 3,
	slow = 2,
	cam = M.travelling({ from = V(-14, 5, 70), look = V(12, 6, 70), dir = "droite", dist = 44, dur = 3, ease = "sine", fov = 48 }),
	setup = function(S) runner(S, "s1", "stand1", "bacon", R20.s1, { "Walk" }) end,
	update = function(S, t) follow(S, R20) end,
}

------------------------------------------------------------------------------------------------
-- 21. Boutique d'un joueur : travelling avant vers la porte de la boutique 03, son propriétaire devant.
------------------------------------------------------------------------------------------------
T.shots.boutique_facade = {
	dur = 2.5,
	slow = 2,
	cam = M.travelling({ from = V(-128, 3.5, 40), look = V(-161.5, 11, 40), dir = "avant", dist = 10, dur = 2.5, ease = "linear", fov = 48 }),
	setup = function(S)
		local a = T.actor("proprio2", "bacon")
		S.actors.s1 = a
		a:place(V(-156, 0, 38), V(1, 0, 0))
		a:play("Idle", { fade = 0 })
	end,
}

local n = 0
for _ in T.shots do n += 1 end
return "plans chargés : " .. n
