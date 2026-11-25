--!nocheck
-- Couche « vrai jeu » de l'outil de tournage (skill trailer-tiktok, references/vrai-jeu.md), 2026-11-25.
-- Retour de Clément sur la série naturelle : « ça montre une idéalisation du jeu ». Ici, tout vient du jeu :
--   - objets : taille de leur poids (Shared/ItemWeight), revenu (Config/Formulas.ItemIncome), étiquettes BB_Item et
--     BB_Carry de Clément remplies comme le fait le code, halo (Shared/RarityHalo), contour BD (Highlight #040435) ;
--   - vitrine : plusieurs coups (éclats, étincelles FX_GlassSparkle, éclair, chiffre « -N », barre BB_WindowHP),
--     puis la casse (« SMASHED! », flash blanc, arrêt sur image) ;
--   - colis : il saute du rayon au sol, s'ouvre en plusieurs actions (accessoires TOOL_Unbox_*, FX_Unbox_*,
--     compteur BB_UnboxOdds), silhouettes, révélation BB_Reveal, l'objet grandit puis se pose sur la tête ;
--   - poursuite : écran UI_Chase de Clément (RUN!, bords rouges), vigile en rouge, bulles BB_GuardShout ; capture
--     « CAUGHT! » ;
--   - bruitages : chaque événement note son son (R.sfx) ; mix_sfx.py les pose sur le plan au montage.
-- Les écrans (RUN!, SMASHED!, CAUGHT!) sont posés dans un cadre tourné de 90° du CoreGui : la caméra est tournée
-- pour le 9:16, l'image redressée au montage redresse aussi l'écran. Tout est retiré par T.stop.
-- À charger après trailer_lib.luau, en Edit.

local T = _G.Trailer
local RS = game:GetService("ReplicatedStorage")
local CG = game:GetService("CoreGui")
local Sh = RS:WaitForChild("Shared")
local Items = require(Sh.Config.Items)
local Rarities = require(Sh.Config.Rarities)
local Formulas = require(Sh.Config.Formulas)
local ItemWeight = require(Sh.ItemWeight)
local Format = require(Sh.Format)
local RarityHalo = require(Sh.RarityHalo)
local Assets = RS.Assets
local UIA = Assets.UI
local V = Vector3.new

local R = T.real or {}
T.real = R
T.sfxLogs = T.sfxLogs or {}

local OUTLINE = Color3.fromHex("#040435") -- contour BD (Config/Outlines)
local STOLEN = Color3.fromHex("#E8413C") -- objet volé à un joueur (CarryService)
local GLASS = Color3.fromRGB(191, 230, 255) -- Config/Shatter.GlassColor
local DARK = Color3.fromRGB(27, 27, 36) -- contour des chiffres et du « SMASHED! »

local function props(): Folder
	local r = T.root()
	local f = r:FindFirstChild("Props")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Props"
		f.Parent = r
	end
	return f
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

local function anchorPart(m: Model): BasePart?
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
end

local function clampT(x) return math.clamp(x, 0, 1) end

------------------------------------------------------------------------------------------------
-- Bruitages : chaque événement note son son à l'instant du plan (secondes de vidéo finale)
------------------------------------------------------------------------------------------------
function R.sfx(S, name: string, delay: number?, gain: number?)
	local log = T.sfxLogs[S.name]
	if not log then
		log = {}
		T.sfxLogs[S.name] = log
	end
	table.insert(log, { t = (S.t or 0) + (delay or 0), name = name, gain = gain or 1 })
end

------------------------------------------------------------------------------------------------
-- Objets : infos du catalogue actif, étiquette, contour, halo
------------------------------------------------------------------------------------------------
function R.info(itemId: string, kg: number)
	local it = Items.ById[itemId]
	assert(it, "objet hors du catalogue actif : " .. itemId)
	local rar = Rarities.ById[it.Rarity]
	local income = Formulas.ItemIncome(itemId) * ItemWeight.IncomeFactor(kg)
	return {
		id = itemId,
		name = it.DisplayName,
		rarity = rar,
		kg = kg,
		scale = ItemWeight.ScaleFor(kg),
		income = income,
		incomeText = Format.income(income),
		weightText = string.upper(ItemWeight.Format(kg)),
	}
end

local function setRarity(label: TextLabel, rar)
	label.Text = rar.DisplayNameUpper
	if rar.Rainbow then
		label.TextColor3 = Color3.new(1, 1, 1)
		local g = label:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
		g.Color = RarityHalo.Sequence(RarityHalo.Colors(rar))
		g.Parent = label
	else
		label.TextColor3 = rar.Color
	end
end

-- Étiquette de Clément (BB_Item, BB_Carry, BB_Reveal…) remplie comme le code, accrochée à un Attachment.
function R.label(template: string, att: Attachment, info, extra)
	local bb = UIA[template]:Clone()
	bb.Adornee = att
	bb.StudsOffset = Vector3.zero
	bb.Parent = att -- détruite avec l'objet
	local function set(n, v)
		local l = bb:FindFirstChild(n, true)
		if l and l:IsA("TextLabel") then
			if v then
				l.Text = v
				l.Visible = true
			else
				l.Visible = false
			end
		end
	end
	set("ItemName", info.name)
	set("Income", info.incomeText)
	set("Weight", info.weightText)
	set("Mutation", nil)
	set("NewBadge", nil)
	for k, v in extra or {} do set(k, v) end
	local r = bb:FindFirstChild("Rarity", true)
	if r and r:IsA("TextLabel") then setRarity(r, info.rarity) end
	return bb
