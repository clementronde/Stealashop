---------------------------------------------------------------- extensions a37 (DEV-052)
-- Ajouts au faux Roblox de la lignée a15 (variables locales ISA, PROPS, Methods, InstanceMT, games,
-- newSignal, Heartbeat), pour Controllers/UI/Motion : classes UIScale et NumberValue, signal
-- GetPropertyChangedSignal (s'il manque), TweenInfo, TweenService (game:GetService). Collé juste
-- après le stubs.luau du banc, dans le même fichier : il voit ses variables locales.
--
-- TIMED_TWEENS (global) :
--   false (défaut) : un tween arrive au bout dès Play (propriétés posées, Completed envoyé tout de
--                    suite) ; les bancs existants gardent leurs vérifications telles quelles ;
--   true           : il avance avec le temps simulé, à chaque Heartbeat, avec les vraies courbes de
--                    Roblox (Linear, Quad, Cubic, Back ; In, Out, InOut), et Cancel envoie
--                    Completed(Cancelled), comme Roblox.
-- TWEEN_STATS : nombre de tweens créés, joués, finis, annulés (pour les vérifications).
TIMED_TWEENS = false
TWEEN_STATS = { created = 0, played = 0, completed = 0, cancelled = 0 }
do
	ISA.UIScale = ISA.UIScale or { "UIComponent" }
	ISA.NumberValue = ISA.NumberValue or { "ValueBase" }
	ISA.UIStroke = ISA.UIStroke or { "UIComponent" }
	ISA.UICorner = ISA.UICorner or { "UIComponent" }
	ISA.UIAspectRatioConstraint = ISA.UIAspectRatioConstraint or { "UIConstraint", "UIComponent" }
	ISA.UISizeConstraint = ISA.UISizeConstraint or { "UIConstraint", "UIComponent" }
	PROPS.UIScale = PROPS.UIScale or { Scale = 1 }
	PROPS.NumberValue = PROPS.NumberValue or { Value = 0 }
	PROPS.UIStroke = PROPS.UIStroke or { Thickness = 1 }
	PROPS.UICorner = PROPS.UICorner or {}
	PROPS.UIAspectRatioConstraint = PROPS.UIAspectRatioConstraint or { AspectRatio = 1 }
	PROPS.UISizeConstraint = PROPS.UISizeConstraint or {}

	if Methods.GetPropertyChangedSignal == nil then
		local plainNewIndex = InstanceMT.__newindex
		InstanceMT.__newindex = function(self, key, value)
			local props = rawget(self, "_props")
			local before = props[key]
			plainNewIndex(self, key, value)
			local signals = rawget(self, "_propSignals")
			local signal = signals and signals[key]
			if signal and props[key] ~= before then
				signal:Fire()
			end
		end
		function Methods.GetPropertyChangedSignal(self, key)
			local signals = rawget(self, "_propSignals")
			if signals == nil then
				signals = {}
				rawset(self, "_propSignals", signals)
			end
			signals[key] = signals[key] or newSignal()
			return signals[key]
		end
	end

	if TweenInfo == nil then
		local TweenInfoMT = { __type = "TweenInfo" }
		TweenInfo = {
			new = function(time, style, direction)
				return setmetatable({
					Time = time or 1,
					EasingStyle = style or "Enum.EasingStyle.Quad",
					EasingDirection = direction or "Enum.EasingDirection.Out",
				}, TweenInfoMT)
			end,
		}
	end

	-- Courbes « In » de Roblox ; Out et InOut s'en déduisent.
	local BACK = 1.70158
	local IN = {
		["Enum.EasingStyle.Linear"] = function(u)
			return u
		end,
		["Enum.EasingStyle.Quad"] = function(u)
			return u * u
		end,
		["Enum.EasingStyle.Cubic"] = function(u)
			return u * u * u
		end,
		["Enum.EasingStyle.Quart"] = function(u)
			return u * u * u * u
		end,
		["Enum.EasingStyle.Back"] = function(u)
			return u * u * ((BACK + 1) * u - BACK)
		end,
	}
	function EASE(style, direction, u)
		local f = IN[style]
		assert(f, "courbe pas simulée : " .. tostring(style))
		if direction == "Enum.EasingDirection.In" then
			return f(u)
		elseif direction == "Enum.EasingDirection.Out" then
			return 1 - f(1 - u)
		end
		if u < 0.5 then
			return f(2 * u) / 2
		end
		return 1 - f(2 * (1 - u)) / 2
	end

	local active = {} -- tweens en cours (mode TIMED_TWEENS), dans l'ordre de Play
	local clock = 0 -- temps des tweens : somme des dt de Heartbeat
	local TweenMT = { __type = "Tween" }
	TweenMT.__index = TweenMT
	function TweenMT:Play()
		TWEEN_STATS.played += 1
		if not TIMED_TWEENS then
			for k, v in self._goals do
				self.Instance[k] = v
			end
			self.PlaybackState = "Enum.PlaybackState.Completed"
			TWEEN_STATS.completed += 1
			self.Completed:Fire("Enum.PlaybackState.Completed")
			return
		end
		self._from = {}
		for k in self._goals do
			self._from[k] = self.Instance[k]
		end
		self._start = clock
		self.PlaybackState = "Enum.PlaybackState.Playing"
		if not table.find(active, self) then
			table.insert(active, self)
		end
	end
	function TweenMT:Cancel()
		local i = table.find(active, self)
		if i == nil then
			return
		end
		table.remove(active, i)
		self.PlaybackState = "Enum.PlaybackState.Cancelled"
		TWEEN_STATS.cancelled += 1
		self.Completed:Fire("Enum.PlaybackState.Cancelled")
	end
	function TweenMT:Pause()
		error("Tween:Pause pas simulé")
	end

	local function stepTweens(dt)
		clock += dt
		for _, tween in table.clone(active) do
			if table.find(active, tween) then
				local info = tween.TweenInfo
				local u = if info.Time <= 0 then 1 else math.min(1, (clock - tween._start) / info.Time)
				if u >= 1 - 1e-9 then
					table.remove(active, table.find(active, tween))
					for k, v in tween._goals do
						tween.Instance[k] = v
					end
					tween.PlaybackState = "Enum.PlaybackState.Completed"
					TWEEN_STATS.completed += 1
					tween.Completed:Fire("Enum.PlaybackState.Completed")
				else
					local e = EASE(info.EasingStyle, info.EasingDirection, u)
					for k, v in tween._goals do
						local from = tween._from[k]
						tween.Instance[k] = from + (v - from) * e
					end
				end
			end
		end
	end
	Heartbeat:Connect(stepTweens)
	function ACTIVE_TWEENS()
		return #active
	end

	TweenServiceStub = {
		Create = function(_, inst, info, goals)
			assert(inst ~= nil and info ~= nil and type(goals) == "table", "TweenService:Create : arguments")
			for k, v in goals do
				assert(type(v) == "number", "tween simulé : seules les propriétés nombres sont prises en charge (" .. k .. ")")
			end
			TWEEN_STATS.created += 1
			return setmetatable({
				Instance = inst,
				TweenInfo = info,
				PlaybackState = "Enum.PlaybackState.Begin",
				Completed = newSignal(),
				_goals = table.clone(goals),
			}, TweenMT)
		end,
		GetValue = function(_, alpha, style, direction)
			return EASE(style, direction, alpha)
		end,
	}

	for side, old in table.clone(games) do
		games[side] = {
			GetService = function(_, name)
				if name == "TweenService" then
					return TweenServiceStub
				end
				return old:GetService(name)
			end,
		}
	end
end
