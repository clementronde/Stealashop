-- Banc a215, partie serveur (collée après les scénarios d'a214, lancés avec SCENARIO = "none") : à la prise d'une bulle,
-- BubbleGone « Claimed » part AVANT la hausse de Speed (le client sait alors que la hausse vient d'une bulle).
-- a302 (21/11) : attente de la bulle lue dans Config/Bubbles (WAIT_ONE du banc a214 copié par a302).
local seenAtFire = nil
NetStub.Server.BubbleGone = {
	Fire = function(_, p, id, reason, gain)
		if reason == "Claimed" then
			seenAtFire = SPEED[p] or 0
		end
		table.insert(GONE, { p = p, id = id, reason = reason, gain = gain, at = NOW })
	end,
}
DATA[alice].Upgrades.Treadmill = 3 -- 8 par seconde
check("O1 Alice monte", mount(alice, 0))
local since = NOW
step(WAIT_ONE, FRAME) -- a302 : SpawnMax + 0,1 s (avant 3,1 s)
local s = spawnsOf(alice, since)[1]
check("O2 une bulle", s ~= nil)
if s then
	local before = SPEED[alice] or 0
	local ok, gain = BubbleService.Claim(alice, s.id)
	local g = goneOf(alice, s.id)
	check("O3 prise : gain = 8 × N", ok == true and gain == 8 * s.multiplier, gain)
	check("O4 BubbleGone « Claimed » avec le gain", g ~= nil and g.reason == "Claimed" and g.gain == 8 * s.multiplier)
	check("O5 envoyé avant la hausse de Speed", seenAtFire == before, `{seenAtFire} / {before}`)
	check("O6 puis Speed monte du gain, une fois", (SPEED[alice] or 0) - before == 8 * s.multiplier)
end
print(`banc a215 (bulles, ordre serveur) : {CHECKS} vérification(s), {FAILS} échec(s)`)
