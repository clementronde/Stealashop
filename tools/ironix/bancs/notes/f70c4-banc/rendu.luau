-- f70c4 : RunService:BindToRenderStep du faux Roblox, appelés par ordre de priorité à chaque image (Heartbeat), et
-- Enum.RenderPriority (valeurs de Roblox).
do
	local baseEnum = Enum
	local renderPriority = {}
	for name, value in { First = 0, Input = 100, Camera = 200, Character = 300, Last = 2000 } do
		renderPriority[name] = { Name = name, Value = value }
	end
	Enum = setmetatable({ RenderPriority = renderPriority }, { __index = baseEnum })
end
RENDER_BOUND = {}
function BENCH_UNBIND(name)
	for i = #RENDER_BOUND, 1, -1 do
		if RENDER_BOUND[i].name == name then
			table.remove(RENDER_BOUND, i)
		end
	end
end
function BENCH_BIND(name, priority, fn)
	BENCH_UNBIND(name)
	assert(type(priority) == "number", "BindToRenderStep : priorité " .. tostring(priority))
	table.insert(RENDER_BOUND, { name = name, priority = priority, fn = fn })
	table.sort(RENDER_BOUND, function(a, b)
		return a.priority < b.priority
	end)
end
HEARTBEAT:Connect(function(dt)
	for _, b in table.clone(RENDER_BOUND) do
		if table.find(RENDER_BOUND, b) then
			b.fn(dt)
		end
	end
end)