end

function R.outline(target: Instance, color: Color3?)
	local h = target:FindFirstChild("_Outline") or Instance.new("Highlight")
	h.Name = "_Outline"
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.OutlineColor = color or OUTLINE
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = target
	h.Parent = target
	return h
end

-- Point d'accroche en haut de la boîte d'un modèle (étiquette posée dessus, comme DisplayMotion.BillboardAtTop)
local function topAttachment(m: Model, down: number?): Attachment
	local p = anchorPart(m)
	local a = p:FindFirstChild("_Top") or Instance.new("Attachment")
	a.Name = "_Top"
	a.Parent = p
	local cf, size = m:GetBoundingBox()
	a.WorldPosition = cf.Position + V(0, size.Y / 2 - (down or 0.15), 0)
	return a
end

-- Objet exposé ou posé : copie d'ITM_ à la taille de son poids, avec étiquette, contour et halo.
-- opts = { label = "BB_Item" | false, outline = true, halo = true, fit = Vector3 (FitSize du présentoir) }
function R.item(S, key: string, itemId: string, kg: number, opts)
	opts = opts or {}
	local info = R.info(itemId, kg)
	local m = T.fx.prop(S, key, "Items", "ITM_" .. itemId)
	if m:GetAttribute("_Kg") ~= kg then
		m:ScaleTo(info.scale)
		m:SetAttribute("_Kg", kg)
		m:SetAttribute("_Fit", nil)
		for _, d in m:GetDescendants() do
			if d.Name == "RarityHalo" or d.Name == "HaloPoint" then d:Destroy() end
		end
	end
	return m, info
end

-- Décore un objet posé à sa place (après PivotTo) : étiquette, contour, halo. Les copies gardent leurs décors.
function R.decorate(m: Model, info, opts)
	opts = opts or {}
	if opts.outline ~= false then R.outline(m, opts.outlineColor) end
	if opts.halo ~= false and not m:FindFirstChild("RarityHalo", true) then
		local cf, size = m:GetBoundingBox()
		pcall(RarityHalo.AddDisplayed, m, info.rarity, cf, size)
	end
	if opts.label ~= false then
		local att = topAttachment(m)
		for _, bb in att:GetChildren() do
			if bb:IsA("BillboardGui") then bb:Destroy() end
		end
		R.label(opts.label or "BB_Item", att, info)
	end
end

-- Objet sur un présentoir de boutique (DisplayService) : pivot sur le DisplaySlot, réduit seulement s'il dépasse le
-- FitSize (moins 1,8 stud de flottement), flottant à 0,6 stud. Rend { model, base, phase, info }.
function R.display(S, plot: Model, slotIndex: number, itemId: string, kg: number)
	local sl = plot:FindFirstChild(("DisplaySlot_%02d"):format(slotIndex), true)
	assert(sl, "présentoir introuvable : " .. slotIndex)
	local cf = sl.WorldCFrame
	local m, info = R.item(S, plot.Name .. "_disp" .. slotIndex .. "_" .. itemId, itemId, kg) -- clé avec l'objet
	m:PivotTo(cf)
	local fit = sl:GetAttribute("FitSize")
	if typeof(fit) == "Vector3" and not m:GetAttribute("_Fit") then
		local _, size = m:GetBoundingBox()
		local f = math.min(1, fit.X / math.max(size.X, 1e-3), fit.Z / math.max(size.Z, 1e-3), (fit.Y - 1.8) / math.max(size.Y, 1e-3))
		if f < 1 then m:ScaleTo(m:GetScale() * f) end
		m:SetAttribute("_Fit", true)
	end
	m:PivotTo(cf + V(0, 0.6, 0))
	R.decorate(m, info)
	return { model = m, base = m:GetPivot(), phase = (slotIndex - 1) * 0.7, info = info, slot = slotIndex }
end

