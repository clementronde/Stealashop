--!nocheck
-- Plans du TRAILER DE LANCEMENT (session « Trailer de lancement », pour Clément).
-- À charger en Edit par execute_luau APRÈS trailer_lib.luau puis shots.luau (session TikTok) : ce fichier n'utilise que
-- _G.Trailer et ne modifie ni l'outil ni les plans TikTok.
--
-- Chaque sujet est enregistré deux fois :
--   T.shots.L_<nom>_h : 16:9 (roll = false), rendu 1920 × 1080 à 60 i/s
--   T.shots.L_<nom>_v : 9:16 (roll = true), rendu 1080 × 1920 à 60 i/s
-- Tournage : T.prepare("L_casse_orbite_h") → capture.sh → T.go() (méthode du skill trailer-tiktok).
-- À NE PAS tourner (doublons, on prend les plans de la session TikTok, en 9:16 et en 16:9) :
--   couloir_accroche → couloir_drone, tapis_orbite → tapis_orbite, casse_orbite → vitrine_orbite,
--   colis_legendaire → colis_ouvert + vol_grab, poursuite_z4 → poursuite_arriere, porte_zone4 → porte_zone3,
--   presentoirs_enfilade → boutique_exposes, argent_plaque → plaque_argent.
-- À tourner ici (12) : couloir_fin, tapis_pieds, facade_bijouterie, rideau_monte, vigile_fige, colis_rate, vigile_surgit,
--   vigile_epuise, boutique_pose, nuit_mur, braquage_porte, braquage_batte.
-- Tout ce qui est créé va dans Workspace/_TRAILER (FX vidé à chaque plan, acteurs repris d'un plan à l'autre) ;
-- ce qui est caché hors de _TRAILER l'est par LocalTransparencyModifier (jamais enregistré) et remis par T.stop().
--
-- Repères relevés dans la place DEV le 2026-11-24 (à revérifier par T.peek avant de tourner) :
--   Bijouterie (zone 4, nord) : Window (442, 6.1, 54.8), Shutter levé (442, 17.9, 53.6), ShelfSlot_01 (433.1, 2.8, 77.5)
--   PLOT_Shop_01 : tapis, Belt (-66.6, 0.9, 168.6) ; PlotDoor.Window (-42, 5.9, 177.5) ; CashPad (-64.4, -0.5, 187) ;
--                  DisplaySlot_01 (-66, 2.7, 184) … DisplaySlot_20
--   Couloir : rue z de -48 à 48, ZoneGate_4 à x = 368 ; mur de nuit Map/Entry/NightWall (27, -12.2, 0), monte de 24.

local T = _G.Trailer
assert(T and T.moves and T.actor, "charger trailer_lib.luau d'abord")
local V = Vector3.new
local M = T.moves
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")

local L = {}
T.launch = L

------------------------------------------------------------------------------------------------
-- Aides (locales à ce fichier)
------------------------------------------------------------------------------------------------
local function store(name: string): Instance
	local s = workspace.Map:FindFirstChild(name, true)
	assert(s, "introuvable dans la Map : " .. name)
	return s
end

local function once(S, key: string, t: number, at: number, fn)
	if t >= at and not S["_" .. key] then
		S["_" .. key] = true
		fn()
	end
end

