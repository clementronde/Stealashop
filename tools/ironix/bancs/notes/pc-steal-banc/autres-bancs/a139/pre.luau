-- a139 (2026-11-14) : préambule des suites a104 et a119, lu après le faux Roblox. Config/PerfClient est monté à
-- côté de DeepFreeze (si SOURCES l'a), sans changer les tests des autres bancs ; caméra avec un champ et une taille
-- d'écran (A139_CAMERA) pour que le test « à l'écran » de MutationFxController travaille.
do
	local baseModuleScript = moduleScript
	function moduleScript(parent, name, key)
		local m = baseModuleScript(parent, name, key)
		if name == "DeepFreeze" and SOURCES["shared/Config/PerfClient.luau"] and parent:FindFirstChild("PerfClient") == nil then
			baseModuleScript(parent, "PerfClient", "shared/Config/PerfClient.luau")
		end
		return m
	end
	if A139_CAMERA then
		Workspace.CurrentCamera.FieldOfView = 70
		Workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
	end
end