-- Objet porté au-dessus de la tête (CarryService) : taille de son poids (×16 au plus), étiquette BB_Carry, halo,
-- contour (rouge s'il est volé à un joueur). Rend le modèle.
function R.carry(actor, itemId: string, kg: number, stolen: boolean?)
	local info = R.info(itemId, kg)
	local m = T.fx.carry(actor, "ITM_" .. itemId, math.min(info.scale, 16))
	local head = actor.model:FindFirstChild("Head")
	local _, size = m:GetBoundingBox()
	actor.carried.lift = head.Size.Y / 2 + size.Y / 2 + 0.25
	actor.carried.info = info
	T.fx.updateCarry(actor)
	R.outline(m, if stolen then STOLEN else nil)
	local p = anchorPart(m)
	local cf = m:GetBoundingBox()
	pcall(RarityHalo.AddCarried, p, p.CFrame:ToObjectSpace(cf), info.rarity, RarityHalo.NoEffects)
	R.label("BB_Carry", topAttachment(m, -0.25), info)
	return m
end

------------------------------------------------------------------------------------------------
-- Écrans (CoreGui, cadre tourné de 90° : redressé au montage avec l'image)
------------------------------------------------------------------------------------------------
function R.uiRoot(): Frame
	local g = CG:FindFirstChild("_TrailerUI")
	if not g then
		g = Instance.new("ScreenGui")
		g.Name = "_TrailerUI"
		g.IgnoreGuiInset = true
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.DisplayOrder = 50
		g.Parent = CG
	end
	local f = g:FindFirstChild("Portrait")
	if not f then
		f = Instance.new("Frame")
		f.Name = "Portrait"
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Parent = g
	end
	-- le cadre couvre exactement l'image 9:16 gardée au montage (partie gauche du viewport, avant transpose=2) :
	-- en plein viewport, le haut de l'écran (RUN!, minuterie) tombait dans la bande coupée
	local vp = workspace.CurrentCamera.ViewportSize
	local roll = not (T.state and T.state.shot and T.state.shot.roll == false)
	if roll then
		-- vue 3D moins large que 16/9 de sa hauteur (1282 × 724 le 2026-11-25, Explorateur rouvert) : le montage
		-- garde toute la largeur et rogne un peu le haut et le bas, au centre (mêmes calculs que les scripts ffmpeg)
		local cropW = math.min(math.floor(vp.Y * 16 / 9 / 2) * 2, math.floor(vp.X / 2) * 2)
		local cropH = math.min(vp.Y, math.floor(vp.X * 9 / 16 / 2) * 2)
		f.Size = UDim2.fromOffset(cropH, cropW)
		f.Position = UDim2.fromOffset(cropW / 2, vp.Y / 2)
		f.Rotation = 90
	else
		f.Size = UDim2.fromScale(1, 1)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Rotation = 0
	end
	return f
end

function R.uiClear()
	local g = CG:FindFirstChild("_TrailerUI")
	if g then g:Destroy() end
end

-- Texte d'écran façon jeu (GothamBlack blanc cerclé de sombre) qui apparaît en grossissant, tient, puis disparaît.
-- spec = { text, pos = UDim2, size = UDim2, rot = -4, from = 0.4, pop = 0.18, hold = 0.7, hide = 0.15, stroke = 4 }
function R.popText(S, spec)
	local root = R.uiRoot()
	local l = Instance.new("TextLabel")
	l.Name = "_Pop"
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = spec.pos or UDim2.fromScale(0.5, 0.42)
	l.Size = spec.size or UDim2.fromScale(0.7, 0.16)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.Text = spec.text
	l.TextScaled = true
	l.TextColor3 = spec.color or Color3.new(1, 1, 1)
	l.Rotation = spec.rot or -4
	l.ZIndex = 20
	local st = Instance.new("UIStroke")
	st.Thickness = spec.stroke or 4
	st.Color = DARK
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = l
	l.Parent = root
	local age = 0
	local pop, hold, hide, from = spec.pop or 0.18, spec.hold or 0.7, spec.hide or 0.15, spec.from or 0.4
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			if age < pop then
				local u = age / pop
				sc.Scale = from + (1.12 - from) * u -- petit dépassement
			elseif age < pop + 0.06 then
				sc.Scale = 1.12 - 0.12 * ((age - pop) / 0.06)
			elseif age < pop + hold then
				sc.Scale = 1
			elseif age < pop + hold + hide then
				sc.Scale = 1 - (age - pop - hold) / hide
			else
				sc.Scale = 0
				l.Visible = false
			end
		end,
	})
	return l
end

-- Flash blanc plein écran (casse de la vitrine : 0,08 s ; surexposition du colis : 0,1 s)
function R.flash(S, dur: number?, peak: number?)
	local root = R.uiRoot()
	local f = Instance.new("Frame")
	f.Name = "_Flash"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1 - (peak or 0.85)
	f.BorderSizePixel = 0
	f.ZIndex = 30
	f.Parent = root
	local age, d = 0, dur or 0.08
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			f.BackgroundTransparency = 1 - (peak or 0.85) * (1 - clampT(age / (d + 0.12)))
			if age > d + 0.12 then f.Visible = false end
		end,
	})
end

-- Écran de poursuite de Clément (UI_Chase) : « RUN! » qui surgit puis pulse, bords rouges qui battent (1,2 s).
function R.runScreen(S)
	local root = R.uiRoot()
	local holder = Instance.new("Frame")
	holder.Name = "_Chase"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = root
	for _, c in game.StarterGui.UI_Chase:GetChildren() do
		c:Clone().Parent = holder
	end
	local banner = holder:FindFirstChild("RunBanner")
	local edges = holder:FindFirstChild("ScreenEdges")
	local vign = holder:FindFirstChild("Vignette")
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = banner
	local age = 0
	local parts = {}
	for _, e in { edges, vign } do
		if e then
			for _, d in e:GetDescendants() do
				if d:IsA("Frame") then table.insert(parts, d) end
			end
		end
	end
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			if age < 0.12 then
				sc.Scale = 1.18 * (age / 0.12)
			elseif age < 0.25 then
				sc.Scale = 1.18 - 0.18 * ((age - 0.12) / 0.13)
			else
				local w = math.sin((age - 0.25) * math.pi * 2 / 0.8)
				sc.Scale = 1 + 0.05 * (0.5 + 0.5 * w)
				banner.Rotation = 1.5 * w
			end
			local tr = 0.35 + 0.25 * math.cos(age * math.pi * 2 / 1.2)
			for _, p in parts do p.BackgroundTransparency = tr end
		end,
	})
	return holder
