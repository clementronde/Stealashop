--!nocheck
-- Reconstruction des 5 plans ratés de la banque (26/11 nuit) : braquage_batte, rideau_monte, colis_rate, boutique_pose,
-- nuit_mur. Leur mise en scène était restée provisoire (caméra en (0, 10, 0)) depuis le chargement allégé de
-- shots_lancement.luau après le redémarrage de Studio. Ce fichier recopie tels quels leurs blocs de shots_lancement.luau
-- (définition + corrections du 25/11 + zone 6 pour le rideau), avec les petites aides locales dont ils ont besoin.
-- À charger après trailer_lib, shots_lancement (même allégé), shots_banque, puis shots_pieds (qui branche les pieds).
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def, "charger trailer_lib et shots_lancement d'abord")
local V = Vector3.new
local M = T.moves
local def = L.def
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local function store(name) local s = workspace.Map:FindFirstChild(name, true) assert(s, "introuvable dans la Map : " .. name) return s end
local function once(S, key, t, at, fn) if t >= at and not S["_" .. key] then S["_" .. key] = true fn() end end
local function fxFolder()
	local r = T.root()
	local f = r:FindFirstChild("FX")
	if not f then f = Instance.new("Folder") f.Name = "FX" f.Parent = r end
	return f
end
local function strip(m) for _, d in m:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end end
local function freeze(m)
	local list = m:GetDescendants() table.insert(list, m)
	for _, d in list do if d:IsA("BasePart") then d.Anchored = true d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end end
end
local function ease(name, u) return (T.ease[name] or T.ease.linear)(math.clamp(u, 0, 1)) end
local function fov(fmt, base) return base end
local PLOT1_SLOT1 = V(-66, 2.7, 184)
local ITEM = "ITM_Z4_Couronne"
local HERO = "bacon"

-- braquage_batte (shots_lancement 626-671)
local A20 = { { 0, V(-50, 0, 192) }, { 0.8, V(-46.5, 0, 183) } }
def("braquage_batte", {
	dur = 2.6,
	cam = function(fmt)
		return M.shake(M.orbit({ center = V(-46, 2.6, 182), radius = 8, height = 0, from = 200, to = 165, dur = 2.6, ease = "sine", fov = fov(fmt, 48) }), { atKey = "hitAt", dur = 0.3, amp = 0.3 })
	end,
	setup = function(S)
		local thief = L.fresh("ami", "bacon_guitare")
		S.actors.p1 = thief
		L.carry(thief, "ITM_Z4_Couronne", 2.5)
		thief:follow(A20, 0)
		thief:play("Run", { fade = 0 })
		thief:play("CarryRun", { fade = 0 })
		local owner = L.fresh("proprio", "bacon")
		S.actors.p2 = owner
		L.hold(owner, "Tools", "TOOL_Batte")
		owner:place(V(-43.5, 0, 180.5), V(-1, 0, 0.6))
		owner:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		local thief, owner = S.actors.p1, S.actors.p2
		if t < 0.8 then thief:follow(A20, t) end
		once(S, "swing", t, 0.55, function()
			owner:play("SwingBat", { looped = false, fade = 0.05 })
		end)
		once(S, "hit", t, 0.8, function()
			S.hitAt = t
			thief:stop("Run", 0.05)
			thief:stop("CarryRun", 0.05)
			thief:play("Knockdown", { looped = false, fade = 0.05 })
			-- l'objet tombe : il quitte la tête et roule au sol
			if thief.carried then
				S.dropped = thief.carried.model
				S.dropFrom = S.dropped:GetPivot()
				thief.carried = nil
			end
		end)
		if S.dropped then
			local u = math.clamp((t - S.hitAt) / 0.6, 0, 1)
			local base = S.dropFrom.Position
			local land = A20[2][2] + V(-2.5, 0.8, -2)
			local p = base:Lerp(land, u) + V(0, math.sin(math.pi * u) * 2, 0)
			S.dropped:PivotTo(CFrame.new(p) * CFrame.Angles(u * 4, u * 2, 0))
		end
	end,
})
for _, f in { "h", "v" } do
	T.shots["L_braquage_batte_" .. f].cam = M.shake(M.orbit({ center = V(-45.3, 3.2, 182), radius = 12, height = 0.8, from = 325, to = 295, dur = 2.6, ease = "sine", fov = 48, lookUp = 2.2 }), { atKey = "hitAt", dur = 0.3, amp = 0.3 })
	local sh = T.shots["L_braquage_batte_" .. f]
	local s0 = sh.setup
	sh.setup = function(S)
		s0(S)
		for _, a in S.actors do L.toVisibleGround(a) end
		if S.actors.p1.carried then L.itemLabel(S.actors.p1.carried.model, true) end
	end