local function fxFolder(): Folder
	local r = T.root()
	local f = r:FindFirstChild("FX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "FX"
		f.Parent = r
	end
	return f
end

local function strip(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
end

local function freeze(m: Instance)
	local list = m:GetDescendants()
	table.insert(list, m)
	for _, d in list do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
end

local function ease(name: string, u: number): number
	return (T.ease[name] or T.ease.linear)(math.clamp(u, 0, 1))
end

-- Copie d'un asset dans _TRAILER/FX (vidé à chaque plan). folder : nom d'un dossier de ReplicatedStorage/Assets, ou une Instance.
function L.prop(folder, name: string, scale: number?)
	local f = if typeof(folder) == "Instance" then folder else Assets:FindFirstChild(folder)
	local src = f and f:FindFirstChild(name, true)
	assert(src, "asset introuvable : " .. tostring(folder) .. "/" .. name)
	local m = src:Clone()
	strip(m)
	freeze(m)
	if scale and scale ~= 1 and m:IsA("Model") then m:ScaleTo(m:GetScale() * scale) end
	m.Parent = fxFolder()
	return m
end

-- Pose un modèle par le bas de sa boîte englobante, centré en p, tourné de yaw degrés.
function L.setOn(m: Model, p: Vector3, yaw: number?)
	local cf = CFrame.new(p) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	m:PivotTo(cf)
	local bb, size = m:GetBoundingBox()
	local bottom = bb.Position - Vector3.new(0, size.Y / 2, 0)
	m:PivotTo(cf + (p - bottom))
end

-- Émet une fois toutes les particules d'un effet de Assets/FX, posé en cf.
function L.emit(name: string, cf: CFrame, mult: number?)
	local m = L.prop("FX", name)
	if m:IsA("Model") then m:PivotTo(cf) elseif m:IsA("BasePart") then m.CFrame = cf end
	for _, e in m:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e:Emit(math.max(1, math.floor((e:GetAttribute("EmitCount") or 20) * (mult or 1))))
		end
	end
	return m
end

-- Cache une instance de la Map pendant le plan (local, jamais enregistré ; remis par T.stop()).
function L.hide(inst: Instance)
	local saved = {}
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, p in list do
		if p:IsA("BasePart") then
			if T.hideLocal then
				-- registre commun de l'outil (2026-11-25) : seule la première valeur vue est gardée, un 1 de départ se remet à 0
				T.hideLocal(p)
				saved[p] = true
			else
				-- une pièce déjà cachée (plan précédent, repérage) se remet à 0 et non à 1, sinon elle resterait cachée
				saved[p] = if p.LocalTransparencyModifier >= 1 then 0 else p.LocalTransparencyModifier
				p.LocalTransparencyModifier = 1
			end
		end
	end
	-- remise à la fin de CE plan (T.restoreLocal n'est appelé qu'au T.clear) : la vitre cachée ici ne reste pas cachée au plan suivant
	table.insert(T._restore, function()
		for p, v in saved do
			if p.Parent then
				if v == true then
					p.LocalTransparencyModifier = (T._ltm and T._ltm[p]) or 0
					if T._ltm then T._ltm[p] = nil end
				else
					p.LocalTransparencyModifier = v
				end
			end
		end
	end)
end

-- Un acteur propre pour une nouvelle prise : animations arrêtées, objet porté et outil retirés.
function L.fresh(id: string, look: string)
	local a = T.actor(id, look)
	if a.held then pcall(function() a.held.model:Destroy() end) a.held = nil end
	if a.carried then pcall(function() a.carried.model:Destroy() end) a.carried = nil end
	a:stopAll()
	return a
end

-- Outil dans la main droite, pris dans n'importe quel dossier d'Assets (Tools ou Unbox). Même prise en main que T.fx.hold.
function L.hold(actor, folder: string, name: string)
	local m = L.prop(folder, name)
	actor.held = { model = m, grip = CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.45, 0) }
	return m
end

-- Objet au-dessus de la tête (même calcul que T.fx.carry, mais rangé dans FX, vidé à chaque plan).
function L.carry(actor, itemName: string, scale: number?)
	local m = L.prop("Items", itemName, scale)
	local bb, size = m:GetBoundingBox()
	local head = actor.model:FindFirstChild("Head")
	actor.carried = { model = m, offset = m:GetPivot():ToObjectSpace(bb), lift = head.Size.Y / 2 + size.Y / 2 + 0.5 }
	return m
end

-- Aura du jeu (Assets/FX/Auras) collée à l'acteur à chaque image.
function L.aura(S, actor, name: string)
	local m = L.prop(Assets.FX:FindFirstChild("Auras"), name)
	S.auras = S.auras or {}
	table.insert(S.auras, { model = m, actor = actor })
	return m
end

-- Billboard du jeu (Assets/UI/BB_*) posé sur une pièce.
function L.billboard(name: string, adornee: BasePart)
	local src = Assets.UI:FindFirstChild(name)
	assert(src, "billboard introuvable : " .. name)
	local b = src:Clone()
	strip(b)
	b.Adornee = adornee
	b.Enabled = true
	-- décalage dans le repère du monde : en 9:16 la caméra est couchée, et le « haut » de la caméra devenait le côté
	if b.StudsOffset.Magnitude > 0 then
		b.StudsOffsetWorldSpace = b.StudsOffset
		b.StudsOffset = Vector3.zero
	end
	b.Parent = fxFolder()
	return b
end

-- Objet qui vole en arc de a à b (billets et pièces vers le joueur).
function L.fly(S, m: Instance, a: Vector3, b: Vector3, t0: number, dur: number, arc: number)
	S.flights = S.flights or {}
	table.insert(S.flights, { m = m, a = a, b = b, t0 = t0, dur = dur, arc = arc })
end

-- À appeler à chaque image par l'update d'un plan qui utilise L.aura ou L.fly.
local function stepExtras(S, t: number)
	for _, au in S.auras or {} do
		au.model:PivotTo(au.actor.root.CFrame)
	end
	for _, f in S.flights or {} do
		local u = math.clamp((t - f.t0) / f.dur, 0, 1)
		if f.m.Parent then
			if u <= 0 then
				f.m:PivotTo(CFrame.new(V(0, -1000, 0)))
			else
				local p = f.a:Lerp(f.b, ease("inQuad", u)) + V(0, math.sin(math.pi * u) * f.arc, 0)
				f.m:PivotTo(CFrame.new(p) * CFrame.Angles(0, t * 9, t * 4))
				if u >= 1 then f.m:Destroy() end
			end
		end
	end
end

-- Objet qui sort du colis : monte de a à b avec un léger rebond et tourne sur lui-même.
local function riseItem(m: Model, base: Vector3, height: number, u: number, t: number)
	local k = ease("outBack", u)
	L.setOn(m, base + V(0, height * k, 0), t * 140)
end

-- Garnit les présentoirs d'une boutique de joueur avec des objets de la zone 4 (copies dans FX).
local SHOW_ITEMS = {
	"ITM_Z4_Couronne", "ITM_Z4_DiamantBrut", "ITM_Z4_HorlogeDeParquet", "ITM_Z4_OeufEnDiamant", "ITM_Z4_ChihuahuaEnDiamants",
	"ITM_Z4_GuitareNeon", "ITM_Z4_TropheeDeStar", "ITM_Z4_MontreGlacee", "ITM_Z4_BasketsEnOr", "ITM_Z4_CollierDePerles",
	"ITM_Z4_MicroDePopStar", "ITM_Z4_GrillzEnDiamant", "ITM_Z4_CoffretDeMontres", "ITM_Z4_PerruquePresidentielle",
	"ITM_Z4_LunettesDeStar", "ITM_Z4_ChaineDrip", "ITM_Z4_Rubis", "ITM_Z4_MontreAGousset", "ITM_Z4_BasketsLumineuses", "ITM_Z4_Parfum",
}
function L.fillPlot(plot: Instance, skip: { [number]: boolean }?)
	for i = 1, 20 do
		if not (skip and skip[i]) then
			local slot = plot:FindFirstChild(("DisplaySlot_%02d"):format(i), true)
			if slot then
				local m = L.prop("Items", SHOW_ITEMS[i], 2.5)
				L.setOn(m, slot.WorldPosition, 180)
			end
		end
	end
end

-- Enregistre un sujet dans les deux formats. d.cam(fmt) rend le mouvement ("h" = 16:9, "v" = 9:16).
local function def(name: string, d)
	for _, fmt in { "h", "v" } do
		T.shots["L_" .. name .. "_" .. fmt] = {
			dur = d.dur,
			slow = d.slow or 2,
			roll = fmt == "v",
			cam = d.cam(fmt),
			setup = d.setup,
			update = d.update,
		}
	end
end
L.def = def

-- Champ : en 16:9 (roll = false) FieldOfView est l'angle vertical ; en 9:16 il devient l'angle horizontal de l'image.
-- Le même nombre donne un sujet à peu près de la même hauteur dans les deux formats.
local function fov(fmt: string, base: number): number
	return if fmt == "h" then base else base
end

------------------------------------------------------------------------------------------------
-- Repères
------------------------------------------------------------------------------------------------
local BIJ_WIN = V(442, 6.1, 54.8)
local BIJ_SLOT1 = V(433.1, 2.8, 77.5)
local BELT = V(-66.6, 0.9, 168.6)
local PLOT1_SLOT1 = V(-66, 2.7, 184)
local CASHPAD = V(-64.4, 0, 187)

------------------------------------------------------------------------------------------------
-- 02. Fin : recul au-dessus du couloir, qui retombe sur le cadre de l'accroche (la vidéo boucle).
------------------------------------------------------------------------------------------------
local DRONE = T.shots.couloir_drone or { setup = function() end } -- shots.luau (session TikTok) : figurants du couloir
def("couloir_fin", {
	dur = 4,
	cam = function(fmt)
		return M.path({ keys = { { 0, V(70, 22, 0), V(330, 0, 0) }, { 4, V(15, 36, 0), V(275, 3, 0) } }, ease = "outCubic", fov = fov(fmt, 48) })
	end,
	setup = DRONE.setup,
	update = DRONE.update,
})

------------------------------------------------------------------------------------------------
-- 04. Entraînement, les pieds sur le tapis en gros plan (même acteur, orbite au ras du tapis).
------------------------------------------------------------------------------------------------
def("tapis_pieds", {
	dur = 3,
	cam = function(fmt)
		return M.orbit({ center = BELT + V(0, 0.9, 0), radius = 4.5, height = 0.3, from = 330, to = 300, dur = 3, ease = "linear", fov = fov(fmt, 50) })
	end,
	setup = function(S)
		local p = L.fresh("coureur_tapis", "bacon")
		S.actors.p1 = p
		p:place(BELT, V(0, 0, -1))
		p:play("TreadmillRun", { fade = 0, looped = true })
		L.aura(S, p, "FX_Aura_Foudre")
	end,
	update = function(S, t, dt)
		stepExtras(S, t)
	end,
})

------------------------------------------------------------------------------------------------
-- 06. Façade de la Bijouterie en travelling latéral ; le joueur arrive, le vigile de la zone 4 le fixe devant la vitrine.
------------------------------------------------------------------------------------------------
local P06 = { { 0, V(424, 0.4, 44) }, { 3, V(438, 0.4, 47) } }
def("facade_bijouterie", {
	dur = 3,
	cam = function(fmt)
		return M.travelling({ from = V(458, 5, 18), look = V(458, 9, 54.75), dir = "droite", dist = 22, dur = 3, ease = "linear", fov = fov(fmt, 48) })
	end,
	setup = function(S)
		local p = L.fresh("braqueur", "bacon")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:follow(P06, 0)
		p:play("Walk", { fade = 0 })
		local g = L.fresh("vigile_z4", "guard:Guard_Z4")
		S.actors.g1 = g
		g:place(V(450, 0.4, 50), V(-1, 0, -0.4))
		g:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		local p = S.actors.p1
		p:follow(P06, t)
		once(S, "stop", t, 2.6, function()
			p:stop("Walk", 0.15)
			p:play("Idle", { fade = 0.15 })
		end)
	end,
})

------------------------------------------------------------------------------------------------
-- 07. Révélation : le rideau de la Bijouterie remonte devant le joueur (copie animée ; le vrai rideau est caché).
------------------------------------------------------------------------------------------------
def("rideau_monte", {
	dur = 3,
	cam = function(fmt)
		return M.travelling({ from = V(442, 3, 26), look = V(442, 7, 54.8), dir = "avant", dist = 7, dur = 3, ease = "linear", fov = fov(fmt, 50) })
	end,
	setup = function(S)
		local st = store("STORE_Z4_Bijouterie")
		local real = st:FindFirstChild("Shutter")
		local copy = real:Clone()
		strip(copy)
		freeze(copy)
		copy.Parent = fxFolder()
		L.hide(real)
		S.shutter = { m = copy, up = real:GetPivot(), down = real:GetPivot() - V(0, 11.8, 0) }
		copy:PivotTo(S.shutter.down)
		local p = L.fresh("braqueur", "bacon")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:place(V(442, 0.4, 48.5), V(0, 0, 1))
		p:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		local sh = S.shutter
		sh.m:PivotTo(sh.down:Lerp(sh.up, ease("outCubic", (t - 0.4) / 1.2)))
	end,
})

------------------------------------------------------------------------------------------------
-- 08. Casse : deux coups de batte, la vitrine éclate vers la rue ; orbite basse, secousse à l'impact.
------------------------------------------------------------------------------------------------
local function hitThenBreak(S, p, t, target, normal)
	once(S, "hit1", t, 0.25, function()
		S.hit = p:play("HitWindow", { looped = false, fade = 0.08 })
	end)
	once(S, "hit2", t, 0.85, function()
		p:stop("HitWindow", 0)
		S.hit = p:play("HitWindow", { looped = false, fade = 0.05 })
		S.hit2At = t
	end)
	local tr = S.hit
	-- marqueur Impact non lu en Edit : impact à 40 % de l'animation (comme vitrine_orbite)
	if S.hit2At and not S.breakAt and ((tr.Length > 0 and tr.TimePosition >= tr.Length * 0.4) or t > S.hit2At + 0.5) then
		S.breakAt = t
		table.insert(S.fx, T.fx.breakWindow(if typeof(target) == "string" then store(target) else target, { speed = 0.6, normal = normal }))
	end
end

------------------------------------------------------------------------------------------------
-- 09. Le vigile figé : la vitrine éclate à côté de lui, la caméra fonce sur son visage (arrêt sur image au montage).
------------------------------------------------------------------------------------------------
def("vigile_fige", {
	dur = 2,
	cam = function(fmt)
		return M.shake(M.travelling({ from = V(445.5, 4.8, 44.5), look = V(450, 4.7, 49.6), dir = "avant", dist = 2.6, dur = 2, ease = "linear", fov = fov(fmt, 45) }), { atKey = "breakAt", dur = 0.3, amp = 0.2 })
	end,
	setup = function(S)
		local p = L.fresh("braqueur", "bacon")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:place(V(442, 0.4, 50.2), V(0, 0, 1))
		p:play("Idle", { fade = 0 })
		local g = L.fresh("vigile_z4", "guard:Guard_Z4")
		S.actors.g1 = g
		g:place(V(450, 0.4, 50), V(-1, 0, -0.4))
		g:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		hitThenBreak(S, S.actors.p1, t, "STORE_Z4_Bijouterie")
	end,
})

------------------------------------------------------------------------------------------------
-- 10. et 11. Colis : pied de biche, le colis s'ouvre. 10 = gag (une Bague minuscule, Commun), 11 = la Couronne (Légendaire).
------------------------------------------------------------------------------------------------
local function boxShot(boxName: string, itemName: string, itemScale: number, rise: number, withGrab: boolean)
	return {
		dur = if withGrab then 3 else 2.6,
		cam = function(fmt)
			if withGrab then
				return M.path({ keys = {
					{ 0, V(437, 3.6, 70), BIJ_SLOT1 + V(0, 0.6, 0) },
					{ 1.5, V(435.6, 3.8, 72), BIJ_SLOT1 + V(0, 0.8, 0) },
					{ 3, V(435, 5.6, 72.4), BIJ_SLOT1 + V(0, 3, -1) },
				}, ease = "linear", fov = fov(fmt, 45) })
			end
			return M.travelling({ from = V(436.5, 4, 69.5), look = BIJ_SLOT1 + V(0, 0.6, 0), dir = "avant", dist = 2, dur = 2.6, ease = "linear", fov = fov(fmt, 45) })
		end,
		setup = function(S)
			local p = L.fresh("ouvreur", "bacon")
			S.actors.p1 = p
			L.hold(p, "Unbox", "TOOL_Unbox_Crowbar")
			p:place(V(433.1, 0, 74), V(0, 0, 1))
			p:play("Idle", { fade = 0 })
			S.box = L.prop("Boxes", boxName)
			L.setOn(S.box, BIJ_SLOT1, 180)
		end,
		update = function(S, t, dt)
			local p = S.actors.p1
			once(S, "pry", t, 0.2, function()
				p:play("Unbox_Crowbar", { looped = false, fade = 0.1 })
			end)
			once(S, "open", t, 1.3, function()
				S.box:Destroy()
				L.emit("FX_Unbox_Burst", CFrame.new(BIJ_SLOT1 + V(0, 0.6, 0)))
				if withGrab then L.emit("FX_Unbox_Reveal", CFrame.new(BIJ_SLOT1 + V(0, 1.5, 0))) end
				S.item = L.prop("Items", itemName, itemScale)
				S.openAt = t
			end)
			if S.item and not S.grabbed then riseItem(S.item, BIJ_SLOT1, rise, (t - S.openAt) / 0.5, t) end
			if withGrab then
				once(S, "grab", t, 2.1, function()
					p:play("Grab", { looped = false, fade = 0.08 })
				end)
				once(S, "take", t, 2.45, function()
					S.grabbed = true
					S.item:Destroy()
					if p.held then p.held.model:Destroy() p.held = nil end
					L.carry(p, itemName, itemScale)
					p:play("CarryIdle", { fade = 0.1 })
				end)
			end
		end,
	}
end
def("colis_rate", boxShot("BOX_Common", "ITM_Z4_Bague", 1.3, 1.6, false))

------------------------------------------------------------------------------------------------
-- 12. Le vigile surgit du fond du magasin en criant ; le voleur sort du champ avec la Couronne.
------------------------------------------------------------------------------------------------
local G12 = { { 0, V(445, 0, 96) }, { 2.6, V(443, 0, 56) } }
local P12 = { { 0, V(440, 0, 62) }, { 1.6, V(434, 0, 36) } }
def("vigile_surgit", {
	dur = 2.6,
	cam = function(fmt)
		return M.travelling({ from = V(441, 2.6, 40), look = V(443, 4.5, 75), dir = "avant", dist = 3, dur = 2.6, ease = "linear", fov = fov(fmt, 48) })
	end,
	setup = function(S)
		L.hide(store("STORE_Z4_Bijouterie"):FindFirstChild("Window"))
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		L.carry(p, "ITM_Z4_Couronne", 3)
		p:follow(P12, 0)
		p:play("Run", { fade = 0 })
		p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z4", "guard:Guard_Z4")
		S.actors.g1 = g
		g:follow(G12, 0)
		g:play("Run", { fade = 0 })
	end,
	update = function(S, t, dt)
		S.actors.p1:follow(P12, t)
		S.actors.g1:follow(G12, t)
		once(S, "shout", t, 0.5, function()
			local head = S.actors.g1.model:FindFirstChild("Head")
			L.billboard("BB_GuardShout", head)
		end)
	end,
})

------------------------------------------------------------------------------------------------
-- 14. Le vigile à bout de souffle : il s'arrête, plié en deux (Tired) ; la caméra avance sur lui.
------------------------------------------------------------------------------------------------
local G14 = { { 0, V(402, 0, 13) }, { 0.9, V(393, 0, 13) } }
def("vigile_epuise", {
	dur = 2.6,
	cam = function(fmt)
		return M.travelling({ from = V(384.5, 3.4, 10.5), look = V(393, 3.4, 13), dir = "avant", dist = 3, dur = 2.6, ease = "linear", fov = fov(fmt, 45) })
	end,
	setup = function(S)
		local g = L.fresh("vigile_z4", "guard:Guard_Z4")
		S.actors.g1 = g
		g:follow(G14, 0)
		g:play("Run", { fade = 0 })
	end,
	update = function(S, t, dt)
		local g = S.actors.g1
		if t < 0.9 then g:follow(G14, t) end
		once(S, "tired", t, 0.9, function()
			g:stop("Run", 0.2)
			g:play("Tired", { fade = 0.2, looped = true })
		end)
	end,
})

------------------------------------------------------------------------------------------------
-- 15. En base : le joueur pose la Couronne sur un présentoir de sa boutique, l'éclat s'allume.
------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------
-- 18. Nuit (version truquée, en Edit) : le mur de nuit monte (copie), un vigile de nuit arrête un figurant.
-- La lumière de nuit ne se fait pas en Edit (Lighting est à Clément) : teinte de nuit au montage, OU vraie nuit en Play
-- avec l'accord de Clément (tools/clement/video/nuit_qui_tombe.luau).
------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------
-- 19. Braquage d'un autre joueur : un ami casse la vitre de la porte de ta boutique (PLOT_Shop_01).
------------------------------------------------------------------------------------------------
def("braquage_porte", {
	dur = 2.6,
	cam = function(fmt)
		return M.shake(M.orbit({ center = V(-42, 4.5, 175.5), radius = 10, height = -1, from = 120, to = 60, dur = 2.6, ease = "sine", fov = fov(fmt, 48), lookUp = 0.5 }), { atKey = "breakAt", dur = 0.3, amp = 0.25 })
	end,
	setup = function(S)
		local p = L.fresh("ami", "bacon_guitare")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:place(V(-42, 0, 174.3), V(0, 0, 1))
		p:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt)
		hitThenBreak(S, S.actors.p1, t, store("PLOT_Shop_01"):FindFirstChild("PlotDoor"), V(0, 0, -1))
	end,
})

