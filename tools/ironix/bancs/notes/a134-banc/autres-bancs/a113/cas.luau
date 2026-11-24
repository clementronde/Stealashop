--!nocheck
-- a113 : faux ContextActionService (ajouté aux services du faux Roblox par run.sh). CAS_BOUND[action] =
-- { fn, touch, keys, title, button } ; button = table { Size } quand le bouton tactile est demandé.
CAS_BOUND = {}
CAS_STUB = {
	BindAction = function(_, name, fn, touch, ...)
		CAS_BOUND[name] = { fn = fn, touch = touch, keys = { ... }, title = nil, button = if touch then { Size = nil } else nil }
	end,
	UnbindAction = function(_, name)
		CAS_BOUND[name] = nil
	end,
	SetTitle = function(_, name, title)
		if CAS_BOUND[name] then
			CAS_BOUND[name].title = title
		end
	end,
	GetButton = function(_, name)
		local b = CAS_BOUND[name]
		return b and b.button
	end,
}