end
-- boutique_pose (shots_lancement 532-564, 833-858, caméra 1220)
local P15 = { { 0, V(-58, 0, 173.5) }, { 1.2, V(-66, 0, 180.6) } }
def("boutique_pose", {
	dur = 3,
	cam = function(fmt)
		return M.orbit({ center = PLOT1_SLOT1 + V(0, 0.6, -1.5), radius = 9, height = 1, from = 250, to = 290, dur = 3, ease = "sine", fov = fov(fmt, 48) })
	end,
	setup = function(S)
		local plot = store("PLOT_Shop_01")
		L.fillPlot(plot, { [1] = true })
		local p = L.fresh("proprio", "bacon")
		S.actors.p1 = p
		L.carry(p, "ITM_Z4_Couronne", 2.5)
		p:follow(P15, 0)
		p:play("Walk", { fade = 0 })
		p:play("CarryIdle", { fade = 0 })
	end,
	update = function(S, t, dt)
		local p = S.actors.p1
		if t < 1.2 then p:follow(P15, t) end
		once(S, "place", t, 1.2, function()
			p:stop("Walk", 0.1)
			p:stop("CarryIdle", 0.1)
			p:place(P15[2][2], V(0, 0, 1))
			p:play("Place", { looped = false, fade = 0.1 })
		end)
		once(S, "drop", t, 1.65, function()
			if p.carried then p.carried.model:Destroy() p.carried = nil end
			local m = L.prop("Items", "ITM_Z4_Couronne", 2.5)
			L.setOn(m, PLOT1_SLOT1, 180)
			L.emit("FX_Unbox_Reveal", CFrame.new(PLOT1_SLOT1 + V(0, 1.2, 0)), 0.6)
		end)
	end,
})
local P15b = { { 0, V(-48, 0, 180.6) }, { 1.2, V(-65.2, 0, 180.6) } } -- à l'intérieur, le long de la façade, depuis la porte (x = -42)
for _, f in { "h", "v" } do
	local sh = T.shots["L_boutique_pose_" .. f]
	sh.setup = function(S)
		L.fillPlot(store("PLOT_Shop_01"), { [1] = true })
		local p = L.fresh("proprio", "bacon")
		S.actors.p1 = p
		L.carry(p, ITEM, 2.5)
		p:follow(P15b, 0) p:play("Walk", { fade = 0 }) p:play("CarryIdle", { fade = 0 })
	end
	sh.update = function(S, t, dt)
		local p = S.actors.p1
		if t < 1.2 then p:follow(P15b, t) end
		once(S, "place", t, 1.2, function()
			p:stop("Walk", 0.1) p:stop("CarryIdle", 0.1)
			p:place(V(-66, 0, 180.6), V(0, 0, 1))
			p:play("Place", { looped = false, fade = 0.1 })
		end)
		once(S, "drop", t, 1.65, function()
			if p.carried then p.carried.model:Destroy() p.carried = nil end
			local m = L.prop("Items", ITEM, 2.5)
			L.setOn(m, PLOT1_SLOT1, 180)
			L.emit("FX_Unbox_Reveal", CFrame.new(PLOT1_SLOT1 + V(0, 1.2, 0)), 0.6)
		end)
	end
