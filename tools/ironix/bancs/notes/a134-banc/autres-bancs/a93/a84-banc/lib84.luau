---------------------------------------------------------------- a84 : aides communes
-- Modules de la vague 27 ajoutés à l'arbre avant le démarrage (le vrai SkillTreeService, le bouchon de
-- TelemetryService, le vrai CameraAlertController).
moduleScript(SERVICES, "SkillTreeService", "server/Services/SkillTreeService.luau")
moduleScript(SERVICES, "ShopWallsService", "server/Services/ShopWallsService.luau") -- copie a93 (vague 29)
moduleScript(SERVICES, "TelemetryService", "stub/TelemetryService")
moduleScript(CONTROLLERS, "CameraAlertController", "client/Controllers/CameraAlertController.luau")
SKILL_IDS = { "Walls", "GlassThickness", "GlassRegen", "Cameras", "Bodyguards", "PotionLuck", "Curtain", "DoorGuard", "PotionTime", "Traps", "Safe" }

function startSkills()
	startServer()
	-- Copie a93 (vague 29) : PV de la porte = base du niveau de boutique (StageLevel). Niveau 2 = 50 × 10 = 500,
	-- la même base qu'avant (50 × les 10 dégâts du propriétaire du banc) : les contrôles d'a84 restent justes.
	for _, plot in CollectionService:GetTagged("PlayerPlot") do
		plot:SetAttribute("StageLevel", 2)
	end
	SkillTreeService = serverModule("SkillTreeService")
end
-- Achat par le vrai chemin (Net : forme et débit, 4 par seconde), puis 0,3 s.
function buy(player, id)
	fireAs(player, "BuySkill", id)
	advance(0.3)
end
function lastNotify(player)
	local list = notifies(player)
	local e = list[#list]
	return if e then e.args[1] else nil, if e then e.args[2] else nil
end
function doorOf(plot)
	return plot:FindFirstChild("Window", true)
end
-- Dernier WindowHP envoyé pour la porte de `plot` : PV, PV max.
function lastHP(plot)
	local id = windowIdOf(plot)
	local list = remotes("WindowHP", function(e)
		return e.args[1] == id
	end)
	local e = list[#list]
	return if e then e.args[2] else nil, if e then e.args[3] else nil
end
-- `n` coups de `hitter` sur la porte de `plot`, outil en main, 9 par seconde.
function hitDoor(hitter, plot, n)
	local S = refsOfShop(plot)
	local id = windowIdOf(plot)
	moveTo(hitter, S.outside + S.front * -3)
	local tool = giveTool(hitter)
	for _ = 1, n do
		fireAs(hitter, "HitWindow", id)
		advance(0.11)
	end
	tool:Destroy()
end
