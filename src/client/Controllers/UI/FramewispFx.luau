--!strict
-- FramewispFx (a298, 21/11 ; client) : les effets des boutons que Clément fait avec le plugin Figma Framewisp, rejoués
-- par notre code depuis les attributs que le plugin pose (« Tous », validé par Cantin, 21/11), pour que les 6 LocalScripts
-- du plugin (FramewispTextScaler, ButtonFX, Juice, Spin, Burst, Stroke) puissent quitter l'UI ; et le reflet du bouton
-- entier (« HUD et boutons d'achat », validé par Cantin, 21/11). Module frère de UiAttrFx, appelé par UiAttrFx.Wire sur
-- chaque GuiObject des écrans UI_* (UiFeelController) ; sa boucle d'image est celle d'UiAttrFx (une seule Heartbeat).
-- Derrière Features.UiAttrFx et Features.FramewispFx ; valeurs du plugin dans Config/UiMotion.AttrFx.Framewisp et
-- ButtonSheen. Un attribut posé par Clément gagne toujours : le nom sans préfixe (SpinSpeed), puis Figma* (FigmaSpinSpeed).
--
--   FigmaSpin            l'élément tourne de SpinSpeed degrés par seconde (Sunburst).
--   FigmaWiggle          toutes les WiggleEvery s, un balancement amorti de ± WiggleAngle degrés (Icon).
--   FigmaLean            au survol du bouton qui le contient, l'élément penche de LeanAngle degrés (Back Out).
--   FigmaBurst           au clic (Motion.Activated : toute la zone du bouton, a290) ou quand l'attribut Burst change,
--                        des éclats (l'image de l'enfant FigmaBurstImg, sinon des ronds) partent du bord, dans un
--                        calque <nom>_Burst posé sous le bouton, détruit quand le dernier éclat a fini.
--   FigmaGleam           le reflet : des copies blanches FW_GleamShine (halo et cœur) du texte, de l'image (sa
--                        silhouette <nom>_Sheen) ou du fond, où passe une bande penchée. Sur un groupe (ou sur un bouton
--                        sans texte ni image, comme les racines des 4 boutons), chaque pièce du groupe a ses copies et la
--                        même bande les traverse toutes.
--   FigmaStroke          le UIGradient de chaque UIStroke de l'élément tourne (mode 0 du plugin).
--   FW_Owned (bouton)    sans FigmaSmooth : images (sinon textes) assombries au survol et à l'appui ; un calque
--                        FigmaNoDim ou dont le nom finit par _nodim garde sa couleur. Avec FigmaSmooth (les 4 boutons),
--                        le plugin grossit le bouton par son UIScale FW_Scale : c'est Motion.Button qui le fait ici
--                        (survol, appui, écrasement), FW_Scale n'est ni créé ni lu (pas de double échelle).
--   Reflet entier        (SheenFx) boutons des rails du HUD, boutons qui ont un UIGradient Gleam, boutons d'achat de la
--                        boutique Robux : une copie blanche du fond (avec son UICorner) où une bande douce passe en boucle.
-- Pas de double effet : un LocalScript ou Script dont le nom commence par Framewisp dans l'écran : rien de Figma* ici
-- pour cet écran (une ligne en Studio). Tout s'arrête quand l'élément n'est pas affiché ou avec « animations réduites »,
-- et revient à l'état de Clément (Rotation, Offset des dégradés, couleurs ; copies cachées ; éclats détruits). Un
-- enfant qui manque : rien, une ligne dans la sortie en Studio.
--
-- API (client) :
--   FramewispFx.Wire(object)          branche cet élément (une fois ; sans effet sans réglage)
--   FramewispFx.Step(now, still)      une image (boucle d'UiAttrFx)
--   FramewispFx.Count() -> number     effets qui demandent la boucle d'image
--   FramewispFx.SetChanged(fn)        fn appelée quand Count peut avoir changé (UiAttrFx branche ou coupe sa boucle)
--   FramewispFx.GetState()            compteurs (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Features = require(Config:WaitForChild("Features"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local FW = UiMotion.AttrFx.Framewisp
local SHEEN = UiMotion.AttrFx.ButtonSheen
local GLEAM_GRADIENT = UiMotion.AttrFx.GleamGradient.Name
local GLEAM_OVERLAY = UiMotion.AttrFx.Gleam.Name
local WHITE = Color3.new(1, 1, 1)
local IS_STUDIO = RunService:IsStudio()
local ENABLED = Features.FramewispFx == true
local SHEEN_ON = SHEEN.Enabled == true
local LEAN_STYLE = FW.Lean.Style
local SHEEN_SUFFIX = "_Sheen"

type Turn = { object: GuiObject, rest: number, spin: number, wiggle: number, lean: number, applied: boolean }
type Loop = { object: GuiObject, turn: Turn, since: number? } -- Spin et Wiggle
type Lean = { object: GuiObject, turn: Turn, from: number, to: number, at: number?, time: number }
type Bit = {
	frame: GuiObject,
	image: boolean,
	born: number,
	wait: number,
	life: number,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	W: number,
	H: number,
	size: number,
	a0: number,
	shrink: boolean,
	rot0: number,
	spin: number,
}
type Burst = { object: GuiObject, layer: Frame?, bits: { Bit } }
type Copy = { frame: GuiObject, gradient: UIGradient }
type Part = { piece: GuiObject, copies: { Copy } }
type Gleam = {
	object: GuiObject,
	group: boolean,
	parts: { Part }?,
	dirty: boolean,
	since: number?,
	live: boolean,
}
type Stroke = {
	object: GuiObject,
	gradient: UIGradient,
	made: boolean,
	rotation: number,
	offset: Vector2,
	since: number?,
	moving: boolean,
}
type DimTarget = { inst: GuiObject, prop: string, base: Color3, own: number }
type Dim = { button: GuiButton, targets: { DimTarget }, over: boolean, held: boolean, level: number }
type Sheen = { button: GuiButton, host: GuiObject, copy: Frame, gradient: UIGradient, phase: number, since: number? }

local FramewispFx = {}

local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local scriptScreens: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local turns: { [GuiObject]: Turn } = {}
local spins: { Loop } = {}
local wiggles: { Loop } = {}
local leans: { Lean } = {}
local bursts: { Burst } = {}
local gleams: { Gleam } = {}
local strokes: { Stroke } = {}
local dims: { Dim } = {}
local sheens: { Sheen } = {}
local skipped = 0
local liveBits = 0
local reported: { [string]: boolean } = {}
local random = Random.new()
local changed: () -> () = function() end

local function report(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(`[FramewispFx] {message}`)
	end
end

local function screenOf(object: Instance): Instance?
	local current: Instance? = object.Parent
	while current ~= nil do
		if current:IsA("LayerCollector") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- L'élément se voit : lui et ses parents Visible, dans un écran allumé du PlayerGui (comme UiAttrFx).
local function shown(object: GuiObject): boolean
	local current: Instance? = object
	while current ~= nil do
		if current:IsA("LayerCollector") then
			return (current :: any).Enabled == true and current:FindFirstAncestorOfClass("PlayerGui") ~= nil
		end
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		current = current.Parent
	end
	return false
end

local function reduced(): boolean
	local ok, value = pcall(Motion.IsReduced)
	return ok and value == true
end

-- Réglage du plugin : l'attribut sans préfixe d'abord (posé par Clément), puis Figma<nom>, sinon la valeur par défaut.
local function number(object: Instance, name: string, default: number): number
	local value = object:GetAttribute(name)
	if type(value) ~= "number" or value ~= value then
		value = object:GetAttribute("Figma" .. name)
	end
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return value
end

local function clamped(object: Instance, name: string, default: number, low: number, high: number): number
	return math.clamp(number(object, name, default), low, high)
end

local function flag(object: Instance, name: string): boolean
	local value = object:GetAttribute("Figma" .. name)
	return value ~= nil and value ~= false and value ~= 0
end

local function gleamGradientInside(object: Instance): boolean
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("UIGradient") and descendant.Name == GLEAM_GRADIENT then
			return true
		end
	end
	return false
end

local function laidOut(parent: Instance?): boolean
	return parent ~= nil
		and (parent:FindFirstChildWhichIsA("UIGridLayout") ~= nil or parent:FindFirstChildWhichIsA("UIListLayout") ~= nil
			or parent:FindFirstChildWhichIsA("UITableLayout") ~= nil or parent:FindFirstChildWhichIsA("UIPageLayout") ~= nil)
end

local function buttonAround(object: GuiObject, includeSelf: boolean): GuiButton?
	local current: Instance? = if includeSelf then object else object.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("GuiButton") then
			return current :: GuiButton
		end
		current = current.Parent
	end
	return nil
end

local function forget<T>(list: { T }, entry: T)
	local index = table.find(list, entry)
	if index then
		table.remove(list, index)
	end
	changed()
end

-- Un LocalScript ou Script du plugin encore dans l'écran : il joue lui-même ses effets, on ne les double pas.
local function pluginScriptIn(object: GuiObject): boolean
	local screen = screenOf(object)
	if screen == nil then
		return false
	end
	local cached: boolean? = scriptScreens[screen]
	if cached == nil then
		local found = false
		for _, descendant in screen:GetDescendants() do
			if (descendant.ClassName == "LocalScript" or descendant.ClassName == "Script")
				and string.sub(descendant.Name, 1, #FW.ScriptPrefix) == FW.ScriptPrefix then
				found = true
				break
			end
		end
		scriptScreens[screen] = found
		if found then
			skipped += 1
			report(`script:{screen:GetFullName()}`, `{screen:GetFullName()} a encore un script {FW.ScriptPrefix}* : ses effets Figma* ne sont pas rejoués par le code (le script les joue)`)
		end
		return found
	end
	return cached
end

------------------------------------------------------------------------------
-- Rotation : Spin, Wiggle et Lean s'ajoutent à la Rotation de Clément
------------------------------------------------------------------------------

local function turnOf(object: GuiObject): Turn
	local turn = turns[object]
	if turn == nil then
		local created: Turn = { object = object, rest = object.Rotation, spin = 0, wiggle = 0, lean = 0, applied = false }
		turns[object] = created
		Motion.SetRest(object, object.Position, object.Rotation)
		object.Destroying:Connect(function()
			turns[object] = nil
		end)
		return created
	end
	return turn
end

local function applyTurn(turn: Turn)
	local total = turn.spin + turn.wiggle + turn.lean
	if total ~= 0 then
		if not turn.applied then
			turn.applied = true
			turn.rest = turn.object.Rotation
		end
		turn.object.Rotation = turn.rest + total
	elseif turn.applied then
		turn.applied = false
		turn.object.Rotation = turn.rest
	end
end

local function wireLoop(list: { Loop }, object: GuiObject)
	local entry: Loop = { object = object, turn = turnOf(object), since = nil }
	table.insert(list, entry)
	object.Destroying:Connect(function()
		forget(list, entry)
	end)
	changed()
end

local function stepSpins(now: number, still: boolean)
	for _, entry in spins do
		if still or not shown(entry.object) then
			entry.since = nil
			entry.turn.spin = 0
		else
			local since: number = entry.since or now
			entry.since = since
			entry.turn.spin = (number(entry.object, "SpinSpeed", FW.Spin.Speed) * (now - since)) % 360
		end
	end
end

local function stepWiggles(now: number, still: boolean)
	local time = FW.Wiggle.Time
	for _, entry in wiggles do
		if still or not shown(entry.object) then
			entry.since = nil
			entry.turn.wiggle = 0
			continue
		end
		local since: number = entry.since or now
		entry.since = since
		local object = entry.object
		local phase = (now - since) % (number(object, "WiggleEvery", FW.Wiggle.Every) + time)
		if phase < time then
			local p = phase / time
			entry.turn.wiggle = math.sin(p * math.pi * 2 * FW.Wiggle.Shakes) * number(object, "WiggleAngle", FW.Wiggle.Angle) * (1 - p)
		else
			entry.turn.wiggle = 0
		end
	end
end

local function leanValue(entry: Lean, now: number): number
	local at = entry.at
	if at == nil then
		return entry.to
	end
	local t = if entry.time > 0 then (now - at) / entry.time else 1
	if t >= 1 then
		entry.at = nil
		return entry.to
	end
	local eased = TweenService:GetValue(math.max(t, 0), LEAN_STYLE, Enum.EasingDirection.Out)
	return entry.from + (entry.to - entry.from) * eased
end

local function leanActive(entry: Lean): boolean
	return entry.at ~= nil or entry.to ~= 0 or entry.turn.lean ~= 0
end

local function stepLeans(now: number, still: boolean)
	for _, entry in leans do
		if still or not shown(entry.object) then
			entry.from, entry.to, entry.at = 0, 0, nil
			entry.turn.lean = 0
		else
			entry.turn.lean = leanValue(entry, now)
		end
	end
end

local function wireLean(object: GuiObject)
	local card = buttonAround(object, false)
	if card == nil then
		report(`Lean:none:{object.Name}`, `FigmaLean sur {object:GetFullName()} : aucun bouton autour, rien ne penche (comme dans le plugin)`)
		return
	end
	local source = card :: GuiButton
	local entry: Lean = { object = object, turn = turnOf(object), from = 0, to = 0, at = nil, time = 0 }
	local function lean(target: number)
		local now = os.clock()
		entry.from = leanValue(entry, now)
		entry.to = target
		entry.time = math.max(0, number(object, "LeanTime", FW.Lean.Time))
		entry.at = now
		changed()
	end
	source.MouseEnter:Connect(function()
		if not reduced() and Motion.IsOnTop(source) then
			lean(number(object, "LeanAngle", FW.Lean.Angle))
		end
	end)
	source.MouseLeave:Connect(function()
		if entry.to ~= 0 then
			lean(0)
		end
	end)
	table.insert(leans, entry)
	object.Destroying:Connect(function()
		forget(leans, entry)
	end)
end

------------------------------------------------------------------------------
-- Burst : éclats au clic
------------------------------------------------------------------------------

local function rgb(value: number): Color3
	local n = math.floor(value)
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end

-- Le premier parent dont le parent ne range pas ses enfants : le calque va à côté de lui, sous le bouton.
local function anchorOf(object: GuiObject): GuiObject
	local anchor = object
	local parent = anchor.Parent
	while parent ~= nil and parent:IsA("GuiObject") and laidOut(parent) do
		anchor = parent :: GuiObject
		parent = anchor.Parent
	end
	return anchor
end

local function burstLayer(entry: Burst): Frame?
	local object = entry.object
	local anchor = anchorOf(object)
	local host = anchor.Parent
	if host == nil or laidOut(host) then
		return nil
	end
	local layer = entry.layer
	if layer == nil or layer.Parent ~= host then
		if layer then
			layer:Destroy()
		end
		local created = Instance.new("Frame")
		created.Name = object.Name .. FW.Burst.LayerSuffix
		created.BackgroundTransparency = 1
		created.BorderSizePixel = 0
		created.ClipsDescendants = false
		created.Active = false
		created.Selectable = false
		created.Parent = host
		layer = created
		entry.layer = created
	end
	local made = layer :: Frame
	made.ZIndex = anchor.ZIndex - 1 -- sous le bouton, comme le plugin
	-- Le calque prend la boîte du bouton : même parent, sa géométrie ; sinon mesurée à l'écran.
	if object.Parent == host then
		made.AnchorPoint = object.AnchorPoint
		made.Position = object.Position
		made.Size = object.Size
		made.Rotation = object.Rotation
		return made
	end
	if not host:IsA("GuiObject") and not host:IsA("LayerCollector") then
		return nil
	end
	local hostGui = host :: any
	local hp: Vector2 = hostGui.AbsolutePosition
	local hs: Vector2 = hostGui.AbsoluteSize
	if host:IsA("ScrollingFrame") then
		local canvas = (host :: ScrollingFrame).AbsoluteCanvasSize
		if canvas.X > 0 and canvas.Y > 0 then
			hp -= (host :: ScrollingFrame).CanvasPosition
			hs = canvas
		end
	end
	if hs == nil or hs.X < 1 or hs.Y < 1 then
		return nil
	end
	local ep, es = object.AbsolutePosition, object.AbsoluteSize
	made.AnchorPoint = Vector2.new(0, 0)
	made.Rotation = 0
	made.Position = UDim2.fromScale((ep.X - hp.X) / hs.X, (ep.Y - hp.Y) / hs.Y)
	made.Size = UDim2.fromScale(es.X / hs.X, es.Y / hs.Y)
	return made
end

local function burstTemplate(object: GuiObject): ImageLabel?
	for _, child in object:GetChildren() do
		if child:IsA("ImageLabel") and child:GetAttribute("FigmaBurstImg") and child.Image ~= "" then
			return child
		end
	end
	return nil
end

local function paintBit(bit: Bit, now: number)
	local t = now - bit.born - bit.wait
	local p = math.min(1, math.max(0, t) / bit.life)
	local e = 1 - (1 - p) ^ 3 -- part vite, se pose doucement
	local x = bit.x0 + (bit.x1 - bit.x0) * e
	local y = bit.y0 + (bit.y1 - bit.y0) * e
	local g = if p < 0.12 then 0.35 + 0.65 * (p / 0.12) else 1
	if bit.shrink and p > 0.12 then
		g = math.max(0, 1 - ((p - 0.12) / 0.88) ^ 2)
	end
	local f = if p <= 0.4 then 0 else ((p - 0.4) / 0.6) ^ 1.5
	local transparency = if t < 0 then 1 else bit.a0 + (1 - bit.a0) * f
	local s = bit.size * g
	local frame = bit.frame
	frame.Position = UDim2.fromScale(x / bit.W, y / bit.H)
	frame.Size = UDim2.fromScale(s / bit.W, s / bit.H)
	frame.Rotation = bit.rot0 + bit.spin * math.max(t, 0)
	if bit.image then
		(frame :: ImageLabel).ImageTransparency = transparency
	else
		frame.BackgroundTransparency = transparency
	end
end

local function clearBurst(entry: Burst)
	for _, bit in entry.bits do
		bit.frame:Destroy()
	end
	liveBits -= #entry.bits
	table.clear(entry.bits)
	local layer = entry.layer
	if layer then
		entry.layer = nil
		layer:Destroy()
	end
end

local function emit(entry: Burst)
	local el = entry.object
	if reduced() or not shown(el) then
		return
	end
	local W, H = el.AbsoluteSize.X, el.AbsoluteSize.Y
	if W < 1 or H < 1 then
		return
	end
	local layer = burstLayer(entry)
	if layer == nil then
		report(`Burst:layer:{el.Name}`, `FigmaBurst sur {el:GetFullName()} : pas de place pour le calque des éclats (parent rangé par un layout), rien ne part`)
		return
	end
	local B = FW.Burst
	local k = W / math.max(1, number(el, "BurstW", W)) -- px d'écran par px de maquette
	local count = math.floor(clamped(el, "BurstCount", B.Count, 1, 200) + 0.5)
	local life = clamped(el, "BurstTime", B.Time, 0.05, 10)
	local reach = clamped(el, "BurstDist", B.Dist, 0, 10) * math.min(W, H)
	local a0 = clamped(el, "BurstAlpha", B.Alpha, 0, 0.95)
	local sMin = clamped(el, "BurstSize", B.Size, 1, 500)
	local sMax = math.max(sMin, clamped(el, "BurstSizeMax", B.SizeMax, 1, 500))
	local shrink = clamped(el, "BurstShrink", B.Shrink, 0, 1) >= 0.5
	local spin = 0
	if clamped(el, "BurstSpin", B.Spin, 0, 1) >= 0.5 then
		spin = clamped(el, "BurstSpinSpeed", B.SpinSpeed, 0, 3600)
	end
	local colour = rgb(clamped(el, "BurstColor", B.Color, 0, 16777215))
	local scatter = clamped(el, "BurstRandom", B.Random, 0, 1) >= 0.5
	local template = burstTemplate(el)
	local phase = random:NextNumber() * math.pi * 2
	local born = os.clock()
	for i = 1, count do
		if liveBits >= B.MaxLive then
			break
		end
		local x0, y0, x1, y1, wait = 0, 0, 0, 0, 0
		if scatter then
			-- Des points au hasard sur le bord, ± 40° de sa normale ; un tiers tout de suite, le reste en filet.
			local r = random:NextNumber() * 2 * (W + H)
			local ex, ey, nx, ny
			if r < W then
				ex, ey, nx, ny = r, 0, 0, -1
			elseif r < W + H then
				ex, ey, nx, ny = W, r - W, 1, 0
			elseif r < 2 * W + H then
				ex, ey, nx, ny = W - (r - W - H), H, 0, 1
			else
				ex, ey, nx, ny = 0, H - (r - 2 * W - H), -1, 0
			end
			local tilt = (random:NextNumber() - 0.5) * 1.4
			local sdx = nx * math.cos(tilt) - ny * math.sin(tilt)
			local sdy = nx * math.sin(tilt) + ny * math.cos(tilt)
			local inset = 0.06 * math.min(W, H)
			local len = inset + reach * (0.7 + random:NextNumber() * 0.6)
			x0, y0 = ex - nx * inset, ey - ny * inset
			x1, y1 = x0 + sdx * len, y0 + sdy * len
			if i > math.ceil(count * 0.35) then
				wait = random:NextNumber() * 0.25 * life
			end
		else
			local th = phase + (i - 1 + random:NextNumber() * 0.6) / count * math.pi * 2
			local dx, dy = math.cos(th), math.sin(th)
			local edge = math.min((W / 2) / math.max(1e-6, math.abs(dx)), (H / 2) / math.max(1e-6, math.abs(dy)))
			local r0, r1 = edge * 0.8, edge + reach * (0.7 + random:NextNumber() * 0.6) -- né sous le bord, sort au-delà
			x0, y0 = W / 2 + dx * r0, H / 2 + dy * r0
			x1, y1 = W / 2 + dx * r1, H / 2 + dy * r1
		end
		local frame: GuiObject
		if template then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Fit
			image.Image = template.Image
			image.ImageRectOffset = template.ImageRectOffset
			image.ImageRectSize = template.ImageRectSize
			image.ImageColor3 = colour
			frame = image
		else
			local dot = Instance.new("Frame")
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = colour
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = dot
			frame = dot
		end
		frame.Name = B.BitName
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Active = false
		frame.ZIndex = layer.ZIndex
		local bit: Bit = {
			frame = frame,
			image = template ~= nil,
			born = born,
			wait = wait,
			life = life * (0.85 + random:NextNumber() * 0.3),
			x0 = x0,
			y0 = y0,
			x1 = x1,
			y1 = y1,
			W = W,
			H = H,
			size = (sMin + (sMax - sMin) * random:NextNumber()) * k,
			a0 = a0,
			shrink = shrink,
			rot0 = if template then random:NextNumber() * 360 else 0,
			spin = spin * (if random:NextNumber() < 0.5 then -1 else 1) * (0.7 + random:NextNumber() * 0.6),
		}
		paintBit(bit, born)
		frame.Parent = layer
		table.insert(entry.bits, bit)
		liveBits += 1
	end
	if #entry.bits == 0 then
		clearBurst(entry)
	end
	changed()
end

local function stepBursts(now: number, still: boolean)
	for _, entry in bursts do
		if #entry.bits == 0 then
			continue
		end
		local layer = entry.layer
		if still or layer == nil or layer.Parent == nil or not shown(entry.object) then
			clearBurst(entry)
			continue
		end
		for index = #entry.bits, 1, -1 do
			local bit = entry.bits[index]
			if now - bit.born - bit.wait >= bit.life or bit.frame.Parent ~= layer then
				bit.frame:Destroy()
				table.remove(entry.bits, index)
				liveBits -= 1
			else
				paintBit(bit, now)
			end
		end
		if #entry.bits == 0 then
			clearBurst(entry)
		end
	end
end

local function wireBurst(object: GuiObject)
	local entry: Burst = { object = object, layer = nil, bits = {} }
	table.insert(bursts, entry)
	local function fire()
		emit(entry)
	end
	local button = buttonAround(object, true)
	if button then
		Motion.Activated(button):Connect(fire) -- le clic sur toute la zone du bouton (a290)
	else
		object.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				fire()
			end
		end)
	end
	object:GetAttributeChangedSignal("Burst"):Connect(fire)
	object.Destroying:Connect(function()
		clearBurst(entry)
		forget(bursts, entry)
	end)
end

------------------------------------------------------------------------------
-- Gleam : le reflet du plugin (copies blanches FW_GleamShine)
------------------------------------------------------------------------------

-- La bande du plugin : épaules à 30 et 70 % ; avec peak, un halo plus doux.
local function gleamSequence(width: number, peak: number?, opacity: number?): NumberSequence
	local h = math.clamp(width * 0.5, 0.04, 0.46)
	local points: { { number } }
	if peak ~= nil then
		points = { { 0, 1 }, { 0.5 - h, 1 }, { 0.5, peak }, { 0.5 + h, 1 }, { 1, 1 } }
	else
		points = { { 0, 1 }, { 0.5 - h, 1 }, { 0.5 - h * 0.4, 0.45 }, { 0.5, 0 }, { 0.5 + h * 0.4, 0.45 }, { 0.5 + h, 1 }, { 1, 1 } }
	end
	local keypoints = {}
	for _, point in points do
		local value = point[2]
		if opacity ~= nil then
			value = 1 - (1 - value) * opacity
		end
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], value))
	end
	return NumberSequence.new(keypoints)
end

local function tiltFor(object: GuiObject, tilt: number, minAspect: number): number
	local box = object.AbsoluteSize
	return if box.Y >= box.X * minAspect then tilt else 0
end

local function silhouette(object: GuiObject): ImageLabel?
	local sheen = object:FindFirstChild(object.Name .. SHEEN_SUFFIX)
	if sheen and sheen:IsA("ImageLabel") and sheen.Image ~= "" then
		return sheen
	end
	return nil
end

local function isText(object: Instance): boolean
	return object:IsA("TextLabel") or object:IsA("TextButton")
end

local function isImage(object: Instance): boolean
	return object:IsA("ImageLabel") or object:IsA("ImageButton")
end

-- Texte blanc : les couleurs des balises font et stroke passent en blanc (texte riche).
local function whiteText(object: TextLabel | TextButton): string
	local text = object.Text
	if not object.RichText then
		return text
	end
	return (string.gsub(text, "<[^>]*>", function(tag: string): string
		local name = string.match(tag, "^<%s*(%a+)")
		if name and (string.lower(name) == "font" or string.lower(name) == "stroke") then
			return (string.gsub(tag, "(%s+[Cc][Oo][Ll][Oo][Rr]%s*=%s*)([\"'])(.-)%2", "%1%2#FFFFFF%2"))
		end
		return tag
	end))
end

local TEXT_SYNC = {
	"RichText", "FontFace", "TextWrapped", "TextSize", "TextScaled", "LineHeight", "TextXAlignment", "TextYAlignment",
	"MaxVisibleGraphemes", "TextTransparency",
}
local IMAGE_SYNC = { "ImageTransparency", "ScaleType", "SliceCenter", "SliceScale", "TileSize", "ImageRectOffset", "ImageRectSize" }

local function syncCopy(copy: GuiObject, source: GuiObject)
	if copy:IsA("TextLabel") and isText(source) then
		local label = copy :: TextLabel
		local text = whiteText(source :: any)
		if label.Text ~= text then
			label.Text = text
		end
		for _, property in TEXT_SYNC do
			local value = (source :: any)[property]
			if value ~= nil and (label :: any)[property] ~= value then
				(label :: any)[property] = value
			end
		end
	elseif copy:IsA("ImageLabel") and isImage(source) then
		local image = copy :: ImageLabel
		local sheen = silhouette(source)
		local wanted = if sheen then sheen.Image else (source :: ImageLabel).Image
		if image.Image ~= wanted then
			image.Image = wanted
		end
		for _, property in IMAGE_SYNC do
			local value = (source :: any)[property]
			if value ~= nil and (image :: any)[property] ~= value then
				(image :: any)[property] = value
			end
		end
	elseif copy:IsA("Frame") then
		copy.BackgroundTransparency = source.BackgroundTransparency
	end
end

-- Les deux copies blanches d'une pièce (halo puis cœur), comme gleamShine du plugin.
local function shine(source: GuiObject, width: number): { Copy }
	for _, child in source:GetChildren() do
		if child.Name == FW.Gleam.CopyName then
			child:Destroy()
		end
	end
	local G = FW.Gleam
	local tilt = tiltFor(source, G.Tilt, G.TiltMinAspect)
	local stroke = source:FindFirstChildWhichIsA("UIStroke")
	local text = isText(source)
	if isImage(source) and silhouette(source) == nil then
		report(`Gleam:sheen:{source.Name}`, `FigmaGleam : {source:GetFullName()} est une image sans sa silhouette {source.Name}{SHEEN_SUFFIX}, le reflet ne s'y voit pas (comme dans le plugin)`)
	end
	local copies: { Copy } = {}
	for _, layer in { { z = 1, width = width * G.HaloWidth, peak = G.HaloPeak :: number? }, { z = 2, width = width, peak = nil :: number? } } do
		local copy: GuiObject
		if text then
			local label = Instance.new("TextLabel")
			label.TextColor3 = WHITE
			label.TextStrokeTransparency = 1
			label.BackgroundTransparency = 1
			copy = label
		elseif isImage(source) then
			local image = Instance.new("ImageLabel")
			image.ImageColor3 = WHITE
			image.BackgroundTransparency = 1
			copy = image
		else
			local frame = Instance.new("Frame")
			frame.BackgroundColor3 = WHITE
			frame.BorderSizePixel = 0
			copy = frame
		end
		copy.Name = G.CopyName
		copy.Visible = false -- seulement pendant le passage : aucune copie au repos
		copy.Size = UDim2.fromScale(1, 1)
		copy.Position = UDim2.fromScale(0.5, 0.5)
		copy.AnchorPoint = Vector2.new(0.5, 0.5)
		copy.ZIndex = source.ZIndex + layer.z
		copy.Active = false
		local corner = source:FindFirstChildWhichIsA("UICorner")
		if corner then
			corner:Clone().Parent = copy
		end
		if stroke and text then
			-- Le contour des lettres, en blanc, sans ses dégradés (ils mesurent dans l'espace du contour).
			local white = (stroke :: UIStroke):Clone()
			for _, inner in white:GetChildren() do
				inner:Destroy()
			end
			white.Color = WHITE
			pcall(function()
				(white :: any).BorderStrokePosition = Enum.BorderStrokePosition.Outer
			end)
			white.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			white.Parent = copy
		end
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = gleamSequence(layer.width, layer.peak, nil)
		gradient.Rotation = tilt
		gradient.Offset = Vector2.new(-2, 0)
		gradient.Parent = copy
		syncCopy(copy, source)
		copy.Parent = source
		table.insert(copies, { frame = copy, gradient = gradient })
	end
	return copies
end

local function clearParts(entry: Gleam)
	for _, part in entry.parts or {} do
		for _, copy in part.copies do
			copy.frame:Destroy()
		end
	end
	entry.parts = nil
end

-- Une pièce du groupe : un descendant texte ou image, pas sous une copie, une silhouette ou un autre reflet.
local function isPart(owner: GuiObject, node: Instance): boolean
	local current: Instance? = node
	while current ~= nil and current ~= owner do
		local name = current.Name
		if name == FW.Gleam.CopyName or name == SHEEN.Name or name == GLEAM_OVERLAY
			or string.sub(name, -#SHEEN_SUFFIX) == SHEEN_SUFFIX or current:GetAttribute("FigmaBurstImg")
			or current:GetAttribute("FigmaSheen") or current:GetAttribute("FigmaGleam") then
			return false
		end
		current = current.Parent
	end
	return current == owner
end

local function collectParts(entry: Gleam): { Part }
	local root = entry.object
	local w0 = number(root, "GleamWidth", FW.Gleam.Width)
	local gw0 = math.max(1, root.AbsoluteSize.X)
	local found: { Part } = {}
	if gw0 <= 1 then
		return found
	end
	for _, node in root:GetDescendants() do
		local text = isText(node)
		if (text or isImage(node)) and isPart(root, node) and (node.Name ~= "Background" or silhouette(node :: GuiObject) ~= nil) then
			local piece = node :: GuiObject
			local dw = piece.AbsoluteSize.X
			local pad = piece:FindFirstChild("FW_TextPad")
			if pad and pad:IsA("UIPadding") then
				dw *= math.max(0, 1 - pad.PaddingLeft.Scale - pad.PaddingRight.Scale)
			end
			if dw > 0 and (text or dw < gw0 * 0.95 or silhouette(piece) ~= nil) then
				local width = math.clamp(w0 * gw0 / math.max(1, dw), FW.Gleam.PartMin, FW.Gleam.PartMax)
				table.insert(found, { piece = piece, copies = shine(piece, width) })
			end
		end
	end
	return found
end

local function hideGleam(entry: Gleam)
	entry.since = nil
	if not entry.live then
		return
	end
	entry.live = false
	for _, part in entry.parts or {} do
		for _, copy in part.copies do
			copy.frame.Visible = false
			copy.gradient.Offset = Vector2.new(-2, 0)
		end
	end
end

local function stepGleams(now: number, still: boolean)
	local G = FW.Gleam
	for _, entry in gleams do
		local root = entry.object
		if still or not shown(root) then
			hideGleam(entry)
			continue
		end
		local since: number = entry.since or now
		entry.since = since
		if entry.dirty then
			entry.dirty = false
			clearParts(entry)
		end
		if entry.parts == nil then
			local found = collectParts(entry)
			if #found > 0 then
				entry.parts = found
			elseif now - since > G.GroupWait and root.BackgroundTransparency < 1 then
				entry.parts = { { piece = root, copies = shine(root, number(root, "GleamWidth", G.Width)) } }
			else
				continue
			end
		end
		local duration = math.max(0.02, number(root, "GleamSpeed", G.Speed))
		local cooldown = number(root, "GleamCooldown", G.Cooldown)
		local w = number(root, "GleamWidth", G.Width)
		local tt = (now - since) % (duration + cooldown)
		local live = tt < duration
		entry.live = live
		if not entry.group then
			-- Chemin simple : la bande traverse l'élément lui-même.
			local span = 0.5 + w
			local offset = if live then -span + (tt / duration) * span * 2 else -2
			for _, part in entry.parts :: { Part } do
				for _, copy in part.copies do
					copy.gradient.Offset = Vector2.new(offset, 0)
					copy.frame.Visible = live
					if live then
						syncCopy(copy.frame, part.piece)
					end
				end
			end
			continue
		end
		-- Groupe : une seule bande, en fractions du groupe, placée dans chaque pièce.
		local gp = root.AbsolutePosition.X
		local gw = math.max(1, root.AbsoluteSize.X)
		local m = 0.5 + w
		local centre = -m + (tt / duration) * (1 + 2 * m)
		for _, part in entry.parts :: { Part } do
			local piece = part.piece
			if piece.Parent == nil then
				continue
			end
			local px = (piece.AbsolutePosition.X - gp) / gw
			local pw = math.max(0.001, piece.AbsoluteSize.X / gw)
			local offset = if live then (centre - px) / pw - 0.5 else -10
			for _, copy in part.copies do
				copy.gradient.Offset = Vector2.new(offset, 0)
				copy.frame.Visible = live
				if live then
					syncCopy(copy.frame, piece)
				end
			end
		end
	end
end

local function wireGleam(object: GuiObject)
	-- Le plugin prend le chemin simple sur tout texte ou image ; sur une racine sans texte ni image visibles (les 4
	-- boutons : TextButton au texte vide), ce chemin ne montre rien en jeu : on prend le groupe, qui fait briller
	-- ses pièces avec les silhouettes *_Sheen que le plugin a exportées pour ça.
	local simple = (isText(object) and (object :: TextLabel).Text ~= "") or (isImage(object) and (object :: ImageLabel).Image ~= "")
	local entry: Gleam = { object = object, group = not simple, parts = nil, dirty = false, since = nil, live = false }
	if simple then
		entry.parts = { { piece = object, copies = shine(object, number(object, "GleamWidth", FW.Gleam.Width)) } }
	else
		object.DescendantAdded:Connect(function(node: Instance)
			if node:IsA("GuiObject") and isPart(object, node) and not node:GetAttribute("FigmaSheen") then
				entry.dirty = true -- une pièce arrive : les copies seront refaites
			end
		end)
	end
	table.insert(gleams, entry)
	object.Destroying:Connect(function()
		forget(gleams, entry)
	end)
	changed()
end

------------------------------------------------------------------------------
-- Stroke : le dégradé du contour tourne
------------------------------------------------------------------------------

local function stepStrokes(now: number, still: boolean)
	for _, entry in strokes do
		local object = entry.object
		local gradient = entry.gradient
		local mode = if clamped(object, "StrokeMode", 0, 0, 1) >= 0.5 then 1 else 0
		if mode == 1 then
			report(`Stroke:mode:{object.Name}`, `StrokeMode = 1 sur {object:GetFullName()} : le défilement du dégradé n'est pas refait, il reste à sa place`)
		end
		if still or mode == 1 or not shown(object) then
			entry.since = nil
			if entry.moving then
				entry.moving = false
				gradient.Rotation = entry.rotation
				gradient.Offset = entry.offset
			end
			continue
		end
		local since: number = entry.since or now
		entry.since = since
		entry.moving = true
		local angle = clamped(object, "StrokeAngle", entry.rotation, -360, 360)
		local turn = ((now - since) * clamped(object, "StrokeRotate", FW.Stroke.Rotate, -360, 360)) % 360
		local phase = clamped(object, "StrokePhase", 0, 0, 1)
		gradient.Rotation = (angle + turn + phase * 360) % 360
		gradient.Offset = Vector2.new(
			clamped(object, "StrokeOffsetX", entry.offset.X, -2, 2),
			clamped(object, "StrokeOffsetY", entry.offset.Y, -2, 2)
		)
	end
end

local function wireStroke(object: GuiObject)
	local any = false
	for _, child in object:GetChildren() do
		if not child:IsA("UIStroke") then
			continue
		end
		any = true
		local gradient = child:FindFirstChildWhichIsA("UIGradient")
		local made = gradient == nil
		if gradient == nil then
			-- Le dégradé par défaut du plugin : gris, blanc au milieu, gris.
			local created = Instance.new("UIGradient")
			created.Name = FW.Stroke.GradientName
			created.Rotation = 0
			created.Offset = Vector2.new(0, 0)
			created.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(0.3, 0.3, 0.3)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(0.3, 0.3, 0.3)),
			})
			created.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.65),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.65),
			})
			created.Parent = child
			gradient = created
		end
		local found = gradient :: UIGradient
		local entry: Stroke = {
			object = object,
			gradient = found,
			made = made,
			rotation = found.Rotation,
			offset = found.Offset,
			since = nil,
			moving = false,
		}
		table.insert(strokes, entry)
		found.Destroying:Connect(function()
			forget(strokes, entry)
		end)
	end
	if not any then
		report(`Stroke:none:{object.Name}`, `FigmaStroke sur {object:GetFullName()} : pas de UIStroke, rien ne tourne`)
	end
	changed()
