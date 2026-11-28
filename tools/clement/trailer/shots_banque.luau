--!nocheck
-- Banque de plans « qui font vivre le jeu » (Clément, 26/11 soir ; brief-banque-de-plans.md). En Edit, sans Play, avec le
-- moteur image par image de shots_lancement.luau (charger trailer_lib.luau, shots_lancement.luau, shots_inspi_allees.luau
-- d'abord). Chaque plan : quelque chose qui bouge, 16:9 (_h), mouvement de caméra simple. Rien n'est laissé : tout va dans
-- Workspace/_TRAILER, et ce qui est caché l'est en local (L.hide, remis par T.stop).
-- Plans neufs (préfixe B_) :
--   B_boutiques_tout (latéral v2 + passants qui marchent + témoins qui bougent), B_tapis_pieds, B_tapis_hub,
--   B_poursuite_face, B_survol_a/b/c, B_temoins, B_vendeurs, B_camion, B_hub_survol, B_boutique_pleine,
--   B_ronde_bijouterie, B_ligne_safe, B_mythique.
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def and L.INSPI, "charger trailer_lib, shots_lancement puis shots_inspi_allees d'abord")
local V = Vector3.new
local M = T.moves
local def = L.def
local RS = game:GetService("ReplicatedStorage")
local Assets = RS.Assets
local Items = require(RS.Shared.Config.Items)
local Rarities = require(RS.Shared.Config.Rarities)

local function store(name) local s = workspace.Map:FindFirstChild(name, true) assert(s, "introuvable : " .. name) return s end
local function once(S, key, t, at, fn) if t >= at and not S["_" .. key] then S["_" .. key] = true fn() end end
local function lin(a, b, dur) return { { 0, a }, { dur, b } } end
local function hideAllWitnesses()
	for _, z in workspace.Map:GetChildren() do
		local w = z:FindFirstChild("Witnesses")
		if w then L.hide(w) end
	end
end
local PASSANTS = { "lavande", "blond", "tresses", "brune", "bacon_jean", "bacon_guitare" }
local D6 = V(376, 0, 0)
local GUARD6 = "guard:Guard_Z6"

