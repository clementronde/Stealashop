-- Banc a187 (2026-11-15, vague 58, L-177) : l'écran de chargement, src/first/LoadingScreen.local.luau (vrai) et
-- src/first/LoadingConfig.luau (vrai), sur un faux Roblox à lui (coroutines : PreloadAsync, game.Loaded, task.delay).
--   L1 sans UI_Loading : rien cloné, écran Roblox par défaut gardé ; sans Root : clone détruit, défaut gardé
--   L2 déroulé : clone dans le PlayerGui puis RemoveDefaultLoadingScreen ; PreloadAsync du clone d'abord ; barre de
--      0 à 100 % qui suit le chargement (écran, game:IsLoaded, lots d'assets sans doublon ni rbxassetid://0) ;
--      fermeture à 100 % ; fondu de FadeTime (fonds, images, textes, UIStroke), puis Destroy
--   L3 astuces : début TIP: de Clément gardé (sa couleur), au hasard toutes les 4 à 5 s, jamais deux fois de suite
--   L4 Skip caché, visible à 5 s ; un clic ferme (fondu, Destroy) ; le préchargement continue sans toucher l'écran
--   L5 chargement bloqué : fermeture à 20 s ; écran sans Bar, Tip ni SkipButton : aucune erreur

NOW = 0
local TIMERS = {}
local function schedule(t, item)
	table.insert(TIMERS, { at = NOW + t, item = item })
end
local function run(item, ...)
	if type(item) == "thread" then
		local ok, err = coroutine.resume(item, ...)
		if not ok then
			ERRORS = (ERRORS or 0) + 1
			print("ERREUR " .. tostring(err))
		end
	else
		item(...)
	end
end

-- Signaux et instances ----------------------------------------------------------------------------
local function newSignal()
	local s = { _c = {}, _waiting = {} }
	function s:Connect(fn)
		local link = { fn = fn, on = true }
		table.insert(self._c, link)
		return { Disconnect = function() link.on = false end }
	end
	function s:Wait()
		table.insert(self._waiting, coroutine.running())
		return coroutine.yield()
	end
	function s:Fire(...)
		for _, link in table.clone(self._c) do
			if link.on then
				link.fn(...)
			end
		end
		local waiting = self._waiting
		self._waiting = {}
		for _, co in waiting do
			run(co, ...)
		end
	end
	return s
end
local CLASSES = {
	ScreenGui = "LayerCollector", Frame = "GuiObject", TextLabel = "GuiObject", ImageLabel = "GuiObject",
	TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject", Texture = "Decal",
}
local I = {}
local methods = {}
I.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	if methods[k] then
		return methods[k]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == k then
			return child
		end
	end
	if rawget(self, "_destroyed") then
		error("lecture de " .. k .. " sur un objet détruit")
	end
	return nil
end
local WRITES = {}
I.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local at = table.find(old._children, self)
			if at then
				table.remove(old._children, at)
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(v._children, self)
			if v.ChildAdded then
				v.ChildAdded:Fire(self)
			end
		end
		return
	end
	if rawget(self, "_destroyed") then
		table.insert(WRITES, { inst = self, key = k, t = NOW })
	end
	rawset(self, k, v)
end
local function node(class, name, parent, props)
	local o = setmetatable({ ClassName = class, Name = name, _children = {} }, I)
	for k, v in props or {} do
		rawset(o, k, v)
	end
	if parent then
		o.Parent = parent
	end
	return o
end
function methods.IsA(self, c)
	local k = self.ClassName
	while k do
		if k == c then
			return true
		end
		k = CLASSES[k]
	end
	return c == "Instance"
end
function methods.FindFirstChild(self, name)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods.WaitForChild(self, name, timeout)
	local found = self:FindFirstChild(name)
	if found or timeout == nil then
		return assert(found, "WaitForChild sans délai : " .. name)
	end
	local co = coroutine.running()
	schedule(timeout, co)
	coroutine.yield()
	return self:FindFirstChild(name)
end
function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, child in o._children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
	for _, d in self:GetDescendants() do
		rawset(d, "_destroyed", true)
	end
end
function methods.Clone(self)
	local copy = node(self.ClassName, self.Name)
	for k, v in self do
		if k ~= "_children" and k ~= "_parent" and k ~= "ClassName" and k ~= "Name" then
			rawset(copy, k, if type(v) == "table" and v._isSignal then newSignal() else v)
		end
	end
	if self.ClassName == "TextButton" then
		rawset(copy, "Activated", newSignal())
	end
	for _, child in self._children do
		child:Clone().Parent = copy
	end
	return copy
end

-- Services ----------------------------------------------------------------------------------------
local REMOVED_DEFAULT = {}
local PRELOADS = {}
local PRELOAD_TIME = 0.5
local BLOCK_PRELOAD = false
local function makeWorld()
	local game = node("DataModel", "game")
	local w = { game = game }
	w.ReplicatedFirst = node("ReplicatedFirst", "ReplicatedFirst", game)
	function w.ReplicatedFirst.RemoveDefaultLoadingScreen()
		table.insert(REMOVED_DEFAULT, { t = NOW, inGui = #w.playerGui._children })
	end
	w.ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", game)
	local player = node("Player", "Alice")
	w.playerGui = node("PlayerGui", "PlayerGui", player)
	rawset(w.playerGui, "ChildAdded", newSignal())
	w.Players = { LocalPlayer = player }
	w.ContentProvider = {
		PreloadAsync = function(_, list)
			table.insert(PRELOADS, { t = NOW, list = list })
			local co = coroutine.running()
			if not BLOCK_PRELOAD then
				schedule(PRELOAD_TIME, co)
			end
			coroutine.yield()
		end,
	}
	w.TWEENS = {}
	w.TweenService = {
		Create = function(_, inst, info, goal)
			return {
				Play = function()
					table.insert(w.TWEENS, { inst = inst, info = info, goal = goal, t = NOW })
					for k, v in goal do
						inst[k] = v
					end
				end,
			}
		end,
	}
	w.loaded = false
	rawset(game, "Loaded", newSignal())
	function game.IsLoaded()
		return w.loaded
	end
	local services = {
		ContentProvider = w.ContentProvider, Players = w.Players, ReplicatedFirst = w.ReplicatedFirst,
		ReplicatedStorage = w.ReplicatedStorage, TweenService = w.TweenService,
	}
	function game.GetService(_, name)
		return assert(services[name], name)
	end
	return w
end

-- Écran de Clément (noms de tools/clement/loading_build.luau)
local function buildScreen(w, opts)
	opts = opts or {}
	local gui = node("ScreenGui", "UI_Loading", nil, { DisplayOrder = 1000, ResetOnSpawn = false })
	if opts.noRoot then
		gui.Parent = w.ReplicatedFirst
		return gui
	end
	local root = node("Frame", "Root", gui, { BackgroundTransparency = 0 })
	local hero = node("Frame", "Hero", root, { BackgroundTransparency = 1 })
	node("ImageLabel", "Rays", hero, { ImageTransparency = 0.45, BackgroundTransparency = 1, Image = "rbxassetid://96610322911997" })
	node("ImageLabel", "Art", hero, { ImageTransparency = 0, BackgroundTransparency = 1, Image = "rbxassetid://0" })
	node("ImageLabel", "Logo", root, { ImageTransparency = 0, BackgroundTransparency = 1, Image = "rbxassetid://0" })
	if not opts.bare then
		local tip = node("TextLabel", "Tip", root, {
			RichText = true, TextTransparency = 0, BackgroundTransparency = 1,
			Text = (opts.tipPrefix or '<font color="#FFD23A">TIP:</font> ') .. "At night a wall closes the street. Rob the shops before it drops!",
		})
		node("UIStroke", "UIStroke", tip, { Transparency = 0 })
		local bar = node("Frame", "Bar", root, { BackgroundTransparency = 0 })
		node("UIStroke", "UIStroke", bar, { Transparency = 0 })
		local fill = node("Frame", "Fill", bar, { BackgroundTransparency = 0, Size = { X = 0.64, Y = 1 } })
		node("Frame", "Shine", fill, { BackgroundTransparency = 0.45 })
		local pct = node("TextLabel", "Percent", bar, { Text = "64%", TextTransparency = 0, BackgroundTransparency = 1 })
		node("UIStroke", "UIStroke", pct, { Transparency = 0 })
		local skip = node("TextButton", "SkipButton", root, { Text = "", BackgroundTransparency = 0, Visible = true, Active = true })
		rawset(skip, "Activated", newSignal())
		node("ImageLabel", "Studs", skip, { ImageTransparency = 0.55, BackgroundTransparency = 1, Image = "rbxassetid://3014551673" })
		local lbl = node("TextLabel", "Label", skip, { Text = "SKIP", TextTransparency = 0, BackgroundTransparency = 1 })
		node("UIStroke", "UIStroke", lbl, { Transparency = 0 })
	end
	gui.Parent = w.ReplicatedFirst
	return gui
end

-- Assets de ReplicatedStorage/Assets : n images uniques, plus des doublons et des images vides
local function buildAssets(w, n)
	local assets = node("Folder", "Assets", w.ReplicatedStorage)
	local ui = node("Folder", "UI", assets)
	local icons = node("Folder", "Icons", assets)
	local anims = node("Folder", "Player", node("Folder", "Animations", assets))
	node("Folder", "Sounds", assets) -- pas dans Preload
	for i = 1, n do
		local id = "rbxassetid://" .. (1000 + i)
		if i % 3 == 0 then
			node("Decal", "ICON_" .. i, icons, { Texture = id })
		elseif i % 3 == 1 then
			node("ImageLabel", "Img" .. i, node("BillboardGui", "BB_" .. i, ui), { Image = id })
		else
			node("Animation", "Anim" .. i, anims, { AnimationId = id })
		end
	end
	node("ImageLabel", "Dup", ui, { Image = "rbxassetid://1001" }) -- doublon
	node("ImageLabel", "Empty", ui, { Image = "" })
	node("ImageLabel", "Zero", ui, { Image = "rbxassetid://0" })
	node("Sound", "Chase_Siren", assets.Sounds, { SoundId = "rbxassetid://5" })
end

-- Lancement du vrai script ---------------------------------------------------------------------------
local fakeRandom = {
	new = function()
		local r = {}
		function r:NextInteger(a, b)
			return math.random(a, b)
		end
		function r:NextNumber(a, b)
			return a + math.random() * (b - a)
		end
		return r
	end,
}
local function launch(w)
	local folder = node("Folder", "First", w.ReplicatedFirst)
	local cfgModule = node("ModuleScript", "LoadingConfig", folder)
	local scriptObj = node("LocalScript", "LoadingScreen", folder)
	local env
	local cfgCache
	local function fakeRequire(m)
		assert(m == cfgModule, "require inattendu")
		if cfgCache == nil then
			local fn = assert(loadstring(SOURCES["first/LoadingConfig.luau"], "LoadingConfig"))
			cfgCache = fn()
		end
		return cfgCache
	end
	env = setmetatable({
		script = scriptObj,
		game = w.game,
		require = fakeRequire,
		Random = fakeRandom,
		TweenInfo = { new = function(t, s, d) return { Time = t, Style = s, Direction = d } end },
		UDim2 = { fromScale = function(x, y) return { X = x, Y = y } end },
		Enum = setmetatable({}, { __index = function(_, a) return setmetatable({}, { __index = function(_, b) return a .. "." .. b end }) end }),
		task = {
			delay = function(t, fn, ...)
				local args = table.pack(...)
				schedule(t, function() fn(table.unpack(args, 1, args.n)) end)
			end,
		},
	}, { __index = getfenv(1) })
	local fn = assert(loadstring(SOURCES["first/LoadingScreen.local.luau"], "LoadingScreen"))
	setfenv(fn, env)
	local co = coroutine.create(fn)
	run(co)
	w.config = fakeRequire(cfgModule)
	return co
end
local function advance(seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		NOW += 0.05
		local due = true
		while due do
			due = false
			for _, timer in table.clone(TIMERS) do
				if timer.at <= NOW + 1e-9 then
					table.remove(TIMERS, table.find(TIMERS, timer))
					run(timer.item)
					due = true
					break
				end
			end
		end
	end
end
local function reset()
	NOW = 0
	table.clear(TIMERS)
	table.clear(REMOVED_DEFAULT)
	table.clear(PRELOADS)
	table.clear(WRITES)
	PRELOAD_TIME = 0.5
	BLOCK_PRELOAD = false
	ERRORS = 0
end

CHECKS, FAILS = 0, 0
local function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("ok    " .. label)
		end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local function screenIn(w)
	return w.playerGui:FindFirstChild("UI_Loading")
end
local function fillScale(gui)
	return gui.Root.Bar.Fill.Size.X
end

-- L1 : sans UI_Loading, sans Root ----------------------------------------------------------------------
do
	reset()
	local w = makeWorld()
	launch(w)
	check("L1 sans UI_Loading : l'écran Roblox reste tant que UI_Loading n'est pas là", #REMOVED_DEFAULT == 0)
	advance(w.config.ScreenWait + 0.1)
	check("L1 sans UI_Loading : rien dans le PlayerGui", #w.playerGui._children == 0)
	check("L1 sans UI_Loading : RemoveDefaultLoadingScreen jamais appelé", #REMOVED_DEFAULT == 0)
	check("L1 sans UI_Loading : aucun préchargement", #PRELOADS == 0)
	advance(25)
	check("L1 sans UI_Loading : aucune erreur", ERRORS == 0, ERRORS)

	reset()
	w = makeWorld()
	buildScreen(w, { noRoot = true })
	launch(w)
	advance(1)
	check("L1 sans Root : rien dans le PlayerGui, défaut gardé", #w.playerGui._children == 0 and #REMOVED_DEFAULT == 0)
	check("L1 sans Root : aucune erreur", ERRORS == 0, ERRORS)
end

-- L2 : déroulé complet -----------------------------------------------------------------------------------
do
	reset()
	local w = makeWorld()
	local template = buildScreen(w)
	buildAssets(w, 45)
	launch(w)
	local cfg = w.config
	local gui = screenIn(w)
	check("L2 clone dans le PlayerGui", gui ~= nil and gui ~= template)
	check("L2 UI_Loading de ReplicatedFirst gardé", w.ReplicatedFirst:FindFirstChild("UI_Loading") == template)
	check("L2 RemoveDefaultLoadingScreen après le clone dans le PlayerGui", #REMOVED_DEFAULT == 1 and REMOVED_DEFAULT[1].inGui == 1)
	check("L2 barre à 0 au départ", gui and near(fillScale(gui), 0) and gui.Root.Bar.Percent.Text == "0%", gui and gui.Root.Bar.Percent.Text)
	check("L2 Skip caché au départ", gui and gui.Root.SkipButton.Visible == false)
	check("L2 PreloadAsync du clone d'abord", #PRELOADS == 1 and PRELOADS[1].list[1] == gui and #PRELOADS[1].list == 1)
	advance(0.5)
	check("L2 écran préchargé : barre à Weights.Screen", gui and near(fillScale(gui), cfg.Weights.Screen) and gui.Root.Bar.Percent.Text == math.floor(cfg.Weights.Screen * 100) .. "%", gui and gui.Root.Bar.Percent.Text)
	local tw = w.TWEENS[#w.TWEENS]
	check("L2 barre en tween court (BarTweenTime)", tw and tw.inst == gui.Root.Bar.Fill and near(tw.info.Time, cfg.BarTweenTime))
	advance(1.5)
	check("L2 en attente de game:IsLoaded : la barre ne bouge pas (jamais un minuteur)", near(fillScale(gui), cfg.Weights.Screen) and #PRELOADS == 1)
	w.loaded = true
	w.game.Loaded:Fire()
	local afterGame = cfg.Weights.Screen + cfg.Weights.Game
	check("L2 jeu chargé : barre à Screen + Game", near(fillScale(gui), afterGame), fillScale(gui))
	-- 45 assets uniques (doublon, vide, rbxassetid://0 et sons exclus), lots de BatchSize
	local expectedBatches = math.ceil(45 / cfg.BatchSize)
	check("L2 premier lot lancé", #PRELOADS == 2 and #PRELOADS[2].list == math.min(cfg.BatchSize, 45), #PRELOADS)
	local seenIds, total, dup = {}, 0, false
	local values = {}
	for b = 1, expectedBatches do
		local list = PRELOADS[1 + b] and PRELOADS[1 + b].list or {}
		for _, inst in list do
			local id = inst.Image or inst.Texture or inst.AnimationId
			if seenIds[id] or id == "" or id == "rbxassetid://0" or inst.ClassName == "Sound" then
				dup = true
			end
			seenIds[id] = true
			total += 1
		end
		advance(0.5)
		table.insert(values, fillScale(gui))
	end
	check("L2 " .. expectedBatches .. " lots, 45 assets, sans doublon ni image vide", #PRELOADS == 1 + expectedBatches and total == 45 and not dup, total)
	local rising = true
	for i = 2, #values do
		if values[i] < values[i - 1] then
			rising = false
		end
	end
	check("L2 la barre monte à chaque lot", rising and values[1] > afterGame)
	check("L2 100 % à la fin du dernier lot", near(values[#values], 1) and gui.Root.Bar.Percent.Text == "100%", gui.Root.Bar.Percent.Text)
	check("L2 encore là le temps du tween de la barre", screenIn(w) == gui and gui.Root.BackgroundTransparency == 0)
	advance(cfg.BarTweenTime)
	local fades = {}
	for _, t in w.TWEENS do
		if near(t.info.Time, cfg.FadeTime) then
			fades[t.inst] = t.goal
		end
	end
	local r = gui.Root
	local ok = fades[r] and fades[r].BackgroundTransparency == 1
		and fades[r.Bar] and fades[r.Bar].BackgroundTransparency == 1
		and fades[r.Bar.Fill] and fades[r.Bar.Fill].BackgroundTransparency == 1
		and fades[r.Bar.Fill.Shine] and fades[r.Bar.Fill.Shine].BackgroundTransparency == 1
		and fades[r.SkipButton] and fades[r.SkipButton].BackgroundTransparency == 1
		and fades[r.Hero.Rays] and fades[r.Hero.Rays].ImageTransparency == 1
		and fades[r.Hero.Art] and fades[r.Hero.Art].ImageTransparency == 1
		and fades[r.Logo] and fades[r.Logo].ImageTransparency == 1
		and fades[r.SkipButton.Studs] and fades[r.SkipButton.Studs].ImageTransparency == 1
		and fades[r.Tip] and fades[r.Tip].TextTransparency == 1
		and fades[r.Bar.Percent] and fades[r.Bar.Percent].TextTransparency == 1
		and fades[r.SkipButton.Label] and fades[r.SkipButton.Label].TextTransparency == 1
	check("L2 fondu en FadeTime : fonds, images et textes de L-177", ok)
	local strokes, faded = 0, 0
	for _, d in r:GetDescendants() do
		if d.ClassName == "UIStroke" then
			strokes += 1
			if fades[d] and fades[d].Transparency == 1 then
				faded += 1
			end
		end
	end
	check("L2 fondu : Transparency de tous les UIStroke", strokes == 4 and faded == 4, faded)
	check("L2 pendant le fondu : encore dans le PlayerGui", screenIn(w) == gui)
	advance(cfg.FadeTime)
	check("L2 après le fondu : Destroy", screenIn(w) == nil and rawget(gui, "_destroyed") == true)
	local tweensAfter = #w.TWEENS
	advance(25)
	check("L2 plus rien ensuite (ni tween, ni écriture sur l'écran détruit)", #w.TWEENS == tweensAfter and #WRITES == 0, #WRITES)
	check("L2 aucune erreur", ERRORS == 0, ERRORS)
end

-- L3 : astuces ---------------------------------------------------------------------------------------------
do
	reset()
	local w = makeWorld()
	buildScreen(w, { tipPrefix = '<font color="#00FF00">TIP:</font> ' })
	BLOCK_PRELOAD = true
	launch(w)
	local cfg = w.config
	local gui = screenIn(w)
	local tipLabel = gui.Root.Tip
	local known = {}
	for _, t in cfg.Tips do
		known[t] = true
	end
	local function body(text)
		return string.match(text, "^<font color=\"#00FF00\">TIP:</font> (.*)$")
	end
	check("L3 première astuce tout de suite, début de Clément gardé (sa couleur)", body(tipLabel.Text) ~= nil and known[body(tipLabel.Text)] == true, tipLabel.Text)
	local changes, last, lastAt, minGap, maxGap, allKnown = 0, tipLabel.Text, 0, math.huge, 0, true
	for _ = 1, 360 do -- 18 s
		advance(0.05)
		if tipLabel.Text ~= last then
			changes += 1
			local gap = NOW - lastAt
			minGap = math.min(minGap, gap)
			maxGap = math.max(maxGap, gap)
			lastAt = NOW
			local b = body(tipLabel.Text)
			if b == nil or not known[b] then
				allKnown = false
			end
			last = tipLabel.Text
		end
	end
	check("L3 astuce changée toutes les 4 à 5 s", changes >= 3 and minGap >= cfg.TipIntervalMin - 0.06 and maxGap <= cfg.TipIntervalMax + 0.06, changes .. " " .. minGap .. " " .. maxGap)
	check("L3 astuces de LoadingConfig, avec le début TIP:", allKnown)
	-- une astuce répétée ne se verrait pas : l'écart suivant dépasserait alors TipIntervalMax
	check("L3 jamais deux fois la même de suite (aucun écart au-delà de TipIntervalMax)", maxGap <= cfg.TipIntervalMax + 0.06)
	local longest = 0
	for _, t in cfg.Tips do
		longest = math.max(longest, #t)
		check("L3 astuce sans banc ni coffre-fort : " .. t, not string.find(string.lower(t), "bench") and not string.find(string.gsub(string.lower(t), "safe zone", ""), "safe") and not string.find(string.lower(t), "vault"))
	end
	check("L3 astuces de 115 caractères au plus (mesure de Clément)", longest <= 115, longest)
	advance(5)
	check("L3 (chargement bloqué) fermé à MaxDuration, astuces arrêtées", screenIn(w) == nil)
	check("L3 aucune erreur", ERRORS == 0, ERRORS)
	-- sans début TIP: dans le texte de Clément : celui de LoadingConfig
	reset()
	w = makeWorld()
	local tpl = buildScreen(w)
	tpl.Root.Tip.Text = "Loading..."
	BLOCK_PRELOAD = true
	launch(w)
	check("L3 sans début dans l'écran : TipPrefix de LoadingConfig", string.sub(screenIn(w).Root.Tip.Text, 1, #w.config.TipPrefix) == w.config.TipPrefix)
end

-- L4 : Skip ------------------------------------------------------------------------------------------------
do
	reset()
	local w = makeWorld()
	buildScreen(w)
	buildAssets(w, 60)
	PRELOAD_TIME = 2
	launch(w)
	local cfg = w.config
	local gui = screenIn(w)
	local skip = gui.Root.SkipButton
	advance(cfg.SkipDelay - 0.1)
	check("L4 Skip encore caché juste avant SkipDelay", skip.Visible == false)
	advance(0.15)
	check("L4 Skip visible à SkipDelay", skip.Visible == true)
	w.loaded = true
	w.game.Loaded:Fire()
	local preloadsAtSkip = #PRELOADS
	skip.Activated:Fire()
	check("L4 clic : fondu lancé (Skip désactivé)", skip.Active == false and skip.BackgroundTransparency == 1)
	skip.Activated:Fire()
	advance(cfg.FadeTime + 0.05)
	check("L4 clic : écran détruit après le fondu", screenIn(w) == nil and rawget(gui, "_destroyed") == true)
	advance(20)
	check("L4 le préchargement continue derrière", #PRELOADS > preloadsAtSkip, #PRELOADS .. " / " .. preloadsAtSkip)
	check("L4 sans toucher l'écran fermé", #WRITES == 0, #WRITES)
	check("L4 aucune erreur", ERRORS == 0, ERRORS)
end

-- L5 : chargement bloqué, écran incomplet -------------------------------------------------------------------
do
	reset()
	local w = makeWorld()
	buildScreen(w)
	launch(w)
	advance(0.5)
	local gui = screenIn(w)
	-- game.Loaded ne vient jamais
	advance(w.config.MaxDuration - 0.6)
	check("L5 bloqué : encore là juste avant MaxDuration", screenIn(w) == gui and gui.Root.BackgroundTransparency == 0)
	check("L5 bloqué : la barre reste au vrai chargement", near(fillScale(gui), w.config.Weights.Screen))
	advance(0.15)
	check("L5 bloqué : fondu à MaxDuration", gui.Root.BackgroundTransparency == 1)
	advance(w.config.FadeTime)
	check("L5 bloqué : détruit", screenIn(w) == nil)
	w.loaded = true
	w.game.Loaded:Fire()
	advance(2)
	check("L5 le jeu arrive après : rien n'écrit sur l'écran détruit", #WRITES == 0 and ERRORS == 0, #WRITES)

	reset()
	w = makeWorld()
	buildScreen(w, { bare = true })
	w.loaded = true
	launch(w)
	advance(0.5)
	check("L5 écran sans Bar, Tip ni SkipButton : affiché", screenIn(w) ~= nil and #REMOVED_DEFAULT == 1)
	advance(w.config.BarTweenTime + w.config.FadeTime + 0.1)
	check("L5 écran incomplet : fermé à 100 % (jeu déjà chargé, aucun asset)", screenIn(w) == nil)
	check("L5 écran incomplet : aucune erreur", ERRORS == 0, ERRORS)
end

print(`banc a187 : {CHECKS} vérification(s), {FAILS} échec(s)`)
