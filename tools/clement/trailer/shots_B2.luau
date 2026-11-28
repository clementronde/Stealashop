--!nocheck
-- Vidéo B v2 (Clément, 27/11) : 3 plans neufs. À charger après trailer_lib, shots_lancement, shots_banque, shots_pieds.
--   B2_ratee_bugs   : l'allée ratée (Workspace/_PREVIEW_ALLEE_RATEE, du chef Map) avec des PNJ « buggés » : T-pose, glisse sans
--                     animation, à moitié dans le mur, tremble, flotte, enfoncé dans le sol. Voulu, et seulement ici : ces
--                     figurants sont marqués a.air (la correction des pieds de shots_pieds ne les touche pas).
--   B2_vraie_pnj    : notre couloir, même travelling que 04_notre_allee, avec des passants qui marchent vraiment (Walk des
--                     témoins à v / Witness.WalkAnimSpeed) ; correction des pieds active.
--   B2_couronne     : la ligne safe : le héros arrive avec la Cosmic Crown, franchit la ligne, s'arrête et fait la joie
--                     (L.JOY_ANIM, à donner par le chef animation) ; le vigile le talonne, agrandi de L.GUARD_SCALE (1,5) sur
--                     notre copie seulement si le modèle du jeu n'a pas encore sa nouvelle taille ; l'effet d'arrivée est
--                     L.ARRIVAL_FX (à donner par le chef VFX ; sinon FX_Escape, celui du jeu aujourd'hui).
local T = _G.Trailer
local L = T.launch
assert(T and L and L.def, "charger trailer_lib et shots_lancement d'abord")
local V = Vector3.new
local M = T.moves
local def = L.def
local RS = game:GetService("ReplicatedStorage")
local Assets = RS.Assets
local W = require(RS.Shared.Config.Witness)
local WALK_ANIM = W.WalkAnimSpeed or 10
local function once(S, key, t, at, fn) if t >= at and not S["_" .. key] then S["_" .. key] = true fn() end end
local function lin(a, b, dur) return { { 0, a }, { dur, b } } end
local rng = Random.new(7)

L.JOY_ANIM = L.JOY_ANIM or "Cheer" -- Chef de projet, 27/11 : la vraie joie ira dans Assets/Animations/Player/Cheer (pas encore faite) ;
-- en attendant, la copie du héros reçoit le Cheer de la foule (NPC_Crowd_01/Animations/Cheer), sur notre copie seulement
L.ARRIVAL_FX = L.ARRIVAL_FX or "FX_Escape_v2" -- Chef de projet, 27/11 : FX_Escape_v2 pour la prise (repli : FX_Escape)
L.GUARD_SCALE = L.GUARD_SCALE or 1.5

-- T-pose : épaules à 90° sur la copie (Motor6D.Transform, sans animation qui l'écrase)
local function tpose(a)
	for _, n in { "LeftShoulder", "RightShoulder" } do
		local j = a.model:FindFirstChild(n, true)
		if j and j:IsA("Motor6D") then
			j.Transform = CFrame.Angles(0, 0, if n == "LeftShoulder" then -math.pi / 2 else math.pi / 2)
		end
	end
end

------------------------------------------------------------------------------------------------
-- 1. L'allée ratée, PNJ buggés (sol à y = 50, axe x de 600 à 1438, murs à z = -2660 et -2540)
------------------------------------------------------------------------------------------------
local AZ, AY = -2600, 50
local BUG = {
	-- id, témoin copié, position (x, z), défaut, paramètre
	{ "bug1", "NPC_Witness_Z1_01", 650, -2585, "tpose" },
	-- (27/11, au tournage) rue entre les bordures z = -2582 et -2618, façades à z = -2575,5 (nord) et -2625,5 (sud) ;
	-- les murs à -2660 et -2540 sont cachés derrière les boutiques : les « mur » vont dans une façade
	{ "bug2", "NPC_Witness_Z2_02", 690, -2614, "glisse", V(0, 0, 9) },           -- glisse de 9 studs vers +z, figé
	{ "bug3", "NPC_Witness_Z3_01", 751, -2575.6, "mur" },                         -- à moitié dans la façade de Shop_31 (nord)
	{ "bug4", "NPC_Witness_Z4_02", 760, -2606, "tremble" },
	{ "bug5", "NPC_Witness_Z5_01", 795, -2590, "flotte", 0.6 },
	{ "bug6", "NPC_Witness_Z6_02", 830, -2612, "enfonce", 1.6 },                  -- jusqu'aux genoux
	{ "bug7", "NPC_Witness_Z2_01", 803, -2625.6, "mur" },                         -- à moitié dans la façade de Shop_7 (sud)
	{ "bug8", "NPC_Witness_Z1_02", 900, -2596, "tpose_tourne" },                  -- T-pose qui tourne sur lui-même
}
local RATEE_DUR = 6
def("B2_ratee_bugs", {
	dur = RATEE_DUR,
	cam = function() return function(t) local p = V(600 + 30 * t, AY + 5.5, AZ) return p, p + V(1, 0, 0), 70 end end,
	setup = function(S)
		L.hideHumans()
		S.bugs = {}
		for _, b in BUG do
			local a = L.fresh(b[1], "witness:" .. b[2])
			a.air = true -- les pieds ne sont pas corrigés : le défaut est voulu
			local base = V(b[3], AY, b[4])
			local y = AY + a.hum.HipHeight + a.root.Size.Y / 2
			local kind = b[5]
			if kind == "flotte" then y += b[6] elseif kind == "enfonce" then y -= b[6] end
			local face = (V(600, 0, AZ) - V(b[3], 0, b[4])) * V(1, 0, 1)
			if kind == "mur" then face = V(1, 0, 0) end
			a.cf = CFrame.lookAt(V(b[3], y, b[4]), V(b[3], y, b[4]) + face.Unit)
			a.model:PivotTo(a.cf)
			if kind == "tpose" or kind == "glisse" or kind == "tpose_tourne" or kind == "mur" then tpose(a) end
			if kind == "flotte" or kind == "enfonce" or kind == "tremble" then a:play("Idle", { fade = 0, looped = true }) end
			S.actors[b[1]] = a
			table.insert(S.bugs, { a = a, kind = kind, cf0 = a.cf, p = b[6] })
		end
	end,
	update = function(S, t)
		for _, b in S.bugs do
			if b.kind == "glisse" then
				b.a.cf = b.cf0 + b.p * math.clamp(t / RATEE_DUR, 0, 1)
				b.a.model:PivotTo(b.a.cf)
				tpose(b.a)
			elseif b.kind == "tremble" then
				-- saccades : un nouveau décalage toutes les 2 images
				if not b.next or t >= b.next then
					b.next = t + 2 / 60
					b.off = CFrame.new(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.25, 0.25)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
				end
				b.a.model:PivotTo(b.cf0 * b.off)
			elseif b.kind == "tpose_tourne" then
				b.a.model:PivotTo(b.cf0 * CFrame.Angles(0, t * 2.2, 0))
				tpose(b.a)
			elseif b.kind == "tpose" or b.kind == "mur" then
				tpose(b.a)
			end
		end
	end,
})

------------------------------------------------------------------------------------------------
-- 2. Notre couloir avec de vrais passants (même caméra que 04_notre_allee : y = 5,5, 30 studs/s, vers +x)
------------------------------------------------------------------------------------------------
local VRAI_DUR = 7
local VRAIS = {
	{ "NPC_Witness_Z1_01", 70, -46, 1 }, { "NPC_Witness_Z1_02", 95, 46.5, -1 }, { "NPC_Witness_Z2_01", 130, -45.5, -1 },
	{ "NPC_Witness_Z2_02", 160, 45.8, 1 }, { "NPC_Witness_Z3_01", 190, -46.4, 1 }, { "NPC_Witness_Z3_02", 215, 46.2, -1 },
	{ "NPC_Witness_Z4_01", 240, -45.8, -1 }, { "NPC_Witness_Z5_02", 265, 46.6, 1 },
}
def("B2_vraie_pnj", {
	dur = VRAI_DUR,
	cam = function() return function(t) local p = V(30 + 30 * t, 5.5, 0) return p, p + V(1, 0, 0), 70 end end,
	setup = function(S)
		L.hideHumans()
		S.walk = {}
		local v = W.WalkSpeed or 6
		for i, w in VRAIS do
			local a = L.fresh("vrai" .. i, "witness:" .. w[1])
			a.air = nil
			local keys = lin(V(w[2], 0, w[3]), V(w[2] + w[4] * v * VRAI_DUR, 0, w[3]), VRAI_DUR)
			a:follow(keys, 0)
			L.toVisibleGround(a)
			a:play("Walk", { fade = 0, looped = true, speed = v / WALK_ANIM })
			S.actors["v" .. i] = a
			S.walk[i] = { a = a, k = keys }
		end
	end,
	update = function(S, t)
		for _, w in S.walk do w.a:follow(w.k, t) L.toVisibleGround(w.a) end
	end,
})

------------------------------------------------------------------------------------------------
-- 3. L'arrivée avec la couronne, à la ligne safe (x ≈ 24) : le héros entre dans le hub vers -x, s'arrête et fait la joie ;
-- le vigile le talonne et s'arrête à la ligne
------------------------------------------------------------------------------------------------
local CDUR = 5
local HP = { { 0, V(58, 0, 3) }, { 2.4, V(10, 0, 3) } }
local GP = { { 0, V(70, 0, 4.5) }, { 2.2, V(30, 0, 4.5) }, { 2.6, V(28.5, 0, 4.5) } }
def("B2_couronne", {
	dur = CDUR,
	cam = function() return M.path({ keys = { { 0, V(-6, 4.2, 12), V(40, 4.6, 3) }, { CDUR, V(-4, 5.2, 13), V(16, 5.6, 2) } }, ease = "sine", fov = 54 }) end,
	setup = function(S)
		L.hideHumans()
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		-- joie : si Assets/Animations/Player n'a pas encore la sienne, le Cheer de la foule sur notre copie
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
		p:play("Run", { fade = 0 })
		p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z1", "guard:Guard_Z1")
		S.actors.g1 = g
		-- 1,5 fois plus grand, sur notre copie seulement (le modèle de Assets/Guards n'est pas touché)
		if L.GUARD_SCALE and L.GUARD_SCALE ~= 1 and not g._scaled then
			g.model:ScaleTo(g.model:GetScale() * L.GUARD_SCALE)
			g._scaled = true
		end
		g:follow(GP, 0)
		g:play("Run", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	end,
	update = function(S, t)
		local p, g = S.actors.p1, S.actors.g1
		if t <= 2.4 then p:follow(HP, t) end
		g:follow(GP, math.min(t, 2.6))
		once(S, "fx", t, 1.4, function()
			local name = if Assets.FX:FindFirstChild(L.ARRIVAL_FX, true) then L.ARRIVAL_FX else "FX_Escape"
			local m = L.prop("FX", name)
			m:PivotTo(CFrame.new(V(24, 3, 3)))
			for _, e in m:GetDescendants() do
				if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 10) end
			end
		end)
		once(S, "stop", t, 2.4, function()
			p:stop("Run", 0.15)
			p:stop("CarryRun", 0.15)
			if L.JOY_ANIM then p:play(L.JOY_ANIM, { fade = 0.15, looped = true }) else p:play("CarryIdle", { fade = 0.15 }) end
		end)
		once(S, "gstop", t, 2.6, function() g:stop("Run", 0.2) g:play("Idle", { fade = 0.2 }) end)
	end,
})

L.B2 = { "L_B2_ratee_bugs_h", "L_B2_vraie_pnj_h", "L_B2_couronne_h" }
return "B v2 : 3 plans (" .. RATEE_DUR + VRAI_DUR + CDUR .. " s)"