end
for _, f in { "h", "v" } do
	T.shots["L_boutique_pose_" .. f].cam = M.orbit({ center = V(-64.5, 3.2, 182), radius = 9.5, height = 1.0, from = 215, to = 175, dur = 3, ease = "sine", fov = 48, lookUp = 1.2 })
end
-- nuit_mur (shots_lancement 571-601, 1189-1214)
def("nuit_mur", {
	dur = 3,
	cam = function(fmt)
		return M.path({ keys = { { 0, V(36, 2.5, -26), V(27, 6, 0) }, { 3, V(58, 34, -34), V(27, 10, 0) } }, ease = "inQuad", fov = fov(fmt, 50) })
	end,
	setup = function(S)
		local real = workspace.Map.Entry:FindFirstChild("NightWall")
		local copy = real:Clone()
		strip(copy)
		freeze(copy)
		copy.Parent = fxFolder()
		S.wall = { m = copy, down = real:GetPivot(), up = real:GetPivot() + V(0, 24, 0) } -- NightWall est un Model
		local g = L.fresh("vigile_nuit", "guard:NightGuard")
		S.actors.g1 = g
		g:place(V(40, 0, -12), V(-1, 0, 0.3))
		g:play("Idle", { fade = 0 })
		local p = L.fresh("figurant_nuit", "bacon_jean")
		S.actors.p1 = p
		p:place(V(36, 0, -10.8), V(1, 0, -0.3))
		p:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		local w = S.wall
		w.m:PivotTo(w.down:Lerp(w.up, ease("outCubic", (t - 0.2) / 1.2)))
		once(S, "arrest", t, 1.2, function()
			S.actors.g1:play("Arrest", { looped = false, fade = 0.1 })
			S.actors.p1:stop("Idle", 0.1)
			S.actors.p1:play("Arrested", { looped = false, fade = 0.1 })
		end)
	end,
})
local GPn = { { 0, V(38.6, 0, -15.5) }, { 1.1, V(40.2, 0, -12.6) }, { 3, V(44.6, 0, -4.4) } }
local FPn = { { 0, V(41.5, 0, -9.2) }, { 1.0, V(41.5, 0, -9.2) }, { 3, V(47.5, 0, 1.5) } }
for _, f in { "h", "v" } do
	local sh = T.shots["L_nuit_mur_" .. f]
	local s0 = sh.setup
	sh.cam = M.path({ keys = { { 0, V(51, 3.4, -19), V(40.5, 3.6, -10) }, { 3, V(55, 9, -22.5), V(37, 6.5, -8) } }, ease = "linear", fov = 50 })
	sh.setup = function(S)
		s0(S)
		local g, p = S.actors.g1, S.actors.p1
		g:follow(GPn, 0) L.toVisibleGround(g)
		p:place(FPn[1][2], V(-0.4, 0, -1)) L.toVisibleGround(p)
		g:stop("Idle", 0)
		g:play("Walk", { fade = 0 })
	end
	sh.update = function(S, t, dt)
		local w = S.wall
		w.m:PivotTo(w.down:Lerp(w.up, ease("outCubic", (t - 0.2) / 1.2)))
		local g, p = S.actors.g1, S.actors.p1
		g:follow(GPn, t) L.toVisibleGround(g)
		if t >= 1.0 then p:follow(FPn, t) L.toVisibleGround(p) end
		once(S, "flee", t, 1.0, function()
			p:stop("Idle", 0.1) p:play("Run", { fade = 0.1 })
			g:stop("Walk", 0.15) g:play("Run", { fade = 0.15 })
		end)
	end
end
-- colis_rate (shots_lancement 728-750, 896-958)
local function crowbarTip(p)
	local m = p.held.model
	local rh = p.model:FindFirstChild("RightHand")
	local cf, size = m:GetBoundingBox()
	if not rh then return cf.Position end
	local hand = rh.Position
	local best, tip = -1, cf.Position
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local c = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
		local d = (c - hand).Magnitude
		if d > best then best, tip = d, c end
	end end end
	return tip
