--!nocheck
-- Outil de tournage des trailers TikTok (skill .claude/skills/trailer-tiktok), pour Clément.
-- À lancer en EDIT par execute_luau (MCP Roblox Studio), jamais en Play : rien n'est laissé dans le jeu.
--
-- Ce fichier définit _G.Trailer (une fois par session de Studio) :
--   - des courbes (T.ease) et des mouvements de caméra (T.moves) qui rendent chacun une fonction t -> position, cible, champ ;
--   - des faux joueurs et des vigiles (T.actor) : PNJ R15 sans script, animés image par image par Animator:StepAnimations ;
--   - des effets de plateau (T.fx) : vitrine qui casse, objet porté, éclats ;
--   - le moteur d'un plan (T.prepare, T.go, T.stop) : écran noir de synchro, caméra tournée de 90° pour du 9:16, horloge ralentie.
-- Tout ce qui est créé va dans Workspace/_TRAILER (dossier temporaire, à vider après le tournage par T.clear()).
-- Ce qui est touché hors de _TRAILER est remis à la fin du plan : caméra de Clément, StarterGui.ShowDevelopmentGui,
-- sélection, LocalTransparencyModifier des vitrines cassées (propriété locale, jamais enregistrée).
--
-- Les plans eux-mêmes sont dans shots.luau (T.shots[nom] = { ... }).

local T = _G.Trailer or {}
_G.Trailer = T
T.VERSION = "2026-11-25"

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Selection = game:GetService("Selection")
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")

------------------------------------------------------------------------------------------------
-- Dossier temporaire
------------------------------------------------------------------------------------------------
function T.root(): Folder
	local f = workspace:FindFirstChild("_TRAILER")
	if not f then
		f = Instance.new("Folder")
		f.Name = "_TRAILER"
		f.Parent = workspace
	end
	return f
end

local function sub(name: string): Folder
	local r = T.root()
	local f = r:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = r
	end
	return f
end

------------------------------------------------------------------------------------------------
-- Courbes (u de 0 à 1)
------------------------------------------------------------------------------------------------
local E = {}
E.linear = function(u) return u end
E.sine = function(u) return 0.5 - 0.5 * math.cos(math.pi * u) end -- départ et arrivée doux (le défaut)
E.quad = function(u) return if u < 0.5 then 2 * u * u else 1 - (-2 * u + 2) ^ 2 / 2 end
E.cubic = function(u) return if u < 0.5 then 4 * u ^ 3 else 1 - (-2 * u + 2) ^ 3 / 2 end
E.inQuad = function(u) return u * u end -- accélère (départ d'une poursuite)
E.inCubic = function(u) return u ^ 3 end
E.outQuad = function(u) return 1 - (1 - u) ^ 2 end -- freine (arrivée sur un sujet)
E.outCubic = function(u) return 1 - (1 - u) ^ 3 end
E.outQuint = function(u) return 1 - (1 - u) ^ 5 end -- coup de frein net : révélation
E.outBack = function(u)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end
T.ease = E
local function curve(name) return E[name or "sine"] or E.sine end
local function clamp01(x) return math.clamp(x, 0, 1) end

------------------------------------------------------------------------------------------------
-- Sol (raycast qui ignore _TRAILER, les pièces invisibles et sans collision)
------------------------------------------------------------------------------------------------
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.RespectCanCollide = true
function T.ground(p: Vector3): number
	rp.FilterDescendantsInstances = { T.root() }
	local r = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rp)
	return if r then r.Position.Y else p.Y
end

------------------------------------------------------------------------------------------------
-- Mouvements de caméra : chacun rend function(t) -> pos, look, fov  (t en secondes de plan)
-- Les noms suivent le catalogue du skill (références/mouvements.md).
------------------------------------------------------------------------------------------------
local M = {}
T.moves = M

local AXES = { avant = "f", arriere = "b", gauche = "l", droite = "r", haut = "u", bas = "d" }

-- Travelling : la caméra glisse sur un de ses axes. dir = avant, arriere, gauche, droite, haut, bas.
-- spec = { from = Vector3, look = Vector3, dir = "avant", dist = 12, dur = 3, ease = "sine", fov = 50, keepLook = false }
-- keepLook = true : la cible reste fixe (le mouvement devient un arc qui garde le sujet au centre).
function M.travelling(s)
	local cf = CFrame.lookAt(s.from, s.look)
	local axis = AXES[s.dir] or s.dir
	local v = ({ f = cf.LookVector, b = -cf.LookVector, l = -cf.RightVector, r = cf.RightVector, u = Vector3.yAxis, d = -Vector3.yAxis })[axis]
	assert(v, "travelling : dir inconnue " .. tostring(s.dir))
	local ez = curve(s.ease)
	return function(t)
		local u = ez(clamp01(t / s.dur))
		local off = v * (s.dist * u)
		return s.from + off, if s.keepLook then s.look else s.look + off, s.fov
	end
end

-- Orbite autour d'un point. spec = { center, radius, height, from = degrés, to = degrés, dur, ease, fov, lookUp = 0 }
-- 0° = caméra côté +X du centre ; les angles tournent dans le sens trigonométrique vu de dessus.
function M.orbit(s)
	local ez = curve(s.ease)
	return function(t)
		local u = ez(clamp01(t / s.dur))
		local a = math.rad(s.from + (s.to - s.from) * u)
		local r = s.radius + (s.radiusTo and (s.radiusTo - s.radius) * u or 0)
		local h = s.height + (s.heightTo and (s.heightTo - s.height) * u or 0)
		local pos = s.center + Vector3.new(math.cos(a) * r, h, -math.sin(a) * r)
		return pos, s.center + Vector3.new(0, s.lookUp or 0, 0), s.fov
	end
end

-- Panoramique : caméra fixe qui tourne d'une cible à l'autre. spec = { pos, from = Vector3, to = Vector3, dur, ease, fov }
function M.pan(s)
	local ez = curve(s.ease)
	return function(t)
		local u = ez(clamp01(t / s.dur))
		return s.pos, s.from:Lerp(s.to, u), s.fov
	end
end

