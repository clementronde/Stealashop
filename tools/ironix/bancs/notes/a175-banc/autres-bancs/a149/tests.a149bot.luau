--!nocheck
-- Copie a175 (vague 54, Cantin 2026-11-15) : la poursuite part à la sortie avec l objet, plus à la prise.
-- Banc a149 (vague 42), scénario bot, sur la mise en place du banc a124 (copie a149) : règle de Cantin du 2026-11-14.
-- Dan entre sans avoir rien volé : ni poursuivi ni frappé. Cy prend un objet puis le perd tout de suite (vol raté,
-- CarryService.Fail) en restant dans la boutique : toujours poursuivie et frappée (dedans, avec ou sans objet).
-- Valeurs V0 de la vague 42 (Config).

startBotServer()
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
local plot, S = botArrives()
local root = botRoot()
local bounds = plot:FindFirstChild("Bounds")
local insideSpot = Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6

section("Config de la vague 42")
check(BotConfig.Defense.TutorialKickCooldown == 15, "Bot.Defense.TutorialKickCooldown = 15 (Clément, L-146 point 3)")
local UiMotion = sharedModule("Config/UiMotion")
check(UiMotion.TimerTick.PoliceColor ~= nil and UiMotion.TimerTick.PoliceColor == UiMotion.TimerTick.RedColor, "UiMotion.TimerTick.PoliceColor : le rouge de HeistTimer (V0)")
local SkillTree = sharedModule("Config/SkillTree")
check(SkillTree.PlotVisuals.Walls ~= nil and not SkillTree.PlotVisuals.Walls.EveryStage, "Walls sans EveryStage : murs visibles à partir du niveau 3 (L-150 point 5, réponse c)")
check(SkillTree.HideFromWalls == "HideFromWalls", "attribut HideFromWalls lu par ShopWallsService (L-150 point 6)")
local UI = sharedModule("Contract/UI")
local sign
for _, b in UI.Billboards do
	if b.Name == "UpgradeSign" then
		sign = b
	end
end
check(sign and sign.Optional and sign.Class == "Model" and sign.Elements[1].Path == "Gain" and sign.Elements[1].Optional, "Contract/UI : UpgradeSign.Gain facultatif (orange sans lui)")
check(BotService.KickCooldown(cy) == nil, "hors tuto : KickCooldown nil (PvP.KickRobCooldown)")

section("intrus qui n'a rien volé : rien")
check(breakDoor(dan, plot), "Dan casse la porte")
moveTo(dan, insideSpot, S.front * -1)
advance(5)
check(inBox(bounds, rootOf(dan).Position), "Dan est dans la boutique")
check(not BotService.IsChasing(dan) and root.Anchored and #BOT_HITS == 0, "ni poursuivi ni frappé")
moveTo(dan, Vector3.new(0, 3, 0))

section("a175 : prise dedans, rien ; sortie avec l objet : poursuivie ; rentrée sans objet : poursuivie et frappée")
check(steal(cy, plot, 2), "Cy prend l objet du présentoir 2")
advance(2)
check(not BotService.IsChasing(cy) and root.Anchored and #BOT_HITS == 0, "dans la boutique avec l objet : ni poursuite ni coup")
moveTo(cy, Vector3.new(S.door.X, 3, S.door.Z) + S.front * 12, S.front)
advance(0.2)
check(BotService.IsChasing(cy), "poursuite démarrée à la sortie avec l objet")
CarryService.Fail(cy, "banc a149")
flush()
check(not CarryService.IsCarrying(cy), "Cy ne porte plus rien (vol raté)")
moveTo(cy, insideSpot, S.front * -1)
advance(0.1)
check(inBox(bounds, rootOf(cy).Position) and BotService.IsChasing(cy), "toujours poursuivie dans la boutique")
local hit = waitFor(function()
	return #BOT_HITS > 0
end, 8)
check(hit and BOT_HITS[1].target == cy, `frappée sans objet, dans la boutique (usage {BOT_HITS[1] and BOT_HITS[1].usage})`)
check(not BotService.IsChasing(dan) and #BOT_HITS == 1, "Dan jamais visé")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
summary("scénario a149bot")
