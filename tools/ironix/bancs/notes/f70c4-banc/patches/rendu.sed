# f70c4 : faux RunService.BindToRenderStep / UnbindFromRenderStep (rendu.luau : appelés par ordre de priorité à chaque image).
s/^(\s*)BindToRenderStep = function\(\) end,$/\1BindToRenderStep = function(_, name, priority, fn) BENCH_BIND(name, priority, fn) end,\n\1UnbindFromRenderStep = function(_, name) BENCH_UNBIND(name) end,/