------------------------------------------------------------------------------------------------
-- 20. Riposte : l'ami sort avec ton objet, tu le frappes à la batte, il tombe et l'objet roule par terre.
------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------
-- Corrections du 2026-11-25 (retours de Clément sur le premier montage) :
-- même vigile (Guard_Z4) et même objet volé (la Couronne) partout ; casse sur la vitrine de la Bijouterie (celle du rideau) ;
-- vigile figé filmé plus large (on voit le joueur casser) ; pieds sur le tapis de la boutique 03 (même coureur que
-- tapis_orbite) ; colis posé au bout du pied de biche, verre du rayon caché, objet qui sort vers l'allée ; en boutique,
-- le joueur est déjà entré par la porte et ne traverse aucune vitre ; présentoirs garnis d'objets du catalogue actif.
------------------------------------------------------------------------------------------------
local ITEM = "ITM_Z4_Couronne"
local GUARD = "guard:Guard_Z4"
local SAFE_ITEMS = { "ITM_Z4_Couronne", "ITM_Z4_DiamantBrut", "ITM_Z4_HorlogeDeParquet", "ITM_Z4_CollierDePerles", "ITM_Z4_MontreAGousset",
	"ITM_Z4_Rubis", "ITM_Z4_CoffretDeMontres", "ITM_Z4_LunettesDeStar", "ITM_Z4_BasketsDeCollection", "ITM_Z4_PenduleDoree",
	"ITM_Z4_ChaineEnOr", "ITM_Z4_MontreEnOr", "ITM_Z4_Parfum", "ITM_Z4_Bague" }
