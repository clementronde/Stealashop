-- a416 (Cantin, 2026-11-23 : « le vigile attrape de hyper loin le joueur », « surtout dans les zones rapides ») :
-- Config/Chase.ClientView et Guard/ClientView. Collé après les aides de tests.luau d'a193 (startBanc déjà fait, FRAME à
-- 1/60, nextStore, FAR2, C, BalanceCfg, ChaseCfg…). Scénarios : voir run.sh. « …avant » : la règle d'a193 (mesure).
--
-- Réseau simulé (faux Roblox d'a36, setup.luau) : L = aller simple (ping de Roblox, événements et WalkSpeed vers le
-- client) ; le serveur reçoit la position du personnage L + UP s en retard (NET.oneWay + NET.extra : tampon de
-- réplication montant) ; le client voit le vigile L + DOWN s en retard (tampon descendant, calculé ici). « Vue » =
-- distance à plat entre la vraie position du client et le vigile tel que son écran le montre au même instant.
-- Collisions simulées ici d'après les groupes : un vigile ne passe pas à moins de BODY studs de la copie de sa cible sur
-- le serveur si leurs groupes se heurtent (table COLLIDABLE du faux PhysicsService). La poussée de la capture est
-- retirée avant le client simulé (le faux la lui montrerait sans retard).
do
	local S = A193_SCENARIO
	local AVANT = string.sub(S, -5) == "avant"
	local BASE = if AVANT then string.sub(S, 1, -6) else S
	local TAG = if AVANT then "avant" else "après"
	local CV = ChaseCfg.ClientView
	local GS = serverModule("GuardService")
	local View = GS._ClientView
	local ZonesList = sharedModule("Config/Zones")
	local K = BalanceCfg.Stats.RealSpeedScale
	local CARRY = BalanceCfg.Carry.NPCBoxSpeedMultiplier
	-- Tampons de réplication simulés (s). Leur somme = Chase.ClientView.BaseSeconds, sauf dans « ecart ».
	-- Multiples d'une image (1/60 s), comme les pings : le faux réseau ne livre qu'image par image.
	local UP, DOWN = 8 / 60, 7 / 60
	local PING60 = 2 / 60 -- aller simple du ping « courant » des scénarios (aller-retour 67 ms)
	local BODY = 1.5

	check(type(CV) == "table" and View ~= nil, "0 Config/Chase.ClientView et Guard/ClientView chargés par GuardService")
	check(CV.Enabled == not AVANT, "0 Chase.ClientView.Enabled = " .. tostring(CV.Enabled) .. " (" .. TAG .. ")")
	check(CV.BaseSeconds == 0.25 and CV.DisplaySeconds == 0.12 and CV.MaxSeconds == 0.6 and CV.WallMargin == 1 and CV.StandOff == 3
		and CV.StillSpeed == 2 and CV.SettleSeconds == 0.4 and CV.SettleSpeed == 16 * K,
		"0 Chase.ClientView : BaseSeconds 0,25, DisplaySeconds 0,12, MaxSeconds 0,6, WallMargin 1, StandOff 3, StillSpeed 2, SettleSeconds 0,4, SettleSpeed 16 × k")
	check(math.abs(UP + DOWN - CV.BaseSeconds) < 1e-9 and math.abs(DOWN - CV.DisplaySeconds) < 0.005, "0 tampons simulés du banc : somme = BaseSeconds, descendant = DisplaySeconds à 5 ms près")
	check(CV.StandOff < C, "0 StandOff sous la portée de capture")

	local function collidable(a, b)
		return COLLIDABLE[tostring(a) .. "|" .. tostring(b)] ~= false
	end
	local function setGroup(player, name)
		for _, d in player.Character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = name
			end
		end
	end
	local function targetRootOf(model)
		local id = model:GetAttribute("TargetUserId")
		for _, p in Players:GetPlayers() do
			if p.UserId == id then
				return rootOf(p)
			end
		end
		return nil
	end

	-- Élan simulé des vigiles (MOMENTUM = studs/s² ; nil : arrêt immédiat, comme le harnais) : la vitesse réelle d'un
	-- vigile ne baisse que de MOMENTUM × dt par image, sauf si le service a coupé son élan (AssemblyLinearVelocity à plat
	-- remise à zéro pendant le Heartbeat : Guard/ClientView). Sa vitesse est écrite dans AssemblyLinearVelocity.
	MOMENTUM = nil
	local momentum = {} -- [root] = vitesse à plat gardée
	local base416 = BEFORE_FRAME
	BEFORE_FRAME = function(dt)
		for _, p in Players:GetPlayers() do
			local r = rootOf(p)
			if r then
				for _, child in r:GetChildren() do
					if child.Name == "GuardKnockback" then
						child:Destroy()
					end
				end
			end
		end
		local active = Workspace:FindFirstChild("ActiveGuards")
		local before = {}
		for _, model in (if active then active:GetChildren() else {}) do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				before[root] = root.Position
				local kept = momentum[root]
				local now = root.AssemblyLinearVelocity
				if kept and Vector3.new(now.X, 0, now.Z).Magnitude < 1e-6 then
					momentum[root] = Vector3.zero -- élan coupé par le service
				end
			end
		end
		base416(dt)
		for root, old in before do
			local model = root.Parent
			if model == nil then
				momentum[root] = nil
				continue
			end
			local wanted = (root.Position - old) / dt
			wanted = Vector3.new(wanted.X, 0, wanted.Z)
			local velocity = wanted
			if MOMENTUM then
				local kept = momentum[root] or Vector3.zero
				local change = wanted - kept
				local limit = MOMENTUM * dt
				-- Il accélère sans limite (comme le harnais), mais ne perd sa vitesse qu'à MOMENTUM studs/s².
				if wanted.Magnitude < kept.Magnitude and change.Magnitude > limit then
					velocity = kept + change.Unit * limit
					local at = old + velocity * dt
					root.CFrame = CFrame.new(Vector3.new(at.X, root.Position.Y, at.Z)) * root.CFrame.Rotation
				end
			end
			momentum[root] = velocity
			root.AssemblyLinearVelocity = velocity
			-- Collisions d'après les groupes.
			local target = targetRootOf(model)
			if target and collidable(root.CollisionGroup, target.CollisionGroup) then
				local offset = Vector3.new(root.Position.X - target.Position.X, 0, root.Position.Z - target.Position.Z)
				if offset.Magnitude < BODY then
					local dir = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(-1, 0, 0)
					local at = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z) + dir * BODY
					root.CFrame = CFrame.new(at) * root.CFrame.Rotation
				end
			end
		end
	end

	-- Attente d'un magasin libre, à grands pas (rien à mesurer pendant ce temps).
	local function store416()
		local frame = FRAME
		FRAME = 1 / 10
		local store = nextStore()
		FRAME = frame
		return store
	end

	-- Une poursuite. o.speed : Speed du profil ; o.L : aller simple (s) ; o.up, o.down : tampons (s) ; o.seconds ;
	-- o.group : groupe de collision du personnage (« Default » par défaut) ; o.stay : il reste devant le magasin ;
	-- o.frame(t, rec) avant chaque image. Relevé image par image, 0,5 s de plus après l'annonce de la capture.
	local function chase416(o)
		NET.oneWay = 0
		NET.extra = nil
		local P = thief(o.speed)
		setGroup(P, o.group or "Default")
		local f = FRAME
		FRAME = 1 / 10
		advance(8)
		FRAME = f
		if heist(P, store416(), OUT) == nil then
			return nil
		end
		local L, up, down = o.L or 0, o.up or UP, o.down or DOWN
		NET.oneWay = L
		NET.extra = function()
			return up
		end
		PING[P] = L
		if o.stay ~= true then
			walk(P, FAR2)
		end
		local model
		for _ = 1, 240 do
			model = chaserOf(P)
			if model then
				break
			end
			advance(FRAME)
		end
		local rec = { P = P, L = L, up = up, down = down, hist = {}, samples = {}, startT = now(), model = model }
		if model == nil then
			return rec
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		local n = #CATCHES
		table.insert(rec.hist, { t = now(), pos = root.Position })
		-- Place du vigile sur l'écran du joueur à l'instant t.
		function rec.shown(t)
			local at = t - (L + down)
			local pos = rec.hist[1].pos
			for _, h in rec.hist do
				if h.t <= at + 1e-9 then
					pos = h.pos
				else
					break
				end
			end
			return pos
		end
		local stopAt = nil
		while now() - rec.startT < (o.seconds or 8) do
			if o.frame then
				o.frame(now() - rec.startT, rec)
			end
			advance(FRAME)
			if model.Parent == nil or rootOf(P) == nil or clientPos(P) == nil then
				rec.gone = true
				break
			end
			table.insert(rec.hist, { t = now(), pos = root.Position })
			local truth = clientPos(P)
			local shown = rec.shown(now())
			local s = {
				t = now(),
				truth = truth,
				guard = root.Position,
				seen = horizontal(truth, shown), -- distance vue par le joueur
				gap = truth.X - shown.X, -- la même, signée le long de la course (+ : vigile derrière)
				server = horizontal(rootOf(P).Position, root.Position), -- copie du serveur − vrai vigile
				lead = root.Position.X - rootOf(P).Position.X, -- + : le vrai vigile est devant la copie
				ws = hum.WalkSpeed,
				walk = humanoidOf(P).WalkSpeed,
			}
			table.insert(rec.samples, s)
			if rec.caughtT == nil and #CATCHES > n then
				rec.caughtT = now()
				rec.decision = s
				local prev = rec.samples[#rec.samples - 1]
				rec.speed = if prev then prev.walk else s.walk -- la capture immobilise : marche de l'image d'avant
				rec.guardSpeed = if prev then prev.ws else s.ws
				stopAt = now() + L + down + 0.5
			end
			if stopAt and now() >= stopAt then
				break
			end
		end
		if rec.caughtT then
			-- À l'annonce : le client apprend la capture L s après (WalkSpeed 0) et s'arrête.
			for _, s in rec.samples do
				if rec.announce == nil and s.t >= rec.caughtT + L - 1e-9 then
					rec.announce = s
				end
			end
			rec.rest = rec.samples[#rec.samples]
			rec.restGap = rec.rest.truth.X - rec.rest.guard.X -- au repos, tout est arrivé à l'écran
		end
		return rec
	end

	local function finish416(rec)
		NET.oneWay = 0
		NET.extra = nil
		MOMENTUM = nil
		if rec == nil then
			return
		end
		if rec.caughtT then
			stop(rec.P)
			advance(4)
		else
			endChase(rec.P)
		end
	end

	-- Bornes de `field` entre t1 et t2 s après le début du relevé.
	local function span416(rec, field, t1, t2)
		local lo, hi, count = math.huge, -math.huge, 0
		for _, s in rec.samples do
			local t = s.t - rec.startT
			if t >= t1 and t <= t2 then
				lo = math.min(lo, s[field])
				hi = math.max(hi, s[field])
				count += 1
			end
		end
		return lo, hi, count
	end

	-- Les vitesses réelles du jeu : la Speed du panneau de chaque zone (Config/Zones), et le plafond de la marche.
	local SPEEDS = {}
	for z = 1, #ZonesList do
		table.insert(SPEEDS, { label = "zone " .. z, speed = ZonesList[z].SpeedRequired, walk = ZonesList[z].AdvisedSpeed * CARRY })
	end
	table.insert(SPEEDS, { label = "plafond", speed = 1e40, walk = BalanceCfg.Stats.MaxWalkSpeed * K * CARRY })

	-- Capture d'un voleur sous le minimum qui court tout droit. Mesures : distance vue à la décision du serveur, à
	-- l'annonce chez le client, au repos ; contrôles selon la règle.
	local function catchRun(entry, L, label, up, down)
		local rec = chase416({ speed = entry.speed, L = L, up = up, down = down, seconds = 22 })
		check(rec ~= nil and rec.model ~= nil, label .. " : braquage, vigile apparu")
		if rec == nil or rec.model == nil then
			finish416(rec)
			return nil
		end
		check(rec.caughtT ~= nil, label .. " : sous le minimum, il est attrapé")
		if rec.caughtT == nil then
			local last = rec.samples[#rec.samples]
			print(string.format("    %s : jamais attrapé ; dernier relevé : vue %s, serveur %s, vigile %s studs/s", label, fmt(last and last.seen), fmt(last and last.server), fmt(last and last.ws)))
			finish416(rec)
			return nil
		end
		local d, a = rec.decision, rec.announce
		check(near(rec.speed, entry.walk, 0.2), label .. string.format(" : marche avec l'objet %.1f studs/s (%.1f)", entry.walk, rec.speed))
		print(string.format("  mesure %s %s : marche %.1f, vigile %.1f, ping %d ms ; vue à la décision %.1f, à l'annonce %.1f, au repos %.1f (signé %.1f) ; sur le serveur %.1f (vigile %s la copie de %.1f)",
			TAG, label, rec.speed, rec.guardSpeed, L * 2000, d.seen, a.seen, horizontal(rec.rest.truth, rec.rest.guard), rec.restGap,
			d.server, if d.lead >= 0 then "devant" else "derrière", math.abs(d.lead)))
		finish416(rec)
		return rec
	end

	---------------------------------------------------------------- unite : le module seul
	if S == "unite" then
		section("unite : Guard/ClientView, fonction par fonction")
		local P = thief(0)
		local root, hum = rootOf(P), humanoidOf(P)
		local params = { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = { P.Character }, RespectCanCollide = true, IgnoreWater = true }
		-- Retard
		PING[P] = 0
		check(near(View.Lag(P), 0.25), "U1 ping 0 : retard 0,25 s (" .. fmt(View.Lag(P)) .. ")")
		PING[P] = 0.03
		check(near(View.Lag(P), 0.25 + 0.03 * ChaseCfg.LagPingFactor), "U2 ping 30 ms aller : 0,31 s (" .. fmt(View.Lag(P)) .. ")")
		PING[P] = 0.5
		check(near(View.Lag(P), 0.6), "U3 ping énorme : plafonné à MaxSeconds 0,6 (" .. fmt(View.Lag(P)) .. ")")
		PING[P] = 0
		-- Groupes
		setGroup(P, "Default")
		check(COLLIDABLE["Guards|Players"] == nil, "U4 avant le premier appel, aucun groupe posé")
		check(View.Active(root) == true, "U5 personnage en Default : suivi (il passe en Players)")
		check(root.CollisionGroup == "Players" and P.Character.Head.CollisionGroup == "Players", "U6 ses pièces sont en Players (" .. tostring(root.CollisionGroup) .. ")")
		check(COLLIDABLE["Guards|Players"] == false and COLLIDABLE["Guards|NightPass"] == false, "U7 Guards ne heurte ni Players ni NightPass")
		check(COLLIDABLE["Guards|Default"] == nil and COLLIDABLE["Players|Default"] == nil and COLLIDABLE["Players|Players"] == nil,
			"U8 rien d'autre ne change (Guards et Players heurtent le décor, Players heurte Players ici)")
		check(COLLISION_GROUPS.Guards == true and COLLISION_GROUPS.Players == true and COLLISION_GROUPS.NightPass == true, "U9 groupes enregistrés")
		check(View.GetState().Ready == true and View.GetState().Ghosted == 1, "U10 GetState : prêt, 1 personnage passé en Players")
		local Q = thief(0)
		setGroup(Q, "NightPass")
		check(View.Active(rootOf(Q)) == true and rootOf(Q).CollisionGroup == "NightPass", "U11 personnage en NightPass (mur de nuit) : suivi, groupe gardé")
		local R = thief(0)
		COLLISION_GROUPS.Bloc416 = true
		setGroup(R, "Bloc416")
		check(View.Active(rootOf(R)) == false and rootOf(R).CollisionGroup == "Bloc416", "U12 groupe qui heurte les vigiles : pas suivi (règle d'avant), groupe gardé")
		check(View.GetState().Ghosted == 1, "U13 aucun autre personnage changé de groupe")
		-- Position estimée (la marche est celle que StatsService donne : 32 pour un profil neuf)
		local at = root.Position
		local W = hum.WalkSpeed
		check(W == 16 * K, "U14a marche d'un profil neuf : 16 × k (" .. fmt(W) .. ")")
		root.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		local e1 = View.Estimate(P, root, hum, params)
		check(near(e1.X - at.X, 5, 1e-6) and near(e1.Z, at.Z, 1e-6), "U14 20 studs/s, ping 0 : 5 studs devant (" .. fmt(e1.X - at.X) .. ")")
		root.AssemblyLinearVelocity = Vector3.new(0, 30, 200)
		local e2 = View.Estimate(P, root, hum, params)
		check(near(e2.Z - at.Z, W * 0.25, 1e-6) and near(e2.Y, at.Y, 1e-6), "U15 vitesse bornée à sa WalkSpeed, à plat : " .. fmt(W * 0.25) .. " studs (" .. fmt(e2.Z - at.Z) .. ")")
		root.AssemblyLinearVelocity = Vector3.zero
		check(View.Estimate(P, root, hum, params) == at, "U16 à l'arrêt : la position reçue")
		root.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		Stats.SetSpeedModifier(P, "Banc416", 0)
		check(hum.WalkSpeed == 0 and View.Estimate(P, root, hum, params) == at, "U17 immobilisé (WalkSpeed 0) : la position reçue")
		Stats.SetSpeedModifier(P, "Banc416", nil)
		local wall = make("Part", { Name = "Mur416", Size = Vector3.new(1, 30, 30), CFrame = CFrame.new(at.X + 4, at.Y, at.Z), Anchored = true }, Workspace)
		local e3 = View.Estimate(P, root, hum, params)
		check(near(e3.X - at.X, 4 - 0.5 - CV.WallMargin, 0.01), "U18 mur à 3,5 studs : arrêtée WallMargin (1) avant, 2,5 (" .. fmt(e3.X - at.X) .. ")")
		wall.CFrame = CFrame.new(at.X + 1, at.Y, at.Z)
		local e4 = View.Estimate(P, root, hum, params)
		check(near(e4.X - at.X, 0, 0.01), "U19 mur tout contre lui : jamais en arrière (" .. fmt(e4.X - at.X) .. ")")
		wall:Destroy()
		root.AssemblyLinearVelocity = Vector3.zero
		-- Relevé du vigile : un faux vigile qui avance à 60 studs/s
		local g = make("Part", { Name = "Vigile416", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 500), Anchored = true }, Workspace)
		local t0 = now()
		local first = View.Seen(g, P, t0)
		check(first == g.Position, "U20 premier relevé : il était déjà là")
		local worst = 0
		for i = 1, 60 do
			g.CFrame = CFrame.new(i, 3, 500)
			local seen = View.Seen(g, P, t0 + i / 60)
			-- il y a 0,25 s il était à x = max(i − 15, 0)
			worst = math.max(worst, math.abs(seen.X - math.max(i - 15, 0)))
		end
		check(worst < 1e-6, "U21 vu là où il était 0,25 s plus tôt, image par image (écart max " .. fmt(worst) .. ")")
		PING[P] = 0.03
		local seen31 = View.Seen(g, P, t0 + 61 / 60)
		check(near(seen31.X, 60 - (0.31 - 1 / 60) * 60, 1e-6), "U22 ping 30 ms : 0,31 s plus tôt, entre deux relevés (" .. fmt(seen31.X) .. ")")
		PING[P] = 0
		g.CFrame = CFrame.new(300, 3, 500)
		local after = View.Seen(g, P, t0 + 61 / 60 + 0.6)
		check(after == g.Position, "U23 relevé interrompu plus de 0,5 s (nouvelle poursuite) : sa place actuelle")
		-- Arrêt net avant la capture attendue. Voleur et vigile à 30 studs/s (sous sa marche, 32), ping 0 : retard 0,25 s,
		-- avance 0,12 s ; à t1 + 0,5 le joueur verra bientôt le vigile là où il était 0,13 s plus tôt.
		local T = thief(0)
		setGroup(T, "Players")
		local troot, thum = rootOf(T), humanoidOf(T)
		local base = troot.Position
		local g2 = make("Part", { Name = "Vigile416b", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(base.X - 30, base.Y, base.Z), Anchored = true }, Workspace)
		local p2 = { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = { T.Character, g2 }, RespectCanCollide = true, IgnoreWater = true }
		local function imminent(guardPart, at2)
			return View.Imminent(guardPart, T, troot, thum, View.Estimate(T, troot, thum, p2), at2, C, p2)
		end
		check(imminent(g2, now()) == false, "U24 sans relevé : pas d'arrêt")
		local t1 = now() + 10
		for i = 0, 30 do
			g2.CFrame = CFrame.new(base.X - 30 + i * 30 / 60, base.Y, base.Z)
			View.Seen(g2, T, t1 + i / 60)
		end
		local seenSoonX = base.X - 30 + (0.5 - 0.13) * 30 -- vigile vu bientôt ; il est maintenant à base − 15
		g2.AssemblyLinearVelocity = Vector3.new(30, 0, 0)
		troot.AssemblyLinearVelocity = Vector3.new(30, 0, 0)
		-- Voleur dans 0,12 s : copie + 3,6. Copie posée pour un écart prévu de 3,9 (position estimée : copie + 7,5, à 3,9
		-- du vigile), puis de 4,5.
		T.Character:PivotTo(CFrame.new(seenSoonX + 3.9 - 3.6, base.Y, base.Z))
		check(imminent(g2, t1 + 0.5) == true, "U25 capture prévue dans 0,12 s (écart prévu 3,9), vigile à portée de la position estimée : arrêt")
		check(g2.AssemblyLinearVelocity.Magnitude < 1e-6, "U26 son élan est coupé")
		g2.AssemblyLinearVelocity = Vector3.new(30, 0, 0)
		T.Character:PivotTo(CFrame.new(seenSoonX + 4.5 - 3.6, base.Y, base.Z))
		check(imminent(g2, t1 + 0.5) == false and g2.AssemblyLinearVelocity.X == 30, "U27 écart prévu 4,5 : pas d'arrêt, élan gardé")
		-- Voleur à l'arrêt à 3,5 studs du vigile vu bientôt : arrêt ; un mur entre eux : pas d'arrêt.
		troot.AssemblyLinearVelocity = Vector3.zero
		T.Character:PivotTo(CFrame.new(seenSoonX + 3.5, base.Y, base.Z))
		check(imminent(g2, t1 + 0.5) == true, "U28 voleur à l'arrêt à 3,5 studs : arrêt")
		local wall2 = make("Part", { Name = "Mur416b", Size = Vector3.new(1, 30, 30), CFrame = CFrame.new(seenSoonX + 1.75, base.Y, base.Z), Anchored = true }, Workspace)
		check(imminent(g2, t1 + 0.5) == false, "U28a un mur entre eux : pas d'arrêt (pas de capture non plus)")
		wall2:Destroy()
		-- Voleur qui vient de s'arrêter net : un vigile à 120 studs/s l'a déjà dépassé de plus de 4 studs : pas d'arrêt.
		local g3 = make("Part", { Name = "Vigile416c", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(base.X - 60, base.Y, base.Z), Anchored = true }, Workspace)
		p2.FilterDescendantsInstances = { T.Character, g2, g3 }
		for i = 0, 30 do
			g3.CFrame = CFrame.new(base.X - 60 + i * 2, base.Y, base.Z)
			View.Seen(g3, T, t1 + i / 60)
		end
		g3.AssemblyLinearVelocity = Vector3.new(120, 0, 0)
		T.Character:PivotTo(CFrame.new(base.X - 60 + 0.37 * 120 + 3, base.Y, base.Z)) -- 3 studs devant le vigile vu bientôt, 12,6 derrière le vrai
		check(imminent(g3, t1 + 0.5) == false and g3.AssemblyLinearVelocity.X == 120,
			"U28b capture prévue, mais le vrai vigile est à plus de 4 studs au-delà du voleur arrêté : pas d'arrêt, il revient d'abord")
		g3:Destroy()
		-- Distance gardée sur un voleur à l'arrêt
		troot.AssemblyLinearVelocity = Vector3.zero
		T.Character:PivotTo(CFrame.new(1000, 3, 0))
		local here = troot.Position
		g2.CFrame = CFrame.new(here.X - 10, here.Y, here.Z)
		local aimFar = Vector3.new(here.X + 20, here.Y, here.Z)
		check(View.StandOff(g2, troot, aimFar, here) == aimFar, "U29 il vise un point devant le voleur : inchangé")
		local s1 = View.StandOff(g2, troot, here, here)
		check(near(s1.X, here.X - 3, 1e-6) and near(s1.Z, here.Z, 1e-6), "U30 droit sur le voleur, à 10 studs : il vise 3 studs avant (" .. fmt(here.X - s1.X) .. ")")
		g2.CFrame = CFrame.new(here.X - 2, here.Y, here.Z)
		g2.AssemblyLinearVelocity = Vector3.new(90, 0, 0)
		check(View.StandOff(g2, troot, here, here) == g2.Position and g2.AssemblyLinearVelocity.Magnitude < 1e-6, "U31 arrivé (2 studs), voleur à l'arrêt : il reste là, élan coupé")
		g2.AssemblyLinearVelocity = Vector3.new(90, 0, 0)
		troot.AssemblyLinearVelocity = Vector3.new(60, 0, 0)
		check(View.StandOff(g2, troot, here, here) == g2.Position and g2.AssemblyLinearVelocity.X == 90, "U32 arrivé, voleur qui court : il reste là, élan gardé")
		setGroup(T, "Bloc416")
		advance(0.3)
		check(View.StandOff(g2, troot, here, here) == here, "U33 voleur qui heurte les vigiles : droit sur lui, comme avant")
		-- Après la capture : il rejoint le joueur qui glisse
		setGroup(T, "Players")
		advance(0.3)
		g2.CFrame = CFrame.new(here.X - 9, here.Y, here.Z)
		check(View.Settle(g2, now()) == nil, "U34 sans capture enregistrée : rien")
		View.Caught(g2, troot, now())
		local to1, speed1 = View.Settle(g2, now() + 0.1)
		check(to1 ~= nil and near(to1.X, here.X - 3, 1e-6) and speed1 == CV.SettleSpeed, "U35 à 9 studs : jusqu'à 3 studs du joueur, à SettleSpeed")
		g2.CFrame = CFrame.new(here.X - 3.3, here.Y, here.Z)
		check(View.Settle(g2, now() + 0.2) == nil, "U36 déjà à 3,3 studs : il ne bouge plus")
		g2.CFrame = CFrame.new(here.X + 6, here.Y, here.Z)
		local to2 = View.Settle(g2, now() + 0.2)
		check(to2 ~= nil and near(to2.X, here.X + 3, 1e-6), "U37 de l'autre côté : au plus près de son côté, jamais à travers le joueur")
		check(View.Settle(g2, now() + CV.SettleSeconds + 0.01) == nil, "U38 après SettleSeconds : fini")
		g2:Destroy()
		g:Destroy()
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- zones : capture en ligne droite, vitesses réelles
	if BASE == "zones" then
		section("zones (" .. TAG .. ") : capture en ligne droite aux vitesses des 6 zones et au plafond, ping 67 ms")
		for _, entry in SPEEDS do
			local rec = catchRun(entry, PING60, entry.label)
			if rec then
				local d, a = rec.decision, rec.announce
				if AVANT then
					-- La règle d'a193 : capture au contact de la copie (3 studs), vue 3 + marche × montant + vigile × descendant.
					local expected = ChaseCfg.LagContactReach + rec.speed * (rec.L + rec.up) + rec.guardSpeed * (rec.L + rec.down)
					check(near(d.server, ChaseCfg.LagContactReach, 0.8), entry.label .. " avant : capture au contact de la copie du serveur (" .. fmt(d.server) .. ")")
					check(near(d.seen, expected, 2), entry.label .. string.format(" avant : vue à %.1f ± 2 (3 + vitesse × retard) : %.1f", expected, d.seen))
				else
					check(d.seen <= C + rec.speed * FRAME + 0.1 and d.seen >= 1, entry.label .. " : à la décision, le joueur voit le vigile à portée, à une image de course près (" .. fmt(d.seen) .. " pour " .. C .. ")")
					check(a.seen <= C + rec.speed * FRAME + 0.1 and a.gap >= 1, entry.label .. " : à l'annonce, vigile à portée, derrière lui (" .. fmt(a.gap) .. ")")
					check(rec.restGap >= 1 and rec.restGap <= C + 0.5, entry.label .. " : au repos, vigile derrière lui, à portée, pas dedans ni au-delà (" .. fmt(rec.restGap) .. ")")
					check(d.lead > 0 or rec.speed * (rec.L * 2 + UP + DOWN) < C, entry.label .. " : le vrai vigile est passé devant la copie du serveur (" .. fmt(d.lead) .. ")")
				end
			end
		end
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- pings : capture en ligne droite, plusieurs pings
	if BASE == "pings" then
		section("pings (" .. TAG .. ") : zones 4 et 6, ping 0, 133 et 200 ms")
		for _, index in { 4, 6 } do
			local entry = SPEEDS[index]
			for _, L in { 0, 4 / 60, 6 / 60 } do
				local label = string.format("%s, ping %d ms", entry.label, L * 2000)
				local rec = catchRun(entry, L, label)
				if rec then
					local d, a = rec.decision, rec.announce
					if AVANT then
						-- ping 0 : pas d'avance compensée, capture à 4 studs de la copie ; sinon au contact (3).
						local reach = if L > 0 then ChaseCfg.LagContactReach else C
						local expected = reach + rec.speed * (rec.L + rec.up) + rec.guardSpeed * (rec.L + rec.down)
						check(near(d.seen, expected, 2), label .. string.format(" avant : vue à %.1f ± 2 : %.1f", expected, d.seen))
					else
						check(d.seen <= C + rec.speed * FRAME + 0.1 and a.seen <= C + rec.speed * FRAME + 0.1 and a.gap >= 1, label .. " : vigile à portée à la décision et à l'annonce, à une image de course près (" .. fmt(d.seen) .. ", " .. fmt(a.gap) .. ")")
						check(rec.restGap >= 1 and rec.restGap <= C + 0.5, label .. " : au repos, derrière lui, à portée (" .. fmt(rec.restGap) .. ")")
					end
				end
			end
		end
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- tenue : au-dessus du minimum, distance gardée
	if BASE == "tenue" or S == "ecart" then
		local runs = {}
		if S == "ecart" then
			section("ecart : tampons réels autres que BaseSeconds : le vigile est décalé de vitesse × erreur, sans capture")
			table.insert(runs, { entry = SPEEDS[6], L = PING60, up = 11 / 60, down = 10 / 60, label = "zone 6, tampons 0,35 s (0,10 de plus)" })
			table.insert(runs, { entry = SPEEDS[6], L = PING60, up = 5 / 60, down = 4 / 60, label = "zone 6, tampons 0,15 s (0,10 de moins)" })
		else
			section("tenue (" .. TAG .. ") : au-dessus du minimum, le vigile garde HoldDistance à l'écran du joueur")
			for _, index in { 1, 4, 6, 7 } do
				table.insert(runs, { entry = SPEEDS[index], L = PING60, label = SPEEDS[index].label })
			end
			table.insert(runs, { entry = SPEEDS[6], L = 0, label = "zone 6, ping 0" })
			table.insert(runs, { entry = SPEEDS[6], L = 6 / 60, label = "zone 6, ping 200 ms" })
		end
		for _, run in runs do
			-- Speed du panneau, au moins le minimum de la zone 1 (10) : au-dessus du minimum.
			local rec = chase416({ speed = math.max(run.entry.speed, ChaseCfg.Zone1SpeedRequired), L = run.L, up = run.up, down = run.down, seconds = 18 })
			check(rec ~= nil and rec.model ~= nil, run.label .. " : braquage, vigile apparu")
			if rec and rec.model then
				local lo, hi, count = span416(rec, "gap", 15, 18)
				local walkNow = rec.samples[#rec.samples].walk
				local D = 2 * rec.L + rec.up + rec.down
				print(string.format("  mesure %s %s : marche %.1f, ping %d ms ; distance vue %.1f à %.1f (prévue %d)", TAG, run.label, walkNow, run.L * 2000, lo, hi, ChaseCfg.HoldDistance))
				check(rec.caughtT == nil, run.label .. " : pas de capture en ligne droite au-dessus du minimum")
				if S == "ecart" then
					-- décalage = marche × (retard réel − retard compensé)
					local model = CV.BaseSeconds + 2 * rec.L
					local expected = ChaseCfg.HoldDistance + walkNow * (D - model)
					check(count > 0 and near((lo + hi) / 2, expected, 1), run.label .. string.format(" : distance vue %.1f ± 1 (%.1f à %.1f)", expected, lo, hi))
					local found = ((lo + hi) / 2 - ChaseCfg.HoldDistance) / walkNow
					check(near(found, D - model, 0.015), run.label .. string.format(" : la recette retrouve l'erreur de BaseSeconds, %+.3f s (%+.3f)", D - model, found))
				elseif AVANT then
					local lead = math.min(walkNow * math.min(2 * rec.L, ChaseCfg.LagMaxSeconds), ChaseCfg.LagMaxStuds)
					local expected = ChaseCfg.HoldDistance - lead + walkNow * D
					check(count > 0 and near((lo + hi) / 2, expected, 1.5), run.label .. string.format(" avant : distance vue %.1f ± 1,5 (%.1f à %.1f)", expected, lo, hi))
				else
					check(count > 0 and lo >= ChaseCfg.HoldDistance - 1 and hi <= ChaseCfg.HoldDistance + 1,
						run.label .. string.format(" : distance vue %d ± 1 (%.1f à %.1f)", ChaseCfg.HoldDistance, lo, hi))
				end
			end
			finish416(rec)
		end
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- arret : le voleur s'arrête net
	if BASE == "arret" then
		section("arret (" .. TAG .. ") : au-dessus du minimum, il court 8 s puis s'arrête net ; élan du vigile simulé (700 studs/s²)")
		for _, index in { 1, 6 } do
			local entry = SPEEDS[index]
			local STOP = 8
			local rec = chase416({ speed = math.max(entry.speed, ChaseCfg.Zone1SpeedRequired), L = PING60, seconds = 14, frame = function(t, r)
				MOMENTUM = 700
				if r.stopT == nil and t >= STOP then
					r.stopT = now()
					stop(r.P)
				end
			end })
			check(rec ~= nil and rec.model ~= nil, entry.label .. " : braquage, vigile apparu")
			if rec and rec.model then
				check(rec.caughtT ~= nil and rec.stopT ~= nil and rec.caughtT > rec.stopT, entry.label .. " : arrêté, il est attrapé")
				if rec.caughtT and rec.stopT then
					-- Entre l'arrêt et la décision : au plus près à l'écran, et jusqu'où le vigile a dépassé le joueur (signé).
					local closest, beyond = math.huge, 0
					for _, s in rec.samples do
						if s.t >= rec.stopT and s.t <= rec.caughtT then
							closest = math.min(closest, s.seen)
							beyond = math.min(beyond, s.gap)
						end
					end
					local rest = horizontal(rec.rest.truth, rec.rest.guard)
					print(string.format("  mesure %s %s : marche %.1f ; attrapé %.2f s après l'arrêt ; au plus près à l'écran %.1f, dépassé de %.1f ; vue à la décision %.1f, à l'annonce %.1f, au repos %.1f",
						TAG, entry.label, rec.speed, rec.caughtT - rec.stopT, closest, -beyond, rec.decision.seen, rec.announce.seen, rest))
					check(rec.caughtT - rec.stopT <= 1, entry.label .. " : attrapé en au plus 1 s après l'arrêt (" .. fmt(rec.caughtT - rec.stopT) .. ")")
					if not AVANT then
						check(closest <= C + rec.speed * FRAME + 0.1, entry.label .. " : avant la capture, le joueur a vu le vigile à portée (" .. fmt(closest) .. ")")
						check(rest >= 1 and rest <= C + 0.5, entry.label .. " : au repos, à portée et pas dans le joueur (" .. fmt(rest) .. ")")
					end
				end
			end
			finish416(rec)
		end
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- depart : départ arrêté
	if BASE == "depart" then
		section("depart (" .. TAG .. ") : immobile devant le magasin, il part en courant quand il voit le vigile à 20 studs (vitesse de la zone 6)")
		local entry = SPEEDS[6]
		local rec = chase416({ speed = entry.speed, L = PING60, stay = true, seconds = 20, frame = function(_, r)
			local last = r.samples[#r.samples]
			if r.startT2 == nil and last and r.caughtT == nil and last.seen <= 20 then
				r.startT2 = now()
				r.startSeen = last.seen
				walk(r.P, FAR2)
			end
		end })
		check(rec ~= nil and rec.model ~= nil, "D1 braquage, vigile apparu")
		if rec and rec.model then
			if AVANT then
				check(rec.caughtT ~= nil, "D2 avant : attrapé")
				if rec.caughtT then
					print(string.format("  mesure avant départ arrêté : attrapé %s, vigile vu à %.1f studs à la décision, %.1f à l'annonce (vigile %.1f studs/s)",
						if rec.startT2 then "après son départ" else "avant d'avoir pu partir", rec.decision.seen, rec.announce.seen, rec.guardSpeed))
					check(rec.decision.seen >= 15, "D3 avant : attrapé alors qu'il voit le vigile à plus de 15 studs (" .. fmt(rec.decision.seen) .. ")")
				end
			else
				check(rec.startT2 ~= nil, "D2 le vigile arrive à 20 studs à l'écran, il part")
				local closest = math.huge
				for _, s in rec.samples do
					if rec.startT2 and s.t >= rec.startT2 then
						closest = math.min(closest, s.seen)
					end
				end
				local lo, hi = span416(rec, "gap", 17, 20)
				print(string.format("  mesure après départ arrêté : parti à %.1f studs ; au plus près ensuite %.1f ; attrapé : %s ; distance vue à la fin %.1f à %.1f",
					rec.startSeen or -1, closest, tostring(rec.caughtT ~= nil), lo, hi))
				check(rec.caughtT == nil, "D3 pas de capture : le vigile ne l'a jamais touché à l'écran")
				check(closest > C + 2, "D4 au plus près, le vigile reste à plus de 6 studs à l'écran (" .. fmt(closest) .. ")")
				check(lo >= ChaseCfg.HoldDistance - 1.5 and hi <= ChaseCfg.HoldDistance + 1.5, "D5 puis il le suit à HoldDistance ± 1,5 (" .. fmt(lo) .. " à " .. fmt(hi) .. ")")
			end
		end
		finish416(rec)
		summary("scénario " .. S)
		return
	end

	---------------------------------------------------------------- heurte : voleur qui heurte encore les vigiles
	if S == "heurte" then
		section("heurte : personnage dans un groupe qui heurte les vigiles : la règle d'avant, jamais inoffensif")
		COLLISION_GROUPS.Bloc416 = true
		local entry = SPEEDS[6]
		local rec = chase416({ speed = entry.speed, L = PING60, seconds = 22, group = "Bloc416" })
		check(rec ~= nil and rec.model ~= nil, "H1 braquage, vigile apparu")
		if rec and rec.model then
			check(rec.caughtT ~= nil, "H2 sous le minimum, il est attrapé quand même")
			check(rootOf(rec.P).CollisionGroup == "Bloc416", "H3 son groupe n'est pas changé")
			if rec.caughtT then
				print(string.format("  mesure heurte : marche %.1f ; à la décision : sur le serveur %.1f (au contact de la copie), vue %.1f", rec.speed, rec.decision.server, rec.decision.seen))
				check(near(rec.decision.server, ChaseCfg.LagContactReach, 0.8), "H4 capture au contact de la copie du serveur (" .. fmt(rec.decision.server) .. ")")
			end
		end
		finish416(rec)
		summary("scénario " .. S)
		return
	end

	check(false, "scénario inconnu : " .. S)
	summary("scénario " .. S)
end
