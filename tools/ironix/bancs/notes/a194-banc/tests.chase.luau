--!nocheck
-- Scénario « chase » (a194, vague 60, Cantin 2026-11-15 : « il faut qu'il nous pourchasse jusqu'au bout »), sur la
-- mise en place du banc a124 : le voleur sorti avec un objet du bot est poursuivi sans laisse (15 studs) ni compte
-- (10 s), jusqu'à la fin : capture (Bob, arrêté loin), dépôt chez soi (Cy, qui court plus vite que le bot), zone safe
-- qui ne contient pas la boutique du bot (Dan). La grande zone safe du hub (qui contient la boutique) n'arrête rien.

startBotServer()
local cyData = newProfile()
local bob = join("Bob", newProfile())
local cy = join("Cy", cyData)
local dan = join("Dan", newProfile())
local plot, S = botArrives()
local root = botRoot()
local home = root.CFrame
local bounds = plot:FindFirstChild("Bounds")
local function outside(p)
	local r = rootOf(p)
	local q = bounds.CFrame:PointToObjectSpace(r.Position)
	local h = bounds.Size / 2
	local dx, dz = math.max(math.abs(q.X) - h.X, 0), math.max(math.abs(q.Z) - h.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

section("1. capture : Bob s'arrête à 40 studs, le bot vient le frapper (plus de laisse ni de 10 s)")
check(breakDoor(bob, plot), "Bob casse la porte")
enterShop(bob, S)
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
exitShop(bob, S, 40)
advance(0.3)
check(outside(bob) > 15, `Bob à {math.round(outside(bob))} studs de la boutique (plus que la laisse)`)
check(BotService.IsChasing(bob), "Bob poursuivi au-delà de la laisse")
local caught = waitFor(function()
	return #BOT_HITS > 0
end, 20)
check(caught and BOT_HITS[1].target == bob and BOT_HITS[1].usage == "Defend", "Bob frappé loin de la boutique (« Defend »)")
flush()
check(not CarryService.IsCarrying(bob) and BotService.GetExposed(plot)[2] ~= nil, "objet revenu sur son présentoir")
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre et se ré-ancre")

section("2. dépôt : Cy court chez elle, poursuivie jusqu'au bout, puis le bot rentre")
check(breakDoor(cy, plot), "Cy casse la porte")
enterShop(cy, S)
local uid = BotService.GetExposed(plot)[3].Uid
check(steal(cy, plot, 3), "Cy prend l'objet du présentoir 3")
local far, lost = 0, false
local watch = ON_FRAME
ON_FRAME = function()
	if watch then
		watch()
	end
	if CarryService.IsCarrying(cy) and rootOf(cy) and outside(cy) > 0.5 then
		if BotService.IsChasing(cy) then
			far = math.max(far, outside(cy))
		elseif outside(cy) > 2 then
			lost = true
		end
	end
end
runHome(cy, plot, 16)
ON_FRAME = watch
check(cyData.Items[uid] ~= nil and cyData.Items[uid].Source == "PvP", "objet déposé chez Cy")
check(not lost, "jamais lâchée avant le dépôt")
check(far > 15, `poursuivie jusqu'à {math.round(far)} studs de la boutique du bot`)
advance(0.3)
check(not BotService.IsChasing(cy), "déposé : plus poursuivie")
check(waitFor(function()
	return root.Anchored
end, 15) and (root.Position - home.Position).Magnitude < 1e-3, "le bot rentre à son point d'apparition")

section("3. zone safe étrangère : Dan s'y réfugie, la poursuite s'arrête")
local far = make("Part", { Name = "SafeZoneLoin", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(40, 40, 40), CFrame = CFrame.new(900, 10, 0) }, HUB)
addTag(far, "SafeZone")
check(breakDoor(dan, plot), "Dan casse la porte")
enterShop(dan, S)
check(steal(dan, plot, 4), "Dan prend l'objet du présentoir 4")
exitShop(dan, S, 20)
advance(0.3)
check(BotService.IsChasing(dan), "Dan poursuivi (la zone safe du hub, qui contient la boutique, n'arrête rien)")
moveTo(dan, Vector3.new(900, 3, 0))
advance(0.5)
check(not BotService.IsChasing(dan), "Dan dans une autre zone safe : plus poursuivi")
check(CarryService.IsCarrying(dan), "Dan garde l'objet")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario chase")