end

function R.hideRun()
	local root = R.uiRoot()
	local h = root:FindFirstChild("_Chase")
	if h then h:Destroy() end
end

------------------------------------------------------------------------------------------------
-- Vitrine : plusieurs coups, puis la casse
------------------------------------------------------------------------------------------------
local sparkleTex = (Assets.FX:FindFirstChild("FX_GlassSparkle") and Assets.FX.FX_GlassSparkle.Texture) or "rbxasset://textures/particles/sparkles_main.dds"

-- Barre de PV de Clément (BB_WindowHP) sur une vitrine ou une porte : R.hpBar(store) puis R.setHp(bar, hp, max)
function R.hpBar(target: Instance)
	local win = target:FindFirstChild("Window") or target
	local part = if win:IsA("BasePart") then win else win:FindFirstChildWhichIsA("BasePart", true)
	local bb = UIA.BB_WindowHP:Clone()
	bb.Adornee = part
	bb.Parent = props()
	table.insert(T._restore, function() bb:Destroy() end)
	return bb
end

function R.setHp(bb, hp: number, max: number)
	local l = bb:FindFirstChild("Label", true)
	if l then l.Text = Format.hp(math.max(0, hp)) .. " / " .. Format.hp(max) end
	local fill = bb:FindFirstChild("Fill", true)
	if fill then fill.Size = UDim2.new(math.clamp(hp / max, 0, 1), 0, fill.Size.Y.Scale, fill.Size.Y.Offset) end
end

-- Chiffre de dégâts (Config/HitFeedback.Damage) : « -N » blanc cerclé, jaillit de 3,5 studs en 0,9 s.
function R.damageNumber(S, pos: Vector3, n: number)
	local p = Instance.new("Part")
	p.Name = "_Dmg"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = V(0.2, 0.2, 0.2)
	p.Position = pos + V(0, 0.5, 0)
	p.Parent = fxFolder()
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 44)
	bb.AlwaysOnTop = true
	bb.Adornee = p
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = "-" .. Format.short(n)
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = DARK
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = l
	local drift = V((math.random() - 0.5) * 2.4, 0, 0)
	local base = p.Position
	local age = 0
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			local u = clampT(age / 0.9)
			p.Position = base + V(0, 3.5 * (1 - (1 - u) ^ 2), 0) + drift * u
			sc.Scale = if age < 0.15 then 0.4 + 0.75 * (age / 0.15) else 1
			local fade = clampT((age - 0.55) / 0.35)
			l.TextTransparency = fade
			st.Transparency = fade
		end,
	})
end

-- Un coup sur la vitre (Config/Shatter, ShatterController) : 8 à 26 éclats vers le casseur, 24 étincelles, poussière,
-- éclair, chiffre de dégâts, barre de PV. towards = point du casseur.
function R.glassHit(S, target: Instance, hitPos: Vector3, towards: Vector3, dmg: number, hp: number, max: number, bar)
	local folder = fxFolder()
	local dir = (towards - hitPos) * V(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else V(0, 0, 1)
	local chips = {}
	for _ = 1, math.random(8, 26) do
		local c = Instance.new("Part")
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
		c.Material = Enum.Material.Glass
		c.Color = GLASS
		c.Transparency = 0.25
		local s = 0.12 + math.random() * 0.25
		c.Size = V(s, s * (0.6 + math.random()), 0.05)
		c.CFrame = CFrame.new(hitPos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		c.Parent = folder
		local toward = math.random() < 0.85
		local side = V(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		local v = (if toward then dir else -dir) * (6 + math.random() * 7) + side * 6
		table.insert(chips, { part = c, v = v, w = V(math.random(), math.random(), math.random()) * 12 })
	end
	local floorY = T.ground(hitPos + dir * 2)
	local age = 0
	-- étincelles et poussière : émetteurs posés sur une pièce invisible
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = V(0.3, 0.3, 0.3)
	a.Position = hitPos
	a.Parent = folder
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = sparkleTex
	sp.Rate = 0
	sp.Lifetime = NumberRange.new(0.25, 0.6)
	sp.Speed = NumberRange.new(4, 11)
	sp.SpreadAngle = Vector2.new(60, 60)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sp.LightEmission = 1
	sp.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	sp.Acceleration = V(0, -12, 0)
	sp.EmissionDirection = Enum.NormalId.Front
	sp.Parent = a
	a.CFrame = CFrame.lookAt(hitPos, hitPos + dir)
	sp:Emit(24)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1, 3)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	dust.Parent = a
	dust:Emit(4)
	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 10
	light.Color = Color3.fromRGB(220, 240, 255)
	light.Parent = a
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			light.Brightness = 4 * (1 - clampT(age / 0.18))
			local fade = clampT((age - 1.4) / 0.5)
			for _, c in chips do
				c.v -= V(0, 45 * dt, 0)
				local pos = c.part.Position + c.v * dt
				if pos.Y < floorY + 0.05 then
					pos = V(pos.X, floorY + 0.05, pos.Z)
					c.v = c.v * V(0.4, -0.2, 0.4)
				end
				c.part.CFrame = CFrame.new(pos) * c.part.CFrame.Rotation * CFrame.Angles(c.w.X * dt, c.w.Y * dt, c.w.Z * dt)
				c.part.Transparency = 0.25 + 0.75 * fade
			end
		end,
	})
	R.damageNumber(S, hitPos, dmg)
	if bar then R.setHp(bar, hp, max) end
	-- le verre sonne de plus en plus aigu (Shatter : 0,9 à pleins PV, 1,35 à 0)
	R.sfx(S, "Glass_Hit", 0, 1)
