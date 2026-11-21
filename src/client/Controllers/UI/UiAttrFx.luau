--!strict
-- UiAttrFx (a285, 21/11 ; client) : les effets d'UI que Clément pose sur ses écrans et qu'aucun code ne jouait
-- (retour de Cantin en jeu : « les glims, les effets de texte, les effets des over » ; diagnostic du 21/11 : Gleam
-- 18 fois, IconHover 24 fois, Idle = Wiggle ou Fall 9 fois ; liaison L-272). Module d'aide rangé dans Controllers/UI :
-- le Loader ne le démarre pas ; UiFeelController appelle UiAttrFx.Wire sur chaque GuiObject des écrans UI_* (hors
-- Template caché, comme ses boutons), copies des contrôleurs comprises. Derrière Features.UiAttrFx ; valeurs des deux
-- fiches de L-272 dans Config/UiMotion.AttrFx.
--
--   UIGradient « Gleam »       enfant d'un UIStroke ou de l'élément (boutons du HUD) : son Offset.X défile en boucle
--                               (fiche HUD) ; tous ceux d'un écran ensemble, depuis son ouverture.
--   Gleam = "Loop" | "Hover"   attribut : une copie blanche de l'image (ou du fond peint) par-dessus, avec une bande
--                               douce qui défile : en boucle (Loop, chaque élément à son moment) ou au survol du bouton
--                               ou de la carte qui le contient (Hover). Rien de plus sur un élément qui a déjà un
--                               UIGradient Gleam de Clément. Sur un texte (ItemName du shop) : ignoré depuis a298
--                               (« HUD et boutons d'achat », validé par Cantin, 21/11), l'attribut reste.
--   Framewisp (a298)           les attributs Figma* du plugin Framewisp et le reflet du bouton entier : module frère
--                               FramewispFx (Features.FramewispFx), appelé ici par Wire et par la même boucle.
--   IconHover = "Jump" | "Lean" au survol de l'élément (bouton ou carte), son enfant Icon saute une fois (Jump) ou
--                               s'incline tant que la souris reste (Lean). Un élément nommé Icon le fait lui-même au
--                               survol de son parent. "Spring" (caméra de la caisse qui suit le pointeur) : pas codé.
--   Idle = "Wiggle"             l'élément se balance par moments autour de sa Rotation ; ceux d'un même écran décalés.
--   Idle = "Fall"               des copies du FallItem de son FallLayer (l'élément lui-même ou un de ses descendants)
--                               tombent du haut au bas du calque ; le FallItem posé est caché le temps de l'effet.
-- Ce qui tourne seul (reflets, Wiggle, Fall) s'arrête quand l'élément n'est pas affiché (écran éteint, élément ou
-- parent caché) ou avec le réglage « animations réduites » : tout revient alors à l'état de Clément. Une valeur
-- inconnue ou un enfant qui manque : rien, une ligne dans la sortie en Studio. Une seule connexion Heartbeat, branchée
-- tant qu'un effet est suivi. L'écrasement au clic (Motion.Press) n'est pas touché.
-- Ce qui est touché, et rien d'autre : Offset des UIGradient Gleam (remis à From), la copie GleamFx (créée ici),
-- Position ou Rotation de l'Icon (IconHover), Rotation de l'élément (Wiggle), Visible du FallItem et ses copies
-- FallItemFx (Fall), tout remis ou détruit ensuite.
--
-- API (client) :
--   UiAttrFx.Wire(object)          branche les effets de cet élément (une fois ; sans effet sans réglage)
--   UiAttrFx.GetState() -> { Gleams, Gradients, IconHovers, Wiggles, Falls, Running }   (bancs)
--   UiAttrFx.Step(now?)            une image de la boucle (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Features = require(Config:WaitForChild("Features"))
local Motion = require(script.Parent:WaitForChild("Motion"))

-- a298 : les effets du plugin Framewisp et le reflet du bouton entier, module frère (absent : rien, comme avant).
type FramewispApi = {
	Wire: (GuiObject) -> (),
	Step: (number, boolean) -> (),
	Count: () -> number,
	SetChanged: (() -> ()) -> (),
}
local NO_FRAMEWISP: FramewispApi = {
	Wire = function(_: GuiObject) end,
	Step = function(_: number, _: boolean) end,
	Count = function(): number
		return 0
	end,
	SetChanged = function(_: () -> ()) end,
}
local FramewispFx: FramewispApi = NO_FRAMEWISP
do
	local module = script.Parent:FindFirstChild("FramewispFx")
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok and type(loaded) == "table" then
			FramewispFx = loaded :: any
		end
	end
end

local SPEC = UiMotion.AttrFx
local GLEAM = SPEC.Gleam
local GRADIENT = SPEC.GleamGradient
local HOVER = SPEC.IconHover
local WIGGLE = SPEC.Wiggle
local FALL = SPEC.Fall
local WHITE = Color3.new(1, 1, 1)
local IS_STUDIO = RunService:IsStudio()
local ENABLED = Features.UiAttrFx == true

type GleamSpec = { Pass: number, Width: number, Style: Enum.EasingStyle }

type Gleam = {
	object: GuiObject,
	overlay: GuiObject,
	gradients: { UIGradient }, -- lettres (ou image) et contour de la copie
	spec: GleamSpec,
	loop: boolean,
	nextAt: number, -- os.clock() du prochain reflet (Loop)
	startedAt: number?, -- os.clock() du reflet en cours
}

type Gradient = { gradient: UIGradient, host: GuiObject, screen: Instance?, moving: boolean }

type Wiggle = {
	object: GuiObject,
	rest: number,
	delay: number, -- décalage dans son écran (Stagger)
	shownAt: number?,
	moving: boolean,
	pausedUntil: number, -- survol de la carte de cet Icon : Motion.HoverCard le fait bouger
}

type Falling = { item: GuiObject, born: number, life: number, x: number, spin: number, base: { [string]: number } }

type Fall = {
	layer: GuiObject,
	template: GuiObject,
	baseVisible: boolean,
	running: boolean,
	nextAt: number,
	live: { Falling },
}

local UiAttrFx = {}

local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local gleams: { Gleam } = {}
local gradients: { Gradient } = {}
local gradientSince: { [Instance]: number } = {} -- os.clock() d'ouverture de chaque écran à reflets
local wiggles: { Wiggle } = {}
local wigglesPerScreen: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local falls: { Fall } = {}
local iconHovers = 0
local reported: { [string]: boolean } = {}
local heartbeat: RBXScriptConnection? = nil
local random = Random.new()

local function report(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(`[UiAttrFx] {message}`)
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

-- L'élément se voit : lui et ses parents Visible, dans un écran allumé du PlayerGui.
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

-- Ce qu'on survole pour l'élément : lui-même s'il est un bouton ou une carte, sinon le premier parent qui l'est.
local function hoverSourceOf(object: GuiObject): GuiObject
	local current: Instance? = object
	while current ~= nil and current:IsA("GuiObject") do
		local gui = current :: GuiObject
		if gui:IsA("GuiButton") or gui:GetAttribute("Hover") ~= nil or gui:FindFirstChild(UiMotion.HoverCard.Outline) ~= nil then
			return gui
		end
		current = gui.Parent
	end
	return object
end

------------------------------------------------------------------------------
-- Boucle d'image
------------------------------------------------------------------------------

local function sweep(entry: Gleam, now: number)
	local started = entry.startedAt
	if started == nil then
		return
	end
	local spec = entry.spec
	local t = (now - started) / spec.Pass
	if t >= 1 then
		entry.startedAt = nil
		entry.overlay.Visible = false
		return
	end
	local eased = TweenService:GetValue(t, spec.Style, Enum.EasingDirection.InOut)
	local reach = 0.5 + spec.Width / 2 + 0.05
	local offset = Vector2.new(-reach + 2 * reach * eased, 0)
	for _, gradient in entry.gradients do
		gradient.Offset = offset
	end
	entry.overlay.Visible = true
end

local function stepGleams(now: number, still: boolean)
	local period = GLEAM.Loop.Pass + GLEAM.Loop.Pause
	for _, entry in gleams do
		if entry.startedAt ~= nil then
			if still or not shown(entry.object) then
				entry.startedAt = nil
				entry.overlay.Visible = false
			else
				sweep(entry, now)
			end
		elseif entry.loop and not still and now >= entry.nextAt then
			entry.nextAt = now + period
			if shown(entry.object) then
				entry.startedAt = now
				sweep(entry, now)
			end
		end
	end
end

local function stepGradients(now: number, still: boolean)
	local cycle = GRADIENT.Sweep + GRADIENT.Pause
	local open: { [Instance]: boolean } = {}
	for _, entry in gradients do
		local screen = entry.screen
		if not still and screen ~= nil and shown(entry.host) then
			local since = gradientSince[screen]
			if since == nil then
				since = now
				gradientSince[screen] = now
			end
			open[screen] = true
			local phase = (now - since) % cycle
			local x = if phase < GRADIENT.Sweep
				then GRADIENT.From + (GRADIENT.To - GRADIENT.From) * phase / GRADIENT.Sweep
				else GRADIENT.From
			entry.gradient.Offset = Vector2.new(x, 0)
			entry.moving = true
		elseif entry.moving then
			entry.moving = false
			entry.gradient.Offset = Vector2.new(GRADIENT.From, 0)
		end
	end
	for screen in gradientSince do
		if not open[screen] then
			gradientSince[screen] = nil -- écran fermé : ses reflets repartiront ensemble à sa prochaine ouverture
		end
	end
end

local function stepWiggles(now: number, still: boolean)
	for _, entry in wiggles do
		local object = entry.object
		local visible = not still and shown(object)
		if not visible then
			entry.shownAt = nil
		end
		if not visible or now < entry.pausedUntil then
			if entry.moving then
				entry.moving = false
				if now >= entry.pausedUntil then
					object.Rotation = entry.rest
				end
			end
			continue
		end
		local since: number = entry.shownAt or now
		entry.shownAt = since
		-- Un balancement toutes les Every s, le premier Every s après l'affichage (Appear a fini son DropIn).
		local t = now - since - entry.delay
		local phase = if t >= WIGGLE.Every then t % WIGGLE.Every else math.huge
		if phase < WIGGLE.Time then
			if not entry.moving then
				entry.moving = true
				entry.rest = object.Rotation
			end
			object.Rotation = entry.rest + WIGGLE.Angle * math.sin(2 * math.pi * phase / WIGGLE.Time)
		elseif entry.moving then
			entry.moving = false
			object.Rotation = entry.rest
		end
	end
end

local TRANSPARENCY = { "ImageTransparency", "TextTransparency", "BackgroundTransparency" }

-- Transparences des copies qui tombent : au moins Fall.Transparency, et rien de ce qui est invisible sur le FallItem.
local function fallTransparencies(object: GuiObject): { [string]: number }
	local base: { [string]: number } = {}
	for _, property in TRANSPARENCY do
		local ok, value = pcall(function(): any
			return (object :: any)[property]
		end)
		if ok and type(value) == "number" and value < 1 then
			base[property] = math.max(value, FALL.Transparency)
		end
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		base.ImageTransparency = math.max(base.ImageTransparency or 0, FALL.Transparency)
	end
	return base
end

local function stopFall(entry: Fall)
	for _, falling in entry.live do
		falling.item:Destroy()
	end
	table.clear(entry.live)
	if entry.running then
		entry.running = false
		if entry.template.Parent ~= nil then
			entry.template.Visible = entry.baseVisible
		end
	end
end

local function stepFalls(now: number, still: boolean)
	for _, entry in falls do
		if still or not shown(entry.layer) then
			stopFall(entry)
			continue
		end
		if not entry.running then
			entry.running = true
			entry.baseVisible = entry.template.Visible
			entry.template.Visible = false
			entry.nextAt = now
		end
		if now >= entry.nextAt and #entry.live < FALL.Count then
			entry.nextAt = now + FALL.Time / FALL.Count
			local template = entry.template
			local item = template:Clone()
			item.Name = FALL.CopyName
			item.AnchorPoint = Vector2.new(0.5, 0.5)
			item.Visible = true
			local scale = FALL.MinScale + (FALL.MaxScale - FALL.MinScale) * random:NextNumber()
			local size = template.Size
			item.Size = UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
			local falling: Falling = {
				item = item,
				born = now,
				life = FALL.Time * (1 + FALL.SpeedSpread * (2 * random:NextNumber() - 1)),
				x = 0.1 + 0.8 * random:NextNumber(),
				spin = FALL.Spin * (2 * random:NextNumber() - 1),
				base = fallTransparencies(template),
			}
			item.Position = UDim2.fromScale(falling.x, 0)
			item.Parent = entry.layer
			table.insert(entry.live, falling)
		end
		for index = #entry.live, 1, -1 do
			local falling = entry.live[index]
			local t = (now - falling.born) / falling.life
			if t >= 1 or falling.item.Parent == nil then
				falling.item:Destroy()
				table.remove(entry.live, index)
				continue
			end
			local item = falling.item
			item.Position = UDim2.fromScale(falling.x, t)
			item.Rotation = entry.template.Rotation + falling.spin * t
			local alpha = math.clamp(math.min(t / FALL.FadeIn, (1 - t) / FALL.FadeOut), 0, 1)
			for property, value in falling.base do
				(item :: any)[property] = 1 - (1 - value) * alpha
			end
		end
	end
end

local function step()
	local now = os.clock()
	local still = reduced()
	stepGradients(now, still)
	stepGleams(now, still)
	stepWiggles(now, still)
	stepFalls(now, still)
	FramewispFx.Step(now, still)
end

local function sync()
	local count = #gleams + #gradients + #wiggles + #falls + FramewispFx.Count()
	if count > 0 and heartbeat == nil then
		local signal = (RunService :: any).Heartbeat
		if signal ~= nil then -- faux Roblox des bancs
			heartbeat = signal:Connect(step)
		end
	elseif count == 0 and heartbeat then -- a291 : test de vérité, l'ancien solveur refuse ~= nil ici
		heartbeat:Disconnect()
		heartbeat = nil
	end
end
FramewispFx.SetChanged(sync)

local function forget<T>(list: { T }, matches: (T) -> boolean, cleanup: ((T) -> ())?)
	for index = #list, 1, -1 do
		local entry = list[index]
		if matches(entry) then
			if cleanup then
				cleanup(entry)
			end
			table.remove(list, index)
		end
	end
	sync()
end

------------------------------------------------------------------------------
-- UIGradient Gleam de Clément
------------------------------------------------------------------------------

local function isGleamGradient(instance: Instance?): boolean
	return instance ~= nil and instance:IsA("UIGradient") and instance.Name == GRADIENT.Name
end

-- Les UIGradient Gleam de l'élément : le sien et ceux de ses UIStroke.
local function gleamGradientsOf(object: GuiObject): { UIGradient }
	local found: { UIGradient } = {}
	for _, child in object:GetChildren() do
		if isGleamGradient(child) then
			table.insert(found, child :: UIGradient)
		elseif child:IsA("UIStroke") then
			for _, inner in child:GetChildren() do
				if isGleamGradient(inner) then
					table.insert(found, inner :: UIGradient)
				end
			end
		end
	end
	return found
end

local function hasGleamGradientInside(object: GuiObject): boolean
	for _, descendant in object:GetDescendants() do
		if isGleamGradient(descendant) then
			return true
		end
	end
	return false
end

local function wireGradient(host: GuiObject, gradient: UIGradient)
	local entry: Gradient = { gradient = gradient, host = host, screen = screenOf(host), moving = false }
	table.insert(gradients, entry)
	gradient.Destroying:Connect(function()
		forget(gradients, function(other: Gradient): boolean
			return other == entry
		end, nil)
	end)
	sync()
end

------------------------------------------------------------------------------
-- Gleam (attribut)
------------------------------------------------------------------------------

local function copy(from: Instance, to: Instance, properties: { string })
	for _, property in properties do
		pcall(function()
			(to :: any)[property] = (from :: any)[property]
		end)
	end
end

local IMAGE_PROPERTIES = {
	"Image", "ScaleType", "SliceCenter", "SliceScale", "TileSize", "ImageRectOffset", "ImageRectSize", "ResampleMode",
	"ImageTransparency",
}

-- Bande douce (cosinus) de largeur width, d'opacité peak en son cœur, au milieu d'un dégradé transparent.
local function band(width: number, peak: number): NumberSequence
	local half = width / 2
	local points = { NumberSequenceKeypoint.new(0, 1) }
	for step = -4, 4 do
		local opacity = peak * (0.5 + 0.5 * math.cos(math.pi * step / 4))
		table.insert(points, NumberSequenceKeypoint.new(0.5 + half * step / 4, 1 - opacity))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(points)
end

local function addGradient(parent: Instance, width: number, peak: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = GLEAM.Rotation
	gradient.Transparency = band(width, peak)
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = parent
	return gradient
end

-- La copie blanche de l'élément qui porte le reflet et ses dégradés, ou nil (ni texte, ni image, ni fond visible).
local function makeOverlay(object: GuiObject, width: number): (GuiObject?, { UIGradient })
	local overlay: GuiObject
	local list: { UIGradient } = {}
	-- a298 : plus de copie de texte (les textes sont ignorés par wireGleam) ; un TextButton à fond peint prend le fond.
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		local image = Instance.new("ImageLabel")
		copy(object, image, IMAGE_PROPERTIES)
		image.ImageColor3 = WHITE
		object:GetPropertyChangedSignal("Image"):Connect(function()
			copy(object, image, { "Image" })
		end)
		table.insert(list, addGradient(image, width, GLEAM.TextPeak))
		overlay = image
	elseif object.BackgroundTransparency < 1 then
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = WHITE
		frame.BackgroundTransparency = 0
		local corner = object:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Clone().Parent = frame
		end
		table.insert(list, addGradient(frame, width, GLEAM.StrokePeak))
		overlay = frame
	else
		return nil, list
	end
	if not overlay:IsA("Frame") then
		overlay.BackgroundTransparency = 1
	end
	overlay.Name = GLEAM.Name
	overlay.BorderSizePixel = 0
	overlay.AnchorPoint = Vector2.zero
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = object.ZIndex + 1
	overlay.Active = false
	overlay.Selectable = false
	overlay.Visible = false
	return overlay, list
end

local function wireGleam(object: GuiObject, mode: string)
	if mode ~= "Loop" and mode ~= "Hover" then
		report(`Gleam:{mode}`, `Gleam = « {mode} » inconnu (Loop ou Hover attendu) : {object:GetFullName()}`)
		return
	end
	if hasGleamGradientInside(object) then
		report(`Gleam:gradient:{object.Name}`, `Gleam = {mode} sur {object:GetFullName()} : déjà un UIGradient {GRADIENT.Name} de Clément, c'est lui qui brille`)
		return
	end
	-- a298 (« HUD et boutons d'achat », validé par Cantin, 21/11) : plus de reflet sur un texte (ItemName du shop) ;
	-- l'attribut reste posé. Un TextButton à fond peint garde le reflet de son fond.
	if object:IsA("TextLabel") or object:IsA("TextBox") or (object:IsA("TextButton") and object.BackgroundTransparency >= 1) then
		report("Gleam:text", `Gleam = {mode} sur un texte ({object:GetFullName()}, et les suivants) : ignoré, le reflet est sur les boutons entiers`)
		return
	end
	local spec: GleamSpec = if mode == "Loop" then GLEAM.Loop else GLEAM.Hover
	local overlay, list = makeOverlay(object, spec.Width)
	if overlay == nil then
		report(`Gleam:none:{object.Name}`, `Gleam sur {object:GetFullName()} : ni texte, ni image, ni fond visible, pas de reflet`)
		return
	end
	overlay.Parent = object
	local entry: Gleam = {
		object = object,
		overlay = overlay,
		gradients = list,
		spec = spec,
		loop = mode == "Loop",
		nextAt = os.clock() + random:NextNumber() * (GLEAM.Loop.Pass + GLEAM.Loop.Pause), -- chaque élément à son moment
		startedAt = nil,
	}
	table.insert(gleams, entry)
	if mode == "Hover" then
		local source = hoverSourceOf(object)
		source.MouseEnter:Connect(function()
			if entry.startedAt == nil and not reduced() and Motion.IsOnTop(source) then
				entry.startedAt = os.clock()
			end
		end)
	end
	object.Destroying:Connect(function()
		forget(gleams, function(other: Gleam): boolean
			return other == entry
		end, nil)
	end)
	sync()
end

------------------------------------------------------------------------------
-- IconHover
------------------------------------------------------------------------------

local function iconOf(object: GuiObject): GuiObject?
	if object.Name == HOVER.Icon then
		return object
	end
	local found = object:FindFirstChild(HOVER.Icon)
	if found == nil then
		found = object:FindFirstChild(HOVER.Icon, true)
	end
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local JUMP_UP = TweenInfo.new(HOVER.Jump.Up, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local JUMP_DOWN = TweenInfo.new(HOVER.Jump.Down, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local LEAN_IN = TweenInfo.new(HOVER.Lean.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LEAN_OUT = TweenInfo.new(HOVER.Lean.BackTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function wireIconHover(object: GuiObject, mode: string)
	if mode == "Spring" then
		report(`IconHover:Spring:{object.Name}`, `IconHover = Spring sur {object:GetFullName()} : la caméra qui suit le pointeur n'est pas encore codée, rien ne bouge`)
		return
	end
	if mode ~= "Jump" and mode ~= "Lean" then
		report(`IconHover:{mode}`, `IconHover = « {mode} » inconnu (Jump ou Lean attendu) : {object:GetFullName()}`)
		return
	end
	local icon = iconOf(object)
	if icon == nil then
		report(`IconHover:none:{object.Name}`, `IconHover sur {object:GetFullName()} : pas d'enfant {HOVER.Icon}, rien ne bouge`)
		return
	end
	local target = icon :: GuiObject
	local parent = target.Parent
	local source: GuiObject = if target == object and parent and parent:IsA("GuiObject") then parent :: GuiObject else object
	local rest = target.Position
	local restRotation = target.Rotation
	Motion.SetRest(target, rest, restRotation)
	if mode == "Jump" then
		-- Un saut par entrée de la souris ; pas interrompu si elle part ; pas de nouveau saut avant la fin du précédent.
		local jumping = false
		source.MouseEnter:Connect(function()
			if jumping or reduced() or not Motion.IsOnTop(source) then
				return
			end
			jumping = true
			-- a299 : la hauteur du saut passe par un NumberValue (0 → 1 → 0) et chaque pas écrit Motion.Placed(rest
			-- + saut) : juste même si le survol recentre l'Icon pendant le saut (Config/UiMotion.Hover.Centered).
			local height = target.AbsoluteSize.Y * HOVER.Jump.Height
			local lift = Instance.new("NumberValue")
			lift.Value = 0
			lift:GetPropertyChangedSignal("Value"):Connect(function()
				target.Position = Motion.Placed(target, rest + UDim2.fromOffset(0, -height * lift.Value))
			end)
			local rise = TweenService:Create(lift, JUMP_UP, { Value = 1 })
			rise.Completed:Connect(function()
				local fall = TweenService:Create(lift, JUMP_DOWN, { Value = 0 })
				fall.Completed:Connect(function()
					target.Position = Motion.Placed(target, rest)
					lift:Destroy()
					jumping = false
				end)
				fall:Play()
			end)
			rise:Play()
		end)
	else
		local playing: Tween? = nil
		local function lean(rotation: number, info: TweenInfo)
			local previous = playing
			if previous then
				previous:Cancel()
			end
			local tween = TweenService:Create(target, info, { Rotation = rotation })
			playing = tween
			tween:Play()
		end
		source.MouseEnter:Connect(function()
			if not reduced() and Motion.IsOnTop(source) then
				lean(restRotation + HOVER.Lean.Tilt, LEAN_IN)
			end
		end)
		source.MouseLeave:Connect(function()
			if target.Rotation ~= restRotation then
				lean(restRotation, LEAN_OUT)
			end
		end)
	end
	iconHovers += 1
end

------------------------------------------------------------------------------
-- Idle : Wiggle et Fall
------------------------------------------------------------------------------

local function wireWiggle(object: GuiObject)
	local screen = screenOf(object)
	local index = 0
	if screen ~= nil then
		index = wigglesPerScreen[screen] or 0
		wigglesPerScreen[screen] = index + 1
	end
	local entry: Wiggle = {
		object = object,
		rest = object.Rotation,
		delay = index * WIGGLE.Stagger,
		shownAt = nil,
		moving = false,
		pausedUntil = 0,
	}
	Motion.SetRest(object, object.Position, object.Rotation)
	-- Un Icon de carte : Motion.HoverCard le penche au survol, on le laisse faire.
	local parent = object.Parent
	if object.Name == UiMotion.HoverCard.Icon and parent and parent:IsA("GuiObject") then
		local card = parent :: GuiObject
		card.MouseEnter:Connect(function()
			entry.pausedUntil = math.huge
			if entry.moving then
				entry.moving = false
				object.Rotation = entry.rest
			end
		end)
		card.MouseLeave:Connect(function()
			entry.pausedUntil = os.clock() + UiMotion.HoverCard.BackTime + 0.05
		end)
	end
	table.insert(wiggles, entry)
	object.Destroying:Connect(function()
		forget(wiggles, function(other: Wiggle): boolean
			return other == entry
		end, nil)
	end)
	sync()
end

local function wireFall(object: GuiObject)
	local layer: Instance? = if object.Name == FALL.Layer then object else object:FindFirstChild(FALL.Layer, true)
	local template = if layer then layer:FindFirstChild(FALL.Item) else nil
	if layer == nil or not layer:IsA("GuiObject") or template == nil or not template:IsA("GuiObject") then
		report(`Fall:none:{object.Name}`, `Idle = Fall sur {object:GetFullName()} : pas de {FALL.Layer}.{FALL.Item}, rien ne tombe`)
		return
	end
	local entry: Fall = {
		layer = layer :: GuiObject,
		template = template :: GuiObject,
		baseVisible = (template :: GuiObject).Visible,
		running = false,
		nextAt = 0,
		live = {},
	}
	table.insert(falls, entry)
	object.Destroying:Connect(function()
		forget(falls, function(other: Fall): boolean
			return other == entry
		end, stopFall)
	end)
	sync()
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function UiAttrFx.Wire(object: Instance)
	if not ENABLED or wired[object] or not object:IsA("GuiObject") then
		return
	end
	local gui = object :: GuiObject
	local found = gleamGradientsOf(gui)
	local gleam = gui:GetAttribute("Gleam")
	local iconHover = gui:GetAttribute("IconHover")
	local idle = gui:GetAttribute("Idle")
	if #found == 0 and gleam == nil and iconHover == nil and idle == nil then
		FramewispFx.Wire(gui) -- a298 : attributs Figma* et reflet du bouton entier
		return
	end
	wired[object] = true
	for _, gradient in found do
		wireGradient(gui, gradient)
	end
	if type(gleam) == "string" then
		wireGleam(gui, gleam)
	end
	if type(iconHover) == "string" then
		wireIconHover(gui, iconHover)
	end
	if idle == "Wiggle" then
		wireWiggle(gui)
	elseif idle == "Fall" then
		wireFall(gui)
	elseif idle ~= nil then
		report(`Idle:{tostring(idle)}`, `Idle = « {tostring(idle)} » inconnu dans l'UI (Wiggle ou Fall attendu) : {gui:GetFullName()}`)
	end
	FramewispFx.Wire(gui) -- après le Gleam d'attribut : une copie GleamFx déjà posée évite un deuxième reflet
end

function UiAttrFx.GetState(): {
	Gleams: number,
	Gradients: number,
	IconHovers: number,
	Wiggles: number,
	Falls: number,
	Running: boolean,
}
	return {
		Gleams = #gleams,
		Gradients = #gradients,
		IconHovers = iconHovers,
		Wiggles = #wiggles,
		Falls = #falls,
		Running = heartbeat ~= nil,
	}
end

-- Bancs : une image de la boucle, à l'heure `now`.
function UiAttrFx.Step(now: number?)
	local clock = now or os.clock()
	local still = reduced()
	stepGradients(clock, still)
	stepGleams(clock, still)
	stepWiggles(clock, still)
	stepFalls(clock, still)
	FramewispFx.Step(clock, still)
end

return UiAttrFx
