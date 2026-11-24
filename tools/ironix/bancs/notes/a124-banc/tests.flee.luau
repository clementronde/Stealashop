--!nocheck
-- Scénario « flee » (a124) : Bob prend un objet et court chez lui à 16 studs/s (vitesse fixe d'un voleur) : le
-- bot (13,4) ne le rattrape pas, le lâche à 15 studs de sa boutique, rentre ; Bob dépose l'objet chez lui.
-- Puis Cy casse la porte et reste devant : le bot la suit, ne la frappe pas, rentre au bout de 10 s.

startBotServer()
local bobData = newProfile()
local bob = join("Bob", bobData)
local cy = join("Cy", newProfile())
local plot, S = botArrives()
local root = botRoot()
local home = root.CFrame
local bounds = plot:FindFirstChild("Bounds")

section("fuite : le voleur distance le bot")
check(breakDoor(bob, plot), "Bob casse la porte")
local uid = BotService.GetExposed(plot)[2].Uid
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
local leashSeen = false
local watch = ON_FRAME
ON_FRAME = function()
	if watch then
		watch()
	end
	local r = rootOf(bob)
	if r and BotService.IsChasing(bob) then
		local p = bounds.CFrame:PointToObjectSpace(r.Position)
		local h = bounds.Size / 2
		local dx, dz = math.max(math.abs(p.X) - h.X, 0), math.max(math.abs(p.Z) - h.Z, 0)
		if math.sqrt(dx * dx + dz * dz) > 15 + 16 * 0.1 + 0.1 then
			leashSeen = true -- encore poursuivi au-delà de la laisse (un tick de 0,1 s de marge)
		end
	end
end
runHome(bob, plot, 16)
ON_FRAME = watch
check(#BOT_HITS == 0 and bob:GetAttribute("BatStun") == nil, "Bob n'a pas été frappé")
check(not leashSeen, "lâché à 15 studs de la boutique du bot au plus")
check(bobData.Items[uid] ~= nil and bobData.Items[uid].Source == "PvP", "objet déposé chez Bob")
check(not BotService.IsChasing(bob), "plus poursuivi")
check(waitFor(function()
	return root.Anchored
end, 12) and (root.Position - home.Position).Magnitude < 1e-3, "le bot rentre et se ré-ancre")

section("casseur resté devant la porte : abandon au bout du temps")
local waited = 0
local id = WindowService.GetWindowId(plot)
while WindowService.IsBroken(id) and waited < 40 do
	advance(0.5)
	waited += 0.5
end
check(breakDoor(cy, plot), "Cy casse la porte")
local t0 = now()
check(BotService.IsChasing(cy), "le bot poursuit Cy")
local gaveUp = waitFor(function()
	return not BotService.IsChasing(cy)
end, 12)
local after = now() - t0
check(gaveUp and after >= 10 and after <= 10.3, `abandon au bout de 10 s (après {math.round(after * 10) / 10} s)`)
check(#BOT_HITS == 0 and cy:GetAttribute("BatStun") == nil, "Cy, dehors, jamais frappée")
check(waitFor(function()
	return root.Anchored
end, 12) and (root.Position - home.Position).Magnitude < 1e-3, "rentré et ré-ancré")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
summary("scénario flee")
