--!nocheck
-- Trailer de lancement v6, version du 27/11 (coupes_v6_2711.csv, validée par le Chef de projet le 27/11).
-- Charger après shots_pieds.luau et shots_poursuite_rapide.luau. Ce fichier :
--   - met la Couronne (Z4_Couronne) chez l'ami (règle de Clément : un seul objet volé dans le trailer), à la place du
--     Croissant requin ;
--   - vol_ami : la saisie arrive 0,5 s plus tard (le plan commence sur le présentoir), puis le héros ressort en courant à
--     la vitesse du jeu (67,9 studs/s) par la porte dont la vitre vient d'être cassée (braquage_porte), cachée ici ;
--     chemin dégagé du présentoir au trottoir (rayons du 27/11) ;
--   - porte_zone4 : le héros passe la porte de la zone 6 (ZoneGate_6, x = 718) à 67,9 studs/s, la porte à 1 s du plan ;
--     rue dégagée de x = 650 à 860 (z = -10) ; caméra qui suit de près, secousse d'épaule ;
--   - L.V6_H et L.V6_V : les 9 plans à tourner, en 16:9 et en 9:16.
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def and L.CHASE_SPEEDS, "charger shots_poursuite_rapide.luau d'abord")
local V = Vector3.new
local M = T.moves
local def = L.def
local HERO_V = L.CHASE_SPEEDS.hero
local RUN_REF = 20
local function runSpeed(a, v)
	local s = 1
	pcall(function() s = a.model:GetScale() end)
	return v / (RUN_REF * s)
end
local function store(name) local x = workspace.Map:FindFirstChild(name, true) assert(x, "introuvable : " .. name) return x end

-- l'objet du héros partout ailleurs (L.HERO_ITEM, la Cosmic Crown de la v5) : ITM_Z4_Couronne n'est qu'un nom de
-- remplacement que L.prop échange, alors que vol_ami charge son modèle directement (L._propItem0)
L.FRIEND_ITEM = L.HERO_ITEM or "Z6_CouronneCosmique"

-- vol_ami : on garde le plan (caméra réglée le 26/11, l'ami au fond) et on décale son horloge de 0,5 s
local SHIFT = 0.5
for _, f in { "h", "v" } do
	local sh = T.shots["L_vol_ami_" .. f]
	assert(sh, "L_vol_ami_" .. f .. " absent")
	local s0 = sh._setup2711 or sh.setup
	local u0 = sh._update2711 or sh.update
	sh._setup2711, sh._update2711 = s0, u0
	sh.setup = function(S)
		s0(S)
		local plot = store(L.FRIEND_PLOT)
		local door = plot:FindFirstChild("PlotDoor")
		if door and door:FindFirstChild("Window") then L.hide(door.Window) end
		local pt = L.plotMap(L.FRIEND_PLOT)
		local a0, door0, outside = pt(V(-64.4, 0, 182.2)), pt(V(-42.5, 0, 178.5)), pt(V(-42, 0, 169))
		local t1 = 0.55 + (door0 - a0).Magnitude / HERO_V
		local t2 = t1 + (outside - door0).Magnitude / HERO_V
		S.out = { { 0.55, a0 }, { t1, door0 }, { t2, outside }, { 9, outside } }
		S.chase = {}
	end
	sh.update = function(S, t)
		local tt = t - SHIFT
		if tt < 0 then return end
		local a = S.actors.p1
		u0(S, tt)
		if tt >= 0.55 and not S._fast then
			S._fast = true
			local tr = a.tracks and a.tracks.Run
			if tr then tr:AdjustSpeed(runSpeed(a, HERO_V)) end
		end
		if tt >= 0.7 and not S.chase.p0 then S.chase.p0, S.chase.t0 = a.model:GetPivot().Position, tt end
		if S.chase.p0 and tt <= 0.82 and tt > S.chase.t0 then
			L.chaseMeasured = L.chaseMeasured or {}
			L.chaseMeasured.vol_ami = { hero = ((a.model:GetPivot().Position - S.chase.p0) * V(1, 0, 1)).Magnitude / (tt - S.chase.t0) }
		end
	end
end

-- porte_zone4 : à la vitesse du jeu, la porte de la zone 6 passée à 1 s
local XG, DUR = 718, 3
local P05 = { { 0, V(XG - HERO_V * 1.0, 0, -10) }, { DUR, V(XG + HERO_V * (DUR - 1.0), 0, -10) } }
def("porte_zone4", {
	dur = DUR,
	cam = function() return M.handheld(M.follow({ actor = "p1", offset = V(1.5, 2.2, 9), offsetTo = V(1.5, 2.4, 10.5), dur = DUR, ease = "linear", lookOffset = V(10, 2, 0), lag = 0.03, fov = 56 }), { amp = 0.16, look = 0.32, freq = 2.4, seed = 21 }) end,
	setup = function(S)
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		p:follow(P05, 0)
		p:play("Run", { fade = 0, speed = runSpeed(p, HERO_V) })
		S.chase = {}
	end,
	update = function(S, t)
		local p = S.actors.p1
		p:follow(P05, t)
		local pp = p.model:GetPivot().Position
		if t >= 0.3 and not S.chase.p0 then S.chase.p0, S.chase.t0 = pp, t end
		if S.chase.p0 and t > S.chase.t0 then
			L.chaseMeasured = L.chaseMeasured or {}
			L.chaseMeasured.porte_zone4 = { hero = ((pp - S.chase.p0) * V(1, 0, 1)).Magnitude / (t - S.chase.t0) }
		end
	end,
})

local NAMES = { "tapis_orbite2", "porte_zone4", "casse_orbite", "colis_legendaire", "vigile_surgit", "poursuite_z4", "argent_plaque", "braquage_porte", "vol_ami" }
L.V6_H, L.V6_V = {}, {}
for _, n in NAMES do
	assert(T.shots["L_" .. n .. "_h"] and T.shots["L_" .. n .. "_v"], "plan absent : " .. n)
	table.insert(L.V6_H, "L_" .. n .. "_h")
	table.insert(L.V6_V, "L_" .. n .. "_v")
end
return ("v6 du 27/11 : %d plans × 2 formats ; objet de l'ami : %s"):format(#NAMES, L.FRIEND_ITEM)
