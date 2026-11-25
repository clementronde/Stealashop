--!nocheck
-- Série « teaser » (2026-11-25), après le retour de Clément : « ça doit faire teasing, et montrer le vrai jeu ».
-- Tout suit references/vrai-jeu.md : vitrine en plusieurs coups (vrais PV de la zone, vraie puissance de l'outil),
-- colis qui saute au sol et s'ouvre en plusieurs actions, objets à la taille de leur poids avec leur étiquette, leur
-- halo et leur contour, écran RUN! et vigile en rouge, CAUGHT!, porte de boutique en 40 coups, éjection par la vitre
-- (version DEV). Des plans fixes où quelque chose bouge, et des mouvements de caméra de cinéma. Bruitages notés par
-- chaque événement (T.real.sfx) et posés au montage (mix_sfx.py) ; pas de musique.
-- À charger après trailer_lib.luau, shots_naturels.luau (troupe) et trailer_real.luau. Ordre : T.ORDER_TEASER.

local T = _G.Trailer
local R = T.real
local V = Vector3.new
local M = T.moves
local FAR = CFrame.new(0, -1000, 0)
local Sh = game:GetService("ReplicatedStorage").Shared
local Zones = require(Sh.Config.Zones)
local Tools = require(Sh.Config.Tools)
local ItemOdds = require(Sh.ItemOdds)
local Format = require(Sh.Format)
local function power(id: string): number
	return (Tools.ById or Tools)[id].Power -- Config/Tools : puissance de l'outil (dégâts d'un coup sans aura)
end

local function store(name: string): Model
	local s = workspace.Map:FindFirstChild(name, true)
	assert(s, "magasin introuvable : " .. name)
	return s
end
local function plot(n: number): Model
	return workspace.Map.Hub.Shops:FindFirstChild(("PLOT_Shop_%02d"):format(n))
end
local function once(S, key, t, at, fn)
	if t >= at and not S["_" .. key] then
		S["_" .. key] = true
		fn()
	end
end
local function cast(S, key, id, look, tool)
	local a = T.actor(id, look)
	a:reset()
	S.actors[key] = a
	if tool then T.fx.hold(a, tool) end
	return a
end
local function hand(move, amp, seed)
	local a = amp or 0.12
	return M.handheld(move, { amp = a, look = a * 2, freq = 0.55, seed = seed or 1 })
end
-- plan fixe : caméra posée, avec un souffle d'épaule à peine visible
local function still(pos, look, fov, seed)
	return M.handheld(M.wide({ pos = pos, look = look, drift = Vector3.zero, dur = 1, fov = fov or 50 }), { amp = 0.025, look = 0.05, freq = 0.4, seed = seed or 1 })
end
local function holdEnd(tr, at)
	if tr and tr.IsPlaying and tr.Length > 0 and tr.TimePosition >= tr.Length * (at or 0.95) then tr:AdjustSpeed(0) end
end
local function run(a, anim)
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
local function dropTool(a)
	if a.held then
		a.held.model:Destroy()
		a.held = nil
	end
end
local function broken(st, normal)
	local f = T.fx.breakWindow(st, { speed = 0.35, fadeAt = 1e6, noBurst = true, normal = normal })
	for _ = 1, 120 do f.step(1 / 30) end
end
local function slotPos(st, i)
	return st:FindFirstChild(("ShelfSlot_%02d"):format(i), true).WorldCFrame
end

-- Une rafale de coups sur une vitrine ou une porte, avec les vrais nombres.
-- spec = { target, hitters = { {key, anim, frac, first, period} }, hp, max, dmg, hitY, sound, onBreak(S, t) }
local function volley(S, t, spec)
	S.hp = S.hp or spec.hp
	for _, h in spec.hitters do
		local a = S.actors[h[1]]
		local k = 0
		while true do
			local start = h[4] + k * h[5]
			if start > t then break end
			local key = h[1] .. "_" .. k
			once(S, key .. "_go", t, start, function()
				if S.hp > 0 then a:play(h[2], { looped = false, fade = 0.05 }) end
			end)
			local impact = start + h[3]
			once(S, key .. "_hit", t, impact, function()
				if S.hp <= 0 then return end
				S.hp = math.max(0, S.hp - spec.dmg)
				local w = spec.target:FindFirstChild("Window") or spec.target
				local wp = if w:IsA("BasePart") then w.Position else w:GetPivot().Position
				local ap = a.cf.Position
				local hitPos = V(ap.X, spec.hitY or 4.2, ap.Z):Lerp(V(ap.X, spec.hitY or 4.2, wp.Z), 0.92)
				if spec.alongX then hitPos = V(wp.X, spec.hitY or 4.2, ap.Z) end -- vitre perpendiculaire à x (porte de boutique)
				R.glassHit(S, spec.target, hitPos, ap, spec.dmg, S.hp, spec.max, S.bar)
				R.sfx(S, spec.sound or "HitWindow_Impact")
				if S.hp <= 0 then spec.onBreak(S, t, a) end
			end)
			k += 1
		end
	end