function L.fillPlot(plot: Instance, skip: { [number]: boolean }?)
	for i = 1, 20 do
		if not (skip and skip[i]) then
			local slot = plot:FindFirstChild(("DisplaySlot_%02d"):format(i), true)
			if slot then
				local m = L.prop("Items", SAFE_ITEMS[((i - 1) % #SAFE_ITEMS) + 1], 2.5)
				L.setOn(m, slot.WorldPosition, 180)
			end
		end
	end
end

for _, f in { "h", "v" } do
	T.shots["L_vigile_fige_" .. f].cam = M.shake(M.travelling({ from = V(455.5, 4.8, 37.5), look = V(446, 4.6, 51), dir = "avant", dist = 4.5, dur = 2, ease = "linear", fov = 48 }), { atKey = "breakAt", dur = 0.3, amp = 0.2 })
end

local TM15 = V(-151.7, 0, 15.4) -- tapis de la boutique 03, celui de tapis_orbite (session TikTok)
def("tapis_pieds", {
	dur = 3,
	cam = function() return M.orbit({ center = TM15 + V(0, 1.9, 0), radius = 5.5, height = 0.2, from = 198, to = 162, dur = 3, ease = "linear", fov = 48 }) end,
	setup = function(S)
		local a = L.fresh("tapis1", "bacon_guitare")
		S.actors.s1 = a
		a:place(TM15, V(1, 0, 0))
		a:play("TreadmillRun", { fade = 0, looped = true })
	end,
})

def("casse_orbite", {
	dur = 2.6,
	cam = function() return M.shake(M.orbit({ center = V(442, 4.5, 51), radius = 10, height = -1.2, from = 130, to = 60, dur = 2.6, ease = "sine", fov = 48, lookUp = 0.5 }), { atKey = "breakAt", dur = 0.3, amp = 0.25 }) end,
	setup = function(S)
		local p = L.fresh("braqueur", "bacon")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:place(V(442, 0.4, 50.2), V(0, 0, 1))
		p:play("Idle", { fade = 0 })
	end,
	update = function(S, t, dt) hitThenBreak(S, S.actors.p1, t, "STORE_Z4_Bijouterie") end,
})

local BOX = V(434.15, 2.77, 77.5) -- bord avant de la planche 2 du rayon A (verre à x = 434,7 ; planche 3 à y = 5,18)
local OUT = V(435.6, 4.35, 77.5) -- l'objet sort vers l'allée, devant la planche du dessus
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
local function boxShot2(boxName: string, itemName: string, scale: number, withGrab: boolean)
	return {
		dur = if withGrab then 3.2 else 2.6,
		cam = function()
			if withGrab then
				return M.path({ keys = {
					{ 0, V(439.4, 3.9, 72.0), BOX + V(0, 0.6, 0) },
					{ 1.6, V(439.0, 4.1, 72.6), BOX + V(0.4, 0.9, 0) },
					{ 3.2, V(439.6, 5.0, 72.2), OUT + V(0, 0.6, 0.8) },
				}, ease = "linear", fov = 45 })
			end
			return M.travelling({ from = V(439.4, 3.9, 72.0), look = BOX + V(0.3, 0.7, 0), dir = "avant", dist = 1.6, dur = 2.6, ease = "linear", fov = 45 })
		end,
		setup = function(S)
			hideShelfGlass()
			local p = L.fresh("ouvreur", "bacon")
			S.actors.p1 = p
			L.hold(p, "Unbox", "TOOL_Unbox_Crowbar")
			local P0, face = V(436.2, 0.52, 79.2), V(-1, 0, -0.55)
			p:place(P0, face)
			-- pose de l'impact (45 % de Unbox_Crowbar), puis on décale le joueur pour que le bout du pied de biche tombe sur le colis
			local tr = p:play("Unbox_Crowbar", { looped = false, fade = 0 })
			if tr.Length > 0 then tr.TimePosition = tr.Length * 0.45 end
			p.animator:StepAnimations(0)
			T.fx.updateCarry(p)
			local d = BOX + V(0, 0.45, 0) - crowbarTip(p)
			p:place(P0 + V(d.X, 0, d.Z), face)
			p:stop("Unbox_Crowbar", 0)
			p.animator:StepAnimations(0)
			p:play("Idle", { fade = 0 })
			S.box = L.prop("Boxes", boxName)
			L.setOn(S.box, BOX, 90)
		end,
		update = function(S, t, dt)
			local p = S.actors.p1
			once(S, "pry", t, 0.2, function() p:stop("Idle", 0.1) p:play("Unbox_Crowbar", { looped = false, fade = 0.1 }) end)
			once(S, "open", t, 1.3, function()
				S.box:Destroy()
				L.emit("FX_Unbox_Burst", CFrame.new(BOX + V(0, 0.6, 0)))
				if withGrab then L.emit("FX_Unbox_Reveal", CFrame.new(OUT)) end
				S.item = L.prop("Items", itemName, scale)
				S.openAt = t
			end)
			if S.item and not S.grabbed then
				-- la Bague (gag) sort vers la caméra, à gauche du joueur ; la Couronne vers l'allée
				local to = if withGrab then OUT - V(0, 0.4, 0) else V(435.1, 3.55, 76.6)
				L.setOn(S.item, BOX:Lerp(to, ease("outBack", (t - S.openAt) / 0.55)), t * 140)
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
def("colis_rate", boxShot2("BOX_Common", "ITM_Z4_Bague", 1.3, false))
def("colis_legendaire", boxShot2("BOX_Legendary", ITEM, 2.4, true)) -- 3 touchait le haut du cadre

local P13b = { { 0, V(430, 0, 10) }, { 3.6, V(372, 0, 10) } }
local G13b = { { 0, V(446, 0, 13.5) }, { 3.6, V(380, 0, 13.5) } }
def("poursuite_z4", {
	dur = 3.6,
	cam = function() return M.follow({ actor = "p1", offset = V(6.5, -1.4, -15), offsetTo = V(5, -1.6, -10), dur = 3.6, ease = "sine", lookOffset = V(2, 1.2, 1.5), lag = 0.12, fov = 50 }) end,
	setup = function(S)
		local p = L.fresh("voleur", "bacon")
		S.actors.p1 = p
		L.carry(p, ITEM, 3)
		p:follow(P13b, 0) p:play("Run", { fade = 0 }) p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z4", GUARD)
		S.actors.g1 = g
		g:follow(G13b, 0) g:play("Run", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	end,
	update = function(S, t, dt) S.actors.p1:follow(P13b, t) S.actors.g1:follow(G13b, t) end,
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

def("presentoirs_enfilade", {
	dur = 3,
	cam = function() return M.travelling({ from = V(-14, 3.2, 178), look = V(-14, 2.6, 189), dir = "droite", dist = 12, dur = 3, ease = "linear", fov = 48 }) end,
	setup = function(S) L.fillPlot(store("PLOT_Shop_01")) end,
})

------------------------------------------------------------------------------------------------
-- Corrections du 2026-11-25, 3e série (analyse image par image du montage) :
-- témoin de la zone 4 caché et vigile décalé (ils se superposaient) ; rideau forcé visible (la copie héritait de « caché ») ;
-- colis : le joueur reste devant le rayon (x ≥ 436, ses jambes passaient dans la planche du bas), le colis se place au bout
-- du pied de biche ; GRAB IT. plus large ; vigile de la poursuite côté caméra ; vrais billets pour CASH. ; nuit au premier
-- plan ; notre héros à la porte de zone 4 et sur le tapis de la boutique 03. Le plan presentoirs_enfilade n'est plus monté.
------------------------------------------------------------------------------------------------
local HERO = "bacon"
local function hideWitness()
	local w = workspace.Map.Zone_4:FindFirstChild("Witnesses")
	if w then L.hide(w) end
end
local function wrapSetup(name: string, extra)
	for _, f in { "h", "v" } do
		local sh = T.shots["L_" .. name .. "_" .. f]
		local s0 = sh.setup
		sh.setup = function(S) s0(S) extra(S) end
	end
end
wrapSetup("vigile_fige", function(S) hideWitness() S.actors.g1:place(V(450.2, 0.4, 50.8), V(-1, 0, -0.2)) end)
wrapSetup("facade_bijouterie", function(S) hideWitness() S.actors.g1:place(V(447.5, 0.4, 48.6), V(-1, 0, -0.3)) end)
wrapSetup("casse_orbite", function(S) hideWitness() end)
wrapSetup("vigile_surgit", function(S) hideWitness() end)
wrapSetup("rideau_monte", function(S)
	hideWitness()
	for _, p in S.shutter.m:GetDescendants() do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
	end
end)

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
def("colis_legendaire", boxShot3("BOX_Legendary", ITEM, 2.4, true))

local P13c = { { 0, V(430, 0, 10) }, { 3.6, V(372, 0, 10) } }
local G13c = { { 0, V(446, 0, 5.5) }, { 3.6, V(380, 0, 6.5) } } -- côté caméra : visible à côté du voleur
def("poursuite_z4", {
	dur = 3.6,
	cam = function() return M.follow({ actor = "p1", offset = V(7.5, -1.4, -16), offsetTo = V(6, -1.6, -11), dur = 3.6, ease = "sine", lookOffset = V(3, 1.2, 3), lag = 0.12, fov = 52 }) end,
	setup = function(S)
		local p = L.fresh("voleur", HERO)
		S.actors.p1 = p
		L.carry(p, ITEM, 2.4)
		p:follow(P13c, 0) p:play("Run", { fade = 0 }) p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z4", GUARD)
		S.actors.g1 = g
		g:follow(G13c, 0) g:play("Run", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	end,
	update = function(S, t, dt) S.actors.p1:follow(P13c, t) S.actors.g1:follow(G13c, t) end,
})

local P16c = { { 0, V(-64.4, 0, 180.5) }, { 1, CASHPAD } }
def("argent_plaque", {
	dur = 3,
	cam = function() return M.travelling({ from = V(-61.5, 2.2, 196), look = CASHPAD + V(-1.5, 2.6, 0), dir = "avant", dist = 2.5, dur = 3, ease = "linear", fov = 52 }) end,
	setup = function(S)
		local plot = store("PLOT_Shop_01")
		L.fillPlot(plot)
		local p = L.fresh("proprio", HERO)
		S.actors.p1 = p
		p:follow(P16c, 0) p:play("Walk", { fade = 0 })
		for i = 1, 18 do
			local slot = plot:FindFirstChild(("DisplaySlot_%02d"):format(((i - 1) % 6) + 1), true)
			local m = L.prop("FX", if i <= 10 then "FX_Collect_Bill" else "FX_Collect_Coin")
			if m:IsA("Model") and i <= 10 then m:ScaleTo(m:GetScale() * 1.6) end
			m:PivotTo(CFrame.new(0, -1000, 0))
			L.fly(S, m, slot.WorldPosition + V(0, 1.5, 0), CASHPAD + V(0, 2.8, 0), 1.0 + i * 0.05, 0.6, 3 + (i % 3))
		end
	end,
	update = function(S, t, dt)
		local p = S.actors.p1
		if t < 1 then p:follow(P16c, t) end
		once(S, "idle", t, 1, function() p:stop("Walk", 0.1) p:play("Idle", { fade = 0.1 }) end)
		stepExtras(S, t)
	end,
})

for _, f in { "h", "v" } do
	T.shots["L_nuit_mur_" .. f].cam = M.path({ keys = { { 0, V(46.5, 3.2, -21.5), V(36.5, 4.2, -9.5) }, { 3, V(50, 8.5, -25.5), V(32, 8, -5) } }, ease = "linear", fov = 50 })
end

local P05 = { { 0, V(348, 0, -10) }, { 3, V(392, 0, -10) } } -- passe la porte de la zone 4 (x = 368)
def("porte_zone4", {
	dur = 3,
	cam = function() return M.follow({ actor = "p1", offset = V(1.5, 2.2, 11), offsetTo = V(1.5, 2.6, 13), dur = 3, ease = "linear", lookOffset = V(10, 2, 0), lag = 0.12, fov = 50 }) end,
	setup = function(S)
		local p = L.fresh("braqueur", HERO)
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Batte")
		p:follow(P05, 0) p:play("Run", { fade = 0 })
	end,
	update = function(S, t, dt) S.actors.p1:follow(P05, t) end,
})

def("tapis_orbite2", {
	dur = 2.5,
	cam = function() return M.orbit({ center = TM15 + V(0, 4, 0), radius = 10, height = 1.5, from = 20, to = 65, dur = 2.5, ease = "linear", fov = 45 }) end,
	setup = function(S)
		local a = L.fresh("coureur", HERO)
		S.actors.s1 = a
		a:place(TM15, V(1, 0, 0))
		a:play("TreadmillRun", { fade = 0, looped = true })
	end,
})

------------------------------------------------------------------------------------------------
-- Corrections du 2026-11-25, 4e série (retours de Clément sur la version 3) :
-- étiquette BB_Carry du jeu au-dessus de la Couronne (nom, rareté, $/s), contour rouge quand elle est volée ;
-- vigile qui surgit seul (le voleur passait dans le bas de la vitrine et semblait courir dans le sol) ;
-- poursuite le long des vitrines du nord (la chaussée n'est qu'un aplat bleu : « il court dans le vide ») ;
-- en base, caméra de côté (le présentoir cachait les jambes) ; l'argent sur les dalles jusqu'à la plaque CollectPad_01
-- (il marchait sur le socle d'un présentoir) ; la nuit, le figurant reste debout, sonné.
------------------------------------------------------------------------------------------------
-- Revenu de la Couronne : Formulas.ItemIncome(4, "Legendary") = Zones[4].BaseIncome 450 × Rarities.Legendary 50 = 22 500,
-- écrit comme le jeu (Format.income) : « +$22.5K/s ». Couleur de la rareté : Rarities.Legendary.Color #FFC21A.
local LEG_COLOR = Color3.fromHex("#FFC21A")
local STOLEN_OUTLINE = Color3.fromHex("#E8413C") -- CarryService.OUTLINE_COLOR
function L.itemLabel(model: Model, stolen: boolean?)
	if model:FindFirstChild("_Label", true) then return end
	local cf, size = model:GetBoundingBox()
	local part
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (not part or d.Size.Magnitude > part.Size.Magnitude) then part = d end
	end
	if not part then return end
	local b = Assets.UI.BB_Carry:Clone()
	b.Name = "_Label"
	for _, d in b:GetDescendants() do
		if d:IsA("TextLabel") then
			if d.Name == "ItemName" then d.Text = "Crown"
			elseif d.Name == "Rarity" then d.Text = "LEGENDARY" d.TextColor3 = LEG_COLOR
			elseif d.Name == "Income" then d.Text = "+$22.5K/s"
			elseif d.Name == "Mutation" then d.Visible = false end
		elseif d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	b.Adornee = part
	b.StudsOffset = Vector3.zero
	b.StudsOffsetWorldSpace = V(0, (cf.Position.Y + size.Y / 2) - part.Position.Y + 1.4, 0)
	b.Parent = model
	if stolen then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = STOLEN_OUTLINE
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end
end
local function wrapUpdate(name: string, extra)
	for _, f in { "h", "v" } do
		local sh = T.shots["L_" .. name .. "_" .. f]
		local u0 = sh.update or function() end
		sh.update = function(S, t, dt) u0(S, t, dt) extra(S, t) end
	end
end
local function labelCarried(S, stolen: boolean)
	for _, a in S.actors do
		if a.carried and a.carried.model.Parent then L.itemLabel(a.carried.model, stolen) end
	end
end
wrapUpdate("colis_legendaire", function(S, t)
	if S.item and S.item.Parent then L.itemLabel(S.item, false) end
	labelCarried(S, true)
end)
wrapUpdate("boutique_pose", function(S, t) labelCarried(S, false) end)
wrapUpdate("braquage_batte", function(S, t) labelCarried(S, true) end)

-- Sol visible : le sol de l'outil ignore les pièces sans collision (dalles décoratives) ; celui-ci prend la première pièce
-- visible sous le perso, collision ou non, et y pose ses pieds.
function L.toVisibleGround(a)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { T.root() }
	local origin = a.cf.Position + V(0, 1, 0)
	for _ = 1, 10 do
		local r = workspace:Raycast(origin, V(0, -12, 0), rp)
		if not r then return end
		if r.Instance.Transparency < 0.9 and r.Instance.LocalTransparencyModifier < 0.9 then
			local h = a.hum.HipHeight + a.root.Size.Y / 2
			a.cf = a.cf + V(0, (r.Position.Y + h) - a.cf.Position.Y, 0)
			a.model:PivotTo(a.cf)
			return
		end
		origin = r.Position - V(0, 0.05, 0)
	end
end

local G12b = { { 0, V(445, 0, 96) }, { 2.6, V(443, 0, 56) } }
for _, f in { "h", "v" } do
	local sh = T.shots["L_vigile_surgit_" .. f]
	sh.setup = function(S)
		L.hide(store("STORE_Z4_Bijouterie"):FindFirstChild("Window"))
		hideWitness()
		local g = L.fresh("vigile_z4", GUARD)
		S.actors.g1 = g
		g:follow(G12b, 0)
		g:play("Run", { fade = 0 })
	end
	sh.update = function(S, t, dt)
		S.actors.g1:follow(G12b, t)
		once(S, "shout", t, 0.5, function() L.billboard("BB_GuardShout", S.actors.g1.model:FindFirstChild("Head")) end)
	end
end

local P13d = { { 0, V(430, 0, 44) }, { 3.6, V(384, 0, 44) } } -- le long des vitrines du nord (façades à z = 54,75)
local G13d = { { 0, V(446, 0, 40.5) }, { 3.6, V(393, 0, 40.5) } }
def("poursuite_z4", {
	dur = 3.6,
	cam = function() return M.follow({ actor = "p1", offset = V(8, -1.2, -16), offsetTo = V(6.5, -1.4, -11), dur = 3.6, ease = "sine", lookOffset = V(3, 2.4, 3), lag = 0.12, fov = 52 }) end,
	setup = function(S)
		local p = L.fresh("voleur", HERO)
		S.actors.p1 = p
		L.carry(p, ITEM, 2.4)
		L.itemLabel(p.carried.model, true)
		p:follow(P13d, 0) p:play("Run", { fade = 0 }) p:play("CarryRun", { fade = 0 })
		local g = L.fresh("vigile_z4", GUARD)
		S.actors.g1 = g
		g:follow(G13d, 0) g:play("Run", { fade = 0 })
		L.billboard("BB_GuardShout", g.model:FindFirstChild("Head"))
	end,
	update = function(S, t, dt) S.actors.p1:follow(P13d, t) S.actors.g1:follow(G13d, t) end,
})

for _, f in { "h", "v" } do
	T.shots["L_boutique_pose_" .. f].cam = M.orbit({ center = V(-65.6, 3, 182.2), radius = 7, height = 0.6, from = 205, to = 165, dur = 3, ease = "sine", fov = 48 })
end

local PAD = V(-61.1, 0, 184) -- Rayon_01/CollectPad_01, la plaque du présentoir 01
local P16d = { { 0, V(-53.5, 0, 184) }, { 1, PAD } }
def("argent_plaque", {
	dur = 3,
	cam = function() return M.travelling({ from = V(-54.5, 2.6, 193), look = PAD + V(-0.5, 2.4, 0), dir = "avant", dist = 2.5, dur = 3, ease = "linear", fov = 52 }) end,
	setup = function(S)
		local plot = store("PLOT_Shop_01")
		L.fillPlot(plot)
		local p = L.fresh("proprio", HERO)
		S.actors.p1 = p
		p:follow(P16d, 0, V(-1, 0, 0))
		L.toVisibleGround(p)
		p:play("Walk", { fade = 0 })
		for i = 1, 18 do
			local slot = plot:FindFirstChild(("DisplaySlot_%02d"):format(((i - 1) % 6) + 1), true)
			local m = L.prop("FX", if i <= 10 then "FX_Collect_Bill" else "FX_Collect_Coin")
			if m:IsA("Model") and i <= 10 then m:ScaleTo(m:GetScale() * 1.6) end
			m:PivotTo(CFrame.new(0, -1000, 0))
			L.fly(S, m, slot.WorldPosition + V(0, 1.5, 0), PAD + V(0, 3, 0), 1.0 + i * 0.05, 0.6, 3 + (i % 3))
		end
	end,
	update = function(S, t, dt)
		local p = S.actors.p1
		if t < 1 then
			p:follow(P16d, t, V(-1, 0, 0))
			L.toVisibleGround(p)
		end
		once(S, "idle", t, 1, function() p:stop("Walk", 0.1) p:play("Idle", { fade = 0.1 }) end)
		stepExtras(S, t)
	end,
})

-- Nuit : personne au sol (« Arrest » agenouille le vigile, « Stunned » couche le joueur, « Catch » fait plonger le vigile).
-- Le vigile de nuit marche vers le joueur puis le poursuit ; le joueur s'enfuit ; tous deux debout, devant le mur qui monte.
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

-- Caméras réglées au repérage du 2026-11-25 : en base plus loin, riposte et fin du colis visées plus haut (l'étiquette de
-- la Couronne sortait par le haut du cadre).
local BOXc = V(434.15, 2.77, 77.5)
for _, f in { "h", "v" } do
	T.shots["L_boutique_pose_" .. f].cam = M.orbit({ center = V(-64.5, 3.2, 182), radius = 9.5, height = 1.0, from = 215, to = 175, dur = 3, ease = "sine", fov = 48, lookUp = 1.2 })
	T.shots["L_braquage_batte_" .. f].cam = M.shake(M.orbit({ center = V(-45.3, 3.2, 182), radius = 12, height = 0.8, from = 325, to = 295, dur = 2.6, ease = "sine", fov = 48, lookUp = 2.2 }), { atKey = "hitAt", dur = 0.3, amp = 0.3 })
	T.shots["L_colis_legendaire_" .. f].cam = M.path({ keys = {
		{ 0, V(439.6, 3.9, 71.8), BOXc + V(0, 0.6, 0) },
		{ 1.6, V(439.4, 4.2, 72.0), BOXc + V(0.5, 1.2, 0) },
		{ 3.2, V(442.2, 5.6, 69.6), V(435.9, 6.2, 78.2) },
	}, ease = "linear", fov = 48 })
end
-- Riposte : l'étiquette et le contour rouge sur la Couronne volée, pieds sur le sol visible
for _, f in { "h", "v" } do
	local sh = T.shots["L_braquage_batte_" .. f]
	local s0 = sh.setup
	sh.setup = function(S)
		s0(S)
		for _, a in S.actors do L.toVisibleGround(a) end
		if S.actors.p1.carried then L.itemLabel(S.actors.p1.carried.model, true) end
	end
end

-- Vue 3D qui n'est pas en 16:9 (1162 × 852 le 2026-11-25) : le découpage garde une zone 16:9 ou 9:16 exacte au centre ;
-- on élargit d'autant le champ pendant la prise pour que le cadrage final soit le même (à appeler avant de tourner).
function L.compensateViewport()
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.min(1, (vp.X * 9 / 16) / vp.Y)
	for name, sh in T.shots do
		if name:sub(1, 2) == "L_" and not sh._cam0 then
			sh._cam0 = sh.cam
			local c0 = sh.cam
			sh.cam = function(t, S)
				local p, l, fv = c0(t, S)
				if fv then fv = math.deg(2 * math.atan(math.tan(math.rad(fv) / 2) / k)) end
				return p, l, fv
			end
		end
	end
	return k
end

-- Lot sans HUD : le HUD du jeu est forcé caché à chaque image pendant le lot (il s'est rallumé pendant une prise)
function L.batch(list)
	local RunService = game:GetService("RunService")
	local SG = game:GetService("StarterGui")
	pcall(function() RunService:UnbindFromRenderStep("_LancementHUD") end)
	RunService:BindToRenderStep("_LancementHUD", Enum.RenderPriority.Last.Value + 101, function()
		if T.state and T.state.phase ~= "done" then SG.ShowDevelopmentGui = false end
	end)
	local ok, res = pcall(T.batch, list)
	pcall(function() RunService:UnbindFromRenderStep("_LancementHUD") end)
	SG.ShowDevelopmentGui = true
	return if ok then res else "ERREUR " .. tostring(res)
end

-- Étiquettes en 9:16 : la caméra est couchée de 90° et l'image redressée au montage ; une BillboardGui suit l'écran,
-- elle sortirait couchée et décalée sur le côté (son SizeOffset est en fraction de l'écran). Pendant un plan couché :
-- largeur et hauteur du cadre échangées, contenu (mise en page comprise) tourné de +90°, SizeOffset tourné avec.
function L.rollFix(b: BillboardGui)
	if not (T.state and T.state.shot and T.state.shot.roll ~= false) then return b end
	if b:GetAttribute("_RollFix") then return b end
	b:SetAttribute("_RollFix", true)
	local s = b.Size
	local PX = 24 -- pixels par stud environ, à la distance des plans (le cadre mêle studs et pixels)
	local r = (s.Y.Scale * PX + s.Y.Offset) / (s.X.Scale * PX + s.X.Offset)
	b.Size = UDim2.new(s.Y.Scale, s.Y.Offset, s.X.Scale, s.X.Offset)
	local o = b.SizeOffset
	b.SizeOffset = Vector2.new(o.Y, -o.X)
	local rot = Instance.new("Frame")
	rot.Name = "_Rot"
	rot.BackgroundTransparency = 1
	rot.AnchorPoint = Vector2.new(0.5, 0.5)
	rot.Position = UDim2.fromScale(0.5, 0.5)
	rot.Size = UDim2.fromScale(1 / r, r)
	rot.Rotation = 90
	for _, c in b:GetChildren() do c.Parent = rot end
	rot.Parent = b
	b.ClipsDescendants = false
	return b
end
do
	local bb0 = L.billboard
	L.billboard = function(name, adornee) return L.rollFix(bb0(name, adornee)) end
	local il0 = L.itemLabel
	L.itemLabel = function(model, stolen)
		il0(model, stolen)
		local b = model:FindFirstChild("_Label", true)
		if b then L.rollFix(b) end
	end
end

------------------------------------------------------------------------------------------------
-- v5 (2026-11-25, retours de Clément sur la v4 : « animations pas fluides » ; « quand il casse la vitre il doit taper
-- vite plusieurs fois pour voir les éclats puis la vitre qui explose »).
--
-- 1. Prise image par image. Mesuré sur la v4 : la capture gdigrab ne rendait qu'environ 44 i/s (1 470 écarts de 33 ms
--    et 45 de 50 ms sur 4 139 images), Studio entre 31 et 54 i/s, et le plan avançait à l'horloge : des images en double
--    ou perdues, donc des à-coups. Ici le plan n'avance plus à l'horloge : chaque état dure exactement 1/60 s de jeu, et
--    il est tenu à l'écran au moins L.HOLD s (2 images de Studio), le temps que la capture le prenne. Un compteur
--    binaire (CoreGui/_TrailerMarker, en haut à gauche, hors du cadre gardé au montage) numérote les états ; le
--    découpage (decouper_marque.py) garde une image par numéro : 60 états = 1 s de vidéo, sans double ni trou.
--    Les particules de Roblox, qui avancent à l'horloge, sont ralenties d'autant (TimeScale, remis à la fin).
--    Un calcul qui attend (creux de la vitre, FragmentAsync) tient l'image (S.wait) sans trou dans la vidéo.
-- 2. Casse en plusieurs coups, reprise du jeu (ShatterController et Config/Shatter, sans rien inventer) : à chaque
--    coup la vitre se creuse (FragmentAsync, creux en cuvette qui grandit quand les PV baissent), les éclats arrachés
--    partent vers celui qui frappe, mini-cubes, paillettes, petit nuage et éclair ; au dernier coup, arrêt sur image,
--    flash, éclair, les éclats de WindowFractured partent du point d'impact vers l'intérieur du magasin, cubes,
--    paillettes et poussière. Le Marteau (TOOL_Marteau, HitWindowHeavy, Impact à 0,233 s) est l'arme de la zone 4.
------------------------------------------------------------------------------------------------
;(function() -- fonction à part : le fichier approche la limite de 200 variables locales
	local RunService = game:GetService("RunService")
	local StarterGui = game:GetService("StarterGui")
	local CoreGui = game:GetService("CoreGui")
	local RS = game:GetService("ReplicatedStorage")
	local STEP = "_TrailerShot" -- même nom que l'outil : T.stop le débranche
	local FPS = 60
	L.HOLD = 1 / 30
	local BITS = 12
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	-- compteur : 2 rangées de 7 cases de 10 px (pas de 12 px) depuis (6, 6) ; rangée 2 : bits 7 à 11, puis blanc, noir
	L.MARK = { x0 = 6, y0 = 6, step = 12, size = 10, cols = 7, bits = BITS }

	local function markerGui()
		local g = CoreGui:FindFirstChild("_TrailerMarker")
		if g then return g end
		g = Instance.new("ScreenGui")
		g.Name = "_TrailerMarker"
		g.IgnoreGuiInset = true
		g.DisplayOrder = 100000
		g.ResetOnSpawn = false
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = BLACK
		bar.Size = UDim2.fromOffset(L.MARK.x0 * 2 + L.MARK.cols * L.MARK.step, L.MARK.y0 * 2 + 2 * L.MARK.step)
		bar.Parent = g
		for i = 0, BITS + 1 do
			local f = Instance.new("Frame")
			f.Name = "B" .. i
			f.BorderSizePixel = 0
			f.Size = UDim2.fromOffset(L.MARK.size, L.MARK.size)
			f.Position = UDim2.fromOffset(L.MARK.x0 + (i % L.MARK.cols) * L.MARK.step, L.MARK.y0 + (i // L.MARK.cols) * L.MARK.step)
			f.Parent = bar
		end
		g.Parent = CoreGui
		return g
	end
	local function setMarker(n: number)
		local bar = markerGui().Bar
		for i = 0, BITS - 1 do
			bar["B" .. i].BackgroundColor3 = if bit32.extract(n, i) == 1 then WHITE else BLACK
		end
		bar["B" .. BITS].BackgroundColor3 = WHITE
		bar["B" .. (BITS + 1)].BackgroundColor3 = BLACK
	end
	L.setMarker = setMarker
	local function dropMarker()
		local g = CoreGui:FindFirstChild("_TrailerMarker")
		if g then g:Destroy() end
	end
	L.dropMarker = dropMarker

	-- particules : leur temps suit celui du plan
	local emitters = {}
	local function track(e)
		if e:IsA("ParticleEmitter") and emitters[e] == nil then emitters[e] = e.TimeScale end
	end
	local scaleNow = 1
	local function setTimeScale(k: number)
		scaleNow = k
		for e, base in emitters do
			if e.Parent then e.TimeScale = base * k end
		end
	end
	local addConn
	local function restoreTimeScale()
		if addConn then addConn:Disconnect() addConn = nil end
		for e, base in emitters do
			if e.Parent then e.TimeScale = base end
		end
		table.clear(emitters)
	end
	L.restoreTimeScale = restoreTimeScale

	local function camAt(S, t)
		local pos, look, fov = S.shot.cam(t, S)
		local cf = CFrame.lookAt(pos, look)
		if S.shot.roll ~= false then cf *= CFrame.Angles(0, 0, math.rad(90)) end
		return { cf = cf, focus = CFrame.new(look), fov = fov }
	end
	local function put(c)
		local cam = workspace.CurrentCamera
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		cam.CFrame = c.cf
		cam.Focus = c.focus
		if c.fov then cam.FieldOfView = c.fov end
		if StarterGui.ShowDevelopmentGui then StarterGui.ShowDevelopmentGui = false end
	end

	local stop0 = T._stopV4 or T.stop
	T._stopV4 = stop0
	function T.stop()
		restoreTimeScale()
		dropMarker()
		local cc = workspace.CurrentCamera:FindFirstChild("_TrailerFlash")
		if cc then cc:Destroy() end
		return stop0()
	end

	function T.go()
		local S = T.state
		assert(S and S.phase == "ready", "appeler T.prepare(nom) d'abord")
		pcall(function() RunService:UnbindFromRenderStep(STEP) end)
		for _, d in workspace:GetDescendants() do track(d) end
		addConn = workspace.DescendantAdded:Connect(function(d)
			track(d)
			if emitters[d] then d.TimeScale = emitters[d] * scaleNow end
		end)
		setMarker(0)
		local total = math.floor(S.shot.dur * FPS + 0.5)
		local start = os.clock()
		local c0 = camAt(S, 0)
		S.phase = "preroll"
		S.n = 0
		S.frames = 0
		S.waits = 0
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 100, function()
			local ok, err = pcall(function()
				local now = os.clock()
				if S.phase == "preroll" then
					put(c0)
					T._black(true)
					setMarker(0)
					if now - start >= T.PREROLL then
						T._black(false)
						S.phase = "run"
						S.last = nil
						S.runStart = now
					end
					return
				end
				if S.phase == "run" then
					if S.wait then
						put(S.cam)
						return
					end
					if S.last and now - S.last < L.HOLD then
						put(S.cam)
						return
					end
					local k = if S.last then (1 / FPS) / math.max(now - S.last, 1 / FPS) else 1
					S.last = now
					S.n += 1
					local t = (S.n - 1) / FPS
					if S.n > 1 then
						local dt = 1 / FPS
						S.t, S.dt = t, dt
						S.frames += 1
						setTimeScale(math.clamp(k, 0.05, 1))
						if S.shot.update then S.shot.update(S, t, dt) end
						local adt = if S.freezeUntil and t < S.freezeUntil then 0 else dt
						for _, a in S.actors do
							a.animator:StepAnimations(adt)
							T.fx.updateCarry(a)
						end
						for _, f in S.fx do f.step(dt) end
					end
					S.cam = camAt(S, t)
					if S.camPost then S.camPost(S, t) end
					put(S.cam)
					setMarker(S.n)
					if S.n >= total then
						S.phase = "postroll"
						S.postStart = now
						S.fps = S.n / (now - S.runStart)
					end
					return
				end
				if S.phase == "postroll" then
					put(S.cam)
					T._black(true)
					setMarker(0)
					if now - S.postStart >= T.POSTROLL then T.stop() end
				end
			end)
			if not ok then
				warn("[Trailer] " .. tostring(err))
				T.stop()
			end
		end)
		return ("top : %s, %d images (image par image)"):format(S.name, total)
	end

	--------------------------------------------------------------------------------------------
	-- Casse du jeu (ShatterController, Config/Shatter)
	--------------------------------------------------------------------------------------------
	local Shatter = require(RS.Shared.Config.Shatter)
	local Carve, Break, Shards, Cubes, Hit, Particles = Shatter.Carve, Shatter.Break, Shatter.Shards, Shatter.Cubes, Shatter.Hit, Shatter.Particles
	local GeometryService = game:GetService("GeometryService")
	local rng = Random.new()
	local FRAME_MARGIN, NEAR_FACTOR, REST_GAP, SPIN_KEEP, CUBE_REST_SPEED, GROUND_PROBE = 0.08, 1.7, 0.02, 0.5, 2, 40
	local function jitter(a: number) return 1 + rng:NextNumber(-a, a) end

	local function fxTexture(name: string): string?
		local d = Assets.FX:FindFirstChild(name)
		if d and d:IsA("Decal") then return d.Texture end
		return nil
	end

	-- Géométrie des vitres (toGlass, boxOf, shardParts, variants, targetGlass, chooseShards du jeu)
	local function toGlass(cf: CFrame, size: Vector3)
		local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
		local sizes = { size.X, size.Y, size.Z }
		local thin = 1
		for i = 2, 3 do
			if sizes[i] < sizes[thin] then thin = i end
		end
		local a = if thin == 1 then 2 else 1
		local b = if thin == 3 then 2 else 3
		local up, wide = a, b
		if math.abs(axes[b].Y) > math.abs(axes[a].Y) then up, wide = b, a end
		local upDir = if axes[up].Y < 0 then -axes[up] else axes[up]
		local normal = axes[thin]
		return { CFrame = CFrame.fromMatrix(cf.Position, upDir:Cross(normal), upDir, normal), Width = sizes[wide], Height = sizes[up], Thickness = sizes[thin] }
	end
	local function glassOf(win: BasePart) return toGlass(win.CFrame, win.Size) end
	local function boxOf(parts, rotation: CFrame)
		local rot = rotation.Rotation
		local low, high
		for _, part in parts do
			local cf, half = part.CFrame, part.Size / 2
			for corner = 0, 7 do
				local o = Vector3.new(if corner % 2 == 0 then -half.X else half.X, if (corner // 2) % 2 == 0 then -half.Y else half.Y, if corner // 4 == 0 then -half.Z else half.Z)
				local q = rot:PointToObjectSpace(cf:PointToWorldSpace(o))
				low = if low then low:Min(q) else q
				high = if high then high:Max(q) else q
			end
		end
		if not low then return nil, nil end
		return rot + rot:PointToWorldSpace((low + high) / 2), high - low
	end
	local function shardParts(root: Instance)
		local list = {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and string.match(d.Name, "^Shard_%d+$") then table.insert(list, d) end
		end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	local variantCache
	local function variants()
		if variantCache then return variantCache end
		local list = {}
		local folder = Assets:FindFirstChild("Windows")
		for _, name in Shatter.Assets.FracturedVariants do
			local m = folder and folder:FindFirstChild(name)
			if m and m:IsA("Model") then
				local shards = shardParts(m)
				local impact = m:FindFirstChild("Shard_01", true)
				if #shards > 0 and impact and impact:IsA("BasePart") then
					local cf, size = boxOf(shards, m:GetPivot())
					if cf then table.insert(list, { Name = name, Shards = shards, Glass = toGlass(cf, size), Impact = impact.Position }) end
				end
			end
		end
		variantCache = list
		return list
	end
	local function targetGlass(window: Instance, fractured: Instance?)
		local rotation, own = nil, {}
		if window:IsA("BasePart") then
			rotation = window.CFrame
			table.insert(own, window)
		else
			rotation = window:GetPivot()
			for _, d in window:GetDescendants() do if d:IsA("BasePart") then table.insert(own, d) end end
		end
		local parts = if fractured then shardParts(fractured) else {}
		if #parts == 0 then parts = own end
		local cf, size = boxOf(parts, rotation)
		return if cf then toGlass(cf, size) else nil
	end
	local MIRROR = CFrame.Angles(0, math.pi, 0)
	local function chooseShards(glass, fractured: Instance?, impact: Vector3)
		local best, bestPlace, bestD = nil, nil, math.huge
		local tol = Shards.SizeTolerance
		for _, v in variants() do
			if math.abs(v.Glass.Width - glass.Width) <= tol and math.abs(v.Glass.Height - glass.Height) <= tol and math.abs(v.Glass.Thickness - glass.Thickness) <= tol then
				for _, mirrored in (if Shards.AllowMirrored then { false, true } else { false }) do
					local target = if mirrored then glass.CFrame * MIRROR else glass.CFrame
					local place = target * v.Glass.CFrame:Inverse()
					local d = (place * v.Impact - impact).Magnitude
					if d < bestD - 1e-3 then best, bestPlace, bestD = v, place, d end
				end
			end
		end
		if best then return best.Shards, bestPlace, best.Name end
		if fractured then return shardParts(fractured), nil, "WindowFractured" end
		return {}, nil, "aucun"
	end

	local function setGlass(part: BasePart, look: BasePart, name: string)
		part.Name = name
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		part.Material = look.Material
		part.Color = look.Color
		part.Transparency = look.Transparency
		part.Reflectance = look.Reflectance
	end

	local function rayParams(exclude)
		local list = table.clone(exclude)
		table.insert(list, T.root())
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = list
		p.RespectCanCollide = true
		p.IgnoreWater = true
		return p
	end
	local function groundBelow(point: Vector3, params): number
		local r = workspace:Raycast(point + Vector3.new(0, 0.5, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
		return if r then r.Position.Y else point.Y - GROUND_PROBE
	end

	-- groupes de pièces simulées (éclats, morceaux arrachés, petits cubes) : même physique que le jeu
	local function newGroup(life: number, fade: number, params)
		return { pieces = {}, age = 0, startAt = 0, fadeAt = life, fadeTime = fade, params = params }
	end
	local function flatCFrame(piece, contact: Vector3, normal: Vector3): CFrame
		local axis = piece.Rotation:VectorToWorldSpace(piece.Thin or Vector3.zAxis)
		if axis:Dot(normal) < 0 then axis = -axis end
		local cross = axis:Cross(normal)
		local sine = cross.Magnitude
		local align = if sine > 1e-4 then CFrame.fromAxisAngle(cross / sine, math.atan2(sine, axis:Dot(normal))) else CFrame.identity
		return CFrame.new(contact + normal * (piece.Half + REST_GAP)) * align * piece.Rotation
	end
	local function stepPiece(group, piece, dt: number, parts, cframes)
		if piece.Resting then return end
		local from, to = piece.SettleFrom, piece.SettleTo
		if from and to then
			piece.SettleTime += dt
			local a = math.clamp(piece.SettleTime / math.max(Shards.SettleTime, 1e-3), 0, 1)
			table.insert(parts, piece.Part)
			table.insert(cframes, from:Lerp(to, 1 - (1 - a) * (1 - a)))
			if a >= 1 then piece.Resting = true end
			return
		end
		piece.Velocity -= Vector3.new(0, Shards.Gravity * dt, 0)
		local start = piece.Position
		local target = start + piece.Velocity * dt
		local angle = piece.Spin.Magnitude * dt
		if angle > 1e-6 then piece.Rotation = CFrame.fromAxisAngle(piece.Spin.Unit, angle) * piece.Rotation end
		if piece.GroundY then
			if piece.Velocity.Y < 0 and target.Y - piece.Half <= piece.GroundY then
				target = Vector3.new(target.X, piece.GroundY + piece.Half, target.Z)
				local up = -piece.Velocity.Y * Cubes.Bounce
				if up < CUBE_REST_SPEED then
					piece.Resting = true
				else
					local v = piece.Velocity
					piece.Velocity = Vector3.new(v.X * Shards.Friction, up, v.Z * Shards.Friction)
					piece.Spin *= SPIN_KEEP
				end
			end
		elseif group.params then
			local delta = target - start
			local length = delta.Magnitude
			if length > 1e-4 then
				local r = workspace:Raycast(start, delta * ((length + piece.Reach) / length), group.params)
				if r then
					local normal = r.Normal
					local into = piece.Velocity:Dot(normal)
					if into < 0 then
						local np = normal * into
						piece.Velocity = (piece.Velocity - np) * Shards.Friction - np * Shards.Bounce
						piece.Spin *= SPIN_KEEP
						target = r.Position + normal * piece.Reach
						if piece.Thin and normal.Y >= Shards.FlatMinNormalY and -into * Shards.Bounce < Shards.SettleSpeed then
							piece.SettleFrom = CFrame.new(target) * piece.Rotation
							piece.SettleTo = flatCFrame(piece, r.Position, normal)
							piece.SettleTime = 0
						end
					end
				end
			end
		end
		piece.Position = target
		table.insert(parts, piece.Part)
		table.insert(cframes, CFrame.new(target) * piece.Rotation)
	end
	local function groupFx(group)
		return {
			step = function(dt)
				group.age += dt
				if group.done then return end
				local parts, cframes = {}, {}
				if group.age >= group.startAt then
					for _, p in group.pieces do stepPiece(group, p, dt, parts, cframes) end
				end
				if #parts > 0 then workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged) end
				if group.age >= group.fadeAt then
					local a = if group.fadeTime > 0 then math.clamp((group.age - group.fadeAt) / group.fadeTime, 0, 1) else 1
					for _, p in group.pieces do p.Part.Transparency = p.Base + (1 - p.Base) * a end
					if a >= 1 then
						for _, p in group.pieces do p.Part:Destroy() end
						group.done = true
					end
				end
			end,
		}
	end
	local function thinOf(size: Vector3)
		if size.X <= size.Y and size.X <= size.Z then return Vector3.xAxis, size.X / 2 end
		if size.Y <= size.Z then return Vector3.yAxis, size.Y / 2 end
		return Vector3.zAxis, size.Z / 2
	end
	local function piece(part: BasePart, velocity: Vector3, spin: Vector3)
		local thin, half = thinOf(part.Size)
		local extent = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2
		return { Part = part, Position = part.Position, Rotation = part.CFrame.Rotation, Velocity = velocity, Spin = spin,
			Thin = thin, Half = half, Reach = half + extent * 0.25, Base = part.Transparency, SettleTime = 0, Resting = false }
	end
	local function cubePiece(origin: Vector3, velocity: Vector3, groundY: number, color: Color3)
		local side = rng:NextNumber(Cubes.SizeMin, Cubes.SizeMax)
		local part = Instance.new("Part")
		part.Name = "GlassCube"
		part.Size = Vector3.new(side, side, side)
		part.Material = Enum.Material.Glass
		part.Color = color
		part.Transparency = Cubes.Transparency
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
		local rotation = CFrame.fromAxisAngle(rng:NextUnitVector(), rng:NextNumber(0, math.pi * 2))
		part.CFrame = CFrame.new(origin) * rotation
		part.Parent = fxFolder()
		return { Part = part, Position = origin, Rotation = rotation, Velocity = velocity,
			Spin = rng:NextUnitVector() * math.rad(rng:NextNumber(Shards.SpinMin, Shards.SpinMax)), Half = side / 2,
			Reach = side / 2, GroundY = groundY, Base = Cubes.Transparency, SettleTime = 0, Resting = false }
	end

	local function upFrame(position: Vector3, up: Vector3): CFrame
		local unit = if up.Magnitude > 1e-4 then up.Unit else Vector3.yAxis
		local other = if math.abs(unit.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		return CFrame.fromMatrix(position, other:Cross(unit).Unit, unit)
	end
	local function emitParticles(kind: string, position: Vector3, direction: Vector3, count: number)
		if count <= 0 then return end
		local texture = if kind == "Sparkle" then fxTexture(Shatter.Assets.SparkleDecal) else (fxTexture(Shatter.Assets.DustDecal) or Shatter.DustTexture)
		if not texture or texture == "" then return end
		local holder = Instance.new("Part")
		holder.Name = "ShatterParticles"
		holder.Size = Vector3.one * 0.1
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
		holder.CFrame = upFrame(position, direction)
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Rate = 0
		e.Texture = texture
		e.EmissionDirection = Enum.NormalId.Top
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-180, 180)
		if kind == "Sparkle" then
			local p = Particles.Sparkle
			e.Size = NumberSequence.new(p.Size, 0)
			e.Lifetime = NumberRange.new(p.LifetimeMin, p.LifetimeMax)
			e.Speed = NumberRange.new(p.SpeedMin, p.SpeedMax)
			e.SpreadAngle = Vector2.new(p.Spread, p.Spread)
			e.Acceleration = Vector3.new(0, -Shards.Gravity * p.GravityScale, 0)
			e.Color = ColorSequence.new(p.Color)
			e.LightEmission = p.LightEmission
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1) })
		elseif kind == "Puff" then
			local p = Particles.Puff
			e.Size = NumberSequence.new(p.SizeMin, p.SizeMax)
			e.Lifetime = NumberRange.new(p.LifetimeMin, p.LifetimeMax)
			e.Speed = NumberRange.new(p.SpeedMin, p.SpeedMax)
			e.SpreadAngle = Vector2.new(p.Spread, p.Spread)
			e.Color = ColorSequence.new(p.Color)
			e.LightEmission = p.LightEmission
			e.Transparency = NumberSequence.new(p.Transparency, 1)
		else
			local p = Particles.Dust
			e.Size = NumberSequence.new(p.SizeMin, p.SizeMax)
			e.Lifetime = NumberRange.new(p.LifetimeMin, p.LifetimeMax)
			e.Speed = NumberRange.new(p.SpeedMin, p.SpeedMax)
			e.SpreadAngle = Vector2.new(p.Spread, p.Spread)
			e.Drag = p.Drag
			e.Color = ColorSequence.new(p.Color)
			e.Transparency = NumberSequence.new(p.Transparency, 1)
		end
		e.Parent = holder
		holder.Parent = fxFolder()
		e.TimeScale = scaleNow
		e:Emit(count)
	end

	-- lumière qui s'éteint en `dur` s de plan (au lieu d'un Tween à l'horloge)
	local function flashLight(S, point: Vector3, brightness: number, range: number, dur: number, color: Color3?)
		local holder = Instance.new("Part")
		holder.Name = "ShatterLight"
		holder.Size = Vector3.one * 0.1
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
		holder.Position = point
		local light = Instance.new("PointLight")
		light.Brightness = brightness
		light.Range = range
		light.Shadows = false
		if color then light.Color = color end
		light.Parent = holder
		holder.Parent = fxFolder()
		local age = 0
		table.insert(S.fx, { step = function(dt)
			age += dt
			light.Brightness = brightness * math.max(0, 1 - age / dur)
		end })
	end

	-- flash blanc de la casse : ColorCorrection sur la caméra, Quad Out en Break.FlashDuration
	local function screenFlash(S)
		local cam = workspace.CurrentCamera
		local cc = cam:FindFirstChild("_TrailerFlash") or Instance.new("ColorCorrectionEffect")
		cc.Name = "_TrailerFlash"
		cc.Parent = cam
		local age = 0
		local function set()
			local a = math.clamp(age / Break.FlashDuration, 0, 1)
			local k = (1 - a) * (1 - a)
			cc.Brightness = Break.FlashBrightness * k
			cc.Saturation = Break.FlashSaturation * k
			cc.Enabled = a < 1
		end
		set()
		table.insert(S.fx, { step = function(dt) age += dt set() end })
	end

	-- État de creux d'une vitre : la vraie vitre est cachée en local, une Part du même verre prend sa place
	local function carveState(S, win: BasePart)
		S.carves = S.carves or {}
		local st = S.carves[win]
		if st then return st end
		local glass = glassOf(win)
		local proxy = Instance.new("Part")
		setGlass(proxy, win, "CarvedGlass")
		proxy.Size = Vector3.new(glass.Width, glass.Height, glass.Thickness)
		proxy.CFrame = glass.CFrame
		proxy.Parent = fxFolder()
		T.hideLocal(win)
		table.insert(T._restore, T.restoreLocal)
		st = { Window = win, Glass = glass, Look = win, Pieces = { proxy }, Radius = 0, Depth = 0, Carves = 0 }
		S.carves[win] = st
		return st
	end

	local function carveSites(glass, x, y, radius, depth, side)
		local cf, thickness = glass.CFrame, glass.Thickness
		local face = side * thickness / 2
		local outer = {}
		local sites = { outer }
		local count = math.clamp(math.floor(radius * radius * Carve.SitesPerArea + 0.5), Carve.MinSites, Carve.MaxSites)
		for _ = 1, count do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = radius * math.sqrt(rng:NextNumber())
			local d = depth * (1 - Carve.Bowl * (distance / radius) ^ 2) * rng:NextNumber(0.85, 1.1)
			d = math.min(d, thickness * Carve.DepthCap)
			local px, py = x + distance * math.cos(angle), y + distance * math.sin(angle)
			table.insert(sites, cf * Vector3.new(px, py, face - side * d * 0.45))
			table.insert(outer, cf * Vector3.new(px + rng:NextNumber(-0.04, 0.04), py + rng:NextNumber(-0.04, 0.04), face - side * d * 1.55))
		end
		local ring = math.clamp(math.floor(radius * 8 + 0.5), Carve.RingMin, Carve.RingMax)
		local turn = rng:NextNumber(0, math.pi * 2)
		local ringZ = face - side * depth * (1 - Carve.Bowl) * 0.45
		for i = 1, ring do
			local angle = turn + (i + rng:NextNumber(-0.35, 0.35)) / ring * math.pi * 2
			local distance = radius * rng:NextNumber(1.3, 1.6)
			table.insert(outer, cf * Vector3.new(x + distance * math.cos(angle), y + distance * math.sin(angle), ringZ))
		end
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			table.insert(outer, cf * Vector3.new(c[1] * glass.Width, c[2] * glass.Height, 0))
		end
		return sites
	end
	local function touchesFrame(glass, part: BasePart): boolean
		local hx, hy = glass.Width / 2 - FRAME_MARGIN, glass.Height / 2 - FRAME_MARGIN
		local half = part.Size / 2
		for corner = 0, 7 do
			local o = Vector3.new(if corner % 2 == 0 then -half.X else half.X, if (corner // 2) % 2 == 0 then -half.Y else half.Y, if corner // 4 == 0 then -half.Z else half.Z)
			local p = glass.CFrame:PointToObjectSpace(part.CFrame * o)
			if math.abs(p.X) >= hx or math.abs(p.Y) >= hy then return true end
		end
		return false
	end

	-- Un coup creuse la vitre (carveOnce du jeu). lost = part des PV perdus après ce coup. Tient l'image pendant le calcul.
	local function carveHit(S, st, point: Vector3, lost: number)
		local glass = st.Glass
		local thickness = glass.Thickness
		local p = glass.CFrame:PointToObjectSpace(point)
		local side = if p.Z >= 0 then 1 else -1
		local hx, hy = glass.Width / 2, glass.Height / 2
		local x = math.clamp(p.X, -hx + math.min(Carve.EdgeMargin, hx), hx - math.min(Carve.EdgeMargin, hx))
		local y = math.clamp(p.Y, -hy + math.min(Carve.EdgeMargin, hy), hy - math.min(Carve.EdgeMargin, hy))
		local radius = Carve.R0 + Carve.RGrow * lost ^ Carve.RadiusCurve
		radius = math.min(math.max(radius, st.Radius + Carve.PerHit), Carve.RMax)
		local depth = math.clamp(Carve.DepthMin + Carve.DepthGrow * lost ^ Carve.DepthCurve, Carve.DepthMin, Carve.DepthMax)
		depth = math.min(math.max(depth * thickness, st.Depth + Carve.DepthPerHit * thickness), Carve.DepthMax * thickness)
		st.Radius, st.Depth = radius, depth
		local outward = glass.CFrame.ZVector * side
		local center = glass.CFrame * Vector3.new(x, y, side * thickness / 2)
		local sites = carveSites(glass, x, y, radius, depth, side)
		S.wait = true
		task.spawn(function()
			local ok, err = pcall(function()
				local kept, chips = {}, {}
				for _, pc in table.clone(st.Pieces) do
					local rel = pc.CFrame:PointToObjectSpace(center)
					local reach = pc.Size / 2 + Vector3.one * (NEAR_FACTOR * radius)
					if math.abs(rel.X) > reach.X or math.abs(rel.Y) > reach.Y or math.abs(rel.Z) > reach.Z then
						table.insert(kept, pc)
						continue
					end
					local res = GeometryService:FragmentAsync(pc, sites, { CollisionFidelity = Enum.CollisionFidelity.Box })
					for _, item in res do
						local inst = if type(item) == "table" then item.Instance else nil
						if typeof(inst) == "Instance" and inst:IsA("BasePart") then
							if item.Index == 1 then
								setGlass(inst, st.Look, "CarvedGlass")
								inst.Parent = fxFolder()
								table.insert(kept, inst)
							else
								table.insert(chips, inst)
							end
						end
					end
					pc:Destroy()
				end
				st.Carves += 1
				local attached, islands = {}, {}
				for _, part in kept do table.insert(if touchesFrame(glass, part) then attached else islands, part) end
				if #attached == 0 then attached, islands = islands, {} end
				st.Pieces = attached
				-- éclats arrachés (et morceaux détachés du cadre) : vers celui qui frappe, Life puis Fade
				local group = newGroup(Carve.Life, Carve.Fade, rayParams({ st.Window }))
				local function chip(part: BasePart, soft: boolean)
					setGlass(part, st.Look, "GlassChip")
					part.Parent = fxFolder()
					local k = if soft then Carve.SoftFactor else 1
					local radial = part.Position - center
					radial -= outward * radial:Dot(outward)
					radial = if radial.Magnitude > 1e-3 then radial.Unit else Vector3.zero
					local v = outward * (rng:NextNumber(Carve.SpeedMin, Carve.SpeedMax) * k) + radial * (rng:NextNumber(Carve.SideMin, Carve.SideMax) * k)
						+ Vector3.new(0, rng:NextNumber(Carve.UpMin, Carve.UpMax) * k, 0)
					table.insert(group.pieces, piece(part, v, rng:NextUnitVector() * rng:NextNumber(Carve.SpinMin, Carve.SpinMax)))
				end
				for _, part in chips do chip(part, rng:NextNumber() >= Carve.OutShare) end
				for _, part in islands do chip(part, true) end
				S.chipCount = (S.chipCount or 0) + #group.pieces
				if #group.pieces > 0 then table.insert(S.fx, groupFx(group)) end
			end)
			if not ok then
				warn("[Trailer] creux : " .. tostring(err))
				S.carveErr = tostring(err)
			end
			S.wait = false
		end)
	end

	-- Effets d'un coup (playHitFx du jeu), sans le son (posé au montage : Glass_Hit, hauteur qui monte)
	local function hitFx(S, st, point: Vector3)
		local glass = st.Glass
		local normal = glass.CFrame.ZVector
		local outward = if (point - glass.CFrame.Position):Dot(normal) >= 0 then normal else -normal
		local origin = point + outward * 0.15
		local params = rayParams({ st.Window })
		local gy = groundBelow(origin + outward * 1.5, params)
		local group = newGroup(Hit.CubeLifetime - Cubes.FadeTime, Cubes.FadeTime, nil)
		for _ = 1, Hit.Cubes do
			local dir = (outward + rng:NextUnitVector() * 0.8 + Vector3.new(0, 0.35, 0)).Unit
			table.insert(group.pieces, cubePiece(origin, dir * (Hit.CubeSpeed * rng:NextNumber(0.6, 1.2)), gy, Shatter.GlassColor))
		end
		table.insert(S.fx, groupFx(group))
		emitParticles("Sparkle", origin, outward, Hit.Sparkles)
		emitParticles("Puff", origin, outward, Hit.Puff)
		flashLight(S, origin, Hit.FlashBrightness, Hit.FlashRange, Hit.FlashTime, Hit.FlashColor)
	end

	-- Casse (prepareShards + prepareBreak + breakBurst du jeu)
	local function breakFx(S, st, store: Instance, impact: Vector3, window: Instance)
		for _, pc in st.Pieces do pc:Destroy() end
		st.Pieces = {}
		local found = store:FindFirstChild("WindowFractured", true)
		local fractured = if found and found:IsA("Model") then found else nil
		local glass = targetGlass(window, fractured) or st.Glass
		local sources, place, used = chooseShards(glass, fractured, impact)
		S.shardsUsed = used .. " (" .. #sources .. " éclats)"
		local normal = glass.CFrame.ZVector
		-- vers l'intérieur : du côté du volume Bounds ; sinon à l'opposé du point de frappe (inwardDirection du jeu)
		local hitSide = (impact - glass.CFrame.Position):Dot(normal)
		local inward = if hitSide > 0.01 then -normal else normal
		local bounds = store:FindFirstChild("Bounds", true)
		if bounds and bounds:IsA("BasePart") then
			local side = (bounds.Position - glass.CFrame.Position):Dot(normal)
			if math.abs(side) > 0.1 then inward = if side > 0 then normal else -normal end
		end
		local params = rayParams({ window, fractured })
		local group = newGroup(Shards.FadeDelay, Shards.FadeDuration, params)
		group.startAt = Break.FreezeFrame
		group.fadeAt = Break.FreezeFrame + Shards.FadeDelay
		for _, src in sources do
			local c = src:Clone()
			for _, d in c:GetDescendants() do
				if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("NoCollisionConstraint") or d:IsA("LuaSourceContainer") then d:Destroy() end
			end
			c.Anchored = true
			c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
			c.CFrame = if place then place * src.CFrame else src.CFrame
			if c.Transparency >= 0.99 then c.Transparency = Shards.FallbackTransparency end
			c.LocalTransparencyModifier = 0
			c.Parent = fxFolder()
			local offset = c.Position - impact
			local inPlane = offset - normal * offset:Dot(normal)
			local dist = inPlane.Magnitude
			local radial
			if dist > 1e-3 then
				radial = inPlane / dist
			else
				local an = rng:NextNumber(0, math.pi * 2)
				radial = glass.CFrame.RightVector * math.cos(an) + glass.CFrame.UpVector * math.sin(an)
			end
			local falloff = 1 / (1 + dist / math.max(Shards.FalloffDistance, 1e-3))
			local v = radial * (Shards.Speed * falloff * jitter(Shards.Jitter)) + inward * (Shards.InwardPush * (0.6 + 0.4 * falloff) * jitter(Shards.Jitter))
				+ Vector3.new(0, Shards.UpBoost * rng:NextNumber(0.5, 1), 0)
			local spin = rng:NextUnitVector() * (math.rad(rng:NextNumber(Shards.SpinMin, Shards.SpinMax)) * (0.5 + 0.5 * falloff))
			table.insert(group.pieces, piece(c, v, spin))
		end
		table.insert(S.fx, groupFx(group))
		-- arrêt sur image, flash, éclair ; puis cubes, paillettes et poussière (après FreezeFrame)
		S.freezeUntil = S.t + Break.FreezeFrame
		screenFlash(S)
		flashLight(S, impact, Break.LightBrightness, Break.LightRange, Break.FlashDuration)
		local burstAge = 0
		local burst
		burst = { step = function(dt)
			burstAge += dt
			if burst.done or burstAge < Break.FreezeFrame then return end
			burst.done = true
			local gy = groundBelow(impact + inward * 2, params)
			local cubes = newGroup(Cubes.BreakLifetime - Cubes.FadeTime, Cubes.FadeTime, nil)
			for _ = 1, Break.Cubes do
				local dir = (inward * rng:NextNumber(0.6, 1.2) + rng:NextUnitVector() * 0.7 + Vector3.new(0, 0.4, 0)).Unit
				table.insert(cubes.pieces, cubePiece(impact, dir * (Shards.Speed * rng:NextNumber(0.5, 1.1)), gy, Shatter.GlassColor))
			end
			table.insert(S.fx, groupFx(cubes))
			emitParticles("Sparkle", impact, inward, Break.Sparkles)
			emitParticles("Sparkle", impact, -inward, math.ceil(Break.Sparkles / 4))
			emitParticles("Dust", impact, inward, Break.Dust)
		end }
		table.insert(S.fx, burst)
	end

	-- Point visé : le point de la vitre le plus proche de celui qui frappe (comme le serveur), à hauteur de poitrine
	local function aimPoint(win: BasePart, p): Vector3
		local glass = glassOf(win)
		local from = p.root.Position + Vector3.new(0, 0.6, 0)
		local q = glass.CFrame:PointToObjectSpace(from)
		local hx, hy = glass.Width / 2 - Carve.EdgeMargin, glass.Height / 2 - Carve.EdgeMargin
		local side = if q.Z >= 0 then 1 else -1
		return glass.CFrame * Vector3.new(math.clamp(q.X, -hx, hx), math.clamp(q.Y, -hy, hy), side * glass.Thickness / 2)
	end
	L.aimPoint = aimPoint

	-- Coups rapides puis casse. opts : { at = premier coup (s), every = écart entre coups (s), hits = nombre de coups
	-- (le dernier casse), anim = "HitWindowHeavy", impact = s après le début de l'animation (marqueur Impact), store, win }
	function L.smash(S, p, t: number, opts)
		local store0 = opts.store
		local win = opts.win or store0:FindFirstChild("Window")
		if not win:IsA("BasePart") then
			-- vitre Model (porte des boutiques) : son verre (la pièce la plus transparente)
			local best
			for _, d in win:GetDescendants() do
				if d:IsA("BasePart") and (not best or d.Transparency > best.Transparency) then best = d end
			end
			win = best
		end
		local hits, every, at = opts.hits or 5, opts.every or 0.25, opts.at or 0.2
		local anim, impactAt = opts.anim or "HitWindowHeavy", opts.impact or 0.233
		S._hitIdx = S._hitIdx or 0
		S.hitTimes = S.hitTimes or {}
		for i = 1, hits do
			local t0 = at + (i - 1) * every
			once(S, "swing" .. i, t, t0, function()
				local tr = p:track(anim)
				tr.Looped = false
				if tr.IsPlaying then tr:Stop(0) end
				tr:Play(0.05, 1, 1)
				tr.TimePosition = 0
			end)
			once(S, "impact" .. i, t, t0 + impactAt, function()
				local st = carveState(S, win)
				local point = aimPoint(win, p) + (if i > 1 then glassOf(win).CFrame:VectorToWorldSpace(Vector3.new(rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.3, 0.3), 0)) else Vector3.zero)
				S.hitTimes[i] = t
				if i < hits then
					hitFx(S, st, point)
					carveHit(S, st, point, i / hits)
				else
					S.breakAt = t
					hitFx(S, st, point)
					breakFx(S, st, store0, point, opts.win or store0:FindFirstChild("Window"))
				end
			end)
		end
	end

	-- Plans de casse refaits : vitrine de la Bijouterie (zone 4) au Marteau, 5 coups à 4 par seconde (le jeu en permet 5).
	local BIJ = function() return store("STORE_Z4_Bijouterie") end
	local function smashSetup(S, withGuard: boolean)
		local p = L.fresh("braqueur", "bacon")
		S.actors.p1 = p
		L.hold(p, "Tools", "TOOL_Marteau")
		p:place(V(442, 0.4, 50.2), V(0, 0, 1))
		p:play("Idle", { fade = 0 })
		if withGuard then
			local g = L.fresh("vigile_z4", GUARD)
			S.actors.g1 = g
			g:place(V(450.2, 0.4, 50.8), V(-1, 0, -0.2))
			g:play("Idle", { fade = 0 })
		end
	end
	for _, f in { "h", "v" } do
		local sv = T.shots["L_vigile_fige_" .. f]
		sv.dur = 2.6
		sv.cam = M.shake(M.travelling({ from = V(455.5, 4.8, 37.5), look = V(446, 4.6, 51), dir = "avant", dist = 4.5, dur = 2.6, ease = "linear", fov = 48 }), { atKey = "breakAt", dur = Break.ShakeDuration, amp = Break.ShakeAmplitude })
		sv.setup = function(S) hideWitness() smashSetup(S, true) end
		sv.update = function(S, t) L.smash(S, S.actors.p1, t, { store = BIJ(), at = 0.2, every = 0.25, hits = 5 }) end
		local sc = T.shots["L_casse_orbite_" .. f]
		sc.dur = 3
		sc.cam = M.shake(M.orbit({ center = V(442, 4.5, 51), radius = 10, height = -1.2, from = 130, to = 60, dur = 3, ease = "sine", fov = 48, lookUp = 0.5 }), { atKey = "breakAt", dur = Break.ShakeDuration, amp = Break.ShakeAmplitude })
		sc.setup = function(S) hideWitness() smashSetup(S, false) end
		sc.update = function(S, t) L.smash(S, S.actors.p1, t, { store = BIJ(), at = 0.2, every = 0.25, hits = 5 }) end
		local sp = T.shots["L_braquage_porte_" .. f]
		sp.dur = 3
		sp.cam = M.shake(M.orbit({ center = V(-42, 4.5, 175.5), radius = 10, height = -1, from = 120, to = 60, dur = 3, ease = "sine", fov = 48, lookUp = 0.5 }), { atKey = "breakAt", dur = Break.ShakeDuration, amp = Break.ShakeAmplitude })
		local setup0 = sp._setup0 or sp.setup
		sp._setup0 = setup0
		sp.setup = function(S)
			local p = L.fresh("ami", "bacon_guitare")
			S.actors.p1 = p
			L.hold(p, "Tools", "TOOL_Marteau")
			p:place(V(-42, 0, 174.3), V(0, 0, 1))
			p:play("Idle", { fade = 0 })
		end
		sp.update = function(S, t)
			local door = store("PLOT_Shop_01"):FindFirstChild("PlotDoor")
			L.smash(S, S.actors.p1, t, { store = door, win = door:FindFirstChild("Window"), at = 0.2, every = 0.25, hits = 5 })
		end
	end
	-- même arme dans toute la séquence de la zone 4 : le Marteau (Config/Tools, zone 4), pas la batte
	for _, name in { "facade_bijouterie", "rideau_monte", "porte_zone4" } do
		for _, f in { "h", "v" } do
			local sh = T.shots["L_" .. name .. "_" .. f]
			local s0 = sh._setupBatte or sh.setup
			sh._setupBatte = s0
			sh.setup = function(S)
				s0(S)
				local p = S.actors.p1
				if p.held then p.held.model:Destroy() p.held = nil end
				L.hold(p, "Tools", "TOOL_Marteau")
			end
		end
	end
	-- dossiers de travail des autres sessions (aperçus, panneaux en essai) : cachés en local pendant chaque plan
	L.HIDE_WORK = { "_PREVIEW_UpgradeSigns", "_PREVIEW_StoreReqSigns", "_PREVIEW_ShelfOpen", "_APERCU_GrandeBoutique",
		"_APERCU_SolLumiere", "_INBOX_CLEMENT", "_APERCU_DeuxProgressions", "_EXEMPLE_STUDS" }
	local prep0 = T._prepV5 or T.prepare
	T._prepV5 = prep0
	function T.prepare(name)
		local r = prep0(name)
		for _, n in L.HIDE_WORK do
			local f = workspace:FindFirstChild(n)
			if f then L.hide(f) end
		end
		return r
	end
	-- couloir_drone (plan de la session TikTok) refilmé lui aussi image par image, dans les deux formats
	if T.shots.couloir_drone then
		for _, f in { "h", "v" } do
			local b = T.shots.couloir_drone
			T.shots["L_couloir_drone_" .. f] = { dur = b.dur, roll = f == "v", cam = b.cam, setup = b.setup, update = b.update }
		end
	end
end)()

local n = 0
for k in T.shots do
	if k:sub(1, 2) == "L_" then n += 1 end
end
return "trailer de lancement : " .. n .. " plans (" .. n // 2 .. " sujets × 16:9 et 9:16)"
