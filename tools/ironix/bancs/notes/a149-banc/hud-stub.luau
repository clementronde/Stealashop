---------------------------------------------------------------- bouchons des voisins (a149 : HeistController pilotable)
SOURCES["stub/HeistController"] = [==[
local H = {}
local listeners = {}
local police = {}
function H.OnTimer(fn) table.insert(listeners, fn) return function() end end
function H.GetTimers() return {} end
function H.IsPoliceTimer(id) return police[id] == true end
function H._fire(id, endsAt, isPolice)
	police[id] = isPolice
	for _, fn in listeners do
		fn(id, endsAt, isPolice)
	end
end
return H
]==]
CLEMENT_TIMER_COLOR = Color3.fromRGB(250, 220, 40)