end

------------------------------------------------------------------------------------------------
-- 1. Plan fixe : trois joueurs cassent la vitrine du Kiosque aux poings (15 PV, 1 dégât par coup), SMASHED!
------------------------------------------------------------------------------------------------
local K1 = { c1 = V(69.5, 0.4, -50.3), c2 = V(74.5, 0.4, -50.6), c3 = V(79.5, 0.4, -50.3) }
local IN1 = { c1 = { { 0, V(67, 0, -68) } }, c2 = { { 0, V(74, 0, -72) } }, c3 = { { 0, V(82, 0, -66) } } }
T.shots.t01_vitrine_poings = {
	dur = 3.4,
	slow = 2,
	cam = still(V(85.5, 2.2, -38.5), V(74, 4.8, -52), 54, 31),
	setup = function(S)
		local st = store("STORE_Z1_Kiosque")
		S.st = st
		cast(S, "c1", "bacon1", "bacon")
		cast(S, "c2", "jean1", "bacon_jean")
		cast(S, "c3", "lav1", "lavande")
		for k, p in K1 do
			S.actors[k]:place(p, V(0, 0, -1))
			S.actors[k]:play("Idle", { fade = 0 })
		end
		local w = cast(S, "w", "wit1", "witness:NPC_Witness_Z1_01")
		w:place(V(91, 0.4, -50.5), V(-1, 0, -0.3))
		w:play("Look", { fade = 0 })
		S.max = Zones[1].WindowHP
		S.hp = S.max
		S.bar = R.hpBar(st)
		R.setHp(S.bar, S.hp, S.max)
	end,
	update = function(S, t)
		local A = S.actors
		local dmg = power("Fists")
		volley(S, t, {
			target = S.st,
			hp = S.max,
			max = S.max,
			dmg = dmg,
			hitters = { { "c1", "HitWindow", 0.133, 0.15, 0.42 }, { "c2", "HitWindow", 0.133, 0.29, 0.42 }, { "c3", "HitWindow", 0.133, 0.43, 0.42 } },
			onBreak = function(S2, t2, a)
				R.smash(S2, S2.st, a, { speed = 0.6 })
				S2.runAt = t2 + 0.5
			end,
		})
		-- le témoin photographie (FX_Witness_Flash toutes les 0,9 s)
		local n = math.floor((t + 0.3) / 0.9)
		once(S, "flash" .. n, t, n * 0.9 - 0.3, function()
			if t > 0.1 then
				T.fx.emit("FX_Witness_Flash", A.w.cf * CFrame.new(0, 1.5, -1))
				R.sfx(S, "Witness_Photo")
			end
		end)
		if S.runAt then
			for k, keys in IN1 do
				once(S, "run" .. k, t, S.runAt, function()
					run(A[k])
					S["path" .. k] = { { S.runAt, A[k].cf.Position * V(1, 0, 1) }, { S.runAt + 1.3, keys[1][2] } }
				end)
				if S["path" .. k] then A[k]:follow(S["path" .. k], t) end
			end
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 2. Orbite lente : trois joueurs à la masse sur la Bijouterie (zone 4 : 271 967 PV, masse 40 000), SMASHED!
------------------------------------------------------------------------------------------------
local K2 = { c1 = V(437.5, 0.4, 49.6), c2 = V(442, 0.4, 49.8), c3 = V(446.5, 0.4, 49.6) }
T.shots.t02_vitrine_masses = {
	dur = 3.0,
	slow = 2,
	cam = hand(M.orbit({ center = V(442, 4.2, 50), radius = 9.5, height = -1.6, from = 62, to = 112, dur = 3, ease = "sine", fov = 52, lookUp = 0.6 }), 0.06, 32),
	setup = function(S)
		local st = store("STORE_Z4_Bijouterie")
		S.st = st
		cast(S, "c1", "jean1", "bacon_jean", "TOOL_Masse")
		cast(S, "c2", "tress1", "tresses", "TOOL_Masse")
		cast(S, "c3", "bacon2", "bacon", "TOOL_Masse")
		for k, p in K2 do
			S.actors[k]:place(p, V(0, 0, 1))
			S.actors[k]:play("Idle", { fade = 0 })
		end
		S.max = Zones[4].WindowHP
		S.hp = S.max
		S.bar = R.hpBar(st)
		R.setHp(S.bar, S.hp, S.max)
	end,
	update = function(S, t)
		volley(S, t, {
			target = S.st,
			hp = S.max,
			max = S.max,
			dmg = power("Sledgehammer"),
			sound = "HitWindowHeavy_Impact",
			hitters = { { "c1", "HitWindowHeavy", 0.233, 0.1, 0.75 }, { "c2", "HitWindowHeavy", 0.233, 0.33, 0.75 }, { "c3", "HitWindowHeavy", 0.233, 0.56, 0.75 } },
			onBreak = function(S2, t2, a)
				R.smash(S2, S2.st, a, { speed = 0.7 })
			end,
		})
	end,
}

------------------------------------------------------------------------------------------------
-- 3 et 4. Colis Légendaire de la Salle des coffres (zone 6) : il saute au sol, sept actions, silhouettes, le Trône
-- en or (150 kg) grandit puis se pose sur la tête. 3 = plan fixe large (le saut), 4 = toute l'ouverture.
------------------------------------------------------------------------------------------------
local SDC = "STORE_Z6_SalleDesCoffres"
local function unboxSetup(S)
	local st = store(SDC)
	local slot = slotPos(st, 1)
	S.slot = slot
	local box = T.fx.prop(S, "t03_box", "Boxes", "BOX_Legendary")
	T.fx.setOn(box, slot.Position, slot.LookVector * V(1, 0, 1))
	R.outline(box)
	local att = R.topAttachment(box, -0.3)
	if not att:FindFirstChildWhichIsA("BillboardGui") then
		local bb = game.ReplicatedStorage.Assets.UI.BB_Box:Clone()
		bb.Adornee = att
		bb.Parent = att
		local rl = bb:FindFirstChild("Rarity", true)
		if rl then R.setRarity(rl, require(Sh.Config.Rarities).ById.Legendary) end
		for _, n in { "Category", "Mutation" } do
			local l = bb:FindFirstChild(n, true)
			if l then l.Visible = false end
		end
	end
	local a = cast(S, "p", "bacon1", "bacon")
	local front = slot.Position + slot.LookVector * 2.6
	a:place(V(front.X, 0.5, front.Z), -slot.LookVector)
	a:play("Idle", { fade = 0 })
	local aisle = slot.LookVector * V(1, 0, 1)
	S.U = R.unbox({
		actor = a,
		box = box,
		slot = slot.Position,
		aisle = aisle,
		itemId = "Z6_TroneEnOr",
		kg = 150,
		actions = { "Kick", "Saw", "Crowbar", "Drill", "Kick", "Crowbar", "Hammer" },
		odds = ItemOdds.OneIn("Z6_TroneEnOr") or 1000,
		t0 = 0.3,
		sides = { V(0, 0, 1), V(0, 0, -1), aisle },
	})
end
local function unboxUpdate(S, t)
	S.U.update(S, t)
end
local SL1 = nil
do
	local ok, cf = pcall(function() return slotPos(store(SDC), 1) end)
	SL1 = if ok then cf else CFrame.new(827, 2.8, -77)
end
local FLOOR1 = SL1.Position + SL1.LookVector * 4.5
T.shots.t03_colis_saut = {
	dur = 3.2,
	slow = 2,
	cam = still(FLOOR1 + SL1.LookVector * 7 + V(0, 2.6, 6.5), FLOOR1 + V(0, 1.6, 0) - SL1.LookVector * 1.5, 54, 33),
	setup = unboxSetup,
	update = unboxUpdate,
}
T.shots.t04_colis_ouverture = {
	dur = 15.5,
	slow = 2,
	-- orbite lente autour du colis, puis recul et montée pour cadrer le trône posé sur la tête (repérage : à 8 studs,
	-- l'objet de 11 studs remplissait l'image)
	cam = hand(M.chain({
		{ 12.9, M.orbit({ center = FLOOR1 + V(0, 1.5, 0), radius = 10.5, radiusTo = 8.5, height = 2.6, heightTo = 2.3, from = 200, to = 240, dur = 12.9, ease = "sine", fov = 50, lookUp = 0.4 }) },
		{ 2.6, M.orbit({ center = FLOOR1 + V(0, 1.5, 0), radius = 8.5, radiusTo = 15, height = 2.3, heightTo = 6.5, from = 240, to = 250, dur = 2.6, ease = "outQuad", fov = 50, lookUp = 3.5 }) },
	}), 0.05, 34),
	setup = unboxSetup,
	update = unboxUpdate,
}

------------------------------------------------------------------------------------------------
-- 5. Poursuite : le voleur sort de la Salle des coffres avec le Trône en or, écran RUN!, vigile en rouge qui crie.
------------------------------------------------------------------------------------------------
local P5 = { { 0, V(818, 0, -66) }, { 0.8, V(819, 0.4, -54.5) }, { 2.0, V(822, 0, -37) }, { 3.0, V(824, 0, -23) } }
local G5 = { { 0, V(816, 0, -80) }, { 1.45, V(818, 0.4, -55) }, { 2.6, V(821, 0, -38) }, { 3.0, V(822, 0, -31) } }
T.shots.t05_run_trone = {
	dur = 3,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(826, 2.2, -27) }, { 3, V(828, 2.6, -17) } }, targets = { "p", "g" }, lookOffset = V(0, 3.2, 0), lag = 0.3, fov = 56 }), 0.13, 35),
	setup = function(S)
		broken(store(SDC))
		local p = cast(S, "p", "guit1", "bacon_guitare")
		R.carry(p, "Z6_TroneEnOr", 150)
		p:follow(P5, 0)
		run(p)
		local g = cast(S, "g", "gz6", "guard:Guard_Z6")
		g:follow(G5, 0)
		g:play("Sprint", { fade = 0 })
		R.chaser(S, g)
	end,
	update = function(S, t)
		S.actors.p:follow(P5, t)
		S.actors.g:follow(G5, t)
		once(S, "run", t, 0.15, function() R.chaseStart(S) end)
	end,
}