end

-- La casse (Config/Shatter.Break) : arrêt sur image 0,06 s, flash blanc, « SMASHED! », éclats, sons.
function R.smash(S, target: Model, hitter, opts)
	opts = opts or {}
	local f = T.fx.breakWindow(target, { speed = opts.speed or 0.7, normal = opts.normal, fadeAt = 1.5, fadeDur = 1.2 })
	table.insert(S.fx, f)
	if hitter then
		for _, tr in hitter.tracks do
			if tr.IsPlaying then
				local sp = tr.Speed
				tr:AdjustSpeed(0)
				task.delay(0.06 * (S.shot.slow or 1), function() tr:AdjustSpeed(sp) end)
			end
		end
	end
	R.flash(S, 0.08, 0.85)
	R.popText(S, { text = "SMASHED!", pos = UDim2.fromScale(0.5, 0.42), size = UDim2.fromScale(0.7, 0.16), rot = -4 })
	R.sfx(S, "Glass_BreakThud")
	R.sfx(S, "Glass_BreakShatter")
	R.sfx(S, "Glass_BreakDebris", 0.45)
	S.breakAt = S.t
end

------------------------------------------------------------------------------------------------
-- Colis : saut au sol, actions, révélation
------------------------------------------------------------------------------------------------
-- Actions d'ouverture (Config/Unbox, tableau des actions) : animation, accessoire, durée, fraction de l'impact, sons
R.ACTIONS = {
	Hammer = { anim = "Unbox_Hammer", tool = "TOOL_Unbox_Sledgehammer", dur = 0.6, hit = 0.55, sfx = { { "Unbox_Windup", 0 }, { "Unbox_Swing", 0.2 }, { "Unbox_HammerHit", 0.33 } } },
	Crowbar = { anim = "Unbox_Crowbar", tool = "TOOL_Unbox_Crowbar", dur = 1.25, hit = 0.75, sfx = { { "Unbox_CrowbarWedge", 0 }, { "Unbox_CrowbarCreak", 0.4 }, { "Unbox_CrowbarCrack", 0.9 } } },
	Kick = { anim = "Unbox_Kick", tool = nil, dur = 0.8, hit = 0.45, sfx = { { "Unbox_KickWhoosh", 0.1 }, { "Unbox_Kick", 0.36 }, { "Unbox_BoxSlide", 0.42 } } },
	Saw = { anim = "Unbox_Saw", tool = "TOOL_Unbox_Saw", dur = 1.25, hit = 0.7, sfx = { { "Unbox_Saw", 0 } } },
	Drill = { anim = "Unbox_Drill", tool = "TOOL_Unbox_Drill", dur = 1.2, hit = 0.75, sfx = { { "Unbox_Drill", 0 }, { "Unbox_DrillThrough", 0.85 } } },
}

local function unboxTool(actor, name: string?)
	if actor.held then
		actor.held.model:Destroy()
		actor.held = nil
	end
	if not name then return end
	local src = Assets.Unbox:FindFirstChild(name)
	if not src then return end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	m.Parent = props()
	actor.held = { model = m, grip = CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.45, 0) }
end

local function emitFx(name: string, cf: CFrame, n: number?)
	return T.fx.emit(name, cf, n)
end