-- Chemin libre par images clés : spec = { keys = { {t, pos, look, fov?}, ... }, ease = "sine" }
-- Les positions passent par une spline de Catmull-Rom (pas d'angle aux clés), les cibles en ligne.
local function catmull(p0, p1, p2, p3, u)
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end
function M.path(s)
	local k = s.keys
	local ez = curve(s.ease)
	local total = k[#k][1]
	return function(t)
		-- la courbe s'applique au plan entier, puis on retrouve le segment
		local tt = ez(clamp01(t / total)) * total
		local i = 1
		while i < #k - 1 and tt > k[i + 1][1] do i += 1 end
		local a, b = k[i], k[i + 1]
		local u = clamp01((tt - a[1]) / math.max(1e-6, b[1] - a[1]))
		local p0 = (k[i - 1] or a)[2]
		local p3 = (k[i + 2] or b)[2]
		local fovA, fovB = a[4] or s.fov, b[4] or s.fov
		return catmull(p0, a[2], b[2], p3, u), a[3]:Lerp(b[3], u), fovA + (fovB - fovA) * u
	end
end

-- Révélation : la caméra passe d'une position cachée (derrière un mur, sous un toit, au ras d'un objet) à la vue,
-- en freinant net (outQuint) ; la cible est fixe. spec = { from, to, look, dur, ease = "outQuint", fov, lookFrom = nil }
function M.reveal(s)
	local ez = curve(s.ease or "outQuint")
	return function(t)
		local u = ez(clamp01(t / s.dur))
		local look = if s.lookFrom then s.lookFrom:Lerp(s.look, u) else s.look
		return s.from:Lerp(s.to, u), look, s.fov + ((s.fovTo or s.fov) - s.fov) * u
	end
end

-- Plan large (drone) : vue haute qui dérive lentement. spec = { pos, look, drift = Vector3, dur, fov, ease = "linear" }
function M.wide(s)
	local ez = curve(s.ease or "linear")
	return function(t)
		local u = ez(clamp01(t / s.dur))
		local d = (s.drift or Vector3.zero) * u
		return s.pos + d, s.look + d * (s.lookDrift or 0.6), s.fov
	end
end

-- Suivi d'un acteur : spec = { actor = "p1", offset = Vector3 (repère de l'acteur : X droite, Y haut, Z arrière),
-- lookOffset = Vector3, lag = 0.15 (lissage en s), fov, world = false (offset en repère monde) }
-- offsetTo + dur : l'écart change pendant le plan (le sujet se rapproche ou s'éloigne de la caméra).
function M.follow(s)
	local smooth
	local ez = curve(s.ease)
	return function(t, S)
		if t <= 0 then smooth = nil end -- nouvelle prise : pas de lissage hérité de la précédente
		local a = S.actors[s.actor]
		if not a then return Vector3.zero, Vector3.zAxis, s.fov end
		local cf = a.cf or a.root.CFrame
		local flat = CFrame.lookAt(cf.Position, cf.Position + (cf.LookVector * Vector3.new(1, 0, 1)))
		local offset = if s.offsetTo and s.dur then s.offset:Lerp(s.offsetTo, ez(clamp01(t / s.dur))) else s.offset
		local want = if s.world then cf.Position + offset else flat:PointToWorldSpace(offset)
		local look = cf.Position + (s.lookOffset or Vector3.new(0, 1.5, 0))
		if smooth and S.dt then
			local k = 1 - math.exp(-S.dt / (s.lag or 0.15))
			smooth = smooth:Lerp(want, k)
		else
			smooth = want
		end
		return smooth, look, s.fov
	end
end

-- Enchaîne plusieurs mouvements : spec = { {dur, move}, {dur, move}, ... } (chaque move reçoit son t local)
function M.chain(list)
	return function(t, S)
		local acc = 0
		for i, seg in list do
			if t <= acc + seg[1] or i == #list then
				return seg[2](t - acc, S)
			end
			acc += seg[1]
		end
	end
end

-- Ajoute une secousse courte (impact) : M.shake(move, { at = 1.2, dur = 0.3, amp = 0.35 })
-- ou { atKey = "breakAt", ... } : l'instant est lu dans S (posé par l'update du plan au moment de l'impact).
function M.shake(move, s)
	return function(t, S)
		local pos, look, fov = move(t, S)
		local at = if s.atKey then S[s.atKey] else s.at
		if not at then return pos, look, fov end
		local x = t - at
		if x > 0 and x < s.dur then
			local a = (1 - x / s.dur) * s.amp
			local off = Vector3.new(math.sin(x * 93) * a, math.cos(x * 71) * a, math.sin(x * 57) * a * 0.5)
			pos += off
			look += off * 0.6
		end
		return pos, look, fov
	end
end

-- Caméra à l'épaule : bruit doux (math.noise, deux octaves) sur la position et la visée, comme un cadreur qui tient
-- la caméra. Rend un plan « naturel » sans le faire trembler. M.handheld(move, { amp = 0.12, look = 0.25, freq = 0.6, seed = 1 })
function M.handheld(move, s)
	local amp, lamp, freq, seed = s.amp or 0.12, s.look or 0.25, s.freq or 0.6, s.seed or 1
	local function n(x, k)
		return math.noise(x, seed * 7.13 + k * 1.71, 0.37) + 0.35 * math.noise(x * 3.1, seed * 3.7 + k * 2.3, 0.81)
	end
	return function(t, S)
		local pos, look, fov = move(t, S)
		local x = t * freq
		pos += Vector3.new(n(x, 1), n(x, 2) * 0.7, n(x, 3)) * amp * 2
		look += Vector3.new(n(x, 4), n(x, 5) * 0.8, n(x, 6)) * lamp * 2
		return pos, look, fov
	end
end