------------------------------------------------------------------------------------------------
-- 6. Plan fixe : le vigile rattrape le voleur dans la rue de New York, il est projeté, CAUGHT!, le trône tombe.
------------------------------------------------------------------------------------------------
local P6 = { { 0, V(784, 0, -14) }, { 1.2, V(805, 0, -11) } }
local G6 = { { 0, V(768, 0, -15) }, { 1.15, V(802, 0, -11.4) } }
T.shots.t06_caught = {
	dur = 3.2,
	slow = 2,
	cam = still(V(812, 1.8, -1), V(803, 3.2, -11), 52, 36),
	setup = function(S)
		local p = cast(S, "p", "guit1", "bacon_guitare")
		R.carry(p, "Z6_TroneEnOr", 150)
		p:follow(P6, 0)
		run(p)
		local g = cast(S, "g", "gz6", "guard:Guard_Z6")
		g:follow(G6, 0)
		g:play("Sprint", { fade = 0 })
		R.chaser(S, g)
		R.runScreen(S)
	end,
	update = function(S, t)
		local A = S.actors
		if t < 1.2 then A.p:follow(P6, t) end
		if t < 1.15 then A.g:follow(G6, t) end
		once(S, "catch", t, 1.0, function()
			A.g:stop("Sprint", 0.08)
			A.g:play("Catch", { looped = false, fade = 0.06 })
		end)
		once(S, "hit", t, 1.2, function()
			S.hitAt = t
			R.caught(S)
			T.fx.drop(S, A.p, V(7, 12, -5)) -- loin de la caméra
			A.p:stop("Run", 0.05)
			A.p:stop("CarryRun", 0.05)
			S.kd = A.p:play("Knockdown", { looped = false, fade = 0.05 })
		end)
		-- poussé de côté (40 studs/s) et vers le haut (22) pendant 0,2 s (Config/Chase)
		if S.hitAt then
			local u = (t - S.hitAt) / 0.45
			if u <= 1 then A.p:flyAt(V(805, 0, -11), V(806.5, 0, -19), 1.6, u, V(1, 0, 0), 0) -- poussé loin de la caméra (repérage : vers elle, ses cheveux remplissaient l'image) end
		end
		holdEnd(S.kd)
		once(S, "gidle", t, 2.3, function() A.g:play("Idle", { fade = 0.2 }) end)
	end,
}

------------------------------------------------------------------------------------------------
-- 7 et 8. Boutique 03 pleine : 18 objets à leur poids (tailles variées), étiquettes, halos, contours.
------------------------------------------------------------------------------------------------
local SHOP = {
	{ 1, "Z5_LaJoconde", 40 }, { 3, "Z6_TroneEnOr", 150 }, { 5, "Z3_PcGamer", 18 }, { 9, "Z4_Couronne", 60 },
	{ 11, "Z5_Sarcophage", 260 }, { 13, "Z2_PelucheGeante", 25 }, { 15, "Z6_PyramideDeLingots", 90 }, { 17, "Z5_StatueDoree", 45 },
	{ 19, "Z6_TaureauEnOr", 600 }, { 2, "Z3_TeleGeante", 30 }, { 4, "Z4_OeufEnDiamant", 12 }, { 6, "Z5_ArmureDeChevalier", 120 },
	{ 10, "Z2_TrainElectrique", 8 }, { 12, "Z5_Meteorite", 35 }, { 14, "Z3_CarteGraphiqueEnOr", 5 }, { 16, "Z6_DiamantGeant", 70 },
	{ 18, "Z5_MasqueAncien", 14 }, { 20, "Z6_StatueDeLaLiberte", 200 },
}
local function fullShop(S, skip)
	S.shop = {}
	local p = plot(3)
	for _, e in SHOP do
		if e[1] ~= skip then table.insert(S.shop, R.display(S, p, e[1], e[2], e[3])) end
	end
end
T.SHOP_TEASER = SHOP
T.shots.t07_boutique_rayon = {
	dur = 4,
	slow = 2,
	cam = hand(M.path({ keys = { { 0, V(-164, 4.4, 27.5), V(-177, 3.2, 16) }, { 4, V(-196, 4.6, 27.5), V(-209, 3.2, 16) } }, ease = "sine", fov = 52 }), 0.05, 37),
	setup = function(S)
		fullShop(S)
		local o = cast(S, "o", "bacon1", "bacon")
		S.po = { { 0, V(-181, 0, 25.5) }, { 4, V(-205, 0, 25) } }
		o:follow(S.po, 0)
		o:play("Walk", { fade = 0 })
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
		S.actors.o:follow(S.po, t)
	end,
}
T.shots.t08_boutique_fixe = {
	dur = 3,
	slow = 2,
	cam = still(V(-163.5, 7.5, 33), V(-196, 3, 20), 58, 38),
	setup = function(S)
		fullShop(S)
		local o = cast(S, "o", "lav1", "lavande")
		S.po = { { 0, V(-170, 0, 34) }, { 3, V(-186, 0, 27) } }
		o:follow(S.po, 0)
		o:play("Walk", { fade = 0 })
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
		S.actors.o:follow(S.po, t)
	end,
}

------------------------------------------------------------------------------------------------
-- 9. Plan fixe : encaissement sur la plaque 01 (billets, pièces, bords verts, l'objet tourne et saute)
------------------------------------------------------------------------------------------------
local PAD9 = V(-168, 0.6, 20.9)
T.shots.t09_encaisse = {
	dur = 2.6,
	slow = 2,
	cam = still(V(-166.2, 1.6, 30), V(-168, 3.2, 18.5), 50, 39),
	setup = function(S)
		fullShop(S)
		local o = cast(S, "o", "bacon1", "bacon")
		S.po = { { 0, V(-176.5, 0, 25.5) }, { 0.9, PAD9 } }
		o:follow(S.po, 0)
		o:play("Walk", { fade = 0 })
	end,
	update = function(S, t)
		local o = S.actors.o
		T.fx.bob(S.shop, t)
		if t < 0.9 then o:follow(S.po, t) end
		once(S, "cash", t, 0.9, function()
			S.cashAt = t
			o:place(PAD9, V(0.2, 0, 1))
			idle(o)
			T.fx.emit("FX_Collect_Bill", CFrame.new(PAD9 + V(0, 1, 0)), 10)
			T.fx.emit("FX_Collect_Coin", CFrame.new(PAD9 + V(0, 1, 0)), 8)
			R.sfx(S, "Cash_Pad")
			-- bords verts d'encaissement (UI_CashFlash de Clément, force 0,45 : 0,06 s, tenu 0,18 s, 0,45 s)
			local root = R.uiRoot()
			local eg = game.StarterGui:FindFirstChild("UI_CashFlash") and game.StarterGui.UI_CashFlash:FindFirstChild("EdgeGlow")
			if eg then
				local c = eg:Clone()
				c.Parent = root
				local frames = {}
				for _, d in c:GetDescendants() do if d:IsA("GuiObject") then table.insert(frames, { d, d.BackgroundTransparency }) end end
				local age = 0
				table.insert(S.fx, { step = function(dt)
					age += dt
					local k = if age < 0.06 then age / 0.06 elseif age < 0.24 then 1 else math.max(0, 1 - (age - 0.24) / 0.45)
					for _, f in frames do f[1].BackgroundTransparency = 1 - 0.45 * k end
				end })
			end
		end)
		-- tour et deux sauts de l'objet du présentoir 01 (DisplayMotion)
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
-- 10. La porte de la boutique 03 en 40 coups (« -1 » à chaque coup, 8 coups/s au plus), BB_ShopInfo, SMASHED!
------------------------------------------------------------------------------------------------
local function shopInfo(S)
	local door = plot(3).PlotDoor
	local bb = game.ReplicatedStorage.Assets.UI.BB_ShopInfo:Clone()
	bb.Adornee = door:FindFirstChild("NameSign") or door:FindFirstChildWhichIsA("BasePart", true)
	bb.Parent = T.root():FindFirstChild("Props")
	table.insert(T._restore, function() bb:Destroy() end)
	local total, best = 0, nil
	for _, e in S.shop do
		total += e.info.income
		if not best or e.info.income > best.income then best = e.info end
	end
	local function set(n, v)
		local l = bb:FindFirstChild(n, true)
		if l and l:IsA("TextLabel") then l.Text = v end
	end
	set("OwnerName", "Bacon's Shop")
	set("Income", Format.income(total))
	set("BestItem", best and best.name or "")
	set("Status", "OPEN")
	S.shopBB = bb
	return function(hp) set("HP", hp .. "/40") end
end
T.shots.t10_porte_40 = {
	dur = 3.2,
	slow = 2,
	cam = still(V(-147.5, 2.4, 47.5), V(-160, 5.5, 40), 54, 40),
	setup = function(S)
		fullShop(S)
		local c1 = cast(S, "c1", "tress1", "tresses", "TOOL_PiedDeBiche")
		local c2 = cast(S, "c2", "blond1", "blond", "TOOL_Marteau")
		c1:place(V(-157.6, 0, 37.5), V(-1, 0, 0))
		c2:place(V(-157.6, 0, 43), V(-1, 0, 0))
		c1:play("Idle", { fade = 0 })
		c2:play("Idle", { fade = 0 })
		S.setDoor = shopInfo(S)
		S.max = 40
		S.hp = 8 -- la prise commence à la fin de la rafale : 8 coups restants
		S.bar = R.hpBar(plot(3).PlotDoor)
		R.setHp(S.bar, S.hp, S.max)
		S.setDoor(S.hp)
	end,
	update = function(S, t)
		T.fx.bob(S.shop, t)
		volley(S, t, {
			target = plot(3).PlotDoor,
			hp = 8,
			max = 40,
			dmg = 1,
			alongX = true,
			hitters = { { "c1", "HitWindow", 0.133, 0.1, 0.42 }, { "c2", "HitWindowHeavy", 0.233, 0.3, 0.72 } },
			onBreak = function(S2, t2, a)
				R.smash(S2, plot(3).PlotDoor, a, { speed = 0.6 })
				S2.runAt = t2 + 0.5
			end,
		})
		if S.setDoor then S.setDoor(S.hp) end
		if S.runAt then
			for k, dz in { c1 = -4, c2 = 4 } do
				local a = S.actors[k]
				once(S, "in" .. k, t, S.runAt, function()
					dropTool(a)
					run(a)
					S["p" .. k] = { { S.runAt, a.cf.Position * V(1, 0, 1) }, { S.runAt + 1.0, V(-170, 0, 40 + dz) } }
				end)
				if S["p" .. k] then a:follow(S["p" .. k], t) end
			end
		end
	end,
}

------------------------------------------------------------------------------------------------
-- 11. Le voleur prend La Joconde (« Steal », 1 s), contour rouge, sirène du propriétaire, il fonce vers la porte.
------------------------------------------------------------------------------------------------
local P11a = { { 0, V(-164, 0, 32) }, { 0.7, V(-168, 0, 20.2) } }
local P11b = { { 1.9, V(-168, 0, 20.2) }, { 2.5, V(-164, 0, 31) }, { 3.2, V(-157, 0, 42) } }
T.shots.t11_vol_contour = {
	dur = 3.2,
	slow = 2,
	cam = hand(M.operator({ keys = { { 0, V(-178, 3.4, 31) }, { 3.2, V(-174, 3.0, 34) } }, targets = { "p" }, lookOffset = V(0, 2.4, 0), lag = 0.3, fov = 54 }), 0.1, 41),
	setup = function(S)
		fullShop(S)
		broken(plot(3).PlotDoor)
		local p = cast(S, "p", "tress1", "tresses")
		p:follow(P11a, 0)
		run(p)
	end,
	update = function(S, t)
		local p = S.actors.p
		T.fx.bob(S.shop, t)
		if t < 0.7 then p:follow(P11a, t) end
		once(S, "stop", t, 0.7, function()
			p:place(P11a[2][2], V(0, 0, -1))
			idle(p)
			p:play("Grab", { looped = false, fade = 0.08 })
			R.sfx(S, "Grab_Grab")
		end)
		once(S, "steal", t, 1.7, function()
			local e = S.shop[1]
			e.hidden = true
			e.model:PivotTo(FAR)
			R.carry(p, e.info.id, e.info.kg, true)
			p:play("CarryIdle", { fade = 0.1 })
			R.sfx(S, "TheftAlert_Siren", 0.1, 0.6)
		end)
		once(S, "go", t, 1.9, function() run(p) end)
		if t >= 1.9 then p:follow(P11b, t) end
	end,
}

------------------------------------------------------------------------------------------------
-- 12. Coup de batte du propriétaire : le voleur est éjecté À TRAVERS la vitre de la porte (version DEV, GlassThrow).
------------------------------------------------------------------------------------------------
local FLY12 = { V(-164.5, 0, 38.5), V(-137, 0, 47) }
T.shots.t12_batte_ejection = {
	dur = 3.2,
	slow = 2,
	cam = M.shake(still(V(-140, 2.6, 33), V(-156, 4.2, 41), 56, 42), { atKey = "throwAt", dur = 0.35, amp = 0.3 }),
	setup = function(S)
		fullShop(S, 1)
		local p = cast(S, "p", "tress1", "tresses")
		R.carry(p, "Z5_LaJoconde", 40, true)
		p:place(V(-168, 0, 34), V(1, 0, 0.3))
		run(p)
		S.pp = { { 0, V(-170, 0, 33) }, { 0.7, FLY12[1] } }
		local o = cast(S, "o", "bacon1", "bacon", "TOOL_Batte")
		o:place(V(-170.5, 0, 40.5), V(1, 0, -0.4))
		o:play("Idle", { fade = 0 })
	end,
	update = function(S, t)
		local A = S.actors
		T.fx.bob(S.shop, t)
		if t < 0.7 then A.p:follow(S.pp, t) end
		once(S, "swing", t, 0.45, function()
			A.o:play("SwingBat", { looped = false, fade = 0.05 })
			R.sfx(S, "SwingBat_Impact")
		end)
		once(S, "hit", t, 0.75, function()
			S.hitAt = t
			R.sfx(S, "SwingBat_Hit")
			R.sfx(S, "Throw_Hit", 0.02)
			R.sfx(S, "Throw_Whoosh", 0.05)
			-- l'objet volé retourne sur son présentoir
			if A.p.carried then
				A.p.carried.model:Destroy()
				A.p.carried = nil
			end
			local e = S.shop[1]
			if e then e.hidden = false end
			A.p:stop("Run", 0.05)
			A.p:stop("CarryRun", 0.05)
			S.kb = A.p:play("Knockback", { looped = false, fade = 0.05 })
		end)
		if S.hitAt then
			local u = math.clamp((t - S.hitAt) / 0.8, 0, 1)
			A.p:flyAt(FLY12[1], FLY12[2], 3.5, u, V(-1, 0, -0.3), 0)
			if u < 1 then A.p:setCF(A.p.cf * CFrame.Angles(u * 9, u * 4, u * 2)) end
			-- passage de la vitre (x = -161,5)
			if not S.throwAt and A.p.cf.Position.X > -162 then
				S.throwAt = t
				local f = T.fx.breakWindow(plot(3).PlotDoor, { speed = 0.9, fadeAt = 1.2 })
				table.insert(S.fx, f)
				T.fx.emit("FX_ShopGlass_Burst", CFrame.lookAt(V(-161.5, 4, 41), V(-150, 4, 44)))
				R.sfx(S, "Throw_GlassBurst")
				R.sfx(S, "Throw_GlassDebris", 0.3)
			end
		end
		holdEnd(S.kb)
	end,
}

------------------------------------------------------------------------------------------------
-- 13. Plan fixe large : la Galerie d'art (zone 5) attaquée, le témoin photographie, « POLICE IN 8s ».
------------------------------------------------------------------------------------------------
local K13 = { c1 = V(614, 0.4, 49.6), c2 = V(622, 0.4, 49.6) }
T.shots.t13_temoin_police = {
	dur = 3,
	slow = 2,
	cam = still(V(604, 3.2, 33), V(617, 5.2, 50), 54, 43),
	setup = function(S)
		local st = store("STORE_Z5_GalerieDArt")
		S.st = st
		cast(S, "c1", "blond1", "blond", "TOOL_HacheDIncendie")
		cast(S, "c2", "brune1", "brune", "TOOL_HacheDIncendie")
		for k, p in K13 do
			S.actors[k]:place(p, V(0, 0, 1))
			S.actors[k]:play("Idle", { fade = 0 })
		end
		local w = cast(S, "w", "wit2", "witness:NPC_Witness_Z1_02")
		w:place(V(607, 0.4, 47), V(1, 0, 0.6))
		w:play("Look", { fade = 0 })
		S.max = Zones[5].WindowHP
		S.hp = S.max
		S.bar = R.hpBar(st)
		R.setHp(S.bar, S.hp, S.max)
		-- minuterie du HUD de Clément (UI_HUD.HeistTimer), en rouge
		local src = game.StarterGui.UI_HUD:FindFirstChild("HeistTimer")
		if src then
			local root = R.uiRoot()
			local c = src:Clone()
			c.Text = "POLICE IN 8s"
			c.TextColor3 = Color3.fromRGB(255, 70, 70)
			c.Visible = true
			c.TextTransparency = 0 -- livrée transparente : le code du HUD l'anime
			for _, d in c:GetDescendants() do
				if d:IsA("UIStroke") then d.Transparency = 0 end
				if d:IsA("TextLabel") then d.TextTransparency = 0 end
			end
			c.Parent = root
			S.timer = c
		end
	end,
	update = function(S, t)
		volley(S, t, {
			target = S.st,
			hp = S.max,
			max = S.max,
			dmg = power("FireAxe"),
			sound = "HitWindowHeavy_Impact",
			hitters = { { "c1", "HitWindowHeavy", 0.233, 0.1, 0.75 }, { "c2", "HitWindowHeavy", 0.233, 0.45, 0.75 } },
			onBreak = function() end,
		})
		local n = math.floor((t + 0.2) / 0.9)
		once(S, "flash" .. n, t, n * 0.9 - 0.2, function()
			if t > 0.05 then
				T.fx.emit("FX_Witness_Flash", S.actors.w.cf * CFrame.new(0, 1.5, -1))
				R.sfx(S, "Witness_Photo")
			end
		end)
		if S.timer then
			local left = math.max(0, 8 - math.floor(t))
			S.timer.Text = "POLICE IN " .. left .. "s"
			once(S, "tick" .. left, t, 8 - left, function() R.sfx(S, "UI_Click_Tick") end)
		end
	end,
}

T.ORDER_TEASER = {
	"t01_vitrine_poings", "t02_vitrine_masses", "t03_colis_saut", "t04_colis_ouverture", "t05_run_trone", "t06_caught",
	"t07_boutique_rayon", "t08_boutique_fixe", "t09_encaisse", "t10_porte_40", "t11_vol_contour", "t12_batte_ejection",
	"t13_temoin_police",
}
T.KEY_TEASER = {
	t01_vitrine_poings = 2.2, t02_vitrine_masses = 1.95, t03_colis_saut = 1.0, t04_colis_ouverture = 13.6,
	t05_run_trone = 1.5, t06_caught = 1.5, t07_boutique_rayon = 2, t08_boutique_fixe = 1.5, t09_encaisse = 1.2,
	t10_porte_40 = 1.9, t11_vol_contour = 2.2, t12_batte_ejection = 1.1, t13_temoin_police = 1.5,
}

return "plans teaser chargés : " .. #T.ORDER_TEASER