end

------------------------------------------------------------------------------
-- Assombrissement au survol et à l'appui (boutons du plugin sans FigmaSmooth)
------------------------------------------------------------------------------

local function inState(button: GuiButton, node: Instance): boolean
	local current: Instance? = node
	while current ~= nil and current ~= button do
		if current:GetAttribute("FigmaState") ~= nil then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Une copie ou un éclat créé par ce code (reflets, calque des éclats) : jamais assombri.
local function ours(button: GuiButton, node: Instance): boolean
	local current: Instance? = node
	while current ~= nil and current ~= button do
		local name = current.Name
		if name == FW.Gleam.CopyName or name == SHEEN.Name or name == GLEAM_OVERLAY or name == FW.Burst.BitName then
			return true
		end
		current = current.Parent
	end
	return false
end

local function noDim(node: Instance): boolean
	local suffix = FW.Dim.NoDimSuffix
	return node:GetAttribute("FigmaNoDim") ~= nil or string.sub(string.lower(node.Name), -#suffix) == suffix
end

local function dimTargets(button: GuiButton): { DimTarget }
	local targets: { DimTarget } = {}
	local function add(inst: GuiObject, prop: string)
		table.insert(targets, { inst = inst, prop = prop, base = (inst :: any)[prop], own = 0 })
	end
	if button:IsA("ImageButton") and button.Image ~= "" and button.ImageTransparency < 1 and not noDim(button) then
		add(button, "ImageColor3")
	end
	if button.BackgroundTransparency < 1 and not noDim(button) then
		add(button, "BackgroundColor3")
	end
	for _, node in button:GetDescendants() do
		if isImage(node) and not noDim(node) and not inState(button, node) and not ours(button, node) then
			add(node :: GuiObject, "ImageColor3")
		end
	end
	if #targets == 0 then
		if button:IsA("TextButton") and button.TextTransparency < 1 then
			add(button, "TextColor3")
		end
		for _, node in button:GetDescendants() do
			if isText(node) and (node :: TextLabel).TextTransparency < 1 and not noDim(node) and not inState(button, node)
				and not ours(button, node) then
				add(node :: GuiObject, "TextColor3")
			end
		end
	end
	return targets
end

local DIM_INFO = TweenInfo.new(FW.Dim.Time)

local function dimTo(entry: Dim, k: number)
	local instant = reduced()
	for _, target in entry.targets do
		local c = target.base
		local goal = Color3.new(c.R * k, c.G * k, c.B * k)
		target.own += 1
		if instant then
			(target.inst :: any)[target.prop] = goal
			target.own -= 1
		else
			local tween = TweenService:Create(target.inst, DIM_INFO, { [target.prop] = goal })
			tween.Completed:Connect(function()
				if target.own > 0 then
					target.own -= 1
				end
			end)
			tween:Play()
		end
	end
end

local function refreshDim(entry: Dim)
	local button = entry.button
	local k = if entry.held and entry.over then number(button, "PressDim", FW.Dim.Press)
		elseif entry.over then number(button, "HoverDim", FW.Dim.Hover)
		else 1
	if k == entry.level then
		return
	end
	entry.level = k
	dimTo(entry, k)
	changed()
end

-- Un bouton assombri qui n'est plus affiché revient à sa couleur (le survol ne finira jamais).
local function stepDims()
	for _, entry in dims do
		if entry.level ~= 1 and not shown(entry.button) then
			entry.over, entry.held = false, false
			refreshDim(entry)
		end
	end
end

local function wireDim(button: GuiButton)
	if button:GetAttribute("FigmaSmooth") then
		return -- le plugin grossit ce bouton sans l'assombrir : Motion.Button s'en charge
	end
	if button:FindFirstChild("Shade") ~= nil then
		return -- calque Shade de Clément : Motion.Button l'assombrit déjà
	end
	local targets = dimTargets(button)
	if #targets == 0 then
		return
	end
	button.AutoButtonColor = false -- comme le plugin : Roblox n'assombrit pas une deuxième fois
	local entry: Dim = { button = button, targets = targets, over = false, held = false, level = 1 }
	for _, target in targets do
		target.inst:GetPropertyChangedSignal(target.prop):Connect(function()
			if target.own == 0 then
				target.base = (target.inst :: any)[target.prop] -- changé par quelqu'un d'autre : la nouvelle couleur de repos
			end
		end)
	end
	button.MouseEnter:Connect(function()
		entry.over = true
		refreshDim(entry)
	end)
	button.MouseLeave:Connect(function()
		entry.over = false
		refreshDim(entry)
	end)
	button.MouseButton1Down:Connect(function()
		entry.over, entry.held = true, true
		refreshDim(entry)
	end)
	button.MouseButton1Up:Connect(function()
		entry.held = false
		refreshDim(entry)
	end)
	local ok, input = pcall(game.GetService, game, "UserInputService")
	local ended = if ok and input then (input :: any).InputEnded else nil
	if ended ~= nil then
		ended:Connect(function(object: InputObject)
			if object.UserInputType == Enum.UserInputType.Touch then
				entry.over, entry.held = false, false
				refreshDim(entry)
			elseif object.UserInputType == Enum.UserInputType.MouseButton1 and entry.held then
				entry.held = false
				refreshDim(entry)
			end
		end)
	end
	table.insert(dims, entry)
	button.Destroying:Connect(function()
		forget(dims, entry)
	end)
end

------------------------------------------------------------------------------
-- Reflet du bouton entier (SheenFx)
------------------------------------------------------------------------------

-- Un bouton déjà fait par le plugin (silhouette *_Sheen, FigmaSheen, FigmaGleam) : son reflet est celui du plugin.
local function figmaButton(button: GuiButton): boolean
	if button:GetAttribute("FigmaGleam") or button:GetAttribute("FigmaSheen") then
		return true
	end
	for _, node in button:GetDescendants() do
		if node:GetAttribute("FigmaSheen") or node:GetAttribute("FigmaGleam")
			or string.sub(node.Name, -#SHEEN_SUFFIX) == SHEEN_SUFFIX then
			return true
		end
	end
	return false
end

local function sheenWanted(button: GuiButton): boolean
	local screen = screenOf(button)
	if screen == nil then
		return false
	end
	if table.find(SHEEN.Shops, screen.Name) and string.match(button.Name, SHEEN.BuyPattern) ~= nil then
		return true
	end
	if gleamGradientInside(button) then
		return true
	end
	if screen.Name == SHEEN.Hud then
		local current: Instance? = button.Parent
		while current ~= nil and current ~= screen do
			if table.find(SHEEN.Containers, current.Name) then
				return true
			end
			current = current.Parent
		end
	end
	return false
end

-- Le fond à faire briller : celui du bouton, sinon un cadre enfant peint qui couvre presque tout le bouton.
local function sheenHost(button: GuiButton): GuiObject?
	if button.BackgroundTransparency < 1 then
		return button
	end
	for _, child in button:GetChildren() do
		-- Pas un calque de texte (le Cooldown de SleepButton, caché hors recharge : play f86b).
		if child:IsA("GuiObject") and not child:IsA("GuiButton") and not child:IsA("TextLabel")
			and not child:IsA("TextBox") and child.BackgroundTransparency < 1
			and child.Size.X.Scale >= SHEEN.CoverMin and child.Size.Y.Scale >= SHEEN.CoverMin then
			return child
		end
	end
	return nil
end

local function wireSheen(button: GuiButton)
	if not sheenWanted(button) or figmaButton(button) or button:FindFirstChild(GLEAM_OVERLAY) ~= nil then
		return
	end
	local host = sheenHost(button)
	if host == nil then
		report(`Sheen:none:{button.Name}`, `reflet du bouton {button:GetFullName()} : pas de fond peint (ni le bouton ni un cadre enfant), pas de reflet`)
		return
	end
	local fill = host :: GuiObject
	local copy = Instance.new("Frame")
	copy.Name = SHEEN.Name
	copy.BackgroundColor3 = WHITE
	copy.BackgroundTransparency = 0
	copy.BorderSizePixel = 0
	copy.AnchorPoint = Vector2.new(0, 0)
	copy.Position = UDim2.fromScale(0, 0)
	copy.Size = UDim2.fromScale(1, 1)
	copy.ZIndex = fill.ZIndex + 1
	copy.Active = false
	copy.Selectable = false
	copy.Visible = false
	local corner = fill:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = copy -- coupé à la forme du bouton
	end
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = gleamSequence(SHEEN.Width, nil, SHEEN.Opacity)
	gradient.Rotation = tiltFor(fill, SHEEN.Tilt, SHEEN.TiltMinAspect)
	gradient.Offset = Vector2.new(-2, 0)
	gradient.Parent = copy
	copy.Parent = fill
	local entry: Sheen = {
		button = button,
		host = fill,
		copy = copy,
		gradient = gradient,
		phase = random:NextNumber() * (SHEEN.Pass + SHEEN.Pause), -- chaque bouton à son moment
		since = nil,
	}
	table.insert(sheens, entry)
	button.Destroying:Connect(function()
		forget(sheens, entry)
	end)
	changed()
end

local function stepSheens(now: number, still: boolean)
	local cycle = SHEEN.Pass + SHEEN.Pause
	local span = 0.5 + SHEEN.Width
	for _, entry in sheens do
		if still or entry.host.BackgroundTransparency >= 1 or not shown(entry.button) then
			entry.since = nil
			if entry.copy.Visible then
				entry.copy.Visible = false
				entry.gradient.Offset = Vector2.new(-2, 0)
			end
			continue
		end
		local since: number = entry.since or now
		entry.since = since
		local tt = (now - since + entry.phase) % cycle
		local live = tt < SHEEN.Pass
		entry.copy.Visible = live
		entry.gradient.Offset = Vector2.new(if live then -span + (tt / SHEEN.Pass) * span * 2 else -2, 0)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

local function hasFigma(object: GuiObject): boolean
	for _, name in { "Spin", "Wiggle", "Lean", "Burst", "Gleam", "Stroke" } do
		if flag(object, name) then
			return true
		end
	end
	for _, name in FW.Unsupported do
		if object:GetAttribute("Figma" .. name) ~= nil then
			return true
		end
	end
	return object:IsA("GuiButton") and object:GetAttribute("FW_Owned") == true
end

local function wireFigma(object: GuiObject)
	for _, name in FW.Unsupported do
		if object:GetAttribute("Figma" .. name) ~= nil then
			report(`Unsupported:{name}`, `Figma{name} sur {object:GetFullName()} : effet du plugin pas refait (aucun des 4 boutons ne l'utilise)`)
		end
	end
	if flag(object, "Spin") then
		wireLoop(spins, object)
	end
	if flag(object, "Wiggle") then
		wireLoop(wiggles, object)
	end
	if flag(object, "Lean") then
		wireLean(object)
	end
	if flag(object, "Burst") then
		wireBurst(object)
	end
	if flag(object, "Gleam") then
		wireGleam(object)
	end
	if flag(object, "Stroke") then
		wireStroke(object)
	end
	if object:IsA("GuiButton") and object:GetAttribute("FW_Owned") == true then
		wireDim(object :: GuiButton)
	end
end

function FramewispFx.Wire(object: GuiObject)
	if not ENABLED or wired[object] then
		return
	end
	wired[object] = true
	if hasFigma(object) and not pluginScriptIn(object) then
		wireFigma(object)
	end
	if SHEEN_ON and object:IsA("GuiButton") then
		wireSheen(object :: GuiButton)
	end
end

function FramewispFx.Step(now: number, still: boolean)
	stepSpins(now, still)
	stepWiggles(now, still)
	stepLeans(now, still)
	for _, turn in turns do
		applyTurn(turn)
	end
	stepBursts(now, still)
	stepGleams(now, still)
	stepStrokes(now, still)
	stepSheens(now, still)
	stepDims()
	-- Une bascule ou un assombrissement fini, des éclats tous retombés : la boucle peut s'arrêter.
	changed()
end

function FramewispFx.Count(): number
	local count = #spins + #wiggles + #gleams + #strokes + #sheens
	for _, entry in leans do
		if leanActive(entry) then
			count += 1
		end
	end
	for _, entry in dims do
		if entry.level ~= 1 then
			count += 1
		end
	end
	if liveBits > 0 then
		count += 1
	end
	return count
end

function FramewispFx.SetChanged(fn: () -> ())
	changed = fn
end

function FramewispFx.GetState(): {
	Spins: number,
	Wiggles: number,
	Leans: number,
	Bursts: number,
	Particles: number,
	Gleams: number,
	Strokes: number,
	Dims: number,
	ButtonSheens: number,
	Skipped: number,
}
	return {
		Spins = #spins,
		Wiggles = #wiggles,
		Leans = #leans,
		Bursts = #bursts,
		Particles = liveBits,
		Gleams = #gleams,
		Strokes = #strokes,
		Dims = #dims,
		ButtonSheens = #sheens,
		Skipped = skipped,
	}
end

return FramewispFx