-- Compose une ouverture de colis jouée par update. spec = {
--   actor, box (Model posé sur le rayon), slot (Vector3 du rayon), aisle (Vector3 : direction de l'allée),
--   itemId, kg, actions = { "Kick", "Crowbar", "Hammer" }, odds = nombre (1 IN N), t0 = instant de l'appui sur E }
-- Rend un objet { update = function(S, t) }.
function R.unbox(spec)
	local U = { spec = spec, done = {} }
	local floor = spec.slot + spec.aisle.Unit * 4.5
	floor = V(floor.X, T.ground(floor) , floor.Z)
	local boxStart = spec.box:GetPivot()
	local timeline = {}
	local t = spec.t0 + 0.3 -- maintien de E (Commun 0,3 s)
	table.insert(timeline, { at = t, kind = "jump" })
	t += 0.6 + 0.25
	local sides = spec.sides or { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1) } -- côté, autre côté, devant
	for i, a in spec.actions do
		local act = R.ACTIONS[a]
		table.insert(timeline, { at = t, kind = "action", name = a, side = sides[(i - 1) % #sides + 1] })
		t += act.dur + 0.25
	end
	table.insert(timeline, { at = t, kind = "burst" })
	t += 0.35
	local rarOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
	local target = Items.ById[spec.itemId].Rarity
	for _, r in rarOrder do
		table.insert(timeline, { at = t, kind = "silhouette", rarity = r })
		t += 0.45
		if r == target then break end
	end
	table.insert(timeline, { at = t, kind = "reveal" })
	U.revealAt = t
	U.landAt = t + 1.6
	U.timeline = timeline
	U.floor = floor

	function U.update(S, now)
		local actor = spec.actor
		for i, ev in timeline do
			if now >= ev.at and not U.done[i] then
				U.done[i] = true
				if ev.kind == "jump" then
					U.jumpAt = ev.at
					R.sfx(S, "Unbox_BoxSlide", 0.45)
				elseif ev.kind == "action" then
					local act = R.ACTIONS[ev.name]
					-- le joueur se téléporte à côté du colis dans un petit nuage
					emitFx("FX_Unbox_Puff", CFrame.new(actor.cf.Position))
					local side = ev.side
					local p = floor + side * 3.2
					actor:place(p, floor - p)
					emitFx("FX_Unbox_Puff", CFrame.new(actor.cf.Position))
					unboxTool(actor, act.tool)
					for _, tr in actor.tracks do if tr.IsPlaying then tr:Stop(0.05) end end
					local tr = actor:play(act.anim, { looped = false, fade = 0.05 })
					U.cur = { ev = ev, act = act, tr = tr }
					for _, s in act.sfx do R.sfx(S, s[1], s[2]) end
					R.sfx(S, "Unbox_Rattle", act.dur)
					U.hitAt = ev.at + act.dur * act.hit
					U.hitDone = false
				elseif ev.kind == "burst" then
					unboxTool(actor, nil)
					spec.box:PivotTo(CFrame.new(0, -1000, 0))
					emitFx("FX_Unbox_Burst", CFrame.new(floor + V(0, 1, 0)))
					R.sfx(S, "Unbox_Burst")
					R.sfx(S, "Unbox_Smoke")
					local away = (actor.cf.Position - floor) * V(1, 0, 1)
					if away.Magnitude > 0.01 then actor:place(actor.cf.Position + away.Unit * 2, -away) end
					actor:play("Idle", { fade = 0.1 })
					if U.oddsBB then U.oddsBB.Enabled = false end
				elseif ev.kind == "silhouette" then
					R.sfx(S, "Unbox_Silhouette")
					if ev.rarity == target then R.sfx(S, "Unbox_Suspense") end
					U.sil = ev
				elseif ev.kind == "reveal" then
					U.sil = nil
					if U.silModel then U.silModel:Destroy() U.silModel = nil end
					R.flash(S, 0.1, 0.9)
					emitFx("FX_Unbox_Reveal", CFrame.new(floor + V(0, 1, 0)))
					R.sfx(S, "Unbox_UpgradePop")
					R.sfx(S, "Unbox_Confetti", 0.1)
					local r = Items.ById[spec.itemId].Rarity
					R.sfx(S, if r == "Common" or r == "Uncommon" or r == "Rare" then "Reveal_RarityLow" elseif r == "Epic" then "Reveal_RarityMid" else "Reveal_RarityHigh", 0.15)
					R.sfx(S, "Reveal_GrowSmall", 0.2)
					R.sfx(S, "Reveal_Land", 1.6)
				end
			end
		end
		-- saut du colis : arc de 0,6 s, bond de 2 studs
		if U.jumpAt and now < U.jumpAt + 0.6 + 1e-3 then
			local u = clampT((now - U.jumpAt) / 0.6)
			local from = boxStart.Position
			local _, size = spec.box:GetBoundingBox()
			local to = floor + V(0, size.Y / 2, 0)
			local pos = from:Lerp(to, u) + V(0, 2 * 4 * u * (1 - u), 0)
			spec.box:PivotTo(CFrame.new(pos) * boxStart.Rotation * CFrame.Angles(0, u * 1.2, 0))
		end
		-- impact d'une action : effet, colis écrasé et secoué, compteur de chances
		if U.cur and not U.hitDone and now >= U.hitAt then
			U.hitDone = true
			emitFx("FX_Unbox_Hit", CFrame.new(floor + V(0, 1, 0)))
			U.squashAt = now
			U.hits = (U.hits or 0) + 1
			U.odds = math.max(U.odds or 2, math.floor(2 + (spec.odds - 2) * U.hits / (#spec.actions + 1)))
			if not U.oddsBB then
				local a = Instance.new("Attachment")
				a.Parent = workspace.Terrain
				a.WorldPosition = floor + V(0, 4.5, 0)
				U.oddsAtt = a
				table.insert(T._restore, function() a:Destroy() end)
				local bb = UIA.BB_UnboxOdds:Clone()
				bb.Adornee = a
				bb.Parent = a
				local up = bb:FindFirstChild("Upgrade", true)
				if up then up.Visible = false end
				local rl = bb:FindFirstChild("Rarity", true)
				if rl then setRarity(rl, Rarities.ById[target]) end
				U.oddsBB = bb
			end
			local ol = U.oddsBB:FindFirstChild("Odds", true)
			if ol then ol.Text = "1 IN " .. Format.short(U.odds) end
			R.sfx(S, "UI_Click")
		end
		if U.squashAt and spec.box:GetPivot().Y > -500 then
			local k = now - U.squashAt
			local amp = if k < 0.25 then (1 - k / 0.25) * 0.25 else 0
			local _, size = spec.box:GetBoundingBox()
			spec.box:PivotTo(CFrame.new(floor + V(0, size.Y / 2, 0)) * boxStart.Rotation * CFrame.Angles(math.sin(k * 60) * amp, 1.2, math.cos(k * 50) * amp))
		end
		-- silhouette noire de l'objet de la rareté en cours (la dernière est le vrai objet)
		if U.sil then
			if not U.silModel or U.silModel:GetAttribute("_R") ~= U.sil.rarity then
				if U.silModel then U.silModel:Destroy() end
				local pool = {}
				for id, it in Items.ById do
					if it.Rarity == U.sil.rarity and Assets.Items:FindFirstChild("ITM_" .. id, true) then table.insert(pool, id) end
				end
				local id = if U.sil.rarity == target then spec.itemId else pool[math.random(1, math.max(1, #pool))]
				local src = id and Assets.Items:FindFirstChild("ITM_" .. id, true)
				if src then
					local m = src:Clone()
					for _, d in m:GetDescendants() do
						if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
					end
					local _, size = m:GetBoundingBox()
					local n = 0
					for _, r in rarOrder do n += 1 if r == U.sil.rarity then break end end
					m:ScaleTo(m:GetScale() * 2.4 * (1.12 ^ (n - 1)) / math.max(size.X, size.Y, size.Z))
					m:PivotTo(CFrame.new(floor + V(0, 0.4, 0)))
					local hl = Assets.FX:FindFirstChild("FX_Unbox_Silhouette")
					if hl then
						local h = hl:Clone()
						h.Adornee = m
						h.Parent = m
					end
					m:SetAttribute("_R", U.sil.rarity)
					m.Parent = fxFolder()
					U.silModel = m
				end
			end
			if U.silModel and U.sil.rarity == target then
				local k = now - U.sil.at
				U.silModel:PivotTo(CFrame.new(floor + V(0, 0.4, 0) + V(math.sin(k * 70), 0, math.cos(k * 63)) * 0.07))
			end
		end
		-- révélation : l'objet grandit de ×2 à sa taille en 0,8 s, étiquette BB_Reveal ; puis il se pose sur la tête
		if now >= U.revealAt and not U.landed then
			if not U.item then
				local info = R.info(spec.itemId, spec.kg)
				local m = T.fx.prop(S, "_reveal_" .. spec.itemId, "Items", "ITM_" .. spec.itemId)
				U.item, U.info = m, info
				m:ScaleTo(2) -- il sort à ×2 (Config/Reveal)
				R.outline(m)
				local cf, size = m:GetBoundingBox()
				pcall(RarityHalo.AddDisplayed, m, info.rarity, cf, size)
				local a = Instance.new("Attachment")
				a.Parent = workspace.Terrain
				U.revAtt = a
				table.insert(T._restore, function() a:Destroy() end)
				local bb = R.label("BB_Reveal", a, info, { Odds = "1 IN " .. Format.short(spec.odds) })
				U.revBB = bb
				table.insert(T._restore, function() bb:Destroy() end)
				if U.oddsBB then U.oddsBB.Enabled = false end
			end
			local u = clampT((now - U.revealAt) / 0.8)
			local s = 2 + (U.info.scale - 2) * (1 - (1 - u) ^ 3)
			U.item:ScaleTo(math.max(0.2, s))
			U.item:PivotTo(CFrame.new(floor) * CFrame.Angles(0, (now - U.revealAt) * 0.8, 0))
			local cf, size = U.item:GetBoundingBox()
			U.revAtt.WorldPosition = cf.Position + V(0, size.Y / 2 + 1.2, 0)
			if now >= U.landAt then
				U.landed = true
				U.item:PivotTo(CFrame.new(0, -1000, 0))
				if U.revBB then U.revBB.Enabled = false end
				R.carry(actor, spec.itemId, spec.kg)
				actor:play("CarryIdle", { fade = 0.1 })
			end
		end
	end
	return U
end

------------------------------------------------------------------------------------------------
-- Poursuite et capture
------------------------------------------------------------------------------------------------
R.SHOUTS = { "STOP RIGHT THERE!", "THIEF!", "COME BACK HERE!", "FREEZE!", "GIVE IT BACK!", "STOP NOW!" } -- Config/ChaseFeel

-- Vigile en poursuite : surligné en rouge (HeistFeel), bulle BB_GuardShout toutes les 2,4 s.
function R.chaser(S, guard)
	local h = guard.model:FindFirstChild("_Chase") or Instance.new("Highlight")
	h.Name = "_Chase"
	h.FillColor = Color3.fromRGB(255, 40, 40)
	h.FillTransparency = 0.6
	h.OutlineColor = Color3.fromRGB(255, 40, 40)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = guard.model
	h.Parent = guard.model
	table.insert(T._restore, function() h:Destroy() end)
	local head = guard.model:FindFirstChild("Head")
	local bb = UIA.BB_GuardShout:Clone()
	bb.Adornee = head
	bb.Parent = props()
	table.insert(T._restore, function() bb:Destroy() end)
	local label = bb:FindFirstChild("ShoutLabel", true)
	local age, k = 0, 0
	if label then label.Text = R.SHOUTS[1] end
	table.insert(S.fx, {
		step = function(dt)
			age += dt
			local n = math.floor(age / 2.4)
			if n ~= k and label then
				k = n
				label.Text = R.SHOUTS[(n % #R.SHOUTS) + 1]
				if n % 2 == 1 then R.sfx(S, "Guard_Radio") end
			end
			bb.Enabled = (age % 2.4) < 1.6
		end,
	})
end

-- Début de poursuite (écran du voleur) : sons et écran RUN!
function R.chaseStart(S)
	R.sfx(S, "Heist_Grab")
	R.sfx(S, "Chase_Whistle", 0.5)
	R.runScreen(S)
end

-- Capture : « CAUGHT! » en tampon (de ×1,6 à ×1, penché de -5°), sons.
function R.caught(S)
	R.hideRun()
	R.popText(S, { text = "CAUGHT!", pos = UDim2.fromScale(0.5, 0.4), size = UDim2.fromScale(0.5, 0.14), rot = -5, from = 1.6, pop = 0.14, hold = 1.2, hide = 0.2 })
	R.sfx(S, "Catch_Impact")
	R.sfx(S, "Catch_Slam", 0.1)
	R.sfx(S, "Knockdown_Land", 0.35)
end

------------------------------------------------------------------------------------------------
-- Étiquettes dans un plan tourné (9:16) : une BillboardGui reste alignée sur l'écran, donc couchée une fois l'image
-- redressée (vu le 2026-11-25 : barre « 1 / 15 » verticale). Son contenu est tourné de 90°, sa taille permutée, ses
-- décalages passés en repère monde ; la taille du contenu suit celle de l'étiquette à chaque image.
------------------------------------------------------------------------------------------------
local RunS = game:GetService("RunService")
R._rotated = R._rotated or {}
function R.rotBB(bb: BillboardGui): BillboardGui
	if bb:GetAttribute("_Rot") then return bb end
	local S = T.state
	if S and S.shot and S.shot.roll == false then return bb end
	bb:SetAttribute("_Rot", true)
	local s = bb.Size
	bb.Size = UDim2.new(s.Y.Scale, s.Y.Offset, s.X.Scale, s.X.Offset)
	bb.StudsOffsetWorldSpace += bb.StudsOffset
	bb.StudsOffset = Vector3.zero
	bb.ExtentsOffsetWorldSpace += bb.ExtentsOffset
	bb.ExtentsOffset = Vector3.zero
	local inner = Instance.new("Frame")
	inner.Name = "_RotInner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Rotation = 90
	inner.Size = UDim2.fromScale(1, 1)
	for _, c in bb:GetChildren() do c.Parent = inner end
	inner.Parent = bb
	table.insert(R._rotated, { bb = bb, inner = inner })
	return bb
end
pcall(function() RunS:UnbindFromRenderStep("_TrailerRotBB") end)
RunS:BindToRenderStep("_TrailerRotBB", Enum.RenderPriority.Last.Value + 103, function()
	local keep = {}
	for _, e in R._rotated do
		if e.bb.Parent and e.inner.Parent then
			local a = e.bb.AbsoluteSize
			e.inner.Size = UDim2.fromOffset(a.Y, a.X)
			table.insert(keep, e)
		end
	end
	R._rotated = keep
end)
-- les écrans se cachent pendant les noirs de synchro (vu le 2026-11-25 : les bords rouges de RUN! sur le noir ont collé
-- deux plans d'un lot au découpage)
pcall(function() RunS:UnbindFromRenderStep("_TrailerUIBlack") end)
RunS:BindToRenderStep("_TrailerUIBlack", Enum.RenderPriority.Last.Value + 104, function()
	local g = CG:FindFirstChild("_TrailerUI")
	if g then g.Enabled = T.root():FindFirstChild("_Black") == nil end
end)

-- toute étiquette ajoutée sous _TRAILER ou sur un Attachment du Terrain pendant un plan est tournée
if R._bbCon then R._bbCon:Disconnect() end
R._bbCon = workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BillboardGui") then
		local S = T.state
		if S and S.phase ~= "done" and (d:IsDescendantOf(T.root()) or d:IsDescendantOf(workspace.Terrain)) then
			task.defer(function() if d.Parent then R.rotBB(d) end end)
		end
	end
end)

------------------------------------------------------------------------------------------------
-- Nettoyage : T.stop retire les écrans ; chaque T.prepare remet à zéro le journal des sons du plan
------------------------------------------------------------------------------------------------
if not T._stopV1 then T._stopV1 = T.stop end
function T.stop()
	R.uiClear()
	return T._stopV1()
end
if not T._prepReal then T._prepReal = T.prepare end
function T.prepare(name)
	T.sfxLogs[name] = {}
	R.uiClear()
	local r = T._prepReal(name)
	T.sfxLogs[name] = {} -- setup et update(0) ne comptent pas
	return r
end

-- Journal des sons de tous les plans tournés, en JSON (pour mix_sfx.py)
function R.sfxJson(): string
	return game:GetService("HttpService"):JSONEncode(T.sfxLogs)
end

return "couche vrai jeu chargée"
