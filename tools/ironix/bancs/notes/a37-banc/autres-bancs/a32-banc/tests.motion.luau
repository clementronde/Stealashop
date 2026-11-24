--!nocheck
-- Scénario « motion » (ajout a37, DEV-052) : apparition et disparition animées de l'alerte par
-- Controllers/UI/Motion, avec des tweens qui avancent dans le temps (le TweenService instantané du
-- faux d'a30 est remplacé ici, pour ce scénario seulement). Repli V0 : le bandeau entre et sort, le
-- voile plein écran n'est jamais mis à l'échelle. Écran de Clément : arrivé allumé au repos, éteint
-- d'un coup ; pendant un vol, ses cadres racine entrent et sortent ; une réannonce pendant la
-- sortie la rattrape. Sauté si le module UI/Motion manque (arbre d'avant la fusion de DEV-052).
if SOURCES["client/Controllers/UI/Motion.luau"] == nil then
	print("--- module Controllers/UI/Motion absent (DEV-052 pas encore fusionné) : scénario sauté")
	summary("scénario motion")
	return
end
do
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
		["Enum.EasingStyle.Back"] = function(u)
			return u * u * ((BACK + 1) * u - BACK)
		end,
	}
	local function ease(style, direction, u)
		local f = IN[style]
		if direction == "Enum.EasingDirection.In" then
			return f(u)
		elseif direction == "Enum.EasingDirection.Out" then
			return 1 - f(1 - u)
		end
		return if u < 0.5 then f(2 * u) / 2 else 1 - f(2 * (1 - u)) / 2
	end
	local active, clock = {}, 0
	local TweenMT = { __type = "Tween" }
	TweenMT.__index = TweenMT
	function TweenMT:Play()
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
		if i then
			table.remove(active, i)
			self.PlaybackState = "Enum.PlaybackState.Cancelled"
			self.Completed:Fire("Enum.PlaybackState.Cancelled")
		end
	end
	HEARTBEAT:Connect(function(dt)
		clock += dt
		for _, tween in table.clone(active) do
			if table.find(active, tween) then
				local u = math.min(1, (clock - tween._start) / tween.TweenInfo.Time)
				if u >= 1 - 1e-9 then
					table.remove(active, table.find(active, tween))
					for k, v in tween._goals do
						tween.Instance[k] = v
					end
					tween.PlaybackState = "Enum.PlaybackState.Completed"
					tween.Completed:Fire("Enum.PlaybackState.Completed")
				else
					local e = ease(tween.TweenInfo.EasingStyle, tween.TweenInfo.EasingDirection, u)
					for k, v in tween._goals do
						tween.Instance[k] = tween._from[k] + (v - tween._from[k]) * e
					end
				end
			end
		end
	end)
	local timed = {
		Create = function(_, inst, info, goals)
			return setmetatable({ Instance = inst, TweenInfo = info, Completed = newSignal(), _goals = table.clone(goals) }, TweenMT)
		end,
		GetValue = function(_, alpha, style, direction)
			return ease(style, direction, alpha)
		end,
	}
	-- TweenInfo du faux d'a30 : la durée seule ; les courbes sont gardées ici.
	TweenInfo = {
		new = function(time, style, direction)
			return setmetatable({
				Time = time or 1,
				EasingStyle = style or "Enum.EasingStyle.Quad",
				EasingDirection = direction or "Enum.EasingDirection.Out",
			}, { __type = "TweenInfo" })
		end,
	}
	for side, old in table.clone(games) do
		games[side] = setmetatable({
			GetService = function(_, name)
				if name == "TweenService" then
					return timed
				end
				return old:GetService(name)
			end,
		}, { __index = old })
	end
end

-- Le UIScale ajouté par Motion (nom de Config/UiMotion), ou nil.
local function codeScale(object)
	return object and object:FindFirstChild("MotionScale")
end

startServer()
local ada = join("Ada", victimProfile())
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
giveBat(ada)
startClient(ada)
advance(1.2)
local adaShop = shopOf(ada)

section("repli V0 (UI_TheftAlert pas livré)")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
frame()
local v0 = ada.PlayerGui:FindFirstChild("TheftAlertV0")
local banner = v0 and v0:FindFirstChild("Banner")
local veil = v0 and v0:FindFirstChild("Veil")
check(v0 ~= nil and v0.Enabled and state().Fallback, "alerte : repli V0 allumé tout de suite")
check(codeScale(banner) ~= nil, "le bandeau entre par une échelle passagère (UIScale du code)")
check(veil ~= nil and veil:FindFirstChildOfClass("UIScale") == nil, "le voile plein écran n'est pas mis à l'échelle")
advance(0.3)
check(v0.Enabled and codeScale(banner) == nil, "entrée finie : plus d'UIScale")
kill(bob)
flush()
frame()
check(v0.Enabled and not state().Active and codeScale(banner) ~= nil, "Bob meurt : sortie du bandeau en cours, repli encore allumé")
advance(0.2)
check(v0.Enabled == false and codeScale(banner) == nil, "puis éteint, UIScale retiré")

section("écran de Clément")
local screen = fakeScreen(ada.PlayerGui, true, 30) -- copie de StarterGui, arrivée allumée
advance(0.25)
local bannerC = screen:FindFirstChild("Banner")
local arrow = screen:FindFirstChild("Arrow")
check(screen.Enabled == false and codeScale(bannerC) == nil and codeScale(arrow) == nil, "arrivé allumé au repos : éteint d'un coup, sans animation")
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips (porte encore cassée)")
frame()
check(screen.Enabled and state().Active and not state().Fallback, "alerte sur l'écran de Clément")
check(codeScale(bannerC) ~= nil and codeScale(arrow) ~= nil, "ses deux cadres racine (Banner, Arrow) entrent par une échelle passagère")
check(ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "le repli V0 est détruit")
advance(0.3)
check(codeScale(bannerC) == nil and codeScale(arrow) == nil, "entrée finie")
local remote = ReplicatedStorage.Remotes.TheftAlert
remote:FireClient(ada, false) -- fin du vol annoncée par le serveur…
frame()
check(screen.Enabled and not state().Active and codeScale(bannerC) ~= nil, "fin annoncée : sortie en cours, écran encore allumé")
remote:FireClient(ada, true, cy, "Z1_PaquetDeChips") -- … puis réannonce aussitôt
frame()
check(screen.Enabled and state().Active, "réannonce pendant la sortie : l'alerte revient, l'écran reste allumé")
advance(0.3)
check(screen.Enabled and codeScale(bannerC) == nil, "revenu à sa taille, UIScale retiré")
advance(1)
check(screen.Enabled and state().Active, "toujours allumé : la sortie annulée n'éteint rien")
remote:FireClient(ada, false)
frame()
advance(0.2)
check(screen.Enabled == false and codeScale(bannerC) == nil and codeScale(arrow) == nil, "fin : éteint, plus aucun UIScale")
check(not logHas("[TheftAlertController]", "WARN"), "aucune erreur du contrôleur")

summary("scénario motion")
