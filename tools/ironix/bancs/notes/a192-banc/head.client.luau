--!nocheck
-- a192 : modules du client absents de la mise en place d'a42 (HudMask sous Controllers/UI, s'il n'y est pas déjà ;
-- HeistController bouchonné : ses chronos, pilotés par le test).
local uiFolder = CONTROLLERS:FindFirstChild("UI")
if uiFolder and not uiFolder:FindFirstChild("HudMask") then
	moduleScript(uiFolder, "HudMask", "client/Controllers/UI/HudMask.luau")
end
-- a207 (vague 63, ajout pur) : Controllers/UI/RarityFx, requis par CatchSceneController (carte ITEM SECURED).
if uiFolder and not uiFolder:FindFirstChild("RarityFx") and SOURCES["client/Controllers/UI/RarityFx.luau"] then
	moduleScript(uiFolder, "RarityFx", "client/Controllers/UI/RarityFx.luau")
end
SOURCES["stub/Heist192"] = [==[
local H = { timers = {} }
function H.GetTimers()
	return H.timers
end
return H
]==]
moduleScript(CONTROLLERS, "HeistController", "stub/Heist192")
