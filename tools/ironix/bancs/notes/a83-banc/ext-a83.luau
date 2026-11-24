---------------------------------------------------------------- ajouts a83 (2026-11-11)
-- PlotDoorController : GetPropertyChangedSignal (signal qui se déclenche quand le banc le demande) et
-- RunService.RenderStepped côté client.
PROPERTY_SIGNALS = {}
function Methods.GetPropertyChangedSignal(self, name)
	local byInst = PROPERTY_SIGNALS[self] or {}
	PROPERTY_SIGNALS[self] = byInst
	byInst[name] = byInst[name] or newSignal()
	return byInst[name]
end
games.client:GetService("RunService").RenderStepped = newSignal()
