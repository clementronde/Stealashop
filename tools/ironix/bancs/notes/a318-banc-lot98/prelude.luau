--!nocheck
-- Banc a318 : Net bouchonné (remotes muets), sources rangées dans l'arbre.
SOURCES["shared/Net/Net.luau"] = [==[
local function remote()
	local signal = {}
	function signal.Connect(_, _fn)
		return { Disconnect = function() end, Connected = true }
	end
	function signal.Fire() end
	return signal
end
return {
	Client = setmetatable({}, { __index = function(t, k)
		local r = remote()
		rawset(t, k, r)
		return r
	end }),
}
]==]
mountSources()
local MAP = model({ Name = "Map" }, Workspace)
function map()
	return MAP
end
function cycles(target, n, lose)
	for _ = 1, n do
		streamOut(target)
		advance(0.2)
		streamIn(target, lose)
		advance(0.2)
	end
end