-- Zoom (le champ se resserre ou s'ouvre) sur n'importe quel mouvement :
-- M.zoom(move, { to = 35, from = nil (champ du mouvement), at = 0 | atKey = "breakAt", dur = 1.5, ease = "sine" })
function M.zoom(move, s)
	local ez = curve(s.ease)
	return function(t, S)
		local pos, look, fov = move(t, S)
		local f0 = s.from or fov or 45
		local at = if s.atKey then S[s.atKey] else (s.at or 0)
		if not at then return pos, look, f0 end
		local u = ez(clamp01((t - at) / s.dur))
		return pos, look, f0 + (s.to - f0) * u
	end
end

-- Cadreur : la caméra suit un chemin (keys = { {t, pos, fov?}, ... }, spline) et garde l'action au centre : elle vise
-- la moyenne des cibles (id d'acteur, ou fonction(S) -> Vector3) + lookOffset, avec du retard (lag), comme un cadreur
-- qui panote pour suivre ce qui se passe. spec = { keys, targets = { "p1", "g1" }, lookOffset, lag = 0.25, fov, ease = "linear", look (secours) }
function M.operator(s)
	local k = {}
	for _, e in s.keys do table.insert(k, { e[1], e[2], e[2], e[3] }) end
	local base = M.path({ keys = k, ease = s.ease or "linear", fov = s.fov })
	local smooth
	return function(t, S)
		if t <= 0 then smooth = nil end
		local pos, _, fov = base(t, S)
		local sum, n = Vector3.zero, 0
		for _, id in s.targets do
			local p
			if type(id) == "function" then
				p = id(S)
			else
				local a = S.actors[id]
				p = a and a.cf and a.cf.Position
			end
			if p then
				sum += p
				n += 1
			end
		end
		local want = if n > 0 then sum / n + (s.lookOffset or Vector3.new(0, 1.5, 0)) else s.look
		if smooth and S.dt and S.dt > 0 then
			smooth = smooth:Lerp(want, 1 - math.exp(-S.dt / (s.lag or 0.25)))
		else
			smooth = want
		end
		return pos, smooth, fov
	end
end

------------------------------------------------------------------------------------------------
-- Faux joueurs et vigiles
------------------------------------------------------------------------------------------------
-- Tenues : bacon hair de départ (mémoire bacon-hair-outfit : veste noire ouverte, t-shirt bleu à moto, jean vert foncé,
-- baskets blanches, peau beige). La chemise est un gabarit fait par make_shirt_baconhair.py, chargé en local
-- (dossier content de Studio) : il ne se voit que sur ce PC, ce qui suffit pour tourner.
local SKIN = Color3.fromRGB(234, 184, 146) -- même beige que les vigiles
T.LOOKS = {
	bacon = { hair = "63690008", shirtTex = "rbxasset://textures/StealAShopTrailer/shirt_baconhair.png", pants = 144076760, skin = SKIN },
	bacon_guitare = { hair = "63690008", shirt = 382538295, pants = 382537569, skin = SKIN }, -- autre tenue de départ Roblox
	bacon_jean = { hair = "147193065", shirt = 144076358, pants = 129458426, skin = Color3.fromRGB(204, 142, 105) },
	-- objets gratuits de Roblox (trouvés par AvatarEditorService:SearchCatalog le 2026-11-25), pour une foule variée
	lavande = { hair = "451220849", shirt = 382537702, pants = 144076760, skin = Color3.fromRGB(255, 214, 178) }, -- chignon lavande, chemise turquoise
	blond = { hair = "376526888", shirt = 398635081, pants = 398635338, skin = SKIN }, -- cheveux blonds lissés, chemise écossaise bleue, pantalon de skateur
	tresses = { hair = "7193454569", shirt = 4047884939, pants = 129458426, skin = Color3.fromRGB(124, 84, 60) }, -- tresses noires, sweat pizza
	brune = { hair = "376548738", shirt = 398633584, pants = 382537569, skin = Color3.fromRGB(204, 142, 105) }, -- coupe de charme brune, veste en jean
}

-- Animations Roblox de base (R15) pour courir et marcher ; les nôtres sont lues par leur nom dans
-- ReplicatedStorage/Assets/Animations/Player (joueur) ou dans le dossier Animations du modèle (vigile).
local BASE = {
	Run = "rbxassetid://507767714",
	Walk = "rbxassetid://507777826",
	Idle = "rbxassetid://507766666",
}

T.cast = {} -- au rechargement, les acteurs déjà dans _TRAILER/Actors sont repris avec les nouvelles méthodes

local function stripScripts(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
end

local Actor = {}
Actor.__index = Actor
T.Actor = Actor

local function newActor(id: string, model: Model, kind: string)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	local a = setmetatable({ id = id, model = model, hum = hum, animator = animator, root = root, kind = kind, tracks = {} }, Actor)
	T.cast[id] = a
	return a
end

-- T.actor("p1", "bacon") : faux joueur ; T.actor("g1", "guard:Guard_Z1") : copie d'un vigile de ReplicatedStorage/Assets/Guards.
function T.actor(id: string, look: string)
	local folder = sub("Actors")
	local existing = T.cast[id]
	if existing and existing.model.Parent then return existing end
	local m = folder:FindFirstChild(id)
	if m then return newActor(id, m, if look:sub(1, 6) == "guard:" or look:sub(1, 8) == "witness:" then "guard" else "player") end
	-- "witness:NPC_Witness_Z1_01" : copie d'un témoin de la carte (l'original n'est pas touché)
	if look:sub(1, 8) == "witness:" then
		local src = workspace.Map:FindFirstChild(look:sub(9), true)
		assert(src, "témoin introuvable : " .. look)
		m = src:Clone()
		m.Name = id
		stripScripts(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.CanCollide = false end
		end
		m.Parent = folder
		return newActor(id, m, "guard")
	end
	if look:sub(1, 6) == "guard:" then
		local src = Assets.Guards:FindFirstChild(look:sub(7))
		assert(src, "vigile introuvable : " .. look)
		m = src:Clone()
		m.Name = id
		stripScripts(m)
		m.Parent = folder
		return newActor(id, m, "guard")
	end
	local L = T.LOOKS[look]
	assert(L, "tenue inconnue : " .. look)
	local desc = Instance.new("HumanoidDescription")
	desc.HairAccessory = L.hair or ""
	desc.Shirt = L.shirt or 0
	desc.Pants = L.pants or 0
	desc.HeadColor, desc.TorsoColor = L.skin, L.skin
	desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = L.skin, L.skin, L.skin, L.skin
	m = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	m.Name = id
	stripScripts(m)
	if L.shirtTex then
		local sh = m:FindFirstChildOfClass("Shirt")
		if not sh then
			sh = Instance.new("Shirt")
			sh.ShirtTemplate = L.shirtTex
			sh.Parent = m
		end
		sh.ShirtTemplate = L.shirtTex
	end
	m.Parent = folder
	return newActor(id, m, "player")
end

function Actor:animId(name: string): string?
	local own = self.model:FindFirstChild("Animations")
	local a = own and own:FindFirstChild(name)
	if a and a:IsA("Animation") then return a.AnimationId end
	local pl = Assets.Animations:FindFirstChild("Player")
	a = pl and pl:FindFirstChild(name)
	if a and a:IsA("Animation") then return a.AnimationId end
	return BASE[name]
end

function Actor:track(name: string)
	local tr = self.tracks[name]
	if tr then return tr end
	local id = self:animId(name)
	assert(id, self.id .. " : animation inconnue " .. name)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	tr = self.animator:LoadAnimation(anim)
	self.tracks[name] = tr
	return tr
end

-- opts : { fade = 0.15, weight = 1, speed = 1, looped = nil (garde celui de l'animation) }
function Actor:play(name: string, opts)
	opts = opts or {}
	local tr = self:track(name)
	if opts.looped ~= nil then tr.Looped = opts.looped end
	if not tr.IsPlaying then tr:Play(opts.fade or 0.15, opts.weight or 1, opts.speed or 1) end
	return tr
end

function Actor:stop(name: string, fade: number?)
	local tr = self.tracks[name]
	if tr and tr.IsPlaying then tr:Stop(fade or 0.15) end
end

function Actor:stopAll()
	for _, tr in self.tracks do tr:Stop(0) end
	self.animator:StepAnimations(0)
end

-- Pose le perso debout sur le sol en p, tourné vers face (point ou direction)
function Actor:place(p: Vector3, faceDir: Vector3?)
	local y = T.ground(p)
	local h = self.hum.HipHeight + self.root.Size.Y / 2
	local dir = faceDir and (faceDir * Vector3.new(1, 0, 1)) or self.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1e-3 then dir = Vector3.zAxis end
	local pos = Vector3.new(p.X, y + h, p.Z)
	self.cf = CFrame.lookAt(pos, pos + dir.Unit)
	self.model:PivotTo(self.cf)
end

function Actor:setCF(cf: CFrame)
	self.cf = cf
	self.model:PivotTo(cf)
end

-- Remet l'acteur à zéro au début d'un plan : objet porté et outil retirés, animations arrêtées.
function Actor:reset()
	if self.carried then
		self.carried.model:Destroy()
		self.carried = nil
	end
	if self.held then
		self.held.model:Destroy()
		self.held = nil
	end
	self:stopAll()
end

-- Projeté (frappé, éjecté par une vitrine) : de p0 à p1 (points au sol), u de 0 à 1 le long du vol, sommet à h studs
-- au-dessus de la ligne ; le corps bascule de tilt degrés vers l'arrière au sommet et regarde vers face
-- (par défaut là d'où il vient : il part à reculons).
function Actor:flyAt(p0: Vector3, p1: Vector3, h: number, u: number, face: Vector3?, tilt: number?)
	u = clamp01(u)
	local hgt = self.hum.HipHeight + self.root.Size.Y / 2
	local y0, y1 = T.ground(p0) + hgt, T.ground(p1) + hgt
	local pos = Vector3.new(p0.X + (p1.X - p0.X) * u, y0 + (y1 - y0) * u + 4 * h * u * (1 - u), p0.Z + (p1.Z - p0.Z) * u)
	local d = (face or (p0 - p1)) * Vector3.new(1, 0, 1)
	if d.Magnitude < 1e-3 then d = Vector3.zAxis end
	self:setCF(CFrame.lookAt(pos, pos + d.Unit) * CFrame.Angles(math.rad(tilt or 0) * math.sin(math.pi * u), 0, 0))
end

------------------------------------------------------------------------------------------------
-- Effets de plateau
------------------------------------------------------------------------------------------------
T.fx = T.fx or {}
T._restore = T._restore or {} -- fonctions de remise en état, appelées à la fin de chaque plan

-- Objet porté au-dessus de la tête : clone d'un ITM_ de ReplicatedStorage/Assets/Items, qui suit la tête.
function T.fx.carry(actor, itemName: string, scale: number?)
	local src = Assets.Items:FindFirstChild(itemName, true)
	assert(src, "objet introuvable : " .. itemName)
	local m = src:Clone()
	stripScripts(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	if scale and scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
	m.Parent = sub("Props")
	-- posé par sa boîte englobante (le pivot d'un ITM_ n'est pas forcément au centre), juste au-dessus des mains levées
	local bb, size = m:GetBoundingBox()
	local head = actor.model:FindFirstChild("Head")
	actor.carried = { model = m, offset = m:GetPivot():ToObjectSpace(bb), lift = head.Size.Y / 2 + size.Y / 2 + 0.5 }
	return m
end

-- Outil tenu dans la main droite : clone d'un TOOL_ de ReplicatedStorage/Assets/Tools (pivot en bas du manche),
-- pointé vers l'avant du poing.
function T.fx.hold(actor, toolName: string)
	local src = Assets.Tools:FindFirstChild(toolName)
	assert(src, "outil introuvable : " .. toolName)
	local m = src:Clone()
	stripScripts(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	m.Parent = sub("Props")
	actor.held = { model = m, grip = CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.45, 0) }
	return m
end

-- Suit la tête (objet porté) et la main droite (outil). Appelé à chaque image par le moteur.
function T.fx.updateCarry(actor)
	local c = actor.carried
	if c then
		local head = actor.model:FindFirstChild("Head")
		local flat = CFrame.lookAt(head.Position, head.Position + actor.root.CFrame.LookVector)
		local box = flat * CFrame.new(0, c.lift, 0)
		c.model:PivotTo(box * (c.offset or CFrame.identity):Inverse())
	end
	local h = actor.held
	if h then
		local hand = actor.model:FindFirstChild("RightHand")
		if hand then h.model:PivotTo(hand.CFrame * h.grip) end
	end
end

-- Décor ou véhicule copié dans _TRAILER/Props : T.fx.prop(S, "cle", "Events", "ENV_Event_Truck_Legendary").
-- Gardé d'une prise à l'autre (T.props[cle]) ; T.prepare range sous la carte ceux qui ne sont pas dans le plan.
-- dossier = un dossier de ReplicatedStorage/Assets (Events, Boxes, Items, FX…). Rend le Model.
T.props = T.props or {}
function T.fx.prop(S, key: string, folder: string, name: string)
	local m = T.props[key]
	if not (m and m.Parent) then
		local src = Assets:FindFirstChild(folder) and Assets[folder]:FindFirstChild(name, true)
		assert(src, "introuvable : Assets/" .. folder .. "/" .. name)
		m = src:Clone()
		m.Name = key
		stripScripts(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		m.Parent = sub("Props")
		T.props[key] = m
	end
	S.props = S.props or {}
	S.props[key] = m
	return m
end

-- Pose un modèle par le bas de sa boîte englobante (posé sur p, tourné vers dir).
function T.fx.setOn(m: Model, p: Vector3, dir: Vector3?)
	local look = dir or Vector3.new(0, 0, -1)
	m:PivotTo(CFrame.lookAt(p, p + look))
	-- recentre la boîte sur p (x, z) et pose son bas sur p.Y
	local bb, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(p.X - bb.Position.X, p.Y - (bb.Position.Y - size.Y / 2), p.Z - bb.Position.Z))
end

-- Effet du jeu émis une fois (copie de ReplicatedStorage/Assets/FX/<nom> dans _TRAILER/FX, effacée par T.stop) :
-- chaque ParticleEmitter émet son attribut EmitCount, ou n.
function T.fx.emit(name: string, cf: CFrame, n: number?)
	local src = Assets.FX:FindFirstChild(name)
	if not src then
		warn("[Trailer] effet introuvable : " .. name)
		return nil
	end
	local fx = src:Clone()
	stripScripts(fx)
	for _, d in fx:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	fx.Parent = sub("FX")
	if fx:IsA("Model") then
		fx:PivotTo(cf)
	elseif fx:IsA("BasePart") then
		fx.CFrame = cf
	end
	for _, e in fx:GetDescendants() do
		if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or n or 20) end
	end
	return fx
end

-- L'objet porté tombe (lâché quand le voleur est frappé ou attrapé) : il quitte la tête, vole et rebondit au sol.
-- vel = vitesse de départ (par défaut vers l'avant de l'acteur et vers le haut). Effacé à la fin du plan.
function T.fx.drop(S, actor, vel: Vector3?)
	local c = actor.carried
	if not c then return nil end
	actor.carried = nil
	local m = c.model
	table.insert(T._restore, function() m:Destroy() end)
	local cf = m:GetPivot()
	local bb, size = m:GetBoundingBox()
	local low = cf.Position.Y - (bb.Position.Y - size.Y / 2) -- du pivot au bas de la boîte
	local v = vel or (actor.root.CFrame.LookVector * 6 + Vector3.new(0, 12, 0))
	local w = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 7
	local floorY = T.ground(cf.Position)
	local rest = false
	local f = {
		step = function(dt)
			if rest then return end
			v -= Vector3.new(0, 70 * dt, 0)
			local p = cf.Position + v * dt
			local rot = cf.Rotation * CFrame.Angles(w.X * dt, w.Y * dt, w.Z * dt)
			if p.Y - low < floorY then
				p = Vector3.new(p.X, floorY + low, p.Z)
				v = Vector3.new(v.X * 0.45, -v.Y * 0.3, v.Z * 0.45)
				w *= 0.5
				if v.Magnitude < 1.5 then rest = true end
			end
			cf = CFrame.new(p) * rot
			m:PivotTo(cf)
		end,
	}
	table.insert(S.fx, f)
	return m
end

-- Rayons d'un magasin PNJ remplis de colis : un BOX_ sur chaque ShelfSlot (tourné vers l'allée, comme en jeu).
-- boxes = liste de noms de Assets/Boxes, reprise en boucle. Les colis sont des décors gardés (T.props).
function T.fx.fillShelves(S, store: Model, boxes: { string }, scale: number?)
	local out = {}
	for i = 1, 10 do
		local sl = store:FindFirstChild(("ShelfSlot_%02d"):format(i), true)
		if sl then
			local cf = if sl:IsA("Attachment") then sl.WorldCFrame elseif sl:IsA("BasePart") then sl.CFrame else sl:GetPivot()
			local name = boxes[(i - 1) % #boxes + 1]
			local m = T.fx.prop(S, store.Name .. "_box" .. i, "Boxes", name)
			if scale and not m:GetAttribute("_Scaled") then
				m:ScaleTo(m:GetScale() * scale)
				m:SetAttribute("_Scaled", true)
			end
			T.fx.setOn(m, cf.Position, cf.LookVector * Vector3.new(1, 0, 1))
			out[i] = m
		end
	end
	return out
end

-- Boutique d'un joueur remplie : un objet ITM_ sur chaque DisplaySlot_nn du PLOT (items = liste de noms, en boucle ;
-- slots = liste de numéros à remplir, tous par défaut). Comme en jeu (DisplayService, Config/DisplayMotion) : jamais
-- grossi, réduit pour tenir dans le FitSize du présentoir moins 1,8 stud, tourné comme le DisplaySlot, flottant à
-- 0,6 stud. Rend une liste { model, base, phase } à passer à T.fx.bob(liste, t) dans update (±0,3 stud, 2,6 s).
-- Les objets ne tournent pas en jeu : ne pas les faire tourner.
function T.fx.fillShop(S, plot: Model, items: { string }, slots: { number }?)
	local out = {}
	local list = slots
	if not list then
		list = {}
		for i = 1, 30 do
			if plot:FindFirstChild(("DisplaySlot_%02d"):format(i), true) then table.insert(list, i) end
		end
	end
	for k, i in list do
		local sl = plot:FindFirstChild(("DisplaySlot_%02d"):format(i), true)
		if sl then
			local cf = if sl:IsA("Attachment") then sl.WorldCFrame elseif sl:IsA("BasePart") then sl.CFrame else sl:GetPivot()
			local m = T.fx.prop(S, plot.Name .. "_item" .. i, "Items", items[(k - 1) % #items + 1])
			local fit = sl:GetAttribute("FitSize")
			if typeof(fit) == "Vector3" and not m:GetAttribute("_Fit") then
				m:PivotTo(cf)
				local _, size = m:GetBoundingBox()
				local f = math.min(1, fit.X / math.max(size.X, 1e-3), fit.Z / math.max(size.Z, 1e-3), (fit.Y - 1.8) / math.max(size.Y, 1e-3))
				if f < 1 then m:ScaleTo(m:GetScale() * f) end
				m:SetAttribute("_Fit", true)
			end
			T.fx.setOn(m, cf.Position + Vector3.new(0, 0.6, 0), cf.LookVector * Vector3.new(1, 0, 1))
			table.insert(out, { model = m, base = m:GetPivot(), phase = (i - 1) * 0.7, slot = i })
		end
	end
	return out
end

-- Flottement des objets exposés (DisplayMotion : ±0,3 stud, période 2,6 s, décalé de 0,7 rad par présentoir).
-- Une entrée marquée hidden (objet pris par un voleur) n'est plus replacée.
function T.fx.bob(list, t: number)
	for _, e in list do
		if not e.hidden then e.model:PivotTo(e.base + Vector3.new(0, 0.3 * math.sin(2 * math.pi * t / 2.6 + e.phase), 0)) end
	end
end

-- Position et direction le long d'un chemin { {t, Vector3}, ... } (interpolation linéaire par segment).
function T.along(keys, t: number): (Vector3, Vector3)
	if t <= keys[1][1] then
		local d = if keys[2] then keys[2][2] - keys[1][2] else Vector3.zAxis
		return keys[1][2], d
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(1e-6, b[1] - a[1])
			return a[2]:Lerp(b[2], u), b[2] - a[2]
		end
	end
	local n = #keys
	return keys[n][2], if n > 1 then keys[n][2] - keys[n - 1][2] else Vector3.zAxis
end

-- Déplace un acteur sur son chemin à l'instant t (il regarde là où il va, sauf face donné).
function Actor:follow(keys, t: number, face: Vector3?)
	local p, d = T.along(keys, t)
	self:place(p, face or d)
end

-- Pièces de la map cachées en local (LocalTransparencyModifier) : un seul registre pour tout l'outil, et seule la
-- première valeur vue est gardée. Sans ça, une pièce cachée deux fois (deux casses de la même vitrine, un repérage
-- puis le plan) gardait 1 comme valeur à remettre et restait invisible (porte de PLOT_Shop_03, 2026-11-25).
-- En Edit, rien d'autre ne pose cette propriété sur la map : une valeur de 1 trouvée au départ se remet à 0.
T._ltm = T._ltm or {}
function T.hideLocal(p: BasePart)
	if T._ltm[p] == nil then
		local v = p.LocalTransparencyModifier
		T._ltm[p] = if v >= 1 then 0 else v
	end
	p.LocalTransparencyModifier = 1
end
function T.restoreLocal()
	for p, v in T._ltm do
		if p.Parent then p.LocalTransparencyModifier = v end
	end
	T._ltm = {}
end

-- Vitrine qui casse : la vraie Window du magasin est cachée en local (T.hideLocal, jamais enregistré)
-- et les éclats de WindowFractured sont copiés dans _TRAILER/FX puis lancés vers la rue (balistique image par image).
-- Rend un objet { step = function(dt) }. La fin du plan remet la vitrine.
function T.fx.breakWindow(store: Model, opts)
	opts = opts or {}
	local win = store:FindFirstChild("Window")
	local frac = store:FindFirstChild("WindowFractured")
	assert(win and frac, store.Name .. " : Window ou WindowFractured absent")
	for _, p in ({ win, table.unpack(win:GetDescendants()) }) do
		if p:IsA("BasePart") then T.hideLocal(p) end
	end
	table.insert(T._restore, T.restoreLocal)
	-- côté rue : la rue du couloir est sur l'axe z = 0
	-- Window est une pièce dans les magasins PNJ, mais un Model dans la porte des boutiques (PLOT_Shop_0n/PlotDoor)
	local winPart = if win:IsA("BasePart") then win else win:FindFirstChildWhichIsA("BasePart", true)
	local wp = if win:IsA("BasePart") then win.Position else win:GetPivot().Position
	local winTransparency = if winPart then winPart.Transparency else 0.5
	-- les éclats partent du centre du bâtiment vers la vitre (magasin PNJ : vers la rue ; porte de boutique : vers le hub)
	local building = if store.Name == "PlotDoor" and store.Parent and store.Parent:IsA("Model") then store.Parent else store
	local away = (wp - building:GetPivot().Position) * Vector3.new(1, 0, 1)
	local out = if away.Magnitude > 1 then away.Unit else Vector3.new(0, 0, -math.sign(wp.Z))
	if opts.normal then out = opts.normal end
	local folder = sub("FX")
	local shards = {}
	local floorY = T.ground(wp + out * 4)
	for _, s in frac:GetDescendants() do
		if s:IsA("BasePart") then
			local c = s:Clone()
			for _, ch in c:GetChildren() do if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") then ch:Destroy() end end
			c.Transparency = math.min(0.35, winTransparency)
			c.Anchored = true
			c.CanCollide = false
			c.Parent = folder
			local side = Vector3.new(out.Z, 0, -out.X)
			local spread = (s.Position - wp):Dot(side)
			local v = out * (opts.speed or 1) * (14 + math.random() * 16) + side * spread * 0.9 + Vector3.new(0, 6 + math.random() * 12, 0)
			local w = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18
			table.insert(shards, { part = c, cf = c.CFrame, v = v, w = w, rest = false, base = c.Transparency })
		end
	end
	-- poussière de verre : l'effet du jeu FX_ShopGlass_Burst, s'il existe
	local burst = Assets.FX:FindFirstChild("FX_ShopGlass_Burst")
	if burst and not opts.noBurst then
		local b = burst:Clone()
		stripScripts(b)
		b.Parent = folder
		if b:IsA("Model") then b:PivotTo(CFrame.lookAt(wp, wp + out)) end
		for _, e in b:GetDescendants() do
			if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 30) end
		end
	end
	local G = opts.gravity or 70
	-- les éclats s'effacent après fadeAt s (sinon ils s'empilent en gros pavés devant l'objectif)
	local fadeAt, fadeDur = opts.fadeAt or 0.9, opts.fadeDur or 0.7
	local age = 0
	return {
		step = function(dt)
			age += dt
			local f = math.clamp((age - fadeAt) / fadeDur, 0, 1)
			for _, s in shards do
				if f > 0 then s.part.Transparency = s.base + (1 - s.base) * f end
				if not s.rest then
					s.v -= Vector3.new(0, G * dt, 0)
					local pos = s.cf.Position + s.v * dt
					local rot = s.cf.Rotation * CFrame.Angles(s.w.X * dt, s.w.Y * dt, s.w.Z * dt)
					if pos.Y < floorY + 0.1 then
						pos = Vector3.new(pos.X, floorY + 0.1, pos.Z)
						s.v = Vector3.new(s.v.X * 0.35, -s.v.Y * 0.18, s.v.Z * 0.35)
						s.w *= 0.4
						if s.v.Magnitude < 1.5 then s.rest = true end
					end
					s.cf = CFrame.new(pos) * rot
					s.part.CFrame = s.cf
				end
			end
		end,
	}
end

------------------------------------------------------------------------------------------------
-- Moteur d'un plan
------------------------------------------------------------------------------------------------
-- Un plan (shots.luau) :
-- {
--   dur = 3,            -- secondes de vidéo
--   slow = 2,           -- la prise dure slow fois plus longtemps ; le montage accélère slow fois (images plus fluides)
--   roll = true,        -- caméra tournée de 90° : le viewport donne une image verticale (9:16 au montage)
--   cam = T.moves.xxx{...},
--   setup = function(S) ... end,      -- crée les acteurs, les pose (appelé par T.prepare)
--   update = function(S, t, dt) ... end, -- chaque image : déplace les acteurs, lance les effets
-- }
T.shots = T.shots or {}
T.PREROLL = 1.5 -- s d'écran noir avant le top (repère de synchro du montage)
T.POSTROLL = 0.5

local state

-- En Edit, Studio redresse sa caméra à chaque image : le roulis ne tient que s'il est reposé à chaque image,
-- APRÈS la caméra de Studio (BindToRenderStep en priorité Last + 100). Un simple cam.CFrame = … ne suffit pas.
local STEP = "_TrailerShot"
local function unbind(name)
	pcall(function() RunService:UnbindFromRenderStep(name) end)
end

local function blackPart(on: boolean)
	local cam = workspace.CurrentCamera
	local p = T.root():FindFirstChild("_Black")
	if on then
		if not p then
			p = Instance.new("Part")
			p.Name = "_Black"
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = Color3.new(0, 0, 0)
			p.Size = Vector3.new(400, 400, 0.05)
			p.Parent = T.root()
		end
		p.CFrame = cam.CFrame * CFrame.new(0, 0, -0.5)
	elseif p then
		p:Destroy()
	end
end
T._black = blackPart

-- Type de caméra à remettre à la fin : jamais Scriptable (c'est le nôtre ; un plan resté préparé l'aurait laissé),
-- la caméra de Studio en Edit est Fixed (vu le 2026-11-25, une suite de repérages avait fini par remettre Scriptable).
local function userType(cam: Camera): Enum.CameraType
	return if cam.CameraType == Enum.CameraType.Scriptable then Enum.CameraType.Fixed else cam.CameraType
end

local function applyCam(S, t)
	local pos, look, fov = S.shot.cam(t, S)
	local cam = workspace.CurrentCamera
	local cf = CFrame.lookAt(pos, look)
	if S.shot.roll ~= false then cf *= CFrame.Angles(0, 0, math.rad(90)) end
	cam.CFrame = cf
	cam.Focus = CFrame.new(look)
	if fov then cam.FieldOfView = fov end
	-- Reposés à chaque image (T.stop remet les deux) : caméra Scriptable (en Fixed, Studio dessine son repère de visée,
	-- un point blanc et deux traits) et HUD caché (le 2026-11-25, deux plans d'un lot ont été filmés avec le HUD).
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	if StarterGui.ShowDevelopmentGui then StarterGui.ShowDevelopmentGui = false end
end

-- Pose le plan à sa première image, écran noir : appeler avant de lancer la capture.
function T.prepare(name: string)
	unbind(STEP)
	unbind("_TrailerPeek")
	local shot = T.shots[name]
	assert(shot, "plan inconnu : " .. tostring(name))
	local cam = workspace.CurrentCamera
	-- la vue à remettre à la fin : celle de Clément, jamais celle d'un plan resté préparé ou d'un repérage
	local saved
	if state and state.phase ~= "done" then
		saved = state.saved
		for _, f in T._restore do pcall(f) end
		T._restore = {}
	elseif T._peekSaved then
		saved = { cf = T._peekSaved.cf, focus = T._peekSaved.focus, fov = T._peekSaved.fov, type = T._peekSaved.type or userType(cam), devGui = true, sel = {} }
		T._peekSaved = nil
	else
		saved = { cf = cam.CFrame, focus = cam.Focus, fov = cam.FieldOfView, type = userType(cam), devGui = StarterGui.ShowDevelopmentGui, sel = Selection:Get() }
	end
	local fxOld = T.root():FindFirstChild("FX")
	if fxOld then fxOld:Destroy() end
	state = {
		name = name,
		shot = shot,
		t = 0,
		dt = 1 / 60,
		actors = {},
		fx = {},
		phase = "ready",
		saved = saved,
	}
	T.state = state
	Selection:Set({})
	StarterGui.ShowDevelopmentGui = false
	-- Scriptable : la caméra de Studio (Fixed) ne pilote plus la vue et ne dessine plus son repère de visée (un point
	-- blanc et deux traits sur la scène, vu le 2026-11-25). T.stop remet le type d'origine (saved.type).
	cam.CameraType = Enum.CameraType.Scriptable
	if shot.setup then shot.setup(state) end
	-- les acteurs des autres plans sont rangés sous la carte, pour ne pas entrer dans le champ
	local far = CFrame.new(0, -1000, 0)
	for _, a in T.cast do
		local inShot = false
		for _, b in state.actors do if b == a then inShot = true end end
		if not inShot and a.model.Parent then
			a.model:PivotTo(far)
			if a.carried then a.carried.model:PivotTo(far) end
			if a.held then a.held.model:PivotTo(far) end
		end
	end
	for key, m in T.props do
		if m.Parent and not (state.props and state.props[key]) then m:PivotTo(far) end
	end
	if shot.update then shot.update(state, 0, 0) end
	for _, a in state.actors do
		a.animator:StepAnimations(0)
		T.fx.updateCarry(a)
	end
	-- tant que T.go() n'est pas lancé, la première image est tenue (et noire) à chaque image
	local S0 = state
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 100, function()
		applyCam(S0, 0)
		blackPart(true)
	end)
	applyCam(state, 0)
	blackPart(true)
	local vp = cam.ViewportSize
	return ("prêt : %s, %d s × %d (prise %.1f s avec les noirs), viewport %d × %d"):format(name, shot.dur, shot.slow or 1, T.PREROLL + shot.dur * (shot.slow or 1) + T.POSTROLL + 0.5, vp.X, vp.Y)
end

-- Remet tout ce qui a été touché hors de _TRAILER, et arrête les acteurs.
function T.stop()
	local S = state
	if not S then return "rien à arrêter" end
	unbind(STEP)
	blackPart(false)
	for _, f in T._restore do pcall(f) end
	T._restore = {}
	for _, a in S.actors do pcall(function() a:stopAll() end) end
	local cam = workspace.CurrentCamera
	cam.CameraType = S.saved.type
	cam.CFrame = S.saved.cf
	cam.Focus = S.saved.focus
	cam.FieldOfView = S.saved.fov
	StarterGui.ShowDevelopmentGui = S.saved.devGui
	pcall(function() Selection:Set(S.saved.sel) end)
	S.phase = "done"
	local fx = T.root():FindFirstChild("FX")
	if fx then fx:Destroy() end
	return "arrêté : " .. S.name .. " (caméra de Clément remise)"
end

-- Lance le plan préparé : PREROLL s de noir, puis le plan au ralenti, puis POSTROLL s de noir, puis T.stop().
function T.go()
	local S = state
	assert(S and S.phase == "ready", "appeler T.prepare(nom) d'abord")
	local slow = S.shot.slow or 1
	local start = os.clock()
	S.phase = "preroll"
	unbind(STEP)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 100, function()
		local ok, err = pcall(function()
			local real = os.clock() - start
			if S.phase == "preroll" then
				applyCam(S, 0)
				blackPart(true)
				if real >= T.PREROLL then
					blackPart(false)
					S.phase = "run"
					S.runStart = os.clock()
					S.frames = 0
				end
				return
			end
			if S.phase == "run" then
				local t = (os.clock() - S.runStart) / slow
				local dt = math.clamp(t - S.t, 0, 0.1)
				S.t, S.dt = t, dt
				S.frames += 1
				if S.shot.update then S.shot.update(S, math.min(t, S.shot.dur), dt) end
				for _, a in S.actors do
					a.animator:StepAnimations(dt)
					T.fx.updateCarry(a)
				end
				for _, f in S.fx do f.step(dt) end
				applyCam(S, math.min(t, S.shot.dur))
				if t >= S.shot.dur then
					S.phase = "postroll"
					S.postStart = os.clock()
					S.fps = S.frames / (os.clock() - S.runStart)
				end
				return
			end
			if S.phase == "postroll" then
				applyCam(S, S.shot.dur)
				blackPart(true)
				if os.clock() - S.postStart >= T.POSTROLL then
					T.stop()
				end
			end
		end)
		if not ok then
			warn("[Trailer] " .. tostring(err))
			T.stop()
		end
	end)
	return "top : " .. S.name
end

-- Image fixe pour repérer un cadrage (sans noir, sans roulis si roll = false) : T.peek(pos, look, fov, roll)
function T.peek(pos: Vector3, look: Vector3, fov: number?, roll: boolean?)
	local cam = workspace.CurrentCamera
	if state and state.phase ~= "done" then T.stop() end
	T._peekSaved = T._peekSaved or { cf = cam.CFrame, focus = cam.Focus, fov = cam.FieldOfView, type = userType(cam) }
	local cf = CFrame.lookAt(pos, look)
	if roll then cf *= CFrame.Angles(0, 0, math.rad(90)) end
	cam.CameraType = Enum.CameraType.Scriptable -- sans repère de visée de Studio
	StarterGui.ShowDevelopmentGui = false
	Selection:Set({})
	unbind("_TrailerPeek")
	RunService:BindToRenderStep("_TrailerPeek", Enum.RenderPriority.Last.Value + 100, function()
		cam.CFrame = cf
		cam.Focus = CFrame.new(look)
		cam.FieldOfView = fov or 45
	end)
	return "vue posée"
end

function T.unpeek()
	unbind("_TrailerPeek")
	local s = T._peekSaved
	if not s then return "rien à remettre" end
	local cam = workspace.CurrentCamera
	cam.CFrame, cam.Focus, cam.FieldOfView = s.cf, s.focus, s.fov
	if s.type then cam.CameraType = s.type end
	StarterGui.ShowDevelopmentGui = true
	T._peekSaved = nil
	return "caméra de Clément remise"
end

-- Repérage : pose le plan à l'instant t (acteurs et caméra), SANS écran noir, et le tient à chaque image.
-- T.still(nom, t) puis capture de l'écran ; T.stop() remet la vue de Clément.
function T.still(name: string, t: number?)
	T.prepare(name)
	local S = state
	local at = t or 0
	if at > 0 and S.shot.update then S.shot.update(S, at, 0) end
	for _, a in S.actors do T.fx.updateCarry(a) end
	unbind(STEP)
	blackPart(false)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 100, function()
		applyCam(S, at)
	end)
	return "repérage : " .. name .. " à t = " .. at
end

-- Repérage fidèle : le plan est JOUÉ image par image (1/30 s) de 0 à t (animations, éclats, objets lâchés, lissages
-- de la caméra), puis tenu à l'instant t, sans noir. Plus juste que T.still pour un moment d'action (impact, vol plané).
function T.stillAt(name: string, t: number)
	T.prepare(name)
	local S = state
	local tt = 0
	while tt < t - 1e-6 do
		local step = math.min(1 / 30, t - tt)
		tt += step
		S.t, S.dt = tt, step
		if S.shot.update then S.shot.update(S, tt, step) end
		for _, a in S.actors do
			a.animator:StepAnimations(step)
			T.fx.updateCarry(a)
		end
		for _, f in S.fx do f.step(step) end
		S.shot.cam(tt, S)
	end
	unbind(STEP)
	blackPart(false)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 100, function()
		applyCam(S, t)
	end)
	return "repérage : " .. name .. " à t = " .. t
end

-- Lot : enchaîne plusieurs plans dans une seule capture, séparés par les noirs de T.prepare et de T.go.
-- Lancer la capture d'abord (durée = somme des prises + 25 s), puis T.batch({ "plan1", "plan2", … }) ;
-- le script decoupe_lot.py du skill recoupe un fichier par plan. Rend la durée et les images par seconde de chaque plan.
function T.batch(list)
	local res = {}
	local t0 = os.clock()
	for _, name in list do
		local ok, err = pcall(T.prepare, name)
		if not ok then
			table.insert(res, name .. " ERREUR " .. tostring(err))
		else
			task.wait(0.8)
			T.go()
			while state.phase ~= "done" do task.wait(0.1) end
			table.insert(res, ("%s %.0f i/s"):format(name, state.fps or -1))
		end
	end
	return ("%.0f s : %s"):format(os.clock() - t0, table.concat(res, " | "))
end

-- Vide Workspace/_TRAILER (fin du tournage). Ne touche à rien d'autre.
function T.clear()
	if state and state.phase ~= "done" then T.stop() end
	-- remises restées en attente (repérage par T.stillAt, plan interrompu) : rien ne reste caché après le tournage
	for _, f in T._restore do pcall(f) end
	T._restore = {}
	T.restoreLocal()
	local r = workspace:FindFirstChild("_TRAILER")
	if r then r:Destroy() end
	T.cast = {}
	T.props = {}
	return "_TRAILER vidé"
end

return "Trailer " .. T.VERSION .. " chargé"