end
local function hideShelfGlass()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { T.root() }
	for _, y in { 3.2, 4.4 } do
		local g = workspace:Raycast(V(437, y, 77.5), V(-5, 0, 0), rp)
		if g and g.Instance.Name:match("Glass") then L.hide(g.Instance) end
	end
end
local BOX0 = V(434.15, 2.77, 77.5)
local OUT3 = V(435.5, 4.3, 77.0)
local RING_OUT = V(435.15, 3.55, 76.7)
local function boxShot3(boxName: string, itemName: string, scale: number, withGrab: boolean)
	return {
		dur = if withGrab then 3.2 else 2.6,
		cam = function()
			if withGrab then
				return M.path({ keys = {
					{ 0, V(439.6, 3.9, 71.8), BOX0 + V(0, 0.6, 0) },
					{ 1.6, V(439.4, 4.2, 72.0), BOX0 + V(0.5, 1.0, 0) },
					{ 3.2, V(441.6, 5.4, 70.2), V(435.9, 4.6, 78.2) },
				}, ease = "linear", fov = 48 })
			end
			return M.travelling({ from = V(439.6, 3.9, 71.8), look = BOX0 + V(0.3, 0.7, 0), dir = "avant", dist = 1.6, dur = 2.6, ease = "linear", fov = 45 })
		end,
		setup = function(S)
			hideShelfGlass()
			local p = L.fresh("ouvreur", HERO)
			S.actors.p1 = p
			L.hold(p, "Unbox", "TOOL_Unbox_Crowbar")
			local P = V(436.1, 0.52, 78.75) -- assez loin du rayon : les jambes accroupies s'arrêtent avant la planche (x = 434,6)
			p:place(P, (BOX0 - P) * Vector3.new(1, 0, 1))
			local tr = p:play("Unbox_Crowbar", { looped = false, fade = 0 })
			if tr.Length > 0 then tr.TimePosition = tr.Length * 0.45 end
			p.animator:StepAnimations(0)
			T.fx.updateCarry(p)
			local tip = crowbarTip(p)
			S.boxPos = V(math.clamp(tip.X, 433.6, 434.25), 2.77, math.clamp(tip.Z, 76.6, 78.4))
			p:stop("Unbox_Crowbar", 0)
			p.animator:StepAnimations(0)
			p:play("Idle", { fade = 0 })
			S.box = L.prop("Boxes", boxName)
			L.setOn(S.box, S.boxPos, 90)
		end,
		update = function(S, t, dt)
			local p = S.actors.p1
			once(S, "pry", t, 0.2, function() p:stop("Idle", 0.1) p:play("Unbox_Crowbar", { looped = false, fade = 0.1 }) end)
			once(S, "open", t, 1.3, function()
				S.box:Destroy()
				L.emit("FX_Unbox_Burst", CFrame.new(S.boxPos + V(0, 0.6, 0)))
				if withGrab then L.emit("FX_Unbox_Reveal", CFrame.new(OUT3)) end
				S.item = L.prop("Items", itemName, scale)
				S.openAt = t
			end)
			if S.item and not S.grabbed then
				local to = if withGrab then OUT3 - V(0, 0.4, 0) else RING_OUT
				L.setOn(S.item, S.boxPos:Lerp(to, ease("outBack", (t - S.openAt) / 0.55)), t * 140)
			end
			if withGrab then
				once(S, "grab", t, 2.2, function() p:play("Grab", { looped = false, fade = 0.08 }) end)
				once(S, "take", t, 2.55, function()
					S.grabbed = true
					S.item:Destroy()
					if p.held then p.held.model:Destroy() p.held = nil end
					L.carry(p, itemName, scale)
					p:play("CarryIdle", { fade = 0.1 })
				end)
			end
		end,
	}