------------------------------------------------------------------------------------------------
-- 01. Boutiques de gauche à droite (cadrage v2) avec des passants sur le trottoir sud et les témoins qui bougent.
-- La caméra passe à x = 30 + 16 t : chaque passant est réglé pour être au milieu de sa zone quand elle passe.
------------------------------------------------------------------------------------------------
do
	local G2 = { 30, 118, 230, 368, 530, 718, 860 }
	local DUR = L.INSPI.durs2.tout
	local cam0 = T.shots.L_inspi2_zones_tout_h.cam
	def("B_boutiques_tout", {
		dur = DUR,
		cam = function() return cam0 end,
		setup = function(S)
			L.hideHumans()
			S.walk = {}
			local n = 0
			for k = 1, 6 do
				local xc = (G2[k] + G2[k + 1]) / 2
				local tc = (xc - 30) / 16
				for j = 1, 2 do
					n += 1
					local dir = if j == 1 then 1 else -1
					local v = 5.2 * dir
					local z = if j == 1 then -45.2 else -46.6
					local off = if j == 1 then -14 else 16
					local p0 = V(xc + off + v * (0 - tc), 0, z)
					local p1 = V(xc + off + v * (DUR - tc), 0, z)
					local a = L.fresh("passant" .. n, PASSANTS[(n - 1) % #PASSANTS + 1])
					a:follow(lin(p0, p1, DUR), 0)
					L.toVisibleGround(a)
					a:play("Walk", { fade = 0, looped = true })
					S.actors["w" .. n] = a
					S.walk[n] = lin(p0, p1, DUR)
				end
				-- le témoin du trottoir sud de la zone (copie animée : il regarde, prend une photo)
				local src = workspace.Map:FindFirstChild(("NPC_Witness_Z%d_02"):format(k), true)
				if src then
					local c = L.fresh("temoin_s" .. k, "witness:" .. src.Name)
					local cf = src:GetPivot()
					c:place(cf.Position - V(0, 3.6, 0), cf.LookVector)
					L.toVisibleGround(c)
					c:play(if k % 2 == 0 then "TakePhoto" else "Look", { fade = 0, looped = true })
					S.actors["ts" .. k] = c
				end
			end
		end,
		update = function(S, t)
			for n, keys in S.walk do
				local a = S.actors["w" .. n]
				a:follow(keys, t)
				L.toVisibleGround(a)
			end
		end,
	})
end

------------------------------------------------------------------------------------------------
-- 02. Tapis : gros plan pieds et bande ; tapis du hub (un coureur sur chacun des 6), panoramique depuis le hub
------------------------------------------------------------------------------------------------
local TM3 = V(-151.7, 0, 15.4) -- tapis de PLOT_Shop_03 (celui de tapis_orbite2)
def("B_tapis_pieds", {
	dur = 3.5,
	cam = function() return M.orbit({ center = TM3 + V(0, 1.6, 0), radius = 5, height = 0.3, from = 200, to = 160, dur = 3.5, ease = "linear", fov = 46 }) end,
	setup = function(S)
		local a = L.fresh("coureur", "bacon")
		S.actors.s1 = a
		a:place(TM3, V(1, 0, 0))
		a:play("TreadmillRun", { fade = 0, looped = true })
	end,
})
local function runnersOnAllTreadmills(S)
	for k = 1, 6 do
		local pt, dir = L.plotMap(("PLOT_Shop_%02d"):format(k), "PLOT_Shop_03")
		local a = L.fresh("tapis_hub" .. k, if k == 3 then "bacon" else PASSANTS[k])
		a:place(pt(TM3), dir(V(1, 0, 0)))
		a:play("TreadmillRun", { fade = 0, looped = true })
		S.actors["t" .. k] = a
		S.nextPop = 0
	end
end
local function popsAll(S, t)
	while t >= (S.nextPop or 0) do
		for k = 1, 6 do L.gainPop(S, S.actors["t" .. k]) end
		S.nextPop = (S.nextPop or 0) + 0.5
	end
end
def("B_tapis_hub", {
	dur = 4.5,
	-- depuis le centre du hub, à hauteur d'homme : du tapis de la boutique 01 à celui de la 03
	cam = function() return M.path({ keys = { { 0, V(-95, 5, 40), V(-66.6, 3, 167.8) }, { 4.5, V(-95, 5, 40), V(-151.7, 3, 15.4) } }, ease = "sine", fov = 34 }) end,
	setup = runnersOnAllTreadmills,
	update = popsAll,
})

------------------------------------------------------------------------------------------------
-- 03. Poursuite de face (même scène que poursuite_z4, zone 6) ; 08b. la même avec un objet Mythique et son halo
------------------------------------------------------------------------------------------------
local P13 = { { 0, V(430, 0, 44) + D6 }, { 3.6, V(384, 0, 44) + D6 } }
local G13 = { { 0, V(446, 0, 40.5) + D6 }, { 3.6, V(393, 0, 40.5) + D6 } }
local function chaseSetup(itemId, scale)
	return function(S)
		local z = workspace.Map:FindFirstChild("Zone_6")
		if z and z:FindFirstChild("Witnesses") then L.hide(z.Witnesses) end
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		if itemId then
			L.carry(p, "ITM_" .. itemId, scale)
			L.itemLabelFor(p.carried.model, itemId, false)
		else
			L.carry(p, "ITM_Z4_Couronne", 2.4)
			L.itemLabel(p.carried.model, false)
		end
		p:follow(P13, 0)
		p:play("Run", { fade = 0 })
		p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z6", GUARD6)
		S.actors.g1 = g
		g:follow(G13, 0)
		g:play("Run", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	end
end
local function chaseUpdate(S, t)
	S.actors.p1:follow(P13, t)
	S.actors.g1:follow(G13, t)
end
def("B_poursuite_face", {
	dur = 3.6,
	-- la caméra recule devant le héros (côté -x), un peu en dessous de ses yeux, le vigile visible derrière lui
	cam = function() return M.follow({ actor = "p1", offset = V(-11, 2.4, -3.5), offsetTo = V(-8.5, 2.2, -3), dur = 3.6, ease = "sine", lookOffset = V(4, 2.8, -1), lag = 0.1, fov = 50 }) end,
	setup = chaseSetup(nil),
	update = chaseUpdate,
})
def("B_mythique", {
	dur = 3.6,
	cam = function() return M.follow({ actor = "p1", offset = V(6, 1.2, -13), offsetTo = V(4, 1.0, -10), dur = 3.6, ease = "sine", lookOffset = V(1, 3.4, 2), lag = 0.12, fov = 50 }) end,
	setup = chaseSetup("Z6_CerveauDore", 2.4),
	update = chaseUpdate,
})

------------------------------------------------------------------------------------------------
-- 04. La ville : survols lents ; témoins animés ; vendeurs qui font signe ; camion ; survol du hub
------------------------------------------------------------------------------------------------
local function survol(name, a, b, look, dur)
	def(name, {
		dur = dur,
		cam = function()
			return function(t)
				local p = a:Lerp(b, math.clamp(t / dur, 0, 1))
				return p, p + look, 55
			end
		end,
		setup = function() L.hideHumans() end,
	})
end
survol("B_survol_a", V(70, 62, -80), V(220, 62, -80), V(30, -48, 80), 5) -- Londres → Tokyo, côté sud, vers les façades nord
survol("B_survol_b", V(560, 62, 82), V(410, 62, 82), V(-30, -48, -80), 5) -- Paris → Los Angeles, côté nord
survol("B_survol_c", V(735, 70, -78), V(845, 70, -78), V(30, -52, 80), 4.5) -- New York

def("B_temoins", {
	dur = 4,
	-- trottoir nord de Londres (zone 2) : un témoin photographie, l'autre appelle la police, un passant traverse
	cam = function() return M.travelling({ from = V(166, 4.2, 37), look = V(176, 4.6, 49), dir = "droite", dist = 3.5, dur = 4, ease = "linear", fov = 48 }) end,
	setup = function(S)
		hideAllWitnesses()
		local w1 = L.fresh("temoin_a", "witness:NPC_Witness_Z2_01")
		w1:place(V(178, 0, 49), V(-0.3, 0, -1))
		L.toVisibleGround(w1)
		w1:play("TakePhoto", { fade = 0, looped = true })
		local w2 = L.fresh("temoin_b", "witness:NPC_Witness_Z1_01")
		w2:place(V(171.5, 0, 50.5), V(0.4, 0, -1))
		L.toVisibleGround(w2)
		w2:play("CallPolice", { fade = 0, looped = true })
		local w3 = L.fresh("passant1", PASSANTS[1])
		S.actors.a, S.actors.b, S.actors.c = w1, w2, w3
		S.path = lin(V(162, 0, 45.5), V(184, 0, 45.5), 4)
		w3:follow(S.path, 0)
		L.toVisibleGround(w3)
		w3:play("Walk", { fade = 0, looped = true })
	end,
	update = function(S, t)
		S.actors.c:follow(S.path, t)
		L.toVisibleGround(S.actors.c)
	end,
})

def("B_vendeurs", {
	dur = 4,
	-- devant les stands du hub (est) : le vendeur d'armes puis celui de la boutique Robux font signe
	cam = function() return M.travelling({ from = V(-6, 5.2, 80), look = V(11.5, 5, 88), dir = "gauche", dist = 30, dur = 4, ease = "sine", fov = 46 }) end,
	setup = function(S)
		for i, n in { "Vendor_Weapons", "Vendor_Robux" } do
			local src = workspace.Map:FindFirstChild(n, true)
			local c = L.fresh("vendeur" .. i, "witness:" .. n)
			L.hide(src)
			c:setCF(src:GetPivot())
			c:play("Wave", { fade = 0, looped = true })
			S.actors["v" .. i] = c
		end
	end,
})

def("B_camion", {
	dur = 4,
	-- le camion de l'événement traverse Tokyo (zone 3), la caméra basse le suit en panoramique
	cam = function()
		return function(t, S)
			local tp = S.truckPos or V(292, 0, -14)
			return V(292, 3.2, 22), tp + V(0, 5, 0), 44
		end
	end,
	setup = function(S)
		L.hideHumans()
		local m = L.prop(Assets:FindFirstChild("Events"), "ENV_Event_Truck_Rare")
		S.truck = m
		S.tpath = lin(V(238, 0, -14), V(346, 0, -14), 4)
		S.truckPos = S.tpath[1][2]
		L.setOn(m, S.truckPos, -90) -- l'avant (-Z du modèle) vers +x
	end,
	update = function(S, t)
		local u = math.clamp(t / 4, 0, 1)
		S.truckPos = S.tpath[1][2]:Lerp(S.tpath[2][2], u)
		L.setOn(S.truck, S.truckPos, -90)
	end,
})

def("B_hub_survol", {
	dur = 5,
	-- grand arc au-dessus du hub : les 6 boutiques, un coureur sur chaque tapis avec ses gains, les stands
	cam = function() return M.orbit({ center = V(-100, 6, 0), radius = 150, height = 60, from = 20, to = -20, dur = 5, ease = "linear", fov = 50 }) end,
	setup = function(S)
		runnersOnAllTreadmills(S)
	end,
	update = popsAll,
})

------------------------------------------------------------------------------------------------
-- 06c. Boutique pleine (PLOT_Shop_01, objets de la zone 6, sans œuf) : de près à loin, les objets tournent
------------------------------------------------------------------------------------------------
local function zone6Items()
	local list = {}
	for id, it in Items.ById do
		if id:sub(1, 3) == "Z6_" and not id:find("Oeuf") and not id:find("Egg") and Assets.Items:FindFirstChild("ITM_" .. id, true) then
			table.insert(list, { id = id, r = (Rarities.ById[it.Rarity] or {}).Order or 0 })
		end
	end
	table.sort(list, function(a, b) if a.r ~= b.r then return a.r > b.r end return a.id < b.id end)
	return list
end
def("B_boutique_pleine", {
	dur = 4.5,
	cam = function() return M.path({ keys = {
		{ 0, V(-58.5, 4.6, 190.5), V(-66, 3.4, 184) },
		{ 4.5, V(-34, 17, 214), V(-62, 3, 178) },
	}, ease = "sine", fov = 50 }) end,
	setup = function(S)
		local plot = store("PLOT_Shop_01")
		local list = zone6Items()
		S.items = {}
		for i = 1, 20 do
			local slot = plot:FindFirstChild(("DisplaySlot_%02d"):format(i), true)
			local e = list[(i - 1) % #list + 1]
			if slot and e then
				local m = L.prop("Items", "ITM_" .. e.id, 2.5)
				L.setOn(m, slot.WorldPosition, 180)
				table.insert(S.items, { m = m, p = slot.WorldPosition, yaw = 180 + i * 37 })
				if i <= 6 then L.itemLabelFor(m, e.id, false) end
			end
		end
	end,
	update = function(S, t)
		for _, it in S.items do L.setOn(it.m, it.p, it.yaw + t * 45) end
	end,
})

------------------------------------------------------------------------------------------------
-- 07b. Ronde dans la Bijouterie (zone 4) : le vigile marche dans l'allée centrale, vers la caméra
------------------------------------------------------------------------------------------------
def("B_ronde_bijouterie", {
	dur = 4.5,
	cam = function() return M.travelling({ from = V(447, 5.2, 70), look = V(442, 4.6, 112), dir = "arriere", dist = 2.5, dur = 4.5, ease = "linear", fov = 50 }) end,
	setup = function(S)
		local z = workspace.Map:FindFirstChild("Zone_4")
		if z and z:FindFirstChild("Witnesses") then L.hide(z.Witnesses) end
		local g = L.fresh("vigile_z4", "guard:Guard_Z4")
		S.actors.g1 = g
		S.path = lin(V(442, 0.5, 128), V(442, 0.5, 100), 4.5)
		g:follow(S.path, 0, V(0, 0, -1))
		L.toVisibleGround(g)
		g:play("Walk", { fade = 0, looped = true })
	end,
	update = function(S, t)
		S.actors.g1:follow(S.path, t, V(0, 0, -1))
		L.toVisibleGround(S.actors.g1)
	end,
})

------------------------------------------------------------------------------------------------
-- 08a. Ligne safe : le héros entre dans le hub avec la Cosmic Crown, l'éclat de sortie (FX_Escape) au passage de la
-- ligne (x ≈ 24), puis les deux feux d'artifice (FX_Fireworks, aux FireworksPoint_N/S), teintés Légendaire.
-- Chaque émetteur part à son attribut Delay (comme dans le jeu), à partir du déclenchement.
------------------------------------------------------------------------------------------------
local function tintAndArm(S, m, t0, color)
	S.emits = S.emits or {}
	for _, e in m:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			if e:GetAttribute("RarityTint") and color then e.Color = ColorSequence.new(color) end
			table.insert(S.emits, { e = e, at = t0 + (e:GetAttribute("Delay") or 0), n = e:GetAttribute("EmitCount") or 10 })
		elseif e:IsA("PointLight") and e:GetAttribute("RarityTint") and color then
			e.Color = color
		end
	end
end
local function stepEmits(S, t)
	for _, x in S.emits or {} do
		if not x.done and t >= x.at then x.done = true x.e:Emit(x.n) end
	end
end
local HP = lin(V(62, 0, 3), V(4, 0, 3), 3.4)
def("B_ligne_safe", {
	dur = 5,
	cam = function() return M.path({ keys = { { 0, V(-14, 4.4, 14), V(40, 5, 2) }, { 5, V(-18, 6, 16), V(24, 16, 0) } }, ease = "sine", fov = 56 }) end,
	setup = function(S)
		L.hideHumans()
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		L.carry(p, "ITM_Z4_Couronne", 2.4)
		L.itemLabel(p.carried.model, false)
		p:follow(HP, 0)
		p:play("Run", { fade = 0 })
		p:play("CarryRun", { fade = 0 })
		local leg = (Rarities.ById.Legendary or {}).Color or Color3.fromHex("#FFC21A")
		S.leg = leg
	end,
	update = function(S, t)
		local p = S.actors.p1
		if t <= 3.4 then p:follow(HP, t) end
		once(S, "stop", t, 3.4, function() p:stop("Run", 0.15) p:play("CarryIdle", { fade = 0.15 }) end)
		once(S, "escape", t, 2.0, function()
			local m = L.prop("FX", "FX_Escape")
			m:PivotTo(CFrame.new(V(24, 3, 3)))
			tintAndArm(S, m, 2.0, S.leg)
		end)
		once(S, "fw", t, 2.1, function()
			for _, n in { "FireworksPoint_N", "FireworksPoint_S" } do
				local pt = workspace.Map:FindFirstChild(n, true)
				local m = L.prop("FX", "FX_Fireworks")
				m:PivotTo(CFrame.new(pt.Position))
				tintAndArm(S, m, 2.1, S.leg)
			end
		end)
		stepEmits(S, t)
	end,
})

------------------------------------------------------------------------------------------------
-- Réglages du repérage du 26/11 au soir (capture interne de Studio, plan par plan) : caméras et figurants corrigés.
------------------------------------------------------------------------------------------------
do
	local function setCam(name, cam)
		local sh = T.shots["L_" .. name .. "_h"]
		sh._cam0 = nil
		sh.cam = cam
	end
	-- pieds : de côté, et non de dos
	setCam("B_tapis_pieds", M.orbit({ center = TM3 + V(0, 1.4, 0), radius = 7.5, height = 0.2, from = 70, to = 110, dur = 3.5, ease = "linear", fov = 44 }))
	-- tapis du hub : plus serré, moins de pelouse
	setCam("B_tapis_hub", M.path({ keys = { { 0, V(-92, 3.6, 48), V(-66.6, 3.2, 167.8) }, { 4.5, V(-92, 3.6, 48), V(-151.7, 3.2, 15.4) } }, ease = "sine", fov = 26 }))
	-- poursuite de face : décalages dans le repère du héros (z < 0 = devant lui), côté rue pour voir le vigile derrière
	setCam("B_poursuite_face", M.follow({ actor = "p1", offset = V(4.5, 1.4, -14), offsetTo = V(3.5, 1.2, -11), dur = 3.6, ease = "sine", lookOffset = V(1.5, 3.6, 6), lag = 0.1, fov = 58 }))
	setCam("B_mythique", M.follow({ actor = "p1", offset = V(6.5, 1.2, -14), offsetTo = V(4.5, 1.0, -11), dur = 3.6, ease = "sine", lookOffset = V(1, 4.8, 2), lag = 0.12, fov = 60 }))
	-- survols : au-dessus de la rue (et non des toits du côté sud), moins plongeants
	local function sv(name, a, b, look, dur)
		setCam(name, function(t) local p = a:Lerp(b, math.clamp(t / dur, 0, 1)) return p, p + look, 55 end)
	end
	sv("B_survol_a", V(60, 48, -22), V(210, 48, -22), V(45, -28, 60), 5)
	sv("B_survol_b", V(570, 48, 22), V(420, 48, 22), V(-45, -28, -60), 5)
	sv("B_survol_c", V(730, 54, -22), V(840, 54, -22), V(45, -30, 60), 4.5)
	-- témoins : caméra reculée, la passante passe près des vitrines, dans l'autre sens
	setCam("B_temoins", M.travelling({ from = V(163, 4.8, 31), look = V(175, 4.4, 49), dir = "droite", dist = 4, dur = 4, ease = "linear", fov = 46 }))
	do
		local sh = T.shots.L_B_temoins_h
		local s0 = sh.setup
		sh.setup = function(S)
			s0(S)
			S.path = { { 0, V(188, 0, 46.6) }, { 4, V(166, 0, 46.6) } }
			S.actors.c:follow(S.path, 0)
			L.toVisibleGround(S.actors.c)
		end
	end
	-- vendeur d'armes : plus haut et plus loin (il était caché derrière son comptoir)
	setCam("B_vendeurs", M.travelling({ from = V(-16, 9, 78), look = V(11.5, 6.2, 85), dir = "gauche", dist = 8, dur = 4, ease = "sine", fov = 32 }))
	-- camion : caméra reculée, le toit entier
	setCam("B_camion", function(t, S) local tp = S.truckPos or V(292, 0, -14) return V(292, 3.6, 30), tp + V(0, 6.5, 0), 50 end)
	-- hub : arc plus serré, et des passants qui traversent la pelouse
	setCam("B_hub_survol", M.orbit({ center = V(-150, 4, 0), radius = 120, height = 38, from = 20, to = -20, dur = 5, ease = "linear", fov = 46 }))
	do
		local sh = T.shots.L_B_hub_survol_h
		local s0, u0 = sh.setup, sh.update
		local WALK = {
			{ "lavande", V(-90, 0, -40), V(-125, 0, -10) }, { "tresses", V(-150, 0, 35), V(-115, 0, 20) },
			{ "brune", V(-100, 0, 25), V(-130, 0, 45) }, { "bacon_jean", V(-160, 0, -30), V(-125, 0, -45) },
			{ "blond", V(-80, 0, 5), V(-105, 0, -25) },
		}
		sh.setup = function(S)
			s0(S)
			S.hw = {}
			for i, w in WALK do
				local a = L.fresh("hubwalk" .. i, w[1])
				local keys = { { 0, w[2] }, { 5, w[3] } }
				a:follow(keys, 0)
				L.toVisibleGround(a)
				a:play("Walk", { fade = 0, looped = true })
				S.hw[i] = { a = a, k = keys }
			end
		end
		sh.update = function(S, t)
			u0(S, t)
			for _, w in S.hw do w.a:follow(w.k, t) L.toVisibleGround(w.a) end
		end
	end
	-- boutique pleine : la fin reste au-dessus de l'intérieur (elle butait sur l'enseigne bleue)
	setCam("B_boutique_pleine", M.path({ keys = { { 0, V(-57.5, 5.4, 191.5), V(-66, 4.6, 184) }, { 4.5, V(-50, 15, 197), V(-70, 3, 180) } }, ease = "sine", fov = 56 }))
end

-- 06a sans HUD pour la banque : on retire l'habillage « compteur d'argent » du plan argent_plaque (remis par L.cashOn)
function L.cashOff()
	for _, f in { "h", "v" } do
		local sh = T.shots["L_argent_plaque_" .. f]
		if sh and sh._setupCash then sh.setup, sh.update = sh._setupCash, sh._updateCash end
	end
end
L.cashOff()

L.BANQUE = {
	"L_B_boutiques_tout_h",
	"L_tapis_orbite2_h", "L_B_tapis_pieds_h", "L_B_tapis_hub_h",
	"L_poursuite_z4_h", "L_B_poursuite_face_h", "L_vigile_surgit_h",
	"L_B_survol_a_h", "L_B_survol_b_h", "L_B_survol_c_h", "L_B_temoins_h", "L_B_vendeurs_h", "L_B_camion_h", "L_B_hub_survol_h",
	"L_casse_orbite_h", "L_braquage_batte_h", "L_rideau_monte_h", "L_vigile_fige_h", "L_colis_legendaire_h", "L_colis_rate_h",
	"L_argent_plaque_h", "L_boutique_pose_h", "L_B_boutique_pleine_h",
	"L_facade_bijouterie_h", "L_B_ronde_bijouterie_h",
	"L_B_ligne_safe_h", "L_B_mythique_h",
	"L_nuit_mur_h",
}
local tot = 0
for _, n in L.BANQUE do
	local sh = T.shots[n]
	assert(sh, "plan absent : " .. n)
	tot += sh.dur
end
return ("banque : %d plans, %.1f s d'images"):format(#L.BANQUE, tot)
