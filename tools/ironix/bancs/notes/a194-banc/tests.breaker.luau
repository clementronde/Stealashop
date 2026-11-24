--!nocheck
-- Scénario « breaker » (a194, vague 60, Cantin 2026-11-15 : « il n'est pas censé essayer de nous chasser dès qu'on tape
-- sa vitrine »), sur la mise en place du banc a124 : pendant la casse de sa porte (hors tuto), le bot ne bouge pas
-- (ni poursuite, ni batte, aucune interdiction) ; prise dans la boutique : rien ; sortie avec l'objet : poursuite.
-- Le vrai propriétaire qui frappe le casseur : scénario owner du banc a177 (lancé par a194-banc/run.sh).

startBotServer()
local bob = join("Bob", newProfile())
local plot, S = botArrives()
local id = WindowService.GetWindowId(plot)
local root = botRoot()

section("Bob casse la porte du bot, coup par coup : le bot ne bouge pas")
moveTo(bob, S.outside + S.front * -3, S.front * -1)
local tool = giveTool(bob)
local moved, n = false, 0
while n < 300 and not WindowService.IsBroken(id) do
	fireAs(bob, "HitWindow", id)
	n += 1
	advance(0.2, 0.2)
	if not root.Anchored or BotService.IsChasing(bob) then
		moved = true
	end
end
tool:Destroy()
check(WindowService.IsBroken(id), `porte cassée ({n} coups)`)
check(not moved, "le bot est resté ancré, sans poursuite, pendant toute la casse")
check(#BOT_HITS == 0 and bob:GetAttribute("BatStun") == nil, "Bob jamais frappé")
check(PvPService.GetRobCooldown(bob, plot) == 0, "aucune interdiction pour Bob")
check(#notifies(bob, "Bonked!") == 0, "pas de message BreakerHit")

section("prise dans la boutique : rien ; sortie : poursuite")
enterShop(bob, S)
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
advance(3)
check(not BotService.IsChasing(bob) and root.Anchored and #BOT_HITS == 0, "3 s dedans avec l'objet : rien")
exitShop(bob, S)
advance(0.3)
check(BotService.IsChasing(bob) and not root.Anchored, "sorti avec l'objet : poursuivi")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
summary("scénario breaker")