end
def("colis_rate", boxShot3("BOX_Common", "ITM_Z4_Bague", 1.3, false))
-- rideau_monte, zone 6 (shots_lancement 2357-2370, 2393-2422)
do
	local D = V(376, 0, 0)
	local STORE6, GUARD6, TOOL6 = "STORE_Z6_Banque", "guard:Guard_Z6", "TOOL_Disqueuse"
	local function bank() return store(STORE6) end
	local function hideW6()
		local z = workspace.Map:FindFirstChild("Zone_6")
		local w = z and z:FindFirstChild("Witnesses")
		if w then L.hide(w) end
	end
	local function hero(id)
		local p = L.fresh(id or "braqueur", "bacon")
		L.hold(p, "Tools", TOOL6)
		return p
	end
	def("rideau_monte", {
		dur = 3,
		cam = function() return M.travelling({ from = V(442, 3, 26) + D, look = V(442, 7, 54.8) + D, dir = "avant", dist = 7, dur = 3, ease = "linear", fov = 50 }) end,
		setup = function(S)
			hideW6()
			local real = bank():FindFirstChild("Shutter")
			local copy = real:Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				end
			end
			copy.Parent = fxFolder()
			L.hide(real)
			for _, d in copy:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end end
			S.shutter = { m = copy, up = real:GetPivot(), down = real:GetPivot() - V(0, 11.8, 0) }
			copy:PivotTo(S.shutter.down)
			local p = hero()
			S.actors.p1 = p
			p:place(V(442, 0.4, 48.5) + D, V(0, 0, 1))
			p:play("Idle", { fade = 0 })
		end,
		update = function(S, t)
			local sh = S.shutter
			sh.m:PivotTo(sh.down:Lerp(sh.up, T.ease.outCubic(math.clamp((t - 0.4) / 1.2, 0, 1))))
		end,
	})
	-- la copie du rideau hérite de « caché » : forcée visible (correction du 25/11, 3e série)
	for _, f in { "h", "v" } do
		local sh = T.shots["L_rideau_monte_" .. f]
		local s0 = sh.setup
		sh.setup = function(S)
			s0(S)
			for _, p in S.shutter.m:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end end
		end
	end
end
-- Réglages du 26/11 nuit (repérage en capture interne) :
-- la batte : le voleur renversé (Knockdown, à 0,8 s) sort de la correction des pieds (a.air), sinon elle l'enfoncerait ;
-- la pose d'objet : orbite plus large (la couronne sortait par le haut).
for _, f in { "h", "v" } do
	local sh = T.shots["L_braquage_batte_" .. f]
	local u0, s0 = sh.update, sh.setup
	sh.update = function(S, t, dt)
		if t >= 0.8 and S.actors.p1 then S.actors.p1.air = true end
		u0(S, t, dt)
	end
	sh.setup = function(S)
		s0(S)
		if S.actors.p1 then S.actors.p1.air = nil end
	end
	local sp = T.shots["L_boutique_pose_" .. f]
	sp._cam0 = nil
	sp.cam = M.orbit({ center = V(-65.5, 3.4, 182.5), radius = 14, height = 2.6, from = 215, to = 180, dur = 3, ease = "sine", fov = 52, lookUp = 0.8 })
end
-- Bloc de reprise (pieds dans le sol + 5 plans ratés), dans l'ordre de tournage
L.REPRISE = {
	"L_tapis_orbite2_h", "L_B_tapis_pieds_h", "L_B_tapis_hub_h", "L_B_hub_survol_h",
	"L_poursuite_z4_h", "L_B_poursuite_face_h", "L_vigile_surgit_h", "L_B_mythique_h", "L_vigile_fige_h",
	"L_facade_bijouterie_h", "L_colis_legendaire_h", "L_argent_plaque_h",
	"L_S_z4_sortie_h", "L_S_z4_hola_cote_h", "L_S_z4_hola_face_h",
	"L_braquage_batte_h", "L_rideau_monte_h", "L_colis_rate_h", "L_boutique_pose_h", "L_nuit_mur_h",
}
-- les pieds : branchement sur les plans redéfinis (s'il est chargé, shots_pieds agit par T.fx.updateCarry : rien à faire)
return "5 plans reconstruits : braquage_batte, boutique_pose, nuit_mur, colis_rate, rideau_monte"
