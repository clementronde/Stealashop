---------------------------------------------------------------- a401 (vague GC4, 23/11) : faux TweenService et TweenInfo
-- Collé après stubs.luau du banc a14 (copie a141), ajout pur. Un tween garde sa cible et l'écrit d'un coup à la fin de
-- sa durée (temps simulé), puis Completed(Completed) ; Cancel avant la fin : rien n'est écrit, Completed(Cancelled).
-- A401_TWEENS : tous les tweens créés, dans l'ordre ({ Instance, Info, Goal, State = "idle"|"playing"|"done"|"cancelled" }).
TweenInfo = {
	new = function(time, style, direction)
		return { Time = time or 1, EasingStyle = style, EasingDirection = direction }
	end,
}
A401_TWEENS = {}
function A401_TWEEN_SERVICE.Create(_, instance, info, goal)
	local listeners = {}
	local tween = { Instance = instance, Info = info, Goal = goal, State = "idle" }
	tween.Completed = {
		Connect = function(_, fn)
			table.insert(listeners, fn)
			return { Disconnect = function() end }
		end,
	}
	local function fire(state)
		for _, fn in table.clone(listeners) do
			taskLib.spawn(fn, state)
		end
	end
	function tween.Play(_)
		tween.State = "playing"
		taskLib.delay(info.Time, function()
			if tween.State ~= "playing" then
				return
			end
			tween.State = "done"
			for key, value in goal do
				instance[key] = value
			end
			fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween.Cancel(_)
		if tween.State == "playing" then
			tween.State = "cancelled"
			fire(Enum.PlaybackState.Cancelled)
		end
	end
	table.insert(A401_TWEENS, tween)
	return tween
end
